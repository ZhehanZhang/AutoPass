#!/bin/bash
# Renders Resources/AppIcon.svg into Resources/AppIcon.icns (all sizes macOS wants).
# Needs only the Command Line Tools: AppKit renders the SVG, iconutil packs the icns.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/render.swift" <<'SWIFT'
import AppKit
let a = CommandLine.arguments
guard a.count == 4, let image = NSImage(contentsOf: URL(fileURLWithPath: a[1])), let px = Int(a[3]) else { fputs("could not load the SVG\n", stderr); exit(1) }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
image.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
SWIFT
swiftc -O "$WORK/render.swift" -o "$WORK/render"

SET="$WORK/AppIcon.iconset"
mkdir "$SET"
for size in 16 32 128 256 512; do
    "$WORK/render" Resources/AppIcon.svg "$SET/icon_${size}x${size}.png" "$size"
    "$WORK/render" Resources/AppIcon.svg "$SET/icon_${size}x${size}@2x.png" "$((size * 2))"
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
