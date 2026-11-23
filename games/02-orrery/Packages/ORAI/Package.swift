// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ORAI",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "ORAI", targets: ["ORAI"])
    ],
    dependencies: [
        .package(path: "../ORCore"),
        .package(path: "../ORContent"),
    ],
    targets: [
        .target(
            name: "ORAI",
            dependencies: [
                .product(name: "ORCore", package: "ORCore"),
                .product(name: "ORContent", package: "ORContent"),
            ],
            path: "Sources/ORAI"
        ),
        .testTarget(
            name: "ORAITests",
            dependencies: ["ORAI"],
            path: "Tests/ORAITests"
        ),
    ]
)
