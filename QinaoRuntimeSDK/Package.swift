// swift-tools-version: 6.0

import PackageDescription

/// QinaoRuntimeSDK — 绮脑运行时 SDK
///
/// Four-layer nesting (see the plan's §1):
///
///   Human Host → Qinao SDK → Second Brain (L1–L14) → Neural Network
///
/// This package is the *承载协议* (carrying protocol) between the
/// human host and the second brain. Seven public modules, each
/// wraps a BAS internal library; the `BAS*` symbols never leak
/// through a Qinao public API.
///
/// Three invariants are contracts, not advertising (§2):
///   1. 先醒再答 — L1 arbitrates wake/budget before generation
///   2. 神经不直接掌权 — three-signature gate (permit + warrant + proof)
///   3. 宿主私有经验不进基础权重 — L5 write audit + L13 ticket shadow
let package = Package(
    name: "QinaoRuntimeSDK",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v14)
    ],
    products: [
        .library(name: "QinaoRuntime", targets: ["QinaoRuntime"]),
        .library(name: "QinaoHost", targets: ["QinaoHost"]),
        .library(name: "QinaoMemory", targets: ["QinaoMemory"]),
        .library(name: "QinaoLoop", targets: ["QinaoLoop"]),
        .library(name: "QinaoRisk", targets: ["QinaoRisk"]),
        .library(name: "QinaoSovereign", targets: ["QinaoSovereign"]),
        .library(name: "QinaoWorldPrior", targets: ["QinaoWorldPrior"]),
        .library(name: "QinaoUI", targets: ["QinaoUI"]),
        // M180 — opt-in Apple FoundationModels endpoint factory.
        // Hosts wanting Apple LLM `import QinaoAppleFoundation`;
        // hosts that don't keep a substrate-only QinaoLoop graph.
        .library(
            name: "QinaoAppleFoundation",
            targets: ["QinaoAppleFoundation"]),
        // M222 — opt-in MLX (downloaded Gemma) endpoint factory.
        // Mirrors QinaoAppleFoundation: hosts wanting open-weights
        // Gemma 3 / 3n via MLX `import QinaoMLX`; hosts that only
        // want Apple FM or remote API stay decoupled from the
        // mlx-swift-lm + swift-transformers + swift-huggingface
        // dep tree.
        .library(
            name: "QinaoMLX",
            targets: ["QinaoMLX"]),
        // M228 — testable SwiftUI library backing QinaoSampleApp.
        // Lifted out of the executable target so test suites can
        // exercise ContentView + SampleSession with mocked endpoint
        // builders. Hosts wanting a SwiftUI demo surface ready to
        // embed into their own app `import QinaoSample`.
        .library(
            name: "QinaoSample",
            targets: ["QinaoSample"]),
        // M203 — runnable demo executable. `swift run QinaoSampleHost
        // "<prompt>"` drives QinaoLoop with the real Apple LLM
        // endpoint and prints the frontier candidate end-to-end.
        // Proves the public API is consumable as an actual program,
        // not just a test framework.
        .executable(
            name: "QinaoSampleHost",
            targets: ["QinaoSampleHost"]),
        // M219 — SwiftUI macOS GUI demo. `swift run QinaoSampleApp`
        // opens a window with provider picker / prompt input /
        // response panel. Same SDK calls as QinaoSampleHost, just
        // visible.
        .executable(
            name: "QinaoSampleApp",
            targets: ["QinaoSampleApp"])
    ],
    dependencies: [
        .package(path: "../BehavioralAISubstrate")
    ],
    targets: [
        // QinaoHost — L5 façade. Host version tree, candidate
        // pipeline, projections, delete/freeze/rollback.
        .target(
            name: "QinaoHost",
            dependencies: [
                .product(name: "BASRuntimeCore", package: "BehavioralAISubstrate"),
                .product(name: "BASMemory", package: "BehavioralAISubstrate")
            ]),
        // QinaoMemory — L8 façade. Hot/warm/cold retrieval,
        // cascade delete, scoped projections.
        .target(
            name: "QinaoMemory",
            dependencies: [
                .product(name: "BASRuntimeCore", package: "BehavioralAISubstrate"),
                .product(name: "BASMemory", package: "BehavioralAISubstrate")
            ]),
        // QinaoRisk — L11 risk-gate façade. ActionPermit request,
        // GSI computation, delay/replace/block modes.
        .target(
            name: "QinaoRisk",
            dependencies: [
                .product(name: "BASRuntimeCore", package: "BehavioralAISubstrate"),
                .product(name: "BASPolicy", package: "BehavioralAISubstrate")
            ]),
        // QinaoSovereign — L14 control-plane façade. Public
        // surface: rollback / freeze / halt / issue warrant.
        // Internal modules (IntegritySentinel, VerdictEngine,
        // TokenAuthority, AuditLedger, SnapshotManager,
        // PrivilegeArbiter, ContaminationGuard, LockManager,
        // StubRenderer) stay private inside BASSovereign and
        // are never re-exported here.
        .target(
            name: "QinaoSovereign",
            dependencies: [
                .product(name: "BASRuntimeCore", package: "BehavioralAISubstrate"),
                .product(name: "BASSovereign", package: "BehavioralAISubstrate"),
                // M127 — L12 BASRenderFrame (in BASOrchestration) is the
                // second per-turn aggregator we store on this control
                // plane. Added so render-frame streaming methods can
                // take the type by value without a bridge struct.
                .product(name: "BASOrchestration", package: "BehavioralAISubstrate")
            ]),
        // QinaoLoop — L9 dream loop + L10 tribunal façade.
        // Optionally folds L4 world priors (`QinaoWorldPrior`) into
        // candidate critique: a host-declared claim attached to a
        // candidate is evaluated against the vault's axioms via
        // `evaluateHostOverride`, and the `.clean / .demote / .reject`
        // outcome feeds a world-prior-contradiction term into the
        // critique strength. This closes the L4↔L9 loop cited on the
        // honesty board's "会想不自转" row without changing the
        // existing host-supplied scoring path (claims are opt-in).
        .target(
            name: "QinaoLoop",
            dependencies: [
                "QinaoWorldPrior",
                .product(name: "BASRuntimeCore", package: "BehavioralAISubstrate"),
                .product(name: "BASOrgan", package: "BehavioralAISubstrate"),
                .product(name: "BASOrchestration", package: "BehavioralAISubstrate")
            ]),
        // QinaoWorldPrior — L4 world-prior vault façade. Public
        // surface: horizons, axioms, causal templates, cross-domain
        // bridges, counterfactual branches, boundary-bedrock
        // override guard. Internal `BASWorldPrior*` symbols never
        // leak through a public API; all types are Qinao-owned
        // mirrors translated in `QinaoWorldPriorProjection`.
        .target(
            name: "QinaoWorldPrior",
            dependencies: [
                .product(name: "BASRuntimeCore", package: "BehavioralAISubstrate"),
                .product(name: "BASWorldPrior", package: "BehavioralAISubstrate")
            ]),
        // QinaoRuntime — composes Host + Risk + Sovereign into
        // a session-level three-signature gate. Depends on the
        // other Qinao modules (not on BAS directly, except for
        // the run-mode / schema types re-exported through BASHostKit).
        .target(
            name: "QinaoRuntime",
            dependencies: [
                "QinaoHost",
                "QinaoMemory",
                "QinaoRisk",
                "QinaoSovereign",
                "QinaoLoop",
                "QinaoWorldPrior",
                .product(name: "BASRuntimeCore", package: "BehavioralAISubstrate"),
                .product(name: "BASOrgan", package: "BehavioralAISubstrate"),
                .product(name: "BASLeaseLife", package: "BehavioralAISubstrate"),
                .product(name: "BASWorldPrior", package: "BehavioralAISubstrate"),
                // M80 — cross-chain ledger bridge: QinaoRuntime is the
                // only layer that may import BASMemory (for the
                // `BASShadowTrialLedger` protocol seam), BASSovereign
                // (for the append-only chain), and BASOrchestration
                // (for the `BASSovereignAuditLedger: BASShadowTrialLedger`
                // conformance extension) in the same module.
                .product(name: "BASMemory", package: "BehavioralAISubstrate"),
                .product(name: "BASSovereign", package: "BehavioralAISubstrate"),
                .product(name: "BASOrchestration", package: "BehavioralAISubstrate"),
                // M137 — L11 `BASRiskObservationBundle` lives in
                // BASPolicy; needed so sendSession can co-derive L10
                // and L11 from one caller-supplied thoughtFrame.
                .product(name: "BASPolicy", package: "BehavioralAISubstrate"),
                // M138 — L13 `BASUpdateTicket` lives in
                // BASObservability. Required for shadow-trial
                // streaming in sendSession.
                .product(name: "BASObservability", package: "BehavioralAISubstrate"),
                // M82 — main-trunk turn-artifacts projection: the
                // composition layer is the only place that may carry
                // the substrate's turn-result type across the seam
                // between BAS and Qinao. The bridge helper that
                // consumes that type is `package`-scoped so the
                // forbidden redaction token never reaches a public
                // Qinao symbol.
                .product(name: "BASHostKit", package: "BehavioralAISubstrate")
            ]),
        // QinaoUI — SwiftUI components. Separated so headless
        // servers can depend on QinaoRuntime without pulling in
        // SwiftUI.
        .target(
            name: "QinaoUI",
            dependencies: []),
        // M180 — public factory wiring Apple FoundationModels
        // behind QinaoOrganEndpoint. Optional library: hosts that
        // don't want Apple-specific code (or BASAppleAdapters'
        // FoundationModels link) skip this target.
        .target(
            name: "QinaoAppleFoundation",
            dependencies: [
                "QinaoLoop",
                .product(name: "BASOrgan", package: "BehavioralAISubstrate"),
                .product(name: "BASAppleAdapters", package: "BehavioralAISubstrate")
            ]),
        // M222 — public factory wiring downloaded MLX Gemma weights
        // behind QinaoOrganEndpoint. Mirrors QinaoAppleFoundation;
        // optional library for hosts that want open-weights Gemma
        // via the mlx-swift-lm pipeline.
        .target(
            name: "QinaoMLX",
            dependencies: [
                "QinaoLoop",
                .product(name: "BASOrgan", package: "BehavioralAISubstrate"),
                .product(name: "BASMLXAdapter", package: "BehavioralAISubstrate")
            ]),
        // M228 — testable SwiftUI library backing QinaoSampleApp.
        // ContentView / SampleSession / SampleProvider live here so
        // tests can `@testable import QinaoSample` instead of trying
        // to drive an executable target.
        .target(
            name: "QinaoSample",
            dependencies: [
                "QinaoLoop",
                "QinaoAppleFoundation",
                "QinaoMLX"
            ]),
        // M219 — SwiftUI macOS GUI demo executable. M228 thinned to
        // just @main + window scene; UI lives in the QinaoSample
        // library so snapshot tests can render ContentView headless.
        .executableTarget(
            name: "QinaoSampleApp",
            dependencies: [
                "QinaoSample"
            ]),
        // M203 — runnable demo executable target. CLI that takes a
        // prompt argument, drives QinaoLoop with Apple FM, prints
        // the frontier candidate. Single-file main.swift; no extra
        // module structure.
        .executableTarget(
            name: "QinaoSampleHost",
            dependencies: [
                "QinaoLoop",
                "QinaoAppleFoundation",
                // M233 — `--lora-train` mode uses MLXLoRATrainer.
                // M234 — `--apple-fm-curriculum` mode uses
                // AppleFoundationOrganAdapter directly with
                // includeRiskCurriculum / includePermitCurriculum
                // flags wired in BAS.
                "QinaoMLX",
                .product(
                    name: "BASMLXAdapter",
                    package: "BehavioralAISubstrate"),
                .product(
                    name: "BASAppleAdapters",
                    package: "BehavioralAISubstrate"),
                // M213 — `--provider chatcompletions` flag uses the
                // generic OpenAI-compatible HTTP adapter. Optional
                // dep at build time but required when the flag is
                // selected at run time.
                .product(
                    name: "BASChatCompletionsAdapter",
                    package: "BehavioralAISubstrate"),
                .product(
                    name: "BASOrgan",
                    package: "BehavioralAISubstrate")
            ]),
        .testTarget(
            name: "QinaoRuntimeSDKTests",
            dependencies: [
                "QinaoRuntime",
                "QinaoHost",
                "QinaoMemory",
                "QinaoLoop",
                "QinaoRisk",
                "QinaoSovereign",
                "QinaoWorldPrior",
                "QinaoUI",
                // M180 — exercise the public factory directly so the
                // host pattern is covered end-to-end.
                "QinaoAppleFoundation",
                // M222 — exercise QinaoMLX façade in unit tests
                // (factory shape, model identity, redaction).
                "QinaoMLX",
                // M228 — exercise QinaoSample SwiftUI library
                // (SampleSession caching + ContentView snapshot).
                "QinaoSample",
                .product(name: "BASOrgan", package: "BehavioralAISubstrate"),
                // M178 — env-gated end-to-end test (`QINAO_FM_E2E=1`)
                // wires `AppleFoundationOrganAdapter` through a
                // host-style `QinaoOrganEndpoint` conformance and
                // drives `QinaoLoop.generateCandidates` with the real
                // on-device LLM. Test-target-only dep so production
                // QinaoLoop stays decoupled from Apple adapters.
                .product(name: "BASAppleAdapters", package: "BehavioralAISubstrate")
            ])
    ]
)
