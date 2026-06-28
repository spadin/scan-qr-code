import Foundation

/// Lightweight wrapper over `UserDefaults` for the app's toggles.
enum AppPreferences {
    private static let openURLKey = "openURLIfFound"
    private static let showWelcomeKey = "showWelcomeAtLaunch"

    /// When on, a successful scan whose payload is an http(s) URL is opened
    /// in the default browser (in addition to being copied to the clipboard).
    static var openURLIfFound: Bool {
        get { UserDefaults.standard.bool(forKey: openURLKey) }
        set { UserDefaults.standard.set(newValue, forKey: openURLKey) }
    }

    /// When on, the welcome / how-to window is shown automatically each launch.
    /// Defaults to `true` so a first run (and App Review's clean install) always
    /// surfaces a visible window — the app is otherwise a headless menu bar agent.
    static var showWelcomeAtLaunch: Bool {
        get { UserDefaults.standard.object(forKey: showWelcomeKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: showWelcomeKey) }
    }
}
