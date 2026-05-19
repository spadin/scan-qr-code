import Foundation

/// Lightweight wrapper over `UserDefaults` for the app's toggles.
enum AppPreferences {
    private static let openURLKey = "openURLIfFound"

    /// When on, a successful scan whose payload is an http(s) URL is opened
    /// in the default browser (in addition to being copied to the clipboard).
    static var openURLIfFound: Bool {
        get { UserDefaults.standard.bool(forKey: openURLKey) }
        set { UserDefaults.standard.set(newValue, forKey: openURLKey) }
    }
}
