// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "sim",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(path: "../../Packages/ORCore"),
    ],
    targets: [
        .executableTarget(
            name: "sim",
            dependencies: [
                .product(name: "ORCore", package: "ORCore"),
            ],
            path: "Sources/sim",
        ),
    ]
)
