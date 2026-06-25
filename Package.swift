// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ScreenBar",
            path: "Sources/ScreenBar"
        ),
        .testTarget(
            name: "ScreenBarTests",
            dependencies: ["ScreenBar"],
            path: "Tests/ScreenBarTests"
        ),
    ]
)
