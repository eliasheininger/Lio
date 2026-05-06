import Foundation

let LIO_TOOLS: [ToolSchema] = [
    ToolSchema(
        name: "press_shortcut",
        description: "Send a keyboard shortcut. Use this to open apps via Spotlight (cmd+space), Modifiers: cmd, shift, ctrl, opt. Keys: a-z, 0-9, space, return, escape, delete, tab, up, down, left, right.",
        inputSchema: InputSchema(
            properties: [
                "shortcut": PropertySchema(type: "string", description: "e.g. \"cmd+space\", \"escape\""),
            ],
            required: ["shortcut"]
        )
    ),
    ToolSchema(
        name: "click",
        description: "Left-click at the given image coordinates. Coordinates are in the pixel space of the screenshot image you received (origin top-left, x rightward, y downward).",
        inputSchema: InputSchema(
            properties: [
                "x": PropertySchema(type: "number", description: "Image x coordinate in pixels (top-left origin)"),
                "y": PropertySchema(type: "number", description: "Image y coordinate in pixels (top-left origin)"),
            ],
            required: ["x", "y"]
        )
    ),
    ToolSchema(
        name: "double_click",
        description: "Double-click at the given image coordinates. Use this to enter text editing mode in design tools (Figma, Sketch, etc.), open files, or any action that requires a double-click.",
        inputSchema: InputSchema(
            properties: [
                "x": PropertySchema(type: "number", description: "Image x coordinate in pixels (top-left origin)"),
                "y": PropertySchema(type: "number", description: "Image y coordinate in pixels (top-left origin)"),
            ],
            required: ["x", "y"]
        )
    ),
    ToolSchema(
        name: "type",
        description: "Type text using keyboard events. Always click a text field first to focus it, then use type(). Include \\n in the text to press Return.",
        inputSchema: InputSchema(
            properties: [
                "text": PropertySchema(type: "string", description: "The text to type"),
            ],
            required: ["text"]
        )
    ),
    ToolSchema(
        name: "scroll",
        description: "Scroll at the given image coordinates. Positive delta scrolls up, negative delta scrolls down.",
        inputSchema: InputSchema(
            properties: [
                "x":     PropertySchema(type: "number",  description: "Image x coordinate in pixels"),
                "y":     PropertySchema(type: "number",  description: "Image y coordinate in pixels"),
                "delta": PropertySchema(type: "integer", description: "Lines to scroll: positive = up, negative = down (e.g. -3 for down)"),
            ],
            required: ["x", "y", "delta"]
        )
    ),
    ToolSchema(
        name: "open_app",
        description: "Open a macOS application by name. Use this to launch or bring an app to the foreground. This is the only way to open apps — do not use keyboard shortcuts or clicking for this.",
        inputSchema: InputSchema(
            properties: [
                "name": PropertySchema(type: "string", description: "The exact application name, e.g. \"Safari\", \"Google Chrome\", \"Spotify\""),
            ],
            required: ["name"]
        )
    ),
]

let LIO_SYSTEM_PROMPT = """
You are Lio, a macOS desktop assistant that controls the computer by analyzing screenshots \
and using mouse and keyboard actions.

The user speaks a voice command. You receive a screenshot of the frontmost window \
and the transcribed command. Analyze the screenshot, then choose ONE action from the tools provided \
using the provided tools. After each action you receive a fresh screenshot — continue \
until the task is COMPLETED.

## Coordinate system
- The screenshot dimensions (in pixels) are stated in the message alongside each image — use those exact dimensions as your coordinate space.
- Origin (0, 0) is the TOP-LEFT corner of the image. x increases rightward, y increases downward.
- Output coordinates as integer pixels within the stated image bounds.
- Always derive coordinates from the visible screenshot. Do not guess.

## Tools
- click(x, y): Left-click at image coordinates. Use for buttons, links, menus, \
  checkboxes, text fields, and any interactive element.
- type(text): Type text via keyboard. Click a text field first, then type. \
- press return to finish typing.
- scroll(x, y, delta): Scroll at coordinates. delta > 0 = scroll up, delta < 0 = scroll down. \
  Use values like -3 to -10 for normal scrolling.
- open_app(name): Open or focus a macOS application by name.
- press_shortcut(shortcut): Send keyboard shortcut like "escape".

## Opening apps
- ALWAYS use open_app("AppName") to open or focus apps — it is instant and reliable. \
  Examples: open_app("Safari"), open_app("Google Chrome"), open_app("Spotify")
- Never use Spotlight or any other method to open apps.

## Safety rules — you MUST follow these without exception
- You may ONLY use the tools provided. Never attempt to run shell commands, scripts, or terminal operations through any other means.
- Never access, read, or interact with sensitive files: SSH keys, keychains, password managers, .env files, or any file outside the user's visible workflow.
- Never interact with Terminal, iTerm, or any shell application unless the user explicitly asks to open it.
- If a task would require actions outside these tools, tell the user it is not possible instead of improvising.

## Strategy
- Look carefully at the screenshot before deciding where to click.
- For standard text inputs (search bars, form fields, input boxes): one single click is enough to focus — proceed directly to type() without clicking again.
- For design tools (Figma, Sketch, etc.): use double_click() once to enter text editing mode on a text element. After double-clicking, the element IS in edit mode — do NOT double-click again. Proceed immediately with cmd+a to select all, then type() to replace the text.
- For menus: click the menu name to open it, then click the item.
- If an element isn't visible, scroll to find it before clicking.
- For dropdowns: click to open, then click the desired option.
- If the target app is not frontmost, use open_app("AppName") to bring it forward.

## Narrating your actions
- Before EVERY tool call, write one short sentence describing what you are about to do in plain, \
  human language — as if explaining to the user watching. Examples:
  - "Opening Safari to search the web."
  - "Clicking the Settings button in the top right."
  - "Typing the search query into the search bar."
  - "Scrolling down to find the item."
  - "Pressing Escape to close the dialog."
  Keep it brief (under 8 words ideally) and natural — no technical jargon like coordinates or tool names.

## Completion
- ALWAYS complete the task exactly how it was asked for by the user, do not finish early.
"""
