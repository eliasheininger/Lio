import AppKit
import AVFoundation

/// Wires all engines together and manages the floating panel lifecycle.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state      = AppState()
    private let hotkey     = HotkeyEngine()
    private let audio      = AudioEngine()
    private let speech     = SpeechEngine()
    private var brain: BrainEngine!
    private var panel: WhiskPanelController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — accessory policy
        NSApp.setActivationPolicy(.accessory)

        brain = BrainEngine(state: state)
        panel = WhiskPanelController(state: state)
        panel.show()

        // Request mic permission early so the first hold isn't delayed
        Task { await requestMicrophoneAccess() }

        // Wire hotkey → audio
        hotkey.onKeyDown = { [weak self] in
            Task { @MainActor in await self?.startRecording() }
        }
        hotkey.onKeyUp = { [weak self] in
            Task { @MainActor in await self?.stopRecording() }
        }
        hotkey.start()
    }

    // MARK: - Recording flow

    private func startRecording() async {
        guard state.phase == .idle else { return }
        state.phase = .recording
        audio.onLevelUpdate = { [weak self] level in
            Task { @MainActor in self?.state.audioLevel = level }
        }
        do {
            try audio.startRecording()
        } catch {
            state.phase = .error(message: error.localizedDescription)
            try? await Task.sleep(for: .seconds(2.5))
            state.phase = .idle
        }
    }

    private func stopRecording() async {
        guard case .recording = state.phase else { return }
        state.phase = .transcribing
        state.audioLevel = 0

        guard let fileURL = audio.stopRecording() else {
            state.phase = .idle
            return
        }

        // Transcribe
        let text: String
        do {
            text = try await speech.transcribe(fileURL: fileURL)
        } catch SpeechError.noSpeechDetected {
            state.phase = .idle
            return
        } catch {
            state.phase = .error(message: error.localizedDescription)
            try? await Task.sleep(for: .seconds(2.5))
            state.phase = .idle
            return
        }

        state.phase = .transcript(text: text)
        try? await Task.sleep(for: .milliseconds(600))

        // Run brain loop
        await brain.run(instruction: text)
    }

    // MARK: - Permissions

    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
}
