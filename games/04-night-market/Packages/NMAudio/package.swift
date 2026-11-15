// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NMAudio",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "NMAudio", targets: ["NMAudio"])
    ],
    dependencies: [
        .package(path: "../NMCore")
    ],
    targets: [
        .target(
            name: "NMAudio",
            dependencies: [
                .product(name: "NMCore", package: "NMCore")
            ],
            path: "Sources/NMAudio"
        ),
        .testTarget(
            name: "NMAudioTests",
            dependencies: ["NMAudio"],
            path: "Tests/NMAudioTests"
        ),
    ]
)
