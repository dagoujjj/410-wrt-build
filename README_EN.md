# Qualcomm 410 Portable Wi-Fi Firmware Builder

> If you cannot read Chinese, please use translation software. The main README is in Chinese.

This repository builds Qualcomm 410 OpenWrt firmware with GitHub Actions. It also provides workflows for upstream verification and flash-tool builds.

## Build

1. Fork this repository to your GitHub account.
2. Open **Actions** in your fork.
3. Run one of these workflows as needed:
   - **Verify Upstream** checks and updates the locked ImmortalWrt source commit.
   - **Build ImmortalWrt Snapdragon 410 Firmware** builds a selected device profile.
   - **Build Flash Tool** builds the flash tool.
4. Leave `extra_packages` empty for the default package set, or enter additional package names when needed.
5. Download the firmware archive from the workflow artifacts or **Releases**.

## Supported Devices

UFI003, UFI001B, UFI001C, UFI103S, JZ02 V10, QRZL903, W001, UZ801, MF32, MF601, WF2, SP970 V10, and SP970 V11.

Select the profile that exactly matches the device. An incorrect image may prevent the device from booting.

## Flashing

Extract the firmware archive and confirm that it contains `boot.img`, `system.img`, `upgrade_patch.bat`, and `upgrade_patch.sh`. Back up important data before flashing. The scripts erase and rewrite the `boot` and `rootfs` partitions.

The current release does not provide a target-validated LuCI dynamic upgrade or generic sysupgrade path.

### Windows

Keep `adb.exe` and `fastboot.exe` in the extracted directory, or add ADB and Fastboot to `PATH`. Connect the device with ADB debugging enabled, then run `upgrade_patch.bat`. The script checks the required tools, images, and Fastboot device before flashing.

### Linux

Install `adb` and `fastboot`, ensure the current user can access the device, and connect it with ADB debugging enabled. Run:

```bash
chmod +x upgrade_patch.sh
./upgrade_patch.sh
```

The script checks ADB, Fastboot, `boot.img`, and `system.img` before it starts.

## Default Access

- Address: `192.168.1.1`
- User: `root`
- Password: empty

Set a password after the first login.

## Build Notes

- Builds use a verified and locked ImmortalWrt source commit.
- Run upstream verification before changing the source version.
- Runtime feeds use the official ImmortalWrt repository and the `aarch64_generic` binary package architecture.
- Every profile includes its selected `kmod-*` packages and `kmod-dummy` as built-ins.
- Firmware target and package-feed architecture are separate settings: the firmware target remains `msm89xx`.

## License

This project follows the repository license. Third-party source code and components remain under their respective licenses.
