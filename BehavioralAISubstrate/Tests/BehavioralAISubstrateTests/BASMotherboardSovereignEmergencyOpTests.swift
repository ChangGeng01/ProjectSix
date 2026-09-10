import XCTest
@testable import BASRuntimeCore

/// 六十二.4 — sovereign emergency op tests.
final class BASMotherboardSovereignEmergencyOpTests:
    XCTestCase
{

    func test_fourEmergencyOps() {
        XCTAssertEqual(
            BASMotherboardSovereignEmergencyOp
                .allCases.count, 4)
    }

    func test_allOpsTraceToDeleteRollbackRebootPrinciple() {
        for op in
            BASMotherboardSovereignEmergencyOp.allCases
        {
            XCTAssertEqual(
                op.triggeredByPrinciple,
                .deleteRollbackRebootFirstClass)
        }
    }

    func test_allOpsProduceEmergencyOpsDuty() {
        for op in
            BASMotherboardSovereignEmergencyOp.allCases
        {
            XCTAssertEqual(
                op.producesDuty, .emergencyOps)
        }
    }

    func test_severityRankOrdering() {
        // deadStop most disruptive, cleanReboot most graceful
        XCTAssertLessThan(
            BASMotherboardSovereignEmergencyOp.deadStop
                .severityRank,
            BASMotherboardSovereignEmergencyOp.quarantine
                .severityRank)
        XCTAssertLessThan(
            BASMotherboardSovereignEmergencyOp.quarantine
                .severityRank,
            BASMotherboardSovereignEmergencyOp.rollback
                .severityRank)
        XCTAssertLessThan(
            BASMotherboardSovereignEmergencyOp.rollback
                .severityRank,
            BASMotherboardSovereignEmergencyOp.cleanReboot
                .severityRank)
    }

    func test_rawValuesPinned() {
        XCTAssertEqual(
            BASMotherboardSovereignEmergencyOp.deadStop
                .rawValue,
            "deadStop")
        XCTAssertEqual(
            BASMotherboardSovereignEmergencyOp.rollback
                .rawValue,
            "rollback")
        XCTAssertEqual(
            BASMotherboardSovereignEmergencyOp.quarantine
                .rawValue,
            "quarantine")
        XCTAssertEqual(
            BASMotherboardSovereignEmergencyOp.cleanReboot
                .rawValue,
            "cleanReboot")
    }

    func test_codableRoundTrip() throws {
        for op in
            BASMotherboardSovereignEmergencyOp.allCases
        {
            let data = try JSONEncoder().encode(op)
            let decoded = try JSONDecoder().decode(
                BASMotherboardSovereignEmergencyOp.self,
                from: data)
            XCTAssertEqual(decoded, op)
        }
    }
}
