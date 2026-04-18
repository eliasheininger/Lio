import AppKit
import ApplicationServices

/// Monitors the global event stream for Right Option (⌥) key press/release.
/// Uses NSEvent.addGlobalMonitorForEvents — requires only Accessibility permission.
final class HotkeyEngine {
    var onKeyDown:          (() -> Void)?
    var onKeyUp:            (() -> Void)?
    var onPermissionNeeded: (() -> Void)?
    var onTapFailed:        (() -> Void)?

    private var monitor: Any?

    func start() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
        NSLog("[HotkeyEngine] AX trusted: \(trusted)")
        guard trusted else {
            DispatchQueue.main.async { self.onPermissionNeeded?() }
            return
        }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
        }

        guard monitor != nil else {
            NSLog("[HotkeyEngine] addGlobalMonitorForEvents returned nil")
            DispatchQueue.main.async { self.onTapFailed?() }
            return
        }

        NSLog("[HotkeyEngine] Global monitor installed successfully")
    }

    func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private func handle(event: NSEvent) {
        // keyCode 61 = Right Option specifically (58 = Left Option)
        guard event.keyCode == 61 else { return }
        NSLog("[HotkeyEngine] Right Option — flags=\(event.modifierFlags.rawValue)")

        if event.modifierFlags.contains(.option) {
            NSLog("[HotkeyEngine] Right Option DOWN")
            DispatchQueue.main.async { self.onKeyDown?() }
        } else {
            NSLog("[HotkeyEngine] Right Option UP")
            DispatchQueue.main.async { self.onKeyUp?() }
        }
    }
}
