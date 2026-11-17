// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MUAudio",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MUAudio", targets: ["MUAudio"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MUAudio",
            dependencies: [],
        ),
        .testTarget(
            name: "MUAudioTests",
            dependencies: ["MUAudio"],
        ),
    ]
)
