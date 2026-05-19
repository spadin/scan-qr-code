// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScanQRCode",
    platforms: [
        // ScreenCaptureKit's SCScreenshotManager (in-process, sandbox-safe
        // capture) requires macOS 14.
        .macOS(.v14)
    ],
    dependencies: [
        .package(
            url: "https://github.com/sindresorhus/KeyboardShortcuts",
            .upToNextMajor(from: "2.0.0")
        )
    ],
    targets: [
        .executableTarget(
            name: "ScanQRCode",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/ScanQRCode"
        ),
        .testTarget(
            name: "ScanQRCodeTests",
            dependencies: ["ScanQRCode"],
            path: "Tests/ScanQRCodeTests"
        )
    ]
)
