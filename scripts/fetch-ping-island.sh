#!/bin/zsh
# Download the notarized Ping Island.app from upstream releases
# into ./vendor/. Run this once before `bun tauri build`.
#
# Why not commit the .app: it's 13MB binary + Apache 2.0 redistribution
# attribution easier with a fetch script than vendored blobs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor"
PI_VERSION="${PI_VERSION:-v0.8.1}"
ZIP_NAME="PingIsland-${PI_VERSION#v}.zip"
URL_PRIMARY="https://github.com/erha19/ping-island/releases/download/${PI_VERSION}/${ZIP_NAME}"
URL_MIRROR="https://gh-proxy.com/${URL_PRIMARY}"

mkdir -p "$VENDOR_DIR"
cd "$VENDOR_DIR"

if [[ -d "Ping Island.app" ]]; then
  echo "vendor/Ping Island.app already exists; skipping fetch."
  exit 0
fi

echo "==> Downloading $ZIP_NAME"
if ! curl -fL --connect-timeout 10 --max-time 180 -o "$ZIP_NAME" "$URL_PRIMARY"; then
  echo "  primary failed; trying mirror"
  curl -fL --connect-timeout 10 --max-time 180 -o "$ZIP_NAME" "$URL_MIRROR"
fi

echo "==> Extracting"
unzip -q "$ZIP_NAME"
rm -f "$ZIP_NAME"

# Strip macOS quarantine flag so codesign verification passes.
xattr -cr "Ping Island.app" 2>/dev/null || true

echo "Done. Ping Island.app ready at $VENDOR_DIR/Ping Island.app"
