#!/usr/bin/env bash
#
# Builds a signed Mac App Store installer package (build/ScanQRCode.pkg).
#
# Requires (all from an Apple Developer Program membership):
#   * an "Apple Distribution" code-signing certificate
#   * a "Mac Installer Distribution" / "3rd Party Mac Developer Installer" cert
#   * a Mac App Store provisioning profile for com.sandropadin.ScanQRCode
#
# Identities/profile are auto-detected; override with env vars:
#   DIST_IDENTITY=…  INSTALLER_IDENTITY=…  PROVISIONING_PROFILE=/path.provisionprofile
#   TEAM_ID=…  (otherwise read from the provisioning profile)
#
# This is normally invoked via `fastlane package`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="ScanQRCode"
BUNDLE_ID="com.sandropadin.ScanQRCode"
APP="$ROOT/build/$APP_NAME.app"
PKG="$ROOT/build/$APP_NAME.pkg"

fail() { echo "✗ $1" >&2; exit 1; }

# --- locate signing assets -------------------------------------------------

DIST_IDENTITY="${DIST_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -oE '"Apple Distribution: [^"]+"' | head -1 | tr -d '"')}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-$(security find-identity -v 2>/dev/null \
  | grep -oE '"(3rd Party Mac Developer Installer|Mac Installer Distribution): [^"]+"' \
  | head -1 | tr -d '"')}"
PROFILE="${PROVISIONING_PROFILE:-}"

if [[ -z "$DIST_IDENTITY" || -z "$INSTALLER_IDENTITY" ]]; then
  cat >&2 <<MSG
✗ Distribution signing identities not found.

  Apple Distribution cert:        ${DIST_IDENTITY:-MISSING}
  Mac Installer Distribution cert: ${INSTALLER_IDENTITY:-MISSING}

These come from an Apple Developer Program membership. Once enrolled:
  • run \`fastlane certs\` to create the Apple Distribution cert + profile, and
  • create the "Mac Installer Distribution" cert once in the Developer portal
    (or Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates).
Then re-run this script (or \`fastlane package\`).
MSG
  exit 1
fi

if [[ -z "$PROFILE" || ! -f "$PROFILE" ]]; then
  fail "Set PROVISIONING_PROFILE to the Mac App Store .provisionprofile (\`fastlane certs\` downloads one)."
fi

# --- derive team id + Mac App Store entitlements ---------------------------

DECODED="$(mktemp)"
security cms -D -i "$PROFILE" > "$DECODED" 2>/dev/null || fail "Could not decode provisioning profile."
TEAM_ID="${TEAM_ID:-$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.team-identifier' "$DECODED" 2>/dev/null || true)}"
[[ -n "$TEAM_ID" ]] || fail "Could not determine TEAM_ID (set it explicitly)."

MAS_ENT="$(mktemp -t mas-entitlements).plist"
cp "$ROOT/ScanQRCode.entitlements" "$MAS_ENT"
/usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" "$MAS_ENT" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :com.apple.application-identifier $TEAM_ID.$BUNDLE_ID" "$MAS_ENT"
/usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $TEAM_ID" "$MAS_ENT" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :com.apple.developer.team-identifier $TEAM_ID" "$MAS_ENT"

# --- build, embed profile, re-sign for distribution ------------------------

echo "▸ Building app bundle…"
CODESIGN_IDENTITY="-" ./scripts/build-app.sh >/dev/null   # assemble; we re-sign below

cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

echo "▸ Signing as: $DIST_IDENTITY (team $TEAM_ID)"
# Sign any nested code bundles first, then the app (no --deep for distribution).
shopt -s nullglob
for nested in "$APP"/Contents/MacOS/*.bundle; do
  codesign --force --sign "$DIST_IDENTITY" "$nested"
done
shopt -u nullglob
codesign --force --sign "$DIST_IDENTITY" --entitlements "$MAS_ENT" "$APP"

echo "▸ Verifying signature…"
codesign --verify --strict --verbose=2 "$APP"

echo "▸ Building installer package…"
rm -f "$PKG"
productbuild --component "$APP" /Applications --sign "$INSTALLER_IDENTITY" "$PKG"

rm -f "$DECODED" "$MAS_ENT"
echo "✓ $PKG ready — upload with \`fastlane upload\`."
