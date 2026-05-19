import Foundation

// STUB — owned by Agent A. Replace the entire file with the real
// `/usr/sbin/screencapture`-based implementation.
struct ScreenCapture: ScreenCapturing {
    func captureFullScreen() throws -> URL { throw ScanError.captureFailed }
    func captureSelection() throws -> URL { throw ScanError.captureFailed }
    func cleanup(_ url: URL) {}
}
