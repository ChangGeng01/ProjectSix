// swift-tools-version: 6.0

import PackageDescription

/// QinaoRuntimeSDK — 绮脑运行时 SDK
///
/// Four-layer nesting (see the plan's §1):
///
///   Human Host → Qinao SDK → Second Brain (L1–L14) → Neural Network
///
/// This package is the *承载协议* (carrying protocol) between the
/// human host and the second brain. The Qinao facade modules each wrap a BAS
/// substrate library. charter audit 2026-07-12 HONESTY FIX: an earlier version of
/// this header claimed "the BAS* symbols never leak through a Qinao public API" —
/// that is NOT true and is not the design: substrate VALUE TYPES flow through Qinao
/// surfaces deliberately (QinaoLifecycle exposes BASThermalTwin.Reading /
/// BASThermalGuardLevel / BASLeaseLifeCoordinator.TurnRecorded; TurnInputs carries
/// BASContextFrame / BASDecomposeFrame / BASMemoryBundle / BASThoughtFrame /
/// BASNeuralOrganMap; the redaction scanner bans specific internal tokens, not BAS*
/// generally). What the facades DO hide is substrate ORCHESTRATION (runTurn,
/// coordinators, reducers) — hosts consume typed artifacts, never drive internals.
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
        // M292.1 — typed seat scaffold (single-brain-multi-seat).
        // First slice: enum + verdict struct only; no protocol,
        // no registry yet.
        .library(name: "QinaoSeats", targets: ["QinaoSeats"]),
        // M292.3 — default seat implementations that read from a
        // QinaoLoop. Separate target so QinaoSeats stays
        // dependency-free (abstract scaffold) and QinaoLoopSeats
        // carries the concrete-with-loop layer.
        .library(name: "QinaoLoopSeats", targets: ["QinaoLoopSeats"]),
        // M294 — convenience factory layer. Wires "standard"
        // seeded vault + standard seats with one call so hosts
        // doing demos don't have to re-derive sensible defaults.
        .library(name: "QinaoDefaults", targets: ["QinaoDefaults"]),
        // ch1050 / v1.0 §11 — thin SDK surfaces re-exporting the substrate squeeze
        // objects under the outline's Qinao* module names (value-type re-use,
        // consistent with QinaoMemory/QinaoRisk surfacing BAS value types).
        .library(name: "QinaoEffort", targets: ["QinaoEffort"]),
        .library(name: "QinaoTranscript", targets: ["QinaoTranscript"]),
        .library(name: "QinaoAxis", targets: ["QinaoAxis"]),
        .library(name: "QinaoOldSeal", targets: ["QinaoOldSeal"]),
        .library(name: "QinaoStudio", targets: ["QinaoStudio"]),
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
        // ch1050 / v1.0 §11 — thin SDK surfaces: typealias re-exports of the
        // substrate squeeze objects under the Qinao* names from the outline.
        .target(name: "QinaoEffort", dependencies: [
            .product(name: "BASRuntimeCore", package: "BehavioralAISubstrate")]),
        .target(name: "QinaoTranscript", dependencies: [
            .product(name: "BASOrgan", package: "BehavioralAISubstrate")]),
        .target(name: "QinaoAxis", dependencies: [
            .product(name: "BASOrchestration", package: "BehavioralAISubstrate")]),
        .target(name: "QinaoOldSeal", dependencies: [
            .product(name: "BASMemory", package: "BehavioralAISubstrate")]),
        .target(name: "QinaoStudio", dependencies: [
            .product(name: "BASMemory", package: "BehavioralAISubstrate")]),
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
        // M292.1 — typed seat scaffold. Zero deps: just the
        // QinaoSeat enum + SeatVerdict struct so any module can
        // reference seats by Swift type without pulling Loop /
        // Risk / Sovereign. Registry / dispatch / default seat
        // implementations land in M292.2+.
        .target(
            name: "QinaoSeats",
            dependencies: []),
        // M292.3 — default seat implementations bound to a
        // QinaoLoop. Each seat takes a loop reference at init
        // and reads the loop's typed state inside `contribute`.
        // Convention: dispatcher passes `sessionID` as `snapshotID`.
        .target(
            name: "QinaoLoopSeats",
            dependencies: [
                "QinaoSeats",
                "QinaoLoop"
            ]),
        // M294 — one-call sensible-default factories for hosts
        // doing first-day integration. Wires seeded vault + loop
        // + standard seats together.
        .target(
            name: "QinaoDefaults",
            dependencies: [
                "QinaoLoop",
                "QinaoLoopSeats",
                "QinaoSeats",
                "QinaoWorldPrior",
                "QinaoUI",
                // integration S2 (2026-07-12) — the LLM-free sovereign host assembly
                // (QinaoSovereignHostAssembly.swift) composes the full stack. BOUNDARY:
                // QinaoAppleFoundation / QinaoMLX must NEVER appear here (pinned by
                // QinaoBoundaryPinTests).
                "QinaoHost",
                "QinaoMemory",
                "QinaoRisk",
                "QinaoSovereign",
                "QinaoRuntime",
                .product(name: "BASRuntimeCore", package: "BehavioralAISubstrate"),
                .product(name: "BASMemory", package: "BehavioralAISubstrate")
            ]),
        // M180 — public factory wiring Apple FoundationModels
        // behind QinaoOrganEndpoint. Optional library: hosts that
        // don't want Apple-specific code (or BASAppleAdapters'
        // FoundationModels link) skip this target.
        .target(
            name: "QinaoAppleFoundation",
            dependencies: [
                "QinaoLoop",
                .product(name: "BASOrgan", package: "BehavioralAISubstrate"),
                .product(name: "BASAppleAdapters", package: "BehavioralAISubstrate"),
                // observe→DISPOSE: route the registered organ through the default-OFF factual-belief
                // adjudicator wrap (BASLLMNeuralCoreService.adjudicating). BASHostKit @_exported-imports
                // BASAppleAdapters, so this adds no new transitive surface for this target.
                .product(name: "BASHostKit", package: "BehavioralAISubstrate")
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
                .product(name: "BASMLXAdapter", package: "BehavioralAISubstrate"),
                // charter audit 2026-07-12 T4: BASMiniLMEmbeddingProvider is edge-injected
                // by this LLM-side factory (BASHostKit no longer links the adapter module);
                // explicit dep so the import is manifest-honest, not transitively lucky.
                .product(name: "BASAppleAdapters", package: "BehavioralAISubstrate"),
                // observe→DISPOSE: route the registered MLX organ through the default-OFF factual-belief
                // adjudicator wrap (BASLLMNeuralCoreService.adjudicating). BASHostKit is NOT an MLX/HF type,
                // so the redaction seam (check_mlx_redaction.sh) stays clean — the wrap is body-only, the
                // public factory signature is unchanged (still `async throws -> any QinaoOrganEndpoint`).
                // TRADE-OFF (audit INFO): BASHostKit widens this target's transitive link closure by the
                // host-kit modules NOT already pulled via QinaoLoop→BASOrchestration→BASMemory — notably
                // BASAppleAdapters (→ FoundationModels), BASMetalSubstrate, BASEvaluation, BASAdmin. Accepted
                // because every standalone QinaoMLX consumer (QinaoSample / QinaoSampleHost) already links
                // QinaoAppleFoundation → BASAppleAdapters → FoundationModels, so NO module newly gains it; the
                // alternative (relocating `adjudicating` out of BASHostKit) is net-new code for no real win.
                .product(name: "BASHostKit", package: "BehavioralAISubstrate")
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
                "QinaoMLX",
                // M301 — wire QinaoSurfaceShowcaseView into the
                // sample app so hosts trying the SDK see all six
                // L12 surface families on first run, not just the
                // prompt/response panel.
                "QinaoUI",
                // integration sample-upgrade (2026-07-12) — the sample now demonstrates
                // the CHARTER posture: LLM endpoint on this side of the boundary, output
                // crossing as data into the assembled LLM-free sovereign spine. The
                // sample links BOTH sides BY DESIGN (it is a host, not an in-boundary
                // module — QinaoBoundaryPinTests guards the assembly targets, not hosts).
                "QinaoDefaults",
                "QinaoRuntime",
                "QinaoSovereign",
                "QinaoMemory"
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
                    package: "BehavioralAISubstrate"),
                // M272 — `--full-stack-demo` mode wires
                // M259/M261/M265/M268/M270/M273/M274 lifecycle.
                // BASObservability owns the
                // BASUpdateTicketLifecycleCoordinator + storage
                // protocol. BASRuntimeCore owns
                // BASSovereignAuditEntry (audit-sink payload).
                .product(
                    name: "BASObservability",
                    package: "BehavioralAISubstrate"),
                .product(
                    name: "BASRuntimeCore",
                    package: "BehavioralAISubstrate"),
                // M306 — `--multi-session-demo` mode drives
                // BASHostRuntime.startSession across two
                // sequential sessions sharing one
                // SQLite-backed audit ledger to prove
                // cross-session chain integrity. BASHostKit
                // owns BASHostRuntime + BASHostConfiguration.
                // BASMemory owns the host-constitution + vault
                // primitives the configuration consumes.
                // BASSovereign owns the SQLite ledger storage
                // + integrity verification helpers.
                .product(
                    name: "BASHostKit",
                    package: "BehavioralAISubstrate"),
                .product(
                    name: "BASMemory",
                    package: "BehavioralAISubstrate"),
                .product(
                    name: "BASSovereign",
                    package: "BehavioralAISubstrate"),
                .product(
                    name: "BASPolicy",
                    package: "BehavioralAISubstrate"),
                .product(
                    name: "BASAdmin",
                    package: "BehavioralAISubstrate"),
                // M313 — `--phase-dispatch-demo` mode + M314
                // `--multi-turn-demo` mode wire QinaoDefaults
                // (M312) and QinaoSeats / QinaoLoopSeats so the
                // sample-host can build a 9-seat council and
                // dispatch by phase, plus drive the multi-turn
                // driver pattern from M310 against a real
                // endpoint.
                "QinaoDefaults",
                "QinaoSeats",
                "QinaoLoopSeats",
                // M326 — `--persona-panel-review` mode runs
                // BASWorldPriorAIPersonaReviewer against the
                // 50-template starter curriculum via Apple
                // Foundation Models. Doctrine A: panel
                // consensus does NOT promote envelope.
                "QinaoWorldPrior",
                // M334 — `--throughput-bench` mode drives
                // BASLeaseLifeCoordinator.recordTurn(...) for
                // thermal/breath quantification across N turns.
                .product(
                    name: "BASLeaseLife",
                    package: "BehavioralAISubstrate"),
                // M393 — `--cthulhu-doctrine-demo` mode exercises
                // M384-M389 typed primitives directly. Needs
                // BASOrchestration (escalation, ceiling gate,
                // abyssal/anchor schemas, doctrine red-line enum)
                // + BASWorldPrior (BASUnknownReserve schema).
                .product(
                    name: "BASOrchestration",
                    package: "BehavioralAISubstrate"),
                .product(
                    name: "BASWorldPrior",
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
                // M292.1 — exercise QinaoSeats typed scaffold.
                "QinaoSeats",
                // M292.3 — exercise default seat implementations.
                "QinaoLoopSeats",
                // M294 — exercise convenience defaults.
                "QinaoDefaults",
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
                .product(name: "BASAppleAdapters", package: "BehavioralAISubstrate"),
                // M333 + M334 — tests that pin
                // `BASEvolutionLifecycleSession` (chapter 五十六) +
                // `BASLeaseLifeCoordinator` substrate contracts
                // the sample-host evolution-loop / throughput-bench
                // demos rely on.
                .product(name: "BASMemory", package: "BehavioralAISubstrate"),
                .product(name: "BASLeaseLife", package: "BehavioralAISubstrate"),
                // M357 + M358 + M359 — tests that pin
                // `BASSovereignAuditLedger` /
                // `BASSovereignFragmentMerger` /
                // `BASMultiHostConvergenceMetric` /
                // `BASHostRuntime` / `BASBenchLatencyStats`
                // substrate contracts the sample-host
                // audit-ledger-bench / multi-host-merge-bench /
                // full-stack-bench modes rely on.
                .product(name: "BASSovereign", package: "BehavioralAISubstrate"),
                .product(name: "BASRuntimeCore", package: "BehavioralAISubstrate"),
                .product(name: "BASHostKit", package: "BehavioralAISubstrate"),
                .product(name: "BASObservability", package: "BehavioralAISubstrate"),
                // M393 — tests that pin Cthulhu doctrine substrate
                // contracts the sample-host
                // `--cthulhu-doctrine-demo` mode relies on
                // (BASAbyssalPermitEscalation +
                // BASAssertionCeilingGate + BASNarrativeDistortion +
                // BASAbyssalDoctrineRedLine in BASOrchestration;
                // BASUnknownReserve in BASWorldPrior;
                // BASActionPermit in BASPolicy).
                .product(name: "BASOrchestration", package: "BehavioralAISubstrate"),
                .product(name: "BASWorldPrior", package: "BehavioralAISubstrate"),
                .product(name: "BASPolicy", package: "BehavioralAISubstrate")
            ])
    ]
)
