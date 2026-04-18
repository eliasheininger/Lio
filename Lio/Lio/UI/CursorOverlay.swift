import AppKit
import SwiftUI

/// A small floating NSWindow that renders a "second mouse" cursor badge.
/// Animates to click coordinates before each mouse action, making Lio's
/// intentions visible to the user.
final class CursorOverlayWindow: NSWindow {

    private static let size: CGFloat = 44

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0,
                                width: CursorOverlayWindow.size,
                                height: CursorOverlayWindow.size),
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       false
        )
        backgroundColor    = .clear
        isOpaque           = false
        hasShadow          = false
        // One level above the Lio pill so it renders on top
        level              = NSWindow.Level(rawValue: Int(NSWindow.Level.floating.rawValue) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        // Critical: cursor must never eat clicks meant for the target app
        ignoresMouseEvents = true

        let hostView = NSHostingView(rootView: CursorIconView())
        hostView.frame = CGRect(x: 0, y: 0,
                                width: CursorOverlayWindow.size,
                                height: CursorOverlayWindow.size)
        contentView = hostView
    }

    /// Animate the cursor badge center to `screenPoint` (macOS bottom-left coords),
    /// then call `completion` when the animation finishes.
    func animateTo(screenPoint: CGPoint, completion: @escaping () -> Void) {
        let half = CursorOverlayWindow.size / 2
        let targetFrame = CGRect(
            x: screenPoint.x - half,
            y: screenPoint.y - half,
            width:  CursorOverlayWindow.size,
            height: CursorOverlayWindow.size
        )
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.26
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(targetFrame, display: true)
        }, completionHandler: {
            completion()
        })
    }

    func show() {
        // Position at current mouse location so the badge appears where the user's cursor is
        let mouse = NSEvent.mouseLocation
        let half  = CursorOverlayWindow.size / 2
        setFrameOrigin(CGPoint(x: mouse.x - half, y: mouse.y - half))
        orderFrontRegardless()
    }
    func hide() { orderOut(nil) }
}

// MARK: - Cursor icon view

/// Blue circle with a white cursor arrow SF Symbol — resembles a second mouse pointer.
private struct CursorIconView: View {
    var body: some View {
        ZStack {
            // Soft drop shadow
            Circle()
                .fill(Color.black.opacity(0.20))
                .frame(width: 30, height: 30)
                .blur(radius: 4)
                .offset(x: 1, y: -2)

            // Main badge
            Circle()
                .fill(Color.aBlue.opacity(0.88))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                )

            // Cursor icon
            Image(systemName: "cursorarrow")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .offset(x: 1, y: 1)
        }
        .frame(width: 44, height: 44)
    }
}
