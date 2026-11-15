// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NMRender",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "NMRender", targets: ["NMRender"])
    ],
    dependencies: [
        .package(path: "../NMCore")
    ],
    targets: [
        .target(
            name: "NMRender",
            dependencies: [
                .product(name: "NMCore", package: "NMCore")
            ],
            path: "Sources/NMRender"
        ),
        .testTarget(
            name: "NMRenderTests",
            dependencies: ["NMRender"],
            path: "Tests/NMRenderTests"
        ),
    ]
)
