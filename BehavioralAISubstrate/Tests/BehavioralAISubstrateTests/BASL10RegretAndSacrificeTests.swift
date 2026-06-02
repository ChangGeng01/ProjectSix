// ch1049 / v1.0 L10 — proofs for BASRegretProfile (悔意剖面) + BASSacrificeMap (牺牲地图).

import XCTest
import Foundation
@testable import BASOrchestration

final class BASL10RegretAndSacrificeTests: XCTestCase {

    // RegretEntry clamps inputs to [0,1] and weight = likelihood × severity.
    func testRegretEntryClampAndWeight() {
        let e = BASRegretEntry(dimension: "d", likelihood: 1.4, severity: -0.2, reversible: true)
        XCTAssertEqual(e.likelihood, 1.0)
        XCTAssertEqual(e.severity, 0.0)
        let w = BASRegretEntry(dimension: "d", likelihood: 0.5, severity: 0.4, reversible: false)
        XCTAssertEqual(w.weight, 0.2, accuracy: 1e-9)
    }

    // RegretProfile aggregates: totalWeight, peak, irreversible-regret flag, empty.
    func testRegretProfileAggregates() {
        let p = BASRegretProfile(choiceRef: "c1", entries: [
            BASRegretEntry(dimension: "reversible_minor", likelihood: 0.2, severity: 0.2, reversible: true),   // 0.04
            BASRegretEntry(dimension: "irreversible_big", likelihood: 0.8, severity: 0.9, reversible: false),  // 0.72
        ])
        XCTAssertEqual(p.totalWeight, 0.76, accuracy: 1e-9)
        XCTAssertEqual(p.peak?.dimension, "irreversible_big")
        XCTAssertTrue(p.hasIrreversibleRegret)

        let safe = BASRegretProfile(choiceRef: "c2", entries: [
            BASRegretEntry(dimension: "x", likelihood: 0.9, severity: 0.9, reversible: true)
        ])
        XCTAssertFalse(safe.hasIrreversibleRegret, "reversible regret is not an irreversible caution")

        let none = BASRegretProfile.empty(choiceRef: "c3")
        XCTAssertEqual(none.totalWeight, 0)
        XCTAssertNil(none.peak)
        XCTAssertFalse(none.hasIrreversibleRegret)
    }

    // SacrificeEntry clamps magnitude.
    func testSacrificeEntryClamp() {
        XCTAssertEqual(BASSacrificeEntry(stakeholder: "s", what: "w", magnitude: 2, reversible: true).magnitude, 1.0)
        XCTAssertEqual(BASSacrificeEntry(stakeholder: "s", what: "w", magnitude: -1, reversible: true).magnitude, 0.0)
    }

    // SacrificeMap: stakeholders (sorted, unique), per-stakeholder query, total, irreversible flag.
    func testSacrificeMapAggregates() {
        let m = BASSacrificeMap(choiceRef: "c1", entries: [
            BASSacrificeEntry(stakeholder: "user", what: "time", magnitude: 0.3, reversible: true),
            BASSacrificeEntry(stakeholder: "host", what: "compute", magnitude: 0.5, reversible: false),
            BASSacrificeEntry(stakeholder: "user", what: "privacy", magnitude: 0.2, reversible: true),
        ])
        XCTAssertEqual(m.stakeholders, ["host", "user"])
        XCTAssertEqual(m.entries(forStakeholder: "user").count, 2)
        XCTAssertEqual(m.totalMagnitude, 1.0, accuracy: 1e-9)
        XCTAssertTrue(m.hasIrreversibleSacrifice)
    }

    // fromFlat losslessly bridges the legacy [String] field into structured entries.
    func testSacrificeMapFromFlat() {
        let m = BASSacrificeMap.fromFlat(["gave up A", "gave up B"], choiceRef: "c9")
        XCTAssertEqual(m.entries.count, 2)
        XCTAssertEqual(m.entries.map { $0.what }, ["gave up A", "gave up B"])
        XCTAssertTrue(m.entries.allSatisfy { $0.stakeholder == "unspecified" && $0.magnitude == 0 && $0.reversible })
        XCTAssertFalse(m.hasIrreversibleSacrifice)
    }
}
