import AppKit
import KeyboardShortcuts

/// Owns the menu bar status item and its menu. All actions route through
/// `@objc` selectors so targets/closures stay main-actor safe.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let settings = SettingsWindowController()
    private let openURLItem = NSMenuItem(
        title: "Open URL If Found",
        action: #selector(toggleOpenURL(_:)),
        keyEquivalent: ""
    )

    override init() {
        super.init()
    }

    func install() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "qrcode.viewfinder",
            accessibilityDescription: "Scan Screen QR Code"
        )

        let menu = NSMenu()
        menu.delegate = self

        let scanScreen = NSMenuItem(
            title: "Scan Screen for QR Code",
            action: #selector(scanScreen(_:)),
            keyEquivalent: ""
        )
        scanScreen.target = self
        // Reflects the user's recorded hotkey and stays in sync automatically.
        scanScreen.setShortcut(for: .scanScreen)
        menu.addItem(scanScreen)

        let scanSelection = NSMenuItem(
            title: "Scan Selected Area for QR Code",
            action: #selector(scanSelection(_:)),
            keyEquivalent: ""
        )
        scanSelection.target = self
        scanSelection.setShortcut(for: .scanSelection)
        menu.addItem(scanSelection)

        menu.addItem(.separator())

        openURLItem.target = self
        openURLItem.state = AppPreferences.openURLIfFound ? .on : .off
        menu.addItem(openURLItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Scan Screen QR Code",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // While a menu is open, NSMenu puts the thread in tracking mode, so
        // global hotkey events buffer and fire on close. Disable them for the
        // duration (the displayed shortcut still shows on the menu items).
        KeyboardShortcuts.disable(.scanScreen, .scanSelection)
        openURLItem.state = AppPreferences.openURLIfFound ? .on : .off
    }

    func menuDidClose(_ menu: NSMenu) {
        KeyboardShortcuts.enable(.scanScreen, .scanSelection)
    }

    // MARK: - Actions

    @objc private func scanScreen(_ sender: Any?) {
        ScanEngine.shared.performScan(.fullScreen)
    }

    @objc private func scanSelection(_ sender: Any?) {
        ScanEngine.shared.performScan(.selection)
    }

    @objc private func toggleOpenURL(_ sender: Any?) {
        AppPreferences.openURLIfFound.toggle()
        openURLItem.state = AppPreferences.openURLIfFound ? .on : .off
    }

    @objc private func openSettings(_ sender: Any?) {
        settings.show()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
