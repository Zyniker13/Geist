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
        .package(path: "../MUCore"),
        .package(path: "../MUContent"),
    ],
    targets: [
        .target(
            name: "MURender",
            dependencies: ["MUCore", "MUContent"],
            resources: [.process("Shaders.metal")],
        ),
        .testTarget(
            name: "MURenderTests",
            dependencies: ["MURender"],
        ),
    ]
)
