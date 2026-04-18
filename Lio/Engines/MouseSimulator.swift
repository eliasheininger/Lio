import CoreGraphics
import Foundation

/// Sends raw CGEvent mouse and keyboard events to control the pointer and keyboard.
/// No Accessibility API dependency — works purely via the HID event tap.
@MainActor
final class MouseSimulator {

    /// Left-click at the given screen point (macOS bottom-left coords).
    func click(at point: CGPoint) async {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown,
                           mouseCursorPosition: point, mouseButton: .left)
        let up   = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp,
                           mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(60))
        up?.post(tap: .cghidEventTap)
    }

    /// Scroll at the given screen point. Positive delta scrolls up, negative scrolls down.
    func scroll(at point: CGPoint, delta: Int) async {
        let ticks = Int32(clamping: delta)
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line,
                            wheelCount: 1, wheel1: ticks, wheel2: 0, wheel3: 0)
        event?.location = point
        event?.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(30))
    }

    /// Type text character-by-character via Unicode keyboard events.
    /// Works in any app — bypasses clipboard-based approaches.
    func type(text: String) async {
        let src = CGEventSource(stateID: .hidSystemState)
        for scalar in text.unicodeScalars {
            var ch = UniChar(scalar.value & 0xFFFF)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            let up   = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            down?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
            up?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Send a keyboard shortcut such as "cmd+space", "cmd+t", "escape".
    /// Modifiers: cmd, shift, ctrl, opt/alt. Keys: a-z, 0-9, space, return,
    /// escape, delete, tab, up, down, left, right, f1-f12.
    func pressShortcut(_ shortcut: String) async {
        let parts = shortcut.lowercased().components(separatedBy: "+")
        guard let keyName = parts.last else { return }
        let mods = Set(parts.dropLast())

        // (virtualKey, flag) pairs — order matters for release
        var modifierKeys: [(CGKeyCode, CGEventFlags)] = []
        var flags = CGEventFlags()
        if mods.contains("cmd") || mods.contains("command") {
            flags.insert(.maskCommand);   modifierKeys.append((55, .maskCommand))
        }
        if mods.contains("shift") {
            flags.insert(.maskShift);     modifierKeys.append((56, .maskShift))
        }
        if mods.contains("ctrl") || mods.contains("control") {
            flags.insert(.maskControl);   modifierKeys.append((59, .maskControl))
        }
        if mods.contains("opt") || mods.contains("alt") {
            flags.insert(.maskAlternate); modifierKeys.append((58, .maskAlternate))
        }

        guard let keyCode = Self.keyCode(for: keyName) else {
            NSLog("[MouseSimulator] pressShortcut: unknown key '\(keyName)'")
            return
        }

        let src = CGEventSource(stateID: .hidSystemState)

        // Press modifier keys explicitly so HID state is correct
        var heldFlags = CGEventFlags()
        for (modKey, modFlag) in modifierKeys {
            heldFlags.insert(modFlag)
            let e = CGEvent(keyboardEventSource: src, virtualKey: modKey, keyDown: true)
            e?.flags = heldFlags
            e?.post(tap: .cghidEventTap)
        }

        // Press and release main key
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags   = flags
        down?.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(40))
        up?.post(tap: .cghidEventTap)

        // Release modifier keys in reverse order so HID state is fully cleared
        for (modKey, modFlag) in modifierKeys.reversed() {
            heldFlags.remove(modFlag)
            let e = CGEvent(keyboardEventSource: src, virtualKey: modKey, keyDown: false)
            e?.flags = heldFlags
            e?.post(tap: .cghidEventTap)
        }

        try? await Task.sleep(for: .milliseconds(80))
    }

    private static func keyCode(for name: String) -> CGKeyCode? {
        let map: [String: CGKeyCode] = [
            // Letters
            "a":0,"b":11,"c":8,"d":2,"e":14,"f":3,"g":5,"h":4,"i":34,
            "j":38,"k":40,"l":37,"m":46,"n":45,"o":31,"p":35,"q":12,
            "r":15,"s":1,"t":17,"u":32,"v":9,"w":13,"x":7,"y":16,"z":6,
            // Numbers
            "0":29,"1":18,"2":19,"3":20,"4":21,"5":23,"6":22,"7":26,"8":28,"9":25,
            // Special
            "space":49,"return":36,"tab":48,"escape":53,"delete":51,"backspace":51,
            "up":126,"down":125,"left":123,"right":124,
            "f1":122,"f2":120,"f3":99,"f4":118,"f5":96,"f6":97,
            "f7":98,"f8":100,"f9":101,"f10":109,"f11":103,"f12":111,
            // Punctuation
            ",":43,".":47,"/":44,";":41,"'":39,"[":33,"]":30,"\\":42,
            "-":27,"=":24,"`":50,
        ]
        return map[name]
    }
}
