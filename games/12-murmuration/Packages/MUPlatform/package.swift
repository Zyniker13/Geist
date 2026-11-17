// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MUPlatform",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MUPlatform", targets: ["MUPlatform"])
    ],
    dependencies: [
        .package(path: "../MUCore")
    ],
    targets: [
        .target(
            name: "MUPlatform",
            dependencies: ["MUCore"],
        ),
        .testTarget(
            name: "MUPlatformTests",
            dependencies: ["MUPlatform"],
        ),
    ]
)
