# Scan QR Code

A native macOS **menu bar app** that detects QR codes on your screen and copies
the result to your clipboard. Uses Apple's Vision framework for accurate
detection — handles angled, small, and low-contrast codes that simpler
libraries miss. Supports QR, Aztec, DataMatrix, and PDF417.

Inspired by the [Raycast extension of the same name](../raycast-scan-qr-code),
rebuilt as a standalone agent app. Everything runs in-process, in the **App
Sandbox**, so it is eligible for the Mac App Store.

## Menu bar actions

Click the menu bar icon (a QR viewfinder) for:

- **Scan Screen for QR Code** — captures the main display, detects any QR code,
  copies the first match to the clipboard, and shows a floating HUD.
- **Scan Selected Area for QR Code** — dims the screen and lets you drag a
  region to scan just that selection. Escape cancels silently.
- **Open URL If Found** — a toggle: when on, a result that is a well-formed
  http(s) URL is opened in your browser (in addition to being copied).

## Global keyboard shortcuts

Both scan actions can be triggered by global hotkeys from anywhere. They are
**unset by default** — open **Settings…** from the menu and record a shortcut
for each. The menu shows the assigned shortcut next to each action.

## How it works

1. **ScreenCaptureKit** captures the display in-process as a `CGImage` — no
   shelling out, no temp files (the region selection uses a custom overlay
   since the sandbox can't invoke the system crosshair).
2. An in-process `VNDetectBarcodesRequest` (Apple Vision) decodes it.
3. The first payload is copied to the clipboard and confirmed with a HUD.

Nothing is written to disk and no screenshot is persisted.

## Permissions

macOS requires **Screen Recording** permission. On the first scan the system
prompts you; grant it in **System Settings ▸ Privacy & Security ▸ Screen
Recording**, then scan again. The build is signed with a stable identity, so
the permission survives rebuilds.

## Requirements

macOS 14 (Sonoma) or later — ScreenCaptureKit's in-process screenshot API.

## Build

Requires the Xcode / Swift toolchain.

```bash
./scripts/build-app.sh          # release build → build/ScanQRCode.app
./scripts/build-app.sh --run    # build, then (re)launch the menu bar app
./scripts/build-app.sh --debug  # faster debug build
```

The build always applies `ScanQRCode.entitlements` (App Sandbox) so local
builds behave like the shipped app. Override the signing identity with
`CODESIGN_IDENTITY=…` (`-` forces ad-hoc). Drop an `AppIcon.icns` into
`Resources/` before building to give the app an icon.

To test the install flow from scratch, fully uninstall first:

```bash
./scripts/uninstall.sh            # quit app, remove .app + sandbox container, reset permission/settings
./scripts/uninstall.sh --purge    # also wipe .build/ and build/ for a cold rebuild
./scripts/uninstall.sh --dry-run  # preview without changing anything
```

### Development

```bash
swift build      # compile the package
swift test       # run the QR-detection + utility tests
```

## Mac App Store submission

The code is store-eligible (sandboxed, no private APIs, in-process capture).
The remaining steps are account/tooling, not code:

1. **Apple Developer Program** membership ($99/yr).
2. In **App Store Connect**, create the app record and bundle ID
   `com.sandropadin.ScanQRCode`.
3. Certificates/profile: an **Apple Distribution** signing certificate, a
   **Mac Installer Distribution** certificate, and a **Mac App Store**
   provisioning profile for the bundle ID.
4. Sign the `.app` with the Apple Distribution cert + embedded provisioning
   profile + `ScanQRCode.entitlements`, build a signed installer with
   `productbuild --component build/ScanQRCode.app /Applications \
   --sign "3rd Party Mac Developer Installer: …" ScanQRCode.pkg`, then upload
   with **Transporter** (or `xcrun altool --upload-app -f ScanQRCode.pkg -t macos`).
5. Submit for review from App Store Connect.

> A SwiftPM-only project can't produce a store `.pkg` from `swift build` alone;
> step 4 needs the distribution cert + provisioning profile in the keychain.
> A thin Xcode project (or `xcodebuild` archive) wrapper makes the
> archive/upload flow turnkey — ask if you want one generated.

## Project layout

| Path | Responsibility |
| --- | --- |
| `Sources/ScanQRCode/Contracts.swift` | Protocol seam; image-based async capture |
| `Sources/ScanQRCode/ScanEngine.swift` | Orchestration: capture → detect → clipboard → feedback |
| `Sources/ScanQRCode/ScreenCapture.swift` | ScreenCaptureKit capture + permission |
| `Sources/ScanQRCode/SelectionOverlay.swift` | Custom drag-to-select region overlay |
| `Sources/ScanQRCode/QRDetector.swift` | In-process Vision barcode detection |
| `Sources/ScanQRCode/MenuBarController.swift` | `NSStatusItem` menu, shortcut display |
| `Sources/ScanQRCode/HotkeyManager.swift` | Global hotkey registration |
| `Sources/ScanQRCode/SettingsWindow.swift` | Shortcut recorder UI |
| `Sources/ScanQRCode/HUDFeedback.swift` | Floating confirmation HUD |
| `Sources/ScanQRCode/Preferences.swift` | UserDefaults-backed toggles |
| `ScanQRCode.entitlements` | App Sandbox entitlement |
| `scripts/build-app.sh` | Assembles + signs the `.app` bundle |

## License

MIT.
