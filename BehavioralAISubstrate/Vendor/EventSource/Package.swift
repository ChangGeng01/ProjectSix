// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "EventSource",
            targets: ["EventSource"]
        )
    ],
    traits: [
        .trait(name: "AsyncHTTPClient")
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.24.0"),
        .package(path: "../swift-nio"),  // M224 vendor freeze: url -> path
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "EventSource",
            dependencies: [
                .product(
                    name: "AsyncHTTPClient",
                    package: "async-http-client",
                    condition: .when(traits: ["AsyncHTTPClient"])
                ),
                .product(name: "NIOCore", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "EventSourceTests",
            dependencies: [
                "EventSource",
                .product(
                    name: "AsyncHTTPClient",
                    package: "async-http-client",
                    condition: .when(traits: ["AsyncHTTPClient"])
                ),
            ]
        ),
    ]
)


// BAS vendor patch (see Docs/VENDOR_REFRESH_RECIPE.md): vendored third-party code — suppress its compiler
// warnings so FIRST-PARTY diagnostics stay visible in Xcode/CI (this package's warnings are upstream's to fix;
// we never act on them). `unsafeFlags` is PERMITTED because the M224 vendor freeze consumes every package as a
// LOCAL PATH dependency (SwiftPM forbids unsafeFlags only for versioned dependencies).
for target in package.targets where target.type == .regular || target.type == .macro {
    var sw = target.swiftSettings ?? []
    sw.append(.unsafeFlags(["-suppress-warnings"]))
    target.swiftSettings = sw
    var cs = target.cSettings ?? []
    cs.append(.unsafeFlags(["-w"]))
    target.cSettings = cs
    var cx = target.cxxSettings ?? []
    cx.append(.unsafeFlags(["-w"]))
    target.cxxSettings = cx
}
