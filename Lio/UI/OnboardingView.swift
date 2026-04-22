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
        let w = OnboardingWindow(
            contentRect: CGRect(x: 0, y: 0, width: 412, height: 540),
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
    case permissions, apiKey, allSet
}

// MARK: - Root view

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var step: Step = .permissions
    @State private var apiKey = UserDefaults.standard.string(forKey: "openrouter_api_key") ?? ""
    @State private var keyError: String? = nil

    @State private var hasSR  = CGPreflightScreenCaptureAccess()
    @State private var hasMic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var hasAX  = AXIsProcessTrusted()

    var body: some View {
        ZStack {
            Color.clear
            cardContent
                .padding(16)
        }
        .frame(width: 412, height: 540)
        .animation(.easeInOut(duration: 0.22), value: step)
        .onReceive(Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()) { _ in
            pollMicPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            pollSRPermission()
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        ZStack {
            VisualEffectBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.75)
                )

            switch step {
            case .permissions:
                PermissionsStep(hasMic: $hasMic, hasSR: $hasSR, hasAX: $hasAX,
                                onRelaunch: onComplete,
                                onAppearCheck: checkAllGrantedAtLaunch)
            case .apiKey:
                APIKeyStep(apiKey: $apiKey, error: $keyError, onFinish: handleAPIKey)
            case .allSet:
                AllSetStep(onFinish: onComplete)
            }
        }
    }

    private func handleAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { keyError = "Please enter your OpenRouter API key."; return }
        UserDefaults.standard.set(trimmed, forKey: "openrouter_api_key")
        keyError = nil
        step = .allSet
    }

    // Mic status is reliable in real-time; poll it on timer.
    private func pollMicPermission() {
        hasMic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    // SR may update when the user returns from Settings; check on app-become-active.
    // AX is NEVER updated in the same process — set only at launch via @State initializer.
    private func pollSRPermission() {
        if #available(macOS 14.2, *) {
            hasSR = CGPreflightScreenCaptureAccess()
        }
    }

    // Called once on PermissionsStep appear — if all three are already granted at
    // launch (i.e. this is Launch 2+), auto-advance without requiring user action.
    private func checkAllGrantedAtLaunch() {
        guard hasSR && hasMic && hasAX && step == .permissions else { return }
        let key = UserDefaults.standard.string(forKey: "openrouter_api_key") ?? ""
        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            step = .apiKey
        } else {
            onComplete()
        }
    }
}

// MARK: - Permissions step (all-in-one)

private struct PermissionsStep: View {
    @Binding var hasMic: Bool
    @Binding var hasSR:  Bool
    @Binding var hasAX:  Bool
    var onRelaunch: () -> Void
    var onAppearCheck: () -> Void

    @State private var axRequested = false
    @State private var srRequested = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogoImage(size: 44)
                .padding(.top, 24)
                .padding(.bottom, 20)

            Text("Welcome to Lio")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 4)

            Text("Enable permissions to get started")
                .font(.system(size: 16))
                .foregroundColor(.primary.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 20)

            VStack(spacing: 8) {
                PermRow(
                    symbol:      "mic.fill",
                    title:       "Microphone",
                    description: "To record your voice",
                    isGranted:   hasMic,
                    onEnable: {
                        let status = AVCaptureDevice.authorizationStatus(for: .audio)
                        if status == .notDetermined {
                            AVCaptureDevice.requestAccess(for: .audio) { _ in }
                        } else {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                        }
                    },
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                )
                PermRow(
                    symbol:      "menubar.rectangle",
                    title:       "Screen Recording",
                    description: srRequested && !hasSR ? "Restart Lio to activate" : "To see your screen",
                    isGranted:   hasSR,
                    onEnable: {
                        srRequested = true
                        if #available(macOS 14.2, *) {
                            CGRequestScreenCaptureAccess()
                        } else {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                        }
                    },
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                )
                PermRow(
                    symbol:      "accessibility",
                    title:       "Accessibility",
                    description: axRequested && !hasAX ? "Restart Lio to activate" : "To type and detect the shortcut",
                    isGranted:   hasAX,
                    onEnable: {
                        axRequested = true
                        AXIsProcessTrustedWithOptions(
                            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        )
                    },
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )
            }

            Spacer()

            VStack(spacing: 10) {
                Button("Relaunch Lio") { onRelaunch() }
                    .buttonStyle(FullWidthPrimaryButton())

                Text("Lio will restart after enabling permissions")
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .onAppear { onAppearCheck() }
    }
}

// MARK: - Permission row

private struct PermRow: View {
    var symbol:      String
    var title:       String
    var description: String
    var isGranted:   Bool
    var onEnable:    (() -> Void)? = nil   // called first time (notDetermined); nil = go straight to Settings
    var settingsURL: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(.primary.opacity(0.65))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.5))
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isGranted },
                set: { _ in
                    if let onEnable, !isGranted {
                        onEnable()
                    } else {
                        NSWorkspace.shared.open(URL(string: settingsURL)!)
                    }
                }
            ))
            .toggleStyle(.switch)
            .tint(Color.aBlue)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
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

            Text("All set! Lio is ready to go.")
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

/// Full-width blue capsule (Finish / API key step)
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

/// Per-row Enable / Done pill
private struct PermRowButton: ButtonStyle {
    var isGranted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isGranted ? .white : Color.aBlue)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isGranted ? Color.green : Color.clear)
                    .overlay(
                        Capsule()
                            .stroke(isGranted ? Color.clear : Color.aBlue, lineWidth: 1.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Expanding blue capsule — fills remaining HStack space
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

/// Plain text — Deny / ghost actions
private struct GhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15))
            .foregroundColor(.primary.opacity(0.50))
            .frame(height: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
