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
func whiskLogoNSImage(size: CGFloat = 18) -> NSImage? {
    // 1. swift run: Lio.svg lands directly in Bundle.main
    if let url = Bundle.main.url(forResource: "Lio", withExtension: "svg"),
       let img = NSImage(contentsOf: url) {
        img.size = NSSize(width: size, height: size)
        return img
    }
    // 2. .app build: Lio.svg lives inside Lio_Lio.bundle/ under Resources
    if let bundleURL = Bundle.main.resourceURL?
            .appendingPathComponent("Lio_Lio.bundle"),
       let resourceBundle = Bundle(url: bundleURL),
       let url = resourceBundle.url(forResource: "Lio", withExtension: "svg"),
       let img = NSImage(contentsOf: url) {
        img.size = NSSize(width: size, height: size)
        return img
    }
    return nil
}

/// Generic SVG loader — searches Bundle.main then Lio_Lio.bundle.
private func loadSVG(name: String, size: CGFloat) -> NSImage? {
    for bundle in [Bundle.main, Bundle.main.resourceURL
        .flatMap { Bundle(url: $0.appendingPathComponent("Lio_Lio.bundle")) }]
        .compactMap({ $0 }) {
        if let url = bundle.url(forResource: name, withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: size, height: size)
            return img
        }
    }
    return nil
}

func cursorNSImage(size: CGFloat = 32) -> NSImage? { loadSVG(name: "cursor", size: size) }
func lioMenuNSImage(size: CGFloat = 18) -> NSImage? { loadSVG(name: "LioMenu", size: size) }

/// LioMenu.svg rendered as a template image in aBlue. Falls back to the ⌥ glyph.
struct LogoImage: View {
    var size: CGFloat = 18
    var body: some View {
        if let img = lioMenuNSImage(size: size) {
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
    if t.hasPrefix("clicking")  { return "cursorarrow.click" }
    if t.hasPrefix("typing")    { return "keyboard" }
    if t.hasPrefix("scrolling") { return "arrow.up.arrow.down" }
    if t.hasPrefix("running")   { return "terminal" }
    if t.hasPrefix("shortcut")  { return "command" }
    if t.hasPrefix("capturing") { return "camera.viewfinder" }
    if t.contains("scroll")     { return "arrow.up.arrow.down" }
    if t.contains("type") || t.contains("enter") { return "keyboard" }
    if t.contains("click") || t.contains("press") { return "cursorarrow.click" }
    return "bolt"
}
