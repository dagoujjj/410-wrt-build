@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
title OpenWrt Upgrade Patch
color 1f
mode con cols=100 lines=30

set "ADB=adb"
set "FASTBOOT=fastboot"
if exist "%SCRIPT_DIR%adb.exe" set "ADB=%SCRIPT_DIR%adb.exe"
if exist "%SCRIPT_DIR%fastboot.exe" set "FASTBOOT=%SCRIPT_DIR%fastboot.exe"

echo Checking required tools...
"%ADB%" version >nul 2>&1
if errorlevel 1 (
    echo ERROR: adb.exe was not found in this directory or in PATH.
    goto error
)

"%FASTBOOT%" --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: fastboot.exe was not found in this directory or in PATH.
    goto error
)

if not exist "%SCRIPT_DIR%boot.img" (
    echo ERROR: boot.img was not found in the script directory.
    goto error
)

if not exist "%SCRIPT_DIR%system.img" (
    echo ERROR: system.img was not found in the script directory.
    goto error
)

echo Required tools and image files are available.
echo.
echo The boot and rootfs partitions will be erased and rewritten.
set /p "CONFIRM=Type YES to continue: "
if /i not "%CONFIRM%"=="YES" goto cancelled

echo Rebooting the device into Fastboot mode...
"%ADB%" reboot bootloader >nul 2>&1
if errorlevel 1 echo ADB did not find a device. Continuing in case the device is already in Fastboot mode.

echo Waiting for a Fastboot device...
set /a WAIT_COUNT=0
:wait_fastboot
"%FASTBOOT%" devices | findstr /r /c:"^[^ ][^ ]*.*fastboot" >nul
if not errorlevel 1 goto flash
set /a WAIT_COUNT+=1
if %WAIT_COUNT% GEQ 30 (
    echo ERROR: No Fastboot device was detected within 60 seconds.
    goto error
)
timeout /t 2 /nobreak >nul
goto wait_fastboot

:flash
echo Erasing the boot partition...
"%FASTBOOT%" erase boot || goto flash_error

echo Flashing boot.img...
"%FASTBOOT%" flash boot "%SCRIPT_DIR%boot.img" || goto flash_error

echo Erasing the rootfs partition...
"%FASTBOOT%" erase rootfs || goto flash_error

echo Flashing system.img...
"%FASTBOOT%" -S 200m flash rootfs "%SCRIPT_DIR%system.img" || goto flash_error

echo Rebooting the device...
"%FASTBOOT%" reboot || goto flash_error

echo Upgrade completed successfully.
goto finish

:flash_error
echo ERROR: A Fastboot command failed. The device has not been reported as successfully upgraded.
goto error

:cancelled
echo Operation cancelled.
goto finish

:error
echo.
echo Upgrade stopped.
pause
exit /b 1

:finish
echo.
pause
exit /b 0
