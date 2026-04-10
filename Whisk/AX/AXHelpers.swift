import AppKit
import ApplicationServices

// MARK: - Low-level AX utilities (deduplicated from ax_runner.swift, ax_inspector.swift)

func axGetAttribute(_ el: AXUIElement, _ attr: String) -> AnyObject? {
    var val: AnyObject?
    AXUIElementCopyAttributeValue(el, attr as CFString, &val)
    return val
}

func axGetAttributeNames(_ el: AXUIElement) -> [String] {
    var names: CFArray?
    AXUIElementCopyAttributeNames(el, &names)
    return (names as? [AnyObject])?.compactMap { $0 as? String } ?? []
}

func axGetChildren(_ el: AXUIElement) -> [AXUIElement] {
    var val: AnyObject?
    AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &val)
    return (val as? [AnyObject])?.compactMap { $0 as! AXUIElement? } ?? []
}

/// Recursively collect all elements matching a given AX role, up to maxDepth levels deep
func axCollect(_ el: AXUIElement, role: String,
               depth: Int = 0, maxDepth: Int = 10) -> [AXUIElement] {
    guard depth < maxDepth else { return [] }
    var results: [AXUIElement] = []
    let r = axGetAttribute(el, kAXRoleAttribute as String) as? String
    if r == role { results.append(el) }
    for child in axGetChildren(el) {
        results.append(contentsOf: axCollect(child, role: role,
                                              depth: depth + 1, maxDepth: maxDepth))
    }
    return results
}

/// Human-readable description of any AX value object
func axStringValue(_ v: AnyObject?) -> String {
    guard let v else { return "(null)" }
    if let s = v as? String { return s }
    if let n = v as? NSNumber { return n.stringValue }
    if let arr = v as? [AnyObject] {
        return "[\(arr.prefix(5).map { axStringValue($0) }.joined(separator: ", "))]"
    }
    return String(describing: v)
}

/// Returns the frontmost running application
func axFocusedApp() -> NSRunningApplication? {
    NSWorkspace.shared.frontmostApplication
}
