#!/usr/bin/env bash
set -Eeuo pipefail

upstream_dir=${1:-}
test -n "$upstream_dir" || {
    echo "Usage: $0 <upstream-source-directory>" >&2
    exit 2
}
test -f "$upstream_dir/include/feeds.mk"
test -f tests/package_repository_generation/expected_apk_repositories.list
test -f tests/package_repository_generation/expected_opkg_distfeeds.conf

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
mkdir -p "$work_dir/openwrt"
cp "$upstream_dir/include/feeds.mk" "$work_dir/openwrt/feeds.mk"
sed -i 's#%U/targets/%S#%U/targets/aarch64_generic#g' "$work_dir/openwrt/feeds.mk"

python3 - "$work_dir/openwrt/feeds.mk" <<'PY'
from pathlib import Path
import sys

feed_file = Path(sys.argv[1])
text = feed_file.read_text()
removals = {
    "FeedSourcesAppendAPK": "echo '%U/targets/aarch64_generic/packages/packages.adb';",
    "FeedSourcesAppendOPKG": "echo 'src/gz %d_core %U/targets/aarch64_generic/packages';",
}
for definition, unavailable in removals.items():
    start = text.index(f"define {definition}")
    end = text.index("endef", start)
    block = text[start:end]
    if unavailable in block:
        block = block.replace(unavailable, "", 1)
    text = text[:start] + block + text[end:]
feed_file.write_text(text)
PY

cat > "$work_dir/Makefile" <<'MAKEFILE'
TOPDIR:=$(CURDIR)
CONFIG_PER_FEED_REPO:=y
CONFIG_FEED_packages:=y
CONFIG_FEED_luci:=y
CONFIG_FEED_routing:=y
CONFIG_FEED_telephony:=y
CONFIG_FEED_video:=
CONFIG_FEED_openstick:=
ARCH_PACKAGES:=aarch64_generic
include $(TOPDIR)/openwrt/feeds.mk
FEEDS_AVAILABLE:=packages luci routing telephony video openstick
all: apk opkg
apk:
	$(call FeedSourcesAppendAPK,$(CURDIR)/apk.list)
opkg:
	$(call FeedSourcesAppendOPKG,$(CURDIR)/opkg.list)
MAKEFILE
make -s -C "$work_dir" all

sed -e 's#%U#https://downloads.immortalwrt.org/snapshots#g' \
    -e 's#%A#aarch64_generic#g' \
    -e 's#%S#msm89xx/msm8916#g' \
    "$work_dir/apk.list" \
  | grep -Ev '^(#|[[:space:]]*$)' \
  | sort > "$work_dir/actual_apk.list"
sed -e 's#%U#https://downloads.immortalwrt.org/snapshots#g' \
    -e 's#%A#aarch64_generic#g' \
    -e 's#%S#msm89xx/msm8916#g' \
    -e 's#%d#immortalwrt#g' \
    "$work_dir/opkg.list" \
  | awk '$1 == "src/gz" { print }' \
  | sort > "$work_dir/actual_opkg.conf"

diff -u tests/package_repository_generation/expected_apk_repositories.list "$work_dir/actual_apk.list"
diff -u tests/package_repository_generation/expected_opkg_distfeeds.conf "$work_dir/actual_opkg.conf"
cat "$work_dir/actual_apk.list"
cat "$work_dir/actual_opkg.conf"
