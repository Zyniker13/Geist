// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MMRender",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MMRender", targets: ["MMRender"])
    ],
    dependencies: [
        .package(path: "../MMCore")
    ],
    targets: [
        .target(
            name: "MMRender",
            dependencies: ["MMCore"],
        ),
        .testTarget(
            name: "MMRenderTests",
            dependencies: ["MMRender"],
        ),
    ]
)
