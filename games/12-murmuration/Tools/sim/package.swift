// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "sim",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "../../Packages/MUCore"),
        .package(path: "../../Packages/MUContent"),
        .package(path: "../../Packages/MUAI"),
    ],
    targets: [
        .executableTarget(
            name: "sim",
            dependencies: [
                .product(name: "MUCore", package: "MUCore"),
                .product(name: "MUContent", package: "MUContent"),
                .product(name: "MUAI", package: "MUAI"),
            ],
            path: "Sources/sim",
        ),
    ]
)
