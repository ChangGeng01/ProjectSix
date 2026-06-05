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
        // BASBrainCLI — executable for terminal use of
        // BASCognitiveBrain. `swift run BASBrainCLI "input"`
        .executable(
            name: "BASBrainCLI",
            targets: ["BASBrainCLI"]),
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
        // M2176 chapter 七百三 第二刀 — BASRuntimeCore
        // grows BASMonotonicNanos.swift Swift actor wrapping
        // the M2175 C function `bas_monotonic_nanos` in
        // BASCSystemBridge。 Opt-in via cBridgeEnabled
        // feature flag (default false → V1 DispatchTime path)。
        // Dependency added so `import BASCSystemBridge`
        // resolves in BASMonotonicNanos。
        .target(
            name: "BASRuntimeCore",
            // chapter 七百六 第三刀 — BASAutoRouteRanker calls
            // bas_ranker_*_simd + bas_substrate_sha256 from
            // the Rust XCFramework。 Platform-gated to iOS/macOS
            // matching the binary target。
            dependencies: [
                "BASCSystemBridge",
                .target(
                    name: "BASRustMemoryTrackerBinary",
                    condition: .when(
                        platforms: [.iOS, .macOS]))
            ],
            // M2250 chapter 七百三十六 PHASE B-2 —
            // BASContextClassifier.mlmodel is the first
            // REAL ML adapter (G11 / G8 fulfillment).
            // Bundle.module.url(forResource: "BAS Context
            // Classifier", withExtension: "mlmodel")
            // serves it at runtime. The Swift adapter
            // (Phase B-3) loads it via MLModel(contentsOf:)。
            resources: [
                .process("Resources/BASContextClassifier.mlmodel"),
                // chapter 七百二 第一刀 / M2167 — SQL pilot:
                // chapter doctrine literal data + entropy
                // chapter index ported to .sql resources。
                // Original Swift literals preserved as /* */
                // comments per 「目前 千万不要 删除 只能
                // commented 代码」 directive。 Loader:
                // BASChapterDoctrineSQLLoader.swift。
                .process("SQL/010_chapter_doctrine_records_schema.sql"),
                .process("SQL/011_chapter_doctrine_literals_data.sql"),
                .process("SQL/012_chapter_doctrine_phase2_data.sql"),
                .process("SQL/021_entropy_chapter_entries_schema.sql"),
                .process("SQL/022_entropy_chapter_entries_data.sql"),
                // chapter 七百四十四 第三刀 / M2393 — L3
                // Knowledge Graph V2 binary wire-format
                // migration。 Adds payload_format + payload_blob
                // columns to knowledge_node + knowledge_edge
                // for dual-read codec dispatch (chapter 七百三十二
                // pattern reused)。
                .process("SQL/030_knowledge_graph_v2_migration.sql")
            ]),
        // M2172 chapter 七百二 第二刀 — BASMemory grows
        // a `SQL/` subdirectory (001_memory_usage_records.sql)
        // + attaches the BASSQLSchemaGen build plugin to
        // emit MemoryUsageRecordsSchema at build time。
        //
        // Plugin attached at M2172 so the .sql file is
        // handled and emits no "unhandled file" warning。
        // BASMemoryUsageTracker.swift is UNCHANGED at
        // M2172 — the generated enum is built but unused。
        //
        // M2173 第三刀 switches BASMemoryUsageTracker
        // to optionally consume the generated enum
        // behind `BASLanguageAugmentationFeatureFlags
        // .sqlMigratorEnabled` (default false →
        // V1 inline path)。
        .target(
            name: "BASMemory",
            // chapter 七百四 第二刀 — BASMemoryAtomEventPayload
            // .sha256Hex routes through the Rust pure-NIST-SHA256
            // ABI (bas_substrate_sha256) shipped by the
            // BASRustMemoryTrackerBinary XCFramework。 Platform
            // gate matches the binary target's gate。
            dependencies: [
                "BASRuntimeCore",
                .target(
                    name: "BASRustMemoryTrackerBinary",
                    condition: .when(
                        platforms: [.iOS, .macOS]))
            ],
            plugins: [
                .plugin(name: "BASSQLSchemaGen")
            ]),
        // chapter 七百三十八 第一刀 / M2361 — BASPolicy grows a
        // `SQL/` subdirectory (006_risk_observations_schema.sql)
        // + attaches the BASSQLSchemaGen build plugin to emit
        // RiskObservationsSchema at build time。 Schema-First
        // pattern per the LAYER-MIGRATION ARC plan:net-new SQL
        // persistence for L11 Wind Gate risk observations lands
        // unconditionally;the Rust state-machine port lands at
        // chapter 七百三十九。 ADR-014 OPT-IN preserved — the
        // generated enum is built but unused by the V1
        // in-memory ring actor (BASRiskObservationLedger)。
        // Chapter 七百三十九 wires consumer behind
        // `useRoutedRiskPlane: Bool = false` flag。
        .target(
            name: "BASPolicy",
            dependencies: ["BASRuntimeCore", "BASMemory"],
            plugins: [
                .plugin(name: "BASSQLSchemaGen")
            ]),
        // BASSovereign (L14) — isolated microkernel. Depends only on BASRuntimeCore
        // schema types. Never depends on Memory/Policy/Orchestration (prevents
        // downstream layers from influencing sovereign decisions).
        //
        // chapter 七百四十一 第三刀 / M2378 — BASSovereign gains
        // a SQL/ subdirectory (009_sovereign_tokens.sql) +
        // attaches the BASSQLSchemaGen build plugin。 Net-new
        // L14 token authority persistence layer。 Pairs with the
        // chapter 七百四十一 第一/二刀 Rust seal/verify primitives。
        .target(
            name: "BASSovereign",
            dependencies: ["BASRuntimeCore"],
            plugins: [
                .plugin(name: "BASSQLSchemaGen")
            ]),
        // BASWorldPrior (L4) — world-knowledge layer. A leaf module:
        // depends only on BASRuntimeCore schema. Neither the sovereign
        // kernel nor memory/policy layers depend on it (world priors
        // are consumed upstream, not produced from host state).
        //
        // chapter 七百七十 / M2501 adds the SQL/ subdirectory + plugin
        // for the 4 net-new world-prior schemas (axioms / templates /
        // bridges / domains)。
        .target(
            name: "BASWorldPrior",
            dependencies: ["BASRuntimeCore"],
            resources: [.process("SQL")],
            plugins: [.plugin(name: "BASSQLSchemaGen")]
        ),
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
        // watchOS has no Metal; the framework LINKS below are
        // platform-gated (.when(platforms: [.iOS, .macOS]))。
        // HONEST STATUS (audit ch1040): most Metal source is
        // `#if canImport(Metal)`-gated, but 10 Metal-using files still
        // `import Metal` UNGATED and ~60 consumer references reach
        // their types — so a watchOS compile of this target is NOT
        // currently verified to be the intended "schema-only stub"。
        // BUILD-VERIFIED FOLLOW-UP FINDING (ch1040): watchOS is broken
        // PACKAGE-WIDE, not just here — `swift build` for watchOS fails
        // at resolution on the vendored MLX deps, and (MLX stripped) in
        // BASRuntimeCore's ungated CoreML `compileModel(at:)` BEFORE this
        // target compiles. The 10-file gating is necessary-but-insufficient
        // and can't be watchOS-build-verified, so it is NOT shipped。 See
        // ADR-035 for the ≥4-layer scope + drop-watchOS / split-package options。
        .target(
            name: "BASMetalSubstrate",
            // M2184 chapter 七百五 第二刀 — BASMetalSubstrate
            // gains BASMPSGraphExecutableCacheCxxBridge.swift
            // Swift actor wrapping the C++ cache from
            // BASMPSGraphExecutableCacheCxx (chapter 七百五
            // 第一刀)。 Dependency added so the import
            // resolves。 Opt-in via cxxMpsCacheEnabled flag
            // (default false → V1 path unchanged)。
            dependencies: [
                "BASRuntimeCore",
                "BASMPSGraphExecutableCacheCxx"
            ],
            // M2179 chapter 七百四 第一刀 — switch from
            // `exclude` (chapter 699 / M2163) to
            // `resources: [.process(...)]` so SPM bundles
            // the SSMScan.metal source into the target's
            // Bundle.module。 BASMetalKernelLibraryLoader
            // (M2180) loads + compiles it at runtime via
            // MTLLibrary.makeLibrary(source:options:)。
            //
            // Platform gating:Metal is unavailable on
            // watchOS,so the resource is gated to iOS +
            // macOS — matches the linkerSettings gating
            // for the Metal / MPS / MPSGraph frameworks
            // below。 watchOS continues to compile this
            // target as a thin schema-only stub。
            //
            // ADR-014 OPT-IN preserved:metalKernelV2Enabled
            // flag default-off → V1 kernel selection
            // (BASMPSGraphSSMScanKernelStub +
            // BASSSMScanCPUReference) remains the live
            // dispatch path until a caller opts in。
            resources: [
                .process(
                    "BASBuiltinKernels/SSMScan.metal",
                    localization: nil),
                // chapter 七百三 第五刀 / M2175 — Metal widening:
                // 5 additional kernel files added (LayerNorm
                // forward/backward, activations, softmax
                // variants, conv1d/conv2d, reduce + cosine)。
                // These all compile via SPM's .metal resource
                // handler — no XCFramework changes needed。
                .process(
                    "BASBuiltinKernels/BASLayerNormKernel.metal",
                    localization: nil),
                .process(
                    "BASBuiltinKernels/BASActivationKernels.metal",
                    localization: nil),
                .process(
                    "BASBuiltinKernels/BASSoftmaxKernels.metal",
                    localization: nil),
                .process(
                    "BASBuiltinKernels/BASConvKernels.metal",
                    localization: nil),
                .process(
                    "BASBuiltinKernels/BASReduceKernels.metal",
                    localization: nil),
                // chapter 七百五 第一刀 / M2196 — FlashAttention
                // tiled kernel family (forward + masked + causal)。
                // Memory-efficient attention for long sequences。
                .process(
                    "BASBuiltinKernels/BASFlashAttention.metal",
                    localization: nil)
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
            dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASSovereign", "BASOrchestration", "BASObservability", "BASAdmin", "BASOrgan", "BASLeaseLife"],
            // MiniLM-L6-v2 sentence embedder (CoreML, fp32) + its BERT WordPiece vocab,
            // for the on-device semantic memory backend (BASMiniLMEmbeddingProvider).
            resources: [
                .copy("Resources/MiniLM.mlmodelc"),
                .copy("Resources/vocab.txt"),
            ]
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
                "BASMetalSubstrate",
                // Rust pilot wire-in (chapter 706) —
                // BASRustBrainHistoryStore wraps the
                // Rust-vendored memory usage tracker as
                // an alternative to BASSQLBrainHistory
                // Store for hosts that want fast
                // in-process telemetry without SQLite
                // durability。
                "BASRustCoreBridge",
                // ch1044 audit LOW-8 — declare BASOrgan explicitly.
                // BASLLMNeuralCoreService.swift + BASTrainingExample
                // Sublimator.swift `import BASOrgan`; it previously
                // resolved only via the transitive closure
                // (AppleAdapters→Organ / Orchestration→Organ), a latent
                // fragility if an intermediary ever dropped it. Direct
                // declaration matches the same discipline as the M320
                // BASWorldPrior entry above。
                "BASOrgan"
            ],
            // chapter 七百五十 第一刀 follow-up — silence
            // the pre-existing SPM `unhandled` warning
            // for BASCognitiveBrain.md (an in-source
            // README markdown that ships alongside the
            // public BASCognitiveBrain facade)。 The .md
            // is documentation,not a SPM resource —
            // explicit exclude is the canonical fix。
            exclude: ["BASCognitiveBrain.md"]
        ),
        // M2167 chapter 七百一 第一刀 — MULTI-LANGUAGE
        // AUGMENTATION ARC scaffold (per user directive
        // 「全面 转向 多个 语言:Swift + Metal,Rust,
        // SQL,C,C++」 2026-05-17)。
        //
        // 4 EMPTY scaffold targets reserved for chapters
        // 702-706 per-language pilots。 Each target ships
        // with a `.gitkeep` placeholder source so SPM
        // resolves cleanly。 No production code yet。
        //
        // Targets:
        //   BASCSystemBridge          — chapter 703 C pilot
        //   BASMPSGraphExecutableCacheCxx — chapter 705 C++ pilot
        //   BASRustCoreBridge         — chapter 706 Rust bridge
        //
        // SQL pilot (chapter 702) uses a build PLUGIN,
        // not a target — slot reserved in Plugins/
        // directory at chapter 702 第一刀。
        //
        // Metal pilot (chapter 704) modifies existing
        // BASMetalSubstrate target (exclude → resources)
        // not a new target。
        //
        // ADR-014 OPT-IN preserved:no existing target
        // depends on these scaffolds;all consumers gated
        // by BASLanguageAugmentationFeatureFlags actor
        // (default-off,shipped at M2168 第二刀)。

        // C pilot target placeholder (chapter 703 / M2175+
        // adds real function bas_monotonic_nanos)。 Scaffold
        // ships minimal no-op C source proving SPM
        // .cTarget integration works in this repo。
        .target(
            name: "BASCSystemBridge",
            path: "Sources/BASCSystemBridge",
            publicHeadersPath: "include"),

        // C++ pilot target placeholder (chapter 705 / M2183+
        // adds real MPS cache wrapper)。 Scaffold ships
        // minimal no-op C++ source proving SPM .cxxTarget
        // integration works (mirrors Vendor/mlx-swift/Cmlx
        // precedent)。
        .target(
            name: "BASMPSGraphExecutableCacheCxx",
            path: "Sources/BASMPSGraphExecutableCacheCxx",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include")
            ]),

        // M2188 chapter 七百六 第二刀 — Rust pilot wired in。
        // BASRustMemoryTracker.xcframework committed at
        // M2187 第一刀 to Vendor/bas-rust-binaries/;this
        // commit declares the binaryTarget + adds
        // BASRustMemoryTrackerBinary as dependency of
        // BASRustCoreBridge so the Swift bridge actor
        // (M2189 第三刀) can `import BASRustMemoryTrackerBinary`。
        //
        // Platform-gated to iOS + macOS (no watchOS slice
        // — rustc cannot cross-compile to
        // arm64-apple-watchos)。 At present the XCFramework
        // ships ONLY the macos-arm64 slice;iOS device +
        // simulator slices documented as planned-future-
        // cuts in scripts/build-rust-xcframework.sh
        // TARGETS array。
        .binaryTarget(
            name: "BASRustMemoryTrackerBinary",
            path: "Vendor/bas-rust-binaries/BASRustMemoryTracker.xcframework"),
        .target(
            name: "BASRustCoreBridge",
            // M2189 chapter 七百六 第三刀 — BASRustMemory
            // UsageTrackerActor mirrors the V1 BASMemory
            // UsageTracker shape,so we depend on
            // BASMemory to reach the shared
            // BASMemoryUsageRecord type。
            dependencies: [
                "BASRuntimeCore",
                "BASMemory",
                .target(
                    name: "BASRustMemoryTrackerBinary",
                    condition: .when(
                        platforms: [.iOS, .macOS]))
            ],
            path: "Sources/BASRustCoreBridge"),

        // M2171 chapter 七百二 第一刀 — SQL pilot core +
        // tool + plugin。 Three-target pattern:
        //
        //   BASSQLSchemaGenCore  — pure-Swift codegen
        //                          function;tests import
        //                          this directly。
        //   BASSQLSchemaGenTool  — executable;parses argv,
        //                          delegates to core。
        //                          Invoked by the build
        //                          plugin per `.sql` file。
        //   BASSQLSchemaGen      — plugin manifest;tells
        //                          SPM which command to
        //                          run per input file。
        //
        // Consumers attach the plugin via target.plugins
        // (see BASMemory target at M2173 第三刀)。 Targets
        // without a `SQL/` subdirectory see the plugin
        // become a no-op。
        .target(
            name: "BASSQLSchemaGenCore",
            path: "Sources/BASSQLSchemaGenCore"),
        .executableTarget(
            name: "BASSQLSchemaGenTool",
            dependencies: ["BASSQLSchemaGenCore"],
            path: "Sources/BASSQLSchemaGenTool"),

        // BASBrainCLI — real product surface: terminal CLI
        // for exercising BASCognitiveBrain.process() +
        // safetyVerdict() end-to-end. Hosts integrating
        // the substrate can use this as a reference for
        // their own integration.
        .executableTarget(
            name: "BASBrainCLI",
            dependencies: [
                "BASHostKit",
                "BASRuntimeCore",
                "BASMemory",
                "BASPolicy"
            ],
            path: "Sources/BASBrainCLI"),
        .plugin(
            name: "BASSQLSchemaGen",
            capability: .buildTool(),
            dependencies: [
                .target(name: "BASSQLSchemaGenTool")
            ],
            path: "Plugins/BASSQLSchemaGen"),

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
            "BASMetalSubstrate",
            // M2171 chapter 七百二 第一刀 — codegen core
            // exposed to tests so BASSQLSchemaGenCoreTests
            // can validate pure-function behavior without
            // spawning the executable tool。
            "BASSQLSchemaGenCore",
            // M2189 chapter 七百六 第三刀 — Rust bridge
            // exposed to tests so BASRustMemoryUsage
            // TrackerActorTests can validate ABI surface +
            // Codable wire-format byte-equality vs V1。
            "BASRustCoreBridge",
            // chapter 七百五 第五刀 — chapter-705 integration
            // tests need bas_lsh_* + bas_flat_index_* symbols
            // exposed by the C++ cache target,plus bas_spsc_ring_*
            // exposed by the C system bridge target。
            "BASMPSGraphExecutableCacheCxx",
            "BASCSystemBridge"
        ])
    ]
)
