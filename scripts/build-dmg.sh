#!/bin/zsh
# Build a release .dmg with the bundled Ping Island.app's signature intact.
#
# Tauri 2's default resource-bundling step subtly corrupts macOS .app
# subbundle signatures (codesign reports "bundle format is ambiguous").
# We work around it by post-processing: extract the produced .app,
# ditto the pristine vendor copy of Ping Island.app over the broken
# one (ditto preserves xattrs + the existing notarized signature),
# and repackage the .dmg.
#
# Run from the repo root.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

VENDOR_PI="$REPO_ROOT/vendor/Ping Island.app"
DMG_DIR="$REPO_ROOT/src-tauri/target/release/bundle/dmg"
TMP_DIR="$(mktemp -d)"

if [[ ! -d "$VENDOR_PI" ]]; then
  echo "ERROR: $VENDOR_PI not found. Drop the notarized Ping Island.app there first." >&2
  exit 1
fi

echo "==> bun tauri build --bundles dmg"
bun tauri build --bundles dmg

ORIG_DMG="$(ls -1 "$DMG_DIR"/*.dmg | grep -v _fixed | head -1)"
if [[ -z "$ORIG_DMG" ]]; then
  echo "ERROR: no .dmg produced in $DMG_DIR" >&2
  exit 1
fi

echo "==> mounting $ORIG_DMG"
MOUNT_PT="$(hdiutil attach "$ORIG_DMG" -nobrowse | tail -1 | awk '{print $NF}')"

echo "==> extracting opcode.app to $TMP_DIR"
ditto "$MOUNT_PT/opcode.app" "$TMP_DIR/opcode.app"
hdiutil detach "$MOUNT_PT" >/dev/null

BUNDLED_PI="$TMP_DIR/opcode.app/Contents/Resources/_up_/vendor/Ping Island.app"
echo "==> overwriting bundled Ping Island.app via ditto"
rm -rf "$BUNDLED_PI"
ditto "$VENDOR_PI" "$BUNDLED_PI"

echo "==> verifying signature"
codesign --verify --deep "$BUNDLED_PI"
spctl -a -t exec -vv "$BUNDLED_PI" || true

FIXED_DMG="${ORIG_DMG%.dmg}_fixed.dmg"
echo "==> repackaging into $FIXED_DMG"
rm -f "$FIXED_DMG"
hdiutil create -volname "opcode" -srcfolder "$TMP_DIR/opcode.app" -ov -format UDZO "$FIXED_DMG" >/dev/null

echo "==> cleanup"
rm -rf "$TMP_DIR"

ls -lh "$FIXED_DMG"
echo "Done. Distribute: $FIXED_DMG"
