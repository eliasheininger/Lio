import AppKit
import ApplicationServices

/// All 13 AX tool implementations as async methods.
/// Ported from ax_runner.swift — now runs in-process (no subprocess overhead).
/// Must run on the main actor since AXUIElement operations are main-thread only.
@MainActor
final class AXRunner {

    // MARK: - Dispatch

    func execute(toolName: String, inputs: [String: Any]) async -> String {
        switch toolName {
        case "list_apps":           return inspector.listApps()
        case "open_app":            return await openApp(inputs["app_name"] as? String ?? "")
        case "focus_app":           return focusApp(inputs["app_name"] as? String ?? "")
        case "open_folder":         return await openFolder(inputs["path"] as? String ?? "")
        case "list_buttons":        return listButtons(pid: inputs["pid"] as? Int32 ?? 0)
        case "press_button":
            return await pressButton(pid: inputs["pid"] as? Int32 ?? 0,
                                     label: inputs["label"] as? String ?? "")
        case "inspect_focused":     return inspector.inspectFocused(pid: inputs["pid"] as? Int32 ?? 0)
        case "type_text":           return await typeText(inputs["text"] as? String ?? "")
        case "press_tab":           return pressKey(keyCode: 48)
        case "press_return":        return pressKey(keyCode: 36)
        case "open_url":            return await openURL(inputs["url"] as? String ?? "")
        case "find_elements":
            return findElements(
                pid:   Int32(inputs["pid"] as? Int ?? 0),
                query: inputs["query"] as? String ?? "",
                role:  inputs["role"]  as? String
            )
        case "scroll":
            return await scroll(
                pid:       Int32(inputs["pid"] as? Int ?? 0),
                direction: inputs["direction"] as? String ?? "down",
                amount:    inputs["amount"]    as? Int ?? 3
            )
        case "click_element":
            return await clickElement(
                pid:   Int32(inputs["pid"] as? Int ?? 0),
                query: inputs["query"] as? String ?? "",
                role:  inputs["role"]  as? String
            )
        case "press_space":    return pressSpace()
        case "shift_tab":      return shiftTab()
        case "press_shortcut": return pressShortcut(inputs["shortcut"] as? String ?? "")
        case "get_focused":    return getFocused(pid: Int32(inputs["pid"] as? Int ?? 0))
        case "tab_to":
            return await tabTo(
                pid:       Int32(inputs["pid"] as? Int ?? 0),
                query:     inputs["query"]     as? String ?? "",
                direction: inputs["direction"] as? String ?? "forward",
                maxTabs:   inputs["max_tabs"]  as? Int    ?? 15
            )
        default:                    return "Unknown tool: \(toolName)"
        }
    }

    private let inspector = AXInspector()

    // MARK: - Tool Implementations

    func openApp(_ name: String) async -> String {
        // Try /Applications first, then NSWorkspace URL lookup
        let candidates = [
            URL(fileURLWithPath: "/Applications/\(name).app"),
            URL(fileURLWithPath: "/System/Applications/\(name).app"),
        ]
        let url = candidates.first { FileManager.default.fileExists(atPath: $0.path) }
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: name.lowercased())

        guard let appURL = url else { return "❌ App '\(name)' not found" }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        return await withCheckedContinuation { cont in
            NSWorkspace.shared.openApplication(at: appURL, configuration: cfg) { _, err in
                if let err { cont.resume(returning: "❌ \(err.localizedDescription)") }
                else        { cont.resume(returning: "✅ Opened \(name)") }
            }
        }
    }

    func focusApp(_ name: String) -> String {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased() == name.lowercased()
        }) else { return "❌ '\(name)' is not running" }
        app.activate(options: [])
        return "✅ Focused \(app.localizedName ?? name)"
    }

    func listButtons(pid: Int32) -> String {
        let app     = AXUIElementCreateApplication(pid)
        let buttons = axCollect(app, role: kAXButtonRole as String)
        guard !buttons.isEmpty else { return "No buttons found" }
        return buttons.enumerated().map { i, btn in
            let t = axStringValue(axGetAttribute(btn, kAXTitleAttribute as String))
            let d = axStringValue(axGetAttribute(btn, kAXDescriptionAttribute as String))
            return "\(i) \([t,d].filter { $0 != "(null)" && !$0.isEmpty }.first ?? "<unlabelled>")"
        }.joined(separator: "\n")
    }

    func pressButton(pid: Int32, label: String) async -> String {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            app.activate(options: [])
            try? await Task.sleep(for: .milliseconds(150))
        }
        let appEl   = AXUIElementCreateApplication(pid)
        let buttons = axCollect(appEl, role: kAXButtonRole as String)
        let scored  = buttons.map { ($0, axScore($0, query: label)) }
        guard let (btn, score) = scored.max(by: { $0.1 < $1.1 }), score >= 0.5
        else { return "❌ No button matching '\(label)'" }
        let r = AXUIElementPerformAction(btn, kAXPressAction as CFString)
        return r == .success ? "✅ Pressed '\(label)'" : "❌ AX error \(r.rawValue)"
    }

    func findElements(pid: Int32, query: String, role: String? = nil) -> String {
        let appEl    = AXUIElementCreateApplication(pid)
        var elements = axCollectAll(appEl)
        if let role {
            elements = elements.filter {
                (axGetAttribute($0, kAXRoleAttribute as String) as? String) == role
            }
        }
        let scored = elements
            .map { ($0, axScore($0, query: query)) }
            .filter { $0.1 >= 0.4 }
            .sorted { $0.1 > $1.1 }
            .prefix(10)
        guard !scored.isEmpty else { return "No elements matching '\(query)'" }
        return scored.enumerated().map { i, pair in
            let (el, score) = pair
            let r     = axGetAttribute(el, kAXRoleAttribute as String) as? String ?? "?"
            let t     = axStringValue(axGetAttribute(el, kAXTitleAttribute as String))
            let d     = axStringValue(axGetAttribute(el, kAXDescriptionAttribute as String))
            let lbl   = [t, d].filter { $0 != "(null)" && !$0.isEmpty }.first ?? "<unlabelled>"
            return "\(i) [\(r)] \(lbl) (score: \(String(format: "%.2f", score)))"
        }.joined(separator: "\n")
    }

    func scroll(pid: Int32, direction: String, amount: Int = 3) async -> String {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            app.activate(options: [])
            try? await Task.sleep(for: .milliseconds(100))
        }
        let ticks = Int32(direction.lowercased() == "down" ? -amount : amount)
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .line,
                                  wheelCount: 1, wheel1: ticks, wheel2: 0, wheel3: 0)
        else { return "❌ Could not create scroll event" }
        event.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(300))
        return "✅ Scrolled \(direction) \(amount) lines"
    }

    func clickElement(pid: Int32, query: String, role: String? = nil) async -> String {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            app.activate(options: [])
            try? await Task.sleep(for: .milliseconds(150))
        }
        let appEl    = AXUIElementCreateApplication(pid)
        var elements = axCollectAll(appEl)
        if let role {
            elements = elements.filter {
                (axGetAttribute($0, kAXRoleAttribute as String) as? String) == role
            }
        }
        let scored = elements
            .map { ($0, axScore($0, query: query)) }
            .filter { $0.1 >= 0.4 }
            .sorted { $0.1 > $1.1 }
        guard let (el, _) = scored.first else { return "❌ No element matching '\(query)'" }

        // Try AXPress
        if AXUIElementPerformAction(el, kAXPressAction as CFString) == .success {
            return "✅ Clicked '\(query)' via AXPress"
        }
        // Try focus + AXPress
        AXUIElementSetAttributeValue(el, kAXFocusedAttribute as CFString, true as CFTypeRef)
        try? await Task.sleep(for: .milliseconds(100))
        if AXUIElementPerformAction(el, kAXPressAction as CFString) == .success {
            return "✅ Clicked '\(query)' via focus+AXPress"
        }
        // Fallback: CGEvent mouse click at element center
        guard let frame = axFrame(el) else { return "❌ Could not get frame for '\(query)'" }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let src    = CGEventSource(stateID: .hidSystemState)
        let down   = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown,
                             mouseCursorPosition: center, mouseButton: .left)
        let up     = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp,
                             mouseCursorPosition: center, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(200))
        return "✅ Clicked '\(query)' via mouse at (\(Int(center.x)), \(Int(center.y)))"
    }

    func openFolder(_ rawPath: String) async -> String {
        let path = NSString(string: rawPath).expandingTildeInPath
        guard let finder = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.finder"
        }) else { return "❌ Finder not running" }

        finder.activate(options: [])
        try? await Task.sleep(for: .milliseconds(300))

        let axApp = AXUIElementCreateApplication(finder.processIdentifier)

        // Step: press "Go" menu
        guard let menuBar = axGetAttribute(axApp, kAXMenuBarAttribute as String) as! AXUIElement?,
              let items = axGetAttribute(menuBar, kAXChildrenAttribute as String) as? [AXUIElement],
              let goItem = items.first(where: { axStringValue(axGetAttribute($0, kAXTitleAttribute as String)) == "Go" })
        else { return "❌ Could not find Go menu" }

        AXUIElementPerformAction(goItem, kAXPressAction as CFString)
        try? await Task.sleep(for: .milliseconds(300))

        // Step: press "Go to Folder…"
        guard let goChildren = axGetAttribute(goItem, kAXChildrenAttribute as String) as? [AXUIElement],
              let goMenu     = goChildren.first(where: { axStringValue(axGetAttribute($0, kAXRoleAttribute as String)) == kAXMenuRole as String }),
              let menuItems  = axGetAttribute(goMenu, kAXChildrenAttribute as String) as? [AXUIElement],
              let gtf        = menuItems.first(where: { axStringValue(axGetAttribute($0, kAXTitleAttribute as String)).hasPrefix("Go to Folder") })
        else { return "❌ Could not find 'Go to Folder…'" }

        AXUIElementPerformAction(gtf, kAXPressAction as CFString)
        try? await Task.sleep(for: .milliseconds(500))

        // Step: set path in text field
        guard let windows = axGetAttribute(axApp, kAXWindowsAttribute as String) as? [AXUIElement] else {
            return "❌ Could not read Finder windows"
        }
        var pathField: AXUIElement?
        for w in windows {
            if let f = axCollect(w, role: kAXTextFieldRole as String).first {
                pathField = f; break
            }
        }
        guard let field = pathField else { return "❌ Path text field not found" }
        AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, path as CFTypeRef)
        try? await Task.sleep(for: .milliseconds(400))

        // Step: press matching suggestion
        let folderName = URL(fileURLWithPath: path).lastPathComponent
        let suggestions = axCollect(axApp, role: kAXMenuItemRole as String)
        if let s = suggestions.first(where: { axStringValue(axGetAttribute($0, kAXTitleAttribute as String)) == folderName }) {
            AXUIElementPerformAction(s, kAXPressAction as CFString)
            return "✅ Opened \(path) in Finder"
        }
        // Fallback: just press Return
        return pressKey(keyCode: 36)
    }

    func typeText(_ text: String) async -> String {
        // Send each character as a real Unicode key event.
        // This works everywhere (Calculator, text fields, etc.) whereas Cmd+V
        // is blocked by many apps and doesn't work for number/operator input.
        let src = CGEventSource(stateID: .hidSystemState)
        for scalar in text.unicodeScalars {
            var ch = UniChar(scalar.value & 0xFFFF)
            guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true),
                  let up   = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            else { continue }
            down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
            up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(20))
        }
        return "✅ Typed \"\(text)\""
    }

    func pressKey(keyCode: CGKeyCode) -> String {
        let src  = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        return "✅ Key \(keyCode) pressed"
    }

    private func pressKeyWithFlags(keyCode: CGKeyCode, flags: CGEventFlags) -> String {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        else { return "❌ Could not create key event" }
        down.flags = flags
        up.flags   = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return "✅ Key \(keyCode) pressed"
    }

    func pressSpace() -> String {
        pressKeyWithFlags(keyCode: 49, flags: [])
    }

    func shiftTab() -> String {
        pressKeyWithFlags(keyCode: 48, flags: .maskShift)
    }

    func pressShortcut(_ shortcut: String) -> String {
        let parts = shortcut.lowercased().split(separator: "+").map(String.init)
        guard let keyName = parts.last else { return "❌ Empty shortcut" }

        var flags: CGEventFlags = []
        for mod in parts.dropLast() {
            switch mod {
            case "cmd", "command":        flags.insert(.maskCommand)
            case "shift":                 flags.insert(.maskShift)
            case "ctrl", "control":       flags.insert(.maskControl)
            case "alt", "opt", "option":  flags.insert(.maskAlternate)
            default: break
            }
        }

        let keyCodeMap: [String: CGKeyCode] = [
            "a":0,"b":11,"c":8,"d":2,"e":14,"f":3,"g":5,"h":4,"i":34,"j":38,
            "k":40,"l":37,"m":46,"n":45,"o":31,"p":35,"q":12,"r":15,"s":1,"t":17,
            "u":32,"v":9,"w":13,"x":7,"y":16,"z":6,
            "0":29,"1":18,"2":19,"3":20,"4":21,"5":23,"6":22,"7":26,"8":28,"9":25,
            "tab":48,"return":36,"enter":36,"space":49,"escape":53,"esc":53,
            "delete":51,"backspace":51,
            "up":126,"down":125,"left":123,"right":124,
            ",":43,".":47,"/":44,";":41,"'":39,"[":33,"]":30,"-":27,"=":24
        ]
        guard let keyCode = keyCodeMap[keyName] else { return "❌ Unknown key '\(keyName)'" }
        return pressKeyWithFlags(keyCode: keyCode, flags: flags)
    }

    func getFocused(pid: Int32) -> String {
        let app = AXUIElementCreateApplication(pid)
        guard let raw = axGetAttribute(app, kAXFocusedUIElementAttribute as String) else {
            return "No focused element"
        }
        let el      = raw as! AXUIElement
        let role    = axGetAttribute(el, kAXRoleAttribute as String)        as? String ?? "(none)"
        let title   = axGetAttribute(el, kAXTitleAttribute as String)       as? String ?? "(none)"
        let desc    = axGetAttribute(el, kAXDescriptionAttribute as String) as? String ?? "(none)"
        let val     = axGetAttribute(el, kAXValueAttribute as String).map { axStringValue($0) } ?? "(none)"
        let enabled = axGetAttribute(el, kAXEnabledAttribute as String)     as? Bool   ?? true
        return "role: \(role)\ntitle: \(title)\ndescription: \(desc)\nvalue: \(val)\nenabled: \(enabled)"
    }

    func tabTo(pid: Int32, query: String, direction: String, maxTabs: Int = 15) async -> String {
        let backward = direction.lowercased() == "backward" || direction.lowercased() == "back"
        let ql = query.lowercased()
        for i in 0..<maxTabs {
            _ = backward ? shiftTab() : pressKey(keyCode: 48)
            try? await Task.sleep(for: .milliseconds(80))
            let info = getFocused(pid: pid)
            if info.lowercased().contains(ql) {
                return "✅ Focused '\(query)' after \(i + 1) tab(s):\n\(info)"
            }
        }
        return "⚠️ '\(query)' not found after \(maxTabs) tabs. Currently focused:\n\(getFocused(pid: pid))"
    }

    func openURL(_ urlString: String) async -> String {
        guard let url = URL(string: urlString) else { return "❌ Invalid URL" }
        let ok = NSWorkspace.shared.open(url)
        return ok ? "✅ Opened \(urlString)" : "❌ Failed to open URL"
    }
}
