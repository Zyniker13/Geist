// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NMPlatform",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "NMPlatform", targets: ["NMPlatform"])
    ],
    dependencies: [
        .package(path: "../NMCore")
    ],
    targets: [
        .target(
            name: "NMPlatform",
            dependencies: [
                .product(name: "NMCore", package: "NMCore")
            ],
            path: "Sources/NMPlatform"
        ),
        .testTarget(
            name: "NMPlatformTests",
            dependencies: ["NMPlatform"],
            path: "Tests/NMPlatformTests"
        ),
    ]
)
