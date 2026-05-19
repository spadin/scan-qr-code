import CoreGraphics

// MARK: - Stable seam between the two feature areas.
//
// The capture side implements `ScreenCapturing` and `QRDetecting`; the UI side
// implements `ScanFeedback`. The orchestration in `ScanEngine` only talks to
// these protocols.
//
// Capture is fully in-process (ScreenCaptureKit) — no temp files, no shelling
// out — so the app runs in the App Sandbox required by the Mac App Store. The
// seam passes a `CGImage` rather than a file URL for the same reason.

/// Captures pixels from the screen, in-process, as a `CGImage`.
protocol ScreenCapturing {
    /// Capture the main display.
    /// - Throws: `ScanError.screenRecordingPermissionDenied` if TCC denied,
    ///           `ScanError.captureFailed` for any other failure.
    func captureFullScreen() async throws -> CGImage

    /// Let the user drag a region selection, then capture just that region.
    /// - Throws: `ScanError.cancelled` if the user pressed Escape / aborted,
    ///           `ScanError.screenRecordingPermissionDenied`,
    ///           `ScanError.captureFailed` otherwise.
    func captureSelection() async throws -> CGImage
}

/// Decodes 2D barcodes from an image using Apple's Vision framework.
protocol QRDetecting {
    /// Detect QR / Aztec / DataMatrix / PDF417 payloads in the image.
    /// - Returns: decoded payload strings in detection order (possibly empty).
    /// - Throws: `ScanError.detection` if Vision itself fails.
    func detect(in image: CGImage) throws -> [String]
}

/// User-facing feedback. All calls arrive on the main actor.
@MainActor
protocol ScanFeedback {
    /// A payload was copied to the clipboard. Show the success HUD.
    func showSuccess(payload: String)
    /// A recoverable problem (e.g. "No QR code found"). Show the failure HUD.
    func showFailure(title: String, message: String?)
}
