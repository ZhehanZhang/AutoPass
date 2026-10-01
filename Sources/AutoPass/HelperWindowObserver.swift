import Cocoa
import ApplicationServices

/// Hears about new windows in Apple's helper the instant they're created, with no polling. It runs on its own thread, so a busy
/// main thread can't delay it. The engine's regular ticks still run as a backstop if a notification never arrives.
final class HelperWindowObserver: @unchecked Sendable {
    /// Called on the observer's thread when the helper with this pid opens a window.
    var onWindow: (@Sendable (pid_t) -> Void)?

    private final class Context {
        let pid: pid_t
        weak var owner: HelperWindowObserver?
        init(pid: pid_t, owner: HelperWindowObserver) { self.pid = pid; self.owner = owner }
    }

    private var observers: [pid_t: (observer: AXObserver, context: Unmanaged<Context>)] = [:]
    private let lock = NSLock()
    private var runLoop: CFRunLoop?

    init() {
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in
            runLoop = CFRunLoopGetCurrent()
            RunLoop.current.add(NSMachPort(), forMode: .default)           // keeps the run loop alive
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = "AutoPass helper observer"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
    }

    func watch(pid: pid_t) {
        lock.lock(); defer { lock.unlock() }
        guard observers[pid] == nil, let runLoop else { return }
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let context = Unmanaged<Context>.fromOpaque(refcon).takeUnretainedValue()
            context.owner?.onWindow?(context.pid)
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let observer = created else { return }
        let context = Unmanaged.passRetained(Context(pid: pid, owner: self))
        guard AXObserverAddNotification(observer, AXUIElementCreateApplication(pid), kAXWindowCreatedNotification as CFString,
                                        context.toOpaque()) == .success else { context.release(); return }
        CFRunLoopAddSource(runLoop, AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = (observer, context)
    }

    func unwatch(pid: pid_t) {
        lock.lock(); defer { lock.unlock() }
        guard let entry = observers.removeValue(forKey: pid) else { return }
        if let runLoop { CFRunLoopRemoveSource(runLoop, AXObserverGetRunLoopSource(entry.observer), .commonModes) }
        entry.context.release()
    }
}
