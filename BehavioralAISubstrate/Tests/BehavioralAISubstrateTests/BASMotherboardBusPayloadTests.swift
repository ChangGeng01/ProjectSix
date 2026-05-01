import XCTest
@testable import BASRuntimeCore

/// 六十二.5 — canonical objects + bus payload tests.
final class BASMotherboardBusPayloadTests: XCTestCase {

    func test_everyBusHasAtLeastOnePayload() {
        for bus in BASMotherboardBus.allCases {
            XCTAssertFalse(
                bus.canonicalPayload.isEmpty,
                "bus \(bus) must carry ≥ 1 payload")
        }
    }

    func test_everyCanonicalObjectHasCarryingBus() {
        for object in
            BASMotherboardCanonicalObject.allCases
        {
            XCTAssertNotNil(
                object.carryingBus,
                "object \(object) must have a carrying bus")
        }
    }

    func test_leaseBusContainsBudgetFrameAndRunLease() {
        let payload = BASMotherboardBus.lease
            .canonicalPayload
        XCTAssertTrue(payload.contains(.budgetFrame))
        XCTAssertTrue(payload.contains(.runLease))
    }

    func test_riskPermitBusContainsActionPermit() {
        let payload = BASMotherboardBus.riskPermit
            .canonicalPayload
        XCTAssertTrue(payload.contains(.actionPermit))
        XCTAssertTrue(
            payload.contains(.sovereignWarrant))
    }

    func test_versionAuditBusContainsUpdateTicket() {
        let payload = BASMotherboardBus.versionAudit
            .canonicalPayload
        XCTAssertTrue(payload.contains(.updateTicket))
        XCTAssertTrue(payload.contains(.versionDelta))
        XCTAssertTrue(
            payload.contains(.sovereignLedgerEntry))
    }

    func test_situationBusContainsSituationField() {
        XCTAssertTrue(
            BASMotherboardBus.situation
                .canonicalPayload
                .contains(.situationField))
    }

    func test_cognitiveFrameBusContainsCanonicalFrame() {
        XCTAssertTrue(
            BASMotherboardBus.cognitiveFrame
                .canonicalPayload
                .contains(.canonicalCognitiveFrame))
    }

    func test_memoryBusContainsMemoryAtom() {
        XCTAssertTrue(
            BASMotherboardBus.memory.canonicalPayload
                .contains(.memoryAtom))
        XCTAssertTrue(
            BASMotherboardBus.memory.canonicalPayload
                .contains(.memoryBundle))
    }

    func test_frontierBusContainsCandidateFrontier() {
        XCTAssertTrue(
            BASMotherboardBus.frontier.canonicalPayload
                .contains(.candidateFrontier))
    }

    func test_sevenCognitiveObjectsAxis() {
        let axis = BASMotherboardCognitiveObjectAxis
            .theSeven
        XCTAssertEqual(axis.count, 7)
        let expected:
            Set<BASMotherboardCanonicalObject> = [
                .situationField,
                .canonicalCognitiveFrame,
                .memoryAtom,
                .candidateFrontier,
                .actionPermit,
                .sovereignWarrant,
                .updateTicket,
            ]
        XCTAssertEqual(axis, expected)
    }

    func test_sevenCognitiveObjectsAllHaveCarryingBuses() {
        for object in
            BASMotherboardCognitiveObjectAxis.theSeven
        {
            XCTAssertNotNil(
                object.carryingBus,
                "cognitive object \(object) must be carried")
        }
    }

    func test_payloadUnionCoversAllBusObjects() {
        var union:
            Set<BASMotherboardCanonicalObject> = []
        for bus in BASMotherboardBus.allCases {
            union.formUnion(bus.canonicalPayload)
        }
        // Union must equal full canonical object set —
        // every object is reachable via some bus.
        XCTAssertEqual(
            union,
            Set(
                BASMotherboardCanonicalObject.allCases))
    }

    func test_codableRoundTrip() throws {
        for object in
            BASMotherboardCanonicalObject.allCases
        {
            let data = try JSONEncoder().encode(object)
            let decoded = try JSONDecoder().decode(
                BASMotherboardCanonicalObject.self,
                from: data)
            XCTAssertEqual(decoded, object)
        }
    }
}
