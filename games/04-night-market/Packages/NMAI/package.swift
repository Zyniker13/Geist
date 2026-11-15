// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NMAI",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "NMAI", targets: ["NMAI"])
    ],
    dependencies: [
        .package(path: "../NMCore"),
        .package(path: "../NMContent"),
    ],
    targets: [
        .target(
            name: "NMAI",
            dependencies: [
                .product(name: "NMCore", package: "NMCore"),
                .product(name: "NMContent", package: "NMContent"),
            ],
            path: "Sources/NMAI"
        ),
        .testTarget(
            name: "NMAITests",
            dependencies: ["NMAI"],
            path: "Tests/NMAITests"
        ),
    ]
)
