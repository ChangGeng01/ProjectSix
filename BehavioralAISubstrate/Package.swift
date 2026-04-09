// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BehavioralAISubstrate",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BASRuntimeCore", targets: ["BASRuntimeCore"]),
        .library(name: "BASMemory", targets: ["BASMemory"]),
        .library(name: "BASPolicy", targets: ["BASPolicy"]),
        .library(name: "BASOrchestration", targets: ["BASOrchestration"]),
        .library(name: "BASObservability", targets: ["BASObservability"]),
        .library(name: "BASEvaluation", targets: ["BASEvaluation"]),
        .library(name: "BASAdmin", targets: ["BASAdmin"]),
        .library(name: "BASAppleAdapters", targets: ["BASAppleAdapters"])
    ],
    targets: [
        .target(name: "BASRuntimeCore"),
        .target(name: "BASMemory"),
        .target(name: "BASPolicy", dependencies: ["BASRuntimeCore", "BASMemory"]),
        .target(name: "BASOrchestration", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy"]),
        .target(name: "BASObservability", dependencies: ["BASRuntimeCore", "BASPolicy"]),
        .target(name: "BASEvaluation", dependencies: ["BASObservability"]),
        .target(name: "BASAdmin", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASEvaluation"]),
        .target(name: "BASAppleAdapters", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy"]),
        .testTarget(name: "BehavioralAISubstrateTests", dependencies: [
            "BASRuntimeCore",
            "BASMemory",
            "BASPolicy",
            "BASOrchestration",
            "BASObservability",
            "BASEvaluation",
            "BASAdmin",
            "BASAppleAdapters"
        ])
    ]
)
