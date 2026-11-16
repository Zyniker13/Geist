// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MMContent",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MMContent", targets: ["MMContent"])
    ],
    dependencies: [
        .package(path: "../MMCore")
    ],
    targets: [
        .target(
            name: "MMContent",
            dependencies: ["MMCore"],
        ),
        .testTarget(
            name: "MMContentTests",
            dependencies: ["MMContent"],
        ),
    ]
)
