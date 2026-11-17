// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "spike",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "../../Packages/MUCore"),
    ],
    targets: [
        .executableTarget(
            name: "spike",
            dependencies: [
                .product(name: "MUCore", package: "MUCore"),
            ],
            path: "Sources/spike",
        ),
        .executableTarget(
            name: "metalprobe",
            path: "Sources/metalprobe",
        ),
    ]
)
