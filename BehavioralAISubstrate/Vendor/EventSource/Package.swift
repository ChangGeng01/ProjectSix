// swift-tools-version: 6.1
// M224 vendor freeze. Original Package.swift edits:
//   - async-http-client url: dep removed (trait gated to off; we
//     do not vendor it and the AsyncHTTPClient trait is never
//     enabled in the BAS build)
//   - swift-nio url: rewritten to path: ../swift-nio
// Original repo: https://github.com/mattt/EventSource

import PackageDescription

let package = Package(
    name: "EventSource",
    platforms: [
        .iOS("15.0"),
        .macOS("12.0"),
        .macCatalyst("15.0"),
        .watchOS("8.0"),
        .tvOS("15.0"),
        .visionOS("1.0"),
    ],
    products: [
        .library(
            name: "EventSource",
            targets: ["EventSource"]
        )
    ],
    dependencies: [
        .package(path: "../swift-nio"),
    ],
    targets: [
        .target(
            name: "EventSource",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
            ]
        ),
    ]
)
