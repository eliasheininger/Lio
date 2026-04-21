import AppKit
import SwiftUI

// MARK: - Cursor state (drives SwiftUI view)

final class CursorState: ObservableObject {
    @Published var position:    CGPoint  = .zero  // SwiftUI coords (top-left origin, Y down)
    @Published var rotation:    Double   = 0.0    // degrees; 0 = tip points up
    @Published var flightScale: CGFloat  = 1.0    // peaks at ~1.25 at arc midpoint
    @Published var glowRadius:  CGFloat  = 0.0    // blue glow radius; 0 at rest
    @Published var clickCount:  Int      = 0      // increment to trigger pulse ring
}

// MARK: - Full-screen overlay window

/// Single full-screen transparent window that renders the cursor via SwiftUI `.position()`.
/// Animates along a quadratic Bezier arc — direction tilt, scale pulse, and glow are all
/// driven by the arc tangent and a sin-curve keyed to flight progress.
final class CursorOverlayWindow: NSWindow {

    let cursorState = CursorState()
    private var flightTimer: Timer?
    private var screenHeight: CGFloat = NSScreen.main?.frame.height ?? 900

    init() {
        let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        super.init(
            contentRect: screen,
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       false
        )
        screenHeight       = screen.height
        backgroundColor    = .clear
        isOpaque           = false
        hasShadow          = false
        level              = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        ignoresMouseEvents = true
        hidesOnDeactivate  = false

        let host = NSHostingView(rootView: CursorScreenView(state: cursorState))
        host.frame = CGRect(origin: .zero, size: screen.size)
        contentView = host
    }

    // MARK: - Public API (same surface as before)

    func show() {
        let mouse = NSEvent.mouseLocation
        cursorState.position = appKitToSwiftUI(mouse)
        orderFrontRegardless()
    }

    func hide() {
        flightTimer?.invalidate()
        flightTimer = nil
        orderOut(nil)
    }

    /// Animate the cursor along a Bezier arc to `screenPoint` (AppKit bottom-left coords),
    /// then call `completion`. Matches the existing call-site API in BrainEngine.
    func animateTo(screenPoint: CGPoint, completion: @escaping () -> Void) {
        let target = appKitToSwiftUI(screenPoint)
        let start  = cursorState.position

        let dx = target.x - start.x
        let dy = target.y - start.y
        let distance = hypot(dx, dy)

        // Very short moves: snap immediately
        guard distance > 8 else {
            cursorState.position = target
            completion()
            return
        }

        // Duration: slightly slower for a more deliberate, weighted feel
        let duration    = min(max(distance / 700.0, 0.30), 0.65)
        let totalFrames = max(1, Int(duration * 60.0))
        var frame       = 0

        // Control point: arc perpendicular to the flight direction
        let midX      = (start.x + target.x) / 2
        let midY      = (start.y + target.y) / 2
        let arcHeight = min(distance * 0.15, 45.0)
        let perpX     = -dy / distance * arcHeight
        let perpY     =  dx / distance * arcHeight
        let control   = CGPoint(x: midX + perpX, y: midY + perpY)

        flightTimer?.invalidate()
        flightTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            frame += 1

            if frame > totalFrames {
                timer.invalidate()
                self.flightTimer = nil
                self.cursorState.position    = target
                self.cursorState.rotation    = 0
                self.cursorState.flightScale = 1.0
                self.cursorState.glowRadius  = 0
                completion()
                return
            }

            let linear = Double(frame) / Double(totalFrames)
            // Smoothstep (Hermite) easing: 3t² − 2t³
            let t = linear * linear * (3.0 - 2.0 * linear)
            let u = 1.0 - t

            // Quadratic Bezier position: B(t) = u²P0 + 2utP1 + t²P2
            let bx = u*u*start.x + 2*u*t*control.x + t*t*target.x
            let by = u*u*start.y + 2*u*t*control.y + t*t*target.y

            // Tangent direction → rotation (cursor tip points up at 0°, so offset −90°)
            let tx = 2*u*(control.x - start.x) + 2*t*(target.x - control.x)
            let ty = 2*u*(control.y - start.y) + 2*t*(target.y - control.y)
            let angle = atan2(ty, tx) * (180.0 / .pi) - 90.0

            // Sin-curve peaks at midpoint: scale up 25%, glow up to 10pt radius
            let pulse = sin(linear * .pi)

            self.cursorState.position    = CGPoint(x: bx, y: by)
            self.cursorState.rotation    = angle
            self.cursorState.flightScale = CGFloat(1.0 + pulse * 0.25)
            self.cursorState.glowRadius  = CGFloat(pulse * 10.0)
        }
        RunLoop.main.add(flightTimer!, forMode: .common)
    }

    func animateClick() {
        DispatchQueue.main.async { [weak self] in
            self?.cursorState.clickCount += 1
        }
    }

    // MARK: - Coordinate conversion

    /// AppKit (bottom-left origin, Y-up) → SwiftUI (top-left origin, Y-down)
    private func appKitToSwiftUI(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: screenHeight - p.y)
    }
}

// MARK: - Full-screen cursor SwiftUI view

private struct CursorScreenView: View {
    @ObservedObject var state: CursorState

    @State private var pulseScale:   CGFloat = 0.6
    @State private var pulseOpacity: Double  = 0.0
    /// Gentle vertical idle float: oscillates ±4 pt continuously.
    @State private var floatOffset:  CGFloat = -4

    var body: some View {
        // Current Y with float applied
        let cursorY = state.position.y + floatOffset

        ZStack {
            // Click pulse ring — expands outward and fades on each click
            Circle()
                .stroke(Color.aBlue.opacity(0.50), lineWidth: 2.5)
                .frame(width: 42, height: 42)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .position(state.position)

            // Lio badge — floats with the cursor
            LioCursorBadge()
                .position(x: state.position.x + 24, y: cursorY - 28)

            // Cursor arrow
            CursorArrowShape()
                .fill(Color.aBlue)
                .frame(width: 26, height: 26)
                // Permanent floating shadow (depth)
                .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 7)
                // Flight glow
                .shadow(color: Color.aBlue.opacity(0.65), radius: state.glowRadius)
                .rotationEffect(.degrees(state.rotation))
                .scaleEffect(state.flightScale)
                .position(CGPoint(x: state.position.x, y: cursorY))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                floatOffset = 4
            }
        }
        .onChange(of: state.clickCount) { _ in
            pulseScale   = 0.6
            pulseOpacity = 0.85
            withAnimation(.easeOut(duration: 0.45)) {
                pulseScale   = 1.9
                pulseOpacity = 0.0
            }
        }
    }
}

// MARK: - Lio cursor badge

private struct LioCursorBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            if let img = lioMenuNSImage(size: 11) {
                Image(nsImage: img)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 11)
                    .foregroundColor(.white)
            }
            Text("Lio")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.aBlue.opacity(0.88))
        )
    }
}

// MARK: - Cursor arrow shape (cursor2.svg geometry)

private struct CursorArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // Left triangle
        p.move(to:    CGPoint(x: w * 0.4931, y: h * 0.0604))
        p.addLine(to: CGPoint(x: w * 0.4349, y: h * 0.8800))
        p.addLine(to: CGPoint(x: w * 0.0000, y: h * 0.8991))
        p.closeSubpath()
        // Right triangle
        p.move(to:    CGPoint(x: w * 0.4925, y: h * 0.0595))
        p.addLine(to: CGPoint(x: w * 0.5507, y: h * 0.8793))
        p.addLine(to: CGPoint(x: w * 0.9856, y: h * 0.8983))
        p.closeSubpath()
        return p
    }
}
