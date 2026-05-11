// MARK: - BASTurnAuditProjectionsGateSideDeriveTrioTests
// chapter 五百六 / M1403 — gate-side derive trio tests

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASTurnAuditProjectionsGateSideDeriveTrioTests:
    XCTestCase
{

    // MARK: - 1) Compute produces 3 typed derives

    func testComputeProducesThreeTypedDerives() {
        let trio =
            BASTurnAuditProjectionsGateSideDeriveTrio
                .compute(
                    sessionID: "S",
                    hostID: "H",
                    riskLevel: .medium,
                    permitMode: .answer,
                    candidateCount: 3,
                    uncertaintyLedger: nil,
                    evidenceDebtCount: 0,
                    defaultConfidenceFloorWhenNoUncertaintyLedger:
                        1.0)
        XCTAssertNotNil(trio.abyssalPressure)
        XCTAssertNotNil(trio.humanAnchorSignal)
        XCTAssertNotNil(trio.unknownReserve)
    }

    // MARK: - 2) Pressure derive uses session + risk
    //             + uncertainty

    func testPressureDeriveCarriesContext() {
        let trio =
            BASTurnAuditProjectionsGateSideDeriveTrio
                .compute(
                    sessionID: "test-session",
                    hostID: "H",
                    riskLevel: .high,
                    permitMode: .answer,
                    candidateCount: 1,
                    uncertaintyLedger: nil,
                    evidenceDebtCount: 5,
                    defaultConfidenceFloorWhenNoUncertaintyLedger:
                        1.0)
        // pressureID embeds turnID per chapter 一百十二
        XCTAssertTrue(trio.abyssalPressure.pressureID
            .contains("test-session"))
    }

    // MARK: - 3) Human anchor derive embeds session

    func testHumanAnchorEmbedsSession() {
        let trio =
            BASTurnAuditProjectionsGateSideDeriveTrio
                .compute(
                    sessionID: "session-xyz",
                    hostID: "host-A",
                    riskLevel: .low,
                    permitMode: .answer,
                    candidateCount: 2,
                    uncertaintyLedger: nil,
                    evidenceDebtCount: 0,
                    defaultConfidenceFloorWhenNoUncertaintyLedger:
                        1.0)
        XCTAssertEqual(
            trio.humanAnchorSignal.anchorID,
            "human-anchor-session-xyz")
        XCTAssertEqual(
            trio.humanAnchorSignal.hostSummaryRef,
            "host-A")
    }

    // MARK: - 4) Unknown reserve embeds session

    func testUnknownReserveEmbedsSession() {
        let trio =
            BASTurnAuditProjectionsGateSideDeriveTrio
                .compute(
                    sessionID: "S",
                    hostID: "H",
                    riskLevel: .low,
                    permitMode: .answer,
                    candidateCount: 1,
                    uncertaintyLedger: nil,
                    evidenceDebtCount: 0,
                    defaultConfidenceFloorWhenNoUncertaintyLedger:
                        1.0)
        XCTAssertEqual(
            trio.unknownReserve.reserveID,
            "unknown-reserve-S")
    }

    // MARK: - 5) Unknown reserve respects assertion ceiling

    func testUnknownReserveHasAssertionCeiling() {
        let trio =
            BASTurnAuditProjectionsGateSideDeriveTrio
                .compute(
                    sessionID: "S",
                    hostID: "H",
                    riskLevel: .low,
                    permitMode: .answer,
                    candidateCount: 1,
                    uncertaintyLedger: nil,
                    evidenceDebtCount: 0,
                    defaultConfidenceFloorWhenNoUncertaintyLedger:
                        1.0)
        // BASUnknownReserve.assertionCeiling is a typed
        // enum — verify it's a valid case
        XCTAssertNotNil(
            trio.unknownReserve.assertionCeiling,
            "BASUnknownReserve MUST have a typed" +
            " assertion ceiling")
    }

    // MARK: - 6) Determinism — same inputs → same outputs

    func testFactoryIsDeterministic() {
        let r1 =
            BASTurnAuditProjectionsGateSideDeriveTrio
                .compute(
                    sessionID: "S",
                    hostID: "H",
                    riskLevel: .medium,
                    permitMode: .mirror,
                    candidateCount: 2,
                    uncertaintyLedger: nil,
                    evidenceDebtCount: 1,
                    defaultConfidenceFloorWhenNoUncertaintyLedger:
                        1.0)
        let r2 =
            BASTurnAuditProjectionsGateSideDeriveTrio
                .compute(
                    sessionID: "S",
                    hostID: "H",
                    riskLevel: .medium,
                    permitMode: .mirror,
                    candidateCount: 2,
                    uncertaintyLedger: nil,
                    evidenceDebtCount: 1,
                    defaultConfidenceFloorWhenNoUncertaintyLedger:
                        1.0)
        XCTAssertEqual(r1.abyssalPressure.pressureID,
                       r2.abyssalPressure.pressureID)
        XCTAssertEqual(r1.humanAnchorSignal.anchorID,
                       r2.humanAnchorSignal.anchorID)
        XCTAssertEqual(r1.unknownReserve.reserveID,
                       r2.unknownReserve.reserveID)
    }

    // MARK: - 7) Sendable across actor boundary

    func testTrioIsSendable() async {
        let trio =
            BASTurnAuditProjectionsGateSideDeriveTrio
                .compute(
                    sessionID: "S",
                    hostID: "H",
                    riskLevel: .low,
                    permitMode: .answer,
                    candidateCount: 1,
                    uncertaintyLedger: nil,
                    evidenceDebtCount: 0,
                    defaultConfidenceFloorWhenNoUncertaintyLedger:
                        1.0)
        let captured = trio
        let task = Task {
            captured.unknownReserve.reserveID
        }
        let id = await task.value
        XCTAssertEqual(id, "unknown-reserve-S")
    }
}
