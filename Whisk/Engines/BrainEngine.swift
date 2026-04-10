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
        var messages: [Message] = [
            Message(role: "user", content: .text(instruction))
        ]

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

                    // Execute tool
                    let rawInput = input.mapValues(\.value)
                    let result   = await runner.execute(toolName: name, inputs: rawInput)

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
        scheduleReset()
    }

    // MARK: - Helpers

    private func scheduleReset() {
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            state.phase = .idle
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
        default:               return name
        }
    }
}
