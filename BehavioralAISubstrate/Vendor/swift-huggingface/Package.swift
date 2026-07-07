// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// BAS vendor freeze (M225 / mega-audit x-sov #3, 2026-07-08): the Xet trait is
// OFF in every BAS build,so its remote dependency must not present SwiftPM a
// remote resolution face by default。 Opt in with BAS_VENDOR_ALLOW_REMOTE=1
// only for a deliberate vendor refresh (Docs/VENDOR_REFRESH_RECIPE.md)。
var packageDependencies: [Package.Dependency] = [
    .package(path: "../EventSource"),  // M224 vendor freeze: url -> path
    .package(path: "../swift-crypto"),
]
var huggingFaceDependencies: [Target.Dependency] = [
    .product(name: "EventSource", package: "EventSource"),
    .product(name: "Crypto", package: "swift-crypto"),
]
if Context.environment["BAS_VENDOR_ALLOW_REMOTE"] == "1" {
    packageDependencies.append(
        .package(url: "https://github.com/huggingface/swift-xet.git", from: "0.2.0"))
    huggingFaceDependencies.append(
        .product(name: "Xet", package: "swift-xet", condition: .when(traits: ["Xet"])))
}

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
    traits: [
        .trait(
            name: "Xet",
            description: "Enable Xet transport support.",
        )
    ],
    dependencies: packageDependencies,
    targets: [
        .target(
            name: "HuggingFace",
            dependencies: huggingFaceDependencies,
            path: "Sources/HuggingFace",
            swiftSettings: [
                .define("HUGGINGFACE_ENABLE_XET", .when(traits: ["Xet"]))
            ]
        ),
        .testTarget(
            name: "HuggingFaceTests",
            dependencies: ["HuggingFace"],
            swiftSettings: [
                .define("HUGGINGFACE_ENABLE_XET", .when(traits: ["Xet"]))
            ]
        ),
        .testTarget(
            name: "HubBenchmarks",
            dependencies: ["HuggingFace"],
            swiftSettings: [
                .define("HUGGINGFACE_ENABLE_XET", .when(traits: ["Xet"]))
            ]
        ),
    ]
)
