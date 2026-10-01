import Cocoa
import CoreGraphics

enum Input {
    /// Seconds since the user last pressed a key, clicked, or scrolled.
    static func idleSeconds() -> Double {
        let types: [CGEventType] = [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        return types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? 0
    }

    /// Seconds since the last real keystroke. Used to avoid typing over the user; clicks don't count.
    static func keyboardIdleSeconds() -> Double {
        [CGEventType.keyDown, .flagsChanged].map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? 0
    }

    static func mouseButtonDown() -> Bool {
        CGEventSource.buttonState(.combinedSessionState, button: .left)
    }

    /// Running count of key-down events from real input; used to notice a physical keystroke mid-typing.
    static func keyDownCount() -> UInt32 {
        CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
    }
}

/// Delivers digits straight to one process (`postToPid`). Nothing goes through the system-wide event
/// stream, so a different app that happens to be frontmost can never receive them, and the
/// clipboard is never touched.
enum KeyInjector {
    fileprivate static func digitKeyCode(_ digit: Character) -> CGKeyCode? { digitKeyCodes[digit] }

    private static let digitKeyCodes: [Character: CGKeyCode] = [
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
    ]

    static func type(digit: Character, toPID pid: pid_t) -> Bool {
        guard let keyCode = digitKeyCodes[digit], let ascii = digit.asciiValue else { return false }
        let source = CGEventSource(stateID: .privateState)       // ignores any modifier the user is holding
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return false }
        var unit = UniChar(ascii)                                 // layout-independent: the character, not the key position
        for event in [down, up] {
            event.flags = []
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
        }
        down.postToPid(pid)
        usleep(10_000)
        up.postToPid(pid)
        return true
    }
}

extension KeyInjector {
    /// All the digits as one quick burst (about 20 ms): the browser handles key events in order, and the extension
    /// moves to the next box on every key, so there's no need to wait between digits.
    static func typeBurst(_ digits: [Character], toPID pid: pid_t) -> Bool {
        let source = CGEventSource(stateID: .privateState)
        var events: [CGEvent] = []
        for digit in digits {
            guard let keyCode = digitKeyCode(digit), let ascii = digit.asciiValue,
                  let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return false }
            var unit = UniChar(ascii)
            for event in [down, up] {
                event.flags = []
                event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
            }
            events += [down, up]
        }
        for event in events { event.postToPid(pid); usleep(1_500) }
        return true
    }

    /// Escape, delivered to one process; closes an extension popup that has focus.
    static func escape(toPID pid: pid_t) {
        let source = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: false) else { return }
        down.flags = []; up.flags = []
        down.postToPid(pid)
        usleep(10_000)
        up.postToPid(pid)
    }
}
