#!/usr/bin/env bash
# Download one OpenWrt source URL for scripts/download.pl.
# Small objects stay on curl; large objects use aria2c's multi-connection
# downloader. Both modes write only payload bytes to stdout and diagnostics to
# stderr, so download.pl can continue hashing the exact downloaded stream.
set -Eeuo pipefail

url=${1:?"source URL is required"}
threshold=$((10 * 1024 * 1024))

# A HEAD probe is advisory. If a server does not expose Content-Length, keep
# curl as the conservative fallback rather than guessing that the object is
# large or silently downloading it twice.
content_length=$(curl -fsSIL --connect-timeout 15 --max-time 30 "$url" 2>/dev/null \
  | awk 'BEGIN { IGNORECASE=1 } /^content-length:/ { gsub(/[[:space:]]/, "", $2); value=$2 } END { if (value ~ /^[0-9]+$/) print value }' \
  | tail -n 1 || true)

if [[ "$content_length" =~ ^[0-9]+$ ]] && (( content_length >= threshold )); then
  echo "aria2c: ${content_length} bytes: ${url}" >&2
  exec aria2c --stdout=true --stderr=true --console-log-level=warn \
    --summary-interval=0 --download-result=hide --enable-color=false \
    -x8 -s8 -k1M --max-tries=8 --retry-wait=3 \
    --timeout=60 --connect-timeout=20 --follow-torrent=false \
    --allow-overwrite=true --auto-file-renaming=false --no-conf "$url"
fi

echo "curl: ${content_length:-unknown} bytes: ${url}" >&2
exec curl --fail --location --connect-timeout 15 --retry 3 --retry-delay 2 "$url"
