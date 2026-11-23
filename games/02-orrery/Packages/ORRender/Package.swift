// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ORRender",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "ORRender", targets: ["ORRender"])
    ],
    dependencies: [
        .package(path: "../ORCore")
    ],
    targets: [
        .target(
            name: "ORRender",
            dependencies: [
                .product(name: "ORCore", package: "ORCore")
            ],
            path: "Sources/ORRender"
        ),
        .testTarget(
            name: "ORRenderTests",
            dependencies: ["ORRender"],
            path: "Tests/ORRenderTests"
        ),
    ]
)
