#!/usr/bin/env bash
#
# Uninstalls ScanQRCode so you can test the install flow from scratch.
#
#   ./scripts/uninstall.sh           # quit app, remove .app, reset permission + settings
#   ./scripts/uninstall.sh --purge   # also delete .build/ and build/ for a cold rebuild
#   ./scripts/uninstall.sh --dry-run # print what would happen, change nothing
#
# Removes only this app's artifacts:
#   * the running process
#   * build/ScanQRCode.app (and /Applications/ScanQRCode.app if present)
#   * its Screen Recording (TCC) grant   -> first scan re-prompts
#   * its stored hotkeys / preferences    -> Settings starts blank
#
set -euo pipefail

APP_NAME="ScanQRCode"
BUNDLE_ID="com.sandropadin.ScanQRCode"

PURGE=0
DRY=0
for arg in "$@"; do
  case "$arg" in
    --purge)   PURGE=1 ;;
    --dry-run) DRY=1 ;;
    *) echo "unknown option: ${arg}" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

run() {
  if [[ "${DRY}" == "1" ]]; then
    echo "  would run: $*"
  else
    "$@"
  fi
}

echo "==> Quitting ${APP_NAME} ..."
if pgrep -x "${APP_NAME}" >/dev/null; then
  run pkill -x "${APP_NAME}" || true
  [[ "${DRY}" == "1" ]] || sleep 0.5
else
  echo "  (not running)"
fi

echo "==> Removing app bundle(s) ..."
for app in "${ROOT}/build/${APP_NAME}.app" "/Applications/${APP_NAME}.app"; do
  if [[ -d "${app}" ]]; then
    echo "  ${app}"
    run rm -rf "${app}"
  fi
done

echo "==> Resetting Screen Recording permission ..."
# Per-app reset; if the OS rejects the targeted form, fall back to a global
# ScreenCapture reset (affects all apps' screen-recording prompts).
if [[ "${DRY}" == "1" ]]; then
  echo "  would run: tccutil reset ScreenCapture ${BUNDLE_ID}"
else
  tccutil reset ScreenCapture "${BUNDLE_ID}" 2>/dev/null \
    || tccutil reset ScreenCapture 2>/dev/null \
    || echo "  (could not reset via tccutil -- remove it manually in System Settings if needed)"
fi

echo "==> Clearing stored hotkeys / preferences ..."
run defaults delete "${BUNDLE_ID}" 2>/dev/null || echo "  (no preferences found)"

echo "==> Removing sandbox container ..."
CONTAINER="${HOME}/Library/Containers/${BUNDLE_ID}"
if [[ -d "${CONTAINER}" ]]; then
  run rm -rf "${CONTAINER}"
else
  echo "  (no container found)"
fi

if [[ "${PURGE}" == "1" ]]; then
  echo "==> Purging build artifacts ..."
  run rm -rf "${ROOT}/.build" "${ROOT}/build"
fi

echo "Uninstalled. Reinstall with: ./scripts/build-app.sh --run"
[[ "${DRY}" == "1" ]] && echo "  (dry run -- nothing was changed)"
exit 0
