import XCTest
import CoreImage
import AppKit
@testable import ScanQRCode

final class QRDetectorTests: XCTestCase {
    func testDetectRoundTripsPayload() throws {
        let payload = "https://example.com/abc"
        let url = try makeQRImage(encoding: payload)
        defer { try? FileManager.default.removeItem(at: url) }

        let results = try QRDetector().detect(in: url)
        XCTAssertEqual(results.first, payload)
    }

    func testDetectReturnsEmptyForBlankImage() throws {
        let url = try makeBlankImage()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(try QRDetector().detect(in: url), [])
    }

    // MARK: - Helpers

    private func makeQRImage(encoding payload: String) throws -> URL {
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        let scaled = filter.outputImage!.transformed(
            by: CGAffineTransform(scaleX: 10, y: 10)
        )
        return try writePNG(scaled)
    }

    private func makeBlankImage() throws -> URL {
        let blank = CIImage(color: .white)
            .cropped(to: CGRect(x: 0, y: 0, width: 200, height: 200))
        return try writePNG(blank)
    }

    private func writePNG(_ image: CIImage) throws -> URL {
        let context = CIContext()
        let cgImage = context.createCGImage(image, from: image.extent)!
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let data = rep.representation(using: .png, properties: [:])!

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("qr_test_\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }
}
