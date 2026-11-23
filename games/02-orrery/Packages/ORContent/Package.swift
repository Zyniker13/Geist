// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ORContent",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "ORContent", targets: ["ORContent"])
    ],
    dependencies: [
        .package(path: "../ORCore")
    ],
    targets: [
        .target(
            name: "ORContent",
            dependencies: [
                .product(name: "ORCore", package: "ORCore")
            ],
            path: "Sources/ORContent"
        ),
        .testTarget(
            name: "ORContentTests",
            dependencies: ["ORContent"],
            path: "Tests/ORContentTests"
        ),
    ]
)
