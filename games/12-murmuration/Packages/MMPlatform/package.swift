// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MMPlatform",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MMPlatform", targets: ["MMPlatform"])
    ],
    dependencies: [
        .package(path: "../MMCore")
    ],
    targets: [
        .target(
            name: "MMPlatform",
            dependencies: ["MMCore"],
        ),
        .testTarget(
            name: "MMPlatformTests",
            dependencies: ["MMPlatform"],
        ),
    ]
)
