# Scan QR Code

A native macOS **menu bar app** that detects QR codes on your screen and copies
the result to your clipboard. Uses Apple's Vision framework for accurate
detection — handles angled, small, and low-contrast codes that simpler
libraries miss. Supports QR, Aztec, DataMatrix, and PDF417.

Inspired by the [Raycast extension of the same name](https://github.com/spadin/raycast-scan-qr-code),
rebuilt as a standalone agent app. Everything runs in-process, in the **App
Sandbox**.

## Install

**[Download on the Mac App Store →](https://apps.apple.com/app/id6770797205)**

Free, sandboxed, and **"Data Not Collected."** macOS 14 (Sonoma) or later.

Prefer to build it yourself? See [Build](#build) below.

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

## Mac App Store releases

The app is **published on the Mac App Store**
([id 6770797205](https://apps.apple.com/app/id6770797205)). It's sandboxed,
uses no private APIs, and captures in-process; release tooling is wired with
**fastlane**.

**Cutting a new version (account + certs already set up):**

```bash
fastlane release      # certs → build+sign .pkg → upload to App Store Connect
```

or step by step: `fastlane certs`, `fastlane package`, `fastlane upload`. Bump
`CFBundleVersion`, update `fastlane/metadata/en-US/release_notes.txt`, then bind
the new build to the version and submit from App Store Connect once it finishes
processing.

<details>
<summary>One-time account setup (already done for this app)</summary>

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

</details>

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
