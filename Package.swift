// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DebugProcessWatcher",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DebugProcessWatcher",
            targets: ["DebugProcessWatcher"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DebugProcessWatcher",
            path: "Sources/DebugProcessWatcher",
            exclude: [
                "Resources"
            ]
        ),
        .testTarget(
            name: "DebugProcessWatcherTests",
            dependencies: ["DebugProcessWatcher"],
            path: "Tests/DebugProcessWatcherTests"
        )
    ]
)
