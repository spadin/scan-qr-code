#!/usr/bin/env bash
#
# Builds ScanQRCode.app — a menu bar agent app — from the Swift package.
#
#   ./scripts/build-app.sh           # release build into ./build/ScanQRCode.app
#   ./scripts/build-app.sh --debug   # debug build (faster compile)
#   ./scripts/build-app.sh --run     # build, then (re)launch the app
#
set -euo pipefail

CONFIG="release"
RUN=0
for arg in "$@"; do
  case "$arg" in
    --debug) CONFIG="debug" ;;
    --run)   RUN=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="ScanQRCode"
BUNDLE_ID="com.sandropadin.ScanQRCode"
APP_DIR="$ROOT/build/$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG"
BUILD_BIN="$(swift build -c "$CONFIG" --show-bin-path)"

echo "▸ Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$BIN_DIR" "$RES_DIR"

cp "$BUILD_BIN/$APP_NAME" "$BIN_DIR/$APP_NAME"

# SwiftPM resource bundles (e.g. KeyboardShortcuts) resolve via Bundle.module
# relative to the executable, so they must sit next to the binary.
shopt -s nullglob
for bundle in "$BUILD_BIN"/*.bundle; do
  cp -R "$bundle" "$BIN_DIR/"
done
shopt -u nullglob

# Optional app icon: drop an AppIcon.icns in Resources/ to use it.
ICON_KEY=""
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"
  ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>Scan QR Code</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
  $ICON_KEY
</dict>
</plist>
PLIST

# TCC (Screen Recording) permission is keyed to the code signature, not the
# bundle ID. Ad-hoc signatures change every rebuild, so the grant never
# persists. Sign with a stable identity (Apple Development / Developer ID) and
# the permission survives rebuilds. Override with CODESIGN_IDENTITY=…; set it
# to "-" to force ad-hoc.
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  IDENTITY="$CODESIGN_IDENTITY"
else
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -oE '"(Apple Development|Developer ID Application): [^"]+"' \
    | head -1 | tr -d '"')"
  IDENTITY="${IDENTITY:--}"
fi

if [[ "$IDENTITY" == "-" ]]; then
  echo "▸ Ad-hoc code signing (no stable identity — permission will re-prompt each build)…"
else
  echo "▸ Code signing as: $IDENTITY"
fi
codesign --force --deep --sign "$IDENTITY" "$APP_DIR" >/dev/null

echo "✓ Built $APP_DIR"

if [[ "$RUN" == "1" ]]; then
  echo "▸ Relaunching…"
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 0.5
  open "$APP_DIR"
  echo "✓ $APP_NAME is running in the menu bar."
fi
