import SwiftUI

@main
struct WhiskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows — the panel is managed entirely by AppDelegate/WhiskPanelController
        Settings { EmptyView() }
    }
}
