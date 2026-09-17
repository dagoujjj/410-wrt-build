#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

fail() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

command -v adb >/dev/null 2>&1 || fail "adb was not found in PATH."
command -v fastboot >/dev/null 2>&1 || fail "fastboot was not found in PATH."
[ -f boot.img ] || fail "boot.img was not found in the script directory."
[ -f system.img ] || fail "system.img was not found in the script directory."

printf '%s\n' "Required tools and image files are available."
printf '%s\n' "The boot and rootfs partitions will be erased and rewritten."
printf '%s' "Type YES to continue: "
IFS= read -r confirm
[ "$confirm" = "YES" ] || {
    printf '%s\n' "Operation cancelled."
    exit 0
}

printf '%s\n' "Rebooting the device into Fastboot mode..."
if ! adb reboot bootloader >/dev/null 2>&1; then
    printf '%s\n' "ADB did not find a device. Continuing in case the device is already in Fastboot mode."
fi

printf '%s\n' "Waiting for a Fastboot device..."
count=0
while ! fastboot devices | grep -Eq '^[^[:space:]]+[[:space:]]+fastboot$'; do
    count=$((count + 1))
    [ "$count" -lt 30 ] || fail "No Fastboot device was detected within 60 seconds."
    sleep 2
done

printf '%s\n' "Erasing the boot partition..."
fastboot erase boot
printf '%s\n' "Flashing boot.img..."
fastboot flash boot boot.img
printf '%s\n' "Erasing the rootfs partition..."
fastboot erase rootfs
printf '%s\n' "Flashing system.img..."
fastboot -S 200m flash rootfs system.img
printf '%s\n' "Rebooting the device..."
fastboot reboot
printf '%s\n' "Upgrade completed successfully."
