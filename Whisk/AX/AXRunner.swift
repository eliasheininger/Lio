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
        // Activate the target app first — AX press actions often fail silently on unfocused apps
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            app.activate(options: [])
            try? await Task.sleep(for: .milliseconds(150))
        }
        let app     = AXUIElementCreateApplication(pid)
        let buttons = axCollect(app, role: kAXButtonRole as String)
        guard let btn = buttons.first(where: {
            let t = axStringValue(axGetAttribute($0, kAXTitleAttribute as String))
            let d = axStringValue(axGetAttribute($0, kAXDescriptionAttribute as String))
            return t.lowercased() == label.lowercased() || d.lowercased() == label.lowercased()
        }) else { return "❌ No button '\(label)'" }
        let r = AXUIElementPerformAction(btn, kAXPressAction as CFString)
        return r == .success ? "✅ Pressed '\(label)'" : "❌ AX error \(r.rawValue)"
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

    func openURL(_ urlString: String) async -> String {
        guard let url = URL(string: urlString) else { return "❌ Invalid URL" }
        let ok = NSWorkspace.shared.open(url)
        return ok ? "✅ Opened \(urlString)" : "❌ Failed to open URL"
    }
}
