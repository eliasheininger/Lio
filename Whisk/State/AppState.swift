import Foundation

// MARK: - Step Item

struct StepItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var completed: Bool
}

// MARK: - App Phase

enum AppPhase: Equatable {
    case idle
    case recording
    case transcribing
    case transcript(text: String)
    case action(label: String)
    case progress(steps: [StepItem], completedCount: Int, summary: String)
    case permission(app: String, message: String)
    case success(message: String)
    case error(message: String)

    var isPill: Bool {
        switch self {
        case .idle, .recording, .transcribing, .action, .success, .error: return true
        default: return false
        }
    }

    var cornerRadius: CGFloat { isPill ? 24 : 24 }
}

// MARK: - App State

/// Central observable state — replaces /tmp/whisk_status.json.
/// All mutations must happen on the main thread.
@MainActor
final class AppState: ObservableObject {
    @Published var phase: AppPhase = .idle
    @Published var audioLevel: Double = 0.0   // 0.0–1.0 RMS, ~30 fps during recording

    // Convenience setters called by engines
    func set(_ phase: AppPhase) { self.phase = phase }
    func setLevel(_ level: Double) { self.audioLevel = level }
}
