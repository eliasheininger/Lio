import AppKit
import SwiftUI

// MARK: - Cursor state (drives SwiftUI animation)

final class CursorState: ObservableObject {
    /// Increment to trigger a click-pulse animation in the view.
    @Published var clickCount: Int = 0
}

// MARK: - Floating cursor window

/// A small floating NSWindow that shows the cursor.svg icon.
/// Animates to click coordinates before each mouse action and pulses on click.
final class CursorOverlayWindow: NSWindow {

    static let size: CGFloat = 52
    let cursorState = CursorState()

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
        // Above .floating so it sits on top of all regular windows
        level              = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        ignoresMouseEvents = true

        let hostView = NSHostingView(rootView: CursorIconView(state: cursorState))
        hostView.frame = CGRect(x: 0, y: 0,
                                width: CursorOverlayWindow.size,
                                height: CursorOverlayWindow.size)
        contentView = hostView
    }

    /// Animate the cursor to `screenPoint` (AppKit bottom-left coords), then call completion.
    func animateTo(screenPoint: CGPoint, completion: @escaping () -> Void) {
        let half = CursorOverlayWindow.size / 2
        let targetFrame = CGRect(
            x: screenPoint.x - half,
            y: screenPoint.y - half,
            width:  CursorOverlayWindow.size,
            height: CursorOverlayWindow.size
        )
        // Always bring to front before animating
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.28
            // Snappy spring-like easing
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.40, 0.64, 1.0)
            animator().setFrame(targetFrame, display: true)
        }, completionHandler: {
            completion()
        })
    }

    /// Trigger a click-pulse ring animation.
    func animateClick() {
        DispatchQueue.main.async { [weak self] in
            self?.cursorState.clickCount += 1
        }
    }

    func show() {
        let mouse = NSEvent.mouseLocation
        let half  = CursorOverlayWindow.size / 2
        setFrameOrigin(CGPoint(x: mouse.x - half, y: mouse.y - half))
        orderFrontRegardless()
    }

    func hide() { orderOut(nil) }
}

// MARK: - Cursor icon view

private struct CursorIconView: View {
    @ObservedObject var state: CursorState

    @State private var pulseScale: CGFloat = 0.6
    @State private var pulseOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Click pulse ring
            Circle()
                .stroke(Color(red: 0.01, green: 0.00, blue: 0.81).opacity(0.55), lineWidth: 2.5)
                .frame(width: 36, height: 36)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)

            CursorSVGImage()
                .frame(width: 26, height: 26)
        }
        .frame(width: CursorOverlayWindow.size, height: CursorOverlayWindow.size)
        .onChange(of: state.clickCount) { _ in
            // Reset, then animate outward + fade
            pulseScale  = 0.6
            pulseOpacity = 0.85
            withAnimation(.easeOut(duration: 0.48)) {
                pulseScale   = 1.9
                pulseOpacity = 0.0
            }
        }
    }
}

// MARK: - Cursor2 shape
// Mirrors cursor2.svg (53×73 viewBox): two triangles forming an upward-pointing arrow.

private struct Cursor2Shape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        // Left triangle  — original coords in 53×73 space, normalised
        p.move(to:    CGPoint(x: w * 0.4931, y: h * 0.0604))  // tip
        p.addLine(to: CGPoint(x: w * 0.4349, y: h * 0.8800))  // inner bottom
        p.addLine(to: CGPoint(x: w * 0.0000, y: h * 0.8991))  // outer bottom-left
        p.closeSubpath()

        // Right triangle
        p.move(to:    CGPoint(x: w * 0.4925, y: h * 0.0595))  // tip
        p.addLine(to: CGPoint(x: w * 0.5507, y: h * 0.8793))  // inner bottom
        p.addLine(to: CGPoint(x: w * 0.9856, y: h * 0.8983))  // outer bottom-right
        p.closeSubpath()

        return p
    }
}

private struct CursorSVGImage: View {
    var body: some View {
        Cursor2Shape()
            .fill(Color(red: 0.01, green: 0.00, blue: 0.81))
    }
}
