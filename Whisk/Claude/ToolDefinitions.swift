import Foundation

let TOOLS: [ToolSchema] = [
    ToolSchema(
        name: "list_apps",
        description: "List all running GUI applications with their PID and bundle ID.",
        inputSchema: InputSchema(properties: [:], required: [])
    ),
    ToolSchema(
        name: "open_app",
        description: "Open a macOS application by name (e.g. 'Safari', 'Finder').",
        inputSchema: InputSchema(
            properties: ["app_name": PropertySchema(type: "string", description: "The app name")],
            required: ["app_name"]
        )
    ),
    ToolSchema(
        name: "focus_app",
        description: "Bring a running application to the foreground.",
        inputSchema: InputSchema(
            properties: ["app_name": PropertySchema(type: "string", description: "The app name")],
            required: ["app_name"]
        )
    ),
    ToolSchema(
        name: "open_folder",
        description: "Open a folder path in Finder using the Go to Folder shortcut.",
        inputSchema: InputSchema(
            properties: ["path": PropertySchema(type: "string", description: "Absolute or ~ path")],
            required: ["path"]
        )
    ),
    ToolSchema(
        name: "list_buttons",
        description: "List all clickable buttons in the given app (by PID).",
        inputSchema: InputSchema(
            properties: ["pid": PropertySchema(type: "integer", description: "Process ID")],
            required: ["pid"]
        )
    ),
    ToolSchema(
        name: "press_button",
        description: "Click a button by label in the given app (by PID).",
        inputSchema: InputSchema(
            properties: [
                "pid":   PropertySchema(type: "integer", description: "Process ID"),
                "label": PropertySchema(type: "string",  description: "Button title or description"),
            ],
            required: ["pid", "label"]
        )
    ),
    ToolSchema(
        name: "inspect_focused",
        description: "Return all AX attributes of the currently focused UI element in the given app.",
        inputSchema: InputSchema(
            properties: ["pid": PropertySchema(type: "integer", description: "Process ID")],
            required: ["pid"]
        )
    ),
    ToolSchema(
        name: "type_text",
        description: "Type text into the currently focused input field (uses clipboard + Cmd+V).",
        inputSchema: InputSchema(
            properties: ["text": PropertySchema(type: "string", description: "Text to type")],
            required: ["text"]
        )
    ),
    ToolSchema(
        name: "press_tab",
        description: "Press the Tab key to move focus to the next field.",
        inputSchema: InputSchema(properties: [:], required: [])
    ),
    ToolSchema(
        name: "press_return",
        description: "Press the Return/Enter key to confirm or submit a form.",
        inputSchema: InputSchema(properties: [:], required: [])
    ),
    ToolSchema(
        name: "open_url",
        description: "Open a URL in the default browser.",
        inputSchema: InputSchema(
            properties: ["url": PropertySchema(type: "string", description: "Full URL including scheme")],
            required: ["url"]
        )
    ),
]

let SYSTEM_PROMPT = """
You are Whisk, a macOS desktop assistant that controls the computer using macOS Accessibility APIs and helps people use their computers handsfree.
The user speaks a voice command and you execute it step by step using the provided tools.

Rules:
- Always call list_apps first to get current PIDs before using pid-based tools.
- Prefer open_url for web searches (use https://www.google.com/search?q=...).
- Use type_text to fill in text fields. For apps that don't accept paste (e.g. Calculator, Terminal), type_text sends real key events so it still works.
- Use press_tab to move between fields, press_return to submit.
- For apps like Calculator: use press_button with the exact button label. Calculator buttons are labelled "0"–"9", "+", "−", "×", "÷", "%", "=", "AC". Use "×" (not *) and "÷" (not /) and "−" (not -).
- Call focus_app before press_button if you are not sure the app is in the foreground.
- After completing the task, respond with a short success message (no tool calls).
- Be concise. The user sees a progress card with each action label.
- If a tool returns ❌, try an alternative (e.g. different label spelling, refocus the app, or use type_text instead).
"""
