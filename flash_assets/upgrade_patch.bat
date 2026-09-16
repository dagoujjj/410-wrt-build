@echo off
chcp 65001 >nul
@title 一键刷入openwrt 补丁
color 1f

mode con cols=100 lines=30

@echo adb重启到fastboot模式（如果已在fastboot模式，出现error: no devices/emulators found属正常）
adb reboot bootloader
set /p a=确认执行？（输入1继续，0退出）：
if /i '%a%'=='0' goto end
timeout /NOBREAK 3
fastboot erase boot
fastboot flash boot boot.img
timeout /NOBREAK 3
fastboot erase rootfs
fastboot -S 200m flash rootfs system.img
timeout /NOBREAK 3
fastboot reboot
@echo 刷入完成，重启中...
timeout 5
pause

:end
