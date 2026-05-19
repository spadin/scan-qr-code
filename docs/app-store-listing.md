# App Store Connect — listing content & answers

Copy/paste this into the matching fields. Required items are marked ⚠️.

## App Information (left nav ▸ General ▸ App Information)

- **Category**: Primary `Utilities`, Secondary `Productivity`.
- **Content Rights**: "No, it does not contain, show, or access third-party content."
- **Age Rating**: answer all "None" → rates **4+**.

## Pricing and Availability ⚠️

- **Price**: Free (Tier 0).
- **Availability**: All countries/regions.

## This page (Distribution ▸ 1.0 Prepare for Submission)

### Promotional Text (170 chars, editable without review)

> Scan any QR code on your screen instantly — from the menu bar or a global hotkey. Copies the result, optionally opens links. Powered by Apple Vision.

### Description ⚠️

> Scan Screen QR Code finds and decodes QR codes anywhere on your Mac's screen and copies the result to your clipboard — no phone, no camera, no fiddling.
>
> • Scan the whole screen, or drag to select just a region.
> • Trigger it from the menu bar or assign your own global keyboard shortcuts.
> • Optionally open the link automatically when the code is a URL.
> • Powered by Apple's Vision framework — reads angled, small, and low‑contrast codes, plus Aztec, DataMatrix, and PDF417.
>
> Private by design: capture and detection happen entirely on your Mac. Nothing is uploaded, nothing is stored, no analytics, no account. The app is sandboxed and collects no data.

### Keywords ⚠️ (100 char max)

```
qr,qr code,barcode scanner,screen,vision,clipboard,aztec,datamatrix,pdf417,menu bar,hotkey
```

### Support URL ⚠️ and Marketing URL

A reachable URL is required. Recommended: push this repo to GitHub and use
`https://github.com/spadin/scan-qr-code` (README serves as support page).

### App Previews and Screenshots ⚠️

At least one macOS screenshot at 1280×800 / 1440×900 / 2560×1600 / 2880×1800.
Generated for you: `Resources/screenshot-1440x900.png` — drag it into the
"Mac" well (regenerate/customize via `./scripts/make-screenshot.sh`).

## App Privacy ⚠️ (left nav ▸ App Privacy)

- "Do you or your third-party partners collect data from this app?" → **No**.
  (Capture + detection are local; nothing leaves the device.)
- Result: **Data Not Collected**.

## App Review Information ⚠️ (left nav ▸ App Review)

- **Sign-in required?** No.
- **Contact**: your name / email / phone.
- **Notes to reviewer**:

> Scan Screen QR Code is a menu bar utility that detects QR codes on the user's
> screen locally using Apple's Vision framework. It requires Screen Recording
> permission solely to capture the screen for on-device QR detection. No screen
> content, image, or any other data is transmitted off the device or stored.
> To test: grant Screen Recording when prompted, display any QR code on screen,
> then choose "Scan Screen for QR Code" from the menu bar icon — the decoded
> text is copied to the clipboard and shown in a brief HUD.

## App Accessibility (optional but quick)

Nothing special to declare; the app is keyboard-operable via assignable
shortcuts.
