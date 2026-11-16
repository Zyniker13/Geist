// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MMMeta",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MMMeta", targets: ["MMMeta"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MMMeta",
        ),
        .testTarget(
            name: "MMMetaTests",
            dependencies: ["MMMeta"],
        ),
    ]
)
