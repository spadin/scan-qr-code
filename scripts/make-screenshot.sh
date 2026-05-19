#!/usr/bin/env bash
#
# Generates the required App Store screenshot (1440×900, no alpha) — a clean
# marketing hero showing the icon, name, the menu, and the result HUD.
# Edit the drawing below to customize.
#
#   ./scripts/make-screenshot.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RES="$ROOT/Resources"
OUT="$RES/screenshot-1440x900.png"
ICON="$RES/AppIcon-1024.png"
[[ -f "$ICON" ]] || { echo "Run ./scripts/make-icon.sh first." >&2; exit 1; }

SWIFT_SRC="$(mktemp -t make-shot).swift"
cat > "$SWIFT_SRC" <<'SWIFT'
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import Foundation

let W: CGFloat = 1440, H: CGFloat = 900
let iconPath = CommandLine.arguments[1]
let out = URL(fileURLWithPath: CommandLine.arguments[2])
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// Brand gradient background.
let grad = CGGradient(colorsSpace: cs,
    colors: [c(0.29, 0.31, 0.88), c(0.13, 0.14, 0.42)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H),
                       end: CGPoint(x: 0, y: 0), options: [])

func text(_ s: String, _ size: CGFloat, _ bold: Bool, _ col: CGColor,
          x: CGFloat, y: CGFloat) {
    let font = CTFontCreateWithName(
        (bold ? "HelveticaNeue-Bold" : "HelveticaNeue") as CFString, size, nil)
    let attr = [kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: col] as CFDictionary
    let line = CTLineCreateWithAttributedString(
        CFAttributedStringCreate(nil, s as CFString, attr)!)
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, ctx)
}

func roundRect(_ r: CGRect, _ rad: CGFloat, _ fill: CGColor) {
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad,
                        transform: nil))
    ctx.setFillColor(fill); ctx.fillPath()
}

// App icon.
if let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: iconPath) as CFURL, nil),
   let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
    ctx.draw(img, in: CGRect(x: 130, y: H - 130 - 300, width: 300, height: 300))
}

let white = c(1, 1, 1)
text("Scan Screen QR Code", 70, true, white, x: 470, y: H - 235)
text("QR codes on your screen → your clipboard.", 34, false,
     c(1, 1, 1, 0.85), x: 472, y: H - 290)

// Mock menu card.
let menu = CGRect(x: 130, y: 150, width: 560, height: 360)
roundRect(menu, 22, c(1, 1, 1, 0.97))
let items = ["Scan Screen for QR Code        ⌥⌘1",
             "Scan Selected Area for QR Code ⌥⌘2",
             "✓ Open URL If Found",
             "Settings…                          ⌘,",
             "Quit Scan Screen QR Code           ⌘Q"]
for (i, it) in items.enumerated() {
    text(it, 27, false, c(0.12, 0.12, 0.16),
         x: menu.minX + 36, y: menu.maxY - 70 - CGFloat(i) * 58)
}

// Result HUD pill.
let hud = CGRect(x: 760, y: 360, width: 540, height: 110)
roundRect(hud, 24, c(0.10, 0.10, 0.14, 0.96))
text("✓", 34, true, c(0.45, 0.85, 0.55), x: hud.minX + 34, y: hud.midY - 14)
text("Copied: https://example.com", 28, false, white,
     x: hud.minX + 78, y: hud.midY - 12)

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(
          out as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("render failed") }
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
SWIFT

echo "▸ Rendering screenshot…"
swift "$SWIFT_SRC" "$ICON" "$OUT"
rm -f "$SWIFT_SRC"
echo "✓ Wrote $OUT"
