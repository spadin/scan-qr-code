# CLAUDE.md

Guidance for working in this repo. Read alongside `README.md` (user-facing) and
`docs/app-store-listing.md` (store copy/answers).

## What this is

A native macOS **menu bar agent app** that detects QR/Aztec/DataMatrix/PDF417
codes on screen via Apple Vision and copies them to the clipboard. SwiftPM
package; the `.app` bundle is assembled by a script (no `.xcodeproj`).
Re-architected to be **Mac App Store eligible** (sandboxed, in-process capture).

## Commands

```bash
swift build && swift test          # compile + tests (4 tests, keep green)
./scripts/build-app.sh --run       # assemble build/ScanQRCode.app and (re)launch
./scripts/build-app.sh --debug     # faster debug build
./scripts/uninstall.sh [--purge]   # clean slate (TCC + container + prefs)
./scripts/make-icon.sh             # regenerate Resources/AppIcon.icns
./scripts/make-screenshot.sh       # regenerate the App Store screenshot
fastlane certs|package|upload|release   # MAS release (needs paid program + ASC key)
```

## Architecture

`Sources/ScanQRCode/Contracts.swift` is the frozen seam. The pipeline:
`ScanEngine.performScan` → `ScreenCapturing` (async, returns `CGImage`) →
`QRDetecting` → clipboard + `ScanFeedback`. `AppDelegate` injects the concrete
implementations. Capture/detection never touch the main actor work; feedback
does. Don't widen the seam casually — it's deliberately small.

## Non-obvious constraints (don't regress these)

- **Sandbox-safe only.** No shelling out, no temp files, no extra entitlements.
  Capture is `SCScreenshotManager` (ScreenCaptureKit). Reintroducing
  `Process`/`screencapture`/disk I/O breaks App Store eligibility.
- **macOS 14+** minimum (SCScreenshotManager). Keep `Package.swift` and the
  Info.plist `LSMinimumSystemVersion` in sync.
- **Signing → TCC persistence.** Screen Recording permission is keyed to the
  code signature; ad-hoc changes every build. `build-app.sh` auto-detects a
  stable identity (override `CODESIGN_IDENTITY`, `-` = ad-hoc). Always signs
  with `ScanQRCode.entitlements` (App Sandbox).
- **HUD rounding** uses `NSVisualEffectView.maskImage`, not
  `layer.cornerRadius` — a behind-window material ignores layer masking;
  `invalidateShadow()` makes the shadow follow it. See `HUDFeedback.swift`.
- **Hotkeys + menu**: `MenuBarController` is `NSMenuDelegate` and calls
  `KeyboardShortcuts.disable/enable` in `menuWillOpen/menuDidClose` — required,
  or buffered key events fire on menu close.
- **URL auto-open** is intentionally restricted to `http`/`https` (no
  `mailto:`/`tel:`/custom schemes from a scanned code) — see `ScanEngine`.
- **Coordinates**: `ScreenCapture` converts the overlay's global bottom-left
  rect to display-local top-left points for `SCStreamConfiguration.sourceRect`.
  Selection currently targets the **main display only** (known limitation).

## Naming (do not change)

- Public / store / `CFBundleDisplayName`: **"Scan Screen QR Code"**.
- Bundle ID: **`com.sandropadin.ScanQRCode`** — registered, app record tied to
  it. Never change.
- Internal `CFBundleName` / target / executable: `ScanQRCode`.

## Conventions

- Match the existing concise doc-comment style; no ceremony.
- Not on a feature-branch workflow; commit to the working branch. Commit
  messages end with the `Co-Authored-By: Claude Opus 4.7` trailer.
- After UI/string/behavior changes, rebuild via `build-app.sh --run` and keep
  `swift test` green.

## Status / outstanding

See the project memory (`app-store-submission-status`). Summary: code is
store-ready; app record exists (id 6770797205); remaining = website→Support URL
(user, 2026-05-19), Mac Installer Distribution cert + ASC API key + `fastlane`
upload, and a manual runtime scan test (grant Screen Recording, try both scans).
