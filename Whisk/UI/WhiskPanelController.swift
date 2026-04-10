import AppKit
import SwiftUI

/// Bridges the SwiftUI ContentView into a floating NSPanel.
/// ContentView reports its ideal height via PanelHeightKey; we animate the panel to match.
@MainActor
final class WhiskPanelController {
    private var panel: WhiskPanel!
    private let state: AppState

    init(state: AppState) { self.state = state }

    func show() {
        var contentView = ContentView(state: state)
        contentView.onHeightChange = { [weak self] h in
            self?.panel.animateHeight(to: h)
        }

        let hosting = NSHostingView(rootView: contentView)
        hosting.autoresizingMask = [.width, .height]

        panel = WhiskPanel(contentNSView: hosting)
        // orderFrontRegardless works without requiring the app to be active,
        // which is necessary for .accessory / non-activating panels.
        panel.orderFrontRegardless()
    }
}
