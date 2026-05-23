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
          x: CGFloat, y: CGFloat, rightAlignTo: CGFloat? = nil) {
    let font = CTFontCreateWithName(
        (bold ? "HelveticaNeue-Bold" : "HelveticaNeue") as CFString, size, nil)
    let attr = [kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: col] as CFDictionary
    let line = CTLineCreateWithAttributedString(
        CFAttributedStringCreate(nil, s as CFString, attr)!)
    var drawX = x
    if let edge = rightAlignTo {
        // CTLineGetTypographicBounds returns the advance width.
        drawX = edge - CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }
    ctx.textPosition = CGPoint(x: drawX, y: y)
    CTLineDraw(line, ctx)
}

func textWidth(_ s: String, _ size: CGFloat, _ bold: Bool = false) -> CGFloat {
    let font = CTFontCreateWithName(
        (bold ? "HelveticaNeue-Bold" : "HelveticaNeue") as CFString, size, nil)
    let attr = [kCTFontAttributeName: font] as CFDictionary
    let line = CTLineCreateWithAttributedString(
        CFAttributedStringCreate(nil, s as CFString, attr)!)
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
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

// Mock menu card — approximates a real macOS menu: light gray background
// (≈ NSColor.windowBackgroundColor under vibrancy), thin group separators,
// soft drop shadow, secondary-color shortcuts right-aligned.
//
// Scan-command shortcuts are user-assignable (no defaults), so the first two
// rows show no shortcut; Settings/Quit keep their standard ⌘, / ⌘Q.
// `checked: true` puts a ✓ in the menu's left gutter (real AppKit behavior).
// Labels are indented enough to leave room for that gutter on every row, so
// checked/unchecked rows align visually like a real macOS menu. Groups are
// separated by thin horizontal lines, matching how AppKit collates them.
let groups: [[(label: String, shortcut: String?, checked: Bool)]] = [
    [("Scan Screen for QR Code", nil, false),
     ("Scan Selected Area for QR Code", nil, false)],
    [("Open URL If Found", nil, true)],
    [("Settings…", "⌘ ,", false)],
    [("Quit Scan Screen QR Code", "⌘ Q", false)],
]
let menuX: CGFloat = 130
let menuW: CGFloat = 560
let rowH: CGFloat = 46
let separatorGap: CGFloat = 18
let topPad: CGFloat = 18
let bottomPad: CGFloat = 18
let totalRows = groups.reduce(0) { $0 + $1.count }
let totalSeparators = groups.count - 1
let menuH = topPad + bottomPad + CGFloat(totalRows) * rowH + CGFloat(totalSeparators) * separatorGap
let menu = CGRect(x: menuX, y: 510 - menuH, width: menuW, height: menuH)

// Soft drop shadow under the card.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8),
              blur: 28,
              color: c(0, 0, 0, 0.22))
roundRect(menu, 12, c(0.945, 0.945, 0.955, 1))
ctx.restoreGState()

let labelColor = c(0.12, 0.12, 0.16)
let shortcutColor = c(0.50, 0.50, 0.54)   // ≈ NSColor.secondaryLabelColor, nudged darker for screenshot legibility
let separatorColor = c(0, 0, 0, 0.10)
let fontSize: CGFloat = 26
let gutterX: CGFloat = 22                 // ✓ position from menu's left edge
let labelX: CGFloat = 48                  // text indented past the gutter
let rightPad: CGFloat = 22

// Shortcuts in a real macOS menu share a column: every ⌘ glyph lines up at
// the same x, with the modifier-target ("," or "Q") trailing — i.e. shortcuts
// are LEFT-aligned to a column sized by the widest one.
let maxShortcutWidth = groups.flatMap { $0 }.compactMap { $0.shortcut }
    .map { textWidth($0, fontSize) }.max() ?? 0
let shortcutColumnX = menu.maxX - rightPad - maxShortcutWidth

var rowTopY = menu.maxY - topPad
for (gIdx, group) in groups.enumerated() {
    for item in group {
        // Baseline centered within the row.
        let baseY = rowTopY - rowH * 0.65
        if item.checked {
            text("✓", fontSize, false, labelColor,
                 x: menu.minX + gutterX, y: baseY)
        }
        text(item.label, fontSize, false, labelColor,
             x: menu.minX + labelX, y: baseY)
        if let sc = item.shortcut {
            text(sc, fontSize, false, shortcutColor,
                 x: shortcutColumnX, y: baseY)
        }
        rowTopY -= rowH
    }
    if gIdx < groups.count - 1 {
        let sepY = rowTopY - separatorGap / 2
        ctx.setStrokeColor(separatorColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: menu.minX + 14, y: sepY))
        ctx.addLine(to: CGPoint(x: menu.maxX - 14, y: sepY))
        ctx.strokePath()
        rowTopY -= separatorGap
    }
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
