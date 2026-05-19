import Foundation
import CoreGraphics

/// Captures the screen to a temporary PNG via `/usr/sbin/screencapture`.
///
/// Runs entirely off the main thread; no AppKit UI. Screen Recording
/// permission is preflighted with the TCC `CG*ScreenCaptureAccess` APIs.
struct ScreenCapture: ScreenCapturing {
    func captureFullScreen() throws -> URL {
        try preflightPermission()
        let url = makeTempURL()
        _ = runScreenCapture(["-x", url.path])
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ScanError.captureFailed
        }
        return url
    }

    func captureSelection() throws -> URL {
        try preflightPermission()
        let url = makeTempURL()
        // `screencapture` exits non-zero (and writes no file) when the user
        // presses Escape / aborts the crosshair selection.
        let status = runScreenCapture(["-x", "-i", url.path])
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw status == 0 ? ScanError.captureFailed : ScanError.cancelled
        }
        return url
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Helpers

    private func preflightPermission() throws {
        guard CGPreflightScreenCaptureAccess() else {
            // Triggers the system prompt for next time, then fail this run.
            CGRequestScreenCaptureAccess()
            throw ScanError.screenRecordingPermissionDenied
        }
    }

    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("qr_scan_\(UUID().uuidString).png")
    }

    /// Runs `/usr/sbin/screencapture` with the given arguments and returns its
    /// exit status (0 on success).
    private func runScreenCapture(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
