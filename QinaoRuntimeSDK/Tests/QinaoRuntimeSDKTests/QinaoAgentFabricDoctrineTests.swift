import XCTest
@testable import QinaoSeats

/// 六十四.1 — Agent Fabric doctrine typed reference tests.
final class QinaoAgentFabricDoctrineTests: XCTestCase {

    // MARK: - Cardinality

    func test_sixLatencyConditions() {
        XCTAssertEqual(
            QinaoAgentLatencyCondition.allCases.count, 6)
    }

    func test_threeConcurrencyPhases() {
        XCTAssertEqual(
            QinaoAgentConcurrencyPhase.allCases.count, 3)
    }

    func test_fiveSwarmParts() {
        XCTAssertEqual(
            QinaoAgentSwarmPart.allCases.count, 5)
    }

    func test_threeMantras() {
        XCTAssertEqual(QinaoAgentMantra.allCases.count, 3)
    }

    // MARK: - Phase × seat partition

    func test_perceptionContainsScoutAndMemory() {
        XCTAssertEqual(
            QinaoAgentConcurrencyPhase.perception
                .seatsInPhase,
            [.scout, .memory])
    }

    func test_cognitionContainsFourDeepSeats() {
        XCTAssertEqual(
            QinaoAgentConcurrencyPhase.cognition
                .seatsInPhase,
            [
                .planner, .critic,
                .hostAlignment, .risk,
            ])
    }

    func test_landingContainsFinalSeats() {
        XCTAssertEqual(
            QinaoAgentConcurrencyPhase.landing
                .seatsInPhase,
            [
                .surface,
                .sovereignSentinel,
                .evolutionShadow,
            ])
    }

    func test_threePhasesPartitionAllNineSeats() {
        var seen: Set<QinaoSeat> = []
        for phase in QinaoAgentConcurrencyPhase.allCases {
            for seat in phase.seatsInPhase {
                XCTAssertFalse(
                    seen.contains(seat),
                    "seat \(seat) appears in multiple phases")
                seen.insert(seat)
            }
        }
        XCTAssertEqual(
            seen, Set(QinaoSeat.allCases),
            "9 seats × 3 phases must partition exhaustively")
    }

    func test_eachSeatHasPhase() {
        for seat in QinaoSeat.allCases {
            // Non-optional access pinned.
            _ = seat.concurrencyPhase
        }
    }

    // MARK: - Mantras

    func test_mantraSlogans() {
        XCTAssertEqual(
            QinaoAgentMantra.multiAgentsSingleBrain
                .chineseSlogan,
            "多 agents，单大脑")
        XCTAssertEqual(
            QinaoAgentMantra.multiRolesSingleSovereign
                .chineseSlogan,
            "多角色，单主权")
        XCTAssertEqual(
            QinaoAgentMantra.multiPerspectivesSingleCommit
                .chineseSlogan,
            "多视角，单提交")
    }

    // MARK: - Codable round-trip

    func test_latencyConditionCodable() throws {
        for value in
            QinaoAgentLatencyCondition.allCases
        {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(
                QinaoAgentLatencyCondition.self,
                from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    func test_phaseCodable() throws {
        for value in
            QinaoAgentConcurrencyPhase.allCases
        {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(
                QinaoAgentConcurrencyPhase.self,
                from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    func test_swarmPartCodable() throws {
        for value in QinaoAgentSwarmPart.allCases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(
                QinaoAgentSwarmPart.self, from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    func test_mantraCodable() throws {
        for value in QinaoAgentMantra.allCases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(
                QinaoAgentMantra.self, from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    // MARK: - Raw values pinned

    func test_latencyConditionRawValues() {
        XCTAssertEqual(
            QinaoAgentLatencyCondition.encodeOnce
                .rawValue,
            "encodeOnce")
        XCTAssertEqual(
            QinaoAgentLatencyCondition
                .singleCommitMouth.rawValue,
            "singleCommitMouth")
    }
}
