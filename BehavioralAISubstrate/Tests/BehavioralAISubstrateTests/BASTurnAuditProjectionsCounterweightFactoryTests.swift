// MARK: - BASTurnAuditProjectionsCounterweightFactoryTests
// chapter 五百十 / M1417 — counterweight factory tests

import XCTest
@testable import BASHostKit
@testable import BASOrchestration

final class BASTurnAuditProjectionsCounterweightFactoryTests:
    XCTestCase
{

    // MARK: - 1) Compute produces typed counterweight

    func testComputeProducesTypedCounterweight() {
        let cw = BASTurnAuditProjectionsCounterweightFactory
            .compute(
                sessionID: "S",
                dignityBias: 0.5,
                agencyFloor: 0.6,
                antiFatalism: 0.7,
                antiPaternalism: 0.8)
        XCTAssertEqual(cw.counterweightID,
                       "cosmic-cold-S")
        XCTAssertEqual(cw.dignityBias, 0.5)
        XCTAssertEqual(cw.agencyFloor, 0.6)
        XCTAssertEqual(cw.antiFatalism, 0.7)
        XCTAssertEqual(cw.antiPaternalism, 0.8)
    }

    // MARK: - 2) Clamping preserved (delegates to
    //             BASCosmicColdCounterweight init)

    func testValuesAboveOneClampToOne() {
        let cw = BASTurnAuditProjectionsCounterweightFactory
            .compute(
                sessionID: "S",
                dignityBias: 1.5,
                agencyFloor: 2.0,
                antiFatalism: 1.1,
                antiPaternalism: 99.0)
        XCTAssertEqual(cw.dignityBias, 1.0)
        XCTAssertEqual(cw.agencyFloor, 1.0)
        XCTAssertEqual(cw.antiFatalism, 1.0)
        XCTAssertEqual(cw.antiPaternalism, 1.0)
    }

    func testValuesBelowZeroClampToZero() {
        let cw = BASTurnAuditProjectionsCounterweightFactory
            .compute(
                sessionID: "S",
                dignityBias: -0.5,
                agencyFloor: -1.0,
                antiFatalism: -100.0,
                antiPaternalism: -0.1)
        XCTAssertEqual(cw.dignityBias, 0.0)
        XCTAssertEqual(cw.agencyFloor, 0.0)
        XCTAssertEqual(cw.antiFatalism, 0.0)
        XCTAssertEqual(cw.antiPaternalism, 0.0)
    }

    // MARK: - 3) counterweightID embeds session

    func testCounterweightIDEmbedsSession() {
        let cw = BASTurnAuditProjectionsCounterweightFactory
            .compute(
                sessionID: "test-session-xyz",
                dignityBias: 0,
                agencyFloor: 0,
                antiFatalism: 0,
                antiPaternalism: 0)
        XCTAssertEqual(cw.counterweightID,
                       "cosmic-cold-test-session-xyz")
    }

    // MARK: - 4) Determinism

    func testFactoryIsDeterministic() {
        let r1 = BASTurnAuditProjectionsCounterweightFactory
            .compute(
                sessionID: "S",
                dignityBias: 0.5,
                agencyFloor: 0.6,
                antiFatalism: 0.7,
                antiPaternalism: 0.8)
        let r2 = BASTurnAuditProjectionsCounterweightFactory
            .compute(
                sessionID: "S",
                dignityBias: 0.5,
                agencyFloor: 0.6,
                antiFatalism: 0.7,
                antiPaternalism: 0.8)
        XCTAssertEqual(r1, r2)
    }

    // MARK: - 5) Schema version pinned

    func testSchemaVersionPinnedToCurrent() {
        let cw = BASTurnAuditProjectionsCounterweightFactory
            .compute(
                sessionID: "S",
                dignityBias: 0,
                agencyFloor: 0,
                antiFatalism: 0,
                antiPaternalism: 0)
        XCTAssertEqual(cw.schemaVersion,
            BASCosmicColdCounterweight
                .currentSchemaVersion)
    }
}
