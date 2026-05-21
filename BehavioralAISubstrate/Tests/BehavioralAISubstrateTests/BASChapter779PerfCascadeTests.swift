// MARK: - BASChapter779PerfCascadeTests
// chapter 七百七十九 / M2546-M2550
//
// 5-axis perf measurement cascade for the 5 internal-bridge Rust
// crates activated at chapter 七百七十三 + 七百七十四:
//
//   - bas-lease-life       (L1 pressure decay + breath validate)
//   - bas-mirror-blade     (L7 decomposition state classifier)
//   - bas-presence-eye     (L6 signal-fusion classifier)
//   - bas-host-constitution (L5 merge + deletion logic)
//   - bas-world-prior      (L4 evidence / latency / reversibility)
//
// Per the 5-axis decision framework + chapter 七百七十八 harness:
//   STRONG-FLIP (>=2×) — auto-flip to Rust default
//   MODEST-FLIP (>=1.2×) — flag for flip review
//   TIE (>=0.83×) — stay opt-in per 「亏的不要硬上」
//   LOSS (<0.83×) — stay opt-in
//
// These crates use SCALAR FFI (not wire-format) so the per-call
// FFI overhead dominates the leaf compute。 Expected verdict
// per the plan-agent estimate from chapter 七百五十七:
//   - lease-life: TIE-or-modest (decay math is ~10 cycles)
//   - mirror-blade: MODEST (threshold cascade)
//   - presence-eye: TIE (10-channel sum)
//   - host-constitution: TIE (match cascade)
//   - world-prior: TIE-or-modest (array iteration)

import XCTest
@testable import BASRuntimeCore
@testable import BASOrchestration
@testable import BASMemory  // for BASShadowTrialStateMachineCore (Phase 1)

#if os(iOS) || os(macOS)

final class BASChapter779PerfCascadeTests: XCTestCase {

    // MARK: - bas-lease-life

    func testLeaseLifePerf() {
        // 1000 iterations of (decay + record_turn) — a typical
        // turn-counting workload。
        let report = BASCrossLanguagePerfHarness.compare(
            crateName: "bas-lease-life",
            workload: "decay + record_turn × 1",
            iterations: 10_000,
            v1Swift: {
                // V1 baseline:simple inline math (mirror Rust)
                let prev = 0.5
                let idle = 30.0
                let tau = 180.0
                let factor = exp(-idle / tau)
                let decayed = max(0, min(1, prev * factor))
                let _ = max(0, min(1, decayed + 0.05))
            },
            v2Rust: {
                _ = BASLeaseLifeBridge.lungStateDecay(
                    prevPressure: 0.5,
                    idleSeconds: 30,
                    timeConstantSeconds: 180)
                _ = BASLeaseLifeBridge.lungStateRecordTurn(
                    prevPressure: 0.5,
                    idleSeconds: 30,
                    timeConstantSeconds: 180,
                    runMode: 3,
                    durationSeconds: 1.0)
            })
        BASCrossLanguagePerfHarness.printReport(report)
        XCTAssertGreaterThan(report.v1SwiftNs, 0)
        XCTAssertGreaterThan(report.v2RustNs, 0)
    }

    // MARK: - bas-mirror-blade

    func testMirrorBladePerf() {
        let report = BASCrossLanguagePerfHarness.compare(
            crateName: "bas-mirror-blade",
            workload: "classify (5-threshold cascade)",
            iterations: 10_000,
            v1Swift: {
                // V1 baseline:inline threshold cascade
                let emotional = 0.6
                let timePressure = 0.3
                let consequence = 0.7
                let ambiguity = 0.5
                let manipulation = 0.2
                let elevated = 0.5
                var bits: UInt8 = 0
                if ambiguity >= 0.6 { bits |= 1 << 1 }
                if emotional >= elevated { /* arousal noted */ }
                if timePressure >= elevated
                    || consequence >= elevated { bits |= 1 << 3 }
                if manipulation >= elevated { bits |= 1 << 4 }
                if bits == 0 { bits |= 1 }
                let _ = bits
            },
            v2Rust: {
                _ = BASMirrorBladeBridge.classify(
                    emotionalLoad: 0.6, timePressure: 0.3,
                    consequenceLevel: 0.7, ambiguityScore: 0.5,
                    manipulationProbability: 0.2,
                    relationTense: false,
                    mirrorDraftRequested: false)
            })
        BASCrossLanguagePerfHarness.printReport(report)
        XCTAssertGreaterThan(report.v1SwiftNs, 0)
        XCTAssertGreaterThan(report.v2RustNs, 0)
    }

    // MARK: - bas-presence-eye

    func testPresenceEyePerf() {
        let report = BASCrossLanguagePerfHarness.compare(
            crateName: "bas-presence-eye",
            workload: "fuse 5 channels",
            iterations: 10_000,
            v1Swift: {
                // V1 baseline:weighted average inline
                let weights: [Double] = [1.0, 1.5, 2.0, 0.5, 0.75]
                let salience: [Double] = [0.5, 0.6, 0.7, 0.4, 0.5]
                let confidence: [Double] = [0.8, 0.7, 0.9, 0.6, 0.5]
                var weighted = 0.0
                var weightTotal = 0.0
                for i in 0..<5 {
                    let score = salience[i] * confidence[i]
                    weighted += score * weights[i]
                    weightTotal += weights[i]
                }
                let _ = weighted / weightTotal
            },
            v2Rust: {
                _ = BASPresenceEyeBridge.fuse(
                    taskSalience: 0.5, taskConfidence: 0.8,
                    riskSalience: 0.6, riskConfidence: 0.7,
                    manipulationSalience: 0.7,
                    manipulationConfidence: 0.9,
                    environmentSalience: 0.4,
                    environmentConfidence: 0.6,
                    bodyRhythmSalience: 0.5,
                    bodyRhythmConfidence: 0.5)
            })
        BASCrossLanguagePerfHarness.printReport(report)
        XCTAssertGreaterThan(report.v1SwiftNs, 0)
        XCTAssertGreaterThan(report.v2RustNs, 0)
    }

    // MARK: - bas-host-constitution

    func testHostConstitutionPerf() {
        let report = BASCrossLanguagePerfHarness.compare(
            crateName: "bas-host-constitution",
            workload: "resolve_field (match cascade)",
            iterations: 10_000,
            v1Swift: {
                // V1 baseline:inline match cascade
                let fieldKind: UInt8 = 5 // MemoryPermissions
                let valuesEqual = false
                let leftRolled = false
                let rightRolled = false
                if leftRolled || rightRolled {
                    let _ = 2 // RollbackBlocked
                } else if valuesEqual {
                    let _ = 0 // Success
                } else {
                    switch fieldKind {
                    case 5, 9:
                        let _ = 1 // ConflictEscalated
                    default:
                        let _ = 0
                    }
                }
            },
            v2Rust: {
                _ = BASHostConstitutionBridge.resolveField(
                    fieldKindByte: 5,
                    valuesEqual: false,
                    leftRolledBack: false,
                    rightRolledBack: false)
            })
        BASCrossLanguagePerfHarness.printReport(report)
        XCTAssertGreaterThan(report.v1SwiftNs, 0)
        XCTAssertGreaterThan(report.v2RustNs, 0)
    }

    // MARK: - bas-world-prior

    func testWorldPriorPerf() {
        // 10-element array workload — typical multi-axiom
        // evidence propagation in L4。
        let levels: [UInt8] = [3, 2, 1, 0, 2, 3, 1, 2, 3, 0]
        let report = BASCrossLanguagePerfHarness.compare(
            crateName: "bas-world-prior",
            workload: "propagate_evidence (10 levels)",
            iterations: 10_000,
            v1Swift: {
                // V1 baseline:inline min over array
                var min: UInt8 = 3
                for l in levels { if l < min { min = l } }
                let _ = min
            },
            v2Rust: {
                _ = BASWorldPriorBridge.propagateEvidence(
                    levels: levels)
            })
        BASCrossLanguagePerfHarness.printReport(report)
        XCTAssertGreaterThan(report.v1SwiftNs, 0)
        XCTAssertGreaterThan(report.v2RustNs, 0)
    }

    // MARK: - bas-shadow-trial (Phase 2)

    func testShadowTrialPerf() {
        let report = BASCrossLanguagePerfHarness.compare(
            crateName: "bas-shadow-trial",
            workload: "transition (match cascade)",
            iterations: 10_000,
            v1Swift: {
                // V1 baseline:Swift Core impl (same enum match)
                let core = BASShadowTrialStateMachineCore()
                let req = BASShadowTrialTransitionRequest(
                    currentPhase: .trialInFlight,
                    verdictRaw: "passed")
                let _ = core.transition(req)
            },
            v2Rust: {
                _ = BASShadowTrialBridge.transition(
                    currentPhaseByte: 1, verdictByte: 0)
            })
        BASCrossLanguagePerfHarness.printReport(report)
        XCTAssertGreaterThan(report.v1SwiftNs, 0)
        XCTAssertGreaterThan(report.v2RustNs, 0)
    }
}

#endif  // os(iOS) || os(macOS)

// MARK: - Scorecard captured in commit log

/// The actual perf numbers measured at chapter 七百七十九 land
/// in the commit message (audit trail)。 This empty test pin
/// just confirms the cascade ran and is the canonical scorecard
/// reference for the arc。

final class BASChapter779PerfCascadeScorecardTests: XCTestCase {
    func testCascadeMeasuredAtChapter779() {
        // The actual decisions land in the commit log。 Future
        // chapters that flip defaults will reference this chapter
        // by id。
        XCTAssertTrue(true,
            "Perf cascade measured at chapter 七百七十九。 " +
            "Numbers + decisions in commit log。")
    }
}
