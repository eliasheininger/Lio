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
/// Loads option.svg from the app bundle as a template image (tinted aBlue).
/// Falls back to the ⌥ glyph if the asset is missing.
struct LogoImage: View {
    var size: CGFloat = 18
    var body: some View {
        // Bundle.module is synthesized by SwiftPM for the resources target
        let logoURL = (Bundle.main.url(forResource: "option", withExtension: "svg")
            ?? Bundle.main.url(forResource: "Whisk_Whisk.bundle/option", withExtension: "svg"))
        if let url = logoURL, let img = NSImage(contentsOf: url) {
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
/// Action-appropriate SF symbol name based on step text
func actionIconName(for text: String) -> String {
    let t = text.lowercased()
    if t.contains("safari") || t.contains("browser")   { return "safari" }
    if t.contains("navigat") || t.contains("go to")    { return "arrow.right.circle" }
    if t.contains("search") || t.contains("find")      { return "magnifyingglass" }
    if t.contains("scroll")                             { return "arrow.down.circle" }
    if t.contains("type") || t.contains("enter")       { return "keyboard" }
    if t.contains("click") || t.contains("press")      { return "cursorarrow.click" }
    if t.contains("open") || t.contains("launch")      { return "arrow.up.right.square" }
    if t.contains("done") || t.contains("finish")      { return "checkmark.circle" }
    return "gearshape"
}
