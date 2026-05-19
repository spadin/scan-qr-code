import AppKit

/// Floating, non-activating HUD in the spirit of a Raycast confirmation:
/// a compact centered pill that fades out after ~2s and never steals focus.
@MainActor
final class HUDFeedback: ScanFeedback {
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    func showSuccess(payload: String) {
        present(
            symbol: "checkmark.circle.fill",
            tint: .secondaryLabelColor,
            title: "Copied: \(payload.truncatedForDisplay())",
            subtitle: nil
        )
    }

    func showFailure(title: String, message: String?) {
        present(
            symbol: "exclamationmark.triangle.fill",
            tint: .systemRed,
            title: title,
            subtitle: message
        )
    }

    // MARK: - Panel lifecycle

    private func present(symbol: String, tint: NSColor, title: String, subtitle: String?) {
        // A new HUD replaces the current one immediately.
        dismissWorkItem?.cancel()
        panel?.orderOut(nil)

        let content = makeContentView(symbol: symbol, tint: tint, title: title, subtitle: subtitle)
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = content
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2
            )
            panel.setFrameOrigin(origin)
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
        // The window shadow is derived from the rectangular backing and cached
        // before the rounded material has drawn — recompute it once the corner
        // mask is on screen so the shadow follows the corner radius.
        DispatchQueue.main.async { panel.invalidateShadow() }
        self.panel = panel

        let work = DispatchWorkItem { [weak self] in
            self?.dismiss(panel)
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func dismiss(_ panel: NSPanel) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                panel.orderOut(nil)
                if self?.panel === panel { self?.panel = nil }
            }
        })
    }

    // MARK: - View

    /// A stretchable rounded-rectangle mask. The center is stretched and the
    /// corners are preserved via cap insets, so it rounds any panel size.
    private static func roundedMaskImage(cornerRadius radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private func makeContentView(
        symbol: String,
        tint: NSColor,
        title: String,
        subtitle: String?
    ) -> NSView {
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        // A behind-window material is composited by the window server over the
        // view's rectangular region — layer.cornerRadius does NOT clip it. The
        // supported way to round it (and the window shadow with it) is a
        // resizable rounded-rect mask image.
        effect.maskImage = Self.roundedMaskImage(cornerRadius: 14)
        effect.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        icon.contentTintColor = tint
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        let textStack = NSStackView(views: [titleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        if let subtitle, !subtitle.isEmpty {
            let subtitleLabel = NSTextField(labelWithString: subtitle)
            subtitleLabel.font = .systemFont(ofSize: 11)
            subtitleLabel.textColor = .secondaryLabelColor
            subtitleLabel.lineBreakMode = .byTruncatingTail
            subtitleLabel.maximumNumberOfLines = 2
            textStack.addArrangedSubview(subtitleLabel)
        }

        let row = NSStackView(views: [icon, textStack])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: effect.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -14),
            effect.widthAnchor.constraint(lessThanOrEqualToConstant: 480)
        ])

        return effect
    }
}
