// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FallDock",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "FallDock",
            path: "Sources/FallDock"
        )
    ]
)
