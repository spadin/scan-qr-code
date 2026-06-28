import AppKit
import KeyboardShortcuts
import SwiftUI

/// Owns the welcome / how-to window. The app is otherwise a headless menu bar
/// agent with no Dock icon and no main window — on a crowded menu bar the
/// status item can be pushed under the notch and never seen, which reads as
/// "the app didn't launch." This window appears on its own (independent of the
/// status item) so launching is always visible, and doubles as a quick how-to.
@MainActor
final class WelcomeWindowController {
    private var window: NSWindow?

    /// Wired by `MenuBarController` so the buttons drive the real actions.
    var scanScreenAction: (() -> Void)?
    var openSettingsAction: (() -> Void)?

    func show() {
        // Rebuilt every time so the displayed shortcuts and toggle reflect
        // current state.
        let view = WelcomeView(
            scanScreenShortcut: KeyboardShortcuts.getShortcut(for: .scanScreen)?.description,
            scanSelectionShortcut: KeyboardShortcuts.getShortcut(for: .scanSelection)?.description,
            onScanNow: { [weak self] in
                self?.window?.close()
                self?.scanScreenAction?()
            },
            onOpenSettings: { [weak self] in self?.openSettingsAction?() },
            onDone: { [weak self] in self?.window?.close() }
        )
        let hosting = NSHostingController(rootView: view)
        // Force a layout pass so fittingSize reflects the wrapped content;
        // otherwise the window adopts a stale (too-narrow) size and the body
        // text truncates instead of wrapping.
        hosting.view.layoutSubtreeIfNeeded()
        let contentSize = hosting.view.fittingSize

        let window: NSWindow
        if let existing = self.window {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: contentSize),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to Scan Screen QR Code"
            window.isReleasedWhenClosed = false
            self.window = window
        }

        window.contentViewController = hosting
        window.setContentSize(contentSize)
        window.center()

        // Accessory agent — bring the app forward so the window is focused.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct WelcomeView: View {
    let onScanNow: () -> Void
    let onOpenSettings: () -> Void
    let onDone: () -> Void

    @State private var scanScreenShortcut: String?
    @State private var scanSelectionShortcut: String?
    @State private var showAtLaunch = AppPreferences.showWelcomeAtLaunch

    // Posted by KeyboardShortcuts whenever any shortcut is reassigned. It's not
    // part of the library's public API, so we match it by name; if a future
    // version renames it, live sync stops gracefully (the window still shows
    // the values it had when opened).
    private static let shortcutDidChange =
        Notification.Name("KeyboardShortcuts_shortcutByNameDidChange")

    init(
        scanScreenShortcut: String?,
        scanSelectionShortcut: String?,
        onScanNow: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        _scanScreenShortcut = State(initialValue: scanScreenShortcut)
        _scanSelectionShortcut = State(initialValue: scanSelectionShortcut)
        self.onScanNow = onScanNow
        self.onOpenSettings = onOpenSettings
        self.onDone = onDone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan Screen QR Code").font(.title2).bold()
                    Text("The app is running in your menu bar.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Label {
                Text("Look for the \(Image(systemName: "qrcode.viewfinder")) icon in the menu bar at the top-right of your screen.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "arrow.up.right")
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                step(1, "Make sure a QR, Aztec, DataMatrix, or PDF417 code is visible on screen.")
                step(2, "Click the menu bar icon, then choose “Scan Screen for QR Code” (or “Scan Selected Area” to drag a box).")
                step(3, "The decoded text is copied to your clipboard and shown in a brief HUD.")
            }

            GroupBox("Keyboard shortcuts") {
                VStack(spacing: 6) {
                    shortcutRow("Scan Screen for QR Code", scanScreenShortcut)
                    shortcutRow("Scan Selected Area for QR Code", scanSelectionShortcut)
                }
                .padding(4)
            }

            Toggle("Show this window when the app launches", isOn: $showAtLaunch)
                .onChange(of: showAtLaunch) { _, newValue in
                    AppPreferences.showWelcomeAtLaunch = newValue
                }

            HStack {
                Button("Open Settings…", action: onOpenSettings)
                Spacer()
                Button("Scan Screen Now", action: onScanNow)
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onReceive(NotificationCenter.default.publisher(for: Self.shortcutDidChange)) { _ in
            scanScreenShortcut = KeyboardShortcuts.getShortcut(for: .scanScreen)?.description
            scanSelectionShortcut = KeyboardShortcuts.getShortcut(for: .scanSelection)?.description
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number).")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func shortcutRow(_ title: String, _ shortcut: String?) -> some View {
        HStack {
            Text(title).font(.callout)
            Spacer()
            if let shortcut {
                Text(shortcut)
                    .font(.callout.monospaced())
            } else {
                Text("Not set — assign in Settings")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
