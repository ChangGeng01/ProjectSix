// MARK: - BASEBrainTurnResultReplayHarness — Step 1 (the byte-equal replay safety net)
//
// Completes the gap the stress-sweep infrastructure left open. The prior harnesses
// (`BASStressSweepHarness` / `BASTurnRuntimeFullSummaryStressSweepRunner` / the readiness gate)
// compare a ~10-field `BASRuntimeAuditEmissionSummary` DIGEST — NOT the full
// `BASEBrainTurnResult`. This harness digests the FULL result (all ~55 fields) after pinning the
// one observation-clock field that legitimately drifts (`memoryBundle.retrievedAt`), so it can:
//
//   (A) `determinismVerdict`            — same request, N fresh-coordinator runs → byte-identical
//   (B) `codableRoundTripIsByteStable`  — encode → decode → re-encode → byte-equal
//   (C) `v1VsRunWithPlanParityVerdict`  — `coordinator.runTurn` vs `engine.runWithPlan` full parity
//
// (C) is byte-equal BY CONSTRUCTION today: `runWithPlan` returns the same
// `coordinator.runTurn(request)` value (`BASTurnRuntimeEngine.swift:574`). So the parity API is a
// REGRESSION TRIPWIRE — it fails the day a future change makes `runWithPlan` synthesize a
// divergent result. It is the evidence gate for Step 3b (promoting `.nativeV2` to a real
// `runWithPlan` dispatch).
//
// Reuses the established `CoordinatorFactory` injection (tests pass
// `BASCoordinatorTestStubs.makeStub`; production passes a real host-runtime coordinator factory)
// plus `defaultRequestBuilder` + the canonical60 fixtures.
//
// SCOPE: the harness REQUIRES a deterministic coordinator (the stub, or a host coordinator with
// injected clock/ID factories). The production `BASCognitiveBrain` path uses `UUID()`/wall-clock
// ticket IDs and is intentionally OUT of scope for byte-equality — this is why the harness takes a
// factory, not a `BASCognitiveBrain`. Building it against that path would be a false tripwire
// (亏的不要上). ADR-014 — purely additive; no production call site routes through it.

import Foundation

public enum BASEBrainTurnResultReplayHarness {

    /// Caller-injected coordinator factory. Tests pass `BASCoordinatorTestStubs.makeStub`.
    public typealias CoordinatorFactory =
        @Sendable () -> BASEBrainRuntimeCoordinator

    /// chapter 一百八十五 — typed default run count for determinism checks.
    public static let defaultRunCount: Int = 3

    /// Fixed default `producedAt` (epoch 0). Metadata only — never affects the compared
    /// `digestString` — so a fixed value keeps verdicts reproducible.
    public static let fixedProducedAt = Date(timeIntervalSince1970: 0)

    // MARK: - Verdict

    /// Outcome of a replay check. `isStable` ⇔ every run produced the same canonical digest.
    public struct ReplayVerdict: Sendable, Equatable {
        public let runCount: Int
        public let distinctDigestCount: Int
        public let firstDigest: String
        public let divergingRunIndex: Int?

        public var isStable: Bool {
            distinctDigestCount == 1 && divergingRunIndex == nil
        }

        public init(
            runCount: Int,
            distinctDigestCount: Int,
            firstDigest: String,
            divergingRunIndex: Int?
        ) {
            self.runCount = runCount
            self.distinctDigestCount = distinctDigestCount
            self.firstDigest = firstDigest
            self.divergingRunIndex = divergingRunIndex
        }
    }

    // MARK: - (A) determinism

    /// Run the SAME request through `runCount` FRESH coordinators (mirroring the
    /// `dualV1Runner` fresh-per-invocation discipline) and assert every full-result canonical
    /// digest matches. Drift ⇒ a non-determinism (chapter 三百九二) violation in something OTHER
    /// than the canonicalized observation-clock fields.
    public static func determinismVerdict(
        coordinatorFactory: @escaping CoordinatorFactory,
        request: BASEBrainTurnRequest,
        runCount: Int = defaultRunCount,
        canonicalize: Bool = true
    ) -> ReplayVerdict {
        precondition(runCount > 0, "runCount must be > 0")
        var digests: [String] = []
        for _ in 0..<runCount {
            let result = coordinatorFactory().runTurn(request)
            let digest = BASEBrainTurnResultReplayDigest.from(
                result: result,
                producedAt: fixedProducedAt,
                canonicalize: canonicalize)
            digests.append(digest.digestString)
        }
        return Self.verdict(from: digests)
    }

    // MARK: - (B) Codable round-trip

    /// encode (`.sortedKeys`) → decode → re-encode; `true` ⇔ the two encodings are byte-identical.
    /// Proves the full result's `Codable` conformance is a stable fixed-point (no field drops a
    /// value, changes precision, or re-orders on a round-trip).
    public static func codableRoundTripIsByteStable(
        _ result: BASEBrainTurnResult
    ) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let first = try? encoder.encode(result),
              let decoded = try? JSONDecoder().decode(
                BASEBrainTurnResult.self, from: first),
              let second = try? encoder.encode(decoded)
        else { return false }
        return first == second
    }

    // MARK: - (C) V1-vs-runWithPlan parity

    /// Run `coordinator.runTurn` (V1) and `engine.runWithPlan` (the native stage executors) on the
    /// SAME request and compare FULL-result canonical digests. Byte-equal by construction today
    /// (runWithPlan returns the same `coordinator.runTurn` value); this is the tripwire guarding
    /// that invariant — and the evidence gate for Step 3b.
    public static func v1VsRunWithPlanParityVerdict(
        coordinatorFactory: @escaping CoordinatorFactory,
        request: BASEBrainTurnRequest,
        plan: BASTurnRuntimeStagePlan = BASTurnRuntimeStagePlan.canonical(),
        canonicalize: Bool = true
    ) async -> ReplayVerdict {
        // V1: direct coordinator.runTurn.
        let v1Result = coordinatorFactory().runTurn(request)
        let v1Digest = BASEBrainTurnResultReplayDigest.from(
            result: v1Result,
            producedAt: fixedProducedAt,
            canonicalize: canonicalize)
        // runWithPlan: engine over a FRESH coordinator, `eventLog` nil so no extra envelope
        // emission occurs (and even if it did, it would not touch the returned result).
        let engine = BASTurnRuntimeEngine(coordinator: coordinatorFactory())
        let planResult = await engine.runWithPlan(request, plan: plan)
        let planDigest = BASEBrainTurnResultReplayDigest.from(
            result: planResult,
            producedAt: fixedProducedAt,
            canonicalize: canonicalize)
        return Self.verdict(from: [v1Digest.digestString, planDigest.digestString])
    }

    // MARK: - helpers

    private static func verdict(from digests: [String]) -> ReplayVerdict {
        let first = digests.first ?? ""
        var distinct = Set<String>()
        var divergingIndex: Int?
        for (index, digest) in digests.enumerated() {
            distinct.insert(digest)
            if digest != first && divergingIndex == nil {
                divergingIndex = index
            }
        }
        return ReplayVerdict(
            runCount: digests.count,
            distinctDigestCount: distinct.count,
            firstDigest: first,
            divergingRunIndex: divergingIndex)
    }
}
