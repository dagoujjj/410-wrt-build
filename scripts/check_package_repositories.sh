#!/usr/bin/env bash
set -u

base_url='https://downloads.immortalwrt.org/snapshots'
urls=(
  "apk|$base_url/targets/aarch64_generic/packages/packages.adb"
  "apk|$base_url/packages/aarch64_generic/base/packages.adb"
  "apk|$base_url/packages/aarch64_generic/packages/packages.adb"
  "apk|$base_url/packages/aarch64_generic/luci/packages.adb"
  "apk|$base_url/packages/aarch64_generic/routing/packages.adb"
  "apk|$base_url/packages/aarch64_generic/telephony/packages.adb"
  "apk|$base_url/packages/aarch64_generic/video/packages.adb"
  "apk|$base_url/packages/aarch64_generic/openstick/packages.adb"
  "opkg|$base_url/targets/aarch64_generic/packages"
  "opkg|$base_url/packages/aarch64_generic/base"
  "opkg|$base_url/packages/aarch64_generic/packages"
  "opkg|$base_url/packages/aarch64_generic/luci"
  "opkg|$base_url/packages/aarch64_generic/routing"
  "opkg|$base_url/packages/aarch64_generic/telephony"
  "opkg|$base_url/packages/aarch64_generic/video"
  "opkg|$base_url/packages/aarch64_generic/openstick"
)

tmp_error=$(mktemp)
trap 'rm -f "$tmp_error"' EXIT
printf '%s\n' 'manager|url|attempt|http_status|curl_exit|result|error'

for entry in "${urls[@]}"; do
  manager=${entry%%|*}
  url=${entry#*|}
  reachable=0
  for attempt in 1 2 3; do
    : > "$tmp_error"
    http_status=$(curl --fail --location --silent --show-error \
      --connect-timeout 10 --max-time 30 -o /dev/null \
      -w '%{http_code}' "$url" 2>"$tmp_error")
    curl_exit=$?
    error=$(tr '\n' ' ' < "$tmp_error" | sed 's/[[:space:]]\+/ /g; s/[[:space:]]*$//')
    if [ "$curl_exit" -eq 0 ] && [ "$http_status" = 200 ]; then
      result=reachable
      reachable=1
    else
      result=failed
    fi
    printf '%s|%s|%d|%s|%d|%s|%s\n' \
      "$manager" "$url" "$attempt" "$http_status" "$curl_exit" "$result" "$error"
    [ "$reachable" -eq 1 ] && break
  done
  if [ "$reachable" -eq 1 ]; then
    printf '%s\n' "RESULT|$manager|$url|REACHABLE"
  else
    printf '%s\n' "RESULT|$manager|$url|RETIRED_AFTER_3_FAILURES"
  fi
done
