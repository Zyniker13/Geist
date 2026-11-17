// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MUAI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MUAI", targets: ["MUAI"])
    ],
    dependencies: [
        .package(path: "../MUCore")
    ],
    targets: [
        .target(
            name: "MUAI",
            dependencies: ["MUCore"],
        ),
        .testTarget(
            name: "MUAITests",
            dependencies: ["MUAI"],
        ),
    ]
)
