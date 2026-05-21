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

# APP_NAME is the internal name: scheme, target, executable, CFBundleName.
# APP_DISPLAY_NAME is the .app bundle's filename — what Finder / the
# Applications folder show the user. They are deliberately different.
APP_NAME="ScanQRCode"
APP_DISPLAY_NAME="Scan Screen QR Code"
BUNDLE_ID="com.sandropadin.ScanQRCode"
APP_DIR="$ROOT/build/$APP_DISPLAY_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

# Build with Xcode's build engine — it operates directly on Package.swift (no
# .xcodeproj needed). Unlike `swift build`, this emits a Bundle.module accessor
# whose candidate list includes Bundle.main.resourceURL, so SwiftPM resource
# bundles (KeyboardShortcuts) resolve from Contents/Resources/ — the only
# bundle layout valid for a code-signed, App Store-eligible .app.
case "$CONFIG" in
  release) XC_CONFIG="Release" ;;
  debug)   XC_CONFIG="Debug" ;;
esac
echo "▸ Building ($XC_CONFIG)…"
xcodebuild -scheme "$APP_NAME" -configuration "$XC_CONFIG" \
  -derivedDataPath "$ROOT/.xcbuild" -destination 'platform=macOS' -quiet build
BUILD_BIN="$ROOT/.xcbuild/Build/Products/$XC_CONFIG"

echo "▸ Assembling $APP_DISPLAY_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$BIN_DIR" "$RES_DIR"

cp "$BUILD_BIN/$APP_NAME" "$BIN_DIR/$APP_NAME"

# SwiftPM resource bundles (e.g. KeyboardShortcuts) resolve via Bundle.module
# from Bundle.main.resourceURL, so they must sit in Contents/Resources/.
shopt -s nullglob
for bundle in "$BUILD_BIN"/*.bundle; do
  cp -R "$bundle" "$RES_DIR/"
done
shopt -u nullglob

# Optional app icon: drop an AppIcon.icns in Resources/ to use it.
ICON_KEY=""
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"
  ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

# Build metadata Xcode normally injects. A SwiftPM build has no Xcode project,
# so these are derived from the toolchain here. App Store Connect validates the
# binary against them — an incomplete Info.plist makes processing silently
# reject the build (it never appears in TestFlight).
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
SDK_BUILD="$(xcrun --sdk macosx --show-sdk-build-version)"
OS_BUILD="$(sw_vers -buildVersion)"
XCODE_RAW="$(xcodebuild -version 2>/dev/null || true)"
XCODE_BUILD="$(awk '/^Build version/ {print $3}' <<<"$XCODE_RAW")"
# DTXcode: 2-digit major, 1-digit minor, 1-digit patch (e.g. 26.4.1 -> 2641).
DTXCODE="$(awk '/^Xcode/ {print $2}' <<<"$XCODE_RAW" | awk -F. '{printf "%02d%d%d", $1, $2, $3}')"

# CFBundleVersion must increase with every upload — Apple rejects duplicates.
BUILD_NUMBER="${BUILD_NUMBER:-2}"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>Scan Screen QR Code</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>ITSAppUsesNonExemptEncryption</key><false/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
  <key>DTCompiler</key><string>com.apple.compilers.llvm.clang.1_0</string>
  <key>DTPlatformName</key><string>macosx</string>
  <key>DTPlatformVersion</key><string>$SDK_VERSION</string>
  <key>DTPlatformBuild</key><string>$SDK_BUILD</string>
  <key>DTSDKName</key><string>macosx$SDK_VERSION</string>
  <key>DTSDKBuild</key><string>$SDK_BUILD</string>
  <key>DTXcode</key><string>$DTXCODE</string>
  <key>DTXcodeBuild</key><string>$XCODE_BUILD</string>
  <key>BuildMachineOSBuild</key><string>$OS_BUILD</string>
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
# The App Sandbox entitlement is required for the Mac App Store and is applied
# even for local dev builds so behavior matches the shipped app.
ENTITLEMENTS="$ROOT/ScanQRCode.entitlements"
codesign --force --deep --sign "$IDENTITY" \
  --entitlements "$ENTITLEMENTS" "$APP_DIR" >/dev/null

echo "✓ Built $APP_DIR"

if [[ "$RUN" == "1" ]]; then
  echo "▸ Relaunching…"
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 0.5
  open "$APP_DIR"
  echo "✓ $APP_DISPLAY_NAME is running in the menu bar."
fi
