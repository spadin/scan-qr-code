import AppKit

/// Owns the menu bar status item and its menu. All actions route through
/// `@objc` selectors so targets/closures stay main-actor safe.
@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let settings = SettingsWindowController()

    override init() {
        super.init()
    }

    func install() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "qrcode.viewfinder",
            accessibilityDescription: "Scan QR Code"
        )

        let menu = NSMenu()

        let scanScreen = NSMenuItem(
            title: "Scan Screen for QR Code",
            action: #selector(scanScreen(_:)),
            keyEquivalent: ""
        )
        scanScreen.target = self
        menu.addItem(scanScreen)

        let scanSelection = NSMenuItem(
            title: "Scan Selected Area for QR Code",
            action: #selector(scanSelection(_:)),
            keyEquivalent: ""
        )
        scanSelection.target = self
        menu.addItem(scanSelection)

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
            title: "Quit Scan QR Code",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    @objc private func scanScreen(_ sender: Any?) {
        ScanEngine.shared.performScan(.fullScreen)
    }

    @objc private func scanSelection(_ sender: Any?) {
        ScanEngine.shared.performScan(.selection)
    }

    @objc private func openSettings(_ sender: Any?) {
        settings.show()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
