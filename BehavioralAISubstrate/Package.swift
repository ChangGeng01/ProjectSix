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
        .library(name: "BASHostKit", targets: ["BASHostKit"]),
        .library(name: "BASRuntimeCore", targets: ["BASRuntimeCore"]),
        .library(name: "BASMemory", targets: ["BASMemory"]),
        .library(name: "BASPolicy", targets: ["BASPolicy"]),
        .library(name: "BASOrchestration", targets: ["BASOrchestration"]),
        .library(name: "BASObservability", targets: ["BASObservability"]),
        .library(name: "BASEvaluation", targets: ["BASEvaluation"]),
        .library(name: "BASAdmin", targets: ["BASAdmin"]),
        .library(name: "BASAppleAdapters", targets: ["BASAppleAdapters"]),
        .library(name: "BASSovereign", targets: ["BASSovereign"]),
        .library(name: "BASWorldPrior", targets: ["BASWorldPrior"]),
        .library(name: "BASLeaseLife", targets: ["BASLeaseLife"]),
        .library(name: "BASOrgan", targets: ["BASOrgan"])
    ],
    targets: [
        .target(name: "BASRuntimeCore"),
        .target(name: "BASMemory", dependencies: ["BASRuntimeCore"]),
        .target(name: "BASPolicy", dependencies: ["BASRuntimeCore", "BASMemory"]),
        // BASSovereign (L14) — isolated microkernel. Depends only on BASRuntimeCore
        // schema types. Never depends on Memory/Policy/Orchestration (prevents
        // downstream layers from influencing sovereign decisions).
        .target(name: "BASSovereign", dependencies: ["BASRuntimeCore"]),
        // BASWorldPrior (L4) — world-knowledge layer. A leaf module:
        // depends only on BASRuntimeCore schema. Neither the sovereign
        // kernel nor memory/policy layers depend on it (world priors
        // are consumed upstream, not produced from host state).
        .target(name: "BASWorldPrior", dependencies: ["BASRuntimeCore"]),
        // BASLeaseLife (L1) — thermal/pressure observation + breath
        // scheduling + long-session accumulation. Leaf module: depends
        // only on BASRuntimeCore schema (BASThermalLevel /
        // BASThermalGuardLevel / BASMaintenanceClass). Platform-specific
        // bindings (BGTaskScheduler) live in adapters, not here.
        .target(name: "BASLeaseLife", dependencies: ["BASRuntimeCore"]),
        // BASOrgan (L2/L3) — neural-organ adapter contract. Leaf
        // module: depends only on BASRuntimeCore. Defines the
        // protocol + Scout/Core presets + an in-memory deterministic
        // fake for tests. Platform providers (Apple FoundationModels,
        // MLX, remote LLMs) live in adapter layers.
        .target(name: "BASOrgan", dependencies: ["BASRuntimeCore"]),
        .target(name: "BASOrchestration", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASSovereign", "BASWorldPrior", "BASLeaseLife", "BASOrgan"]),
        .target(name: "BASObservability", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy"]),
        .target(
            name: "BASEvaluation",
            dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASObservability"]
        ),
        .target(name: "BASAdmin", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASSovereign", "BASOrchestration", "BASObservability", "BASEvaluation"]),
        .target(
            name: "BASAppleAdapters",
            dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASSovereign", "BASOrchestration", "BASObservability", "BASAdmin", "BASOrgan", "BASLeaseLife"]
        ),
        .target(
            name: "BASHostKit",
            dependencies: [
                "BASRuntimeCore",
                "BASMemory",
                "BASPolicy",
                "BASSovereign",
                "BASOrchestration",
                "BASObservability",
                "BASEvaluation",
                "BASAdmin",
                "BASAppleAdapters"
            ]
        ),
        .testTarget(name: "BehavioralAISubstrateTests", dependencies: [
            "BASHostKit",
            "BASRuntimeCore",
            "BASMemory",
            "BASPolicy",
            "BASSovereign",
            "BASWorldPrior",
            "BASLeaseLife",
            "BASOrgan",
            "BASOrchestration",
            "BASObservability",
            "BASEvaluation",
            "BASAdmin",
            "BASAppleAdapters"
        ])
    ]
)
