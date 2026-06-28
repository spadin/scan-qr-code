import AppKit

/// Wires the two feature areas together at launch. This file owns no feature
/// logic — it only injects the concrete implementations into `ScanEngine` and
/// keeps the long-lived controllers alive.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var hotkeys: HotkeyManager?
    private var feedback: HUDFeedback?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon / no main window — pure menu bar agent app.
        NSApp.setActivationPolicy(.accessory)

        // Agent A: capture + Vision detection.
        ScanEngine.shared.capturer = ScreenCapture()
        ScanEngine.shared.detector = QRDetector()

        // Agent B: feedback HUD, menu bar UI, global hotkeys.
        let feedback = HUDFeedback()
        ScanEngine.shared.feedback = feedback
        self.feedback = feedback

        let menuBar = MenuBarController()
        menuBar.install()
        self.menuBar = menuBar

        let hotkeys = HotkeyManager()
        hotkeys.register()
        self.hotkeys = hotkeys

        // The app is a headless menu bar agent; surface a visible window on
        // launch (default on) so it's obvious it started even if the menu bar
        // status item is hidden behind a crowded bar / notch.
        if AppPreferences.showWelcomeAtLaunch {
            menuBar.showWelcome()
        }
    }
}
