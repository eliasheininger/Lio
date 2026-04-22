import AppKit
import ApplicationServices

/// Monitors the global event stream for Right Option (⌥) key press/release.
/// Uses NSEvent.addGlobalMonitorForEvents — requires Accessibility + Input Monitoring.
final class HotkeyEngine {
    var onKeyDown:   (() -> Void)?
    var onKeyUp:     (() -> Void)?
    /// Called once when Input Monitoring is missing (monitor returned nil despite AX being trusted).
    var onTapFailed: (() -> Void)?

    private var monitor: Any?

    func start() {
        // Show Apple's native Accessibility prompt if not yet trusted.
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
        tryInstallMonitor()
    }

    private func tryInstallMonitor() {
        guard AXIsProcessTrusted() else {
            // Not trusted yet — poll until Accessibility is granted.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.tryInstallMonitor()
            }
            return
        }

        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
        }

        if monitor == nil {
            NSLog("[HotkeyEngine] addGlobalMonitorForEvents returned nil — Input Monitoring likely missing")
            DispatchQueue.main.async { self.onTapFailed?() }
        } else {
            NSLog("[HotkeyEngine] Global monitor installed successfully")
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func handle(event: NSEvent) {
        guard event.keyCode == 61 else { return } // Right Option (58 = Left)
        if event.modifierFlags.contains(.option) {
            NSLog("[HotkeyEngine] Right Option DOWN")
            DispatchQueue.main.async { self.onKeyDown?() }
        } else {
            NSLog("[HotkeyEngine] Right Option UP")
            DispatchQueue.main.async { self.onKeyUp?() }
        }
    }
}
