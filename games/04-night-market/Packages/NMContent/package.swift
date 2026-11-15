// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NMContent",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "NMContent", targets: ["NMContent"])
    ],
    dependencies: [
        .package(path: "../NMCore")
    ],
    targets: [
        .target(
            name: "NMContent",
            dependencies: [
                .product(name: "NMCore", package: "NMCore")
            ],
            path: "Sources/NMContent"
        ),
        .testTarget(
            name: "NMContentTests",
            dependencies: ["NMContent"],
            path: "Tests/NMContentTests"
        ),
    ]
)
