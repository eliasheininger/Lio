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
    ToolSchema(
        name: "find_elements",
        description: "Search all UI elements in an app by fuzzy text match. Returns up to 10 results with role, label, and match score. Use before click_element when you're unsure of the exact label.",
        inputSchema: InputSchema(
            properties: [
                "pid":   PropertySchema(type: "integer", description: "Process ID"),
                "query": PropertySchema(type: "string",  description: "Text to search for"),
                "role":  PropertySchema(type: "string",  description: "Optional AX role filter, e.g. AXButton, AXTextField"),
            ],
            required: ["pid", "query"]
        )
    ),
    ToolSchema(
        name: "scroll",
        description: "Scroll the focused window in the given app up or down by a number of lines.",
        inputSchema: InputSchema(
            properties: [
                "pid":       PropertySchema(type: "integer", description: "Process ID"),
                "direction": PropertySchema(type: "string",  description: "\"up\" or \"down\""),
                "amount":    PropertySchema(type: "integer",  description: "Number of lines (default 3)"),
            ],
            required: ["pid", "direction"]
        )
    ),
    ToolSchema(
        name: "click_element",
        description: "Click a UI element by fuzzy label match, with 3-step fallback: AXPress → focus+AXPress → mouse click at element center. More reliable than press_button for non-button elements.",
        inputSchema: InputSchema(
            properties: [
                "pid":   PropertySchema(type: "integer", description: "Process ID"),
                "query": PropertySchema(type: "string",  description: "Label or text to match"),
                "role":  PropertySchema(type: "string",  description: "Optional AX role filter"),
            ],
            required: ["pid", "query"]
        )
    ),
    ToolSchema(
        name: "press_space",
        description: "Press Space to activate the currently focused button, checkbox, or toggle.",
        inputSchema: InputSchema(properties: [:], required: [])
    ),
    ToolSchema(
        name: "shift_tab",
        description: "Press Shift+Tab to move focus to the previous focusable element.",
        inputSchema: InputSchema(properties: [:], required: [])
    ),
    ToolSchema(
        name: "press_shortcut",
        description: "Send a keyboard shortcut such as \"cmd+a\", \"cmd+shift+z\", \"ctrl+c\". Modifiers: cmd, shift, ctrl, alt/opt. Keys: a–z, 0–9, tab, return, space, escape, delete, up, down, left, right.",
        inputSchema: InputSchema(
            properties: ["shortcut": PropertySchema(type: "string", description: "e.g. \"cmd+a\", \"shift+tab\", \"cmd+t\"")],
            required: ["shortcut"]
        )
    ),
    ToolSchema(
        name: "get_focused",
        description: "Return the role, title, description, value, and enabled state of the currently focused UI element in the given app.",
        inputSchema: InputSchema(
            properties: ["pid": PropertySchema(type: "integer", description: "Process ID")],
            required: ["pid"]
        )
    ),
    ToolSchema(
        name: "tab_to",
        description: "Tab forward (or backward) through focusable elements until one matching 'query' is focused, then stop. Returns matched element info. Use instead of manually looping press_tab + get_focused.",
        inputSchema: InputSchema(
            properties: [
                "pid":       PropertySchema(type: "integer", description: "Process ID"),
                "query":     PropertySchema(type: "string",  description: "Label/title to search for"),
                "direction": PropertySchema(type: "string",  description: "\"forward\" (default) or \"backward\""),
                "max_tabs":  PropertySchema(type: "integer", description: "Max tabs to try (default 15)"),
            ],
            required: ["pid", "query"]
        )
    ),
]

let SYSTEM_PROMPT = """
You are Whisk, a macOS desktop assistant that controls the computer using macOS Accessibility APIs.
The user speaks a voice command; execute it step by step using the provided tools.

## App discovery
- Call list_apps to get PIDs only when you need to interact with a specific app and don't already know its PID from context or memory.
- If the command is purely keyboard-based (text replacement, shortcuts, navigation in the active window), skip list_apps entirely.

## Common patterns — use these first, no discovery needed
- Replace text in a focused/visible field: press_shortcut("cmd+a") → type_text(replacement) → press_return
- A dropdown is open with autocomplete suggestions: type_text(new text) to overwrite, then press_return or click the desired suggestion
- Clear a field: press_shortcut("cmd+a") → press_shortcut("delete")
- Submit a form or confirm a dialog: press_return
- Activate the focused button / checkbox / toggle: press_space

## Keyboard navigation (preferred for standard apps)
- Use tab_to to reach a field or button by name — it tabs and inspects automatically.
- Use press_space to activate the currently focused element.
- Use shift_tab or tab_to with direction "backward" to go backwards.
- Use press_shortcut for: "cmd+t" (new tab), "cmd+w" (close tab), "cmd+a" (select all), "cmd+c" (copy), "cmd+v" (paste), "cmd+z" (undo), "cmd+n" (new window).
- Use get_focused to check what is focused before acting on it.

## When to use keyboard vs AX tools
- Prefer keyboard (tab_to → press_space) for: forms, dialogs, standard app buttons.
- Use press_button for Calculator (labels "0"–"9", "+", "−", "×", "÷", "%", "=", "AC").
- Prefer open_url for web searches (https://www.google.com/search?q=...).
- Fall back to click_element only when tab_to returns ⚠️ not found or the app has no tab order.

## Retry logic
- If a keyboard approach fails (❌), try the AX click fallback once.
- After 2 consecutive failures on the same action, report the error — do not loop.

## Context and memory
- If a [Context from last session] message is present, use it to skip re-discovery of already-open apps and UI state.
- End your final success message with one sentence describing the current UI state (e.g. "Google Flights is open in Safari with Munich as origin."). This becomes memory for the next command.

After completing the task, respond with a short success message (no tool calls).
Be concise. The user sees a progress card with each step label.
"""
