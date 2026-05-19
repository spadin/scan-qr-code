import AppKit

/// Orchestrates the scan pipeline: capture → detect → clipboard → feedback.
///
/// This is the single entry point both the menu items and the global hotkeys
/// call. Capture is async (ScreenCaptureKit); Vision detection is offloaded so
/// it never blocks the main actor. Clipboard and feedback run on main.
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

        Task {
            do {
                let image: CGImage
                switch mode {
                case .fullScreen:
                    image = try await capturer.captureFullScreen()
                case .selection:
                    image = try await capturer.captureSelection()
                }

                let payloads = try await Task.detached(priority: .userInitiated) {
                    try detector.detect(in: image)
                }.value

                guard let first = payloads.first, !first.isEmpty else {
                    self.handle(.failure(.noCodeFound), mode: mode)
                    return
                }
                self.handle(.success(first), mode: mode)
            } catch let error as ScanError {
                self.handle(.failure(error), mode: mode)
            } catch {
                self.handle(.failure(.detection(error.localizedDescription)), mode: mode)
            }
        }
    }

    /// A payload is treated as openable only if it is a well-formed http(s)
    /// URL with a host — we deliberately don't auto-open arbitrary schemes
    /// (mailto:, tel:, custom app schemes) from a scanned code.
    private static func webURL(from payload: String) -> URL? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false
        else { return nil }
        return url
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
            if AppPreferences.openURLIfFound, let url = Self.webURL(from: payload) {
                NSWorkspace.shared.open(url)
            }
            feedback?.showSuccess(payload: payload)

        case .failure(.cancelled):
            // User aborted the region selection — silent, like the reference.
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

// MARK: - Placeholder implementations (replaced by AppDelegate at launch)

private struct UnconfiguredCapturer: ScreenCapturing {
    func captureFullScreen() async throws -> CGImage { throw ScanError.captureFailed }
    func captureSelection() async throws -> CGImage { throw ScanError.captureFailed }
}

private struct UnconfiguredDetector: QRDetecting {
    func detect(in image: CGImage) throws -> [String] { [] }
}
