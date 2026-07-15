import XCTest
@testable import QinaoSeats

/// 六十五.4 — proposing protocol + dispatch tests.
final class QinaoSeatProposingProtocolTests: XCTestCase {

    /// Mock proposing seat that emits one or more typed
    /// proposals on each call.
    private struct MockProposingSeat:
        QinaoSeatProposingProtocol
    {
        let seat: QinaoSeat
        let proposals: [QinaoAgentProposal]

        func proposeDeltas(
            snapshotID: String
        ) async throws -> [QinaoAgentProposal] {
            proposals
        }
    }

    private struct ThrowingSeat:
        QinaoSeatProposingProtocol
    {
        let seat: QinaoSeat = .planner
        struct E: Error {}
        func proposeDeltas(
            snapshotID: String
        ) async throws -> [QinaoAgentProposal] {
            throw E()
        }
    }

    func test_validProposalAccepted() async {
        // audit F12: a leaseRef now requires a wired enforcer to verify it (fail-closed).
        // Issue a real lease + attach the enforcer so this is the genuinely-valid accept path.
        let enforcer = QinaoAgentLeaseEnforcer()
        let leaseRef = await enforcer.issue(QinaoAgentLease(
            agent: .planner, maxMs: 60_000, maxLoops: 10, maxWrites: 10,
            scope: [.candidateFrontier]))
        let proposal = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(
                target: .candidateFrontier,
                payload: "{}"),
            leaseRef: leaseRef)
        let seat = MockProposingSeat(
            seat: .planner,
            proposals: [proposal])

        let registry = QinaoAgentProposalRegistry(leaseEnforcer: enforcer)
        await registry.register(seat)
        let board = await registry
            .dispatchProposals(snapshotID: "s1")
        XCTAssertEqual(board.validProposals.count, 1)
        XCTAssertEqual(
            board.rejectedProposals.count, 0)
    }

    // MARK: - audit F12: fail-closed identity + lease binding

    /// A leaseRef with NO enforcer wired is unverifiable → rejected (was fail-open: passed).
    func test_leaseRefWithoutEnforcerIsRejected() async {
        let proposal = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(target: .candidateFrontier, payload: "{}"),
            leaseRef: "fabricated-lease")
        let registry = QinaoAgentProposalRegistry()  // no enforcer
        await registry.register(MockProposingSeat(seat: .planner, proposals: [proposal]))
        let board = await registry.dispatchProposals(snapshotID: "s1")
        XCTAssertEqual(board.validProposals.count, 0, "unverifiable lease must fail closed")
        XCTAssertEqual(board.rejectedProposals.count, 1)
        XCTAssertTrue(board.rejectedProposals[0].issues.contains(
            .leaseUnverifiable(agent: .planner)))
    }

    /// A seat proposing under ANOTHER agent's identity → rejected (seat↔agent binding).
    func test_seatImpersonatingAnotherAgentIsRejected() async {
        // seat .scout emits a proposal claiming to be .planner
        let proposal = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(target: .candidateFrontier, payload: "{}"),
            leaseRef: nil)
        let registry = QinaoAgentProposalRegistry()
        await registry.register(MockProposingSeat(seat: .scout, proposals: [proposal]))
        let board = await registry.dispatchProposals(snapshotID: "s1")
        XCTAssertEqual(board.validProposals.count, 0, "seat impersonation must fail closed")
        XCTAssertTrue(board.rejectedProposals[0].issues.contains(
            .seatIdentityMismatch(claimed: .planner, actual: .scout)))
    }

    func test_invalidWriteDomainRejected() async {
        // Scout cannot write actionPermit.
        let proposal = QinaoAgentProposal(
            agent: .scout,
            delta: QinaoAgentDelta(
                target: .actionPermit,
                payload: "{}"),
            leaseRef: nil)
        let seat = MockProposingSeat(
            seat: .scout,
            proposals: [proposal])

        let registry =
            QinaoAgentProposalRegistry()
        await registry.register(seat)
        let board = await registry
            .dispatchProposals(snapshotID: "s1")
        XCTAssertEqual(board.validProposals.count, 0)
        XCTAssertEqual(
            board.rejectedProposals.count, 1)
    }

    func test_throwingSeatRecordedAsFailed() async {
        let seat = ThrowingSeat()
        let registry =
            QinaoAgentProposalRegistry()
        await registry.register(seat)
        let board = await registry
            .dispatchProposals(snapshotID: "s1")
        XCTAssertNotNil(board.failedSeats[.planner])
        XCTAssertEqual(board.validProposals.count, 0)
    }

    func test_leaseEnforcerIntegration() async {
        let enforcer = QinaoAgentLeaseEnforcer(
            now: { 0 })
        let leaseRef = await enforcer.issue(
            QinaoAgentLease(
                agent: .planner,
                maxMs: 1000,
                maxLoops: 3,
                maxWrites: 3,
                scope: [.candidateFrontier]))
        let proposal = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(
                target: .candidateFrontier,
                payload: "{}"),
            leaseRef: leaseRef)
        let seat = MockProposingSeat(
            seat: .planner, proposals: [proposal])

        let registry =
            QinaoAgentProposalRegistry(
                leaseEnforcer: enforcer)
        await registry.register(seat)
        let board = await registry
            .dispatchProposals(snapshotID: "s1")
        XCTAssertEqual(board.validProposals.count, 1)
    }

    func test_revokedLeaseRejectsProposal() async {
        let enforcer = QinaoAgentLeaseEnforcer(
            now: { 0 })
        let leaseRef = await enforcer.issue(
            QinaoAgentLease(
                agent: .planner,
                maxMs: 1000,
                maxLoops: 3,
                maxWrites: 3,
                scope: [.candidateFrontier]))
        await enforcer.revoke(leaseRef: leaseRef)
        let proposal = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(
                target: .candidateFrontier,
                payload: "{}"),
            leaseRef: leaseRef)
        let seat = MockProposingSeat(
            seat: .planner, proposals: [proposal])

        let registry =
            QinaoAgentProposalRegistry(
                leaseEnforcer: enforcer)
        await registry.register(seat)
        let board = await registry
            .dispatchProposals(snapshotID: "s1")
        XCTAssertEqual(board.validProposals.count, 0)
        XCTAssertEqual(
            board.rejectedProposals.count, 1)
    }

    func test_registryClear() async {
        let registry =
            QinaoAgentProposalRegistry()
        let seat = MockProposingSeat(
            seat: .planner, proposals: [])
        await registry.register(seat)
        var seats = await registry.registeredSeats()
        XCTAssertEqual(seats, [.planner])
        await registry.clear()
        seats = await registry.registeredSeats()
        XCTAssertEqual(seats, [])
    }

    func test_proposalBoardCodable() throws {
        let board = QinaoAgentProposalBoard(
            validProposals: [
                QinaoAgentProposal(
                    agent: .planner,
                    delta: QinaoAgentDelta(
                        target: .candidateFrontier,
                        payload: "p"),
                    leaseRef: "l")
            ],
            rejectedProposals: [],
            failedSeats: [.scout: "test error"])
        let data = try JSONEncoder().encode(board)
        let decoded = try JSONDecoder().decode(
            QinaoAgentProposalBoard.self, from: data)
        XCTAssertEqual(decoded, board)
    }
}
