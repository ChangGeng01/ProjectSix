// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BehavioralAISubstrate",
    platforms: [
        // watchOS was DROPPED at ch1040 (ADR-035 option A): it was broken
        // package-wide (the vendored MLX deps fail to resolve for watchOS,
        // and BASRuntimeCore's CoreML + BASMetalSubstrate's Metal cannot
        // compile there) and was never a real target for a Metal/CoreML/MLX
        // device-ML substrate. Re-adding it requires the ADR-035 §watchOS work.
        .iOS(.v18),
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
        // audit M-o MED-2 — SwiftUI-only console view, split out of BASAdmin
        // so the substrate core (and headless hosts) stay SwiftUI-free.
        .library(name: "BASAdminUI", targets: ["BASAdminUI"]),
        .library(name: "BASAppleAdapters", targets: ["BASAppleAdapters"]),
        // charter audit 2026-07-12 T4 — pure lifecycle half + edge-wiring ring.
        .library(name: "BASAppleLifecycleKit", targets: ["BASAppleLifecycleKit"]),
        .library(name: "BASAppleEdgeWiring", targets: ["BASAppleEdgeWiring"]),
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
        // REFRESHED TO LATEST on the vendor-latest-refresh branch
        // (2026-06-11, commit fd7233805 — mlx-swift-lm 3.31.3 era;
        // see that commit for the exact per-package versions) and
        // stripped of `Tests/` / `Documentation/` / `cmake/` for
        // size discipline. The M224 url→path rewrites + the ADR-038
        // wedge instruments were re-applied — full procedure in
        // Docs/VENDOR_REFRESH_RECIPE.md.
        //
        // Why the full transitive set is vendored: pinning only
        // direct deps still leaves SPM resolving transitives from
        // remote URLs, which defeats the purpose if upstream is
        // unreachable. Updates require an explicit `Vendor/` swap.
        // audit M-o MED-3 — swift-crypto (Ed25519 sovereign seals +
        // NIST-SHA256 chain hashes) was in the graph ONLY transitively via
        // swift-huggingface / swift-transformers; a vendor refresh that
        // dropped it would break 87 security-critical `import Crypto` files
        // across 10 targets. Declared explicitly at root so the crypto
        // dependency is first-class, not contingent on an ML tokenizer
        // package. Same on-disk path SPM already resolves ⇒ same identity,
        // no duplicate (byte-equal build).
        .package(path: "Vendor/swift-crypto"),
        // audit x-architecture LOW-4 — explicit mlx-swift (base MLX / MLXNN /
        // MLXOptimizers) was in the graph ONLY transitively via mlx-swift-lm;
        // BASMLXAdapter imports MLX/MLXNN/MLXOptimizers directly. Declared at
        // root so the base MLX dependency is first-class, not contingent on the
        // mlx-swift-lm LLM package (a vendor refresh that dropped mlx-swift-lm's
        // dep would break the direct imports). Same on-disk path SPM already
        // resolves (mlx-swift-lm references it as ../mlx-swift) ⇒ same identity,
        // no duplicate (byte-equal build). Mirrors the swift-crypto MED-3 fix.
        .package(path: "Vendor/mlx-swift"),
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
                // audit M-o MED-3 — explicit swift-crypto (was transitive-only)
                .product(name: "Crypto", package: "swift-crypto"),
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
                // audit M-o MED-3 — explicit swift-crypto (was transitive-only)
                .product(name: "Crypto", package: "swift-crypto"),
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
            // audit M-o MED-3 — explicit swift-crypto: L14 sovereign seals
            // (Ed25519) must not depend on an ML package's transitive graph.
            dependencies: [
                "BASRuntimeCore",
                .product(name: "Crypto", package: "swift-crypto")],
            resources: [.process("Resources")],
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
        .target(name: "BASOrgan", dependencies: ["BASRuntimeCore",
            // audit M-o MED-3 — explicit swift-crypto (was transitive-only)
            .product(name: "Crypto", package: "swift-crypto")]),
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
        // The framework LINKS below are platform-gated to iOS + macOS。
        // NOTE (ch1040): the package's `.watchOS` platform was DROPPED
        // (ADR-035 option A) — watchOS was broken package-wide (the
        // vendored MLX deps fail to resolve for watchOS; BASRuntimeCore's
        // CoreML + this target's 10 ungated `import Metal` files cannot
        // compile there) and was never a real target for a Metal/CoreML/MLX
        // device-ML substrate. The `#if canImport(Metal)` gating elsewhere
        // in this module stays as defensive practice (harmless on iOS/macOS)。
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
                // audit x-architecture LOW-4 — explicit mlx-swift base products
                // (was transitive-only via mlx-swift-lm). This target imports
                // MLX / MLXNN / MLXOptimizers directly.
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                // audit M-o MED-3 — explicit swift-crypto (was transitive-only)
                .product(name: "Crypto", package: "swift-crypto"),
                .product(
                    name: "MLXLLM",
                    package: "mlx-swift-lm"),
                .product(
                    name: "MLXLMCommon",
                    package: "mlx-swift-lm"),
                .product(
                    name: "Tokenizers",
                    package: "swift-transformers"),
                // audit x-arch LOW-5: the "Hub" product edge was phantom — no `import Hub`, no
                // #hubDownloader/#huggingFaceTokenizerLoader macro invocation in Sources/ (Tokenizers
                // resolves Hub internally via the package graph). Removed 2026-07-10, full DeviceTestApp
                // xcodebuild verified green.
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
        .target(name: "BASObservability", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy",
            // audit M-o MED-3 — explicit swift-crypto (was transitive-only)
            .product(name: "Crypto", package: "swift-crypto")]),
        // BASOrchestration depends on BASObservability because M58
        // `BASUpdateTicketObservationDerivation` needs to read
        // `BASUpdateTicket` (defined in BASObservability) to produce a
        // per-ticket observation bundle on the main-chain thought frame.
        // Safe topology: BASObservability does not import BASOrchestration,
        // so no cycle.
        // audit x-arch LOW-5: BASLeaseLife edge was phantom — no `import BASLeaseLife` in
        // Sources/BASOrchestration/, no re-export dependency (removed 2026-07-10, build-verified).
        .target(name: "BASOrchestration", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASSovereign", "BASWorldPrior", "BASOrgan", "BASObservability",
            // audit M-o MED-3 — explicit swift-crypto (was transitive-only)
            .product(name: "Crypto", package: "swift-crypto")]),
        .target(
            name: "BASEvaluation",
            // Memory + Policy dropped (audit ch1040): no BASEvaluation source imports them —
            // the module documents intentional isolation from both. BASObservability remains
            // (and transitively provides them if ever needed). Aligns manifest with actual usage.
            dependencies: ["BASRuntimeCore", "BASObservability"]
        ),
        .target(name: "BASAdmin", dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASSovereign", "BASOrchestration", "BASObservability", "BASEvaluation", "BASWorldPrior"]),
        // audit M-o MED-2 — the SwiftUI BASConsoleView (was inside BASAdmin,
        // forcing headless hosts to link SwiftUI transitively). Isolated here
        // so only explicit UI hosts pull in SwiftUI.
        .target(name: "BASAdminUI", dependencies: ["BASAdmin"]),
        // charter audit 2026-07-12 T4 — the LLM-outside cut. Pure-Swift Apple lifecycle /
        // executor / config types that BASHostKit's public API is built on (they never
        // invoke a model runtime; their old home in BASAppleAdapters wove the
        // FoundationModels-linking module into the core host umbrella). BASHostKit now
        // depends on THIS target only; BASAppleAdapters re-exports it for compatibility.
        // BOUNDARY (pinned by BASModelBoundaryPinTests): this target must NEVER import
        // CoreML / FoundationModels / CoreAI / MLX / Tokenizers.
        // charter audit 2026-07-12 T4 — the edge-wiring ring: sees BOTH BASHostKit and
        // BASAppleAdapters; cross-side model-bound conveniences live here so neither side
        // links the other.
        .target(
            name: "BASAppleEdgeWiring",
            dependencies: ["BASRuntimeCore", "BASHostKit", "BASAppleAdapters"]),
        .target(
            name: "BASAppleLifecycleKit",
            dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASObservability", "BASOrchestration", "BASLeaseLife"]),
        .target(
            name: "BASAppleAdapters",
            dependencies: ["BASRuntimeCore", "BASMemory", "BASPolicy", "BASSovereign", "BASOrchestration", "BASObservability", "BASAdmin", "BASOrgan", "BASLeaseLife",
                // charter audit 2026-07-12 T4: the pure lifecycle half moved out; the
                // re-export in Exports.swift keeps every existing importer compiling.
                "BASAppleLifecycleKit",
                // audit M-o MED-3 — explicit swift-crypto (was transitive-only)
                .product(name: "Crypto", package: "swift-crypto"),
                // RoBERTa BPE tokenizer for the CoreAI NLI verifier (BASCoreAINLIVerifier)
                .product(name: "Tokenizers", package: "swift-transformers")],
            // MiniLM-L6-v2 sentence embedder (CoreML, fp32) + its BERT WordPiece vocab,
            // for the on-device semantic memory backend (BASMiniLMEmbeddingProvider).
            resources: [
                .copy("Resources/MiniLM.mlmodelc"),
                .copy("Resources/vocab.txt"),
                // The Core AI shadow-classifier asset (ADR-041). Produced by
                // scripts/PhaseB_ContextClassifier/convert_coreai.py (coreai_torch: PyTorch → .aimodel) — which
                // BYPASSES the Apple Xcode-27-beta `aimodelc` Metal-Toolchain version gate by going through the
                // `metal`-based Python converter. Python-runtime parity vs the PyTorch reference: 5/5 argmax,
                // logits-MAE ~1e-6. BASCoreAIContextClassifierAdapter loads it via Bundle.module on iOS 27.
                .copy("Resources/BASContextClassifier.aimodel"),
            ]
        ),
        .target(
            name: "BASHostKit",
            dependencies: [
                // (swift-crypto dep removed: commit 44ba14dad moved the sole
                //  swift-crypto user, BASSovereignLedgerHostSink, to native
                //  CryptoKit; all ~40 crypto files in this target now use
                //  CryptoKit, so the M-o MED-3 explicit dep here is vestigial.)
                "BASRuntimeCore",
                "BASMemory",
                "BASPolicy",
                "BASSovereign",
                "BASOrchestration",
                "BASObservability",
                "BASEvaluation",
                "BASAdmin",
                // charter audit 2026-07-12 T4: was BASAppleAdapters — the LLM-adapter
                // module is no longer in the core host umbrella's link closure. Model
                // probes (MiniLM embedder, CoreAI NLI) are now INJECTED by the edge.
                "BASAppleLifecycleKit",
                "BASLeaseLife",
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
                // gaps-reconciliation x-architecture LOW-4 (2026-07-11): 11 BASHostKit files
                // import BASRustMemoryTrackerBinary but the dep was TRANSITIVE-only (via
                // BASRustCoreBridge) — if that path is ever trimmed, the one #if canImport site
                // (BASCognitiveMetalKernels.swift) degrades SILENTLY. Declare it, conditioned
                // exactly like BASRustCoreBridge's own dep (no watchOS slice).
                .target(
                    name: "BASRustMemoryTrackerBinary",
                    condition: .when(
                        platforms: [.iOS, .macOS])),
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
            exclude: ["BASCognitiveBrain.md"],
            // observe→DISPOSE: bundled CC0 Wikidata starter fact corpus (1131) so the adjudicator's
            // fact bank loads on a sandboxed, network-less device. Expandable to the full dump offline.
            resources: [.copy("Resources/wikidata_facts.json")]
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
        // arm64-apple-watchos)。 The XCFramework ships ALL
        // THREE slices — ios-arm64 (device), ios-arm64-
        // simulator, macos-arm64 — built by
        // scripts/build-rust-xcframework.sh (verified in the
        // xcframework Info.plist; ADR-037). The device slice
        // exports the L8 engine FFI symbols (ch1027 on-device
        // BASRustVerifyProbe all_ok),so the Rust engine links
        // + runs on a physical device。
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
                // audit x-arch LOW-5: BASMemory/BASPolicy edges were phantom — main.swift imports
                // only Foundation/BASHostKit/BASRuntimeCore, and BASHostKit already declares +
                // @_exports both (removed 2026-07-10, build-verified).
                "BASHostKit",
                "BASRuntimeCore"
            ],
            path: "Sources/BASBrainCLI"),

        // BASJournalCLI — "The Ledger" (#20 first daily workload). A sovereign decision &
        // thread journal over the real event-sourced memory store; the first LIVE workload
        // that fires the memory / deletion-doctrine / pagination chambers on a daily path.
        .executableTarget(
            name: "BASJournalCLI",
            dependencies: [
                // audit M-o MED-3 — explicit swift-crypto (was transitive-only)
                .product(name: "Crypto", package: "swift-crypto"),
                "BASMemory",
                "BASRuntimeCore",
                "BASSovereign",
                // increment 3: the ShadowTrial "was I right?" loop. BASOrchestration is the only
                // module that can see both BASMemory (the coordinator) and BASSovereign (the
                // ledger), so it hosts the BASSovereignAuditLedger→BASShadowTrialLedger bridge +
                // the makeWithDefaultStateMachine factory.
                "BASOrchestration",
                // increment 2b: route add through the L1-L14 spine for a governance verdict.
                // BASHostKit holds BASCognitiveBrain + runTurn; BASPolicy holds the permit/risk
                // enums (BASActionPermitMode / BASBrainRiskLevel) named in the honest verdict string.
                "BASHostKit",
                "BASPolicy",
                // grounding increment 2 (semantic citation ASSISTANT, hint-only): the bundled
                // MiniLM-L6-v2 CoreML embedder (BASMiniLMEmbeddingProvider) — genuinely imported
                // by SemanticHint.swift, not a phantom edge (x-arch LOW-5 lesson).
                "BASAppleAdapters"
            ],
            path: "Sources/BASJournalCLI"),
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
            "BASCSystemBridge",
            "BASAppleLifecycleKit", "BASAppleEdgeWiring",
        ]),
        // Universal Draft Layer — XCTest-ONLY target (no swift-testing), so these run in their OWN .xctest bundle
        // and are not blocked by the swift-testing/XCTest co-bundle load crash in BehavioralAISubstrateTests.
        .testTarget(name: "BASUniversalDraftLayerTests", dependencies: [
            "BASRuntimeCore",
            "BASOrgan",
            "BASMLXAdapter"
        ])
    ]
)
