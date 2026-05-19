import Foundation

// MARK: - Stable seam between the two feature areas.
//
// Agent A (capture + Vision detection) implements `ScreenCapturing` and
// `QRDetecting`. Agent B (menubar / hotkeys / settings / HUD) implements
// `ScanFeedback`. The orchestration in `ScanEngine` only talks to these
// protocols, so the two feature areas never touch each other's code.

/// Captures pixels from the screen to a temporary PNG file on disk.
protocol ScreenCapturing {
    /// Capture the entire screen.
    /// - Returns: URL of a temporary PNG. Caller owns it and must call `cleanup`.
    /// - Throws: `ScanError.screenRecordingPermissionDenied` if TCC denied,
    ///           `ScanError.captureFailed` for any other failure.
    func captureFullScreen() throws -> URL

    /// Present the macOS crosshair and capture the selected region.
    /// - Returns: URL of a temporary PNG. Caller owns it and must call `cleanup`.
    /// - Throws: `ScanError.cancelled` if the user pressed Escape / aborted,
    ///           `ScanError.screenRecordingPermissionDenied`,
    ///           `ScanError.captureFailed` otherwise.
    func captureSelection() throws -> URL

    /// Best-effort deletion of a temp file produced by this capturer.
    func cleanup(_ url: URL)
}

/// Decodes 2D barcodes from an image using Apple's Vision framework.
protocol QRDetecting {
    /// Detect QR / Aztec / DataMatrix / PDF417 payloads in the image.
    /// - Returns: decoded payload strings in detection order (possibly empty).
    /// - Throws: `ScanError.detection` if Vision itself fails.
    func detect(in imageURL: URL) throws -> [String]
}

/// User-facing feedback. All calls arrive on the main actor.
@MainActor
protocol ScanFeedback {
    /// A payload was copied to the clipboard. Show the success HUD.
    func showSuccess(payload: String)
    /// A recoverable problem (e.g. "No QR code found"). Show the failure HUD.
    func showFailure(title: String, message: String?)
}
