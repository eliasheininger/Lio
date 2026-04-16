import AppKit
import Foundation

/// Drives the Lio agentic loop: screenshot → Claude (multimodal) → action → repeat.
@MainActor
final class BrainEngine {
    private let client  = AnthropicClient()
    private let screen  = ScreenEngine()
    private let mouse   = MouseSimulator()
    private let cursor: CursorOverlayWindow
    private let state:  AppState

    private let model     = "claude-opus-4-6"
    private let maxTokens = 4096
    private let maxIter   = 10

    /// Signature of the last executed tool call (name + serialized inputs).
    /// Used for stall detection — if Claude repeats the exact same action, we inject a warning.
    private var lastToolSignature: String? = nil

    init(state: AppState, cursor: CursorOverlayWindow) {
        self.state  = state
        self.cursor = cursor
    }

    func run(instruction: String) async {
        lastToolSignature = nil
        cursor.show()

        // Initial screenshot
        let initialCapture: CaptureResult
        do {
            initialCapture = try await screen.captureWindow()
        } catch ScreenCaptureError.permissionDenied, ScreenCaptureError.requiresMacOS14 {
            cursor.hide()
            state.phase = .error(message: "Screen Recording permission needed")
            scheduleReset()
            return
        } catch {
            cursor.hide()
            state.phase = .error(message: error.localizedDescription)
            scheduleReset()
            return
        }

        var capture = initialCapture

        // Build initial message: screenshot + user instruction
        var messages: [Message] = [
            Message(role: "user", content: .blocks([
                .image(ImageBlock(source: ImageSource(mediaType: "image/jpeg", data: capture.base64JPEG))),
                .text(TextBlock(text: instruction))
            ]))
        ]

        var steps: [StepItem] = []
        var completedCount = 0

        for _ in 0..<maxIter {
            let req = MessagesRequest(
                model:     model,
                maxTokens: maxTokens,
                system:    LIO_SYSTEM_PROMPT,
                tools:     LIO_TOOLS,
                messages:  messages
            )

            let response: MessagesResponse
            do {
                response = try await client.send(req)
            } catch {
                cursor.hide()
                state.phase = .error(message: error.localizedDescription)
                scheduleReset()
                return
            }

            var assistantBlocks: [ContentBlock] = []
            var toolResultBlocks: [ContentBlock] = []
            var hasToolUse = false

            for block in response.content {
                switch block {
                case .text(let t):
                    assistantBlocks.append(.text(TextBlock(text: t)))
                    if response.stopReason == "end_turn" {
                        state.phase = .progress(steps: steps, completedCount: completedCount, summary: t)
                    }

                case .toolUse(let id, let name, let input):
                    hasToolUse = true
                    assistantBlocks.append(.toolUse(ToolUseBlock(id: id, name: name, input: input)))

                    // Stall detection — if Claude repeats the exact same action, warn it
                    let signature = toolSignature(name: name, input: input)
                    let isStalled = signature == lastToolSignature
                    lastToolSignature = signature

                    let label = toolLabel(name: name, input: input)
                    steps.append(StepItem(text: label, completed: false))
                    state.phase = .progress(steps: steps, completedCount: completedCount, summary: "")

                    // Execute the action
                    var result = await executeTool(name: name, input: input, capture: capture)

                    if isStalled {
                        result += "\n\nWARNING: This exact action was already tried and had no visible effect. You MUST try a completely different approach — use run_command, a different coordinate, or a different tool."
                        NSLog("[BrainEngine] Stall detected for: \(signature)")
                    }

                    // Mark step complete
                    if let idx = steps.indices.last {
                        steps[idx] = StepItem(text: label, completed: true)
                        completedCount += 1
                    }
                    state.phase = .progress(steps: steps, completedCount: completedCount, summary: "")

                    // Wait for UI to settle — longer after shortcuts/commands that open windows
                    let waitMs: UInt64 = (name == "run_command" || name == "press_shortcut") ? 900 : 400
                    try? await Task.sleep(for: .milliseconds(waitMs))
                    if let newCapture = try? await screen.captureWindow() {
                        capture = newCapture
                    }

                    // Tool result + new screenshot as next user turn
                    toolResultBlocks.append(.toolResult(ToolResultBlock(toolUseId: id, content: result)))
                    toolResultBlocks.append(.image(ImageBlock(source: ImageSource(mediaType: "image/jpeg", data: capture.base64JPEG))))
                    toolResultBlocks.append(.text(TextBlock(text: "Updated screenshot after action.")))

                case .unknown:
                    break
                }
            }

            messages.append(Message(role: "assistant", content: .blocks(assistantBlocks)))

            if hasToolUse && !toolResultBlocks.isEmpty {
                messages.append(Message(role: "user", content: .blocks(toolResultBlocks)))
            }

            if !hasToolUse || response.stopReason == "end_turn" {
                break
            }
        }

        cursor.hide()

        let summary: String
        if case .progress(_, _, let m) = state.phase, !m.isEmpty {
            summary = m
        } else {
            summary = "Done"
        }
        state.phase = .success(message: summary)
        scheduleReset()
    }

    // MARK: - Tool execution

    private func executeTool(name: String, input: [String: AnyCodable], capture: CaptureResult) async -> String {
        switch name {
        case "click":
            let apiX = (input["x"]?.value as? Double) ?? (input["x"]?.value as? Int).map(Double.init) ?? 0
            let apiY = (input["y"]?.value as? Double) ?? (input["y"]?.value as? Int).map(Double.init) ?? 0
            // Guard against (0,0) — Claude returns this when confused; clicking there is always wrong
            guard apiX > 1 || apiY > 1 else {
                return "ERROR: Refused to click at (0,0). The target element is not visible. Use run_command to open the app, or describe what you see."
            }
            let apiPoint  = CGPoint(x: apiX, y: apiY)
            let quartzPt  = apiToScreen(apiPoint, capture)           // Quartz coords for CGEvent
            let appKitPt  = quartzToAppKit(quartzPt)                 // AppKit coords for NSWindow
            NSLog("[BrainEngine] click: api=(\(Int(apiX)),\(Int(apiY))) → quartz=(\(Int(quartzPt.x)),\(Int(quartzPt.y)))")
            // Animate cursor badge (AppKit frame coords), then fire CGEvent (Quartz coords)
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                cursor.animateTo(screenPoint: appKitPt) { cont.resume() }
            }
            await mouse.click(at: quartzPt)
            return "Clicked at (\(Int(quartzPt.x)), \(Int(quartzPt.y)))"

        case "type":
            let text = input["text"]?.value as? String ?? ""
            NSLog("[BrainEngine] type: \"\(text.prefix(40))\"")
            await mouse.type(text: text)
            let preview = text.count > 30 ? String(text.prefix(30)) + "…" : text
            return "Typed \"\(preview)\""

        case "scroll":
            let apiX  = (input["x"]?.value as? Double) ?? (input["x"]?.value as? Int).map(Double.init) ?? 0
            let apiY  = (input["y"]?.value as? Double) ?? (input["y"]?.value as? Int).map(Double.init) ?? 0
            let delta = input["delta"]?.value as? Int ?? -3
            let quartzPt = apiToScreen(CGPoint(x: apiX, y: apiY), capture)
            NSLog("[BrainEngine] scroll: delta=\(delta) quartz=(\(Int(quartzPt.x)),\(Int(quartzPt.y)))")
            await mouse.scroll(at: quartzPt, delta: delta)
            return "Scrolled \(delta > 0 ? "up" : "down") at (\(Int(quartzPt.x)), \(Int(quartzPt.y)))"

        case "press_shortcut":
            let shortcut = input["shortcut"]?.value as? String ?? ""
            NSLog("[BrainEngine] press_shortcut: \(shortcut)")
            await mouse.pressShortcut(shortcut)
            return "Pressed \(shortcut)"

        case "run_command":
            let command = input["command"]?.value as? String ?? ""
            NSLog("[BrainEngine] run_command: \(command)")
            let output = await runShellCommand(command)
            return "Ran: \(command)\nOutput: \(output.isEmpty ? "(none)" : output)"

        default:
            return "Unknown tool: \(name)"
        }
    }

    private func runShellCommand(_ command: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]
                let pipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = pipe
                process.standardError = errPipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let err = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let combined = [out, err].filter { !$0.isEmpty }.joined(separator: "\n")
                    continuation.resume(returning: combined)
                } catch {
                    continuation.resume(returning: "Error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Coordinate conversion

    /// Converts API image coordinates (top-left origin, pixels) to Quartz/CGEvent screen
    /// coordinates (top-left origin, points). CGEvent and CGWindowList both use Quartz coords.
    /// NSWindow frames use AppKit coords (bottom-left origin) — convert separately for the cursor.
    private func apiToScreen(_ apiPoint: CGPoint, _ cap: CaptureResult) -> CGPoint {
        let scaleX = cap.windowSizePoints.width  / cap.apiImageSize.width
        let scaleY = cap.windowSizePoints.height / cap.apiImageSize.height

        // The captured display's top-left in Quartz coords is (0, 0) for the primary display.
        // Image Y and Quartz Y both increase downward, so this is a straight scale — no inversion.
        let quartzX = cap.windowOriginTopLeft.x + apiPoint.x * scaleX
        let quartzY = cap.windowOriginTopLeft.y + apiPoint.y * scaleY

        return CGPoint(x: quartzX, y: quartzY)
    }

    /// Converts Quartz/CGEvent coordinates to AppKit/NSWindow frame coordinates (bottom-left origin).
    /// Used only for positioning the CursorOverlayWindow, which sets NSWindow frames.
    private func quartzToAppKit(_ quartzPoint: CGPoint) -> CGPoint {
        let screenH = NSScreen.main?.frame.height ?? quartzPoint.y
        return CGPoint(x: quartzPoint.x, y: screenH - quartzPoint.y)
    }

    // MARK: - Helpers

    private func scheduleReset() {
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            state.phase = .idle
        }
    }

    /// Stable string identifying a tool call for stall detection.
    private func toolSignature(name: String, input: [String: AnyCodable]) -> String {
        let sorted = input.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.value)" }
            .joined(separator: ",")
        return "\(name):\(sorted)"
    }

    private func toolLabel(name: String, input: [String: AnyCodable]) -> String {
        switch name {
        case "click":
            let x = (input["x"]?.value as? Double) ?? (input["x"]?.value as? Int).map(Double.init) ?? 0
            let y = (input["y"]?.value as? Double) ?? (input["y"]?.value as? Int).map(Double.init) ?? 0
            return "Clicking at (\(Int(x)), \(Int(y)))"
        case "type":
            let txt = input["text"]?.value as? String ?? ""
            let preview = txt.count > 20 ? String(txt.prefix(20)) + "…" : txt
            return "Typing \"\(preview)\""
        case "scroll":
            let delta = input["delta"]?.value as? Int ?? 0
            return "Scrolling \(delta > 0 ? "up" : "down")"
        case "press_shortcut":
            let s = input["shortcut"]?.value as? String ?? ""
            return "Shortcut \(s)"
        case "run_command":
            let cmd = input["command"]?.value as? String ?? ""
            let preview = cmd.count > 30 ? String(cmd.prefix(30)) + "…" : cmd
            return "Running \(preview)"
        default:
            return name
        }
    }
}
