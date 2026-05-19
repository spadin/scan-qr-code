import AppKit

/// Orchestrates the scan pipeline: capture → detect → clipboard → feedback.
///
/// This is the single entry point both the menu items and the global
/// hotkeys call. Capture and Vision detection are blocking, so they run off
/// the main thread; clipboard writes and feedback happen back on the main actor.
@MainActor
final class ScanEngine {
    static let shared = ScanEngine()

    /// Implementations are injected by `AppDelegate` at launch.
    var capturer: ScreenCapturing = UnconfiguredCapturer()
    var detector: QRDetecting = UnconfiguredDetector()
    var feedback: ScanFeedback?

    private init() {}

    func performScan(_ mode: ScanMode) {
        let capturer = self.capturer
        let detector = self.detector

        Task.detached(priority: .userInitiated) {
            do {
                let imageURL: URL
                switch mode {
                case .fullScreen:
                    imageURL = try capturer.captureFullScreen()
                case .selection:
                    imageURL = try capturer.captureSelection()
                }
                defer { capturer.cleanup(imageURL) }

                let payloads = try detector.detect(in: imageURL)
                guard let first = payloads.first, !first.isEmpty else {
                    await self.handle(.failure(.noCodeFound), mode: mode)
                    return
                }
                await self.handle(.success(first), mode: mode)
            } catch let error as ScanError {
                await self.handle(.failure(error), mode: mode)
            } catch {
                await self.handle(.failure(.detection(error.localizedDescription)), mode: mode)
            }
        }
    }

    private enum Outcome {
        case success(String)
        case failure(ScanError)
    }

    private func handle(_ outcome: Outcome, mode: ScanMode) {
        switch outcome {
        case .success(let payload):
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(payload, forType: .string)
            feedback?.showSuccess(payload: payload)

        case .failure(.cancelled):
            // User aborted the crosshair selection — silent, like the reference.
            break

        case .failure(.noCodeFound):
            let message = mode == .selection
                ? "No QR code found in selection"
                : "Make sure a QR code is fully visible on screen"
            feedback?.showFailure(title: "No QR code found", message: message)

        case .failure(.screenRecordingPermissionDenied):
            feedback?.showFailure(
                title: "Screen Recording permission required",
                message: "Enable it in System Settings ▸ Privacy & Security ▸ Screen Recording, then try again."
            )

        case .failure(.captureFailed):
            feedback?.showFailure(title: "Screen capture failed", message: nil)

        case .failure(.detection(let message)):
            feedback?.showFailure(title: "Scan failed", message: message)
        }
    }
}

// MARK: - Placeholder implementations (replaced by Agent A at launch wiring)

private struct UnconfiguredCapturer: ScreenCapturing {
    func captureFullScreen() throws -> URL { throw ScanError.captureFailed }
    func captureSelection() throws -> URL { throw ScanError.captureFailed }
    func cleanup(_ url: URL) {}
}

private struct UnconfiguredDetector: QRDetecting {
    func detect(in imageURL: URL) throws -> [String] { [] }
}
