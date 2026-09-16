// Package fastboot 实现 Fastboot USB 协议，直接通过 libusb 通信，无需安装任何驱动。
package fastboot

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"github.com/google/gousb"
)

const (
	// Fastboot 设备的 USB Class/SubClass/Protocol
	fbClass    = 0xff
	fbSubClass = 0x42
	fbProtocol = 0x03

	maxPacket = 64 * 1024 // 64KB 单次传输上限
	timeout   = 30 * time.Second
)

// Device 代表一个已连接的 Fastboot 设备
type Device struct {
	ctx   *gousb.Context
	dev   *gousb.Device
	cfg   *gousb.Config
	iface *gousb.Interface
	inEP  *gousb.InEndpoint
	outEP *gousb.OutEndpoint
}

// Open 扫描 USB 总线，找到第一个 Fastboot 设备并打开
func Open() (*Device, error) {
	ctx := gousb.NewContext()

	devs, err := ctx.OpenDevices(func(desc *gousb.DeviceDesc) bool {
		for _, cfg := range desc.Configs {
			for _, iface := range cfg.Interfaces {
				for _, alt := range iface.AltSettings {
					if alt.Class == fbClass &&
						alt.SubClass == fbSubClass &&
						alt.Protocol == fbProtocol {
						return true
					}
				}
			}
		}
		return false
	})
	// OpenDevices 在没有权限访问某些设备时会返回 err，但只要找到了目标设备就继续
	if len(devs) == 0 {
		ctx.Close()
		if err != nil {
			return nil, fmt.Errorf("未找到 Fastboot 设备：%w", err)
		}
		return nil, fmt.Errorf("未找到 Fastboot 设备，请确认设备已进入 Fastboot 模式")
	}

	usbDev := devs[0]
	// 关闭多余设备
	for _, d := range devs[1:] {
		d.Close()
	}

	usbDev.SetAutoDetach(true)

	// 找到正确的配置和接口
	cfg, err := usbDev.Config(1)
	if err != nil {
		usbDev.Close()
		ctx.Close()
		return nil, fmt.Errorf("无法获取 USB 配置：%w", err)
	}

	var iface *gousb.Interface
	var inEP *gousb.InEndpoint
	var outEP *gousb.OutEndpoint

	for _, ifaceDesc := range cfg.Desc.Interfaces {
		for _, alt := range ifaceDesc.AltSettings {
			if alt.Class == fbClass && alt.SubClass == fbSubClass && alt.Protocol == fbProtocol {
				iface, err = cfg.Interface(ifaceDesc.Number, alt.Alternate)
				if err != nil {
					continue
				}
				// 找 IN 和 OUT endpoint
				for _, ep := range alt.Endpoints {
					if ep.Direction == gousb.EndpointDirectionIn {
						inEP, err = iface.InEndpoint(ep.Number)
						if err != nil {
							iface.Close()
							cfg.Close()
							usbDev.Close()
							ctx.Close()
							return nil, fmt.Errorf("无法打开 IN endpoint：%w", err)
						}
					} else {
						outEP, err = iface.OutEndpoint(ep.Number)
						if err != nil {
							iface.Close()
							cfg.Close()
							usbDev.Close()
							ctx.Close()
							return nil, fmt.Errorf("无法打开 OUT endpoint：%w", err)
						}
					}
				}
				if inEP == nil || outEP == nil {
					iface.Close()
					continue
				}
				goto found
			}
		}
	}
	cfg.Close()
	usbDev.Close()
	ctx.Close()
	return nil, fmt.Errorf("未找到 Fastboot 接口（IN/OUT endpoint 不完整）")

found:
	return &Device{
		ctx:   ctx,
		dev:   usbDev,
		cfg:   cfg,
		iface: iface,
		inEP:  inEP,
		outEP: outEP,
	}, nil
}

// Close 释放设备资源
func (d *Device) Close() {
	if d.iface != nil {
		d.iface.Close()
		d.iface = nil
	}
	if d.cfg != nil {
		d.cfg.Close()
		d.cfg = nil
	}
	if d.dev != nil {
		d.dev.Close()
		d.dev = nil
	}
	if d.ctx != nil {
		d.ctx.Close()
		d.ctx = nil
	}
}

// Command 发送一条 Fastboot 命令，返回设备响应
func (d *Device) Command(cmd string) (string, error) {
	if err := d.send([]byte(cmd)); err != nil {
		return "", fmt.Errorf("发送命令失败：%w", err)
	}
	return d.readResponse()
}

// GetVar 获取设备变量
func (d *Device) GetVar(variable string) (string, error) {
	return d.Command("getvar:" + variable)
}

// Erase 擦除分区
func (d *Device) Erase(partition string) error {
	resp, err := d.Command("erase:" + partition)
	if err != nil {
		return err
	}
	if !strings.HasPrefix(resp, "OKAY") {
		return fmt.Errorf("擦除 %s 失败：%s", partition, resp)
	}
	return nil
}

// Flash 刷写分区，支持进度回调
func (d *Device) Flash(partition string, data []byte, progress func(sent, total int)) error {
	return d.flashReader(partition, bytes.NewReader(data), len(data), maxPacket, progress)
}

// FlashFile 从文件流式刷写分区，避免将大文件一次性载入内存。
func (d *Device) FlashFile(partition, path string, progress func(sent, total int)) error {
	f, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("读取文件失败 %s：%w", path, err)
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		return fmt.Errorf("读取文件信息失败 %s：%w", path, err)
	}
	if info.Size() > int64(^uint(0)>>1) {
		return fmt.Errorf("文件过大，无法在当前平台传输：%s", path)
	}
	return d.flashReader(partition, f, int(info.Size()), maxPacket, progress)
}

// FlashFileSparse streams one download transaction for a large image.
// Fastboot writes each flash command from the start of the partition, so
// splitting the image into multiple Flash calls would overwrite earlier data.
// chunkSize is retained for API compatibility and is only used as the buffer size.
func (d *Device) FlashFileSparse(partition, path string, chunkSize int, progress func(sent, total int)) error {
	f, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("读取文件失败 %s：%w", path, err)
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		return fmt.Errorf("读取文件信息失败 %s：%w", path, err)
	}
	if info.Size() > int64(^uint(0)>>1) {
		return fmt.Errorf("文件过大，无法在当前平台传输：%s", path)
	}
	if chunkSize <= 0 || chunkSize > 4*1024*1024 {
		chunkSize = 4 * 1024 * 1024
	}
	return d.flashReader(partition, f, int(info.Size()), chunkSize, progress)
}

// flashReader performs exactly one download/flash transaction for a reader.
func (d *Device) flashReader(partition string, r io.Reader, total, bufferSize int, progress func(sent, total int)) error {
	if total < 0 {
		return fmt.Errorf("无效的数据大小：%d", total)
	}
	resp, err := d.Command(fmt.Sprintf("download:%08x", total))
	if err != nil {
		return err
	}
	if !strings.HasPrefix(resp, "DATA") {
		return fmt.Errorf("download 命令失败：%s", resp)
	}
	if bufferSize <= 0 || bufferSize > 4*1024*1024 {
		bufferSize = 4 * 1024 * 1024
	}

	buf := make([]byte, bufferSize)
	sent := 0
	for sent < total {
		want := total - sent
		if want > len(buf) {
			want = len(buf)
		}
		n, readErr := io.ReadFull(r, buf[:want])
		if n > 0 {
			written := 0
			for written < n {
				end := written + maxPacket
				if end > n {
					end = n
				}
				chunkWritten := 0
				for chunkWritten < end-written {
					m, writeErr := d.outEP.Write(buf[written+chunkWritten : end])
					if writeErr != nil {
						return fmt.Errorf("数据传输失败（offset %d）：%w", sent+written+chunkWritten, writeErr)
					}
					if m <= 0 {
						return fmt.Errorf("数据传输失败（offset %d）：写入 0 字节", sent+written+chunkWritten)
					}
					chunkWritten += m
				}
				written += chunkWritten
			}
			sent += n
			if progress != nil {
				progress(sent, total)
			}
		}
		if readErr != nil {
			if readErr == io.EOF || readErr == io.ErrUnexpectedEOF {
				return fmt.Errorf("文件数据不足：已读取 %d/%d 字节", sent, total)
			}
			return fmt.Errorf("读取数据失败（offset %d）：%w", sent, readErr)
		}
	}

	resp, err = d.readResponse()
	if err != nil {
		return err
	}
	if !strings.HasPrefix(resp, "OKAY") {
		return fmt.Errorf("download 完成确认失败：%s", resp)
	}
	resp, err = d.Command("flash:" + partition)
	if err != nil {
		return err
	}
	if !strings.HasPrefix(resp, "OKAY") {
		return fmt.Errorf("flash %s 失败：%s", partition, resp)
	}
	return nil
}

// OEMDump 备份分区（fastboot oem dump + get_staged）
func (d *Device) OEMDump(partition, outFile string) error {
	// oem dump <partition>
	resp, err := d.Command("oem dump " + partition)
	if err != nil {
		return fmt.Errorf("oem dump %s 失败：%w", partition, err)
	}
	if strings.Contains(resp, "FAIL") {
		return fmt.Errorf("oem dump %s 被拒绝：%s", partition, resp)
	}

	// get_staged → 读取数据
	if err := d.send([]byte("get_staged")); err != nil {
		return fmt.Errorf("get_staged 发送失败：%w", err)
	}

	// 先读 DATA:<size>
	header := make([]byte, 64)
	n, err := d.inEP.Read(header)
	if err != nil {
		return fmt.Errorf("get_staged 读取头部失败：%w", err)
	}
	headerStr := strings.TrimSpace(string(header[:n]))
	if !strings.HasPrefix(headerStr, "DATA") {
		return fmt.Errorf("get_staged 响应异常：%s", headerStr)
	}

	// 解析大小
	var size uint32
	fmt.Sscanf(headerStr[4:], "%x", &size)
	if size == 0 {
		return fmt.Errorf("get_staged 返回大小为0，分区可能为空")
	}

	// 读取数据
	data := make([]byte, size)
	totalRead := 0
	for totalRead < int(size) {
		n, err := d.inEP.Read(data[totalRead:])
		totalRead += n
		if err != nil && err != io.EOF {
			return fmt.Errorf("get_staged 读取数据失败：%w", err)
		}
		if err == io.EOF {
			break
		}
	}

	// 读 OKAY
	_, _ = d.readResponse()

	// 写文件
	if err := os.WriteFile(outFile, data[:totalRead], 0644); err != nil {
		return fmt.Errorf("写入备份文件失败：%w", err)
	}
	return nil
}

// Reboot 重启设备
func (d *Device) Reboot() error {
	// reboot 命令设备可能不回 OKAY 就断开，忽略错误
	_ = d.send([]byte("reboot"))
	return nil
}

// RebootBootloader 重启到 Bootloader
func (d *Device) RebootBootloader() error {
	// 同上，设备重启后连接断开属正常
	_ = d.send([]byte("reboot-bootloader"))
	return nil
}

// ── 内部方法 ──────────────────────────────────────────────────────────────────

func (d *Device) send(data []byte) error {
	_, err := d.outEP.Write(data)
	return err
}

// readResponse 读取设备响应，处理 INFO 多行和最终 OKAY/FAIL
// Fastboot 响应格式固定为 4字节类型 + 内容，每包最大 64 字节
func (d *Device) readResponse() (string, error) {
	deadline := time.Now().Add(timeout)

	for time.Now().Before(deadline) {
		buf := make([]byte, 64)
		n, err := d.inEP.Read(buf)
		if err != nil {
			if err == io.EOF {
				time.Sleep(10 * time.Millisecond)
				continue
			}
			return "", fmt.Errorf("读取响应失败：%w", err)
		}
		if n < 4 {
			time.Sleep(10 * time.Millisecond)
			continue
		}
		resp := string(buf[:n])
		tag := resp[:4]

		switch tag {
		case "OKAY":
			return resp, nil
		case "FAIL":
			return resp, fmt.Errorf("设备返回错误：%s", resp[4:])
		case "DATA":
			return resp, nil
		case "INFO":
			// INFO 是设备打印的日志，继续读直到 OKAY/FAIL
			continue
		default:
			time.Sleep(10 * time.Millisecond)
		}
	}
	return "", fmt.Errorf("等待响应超时（%v）", timeout)
}

// WaitForDevice 等待 Fastboot 设备出现，最多等 waitSec 秒
func WaitForDevice(waitSec int) (*Device, error) {
	deadline := time.Now().Add(time.Duration(waitSec) * time.Second)
	for time.Now().Before(deadline) {
		dev, err := Open()
		if err == nil {
			return dev, nil
		}
		time.Sleep(500 * time.Millisecond)
	}
	return nil, fmt.Errorf("等待设备超时（%d秒）", waitSec)
}

// SparseImageSize 读取 sparse image 的实际大小（用于进度显示）
func SparseImageSize(path string) (int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, err
	}
	defer f.Close()

	// sparse image magic: 0xed26ff3a
	magic := make([]byte, 4)
	if _, err := f.Read(magic); err != nil {
		return 0, err
	}
	if binary.LittleEndian.Uint32(magic) == 0xed26ff3a {
		// 读 total_blks (offset 16) 和 blk_sz (offset 8)
		header := make([]byte, 28)
		f.Seek(0, 0)
		f.Read(header)
		blkSz := binary.LittleEndian.Uint32(header[8:12])
		totalBlks := binary.LittleEndian.Uint32(header[16:20])
		return int64(blkSz) * int64(totalBlks), nil
	}

	info, _ := f.Stat()
	return info.Size(), nil
}
