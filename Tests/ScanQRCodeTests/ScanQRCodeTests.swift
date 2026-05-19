import XCTest
@testable import ScanQRCode

final class ScanQRCodeTests: XCTestCase {
    func testTruncationLeavesShortStringsAlone() {
        XCTAssertEqual("https://example.com".truncatedForDisplay(max: 60), "https://example.com")
    }

    func testTruncationAddsEllipsis() {
        let long = String(repeating: "a", count: 100)
        let result = long.truncatedForDisplay(max: 10)
        XCTAssertEqual(result.count, 10)
        XCTAssertTrue(result.hasSuffix("…"))
    }
}
