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
    dependencies: [
        .package(name: "MUContent", path: "../MUContent"),
        .package(name: "MUCore", path: "../MUCore"),
    ],
    targets: [
        .target(
            name: "MUMeta",
            dependencies: ["MUContent", "MUCore"],
        ),
        .testTarget(
            name: "MUMetaTests",
            dependencies: ["MUMeta"],
        ),
    ]
)
