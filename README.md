# 高通 410 随身 WiFi 固件云编译

> If you cannot read Chinese, please use translation software.

基于 ImmortalWrt 的高通 410 随身 WiFi 固件构建项目。通过 GitHub Actions 在线更新上游、构建刷机工具或编译固件，无需配置本地编译环境。

## 部署与配置

### 1. Fork 仓库

点击仓库右上角的 **Fork**，将本仓库复制到自己的 GitHub 账号。

### 2. 运行 Actions

进入 Fork 后的仓库，打开 **Actions** 页面，按需选择工作流并点击 **Run workflow**：

- **Verify Upstream**：检查并更新锁定的上游源码版本。
- **Build ImmortalWrt Snapdragon 410 Firmware**：选择设备型号并构建固件。
- **Build Flash Tool**：构建刷机工具。

构建固件时可填写额外软件包名称；不需要额外软件包时保持为空。构建完成后，在工作流运行页面或 Releases 中下载压缩包。

## 支持的设备

- UFI003
- UFI001B / UFI001C
- UFI103S
- JZ02 V10
- QRZL903
- W001
- UZ801
- MF32 / MF601
- WF2
- SP970 V10 / V11

请选择与设备完全匹配的型号。刷入错误固件可能导致设备无法启动。

## 刷入固件

解压固件压缩包，确认目录中包含 `boot.img`、`system.img`、`upgrade_patch.bat` 和 `upgrade_patch.sh`。

刷机前请备份重要数据，保持 USB 连接稳定。刷机过程会擦除并重写 `boot` 与 `rootfs` 分区；当前发布物不提供经过目标设备验证的 LuCI 动态升级或通用 sysupgrade 入口。

### Windows

1. 确认目录中存在 `adb.exe` 和 `fastboot.exe`，或已将 ADB 与 Fastboot 加入系统 `PATH`。
2. 连接设备并启用 ADB 调试。
3. 双击运行 `upgrade_patch.bat`，按英文提示操作。

### Linux

1. 安装 `adb` 和 `fastboot`，并确认当前用户具有访问设备的权限。
2. 连接设备并启用 ADB 调试。
3. 在解压目录执行：

```bash
chmod +x upgrade_patch.sh
./upgrade_patch.sh
```

两个脚本都会检查 ADB、Fastboot、`boot.img` 和 `system.img`。缺少任意必要项时不会开始刷写。

## 默认管理信息

- 管理地址：`192.168.1.1`
- 用户名：`root`
- 默认密码：无

首次登录后请立即设置管理密码。

## 项目说明

- 固件使用已验证并锁定的 ImmortalWrt 上游版本。
- 如需更新源码，请先运行上游检查工作流，再构建固件。
- 固件使用官方 ImmortalWrt 软件源，二进制包架构为 `aarch64_generic`。
- 每个设备配置均内置指定软件包、所选 `kmod-*` 和 `kmod-dummy`。
- 可通过构建工作流按需添加额外软件包。

## 致谢

感谢 OpenWrt、ImmortalWrt、GitHub Actions 及相关开源项目的贡献者。

## 许可证

本项目遵循仓库中的许可证文件。第三方源码和组件分别遵循其各自许可证。
