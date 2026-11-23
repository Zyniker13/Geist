// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ORPlatform",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "ORPlatform", targets: ["ORPlatform"])
    ],
    dependencies: [
        .package(path: "../ORCore")
    ],
    targets: [
        .target(
            name: "ORPlatform",
            dependencies: [
                .product(name: "ORCore", package: "ORCore")
            ],
            path: "Sources/ORPlatform"
        ),
        .testTarget(
            name: "ORPlatformTests",
            dependencies: ["ORPlatform"],
            path: "Tests/ORPlatformTests"
        ),
    ]
)
