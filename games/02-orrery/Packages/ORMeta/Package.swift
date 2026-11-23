// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ORMeta",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "ORMeta", targets: ["ORMeta"])
    ],
    dependencies: [
        .package(path: "../ORCore"),
        .package(path: "../ORContent"),
    ],
    targets: [
        .target(
            name: "ORMeta",
            dependencies: [
                .product(name: "ORCore", package: "ORCore"),
                .product(name: "ORContent", package: "ORContent"),
            ],
            path: "Sources/ORMeta"
        ),
        .testTarget(
            name: "ORMetaTests",
            dependencies: ["ORMeta"],
            path: "Tests/ORMetaTests"
        ),
    ]
)
