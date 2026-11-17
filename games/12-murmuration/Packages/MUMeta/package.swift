// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MUMeta",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MUMeta", targets: ["MUMeta"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MUMeta",
        ),
        .testTarget(
            name: "MUMetaTests",
            dependencies: ["MUMeta"],
        ),
    ]
)
