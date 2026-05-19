import KeyboardShortcuts

/// Single source of truth for the app's shortcut identities. No defaults —
/// the user assigns them in the Settings window.
extension KeyboardShortcuts.Name {
    static let scanScreen = Self("scanScreen")
    static let scanSelection = Self("scanSelection")
}

/// Owns the global hotkey registration. The shortcut values themselves live in
/// `KeyboardShortcuts`' own storage and are edited via `KeyboardShortcuts.Recorder`.
@MainActor
final class HotkeyManager {
    init() {}

    func register() {
        KeyboardShortcuts.onKeyUp(for: .scanScreen) {
            ScanEngine.shared.performScan(.fullScreen)
        }
        KeyboardShortcuts.onKeyUp(for: .scanSelection) {
            ScanEngine.shared.performScan(.selection)
        }
    }
}
