import SwiftUI

@main
struct LioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows — the panel is managed entirely by AppDelegate/LioPanelController
        Settings { EmptyView() }
    }
}
