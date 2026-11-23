// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ORCore",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "ORCore", targets: ["ORCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ORCore",
            path: "Sources/ORCore"
        ),
        .testTarget(
            name: "ORCoreTests",
            dependencies: ["ORCore"],
            path: "Tests/ORCoreTests",
            resources: [.copy("GoldenReplays")]
        ),
    ]
)
