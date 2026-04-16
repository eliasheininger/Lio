import SwiftUI

// MARK: - Colors
extension Color {
    static let aSecondary = Color(white: 1.00)
    static let aRed       = Color(red: 1.00, green: 0.27, blue: 0.23)
    static let aOrange    = Color(red: 1.00, green: 0.62, blue: 0.04)
    static let aGreen     = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let aBlue      = Color(red: 0.04, green: 0.52, blue: 1.00)
    static let aPrimary   = Color(white: 0.08)
}

// MARK: - Dimensions
let PANEL_W: CGFloat = 288
let PILL_H:  CGFloat = 64
let DIV_X:   CGFloat = 56   // vertical divider x for pill states

// MARK: - Logo

/// Loads Lio.svg from the app bundle. Works for both `swift run` and a built `.app`.
/// Returns nil if the asset can't be found.
func whiskLogoNSImage(size: CGFloat = 18) -> NSImage? {
    // 1. swift run: Lio.svg lands directly in Bundle.main
    if let url = Bundle.main.url(forResource: "option", withExtension: "svg"),
       let img = NSImage(contentsOf: url) {
        img.size = NSSize(width: size, height: size)
        return img
    }
    // 2. .app build: Lio.svg lives inside Whisk_Whisk.bundle/ under Resources
    if let bundleURL = Bundle.main.resourceURL?
            .appendingPathComponent("Whisk_Whisk.bundle"),
       let resourceBundle = Bundle(url: bundleURL),
       let url = resourceBundle.url(forResource: "option", withExtension: "svg"),
       let img = NSImage(contentsOf: url) {
        img.size = NSSize(width: size, height: size)
        return img
    }
    return nil
}

/// Loads Lio.svg as a template image (tinted aBlue). Falls back to the ⌥ glyph.
struct LogoImage: View {
    var size: CGFloat = 18
    var body: some View {
        if let img = whiskLogoNSImage(size: size) {
            Image(nsImage: img)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(.aBlue)
        } else {
            Text("⌥")
                .font(.system(size: size * 0.85, weight: .semibold))
                .foregroundColor(.aBlue)
        }
    }
}

// MARK: - SF Symbol helper
/// Action-appropriate SF symbol name based on step label text from BrainEngine.toolLabel
func actionIconName(for text: String) -> String {
    let t = text.lowercased()
    if t.hasPrefix("listing apps")                      { return "square.grid.2x2" }
    if t.hasPrefix("listing buttons")                   { return "list.bullet" }
    if t.hasPrefix("opening folder")                    { return "folder" }
    if t.hasPrefix("opening url") || t.contains("url") { return "globe" }
    if t.hasPrefix("opening")                           { return "arrow.up.right.square" }
    if t.hasPrefix("focusing")                          { return "scope" }
    if t.hasPrefix("clicking") || t.hasPrefix("pressing button") { return "cursorarrow.click" }
    if t.hasPrefix("inspecting")                        { return "magnifyingglass" }
    if t.hasPrefix("typing")                            { return "keyboard" }
    if t.hasPrefix("pressing tab")                      { return "arrow.right.to.line" }
    if t.hasPrefix("pressing return")                   { return "return" }
    if t.hasPrefix("searching")                         { return "magnifyingglass" }
    if t.hasPrefix("scrolling")                         { return "arrow.up.arrow.down" }
    if t.contains("safari") || t.contains("browser")   { return "safari" }
    if t.contains("folder")                             { return "folder" }
    if t.contains("scroll")                             { return "arrow.up.arrow.down" }
    if t.contains("type") || t.contains("enter")       { return "keyboard" }
    if t.contains("click") || t.contains("press")      { return "cursorarrow.click" }
    if t.contains("open") || t.contains("launch")      { return "arrow.up.right.square" }
    if t.contains("search") || t.contains("find")      { return "magnifyingglass" }
    return "bolt"
}
