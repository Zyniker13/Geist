// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "sim",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../../Packages/NMCore"),
        .package(path: "../../Packages/NMContent"),
    ],
    targets: [
        .executableTarget(
            name: "sim",
            dependencies: [
                .product(name: "NMCore", package: "NMCore"),
                .product(name: "NMContent", package: "NMContent"),
            ],
            path: "Sources/sim"
        )
    ]
)
