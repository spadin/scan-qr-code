import AppKit
import CoreGraphics
import ScreenCaptureKit

/// In-process screen capture via ScreenCaptureKit.
///
/// No shelling out and no temp files, so the app runs in the App Sandbox
/// required by the Mac App Store. Screen Recording is TCC-gated (the system
/// prompts on first use); ScreenCaptureKit needs no extra entitlement.
final class ScreenCapture: ScreenCapturing {
    func captureFullScreen() async throws -> CGImage {
        let (display, scale) = try await mainDisplay()
        return try await capture(
            display: display,
            sourceRect: nil,
            pixelSize: CGSize(
                width: CGFloat(display.width) * scale,
                height: CGFloat(display.height) * scale
            )
        )
    }

    func captureSelection() async throws -> CGImage {
        // Select the region first; ScreenCaptureKit raises its permission
        // prompt during the capture below, so a drag is never interrupted.
        let regionGlobal = try await selectRegion()

        guard let screen = NSScreen.main else { throw ScanError.captureFailed }
        let scale = screen.backingScaleFactor

        // Global (bottom-left origin) → display-local (top-left origin) points.
        let local = CGRect(
            x: regionGlobal.minX - screen.frame.minX,
            y: screen.frame.maxY - regionGlobal.maxY,
            width: regionGlobal.width,
            height: regionGlobal.height
        )

        // Give the overlay window a moment to leave the screen so it isn't
        // captured.
        try await Task.sleep(for: .milliseconds(80))

        let (display, _) = try await mainDisplay()
        return try await capture(
            display: display,
            sourceRect: local,
            pixelSize: CGSize(width: local.width * scale, height: local.height * scale)
        )
    }

    // MARK: - Helpers

    /// The overlay is `@MainActor`; build and drive it there.
    @MainActor
    private func selectRegion() async throws -> CGRect {
        try await SelectionOverlay().selectRegion()
    }

    private func mainDisplay() async throws -> (SCDisplay, CGFloat) {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            // ScreenCaptureKit raises the system Screen Recording prompt on
            // first use and surfaces a denial as an error here. This is the
            // app's sole permission gate — issuing a separate CoreGraphics
            // request would show a second, redundant prompt.
            throw ScanError.screenRecordingPermissionDenied
        }
        guard let display = content.displays.first(where: {
            $0.displayID == CGMainDisplayID()
        }) ?? content.displays.first else {
            throw ScanError.captureFailed
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        return (display, scale)
    }

    private func capture(
        display: SCDisplay,
        sourceRect: CGRect?,
        pixelSize: CGSize
    ) async throws -> CGImage {
        let content = try? await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        // Exclude our own windows (overlay / HUD / menu) from the capture.
        let ownApp = content?.applications.first {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter: SCContentFilter = ownApp.map {
            SCContentFilter(display: display, excludingApplications: [$0], exceptingWindows: [])
        } ?? SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.width = max(1, Int(pixelSize.width.rounded()))
        config.height = max(1, Int(pixelSize.height.rounded()))
        config.showsCursor = false
        config.scalesToFit = false
        if let sourceRect {
            config.sourceRect = sourceRect
        }

        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            throw ScanError.captureFailed
        }
    }
}
