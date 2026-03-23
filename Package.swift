// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SchemataValidator",
    products: [
        .library(name: "SchemataValidator", targets: ["SchemataValidator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kylef/JSONSchema.swift.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "SchemataValidator",
            dependencies: [
                .product(name: "JSONSchema", package: "JSONSchema.swift"),
            ],
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "SchemataValidatorTests",
            dependencies: ["SchemataValidator"]
        ),
    ]
)
