import AppKit

/// A full-screen overlay that lets the user drag out a rectangle, replacing
/// the system `screencapture -i` crosshair (which a sandboxed app can't
/// invoke). Returns the chosen region in global screen coordinates
/// (AppKit convention: bottom-left origin).
@MainActor
final class SelectionOverlay {
    private var window: SelectionWindow?

    /// Presents the overlay on the main display and resolves with the dragged
    /// rectangle. Throws `ScanError.cancelled` on Escape, an empty drag, or a
    /// plain click.
    func selectRegion() async throws -> CGRect {
        guard let screen = NSScreen.main else { throw ScanError.captureFailed }

        let rect: CGRect? = await withCheckedContinuation { continuation in
            let window = SelectionWindow(screen: screen) { result in
                continuation.resume(returning: result)
            }
            self.window = window
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }

        window?.orderOut(nil)
        window = nil

        guard let rect, rect.width >= 4, rect.height >= 4 else {
            throw ScanError.cancelled
        }
        // Convert window-local rect to global screen coordinates.
        return rect.offsetBy(dx: screen.frame.origin.x, dy: screen.frame.origin.y)
    }
}

/// Borderless transparent window that hosts the selection view. Subclassed so
/// it can become key (borderless windows can't by default) and receive the
/// Escape key.
private final class SelectionWindow: NSWindow {
    init(screen: NSScreen, completion: @escaping (CGRect?) -> Void) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        contentView = SelectionView(completion: completion)
    }

    override var canBecomeKey: Bool { true }
}

/// Draws a dimmed backdrop with a clear "punch-out" for the live selection and
/// reports the final rectangle (in its own coordinate space) on mouse-up.
private final class SelectionView: NSView {
    private let completion: (CGRect?) -> Void
    private var origin: NSPoint?
    private var current: NSRect = .zero
    private var finished = false

    init(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        origin = convert(event.locationInWindow, from: nil)
        current = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin else { return }
        let point = convert(event.locationInWindow, from: nil)
        current = NSRect(
            x: min(origin.x, point.x),
            y: min(origin.y, point.y),
            width: abs(point.x - origin.x),
            height: abs(point.y - origin.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        finish(current.width >= 4 && current.height >= 4 ? current : nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { finish(nil) }  // Escape
    }

    private func finish(_ rect: NSRect?) {
        guard !finished else { return }
        finished = true
        completion(rect)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()

        guard current.width > 0, current.height > 0 else { return }
        // Clear the selected region so the user sees what they'll capture.
        NSColor.clear.set()
        current.fill(using: .copy)

        NSColor.controlAccentColor.setStroke()
        let border = NSBezierPath(rect: current.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()
    }
}
