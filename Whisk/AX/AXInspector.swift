import AppKit
import ApplicationServices

/// Introspection utilities — ported from ax_inspector.swift
@MainActor
final class AXInspector {

    /// Returns a list of all running GUI apps: "PID AppName (bundleID)"
    func listApps() -> String {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { "\($0.processIdentifier) \($0.localizedName ?? "?") (\($0.bundleIdentifier ?? "?"))" }
        return apps.joined(separator: "\n")
    }

    /// Returns all AX attributes of the focused element in the given app
    func inspectFocused(pid: Int32) -> String {
        let app = AXUIElementCreateApplication(pid)
        guard let focused = axGetAttribute(app, kAXFocusedUIElementAttribute as String) else {
            return "No focused element found"
        }
        let el = focused as! AXUIElement
        let names = axGetAttributeNames(el)
        var lines: [String] = []
        for name in names {
            if let val = axGetAttribute(el, name) {
                lines.append("  \(name): \(axStringValue(val))")
            }
        }
        return lines.joined(separator: "\n")
    }
}
