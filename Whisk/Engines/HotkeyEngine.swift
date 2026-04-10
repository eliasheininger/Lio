import AppKit
import ApplicationServices

/// Monitors the global event stream for Right Option (⌥) key press/release.
/// Uses a listenOnly tap so the key still works normally for the system.
final class HotkeyEngine {
    var onKeyDown: (() -> Void)?
    var onKeyUp:   (() -> Void)?

    private var tap:        CFMachPort?
    private var runLoopSrc: CFRunLoopSource?

    // NX_DEVICERALTKEYMASK — right-side Alt/Option flag bit
    private let rightAltMask: UInt64 = 0x0000_0040

    func start() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else {
            print("[HotkeyEngine] Accessibility not granted — hotkey disabled.")
            return
        }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let engine = Unmanaged<HotkeyEngine>.fromOpaque(refcon).takeUnretainedValue()
            engine.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        tap = CGEvent.tapCreate(
            tap:               .cgSessionEventTap,
            place:             .headInsertEventTap,
            options:           .listenOnly,
            eventsOfInterest:  mask,
            callback:          callback,
            userInfo:          Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            print("[HotkeyEngine] Event tap creation failed — check Input Monitoring permission.")
            return
        }

        runLoopSrc = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSrc, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSrc {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard type == .flagsChanged else { return }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == 61 else { return }   // Right Option key code

        let flags   = event.flags
        let isAlt   = flags.contains(.maskAlternate)
        let isRight = (flags.rawValue & rightAltMask) != 0

        if isAlt && isRight {
            // Key pressed down
            DispatchQueue.main.async { self.onKeyDown?() }
        } else if !isAlt {
            // Key released (both isAlt and isRight are cleared on release)
            DispatchQueue.main.async { self.onKeyUp?() }
        }
    }
}
