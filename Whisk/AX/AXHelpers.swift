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

/// Collect ALL elements (any role) recursively, up to maxDepth/maxCount
func axCollectAll(_ el: AXUIElement, maxDepth: Int = 12, maxCount: Int = 500) -> [AXUIElement] {
    var results: [AXUIElement] = []
    results.reserveCapacity(min(maxCount, 128))
    func recurse(_ el: AXUIElement, depth: Int) {
        guard depth < maxDepth, results.count < maxCount else { return }
        results.append(el)
        for child in axGetChildren(el) {
            guard results.count < maxCount else { return }
            recurse(child, depth: depth + 1)
        }
    }
    recurse(el, depth: 0)
    return results
}

/// Lowercase, letters/numbers/spaces only, collapse whitespace
func axNormalize(_ s: String) -> String {
    let filtered = s.lowercased().filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
    return filtered.split(separator: " ").joined(separator: " ")
}

/// Fuzzy relevance score for an element vs a query string (0–1)
func axScore(_ el: AXUIElement, query: String) -> Double {
    let attrs: [String] = [kAXTitleAttribute as String, kAXDescriptionAttribute as String,
                           kAXValueAttribute as String, kAXHelpAttribute as String,
                           "AXPlaceholderValue"]

    // Exact match pass — handles symbols like ×, ÷, −, = that normalize to empty
    let ql = query.lowercased()
    for attr in attrs {
        guard let raw = axGetAttribute(el, attr) as? String,
              raw != "(null)", !raw.isEmpty else { continue }
        if raw.lowercased() == ql { return 1.0 }
    }

    let qn = axNormalize(query)
    guard !qn.isEmpty else { return 0 }
    var best = 0.0
    for attr in attrs {
        guard let raw = axGetAttribute(el, attr) as? String,
              raw != "(null)", !raw.isEmpty else { continue }
        let vn = axNormalize(raw)
        guard !vn.isEmpty else { continue }
        let score: Double
        if vn == qn                 { score = 1.0 }
        else if vn.hasPrefix(qn)    { score = 0.9 }
        else if vn.contains(qn)     { score = 0.75 }
        else if qn.contains(vn)     { score = 0.6 }
        else {
            let qWords = Set(qn.split(separator: " ").map(String.init))
            let vWords = Set(vn.split(separator: " ").map(String.init))
            let overlap = qWords.intersection(vWords).count
            score = overlap > 0 ? 0.4 + Double(overlap) / Double(qWords.count) * 0.2 : 0
        }
        if score > best { best = score }
    }
    return best
}

/// Read screen-space frame of an AX element (nil if attributes missing or wrong type)
func axFrame(_ el: AXUIElement) -> CGRect? {
    guard let posVal  = axGetAttribute(el, kAXPositionAttribute as String),
          let sizeVal = axGetAttribute(el, kAXSizeAttribute as String) else { return nil }
    var point = CGPoint.zero
    var size  = CGSize.zero
    guard AXValueGetValue(posVal as! AXValue, .cgPoint, &point),
          AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else { return nil }
    return CGRect(origin: point, size: size)
}
