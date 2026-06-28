import AppKit
import KeyboardShortcuts
import SwiftUI

/// Owns one reusable settings window hosting a SwiftUI form with a
/// `KeyboardShortcuts.Recorder` per scan action.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        // App is an .accessory agent — bring it forward so the window is usable.
        NSApp.activate(ignoringOtherApps: true)

        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Scan Screen QR Code Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 420, height: 300))
            window.center()
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @State private var showWelcomeAtLaunch = AppPreferences.showWelcomeAtLaunch

    var body: some View {
        Form {
            Section {
                LabeledContent("Scan Screen for QR Code") {
                    KeyboardShortcuts.Recorder(for: .scanScreen)
                }
                Text("Silently captures the whole screen and copies the first QR code found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Scan Selected Area for QR Code") {
                    KeyboardShortcuts.Recorder(for: .scanSelection)
                }
                Text("Draw a selection with the crosshair, then scan just that region.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show welcome window at launch", isOn: $showWelcomeAtLaunch)
                    .onChange(of: showWelcomeAtLaunch) { _, newValue in
                        AppPreferences.showWelcomeAtLaunch = newValue
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 300)
    }
}
