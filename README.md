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

The code is store-eligible (sandboxed, no private APIs, in-process capture) and
release tooling is wired with **fastlane**. The remaining work is account
setup, not code.

**One-time account steps (manual — only you can do these):**

1. Enroll in the **Apple Developer Program** ($99/yr).
2. In **App Store Connect**, create the app record and register bundle ID
   `com.sandropadin.ScanQRCode`. Add a privacy policy URL and answer App
   Privacy as **"Data Not Collected."**
3. Create a **Mac Installer Distribution** certificate once (Developer portal,
   or Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates). fastlane mints the
   Apple Distribution cert + provisioning profile for you.
4. Create an **App Store Connect API key** (.p8) and export:

   ```bash
   export ASC_KEY_ID=XXXXXXXXXX
   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   export ASC_KEY_PATH="$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
   ```

**Then the whole release is:**

```bash
fastlane release      # certs → build+sign .pkg → upload to App Store Connect
```

or step by step: `fastlane certs`, `fastlane package`, `fastlane upload`.
Submit for review from App Store Connect once the build finishes processing.

The icon is a generated placeholder (`./scripts/make-icon.sh`); replace the
artwork in `Resources/AppIcon-1024.png` (or edit the drawing in that script)
and rebuild before shipping if you want something custom.

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
| `scripts/make-icon.sh` | Generates the placeholder app icon |
| `scripts/make-screenshot.sh` | Generates the App Store screenshot |
| `scripts/package-mas.sh` | Signs + builds the App Store `.pkg` |
| `docs/app-store-listing.md` | Copy/paste listing text + review answers |
| `fastlane/Fastfile` | `certs` / `package` / `upload` / `release` lanes |

## License

MIT.
