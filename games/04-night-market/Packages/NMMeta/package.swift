// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NMMeta",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "NMMeta", targets: ["NMMeta"])
    ],
    dependencies: [
        .package(path: "../NMCore")
    ],
    targets: [
        .target(
            name: "NMMeta",
            dependencies: [
                .product(name: "NMCore", package: "NMCore")
            ],
            path: "Sources/NMMeta"
        ),
        .testTarget(
            name: "NMMetaTests",
            dependencies: ["NMMeta"],
            path: "Tests/NMMetaTests"
        ),
    ]
)
