import Foundation

/// Which scan the user requested. Mirrors the two Raycast commands.
enum ScanMode {
    /// Silent full-screen capture (`screencapture -x`).
    case fullScreen
    /// Interactive crosshair region selection (`screencapture -x -i`).
    case selection
}

/// Errors surfaced by the capture + detection pipeline.
///
/// `cancelled` is special: it means the user aborted the crosshair selection
/// and the app must exit silently with no feedback (matching the reference).
enum ScanError: Error, LocalizedError {
    case screenRecordingPermissionDenied
    case captureFailed
    case cancelled
    case noCodeFound
    case detection(String)

    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionDenied:
            return "Screen Recording permission is required"
        case .captureFailed:
            return "Screen capture failed"
        case .cancelled:
            return "Cancelled"
        case .noCodeFound:
            return "No QR code found"
        case .detection(let message):
            return message
        }
    }
}

extension String {
    /// Shortens a payload for single-line display in the HUD, matching the
    /// reference extension's `truncateForDisplay` behavior.
    func truncatedForDisplay(max maxLength: Int = 60) -> String {
        guard count > maxLength else { return self }
        return prefix(maxLength - 1) + "…"
    }
}
