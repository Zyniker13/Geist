// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "sim",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../../Packages/NMCore"),
        .package(path: "../../Packages/NMContent"),
        .package(path: "../../Packages/NMAI"),
    ],
    targets: [
        .executableTarget(
            name: "sim",
            dependencies: [
                .product(name: "NMCore", package: "NMCore"),
                .product(name: "NMContent", package: "NMContent"),
                .product(name: "NMAI", package: "NMAI"),
            ],
            path: "Sources/sim"
        )
    ]
)
