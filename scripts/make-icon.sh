#!/usr/bin/env bash
#
# Generates a clean placeholder app icon (QR finder-pattern motif on an indigo
# macOS squircle) and assembles Resources/AppIcon.icns + the 1024 marketing
# PNG. Replace the artwork later by editing the drawing below or dropping your
# own master into Resources/AppIcon-1024.png and re-running the assembly.
#
#   ./scripts/make-icon.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RES="$ROOT/Resources"
mkdir -p "$RES"

MASTER="$RES/AppIcon-1024.png"
SWIFT_SRC="$(mktemp -t make-icon).swift"

cat > "$SWIFT_SRC" <<'SWIFT'
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let S: CGFloat = 1024
let out = URL(fileURLWithPath: CommandLine.arguments[1])

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
    bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// Transparent canvas; the squircle leaves macOS-standard padding.
let pad: CGFloat = 100
let box = CGRect(x: pad, y: pad, width: S - pad * 2, height: S - pad * 2)
let radius = box.width * 0.2237

func squirclePath(_ rect: CGRect, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

// Soft drop shadow under the icon shape.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40,
              color: color(0, 0, 0, 0.35))
ctx.addPath(squirclePath(box, radius))
ctx.setFillColor(color(0.30, 0.34, 0.95))
ctx.fillPath()
ctx.restoreGState()

// Vertical gradient fill, clipped to the squircle.
ctx.saveGState()
ctx.addPath(squirclePath(box, radius))
ctx.clip()
let grad = CGGradient(
    colorsSpace: cs,
    colors: [color(0.42, 0.46, 1.0), color(0.18, 0.19, 0.55)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: box.maxY),
                       end: CGPoint(x: 0, y: box.minY), options: [])
ctx.restoreGState()

// QR finder patterns (the three corner eyes) + a few modules, in white.
ctx.setFillColor(color(1, 1, 1, 1))
let white = color(1, 1, 1, 1)

func finder(at p: CGPoint, size: CGFloat) {
    let outer = CGRect(x: p.x, y: p.y, width: size, height: size)
    let lw = size * 0.16
    let ir = size * 0.18
    ctx.addPath(CGPath(roundedRect: outer, cornerWidth: ir, cornerHeight: ir, transform: nil))
    ctx.setStrokeColor(white)
    ctx.setLineWidth(lw)
    ctx.strokePath()
    let innerInset = size * 0.30
    let inner = outer.insetBy(dx: innerInset, dy: innerInset)
    ctx.addPath(CGPath(roundedRect: inner, cornerWidth: size * 0.10,
                       cornerHeight: size * 0.10, transform: nil))
    ctx.setFillColor(white)
    ctx.fillPath()
}

let art = box.insetBy(dx: box.width * 0.20, dy: box.height * 0.20)
let fSize = art.width * 0.40
finder(at: CGPoint(x: art.minX, y: art.maxY - fSize), size: fSize)            // top-left
finder(at: CGPoint(x: art.maxX - fSize, y: art.maxY - fSize), size: fSize)    // top-right
finder(at: CGPoint(x: art.minX, y: art.minY), size: fSize)                    // bottom-left

// Scattered data modules for QR texture (deterministic).
let m = fSize * 0.22
for (cx, cy) in [(0.72, 0.34), (0.84, 0.46), (0.62, 0.20),
                 (0.80, 0.20), (0.72, 0.46), (0.92, 0.30)] {
    let r = CGRect(x: art.minX + art.width * CGFloat(cx),
                   y: art.minY + art.height * CGFloat(cy),
                   width: m, height: m)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: m * 0.2,
                       cornerHeight: m * 0.2, transform: nil))
    ctx.setFillColor(white)
    ctx.fillPath()
}

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(
          out as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("render failed") }
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
SWIFT

echo "▸ Rendering master icon…"
swift "$SWIFT_SRC" "$MASTER"
rm -f "$SWIFT_SRC"

echo "▸ Building AppIcon.iconset…"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
gen() { sips -z "$2" "$2" "$MASTER" --out "$ICONSET/$1" >/dev/null; }
gen icon_16x16.png 16
gen icon_16x16@2x.png 32
gen icon_32x32.png 32
gen icon_32x32@2x.png 64
gen icon_128x128.png 128
gen icon_128x128@2x.png 256
gen icon_256x256.png 256
gen icon_256x256@2x.png 512
gen icon_512x512.png 512
cp "$MASTER" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$RES/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

echo "✓ Wrote $RES/AppIcon.icns and $MASTER (1024 marketing icon)"
