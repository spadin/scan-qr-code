import XCTest
import CoreImage
@testable import ScanQRCode

final class QRDetectorTests: XCTestCase {
    func testDetectRoundTripsPayload() throws {
        let payload = "https://example.com/abc"
        let image = try makeQRImage(encoding: payload)
        let results = try QRDetector().detect(in: image)
        XCTAssertEqual(results.first, payload)
    }

    func testDetectReturnsEmptyForBlankImage() throws {
        let blank = CIImage(color: .white)
            .cropped(to: CGRect(x: 0, y: 0, width: 200, height: 200))
        XCTAssertEqual(try QRDetector().detect(in: render(blank)), [])
    }

    // MARK: - Helpers

    private func makeQRImage(encoding payload: String) throws -> CGImage {
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        let scaled = filter.outputImage!.transformed(
            by: CGAffineTransform(scaleX: 10, y: 10)
        )
        return render(scaled)
    }

    private func render(_ image: CIImage) -> CGImage {
        CIContext().createCGImage(image, from: image.extent)!
    }
}
