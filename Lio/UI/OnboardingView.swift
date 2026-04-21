import SwiftUI
import AVFoundation
import CoreGraphics

// MARK: - Window controller

private final class OnboardingWindow: NSWindow {
    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { true }
}

final class OnboardingWindowController: NSWindowController {

    convenience init(onComplete: @escaping () -> Void) {
        // 16px padding on all sides around the card (380 × 360 card → 412 × 392 window)
        let w = OnboardingWindow(
            contentRect: CGRect(x: 0, y: 0, width: 412, height: 392),
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       false
        )
        w.isOpaque                    = false
        w.backgroundColor             = .clear
        w.hasShadow                   = true
        w.isMovableByWindowBackground = true
        w.level                       = .floating
        w.center()
        self.init(window: w)
        w.contentView = NSHostingView(rootView: OnboardingView(onComplete: onComplete))
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - API Key Settings window controller

final class APIKeySettingsWindowController: NSWindowController {

    convenience init(onDismiss: @escaping () -> Void) {
        let w = OnboardingWindow(
            contentRect: CGRect(x: 0, y: 0, width: 412, height: 320),
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       false
        )
        w.isOpaque                    = false
        w.backgroundColor             = .clear
        w.hasShadow                   = true
        w.isMovableByWindowBackground = true
        w.level                       = .floating
        w.center()
        self.init(window: w)
        w.contentView = NSHostingView(rootView: APIKeySettingsView(onDismiss: onDismiss))
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - API Key Settings view

struct APIKeySettingsView: View {
    var onDismiss: () -> Void

    @State private var apiKey = UserDefaults.standard.string(forKey: "openrouter_api_key") ?? ""
    @State private var error: String? = nil

    var body: some View {
        ZStack {
            Color.clear
            ZStack {
                VisualEffectBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.75)
                    )

                VStack(alignment: .leading, spacing: 0) {
                    LogoImage(size: 36)
                        .padding(.top, 24)
                        .padding(.bottom, 20)

                    Text("OpenRouter API Key")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 16)

                    TextField("sk-or-…", text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                        .padding(.bottom, error != nil ? 6 : 12)

                    if let err = error {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .padding(.bottom, 8)
                    }

                    Button("Get your free OpenRouter Key here →") {
                        NSWorkspace.shared.open(URL(string: "https://openrouter.ai/keys")!)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.aBlue)

                    Spacer()

                    HStack(spacing: 16) {
                        Button("Remove Key") {
                            UserDefaults.standard.removeObject(forKey: "openrouter_api_key")
                            onDismiss()
                        }
                        .buttonStyle(GhostButton())
                        .foregroundColor(.red.opacity(0.7))

                        Button("Save", action: save)
                            .buttonStyle(PrimaryButton())
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }
            .padding(16)
        }
        .frame(width: 412, height: 320)
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = "Please enter your OpenRouter API key."; return }
        UserDefaults.standard.set(trimmed, forKey: "openrouter_api_key")
        onDismiss()
    }
}

// MARK: - Steps

private enum Step: Equatable {
    case welcome, screenRecording, microphone, accessibility, apiKey, allSet
}

// MARK: - Root view

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var step: Step = .welcome
    @State private var apiKey = UserDefaults.standard.string(forKey: "openrouter_api_key") ?? ""
    @State private var keyError: String? = nil

    @State private var hasSR  = CGPreflightScreenCaptureAccess()
    @State private var hasMic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var hasAX  = AXIsProcessTrusted()

    var body: some View {
        // 16px gap from window edge to card
        ZStack {
            Color.clear
            cardContent
                .padding(16)
        }
        .frame(width: 412, height: 392)
        .animation(.easeInOut(duration: 0.22), value: step)
        .onReceive(Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()) { _ in
            pollPermissions()
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        ZStack {
            // Card background — same material & stroke as main panel
            VisualEffectBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.75)
                )

            switch step {
            case .welcome:
                WelcomeStep(onNext: { step = advance(from: .welcome) })
            case .screenRecording:
                PermStep(
                    sfSymbol:    "menubar.rectangle",
                    title:       "Lio wants to record your screen.",
                    instruction: "Allow access in the dialog, or go to Settings → Privacy & Security → Screen Recording.",
                    isGranted:   hasSR,
                    onDeny:      { step = advance(from: .screenRecording) },
                    onSettings:  { open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") }
                )
                .onAppear {
                    if #available(macOS 14.2, *) { CGRequestScreenCaptureAccess() }
                }
            case .microphone:
                PermStep(
                    sfSymbol:    "mic.fill",
                    title:       "Lio wants to access your microphone.",
                    instruction: "Allow access in the dialog, or go to Settings → Privacy & Security → Microphone.",
                    isGranted:   hasMic,
                    onDeny:      { step = advance(from: .microphone) },
                    onSettings:  { open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") }
                )
                .onAppear {
                    AVCaptureDevice.requestAccess(for: .audio) { _ in }
                }
            case .accessibility:
                PermStep(
                    sfSymbol:    "figure.accessibility",
                    title:       "Lio wants to access Accessibility.",
                    instruction: "Go to Settings → Privacy & Security → Accessibility and enable Lio.",
                    isGranted:   hasAX,
                    onDeny:      { step = advance(from: .accessibility) },
                    onSettings:  { open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") }
                )
            case .apiKey:
                APIKeyStep(apiKey: $apiKey, error: $keyError, onFinish: handleAPIKey)
            case .allSet:
                AllSetStep(onFinish: onComplete)
            }
        }
    }

    // MARK: - Helpers

    private func open(_ urlString: String) {
        NSWorkspace.shared.open(URL(string: urlString)!)
    }

    private func handleAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { keyError = "Please enter your OpenRouter API key."; return }
        UserDefaults.standard.set(trimmed, forKey: "openrouter_api_key")
        keyError = nil
        step = .allSet
    }

    @discardableResult
    private func advance(from current: Step) -> Step {
        switch current {
        case .welcome:         return hasSR  ? advance(from: .screenRecording) : .screenRecording
        case .screenRecording: return hasMic ? advance(from: .microphone)      : .microphone
        case .microphone:      return hasAX  ? advance(from: .accessibility)   : .accessibility
        case .accessibility:   return .apiKey
        case .apiKey:          return .allSet
        case .allSet:          return .allSet
        }
    }

    private func pollPermissions() {
        if #available(macOS 14.2, *) {
            let sr = CGPreflightScreenCaptureAccess()
            if sr && !hasSR { hasSR = sr; if step == .screenRecording { step = advance(from: .screenRecording) } }
        }
        let mic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        if mic && !hasMic { hasMic = mic; if step == .microphone { step = advance(from: .microphone) } }
        let ax = AXIsProcessTrusted()
        if ax && !hasAX { hasAX = ax; if step == .accessibility { step = advance(from: .accessibility) } }
    }
}

// MARK: - Welcome step

private struct WelcomeStep: View {
    var onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogoImage(size: 44)
                .padding(.top, 24)
                .padding(.bottom, 20)

            Text("Welcome to Lio! You can activate Lio anytime you want it to do something by holding the")
                .font(.system(size: 16))
                .foregroundColor(.primary.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // "right option key" pill — centered between text and button
            HStack(spacing: 6) {
                Image(systemName: "option")
                    .font(.system(size: 13, weight: .medium))
                Text("right option key")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.primary.opacity(0.75))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            )
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer()

            Button("Next", action: onNext)
                .buttonStyle(FullWidthPrimaryButton())
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Permission step

private struct PermStep: View {
    var sfSymbol:    String
    var title:       String
    var instruction: String
    var isGranted:   Bool
    var onDeny:      () -> Void
    var onSettings:  () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: sfSymbol)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.aBlue)
                .padding(.top, 24)
                .padding(.bottom, 20)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 4)

            Text(instruction)
                .font(.system(size: 16))
                .foregroundColor(.primary.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            if isGranted {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.top, 14)
            }

            Spacer()

            // Deny (compact left) | Open Settings (fills remaining)
            HStack(spacing: 16) {
                Button("Deny", action: onDeny)
                    .buttonStyle(GhostButton())
                Button("Open Settings", action: onSettings)
                    .buttonStyle(PrimaryButton())
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - API Key step

private struct APIKeyStep: View {
    @Binding var apiKey: String
    @Binding var error:  String?
    var onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogoImage(size: 44)
                .padding(.top, 24)
                .padding(.bottom, 20)

            Text("Lio uses OpenRouter for AI Models. Please paste your key below - it stays on your Mac.")
                .font(.system(size: 16))
                .foregroundColor(.primary.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            // Capsule-style text field matching design
            TextField("sk88....", text: $apiKey)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.07))
                )
                .padding(.bottom, error != nil ? 6 : 10)

            if let err = error {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
            }

            Button("Get your free OpenRouter Key here →") {
                NSWorkspace.shared.open(URL(string: "https://openrouter.ai/keys")!)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(.aBlue)

            Spacer()

            Button("Finish", action: onFinish)
                .buttonStyle(FullWidthPrimaryButton())
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - All Set step

private struct AllSetStep: View {
    var onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogoImage(size: 44)
                .padding(.top, 24)
                .padding(.bottom, 20)

            Text("All set! You can now control your Computer with your voice.")
                .font(.system(size: 16))
                .foregroundColor(.primary.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button("Finish", action: onFinish)
                .buttonStyle(FullWidthPrimaryButton())
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Button styles

/// Full-width blue capsule (Finish buttons)
private struct FullWidthPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Capsule().fill(Color.aBlue))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Expanding blue capsule — fills remaining HStack space (Next, Open Settings)
private struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Capsule().fill(Color.aBlue))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Plain text — Back, Deny
private struct GhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15))
            .foregroundColor(.primary.opacity(0.50))
            .frame(height: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
