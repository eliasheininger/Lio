import AppKit
import AVFoundation
import Combine

/// Wires all engines together and manages the floating panel lifecycle.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state      = AppState()
    private let hotkey     = HotkeyEngine()
    private let audio      = AudioEngine()
    private let speech     = SpeechEngine()
    private let cursor     = CursorOverlayWindow()
    private var brain: BrainEngine!
    private var panel: LioPanelController!

    private var statusItem: NSStatusItem?
    private var isPanelVisible = false
    private var cancellables   = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)

        brain = BrainEngine(state: state, cursor: cursor)
        panel = LioPanelController(state: state)

        setupStatusItem()
        observePhase()
        requestMicrophoneAccess()
        checkAndRequestScreenRecording()

        hotkey.onKeyDown = { [weak self] in
            NSLog("[AppDelegate] onKeyDown fired")
            Task { @MainActor in await self?.startRecording() }
        }
        hotkey.onKeyUp = { [weak self] in
            NSLog("[AppDelegate] onKeyUp fired")
            Task { @MainActor in await self?.stopRecording() }
        }
        hotkey.onPermissionNeeded = { [weak self] in
            NSLog("[AppDelegate] onPermissionNeeded — showing Accessibility card")
            guard let self else { return }
            Task { @MainActor in self.showAccessibilityPermission() }
        }
        hotkey.onTapFailed = { [weak self] in
            NSLog("[AppDelegate] onTapFailed — showing Input Monitoring card")
            guard let self else { return }
            Task { @MainActor in self.showInputMonitoringPermission() }
        }

        NSLog("[AppDelegate] calling hotkey.start()")
        hotkey.start()
    }

    // MARK: - Screen Recording

    private func checkAndRequestScreenRecording() {
        if #available(macOS 14.2, *) {
            if !CGPreflightScreenCaptureAccess() {
                CGRequestScreenCaptureAccess()
                // Show the panel with a brief instruction after the system prompt
                Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    if !CGPreflightScreenCaptureAccess() {
                        showScreenRecordingPermission()
                    }
                }
            }
        }
        // On macOS 13 the prompt fires on first capture attempt
    }

    private func showScreenRecordingPermission() {
        state.permissionHandlers = (
            accept: { [weak self] in
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                NSWorkspace.shared.open(url)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    self?.state.phase = .idle
                }
            },
            deny: { [weak self] in
                Task { @MainActor in self?.state.phase = .idle }
            }
        )
        panel.show()
        isPanelVisible = true
        state.phase = .permission(
            app: "Screen Recording",
            message: "Lio needs Screen Recording to see your screen.\n\nOpen Settings → Privacy & Security → Screen Recording, enable Lio, then relaunch.",
            acceptLabel: "Open Settings",
            denyLabel: "Not now"
        )
    }

    // MARK: - Accessibility / Input Monitoring Permissions

    private func showInputMonitoringPermission() {
        state.permissionHandlers = (
            accept: { [weak self] in
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
                NSWorkspace.shared.open(url)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    self?.state.phase = .idle
                }
            },
            deny: { [weak self] in
                Task { @MainActor in self?.state.phase = .idle }
            }
        )
        panel.show()
        isPanelVisible = true
        state.phase = .permission(
            app: "Input Monitoring",
            message: "Lio needs Input Monitoring permission to detect the Option key.\n\nOpen Settings → Privacy & Security → Input Monitoring, enable Lio, then relaunch."
        )
    }

    private func showAccessibilityPermission() {
        state.permissionHandlers = (
            accept: { [weak self] in
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    self?.state.phase = .idle
                }
            },
            deny: { [weak self] in
                Task { @MainActor in self?.state.phase = .idle }
            }
        )
        panel.show()
        isPanelVisible = true
        state.phase = .permission(
            app: "Accessibility",
            message: "Lio needs Accessibility permission to detect the Option key.\n\nOpen Settings → Privacy & Security → Accessibility, enable Lio, then relaunch."
        )
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        if let img = whiskLogoNSImage(size: 18) {
            img.isTemplate = true
            button.image = img
        } else {
            button.title = "⌥"
        }

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit Lio",
                         action: #selector(NSApplication.terminate(_:)),
                         keyEquivalent: "q")
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            DispatchQueue.main.async { self.statusItem?.menu = nil }
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if isPanelVisible {
            panel.hide()
            isPanelVisible = false
        } else {
            panel.show()
            isPanelVisible = true
        }
    }

    // MARK: - Phase observation (auto-hide)

    private func observePhase() {
        state.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                guard let self else { return }
                NSLog("[AppDelegate] phase → \(phase)")
                guard case .idle = phase, self.isPanelVisible else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    if case .idle = self.state.phase {
                        NSLog("[AppDelegate] auto-hiding panel")
                        self.panel.hide()
                        self.isPanelVisible = false
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Recording flow

    private func startRecording() async {
        NSLog("[AppDelegate] startRecording — phase=\(state.phase) visible=\(isPanelVisible)")

        // Right Option during a confirmation card = Accept
        if case .permission = state.phase {
            state.permissionHandlers?.accept()
            return
        }

        if !isPanelVisible {
            panel.show()
            isPanelVisible = true
        }
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
        NSLog("[AppDelegate] stopRecording — phase=\(state.phase)")
        guard case .recording = state.phase else { return }
        state.phase = .transcribing
        state.audioLevel = 0

        guard let fileURL = audio.stopRecording() else {
            state.phase = .idle
            return
        }

        let text: String
        do {
            text = try await speech.transcribe(fileURL: fileURL)
            NSLog("[AppDelegate] transcribed: \"\(text)\"")
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
        try? await Task.sleep(for: .milliseconds(1000))
        await brain.run(instruction: text)
    }

    // MARK: - Permissions

    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            NSLog("[AppDelegate] microphone access granted: \(granted)")
        }
    }
}
