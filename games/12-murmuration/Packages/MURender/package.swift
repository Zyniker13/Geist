// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MURender",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MURender", targets: ["MURender"])
    ],
    dependencies: [
        .package(path: "../MUCore")
    ],
    targets: [
        .target(
            name: "MURender",
            dependencies: ["MUCore"],
        ),
        .testTarget(
            name: "MURenderTests",
            dependencies: ["MURender"],
        ),
    ]
)
