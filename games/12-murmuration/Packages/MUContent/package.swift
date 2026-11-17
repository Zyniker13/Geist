// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MUContent",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MUContent", targets: ["MUContent"])
    ],
    dependencies: [
        .package(path: "../MUCore")
    ],
    targets: [
        .target(
            name: "MUContent",
            dependencies: ["MUCore"],
        ),
        .testTarget(
            name: "MUContentTests",
            dependencies: ["MUContent"],
        ),
    ]
)
