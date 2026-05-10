// MARK: - BASStressSweepCanonical60Driver
// chapter 四百三十四 / M1112 — Wave 5 evidence collection
//
// Canonical 60-fixture driver that anchors the V1↔V2
// byte-equality evidence path。 Builds a typed
// `BASTurnRuntimeStressFixtureSet` covering the
// 60-element Cartesian product of the M1071 typed
// dimensions (risk × permitMode × quarantines ×
// anchorTone × neuralCoreWired × evolutionFeedback)
// AND ships a default stub runner so the harness
// pipeline can be exercised end-to-end immediately。
//
// ## Why this exists (system entropy framing)
//
// `BASStressSweepHarness` (M1074) ships the dual-mode
// comparison contract but takes a caller-provided
// `FixtureRunner` closure。 No production driver exists —
// the harness can't be exercised end-to-end without
// each caller building their own fixture set + runner。
// That blocks Wave 6 (V2 default mode flip) since
// flip requires byte-equality evidence that the
// harness can't produce in isolation。
//
// `BASStressSweepCanonical60Driver` ships:
//   1. The canonical 60-fixture set (typed Cartesian
//      product of 6 dimensions:
//        risk ∈ {low, mid, high}             (3)
//        permitMode ∈ {answer, delay}         (2)
//        quarantines ∈ {true, false}          (2)
//        anchorTone ∈ {true, false}           (2)
//        neuralCoreWired ∈ {true, false}      (2)
//        evolutionFeedbackPresent ∈ {ø}        (1)
//      = 3 × 2 × 2 × 2 × 2 × 1 = 48 actually,
//      but we 60-pad with permitMode×evolutionFB
//      to reach the canonical 60 target — see
//      `canonicalKeyExpansion()` for the typed
//      generator that lands at exactly 60 keys per
//      M1071 plan)
//   2. A reference stub runner that returns identical
//      V1+V2 summaries for every key — proves the
//      harness pipeline reports `passing: 60/60`
//      when V1↔V2 are byte-identical
//   3. A divergence-injection runner that mutates V2
//      summaries deterministically — proves the
//      harness reports `failing` correctly
//
// ## What this DOES NOT ship (deferred)
//
// The REAL V1+V2 coordinator-driven runner that:
//   - Constructs a `BASEBrainRuntimeCoordinator` with
//     the 10-service stub harness
//   - Runs each fixture's request through V1's `runTurn`
//     to produce the V1 summary
//   - Runs the same request through V2's `runWithPlan`
//     to produce the V2 summary
//   - Returns the (V1, V2) pair to the harness
//
// Building that real-coordinator runner requires the
// same ~30 service stubs that BASEBrainSchemaCoreTests
// inlines per-test。 Deferred to a follow-up chapter
// where the host-side stub fixtures are formalized
// (see `plannedFutureCuts` in chapter 434 doctrine)。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     fixture set + stub runner)
//   - chapter 二百一一 — single source-of-truth (one
//     canonical60 set + one default driver — future
//     real-coordinator runners replace the stub at
//     the same surface)
//   - chapter 三百九二 — replay-determinism (Cartesian
//     product is deterministic;sortedKeys JSON
//     digests on summaries are byte-stable)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (driver is observation only)
//   - 红线 7 — hint-only (sweep evidence is
//     observation,not commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore
import BASOrchestration

/// Canonical 60-fixture driver。 Pure-function builder
/// + reference stub runners for the V1↔V2 byte-equality
/// evidence path。
public enum BASStressSweepCanonical60Driver {

    /// Pinned canonical60 fixture-set name。
    public static let canonicalSetName: String =
        "canonical-60"

    /// Pinned canonical60 set version (chapter 八十七
    /// raw value stability)。
    public static let canonicalSetVersion: String =
        "1.0.0"

    // MARK: - Canonical60 fixture set

    /// Build the canonical 60-fixture set。 Deterministic
    /// — same input produces same set (no randomness)。
    public static func canonicalFixtureSet()
        -> BASTurnRuntimeStressFixtureSet
    {
        return BASTurnRuntimeStressFixtureSet(
            name: canonicalSetName,
            setVersion: canonicalSetVersion,
            keys: canonicalKeyExpansion())
    }

    /// Generate the 60 typed fixture keys via Cartesian
    /// product of the M1071 dimensions。 Order is
    /// stable for replay-determinism (chapter 三百九二)。
    ///
    /// Dimension cardinalities (yields exactly 60 keys):
    ///   Base set (neuralCoreWired = true):
    ///     risk:               3 (low / medium / high)
    ///     permitMode:         2 (answer / delay)
    ///     quarantines:        2 (false / true)
    ///     anchorTone:         2 (false / true)
    ///     evolutionFeedback:  2 (false / true)
    ///     → 3 × 2 × 2 × 2 × 2 = 48 keys
    ///
    ///   Boundary set (neuralCoreWired = false):
    ///     risk:               3 (low / medium / high)
    ///     permitMode:         2 (answer / delay)
    ///     anchorTone:         2 (false / true)
    ///     quarantines:        pinned false
    ///     evolutionFeedback:  pinned false
    ///     → 3 × 2 × 2 = 12 keys
    ///
    /// Total: 48 + 12 = 60 ✓
    ///
    /// `.extreme` risk reserved for separate
    /// boundary-stress sweeps (not canonical60)。
    public static func canonicalKeyExpansion()
        -> [BASTurnRuntimeStressFixtureKey]
    {
        var keys: [BASTurnRuntimeStressFixtureKey] = []
        // Use low/medium/high (3 of the 4 cases —
        // .extreme is reserved for boundary stress
        // sweeps not in the canonical60 set)
        let risks: [BASTurnRuntimeStressRiskBucket] = [
            .low, .medium, .high]
        let permits: [BASActionPermitMode] = [
            .answer, .delay]
        let quars: [Bool] = [false, true]
        let anchors: [Bool] = [false, true]
        let evolutions: [Bool] = [false, true]

        // Base: 3 × 2 × 2 × 2 × 2 = 48 keys with
        // neuralCoreWired = true
        for risk in risks {
            for permit in permits {
                for q in quars {
                    for a in anchors {
                        for e in evolutions {
                            keys.append(
                                BASTurnRuntimeStressFixtureKey(
                                    risk: risk,
                                    permitMode: permit,
                                    quarantines: q,
                                    anchorTone: a,
                                    neuralCoreWired: true,
                                    evolutionFeedbackPresent: e))
                        }
                    }
                }
            }
        }
        // Boundary: 12 keys with neuralCoreWired = false
        // (covers the no-neural-core path) — only
        // exercise the 12-key cross of risks × permits ×
        // anchors with q=false, e=false to stay tight。
        for risk in risks {
            for permit in permits {
                for a in anchors {
                    keys.append(
                        BASTurnRuntimeStressFixtureKey(
                            risk: risk,
                            permitMode: permit,
                            quarantines: false,
                            anchorTone: a,
                            neuralCoreWired: false,
                            evolutionFeedbackPresent: false))
                }
            }
        }
        // Total: 48 + 12 = 60 ✓
        return keys
    }

    // MARK: - Reference stub runners

    /// Stub runner that returns IDENTICAL V1 + V2
    /// summaries for every fixture。 Useful for
    /// proving the harness pipeline reports a clean
    /// `passing: 60/60` verdict when nothing diverges。
    public static func identityStubRunner()
        -> BASStressSweepHarness.FixtureRunner
    {
        return { key in
            let identical =
                BASRuntimeAuditEmissionSummary(
                    traceID: "canonical60-" + key.label,
                    verdictLevelRaw: "stub",
                    permitModeRaw: key.permitMode.rawValue,
                    ticketCount: 0,
                    auditID: "stub-" + key.label,
                    runMode: "v1ByteEqual",
                    stageCount: 18,
                    stagePlanStepCount: 16,
                    stagePlanIsCanonical: true)
            return (
                v1Summary: identical,
                v2Summary: identical)
        }
    }

    /// Stub runner that returns SLIGHTLY DIVERGENT
    /// V1+V2 summaries — useful for proving the
    /// harness reports `failing` verdicts correctly。
    /// Divergence is deterministic (always V2's
    /// `permitEscalationFiredStageCount` is +1 over V1)。
    public static func deterministicDivergenceStubRunner()
        -> BASStressSweepHarness.FixtureRunner
    {
        return { key in
            let baseTrace =
                "canonical60-" + key.label
            let v1 = BASRuntimeAuditEmissionSummary(
                traceID: baseTrace,
                verdictLevelRaw: "stub",
                permitModeRaw: key.permitMode.rawValue,
                ticketCount: 0,
                auditID: "stub-v1-" + key.label,
                runMode: "v1ByteEqual",
                permitEscalationFiredStageCount: 0,
                stageCount: 18,
                stagePlanStepCount: 16,
                stagePlanIsCanonical: true)
            let v2 = BASRuntimeAuditEmissionSummary(
                traceID: baseTrace,
                verdictLevelRaw: "stub",
                permitModeRaw: key.permitMode.rawValue,
                ticketCount: 0,
                auditID: "stub-v2-" + key.label,
                runMode: "nativeV2",
                permitEscalationFiredStageCount: 1,  // +1 vs V1
                stageCount: 18,
                stagePlanStepCount: 16,
                stagePlanIsCanonical: true)
            return (v1Summary: v1, v2Summary: v2)
        }
    }

    // MARK: - End-to-end driver entry

    /// Runs the full canonical60 sweep with the
    /// identity stub runner and returns the typed
    /// report。 Default convenience for callers that
    /// want to exercise the harness pipeline end-to-end
    /// with byte-identical V1/V2 inputs。
    public static func runIdentitySweep() async
        -> BASStressSweepReport
    {
        let harness = BASStressSweepHarness()
        return await harness.run(
            fixtureSet: canonicalFixtureSet(),
            runner: identityStubRunner())
    }

    /// Runs the canonical60 sweep with the deterministic-
    /// divergence stub runner — useful for proving the
    /// harness fails closed when V1↔V2 diverge。
    public static func runDivergenceSweep() async
        -> BASStressSweepReport
    {
        let harness = BASStressSweepHarness()
        return await harness.run(
            fixtureSet: canonicalFixtureSet(),
            runner: deterministicDivergenceStubRunner())
    }
}
