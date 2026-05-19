import AppKit

// STUB — owned by Agent B. Replace the entire file with the real
// floating-panel HUD implementation.
@MainActor
final class HUDFeedback: ScanFeedback {
    func showSuccess(payload: String) {}
    func showFailure(title: String, message: String?) {}
}
