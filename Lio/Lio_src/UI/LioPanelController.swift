import AppKit
import SwiftUI

/// Bridges the SwiftUI ContentView into a floating LioPanel.
/// ContentView reports its ideal height via PanelHeightKey; we animate the panel to match.
@MainActor
final class LioPanelController {
    private var panel: LioPanel?
    private let state: AppState

    init(state: AppState) { self.state = state }

    func show() {
        if panel == nil { buildPanel() }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func buildPanel() {
        var contentView = ContentView(state: state)
        contentView.onHeightChange = { [weak self] h in
            self?.panel?.animateHeight(to: h)
        }

        let hosting = NSHostingView(rootView: contentView)
        hosting.autoresizingMask = [.width, .height]

        panel = LioPanel(contentNSView: hosting)
    }
}
