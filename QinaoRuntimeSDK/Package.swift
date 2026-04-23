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
        .library(name: "QinaoUI", targets: ["QinaoUI"])
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
                .product(name: "BASSovereign", package: "BehavioralAISubstrate")
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
                .product(name: "BASOrgan", package: "BehavioralAISubstrate")
            ])
    ]
)
