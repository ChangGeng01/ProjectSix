// MARK: - BASTurnRuntimeFullSummaryStressSweepRunner
// chapter 四百七十八 / M1290 — V1 fold PILOT regression guard
//
// REAL coordinator-driven `BASStressSweepHarness.FixtureRunner`
// factory。 Closes the chapter 434 deferral note that the
// canonical60 driver explicitly punted:
//
//   > "What this DOES NOT ship (deferred):
//    > The REAL V1+V2 coordinator-driven runner that:
//    >   - Constructs a BASEBrainRuntimeCoordinator
//    >   - Runs each fixture's request through V1's runTurn
//    >   - ... Returns the (V1, V2) pair to the harness
//    > Building that real-coordinator runner requires the
//    > same ~30 service stubs that BASEBrainSchemaCoreTests
//    > inlines per-test."
//
// Chapter 462 M1225 shipped `BASCoordinatorTestStubs` —
// the 30-service stub harness。 M1290 wires that harness
// to the BASStressSweepHarness FixtureRunner contract,
// closing the 1.5-year-deferred regression-guard gap。
//
// ## Why this exists (system entropy framing)
//
// The chapter 478 V1 fold pilot (M1288 trio extraction +
// M1289 coordinator splice) preserves byte-equality by
// construction:the factory dispatches the same 3 derive
// calls in the same order。 But "by construction" is not
// the same as "proven"。 Future chapters (492-493) fold
// 36 more declarations + 6 permit rebinds — each fold
// carries byte-equality risk。
//
// `BASTurnRuntimeFullSummaryStressSweepRunner` ships the
// REGRESSION GUARD:
//
//   - Takes a caller-provided coordinator factory closure
//     (e.g。 `BASCoordinatorTestStubs.makeStub`) + request
//     builder closure
//   - For each canonical60 fixture key:invokes the
//     factory twice,runs `runTurn(_:)` on each,extracts
//     `BASRuntimeAuditEmissionSummary` via M993 factory,
//     returns `(v1Summary, v2Summary)` pair
//   - BASStressSweepHarness then SHA256 digests both
//     summaries + compares via `.matches(_:)` →
//     divergence detection
//
// In chapters 478-491:returns IDENTICAL summaries
// (V1↔V1 determinism check)。 Catches any non-deterministic
// drift the fold work introduces。
//
// In chapter 489+ (when V2 path actually exists):the
// v2Summary closure swaps to call `BASTurnRuntimeEngine
// .runWithPlan(_:plan:)` instead of a second V1 invocation
// → real V1↔V2 dual-mode comparison。
//
// ## What this ships (M1290)
//
//   - `BASTurnRuntimeFullSummaryStressSweepRunner` enum
//     namespace
//   - `CoordinatorFactory` typealias for caller-injected
//     coordinator builder
//   - `RequestBuilder` typealias for fixture-key →
//     request transformation
//   - `dualV1Runner(coordinatorFactory:requestBuilder:)`
//     static factory returning a typed FixtureRunner
//   - `defaultRequestBuilder(for:)` helper producing a
//     minimal deterministic request from a fixture key
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed factory + typealias
//     prevents magic closure shapes
//   - chapter 二百一一 — single source-of-truth for V1
//     fold regression guard
//   - chapter 三百九二 — replay-determinism is the
//     INVARIANT this runner enforces。 Identical inputs
//     → identical summaries → equal digests
//   - chapter 四百三十四 plannedFutureCuts honored
//     (real-coordinator runner deferral closed)
//   - 不变量 #1/#2/#3 — runner is observation-only
//   - 红线 7 — runner produces evidence,not commitment
//   - ADR-014 OPT-IN — additive only。 Hosts may use
//     this in CI;production unaffected

import Foundation
import BASRuntimeCore

/// Factory namespace producing real coordinator-driven
/// FixtureRunner closures for the BASStressSweepHarness。
/// Closes the chapter 434 deferral by leveraging the
/// chapter 462 BASCoordinatorTestStubs harness。
public enum BASTurnRuntimeFullSummaryStressSweepRunner {

    /// Caller-injected coordinator factory closure。
    /// Tests typically pass `BASCoordinatorTestStubs.makeStub`。
    /// Production callers can wire a real host-runtime-
    /// service-bound coordinator factory。
    public typealias CoordinatorFactory =
        @Sendable () -> BASEBrainRuntimeCoordinator

    /// Caller-injected fixture-key → request builder。
    /// Maps the typed fixture's dimensions (risk +
    /// permitMode + quarantines + etc.) into a concrete
    /// `BASEBrainTurnRequest`。 Use `.defaultRequestBuilder(for:)`
    /// for a minimal deterministic mapping。
    public typealias RequestBuilder = @Sendable (
        BASTurnRuntimeStressFixtureKey
    ) -> BASEBrainTurnRequest

    // MARK: - Dual-V1 runner (chapter 478 baseline)

    /// Build a `FixtureRunner` that drives 2 V1 coordinator
    /// invocations per fixture key + extracts audit
    /// summaries via M993 `BASRuntimeAuditEmissionSummary
    /// .from(result:)`。 Returns the `(v1Summary,
    /// v2Summary)` pair to the harness。
    ///
    /// In chapters 478-488:both summaries come from V1。
    /// Harness equality verifies V1↔V1 determinism — any
    /// drift across the two invocations of the SAME
    /// `runTurn(_:)` with the SAME request indicates
    /// non-determinism (chapter 三百九二 violation)。
    ///
    /// In chapter 489+:swap the second invocation to
    /// `engine.runWithPlan(_:plan:)` for real V1↔V2
    /// dual-mode comparison。
    public static func dualV1Runner(
        coordinatorFactory:
            @escaping CoordinatorFactory,
        requestBuilder:
            @escaping RequestBuilder
    ) -> BASStressSweepHarness.FixtureRunner {
        return { key in
            let request = requestBuilder(key)
            let coord1 = coordinatorFactory()
            let result1 = coord1.runTurn(request)
            let summary1 =
                BASRuntimeAuditEmissionSummary.from(
                    result: result1)
            let coord2 = coordinatorFactory()
            let result2 = coord2.runTurn(request)
            let summary2 =
                BASRuntimeAuditEmissionSummary.from(
                    result: result2)
            return (
                v1Summary: summary1,
                v2Summary: summary2)
        }
    }

    // MARK: - Default request builder

    /// Build a minimal deterministic
    /// `BASEBrainTurnRequest` from a fixture key。 Maps
    /// the typed fixture-key dimensions (risk +
    /// permitMode + etc.) into request fields:
    ///
    ///   - `userInput` → "stress-sweep:" + key label
    ///   - `deviceState` → nominal device fixture
    ///     (battery 0.8, thermal nominal, network online,
    ///     foreground, npuAvailable per fixture-key
    ///     `neuralCoreWired`)
    ///   - `hostID` → "stress-sweep.host"
    ///   - `recordedAt` → fixed epoch (Jan 1 2024) for
    ///     replay-determinism
    ///   - `riskHint` → fixture-key risk bucket mapped to
    ///     BASBrainRiskLevel
    public static func defaultRequestBuilder(
        for key: BASTurnRuntimeStressFixtureKey
    ) -> BASEBrainTurnRequest {
        let deviceState = BASDeviceState(
            batteryLevel: 0.8,
            thermalLevel: .nominal,
            memoryFreeMB: 2048,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.2,
            gpuLoad: 0.1,
            npuAvailable: key.neuralCoreWired,
            latencyBudgetMs: 1500)
        let riskHint: BASBrainRiskLevel
        switch key.risk {
        case .low: riskHint = .low
        case .medium: riskHint = .medium
        case .high: riskHint = .high
        case .extreme: riskHint = .extreme
        }
        return BASEBrainTurnRequest(
            userInput: "stress-sweep:" + key.label,
            deviceState: deviceState,
            hostID: "stress-sweep.host",
            recordedAt: Date(
                timeIntervalSince1970: 1_704_067_200),
            riskHint: riskHint)
    }
}
