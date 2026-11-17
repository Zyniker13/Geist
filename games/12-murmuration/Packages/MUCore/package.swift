// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MUCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MUCore", targets: ["MUCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MUCore",
            dependencies: [],
        ),
        .testTarget(
            name: "MUCoreTests",
            dependencies: ["MUCore"],
            resources: [.copy("GoldenReplays")],
        ),
    ]
)
