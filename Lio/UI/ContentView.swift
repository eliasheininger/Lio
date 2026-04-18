import SwiftUI

// Height preference — ContentView reports its ideal height up to LioPanelController
struct PanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = PILL_H
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ContentView: View {
    @ObservedObject var state: AppState
    var onHeightChange: ((CGFloat) -> Void)?

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .clipShape(
                    RoundedRectangle(cornerRadius: state.phase.cornerRadius,
                                     style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: state.phase.cornerRadius,
                                     style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.75)
                )

            phaseView
        }
        .fixedSize(horizontal: true, vertical: true)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: PanelHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(PanelHeightKey.self) { h in
            onHeightChange?(h)
        }
    }

    @ViewBuilder
    private var phaseView: some View {
        switch state.phase {
        case .idle:
            IdleView()
        case .recording:
            RecordingView(level: state.audioLevel)
        case .transcribing:
            TranscribingView()
        case .transcript(let text):
            TranscriptView(text: text)
        case .action(let label):
            ActionView(label: label)
        case .progress(let steps, let completed, let summary):
            ProgressCardView(steps: steps, completedCount: completed, summary: summary)
        case .permission(let app, let message, let acceptLabel, let denyLabel):
            PermissionView(app: app, message: message,
                           acceptLabel: acceptLabel, denyLabel: denyLabel,
                           onDeny:   { self.state.permissionHandlers?.deny() },
                           onAccept: { self.state.permissionHandlers?.accept() })
        case .success(let message):
            SuccessView(message: message)
        case .error(let message):
            ErrorView(message: message)
        }
    }
}
