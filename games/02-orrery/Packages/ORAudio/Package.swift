// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ORAudio",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "ORAudio", targets: ["ORAudio"])
    ],
    dependencies: [
        .package(path: "../ORCore")
    ],
    targets: [
        .target(
            name: "ORAudio",
            dependencies: [
                .product(name: "ORCore", package: "ORCore")
            ],
            path: "Sources/ORAudio"
        ),
        .testTarget(
            name: "ORAudioTests",
            dependencies: ["ORAudio"],
            path: "Tests/ORAudioTests"
        ),
    ]
)
