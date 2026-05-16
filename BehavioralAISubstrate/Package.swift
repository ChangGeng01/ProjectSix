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
            targets: ["BASMLXAdapter"]),
        // M1096 — RADICAL EVOLUTION SWEEP Phase E entry。
        // BASMetalSubstrate ships native Apple Silicon
        // primitives:typed BASTensor (with discriminated
        // backing across MLX/CoreML/Metal),BASANECapability
        // introspection,BASMetalKernelRegistry actor,
        // and reference MPSGraph kernels (MatMul / RMSNorm
        // / RotaryEmbedding)。 First module to touch
        // MTLDevice + MPSGraph directly。
        .library(
            name: "BASMetalSubstrate",
            targets: ["BASMetalSubstrate"])
    ],
    dependencies: [
        // M224 — vendor freeze. All MLX / HuggingFace dependencies
        // live in BehavioralAISubstrate/Vendor/ as path packages.
        // Build is now self-contained: no GitHub fetch is required
        // to resolve the substrate. The 15 vendored packages were
        // copied at the M220 + M221 + M222 pinned revisions and
        // stripped of `Tests/` / `Documentation/` / `cmake/` for
        // size discipline (~75 MB total).
        //
        // Why the full transitive set is vendored: pinning only
        // direct deps still leaves SPM resolving transitives from
        // remote URLs, which defeats the purpose if upstream is
        // unreachable. Updates require an explicit `Vendor/` swap.
        .package(path: "Vendor/mlx-swift-lm"),
        .package(path: "Vendor/swift-transformers"),
        .package(path: "Vendor/swift-huggingface")
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
        // M1096 — RADICAL EVOLUTION SWEEP Phase E entry。
        // BASMetalSubstrate ships native Apple Silicon
        // primitives:typed BASTensor (with discriminated
        // backing across MLX/CoreML/Metal),BASANECapability
        // introspection,BASMetalKernelRegistry actor,
        // and reference MPSGraph kernels (MatMul / RMSNorm
        // / RotaryEmbedding)。 First module to touch
        // MTLDevice + MPSGraph directly。
        //
        // Frameworks linked:
        //   - Metal           — MTLDevice / MTLCommandQueue / MTLBuffer
        //   - MetalPerformanceShaders      — MPSImage / MPSMatrix kernels
        //   - MetalPerformanceShadersGraph — MPSGraph executable build
        //   - Accelerate      — vDSP / BNNS fallback paths
        //   - CoreML          — MLMultiArray bridge for ANE dispatch
        //
        // watchOS has no Metal; framework links are gated by
        // platform inside source files via `#if canImport(Metal)`。
        // The target itself compiles as a thin schema-only stub
        // on watchOS so BASRuntimeCore consumers stay portable。
        .target(
            name: "BASMetalSubstrate",
            dependencies: ["BASRuntimeCore"],
            // M2163 chapter 六百九十九 第一刀 — exclude the
            // SSMScan.metal reference shader file from
            // SPM build。 SPM doesn't compile .metal
            // sources natively (Xcode build system does)。
            // The file ships as reference for hosts that
            // integrate via Xcode project + custom Metal
            // compilation step。 Excluding silences the
            // persistent "unhandled file" warning that
            // has been present since chapter 六百七十七
            // / M2089 when Phase M SSM kernel landed。
            exclude: [
                "BASBuiltinKernels/SSMScan.metal"
            ],
            linkerSettings: [
                .linkedFramework(
                    "Metal",
                    .when(platforms: [.iOS, .macOS])),
                .linkedFramework(
                    "MetalPerformanceShaders",
                    .when(platforms: [.iOS, .macOS])),
                .linkedFramework(
                    "MetalPerformanceShadersGraph",
                    .when(platforms: [.iOS, .macOS])),
                .linkedFramework(
                    "Accelerate",
                    .when(platforms: [.iOS, .macOS])),
                .linkedFramework(
                    "CoreML",
                    .when(platforms: [.iOS, .macOS]))
            ]),
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
                "BASAppleAdapters",
                // M320 — `buildSovereignAuditEntry` accepts an
                // optional `BASUnknownReserve` projection (white
                // paper §5.4). The schema lives in BASWorldPrior;
                // host kit imports it to type the audit entry's
                // optional parameter.
                "BASWorldPrior",
                // M1100 — Phase F entry。 BASTurnRuntimeEngine
                // Configuration grows optional `metalKernelRegistry`
                // + `aneCapability` slots so callers can wire
                // BASMetalSubstrate primitives into the runtime
                // composition path。 BASHardwareAwareScheduler
                // (M1102) consumes the same primitives via
                // injection。
                "BASMetalSubstrate"
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
            "BASMLXAdapter",
            "BASMetalSubstrate"
        ])
    ]
)
