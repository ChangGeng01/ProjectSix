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
        let proposal = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(
                target: .candidateFrontier,
                payload: "{}"),
            leaseRef: "lease-ok")
        let seat = MockProposingSeat(
            seat: .planner,
            proposals: [proposal])

        let registry =
            QinaoAgentProposalRegistry()
        await registry.register(seat)
        let board = await registry
            .dispatchProposals(snapshotID: "s1")
        // No lease enforcer attached → registry doesn't
        // check lease validity. Capability validation only
        // (lease ref non-nil suffices for that path here).
        XCTAssertEqual(board.validProposals.count, 1)
        XCTAssertEqual(
            board.rejectedProposals.count, 0)
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
