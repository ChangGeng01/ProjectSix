import XCTest
@testable import QinaoSeats

/// 六十五 — v4 Agent Fabric runtime capstone.
///
/// **One mega-test** exercising the full v4 runtime stack:
/// lease enforcer + state graph bus + residency manager +
/// proposing protocol + speculative council + commit gate
/// composing without conflict.
final class QinaoAgentFabricRuntimeCapstoneTests:
    XCTestCase
{

    private struct MockSeat: QinaoSeatProtocol {
        let seat: QinaoSeat
        func contribute(
            snapshotID: String
        ) async throws -> SeatVerdict {
            SeatVerdict(seat: seat, urgency: 0)
        }
    }

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

    func test_v4FullRuntimeStackComposes() async throws {
        // ============================================================
        // 1. Residency manager — only hot seats at boot
        // ============================================================

        let mgr = await QinaoSeatResidencyManager(
            factory: { seat in
                MockSeat(seat: seat)
            })
        let bootActive = await mgr.activeSeats()
        XCTAssertEqual(
            bootActive,
            [
                .scout, .risk, .surface,
                .sovereignSentinel,
            ],
            "boot: only 4 hot seats active")

        // ============================================================
        // 2. Wakeup cold seats (Planner + Critic for cognition)
        // ============================================================

        await mgr.wakeup(seat: .planner)
        await mgr.wakeup(seat: .critic)
        let cognitionActive = await mgr.activeSeats()
        XCTAssertTrue(
            cognitionActive.contains(.planner))
        XCTAssertTrue(
            cognitionActive.contains(.critic))

        // ============================================================
        // 3. Lease enforcer — issue + use + check validity
        // ============================================================

        let leaseEnforcer = QinaoAgentLeaseEnforcer(
            now: { 0 })
        let plannerLeaseRef = await leaseEnforcer.issue(
            QinaoAgentLease(
                agent: .planner,
                maxMs: 1000,
                maxLoops: 3,
                maxWrites: 3,
                scope: [
                    .candidateFrontier,
                    .projection,
                ]))
        let plannerValid = await leaseEnforcer.isValid(
            leaseRef: plannerLeaseRef,
            target: .candidateFrontier)
        XCTAssertTrue(plannerValid)

        // ============================================================
        // 4. State graph bus — subscribe + publish
        // ============================================================

        let bus = QinaoStateGraphBus()
        let scoutSub = await bus.subscribeCanonical(
            seat: .scout)
        XCTAssertTrue(
            scoutSub.domains.contains(.situationField))
        await bus.publish(
            domain: .situationField,
            payload: "initial",
            originAgent: nil)
        var scoutIter = scoutSub.events
            .makeAsyncIterator()
        let event = await scoutIter.next()
        XCTAssertEqual(event?.payload, "initial")
        scoutSub.close()

        // ============================================================
        // 5. Proposing seat → registry → board
        // ============================================================

        let proposal = QinaoAgentProposal(
            agent: .planner,
            delta: QinaoAgentDelta(
                target: .candidateFrontier,
                payload: "{}"),
            leaseRef: plannerLeaseRef)
        let proposingSeat = MockProposingSeat(
            seat: .planner,
            proposals: [proposal])
        let proposalRegistry =
            QinaoAgentProposalRegistry(
                leaseEnforcer: leaseEnforcer)
        await proposalRegistry.register(
            proposingSeat)
        let board = await proposalRegistry
            .dispatchProposals(snapshotID: "s1")
        XCTAssertEqual(board.validProposals.count, 1)
        XCTAssertEqual(
            board.rejectedProposals.count, 0)

        // ============================================================
        // 6. Speculative council — committed when no veto
        // ============================================================

        let outcome:
            QinaoSpeculativeOutcome<Int>
            = await QinaoSpeculativeCouncil
                .runSpeculatively(
                    council: { 1 },
                    veto: { (false, "") })
        switch outcome {
        case .committed(let v):
            XCTAssertEqual(v, 1)
        case .vetoed:
            XCTFail("speculative must commit")
        }

        // ============================================================
        // 7. Speculative council — vetoed discards result
        // ============================================================

        let vetoed:
            QinaoSpeculativeOutcome<Int>
            = await QinaoSpeculativeCouncil
                .runSpeculatively(
                    council: { 1 },
                    sovereignVeto: { true })
        switch vetoed {
        case .committed:
            XCTFail("speculative must veto")
        case .vetoed(let reason):
            XCTAssertEqual(
                reason, "sovereign-veto")
        }

        // ============================================================
        // 8. Single commit gate — invariant held
        // ============================================================

        let proposalRefs = board.validProposals
            .map { _ in "p1" }
        // Missing warrant rejected
        XCTAssertFalse(
            QinaoAgentCommitGate.canCommit(
                proposalRefs: proposalRefs,
                actionPermitRef: "permit-x",
                sovereignWarrantRef: nil))
        // All three present accepted
        XCTAssertTrue(
            QinaoAgentCommitGate.canCommit(
                proposalRefs: proposalRefs,
                actionPermitRef: "permit-x",
                sovereignWarrantRef: "warrant-x"))

        // ============================================================
        // 9. Sleep cold seat — back to lean state
        // ============================================================

        let slept = await mgr.sleep(seat: .planner)
        XCTAssertTrue(slept)
        let postSleep = await mgr.activeSeats()
        XCTAssertFalse(postSleep.contains(.planner))

        // ============================================================
        // 10. doctrine invariants still hold
        // ============================================================

        // Single commit mouth: 9 seats × 0 directCommit
        for s in QinaoSeat.allCases {
            XCTAssertFalse(
                s.canonicalCapability.directCommit)
        }

        // 6 latency conditions all enumerable
        XCTAssertEqual(
            QinaoAgentLatencyCondition.allCases.count, 6)

        // 3 mantras still in place
        XCTAssertEqual(
            QinaoAgentMantra.allCases.count, 3)
    }
}
