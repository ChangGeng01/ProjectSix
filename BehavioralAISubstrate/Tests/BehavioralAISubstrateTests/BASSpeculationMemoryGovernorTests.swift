// MARK: - BASSpeculationMemoryGovernorTests — U1 gate
//
// Deterministic unit gate for the between-turns speculation memory
// governor (pure state machine — no probes, no device)。 Load-bearing
// claims: strike accumulation, hysteresis on both sides, dead-probe
// honesty, watermark validation clamps。

import XCTest
@testable import BASMLXAdapter

final class BASSpeculationMemoryGovernorTests: XCTestCase {

    private typealias Gov = BASSpeculationMemoryGovernor
    private let MB: UInt64 = 1024 * 1024

    private func makeGovernor(
        highMB: UInt64 = 2700, lowMB: UInt64? = nil,
        strikes: Int = 2, clean: Int = 3
    ) -> Gov {
        Gov(configuration: Gov.Configuration(
            highWaterBytes: highMB * MB,
            lowWaterBytes: lowMB.map { $0 * MB },
            strikesToDrop: strikes,
            cleanSamplesToRestore: clean))
    }

    private func sample(
        footprintMB: UInt64?, pressure: Bool = false
    ) -> Gov.Sample {
        Gov.Sample(
            footprintBytes: footprintMB.map { $0 * MB },
            underPressure: pressure)
    }

    // MARK: - Drop side

    func testSingleBadSampleHoldsBelowStrikeThreshold() {
        let g = makeGovernor()
        let (next, advice) = g.evaluating(sample(footprintMB: 2800))
        XCTAssertEqual(advice, .hold,
            "one bad sample < strikesToDrop=2 must hold")
        XCTAssertEqual(next.strikes, 1)
        XCTAssertEqual(next.residency, .draftResident)
    }

    func testConsecutiveBadSamplesAdviseDrop() {
        let g = makeGovernor()
        let (g1, a1) = g.evaluating(sample(footprintMB: 2800))
        XCTAssertEqual(a1, .hold)
        let (g2, a2) = g1.evaluating(sample(footprintMB: 2900))
        guard case .dropDraft = a2 else {
            return XCTFail("2nd consecutive bad sample must advise drop, got \(a2)")
        }
        XCTAssertEqual(g2.residency, .draftDropped)
        XCTAssertEqual(g2.strikes, 0, "counters reset after transition")
    }

    func testCleanSampleResetsStrikes() {
        let g = makeGovernor()
        let (g1, _) = g.evaluating(sample(footprintMB: 2800))
        XCTAssertEqual(g1.strikes, 1)
        let (g2, a2) = g1.evaluating(sample(footprintMB: 1000))
        XCTAssertEqual(a2, .hold)
        XCTAssertEqual(g2.strikes, 0,
            "a clean sample must reset the strike counter (no flapping " +
            "on intermittent spikes)")
    }

    func testPressureAloneCountsAsBad() {
        let g = makeGovernor()
        let (g1, _) = g.evaluating(
            sample(footprintMB: 1000, pressure: true))
        XCTAssertEqual(g1.strikes, 1,
            "system pressure must count as a bad sample even with a " +
            "low footprint (thermal >= serious is a real constraint)")
        let (_, a2) = g1.evaluating(
            sample(footprintMB: 1000, pressure: true))
        guard case .dropDraft = a2 else {
            return XCTFail("consecutive pressure must advise drop")
        }
    }

    // MARK: - Restore side (hysteresis)

    private func droppedGovernor() -> Gov {
        let g = makeGovernor()
        let (g1, _) = g.evaluating(sample(footprintMB: 2800))
        let (g2, _) = g1.evaluating(sample(footprintMB: 2800))
        XCTAssertEqual(g2.residency, .draftDropped)
        return g2
    }

    func testRestoreNeedsConsecutiveCleanBelowLowWater() {
        var g = droppedGovernor()
        // low water default = 2700*0.8 = 2160 MB。 Two clean samples
        // below it: hold, hold;third: restore。
        for i in 1...2 {
            let (next, advice) = g.evaluating(sample(footprintMB: 2000))
            XCTAssertEqual(advice, .hold, "clean sample \(i)/3 must hold")
            g = next
        }
        let (g3, a3) = g.evaluating(sample(footprintMB: 2000))
        guard case .restoreDraft = a3 else {
            return XCTFail("3rd consecutive clean below low water must restore, got \(a3)")
        }
        XCTAssertEqual(g3.residency, .draftResident)
    }

    func testBetweenWatersDoesNotCountTowardRestore() {
        let g = droppedGovernor()
        // 2400 MB is below HIGH (2700) — not bad — but above LOW
        // (2160):must NOT accumulate restore credit (hysteresis)。
        let (g1, a1) = g.evaluating(sample(footprintMB: 2400))
        XCTAssertEqual(a1, .hold)
        XCTAssertEqual(g1.cleanSamples, 0,
            "between low and high water the governor must neither " +
            "drop nor accumulate restore credit")
    }

    func testBadSampleWhileDroppedResetsCleanCount() {
        var g = droppedGovernor()
        (g, _) = g.evaluating(sample(footprintMB: 2000))
        (g, _) = g.evaluating(sample(footprintMB: 2000))
        XCTAssertEqual(g.cleanSamples, 2)
        let (g3, _) = g.evaluating(sample(footprintMB: 2800))
        XCTAssertEqual(g3.cleanSamples, 0,
            "a bad sample while dropped must reset restore credit")
        XCTAssertEqual(g3.residency, .draftDropped)
    }

    // MARK: - Dead probe honesty

    func testDeadProbeAloneIsCleanButPressureStillDrops() {
        let g = makeGovernor()
        // nil footprint, no pressure ⇒ clean (a dead probe must not
        // thrash the draft)。
        let (g1, a1) = g.evaluating(sample(footprintMB: nil))
        XCTAssertEqual(a1, .hold)
        XCTAssertEqual(g1.strikes, 0)
        // nil footprint + pressure ⇒ still counts bad。
        let (g2, _) = g1.evaluating(
            sample(footprintMB: nil, pressure: true))
        XCTAssertEqual(g2.strikes, 1,
            "pressure must drive strikes even when the probe is dead")
    }

    func testDeadProbeAllowsRestoreOnPressureClearAlone() {
        var g = droppedGovernor()
        for _ in 1...2 {
            (g, _) = g.evaluating(sample(footprintMB: nil))
        }
        let (g3, a3) = g.evaluating(sample(footprintMB: nil))
        guard case .restoreDraft = a3 else {
            return XCTFail("with a dead probe, pressure-clear alone must restore")
        }
        XCTAssertEqual(g3.residency, .draftResident)
    }

    // MARK: - Configuration validation (boundary clamps)

    func testConfigurationClampsInvertedWatermarksAndZeroThresholds() {
        let cfg = Gov.Configuration(
            highWaterBytes: 100 * MB,
            lowWaterBytes: 500 * MB,   // inverted — must clamp to high
            strikesToDrop: 0,          // must clamp to 1
            cleanSamplesToRestore: -3) // must clamp to 1
        XCTAssertLessThanOrEqual(cfg.lowWaterBytes, cfg.highWaterBytes,
            "an inverted low water must clamp to the high water")
        XCTAssertEqual(cfg.strikesToDrop, 1)
        XCTAssertEqual(cfg.cleanSamplesToRestore, 1)
    }

    func testFromFitBudgetDerivesNinetyPercentHighWater() {
        let cfg = Gov.Configuration.fromFitBudget(3_000 * 1024 * 1024)
        XCTAssertEqual(cfg.highWaterBytes, 2_700 * MB,
            "high water must be 90% of the fit budget")
        XCTAssertEqual(cfg.lowWaterBytes, 2_160 * MB,
            "low water must default to 80% of high water")
    }
}
