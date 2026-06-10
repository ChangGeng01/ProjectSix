// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// Define the strict concurrency settings to be applied to all targets.
let swiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
    name: "swift-transformers",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Hub", targets: ["Hub"]),
        .library(name: "Tokenizers", targets: ["Tokenizers"]),
        .library(name: "Transformers", targets: ["Tokenizers", "Generation", "Models"]),
    ],
    dependencies: [
        .package(path: "../swift-jinja"),  // M224 vendor freeze: url -> path
        .package(path: "../swift-huggingface"),
        .package(path: "../swift-collections"),
        .package(path: "../swift-crypto"),
        .package(path: "../yyjson"),
    ],
    targets: [
        .target(name: "Generation", dependencies: ["Tokenizers"]),
        .target(
            name: "Hub",
            dependencies: [
                .product(name: "Jinja", package: "swift-jinja"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "yyjson", package: "yyjson"),
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: swiftSettings
        ),
        .target(name: "Models", dependencies: ["Tokenizers", "Generation"]),
        .target(name: "Tokenizers", dependencies: ["Hub", .product(name: "Jinja", package: "swift-jinja")]),
        .testTarget(name: "Benchmarks", dependencies: ["Hub", "Tokenizers", .product(name: "yyjson", package: "yyjson")]),
        .testTarget(name: "GenerationTests", dependencies: ["Generation"]),
        .testTarget(name: "HubTests", dependencies: ["Hub", .product(name: "Jinja", package: "swift-jinja")], swiftSettings: swiftSettings),
        .testTarget(name: "ModelsTests", dependencies: ["Models", "Hub"], resources: [.process("Resources")]),
        .testTarget(name: "TokenizersTests", dependencies: ["Tokenizers", "Models", "Hub"], resources: [.process("Resources")]),
    ]
)
