import AppKit
import Foundation

/// Drives the Claude agentic loop — replaces ax_brain.py.
/// Calls AnthropicClient, dispatches tool calls to AXRunner, updates AppState.
@MainActor
final class BrainEngine {
    private let client  = AnthropicClient()
    private let runner  = AXRunner()
    private let state: AppState

    private let model     = "claude-opus-4-6"
    private let maxTokens = 4096
    private let maxIter   = 15

    init(state: AppState) { self.state = state }

    func run(instruction: String) async {
        // Prepend last-session context so Claude can skip re-discovery
        var messages: [Message] = []
        if let mem = WhiskMemoryStore.shared.load() {
            let ctx = "[Context from last session] \(mem.contextNote) Last task: \(mem.lastTask)"
            messages.append(Message(role: "user",      content: .text(ctx)))
            messages.append(Message(role: "assistant", content: .text("Understood. I'll use this context.")))
        }
        messages.append(Message(role: "user", content: .text(instruction)))

        // Build steps list for progress card
        var steps: [StepItem] = []
        var completedCount    = 0

        for _ in 0..<maxIter {
            let req = MessagesRequest(
                model:     model,
                maxTokens: maxTokens,
                system:    SYSTEM_PROMPT,
                tools:     TOOLS,
                messages:  messages
            )

            let response: MessagesResponse
            do {
                response = try await client.send(req)
            } catch {
                state.phase = .error(message: error.localizedDescription)
                scheduleReset()
                return
            }

            // Collect assistant blocks to append to messages
            var assistantBlocks: [ContentBlock] = []
            var toolResultBlocks: [ContentBlock] = []
            var hasToolUse = false

            for block in response.content {
                switch block {
                case .text(let t):
                    assistantBlocks.append(.text(TextBlock(text: t)))
                    // Final text from Claude → success
                    if response.stopReason == "end_turn" {
                        state.phase = .progress(
                            steps: steps,
                            completedCount: completedCount,
                            summary: t
                        )
                    }

                case .toolUse(let id, let name, let input):
                    hasToolUse = true
                    assistantBlocks.append(.toolUse(ToolUseBlock(id: id, name: name, input: input)))

                    // Add in-progress step to the live list
                    let label = toolLabel(name: name, input: input)
                    steps.append(StepItem(text: label, completed: false))
                    state.phase = .progress(steps: steps, completedCount: completedCount, summary: "")

                    // Execute tool (with confirmation gate for destructive actions)
                    let rawInput = input.mapValues(\.value)
                    let result: String
                    if let confirmMsg = isCritical(tool: name, inputs: rawInput) {
                        let allowed = await requestConfirmation(message: confirmMsg)
                        if allowed {
                            result = await runner.execute(toolName: name, inputs: rawInput)
                        } else {
                            result = "Action cancelled by user."
                            state.phase = .progress(steps: steps, completedCount: completedCount, summary: "")
                        }
                    } else {
                        result = await runner.execute(toolName: name, inputs: rawInput)
                    }

                    // Mark last step done
                    if let idx = steps.indices.last {
                        steps[idx] = StepItem(text: label, completed: true)
                        completedCount += 1
                    }
                    state.phase = .progress(steps: steps, completedCount: completedCount, summary: "")

                    // Append tool result to next user message
                    toolResultBlocks.append(.toolResult(ToolResultBlock(toolUseId: id, content: result)))

                case .unknown:
                    break
                }
            }

            // Append assistant message
            messages.append(Message(role: "assistant", content: .blocks(assistantBlocks)))

            // If there were tool calls, append all results as one user message
            if hasToolUse && !toolResultBlocks.isEmpty {
                messages.append(Message(role: "user", content: .blocks(toolResultBlocks)))
            }

            // Stop if no more tool calls
            if !hasToolUse || response.stopReason == "end_turn" {
                break
            }
        }

        // Final success
        let summary: String
        if case .progress(let s, let c, let m) = state.phase, !m.isEmpty {
            summary = m
        } else {
            summary = "Done"
        }
        state.phase = .success(message: summary)
        saveMemory(task: instruction, summary: summary)
        scheduleReset()
    }

    // MARK: - Helpers

    private func saveMemory(task: String, summary: String) {
        let frontmost = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        WhiskMemoryStore.shared.save(WhiskMemory(
            lastTask: task,
            frontmostApp: frontmost,
            contextNote: summary
        ))
    }

    private func scheduleReset() {
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            state.phase = .idle
        }
    }

    // MARK: - Safety confirmation

    /// Returns a user-facing warning message if the tool call is potentially destructive,
    /// otherwise returns nil (no confirmation needed).
    private func isCritical(tool: String, inputs: [String: Any]) -> String? {
        func str(_ key: String) -> String { inputs[key] as? String ?? "" }

        switch tool {

        case "press_shortcut":
            let s = str("shortcut").lowercased()
            let destructive = [
                "cmd+q", "command+q",
                "cmd+option+esc",
                "cmd+w", "cmd+option+w",
                "cmd+delete", "cmd+backspace",
                "ctrl+delete", "ctrl+backspace"
            ]
            if destructive.contains(where: { s.contains($0) }) {
                return "Whisk wants to press \(str("shortcut")).\nThis may close or quit something."
            }

        case "press_button", "click_element":
            let raw = str("label").isEmpty ? str("query") : str("label")
            let label = raw.lowercased()
            let destructiveWords = [
                "delete", "remove", "trash", "move to trash",
                "close", "close all", "discard", "discard changes", "don't save", "dont save",
                "quit", "force quit", "terminate", "kill",
                "overwrite", "replace", "replace all",
                "uninstall", "erase", "format", "reset", "clear all", "wipe"
            ]
            if destructiveWords.contains(where: { label.contains($0) }) {
                return "Whisk wants to click \"\(raw)\".\nThis action may be irreversible."
            }

        default: break
        }
        return nil
    }

    /// Suspends the agentic loop, shows a confirmation card, and resumes when the user responds.
    private func requestConfirmation(message: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            state.permissionHandlers = (
                accept: { continuation.resume(returning: true) },
                deny:   { continuation.resume(returning: false) }
            )
            state.phase = .permission(
                app: "Confirm Action",
                message: message,
                acceptLabel: "Allow",
                denyLabel: "Cancel"
            )
        }
    }

    private func toolLabel(name: String, input: [String: AnyCodable]) -> String {
        switch name {
        case "list_apps":      return "Listing apps"
        case "open_app":       return "Opening \(input["app_name"]?.value as? String ?? "app")"
        case "focus_app":      return "Focusing \(input["app_name"]?.value as? String ?? "app")"
        case "open_folder":    return "Opening folder"
        case "list_buttons":   return "Listing buttons"
        case "press_button":   return "Clicking \(input["label"]?.value as? String ?? "button")"
        case "inspect_focused":return "Inspecting element"
        case "type_text":
            let txt = input["text"]?.value as? String ?? ""
            let preview = txt.count > 20 ? String(txt.prefix(20)) + "…" : txt
            return "Typing \"\(preview)\""
        case "press_tab":      return "Pressing Tab"
        case "press_return":   return "Pressing Return"
        case "open_url":       return "Opening URL"
        case "find_elements":  return "Searching for \(input["query"]?.value as? String ?? "elements")"
        case "scroll":         return "Scrolling \(input["direction"]?.value as? String ?? "")"
        case "click_element":  return "Clicking \(input["query"]?.value as? String ?? "element")"
        case "press_space":    return "Pressing Space"
        case "shift_tab":      return "Tabbing backward"
        case "press_shortcut": return "Shortcut \(input["shortcut"]?.value as? String ?? "")"
        case "get_focused":    return "Checking focus"
        case "tab_to":         return "Navigating to \(input["query"]?.value as? String ?? "element")"
        default:               return name
        }
    }
}
