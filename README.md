# Scan QR Code

A native macOS **menu bar app** that detects QR codes on your screen and copies
the result to your clipboard. Uses Apple's Vision framework for accurate
detection — handles angled, small, and low-contrast codes that simpler
libraries miss. Supports QR, Aztec, DataMatrix, and PDF417.

Inspired by the [Raycast extension of the same name](../raycast-scan-qr-code),
rebuilt as a standalone, dependency-free agent app (no Raycast required). Vision
detection runs in-process, so there is no bundled external binary.

## Menu bar actions

Click the menu bar icon (a QR viewfinder) for:

- **Scan Screen for QR Code** — silently captures the whole screen, detects any
  QR code, copies the first match to the clipboard, and shows a floating HUD.
- **Scan Selected Area for QR Code** — opens the macOS crosshair so you can draw
  a region, then scans just that selection. Pressing Escape cancels silently.

## Global keyboard shortcuts

Both actions can be triggered by global hotkeys from anywhere. They are **unset
by default** — open **Settings…** from the menu and record a shortcut for each
action. Shortcuts are stored by macOS and persist across launches.

## How it works

1. `/usr/sbin/screencapture -x` (full screen) or `-x -i` (region) writes a
   lossless PNG to a temp file.
2. An in-process `VNDetectBarcodesRequest` (Apple Vision) decodes it.
3. The first payload is copied to the clipboard and confirmed with a HUD.

The screenshot is deleted immediately after detection and never persisted.

## Permissions

macOS requires **Screen Recording** permission for any screen capture. On the
first scan the system prompts you; grant it in **System Settings ▸ Privacy &
Security ▸ Screen Recording**, then scan again. The app is ad-hoc signed with a
stable bundle identifier (`com.spadin.ScanQRCode`), so the permission survives
rebuilds.

## Build

Requires Xcode / Swift toolchain (Swift 5.9+).

```bash
./scripts/build-app.sh          # release build → build/ScanQRCode.app
./scripts/build-app.sh --run    # build, then (re)launch the menu bar app
./scripts/build-app.sh --debug  # faster debug build
```

To put an icon on the app, drop an `AppIcon.icns` into `Resources/` before
building.

### Development

```bash
swift build      # compile the package
swift test       # run the QR-detection + utility tests
```

## Project layout

| Path | Responsibility |
| --- | --- |
| `Sources/ScanQRCode/Contracts.swift` | Protocol seam between the feature areas |
| `Sources/ScanQRCode/ScanEngine.swift` | Orchestration: capture → detect → clipboard → feedback |
| `Sources/ScanQRCode/ScreenCapture.swift` | `screencapture` + Screen Recording permission |
| `Sources/ScanQRCode/QRDetector.swift` | In-process Vision barcode detection |
| `Sources/ScanQRCode/MenuBarController.swift` | `NSStatusItem` menu |
| `Sources/ScanQRCode/HotkeyManager.swift` | Global hotkey registration |
| `Sources/ScanQRCode/SettingsWindow.swift` | Shortcut recorder UI |
| `Sources/ScanQRCode/HUDFeedback.swift` | Floating confirmation HUD |
| `scripts/build-app.sh` | Assembles + signs the `.app` bundle |

## License

MIT.
