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
        .library(name: "BASOrgan", targets: ["BASOrgan"]),
        // M208 — generic OpenAI/Anthropic/llama.cpp-compatible
        // HTTP organ provider. Proves BASOrganAdapter protocol is
        // truly provider-agnostic. Optional library — hosts that
        // only want on-device adapters skip it.
        .library(
            name: "BASChatCompletionsAdapter",
            targets: ["BASChatCompletionsAdapter"]),
        // M220 — opt-in MLX (Apple Silicon, on-device) organ
        // provider for downloaded Gemma 3 / 3n weights. Pulls in
        // mlx-swift-lm + swift-transformers transitive deps; hosts
        // that only want Apple FoundationModels or remote HTTP
        // providers skip this library.
        .library(
            name: "BASMLXAdapter",
            targets: ["BASMLXAdapter"])
    ],
    dependencies: [
        // M220 — pinned to a known-good revision (護欄 #1 from the
        // M220 plan: explicit revision, not from: semver). Update
        // by bumping the hash deliberately; do not migrate to
        // .upToNextMajor without an audit pass.
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm",
            revision:
                "7e2b7107be52ffbfe488f3c7987d3f52c1858b4b"),
        .package(
            url: "https://github.com/huggingface/swift-transformers",
            revision:
                "15bcc471a2de73ce3c17c08781f34a1f9bebaf70"),
        // M221 — explicit top-level pin so BASMLXAdapter can list
        // `HuggingFace` as a target dep (transitive visibility from
        // swift-transformers is not enough for SPM product binding).
        .package(
            url: "https://github.com/huggingface/swift-huggingface",
            revision:
                "b721959445b617d0bf03910b2b4aced345fd93bf")
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
        // BASChatCompletionsAdapter — generic remote-LLM organ
        // provider. URLSession-backed, OpenAI Chat Completions
        // JSON shape. Conforms to BASOrganAdapter so it drops into
        // any registry the same way the deterministic / Apple FM
        // adapters do.
        .target(
            name: "BASChatCompletionsAdapter",
            dependencies: ["BASRuntimeCore", "BASOrgan"]),
        // M220 — MLX organ adapter. Loads quantized Gemma weights
        // from Hugging Face and runs on-device inference via
        // mlx-swift-lm. Implementation behind
        // `#if canImport(MLXLLM)` so watchOS (no Metal) and
        // unsupported platforms compile to a stub that reports
        // unavailable through `currentCapacity()`.
        .target(
            name: "BASMLXAdapter",
            dependencies: [
                "BASRuntimeCore",
                "BASOrgan",
                .product(
                    name: "MLXLLM",
                    package: "mlx-swift-lm"),
                .product(
                    name: "MLXLMCommon",
                    package: "mlx-swift-lm"),
                .product(
                    name: "Tokenizers",
                    package: "swift-transformers"),
                .product(
                    name: "Hub",
                    package: "swift-transformers"),
                // M221 — MLXHuggingFace freestanding macros
                // (#hubDownloader / #huggingFaceTokenizerLoader)
                // bridge HuggingFace.HubClient + Tokenizers into
                // MLXLMCommon.Downloader + TokenizerLoader.
                .product(
                    name: "MLXHuggingFace",
                    package: "mlx-swift-lm"),
                .product(
                    name: "HuggingFace",
                    package: "swift-huggingface")
            ]),
        .target(name: "BASObservability", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy"]),
        // BASOrchestration depends on BASObservability because M58
        // `BASUpdateTicketObservationDerivation` needs to read
        // `BASUpdateTicket` (defined in BASObservability) to produce a
        // per-ticket observation bundle on the main-chain thought frame.
        // Safe topology: BASObservability does not import BASOrchestration,
        // so no cycle.
        .target(name: "BASOrchestration", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASSovereign", "BASWorldPrior", "BASLeaseLife", "BASOrgan", "BASObservability"]),
        .target(
            name: "BASEvaluation",
            dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASObservability"]
        ),
        .target(name: "BASAdmin", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASSovereign", "BASOrchestration", "BASObservability", "BASEvaluation", "BASWorldPrior"]),
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
            "BASAppleAdapters",
            "BASChatCompletionsAdapter",
            "BASMLXAdapter"
        ])
    ]
)
