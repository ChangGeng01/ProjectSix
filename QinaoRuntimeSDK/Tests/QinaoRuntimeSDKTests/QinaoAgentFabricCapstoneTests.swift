import XCTest
@testable import QinaoSeats

/// 六十四.4 — Agent Fabric capstone integration test.
///
/// Proves manifesto v4 doctrine composes with the existing
/// 9-seat infrastructure without conflict. Single test
/// method exercising every doctrine surface.
final class QinaoAgentFabricCapstoneTests: XCTestCase {

    func test_agentFabricFullStackComposes() throws {
        // ============================================================
        // Doctrine cardinality
        // ============================================================

        XCTAssertEqual(
            QinaoSeat.allCases.count, 9,
            "9 seats")
        XCTAssertEqual(
            QinaoAgentLatencyCondition.allCases.count, 6,
            "6 latency conditions")
        XCTAssertEqual(
            QinaoAgentConcurrencyPhase.allCases.count, 3,
            "3 concurrency phases")
        XCTAssertEqual(
            QinaoAgentSwarmPart.allCases.count, 5,
            "5 swarm architecture parts")
        XCTAssertEqual(
            QinaoAgentMantra.allCases.count, 3,
            "3 mantras")

        // ============================================================
        // 单提交口 invariant: 9 seats × 0 directCommit
        // ============================================================

        for seat in QinaoSeat.allCases {
            XCTAssertFalse(
                seat.canonicalCapability.directCommit,
                "Single commit mouth: seat \(seat) MUST " +
                "have directCommit = false")
        }

        // ============================================================
        // 3 phase × 9 seat partition
        // ============================================================

        var seenInPhase: Set<QinaoSeat> = []
        for phase in QinaoAgentConcurrencyPhase.allCases {
            for seat in phase.seatsInPhase {
                XCTAssertFalse(
                    seenInPhase.contains(seat),
                    "seat \(seat) double-allocated")
                seenInPhase.insert(seat)
            }
        }
        XCTAssertEqual(
            seenInPhase, Set(QinaoSeat.allCases),
            "all 9 seats partitioned by phase")

        // ============================================================
        // Hot core minimum
        // ============================================================

        let hotSeats = QinaoSeat.allCases.filter {
            $0.canonicalCapability.residency == .hot
        }
        XCTAssertGreaterThanOrEqual(hotSeats.count, 4)

        // ============================================================
        // proposeDelta: clean path through gate
        // ============================================================

        let goodProposal = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(
                target: .candidateFrontier,
                payload: "{}"),
            leaseRef: "lease-1")
        XCTAssertTrue(
            QinaoAgentProposalGate.isAcceptable(
                goodProposal,
                capability: QinaoSeat.planner
                    .canonicalCapability))

        // ============================================================
        // proposeDelta: typed rejection paths
        // ============================================================

        let outOfDomain = QinaoAgentProposal(
            agent: .scout,
            delta: QinaoAgentDelta(
                target: .sovereignWarrant,
                payload: "{}"),
            leaseRef: nil)
        XCTAssertFalse(
            QinaoAgentProposalGate.isAcceptable(
                outOfDomain,
                capability: QinaoSeat.scout
                    .canonicalCapability))

        let leaseMissing = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(
                target: .candidateFrontier,
                payload: "{}"),
            leaseRef: nil)
        XCTAssertFalse(
            QinaoAgentProposalGate.isAcceptable(
                leaseMissing,
                capability: QinaoSeat.planner
                    .canonicalCapability))

        // ============================================================
        // commitAction: 单提交口
        // ============================================================

        // Missing actionPermit
        XCTAssertFalse(
            QinaoAgentCommitGate.canCommit(
                proposalRefs: ["p1"],
                actionPermitRef: nil,
                sovereignWarrantRef: "w1"))

        // Missing sovereignWarrant
        XCTAssertFalse(
            QinaoAgentCommitGate.canCommit(
                proposalRefs: ["p1"],
                actionPermitRef: "a1",
                sovereignWarrantRef: nil))

        // All three present
        XCTAssertTrue(
            QinaoAgentCommitGate.canCommit(
                proposalRefs: ["p1"],
                actionPermitRef: "a1",
                sovereignWarrantRef: "w1"))

        // ============================================================
        // Mantras
        // ============================================================

        let mantraSlogans = QinaoAgentMantra.allCases
            .map(\.chineseSlogan)
        XCTAssertTrue(
            mantraSlogans.contains("多 agents，单大脑"))
        XCTAssertTrue(
            mantraSlogans.contains("多角色，单主权"))
        XCTAssertTrue(
            mantraSlogans.contains("多视角，单提交"))

        // ============================================================
        // Composition: existing 9-seat enum + capability +
        // proposal + commit gate compose into one coherent
        // pipeline.
        // ============================================================
        // (No assertion needed — reaching here means everything
        // above held.)
    }
}
