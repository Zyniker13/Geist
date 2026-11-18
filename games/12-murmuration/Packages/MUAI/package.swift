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
        .package(path: "../MUCore"),
        .package(path: "../MUContent"),
    ],
    targets: [
        .target(
            name: "MUAI",
            dependencies: ["MUCore", "MUContent"],
        ),
        .testTarget(
            name: "MUAITests",
            dependencies: ["MUAI"],
        ),
    ]
)
