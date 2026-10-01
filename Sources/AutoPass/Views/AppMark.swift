import SwiftUI
import AppKit

// The AutoPass mark: two rows of three code dots over a key. The same drawing as `Resources/AppMark.svg` and the app
// icon, in a 264 x 264 box. All three rows are as tall as a dot and the gaps between them are equal, so it reads as a
// 3 x 3 grid whose last row is a key. The key is as heavy as a row of dots, and it is one filled shape (not strokes that
// overlap), so it stays even when it's drawn faint.

enum MarkGeometry {
    static let width: CGFloat = 264
    static let height: CGFloat = 264
    static let dotRadius: CGFloat = 32
    static let dotColumns: [CGFloat] = [32, 132, 232]
    static let dotRows: [CGFloat] = [32, 132]

    /// Where dot `i` is, row by row, left to right.
    static func dot(_ i: Int) -> (x: CGFloat, y: CGFloat) { (dotColumns[i % 3], dotRows[i / 3]) }

    /// The key: a ring as big as a dot with a small hole, a thick shaft, and two teeth, the last one flush with the end.
    static let key: CGPath = {
        let y: CGFloat = 232
        let ring = CGPath(ellipseIn: CGRect(x: 0, y: y - 32, width: 64, height: 64), transform: nil)
        let hole = CGPath(ellipseIn: CGRect(x: 22, y: y - 10, width: 20, height: 20), transform: nil)
        // The shaft sits a little above the ring's center so the teeth have room under it inside the row's height.
        let shaft = CGPath(roundedRect: CGRect(x: 52, y: 212, width: 212, height: 28), cornerWidth: 14, cornerHeight: 14, transform: nil)
        let joint = CGPath(rect: CGRect(x: 50, y: 212, width: 40, height: 28), transform: nil)       // squares off the join with the ring
        func tooth(_ x: CGFloat, top: CGFloat) -> CGPath {
            CGPath(roundedRect: CGRect(x: x, y: top, width: 30, height: 264 - top), cornerWidth: 12, cornerHeight: 12, transform: nil)
        }
        // The last tooth runs up to the top of the shaft, so the end of the key is one straight edge.
        return ring.union(shaft).union(joint).union(tooth(182, top: 226)).union(tooth(234, top: 212)).subtracting(hole)
    }()
}

/// The mark as a view. It takes the surrounding foreground style, so it can be white on a tinted disc, tinted on clear
/// glass, or follow a sidebar row.
struct AppMark: View {
    /// How many of the six code dots are solid. The rest are faint, like empty boxes waiting for the code.
    var filled = 6
    /// How faint the empty dots are.
    var dim = 0.35

    var body: some View {
        GeometryReader { geo in
            let g = MarkGeometry.self
            let u = min(geo.size.width / g.width, geo.size.height / g.height)
            ZStack(alignment: .topLeading) {
                ForEach(0..<6, id: \.self) { i in
                    let d = g.dot(i)
                    Circle()
                        .frame(width: g.dotRadius * 2 * u, height: g.dotRadius * 2 * u)
                        .offset(x: (d.x - g.dotRadius) * u, y: (d.y - g.dotRadius) * u)
                        .opacity(i < filled ? 1 : dim)
                        .animation(.smooth(duration: 0.2).delay(Double(i) * 0.03), value: filled)
                }
                MarkKey()
            }
            .frame(width: g.width * u, height: g.height * u, alignment: .topLeading)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(MarkGeometry.width / MarkGeometry.height, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct MarkKey: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / MarkGeometry.width
        let transform = CGAffineTransform(scaleX: s, y: s).concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return Path(MarkGeometry.key).applying(transform)
    }
}

/// The mark as an image, for places that need an `NSImage` (the menu bar). Drawn directly, so it stays crisp at any
/// scale and doesn't depend on symbol rendering.
enum MarkImage {
    /// - Parameters:
    ///   - height: in points; the image is square.
    ///   - dotAlpha: how solid the dots are (1 is solid; less reads as "pending").
    ///   - alpha: the whole mark's opacity.
    ///   - badge: a small dot in the top right corner, for "needs attention". The mark shrinks a little to make room.
    static func image(height: CGFloat, dotAlpha: CGFloat = 1, alpha: CGFloat = 1, badge: Bool = false, label: String) -> NSImage {
        let image = NSImage(size: NSSize(width: height, height: height), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let g = MarkGeometry.self
            let s = min(rect.width / g.width, rect.height / g.height) * (badge ? 0.82 : 1)
            context.saveGState()
            // Design units have y pointing down; the mark sits bottom left when there's a badge, otherwise centered.
            let inset = badge ? CGFloat(0) : (rect.width - g.width * s) / 2
            context.translateBy(x: inset, y: (badge ? 0 : (rect.height - g.height * s) / 2) + g.height * s)
            context.scaleBy(x: s, y: -s)

            context.setFillColor(NSColor.black.withAlphaComponent(alpha * dotAlpha).cgColor)
            for i in 0..<6 {
                let d = g.dot(i)
                context.fillEllipse(in: CGRect(x: d.x - g.dotRadius, y: d.y - g.dotRadius, width: g.dotRadius * 2, height: g.dotRadius * 2))
            }
            context.setFillColor(NSColor.black.withAlphaComponent(alpha).cgColor)
            context.addPath(g.key)
            context.fillPath()
            context.restoreGState()

            if badge {
                let r = rect.width * 0.17
                context.setFillColor(NSColor.black.cgColor)
                context.fillEllipse(in: CGRect(x: rect.maxX - 2 * r, y: rect.maxY - 2 * r, width: 2 * r, height: 2 * r))
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = label
        return image
    }
}
