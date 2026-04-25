// swift-tools-version: 5.9
// M224 vendor freeze. Original Package.swift edits:
//   - All url: rewritten to path: ../<vendored>
//   - testTargets removed (Tests/ stripped during vendor)
// Original repo: https://github.com/huggingface/swift-transformers

import PackageDescription

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
        .package(path: "../swift-jinja"),
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
    ]
)
