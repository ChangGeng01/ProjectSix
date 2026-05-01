import XCTest
@testable import QinaoSeats

/// 六十四.2 — per-seat capability spec tests.
final class QinaoAgentSeatCapabilityTests: XCTestCase {

    // MARK: - Cardinality

    func test_seatDomainsExist() {
        XCTAssertGreaterThanOrEqual(
            QinaoSeatDomain.allCases.count, 11,
            "doctrine names ≥ 11 domain kinds")
    }

    func test_residencyTwoCases() {
        XCTAssertEqual(
            QinaoSeatResidency.allCases.count, 2)
        XCTAssertEqual(
            Set(QinaoSeatResidency.allCases),
            [.hot, .cold])
    }

    // MARK: - Doctrine invariants — Single Commit Mouth

    func test_allNineSeatsHaveZeroDirectCommit() {
        for seat in QinaoSeat.allCases {
            XCTAssertFalse(
                seat.canonicalCapability.directCommit,
                "Single commit mouth invariant: seat " +
                "\(seat) MUST have directCommit = false")
        }
    }

    // MARK: - Hot core minimum size

    func test_hotResidencyContainsAtLeastFourSeats() {
        let hotSeats = QinaoSeat.allCases.filter {
            $0.canonicalCapability.residency == .hot
        }
        XCTAssertGreaterThanOrEqual(
            hotSeats.count, 4,
            "Doctrine: hot core ≥ 4 seats (Scout/Risk/" +
            "SovereignSentinel/Surface min-core)")
    }

    func test_specificHotSeats() {
        XCTAssertEqual(
            QinaoSeat.scout.canonicalCapability
                .residency, .hot)
        XCTAssertEqual(
            QinaoSeat.risk.canonicalCapability.residency,
            .hot)
        XCTAssertEqual(
            QinaoSeat.sovereignSentinel
                .canonicalCapability.residency,
            .hot)
        XCTAssertEqual(
            QinaoSeat.surface.canonicalCapability
                .residency,
            .hot)
    }

    // MARK: - Specific capability assertions per seat

    func test_sovereignSentinelReadsPermitsAndWarrants() {
        let cap = QinaoSeat.sovereignSentinel
            .canonicalCapability
        XCTAssertTrue(
            cap.readDomains.contains(.actionPermit))
        XCTAssertTrue(
            cap.readDomains.contains(.sovereignWarrant))
    }

    func test_riskWritesActionPermit() {
        let cap = QinaoSeat.risk.canonicalCapability
        XCTAssertTrue(
            cap.writeDomains.contains(.actionPermit))
        XCTAssertTrue(
            cap.writeDomains.contains(.riskField))
    }

    func test_plannerWritesCandidateFrontier() {
        let cap = QinaoSeat.planner.canonicalCapability
        XCTAssertTrue(
            cap.writeDomains.contains(.candidateFrontier))
        XCTAssertTrue(cap.requiresLease)
    }

    func test_criticWritesAdversarialBrief() {
        let cap = QinaoSeat.critic.canonicalCapability
        XCTAssertTrue(
            cap.writeDomains.contains(.adversarialBrief))
    }

    func test_evolutionShadowDoesNotWriteCommitDomains() {
        let cap = QinaoSeat.evolutionShadow
            .canonicalCapability
        XCTAssertEqual(cap.residency, .cold,
            "evolution shadow is cold by doctrine")
        // It shouldn't write actionPermit / sovereignWarrant
        // — those are this-turn commit domains.
        XCTAssertFalse(
            cap.writeDomains.contains(.actionPermit))
        XCTAssertFalse(
            cap.writeDomains.contains(.sovereignWarrant))
    }

    func test_scoutHasLightWriteScope() {
        let cap = QinaoSeat.scout.canonicalCapability
        XCTAssertEqual(cap.residency, .hot)
        XCTAssertLessThanOrEqual(
            cap.writeDomains.count, 2,
            "scout is fast pass; light write scope")
    }

    // MARK: - Capability Codable

    func test_capabilityCodableRoundTrip() throws {
        for seat in QinaoSeat.allCases {
            let cap = seat.canonicalCapability
            let data = try JSONEncoder().encode(cap)
            let decoded = try JSONDecoder().decode(
                QinaoSeatCapability.self, from: data)
            XCTAssertEqual(decoded, cap)
        }
    }

    func test_seatDomainCodableRoundTrip() throws {
        for domain in QinaoSeatDomain.allCases {
            let data = try JSONEncoder().encode(domain)
            let decoded = try JSONDecoder().decode(
                QinaoSeatDomain.self, from: data)
            XCTAssertEqual(decoded, domain)
        }
    }
}
