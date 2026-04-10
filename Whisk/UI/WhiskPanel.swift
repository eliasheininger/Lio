import AppKit

/// Floating non-activating borderless panel — identical character to the current widget.
final class WhiskPanel: NSPanel {

    init(contentNSView: NSView) {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let origin = CGPoint(
            x: screen.minX + (screen.width - PANEL_W) / 2,
            y: screen.minY + 24
        )
        super.init(
            contentRect: CGRect(origin: origin, size: CGSize(width: PANEL_W, height: PILL_H)),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        level              = .floating
        backgroundColor    = .clear
        isOpaque           = false
        hasShadow          = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let wrapper = DragView(frame: CGRect(origin: .zero,
                                             size: CGSize(width: PANEL_W, height: PILL_H)),
                               panel: self)
        wrapper.autoresizingMask    = [.width, .height]
        contentNSView.frame         = wrapper.bounds
        contentNSView.autoresizingMask = [.width, .height]
        wrapper.addSubview(contentNSView)
        contentView = wrapper
    }

    /// Animate height while keeping the bottom edge fixed.
    func animateHeight(to h: CGFloat) {
        guard abs(frame.height - h) > 0.5 else { return }
        var f = frame
        f.size.height = h
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration       = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(f, display: true)
        }
    }
}

// MARK: - Drag handle

private final class DragView: NSView {
    weak var panel: NSPanel?

    init(frame: CGRect, panel: NSPanel) {
        self.panel = panel
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with e: NSEvent)       { panel?.performDrag(with: e) }
    override func hitTest(_ p: NSPoint) -> NSView? { self }

    override func rightMouseDown(with e: NSEvent) {
        let m = NSMenu()
        m.addItem(withTitle: "Quit Whisk", action: #selector(quit), keyEquivalent: "q")
        NSMenu.popUpContextMenu(m, with: e, for: self)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
