// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SchemataValidator",
    products: [
        .library(name: "SchemataValidator", targets: ["SchemataValidator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nostrability/schemata-swift.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "SchemataValidator",
            dependencies: [
                .product(name: "SchemataSwift", package: "schemata-swift"),
            ]
        ),
        .testTarget(
            name: "SchemataValidatorTests",
            dependencies: ["SchemataValidator"]
        ),
    ]
)
