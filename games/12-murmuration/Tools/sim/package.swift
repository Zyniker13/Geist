// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "sim",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "../../Packages/MUCore"),
    ],
    targets: [
        .executableTarget(
            name: "sim",
            dependencies: [
                .product(name: "MUCore", package: "MUCore"),
            ],
            path: "Sources/sim",
        ),
    ]
)
