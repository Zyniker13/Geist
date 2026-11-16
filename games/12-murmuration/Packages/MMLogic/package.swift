// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MMLogic",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MMLogic", targets: ["MMLogic"])
    ],
    dependencies: [
        .package(path: "../MMCore")
    ],
    targets: [
        .target(
            name: "MMLogic",
            dependencies: ["MMCore"],
        ),
        .testTarget(
            name: "MMLogicTests",
            dependencies: ["MMLogic"],
        ),
    ]
)
