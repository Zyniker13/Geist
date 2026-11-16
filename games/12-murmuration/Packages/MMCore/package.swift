// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MMCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MMCore", targets: ["MMCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MMCore",
            dependencies: [],
        ),
        .testTarget(
            name: "MMCoreTests",
            dependencies: ["MMCore"],
        ),
    ]
)
