// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NMCore",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "NMCore", targets: ["NMCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NMCore",
            path: "Sources/NMCore"
        ),
        .testTarget(
            name: "NMCoreTests",
            dependencies: ["NMCore"],
            path: "Tests/NMCoreTests",
            resources: [.copy("GoldenReplays")]
        ),
    ]
)
