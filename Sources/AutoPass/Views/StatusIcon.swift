import SwiftUI
import AppKit

// MARK: Compatibility
//
// The interface uses current APIs where they exist and falls back below them. The only thing that differs without
// Liquid Glass (before macOS 26) is the glass itself: sizes, shapes, layout and everything else stay the same. Symbol
// effects and the mesh backdrop follow their own minimum versions (26, 15, 14).
// `AUTOPASS_LEGACY_UI=1` turns glass off on a current system so that look can be checked.

enum Compat {
    static let noGlass = ProcessInfo.processInfo.environment["AUTOPASS_LEGACY_UI"] != nil
}

// MARK: Status icon (in the app)

/// The AutoPass mark on a Liquid Glass disc. States that have something to say tint the disc and draw the mark in
/// white; quiet states are clear glass with a tinted mark. The code dots fill in as a code is typed, and a small badge
/// 
struct StatusIcon: View {
    let status: EngineStatus
    var size: CGFloat = 92

    var body: some View {
        StatusMark(status: status)
            .foregroundStyle(status.isLoud ? Color.white : status.markColor)
            .frame(width: size * 0.5)
            .frame(width: size, height: size)
            .modifier(StatusDisc(tint: status.isLoud ? status.tint : nil))
            .modifier(PairedBounce(trigger: status.isPaired))
            .animation(.smooth(duration: 0.35), value: status)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(status.summary)
    }
}

/// The mark, with its dots filled for the state. While AutoPass is working they fill one after another, like a code
/// being typed. That's the only thing that animates continuously, and only while it's working.
private struct StatusMark: View {
    let status: EngineStatus

    var body: some View {
        if status.isWorking {
            TimelineView(.periodic(from: .now, by: 0.16)) { context in
                AppMark(filled: min(Int(context.date.timeIntervalSinceReferenceDate / 0.16) % 8, 6))
            }
        } else {
            AppMark(filled: status.isPaired ? 6 : 0)
        }
    }
}

/// One small bounce when pairing completes.
private struct PairedBounce: ViewModifier {
    let trigger: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.08, duration: 0.15)
            SpringKeyframe(1.0, spring: .bouncy)
        }
    }
}

/// Liquid Glass disc on macOS 26+; a tinted disc with a soft rim before that.
private struct StatusDisc: ViewModifier {
    let tint: Color?

    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !Compat.noGlass {
            content.glassEffect(.regular.tint(tint), in: .circle)
        } else {
            content.background {
                Circle().fill(tint ?? Color(nsColor: .textBackgroundColor).opacity(0.75))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            }
        }
    }
}

/// A small status disc for a browser row, drawn over the corner of its app icon.
struct StatusBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 15

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size))
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.white, tint)
            .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).padding(1))
            .contentTransition(.symbolEffect(.replace))
    }
}

// MARK: Status icon (menu bar)

enum MenuBarIcon {
    /// The AutoPass mark, plain: a template image with no color, so the menu bar draws it in its own light or dark
    /// appearance. Solid when AutoPass is done (paired). While something is pending the dots are fainter than the key.
    /// Idle or paused it's all faint, and it carries a small dot when it needs you.
    static func image(for status: EngineStatus) -> NSImage {
        let label = status.short
        switch status {
        case .paired:
            return MarkImage.image(height: height, label: label)
        case .needsAccessibility, .attention:
            return MarkImage.image(height: height, dotAlpha: pending, badge: true, label: label)
        case .awaitingApproval, .openingPopup, .typing, .watching, .waiting:
            return MarkImage.image(height: height, dotAlpha: pending, label: label)
        case .idle, .paused:
            return MarkImage.image(height: height, alpha: 0.45, label: label)
        }
    }

    /// The dots' opacity while something is pending.
    private static let pending: CGFloat = 0.4
    /// Menu bar icons are about this tall.
    private static let height: CGFloat = 16
}
