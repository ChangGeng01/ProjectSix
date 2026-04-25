// swift-tools-version: 6.1
// M224 vendor freeze. Original Package.swift edits:
//   - EventSource / swift-crypto url: rewritten to path: ../<vendored>
//   - swift-xet url: + Xet trait dep removed (we do not vendor
//     swift-xet and the Xet trait is never enabled in BAS builds)
//   - testTargets removed (Tests/ stripped during vendor)
// Original repo: https://github.com/huggingface/swift-huggingface

import PackageDescription

let package = Package(
    name: "swift-huggingface",
    platforms: [
        .macOS(.v13),
        .macCatalyst(.v16),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "HuggingFace",
            targets: ["HuggingFace"]
        )
    ],
    dependencies: [
        .package(path: "../EventSource"),
        .package(path: "../swift-crypto"),
    ],
    targets: [
        .target(
            name: "HuggingFace",
            dependencies: [
                .product(name: "EventSource", package: "EventSource"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Sources/HuggingFace"
        ),
    ]
)
