// MARK: - BASChapter787TIEReMeasureAtScaleTests
// chapter 七百八十七 / M2586-M2590
//
// Re-measure the 3 TIE crates from chapter 七百七十九 at LARGER
// batch sizes to check whether FFI overhead amortizes when each
// call is part of a tight loop (vs single-shot per-batch)。
//
// Hypothesis:at N=10000 the per-call FFI overhead (~80 ns) is
// the same as at N=10,but the Swift baseline's array/string
// allocation cost may scale superlinearly。 If so,Rust opens
// up vs Swift at scale。
//
// Honest negative result if no crossing。

import XCTest
@testable import BASRuntimeCore
@testable import BASOrchestration
@testable import BASMemory  // for shadow-trial Phase 1 Core

#if os(iOS) || os(macOS)

final class BASChapter787TIEReMeasureAtScaleTests: XCTestCase {

    // MARK: - bas-lease-life at 3 scale points

    func testLeaseLifeReMeasureAtScale() {
        for iterations in [100, 1000, 10_000] {
            let report = BASCrossLanguagePerfHarness.compare(
                crateName: "bas-lease-life",
                workload: "decay+record_turn @ N=\(iterations)",
                iterations: iterations,
                v1Swift: {
                    let prev = 0.5
                    let idle = 30.0
                    let tau = 180.0
                    let factor = exp(-idle / tau)
                    let decayed = max(0, min(1, prev * factor))
                    let _ = max(0, min(1, decayed + 0.05))
                },
                v2Rust: {
                    _ = BASLeaseLifeBridge.lungStateDecay(
                        prevPressure: 0.5, idleSeconds: 30,
                        timeConstantSeconds: 180)
                    _ = BASLeaseLifeBridge.lungStateRecordTurn(
                        prevPressure: 0.5, idleSeconds: 30,
                        timeConstantSeconds: 180,
                        runMode: 3, durationSeconds: 1.0)
                })
            BASCrossLanguagePerfHarness.printReport(report)
            XCTAssertGreaterThan(report.v1SwiftNs, 0)
            XCTAssertGreaterThan(report.v2RustNs, 0)
        }
    }

    // MARK: - bas-host-constitution at 3 scale points

    func testHostConstitutionReMeasureAtScale() {
        for iterations in [100, 1000, 10_000] {
            let report = BASCrossLanguagePerfHarness.compare(
                crateName: "bas-host-constitution",
                workload: "resolve_field @ N=\(iterations)",
                iterations: iterations,
                v1Swift: {
                    let fieldKind: UInt8 = 5
                    let valuesEqual = false
                    let leftRolled = false
                    let rightRolled = false
                    if leftRolled || rightRolled {
                        let _ = 2
                    } else if valuesEqual {
                        let _ = 0
                    } else {
                        switch fieldKind {
                        case 5, 9: let _ = 1
                        default: let _ = 0
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
    }

    // MARK: - bas-mirror-blade at 3 scale points

    func testMirrorBladeReMeasureAtScale() {
        for iterations in [100, 1000, 10_000] {
            let report = BASCrossLanguagePerfHarness.compare(
                crateName: "bas-mirror-blade",
                workload: "classify @ N=\(iterations)",
                iterations: iterations,
                v1Swift: {
                    let emotional = 0.6
                    let timePressure = 0.3
                    let consequence = 0.7
                    let ambiguity = 0.5
                    let manipulation = 0.2
                    let elevated = 0.5
                    var bits: UInt8 = 0
                    if ambiguity >= 0.6 { bits |= 1 << 1 }
                    if emotional >= elevated { /* arousal */ }
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
    }

    // MARK: - new bas-atom-lifecycle perf measurement

    func testAtomLifecyclePerfAtScale() {
        // First-time perf measurement for the L8 atom-lifecycle
        // bridge (chapter 七百八十三)。 Expected:TIE-or-modest
        // since the transition is a 20-cell match cascade,
        // similar shape to host-constitution。
        for iterations in [100, 1000, 10_000] {
            let report = BASCrossLanguagePerfHarness.compare(
                crateName: "bas-atom-lifecycle",
                workload: "transition @ N=\(iterations)",
                iterations: iterations,
                v1Swift: {
                    // Inline equivalent:Created+Admit→Admitted
                    let phase: UInt8 = 0
                    let action: UInt8 = 0
                    if phase == 4 { let _ = 2 }  // terminal
                    else {
                        switch (phase, action) {
                        case (0, 0): let _ = 1  // Created+Admit→Admitted
                        default: let _ = 1
                        }
                    }
                },
                v2Rust: {
                    _ = BASAtomLifecycleBridge.transition(
                        currentPhaseByte: 0, actionByte: 0)
                })
            BASCrossLanguagePerfHarness.printReport(report)
            XCTAssertGreaterThan(report.v1SwiftNs, 0)
            XCTAssertGreaterThan(report.v2RustNs, 0)
        }
    }
}

#endif  // os(iOS) || os(macOS)
