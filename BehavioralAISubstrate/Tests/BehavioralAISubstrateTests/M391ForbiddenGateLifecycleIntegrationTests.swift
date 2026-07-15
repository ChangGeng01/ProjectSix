import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASObservability

/// M391 — pin the integration contract that
/// `BASForbiddenLifecycleGate` (M386) is now load-bearing in the
/// `BASUpdateTicketLifecycleCoordinator` actor path.
///
/// What this file pins:
///
///   1. `submitWithForbiddenGate(_:forbidden:)` accepts when
///      candidate is nil → entry persists in `.proposed`.
///   2. `submitWithForbiddenGate` accepts when candidate is
///      permissive → entry persists in `.proposed`.
///   3. `submitWithForbiddenGate` rejects when sovereign-rejected
///      candidate is paired → entry persists in `.rejected` with
///      the gate's reason code.
///   4. `submitWithForbiddenGate` is idempotent on duplicates —
///      re-presenting the same ticket twice does not crash; the
///      second call's gate decision still applies.
///   5. `startTrialWithForbiddenGate` accepts when candidate is
///      permissive → ticket reaches `.trialing`.
///   6. `startTrialWithForbiddenGate` rejects when held sovereign
///      candidate is paired → ticket reaches `.rejected` with the
///      gate's reason code + trial-record ref.
///   7. `ingestTurnResultWithForbiddenGate` walks tickets,
///      paired-or-not, and returns the accepted count.
final class M391ForbiddenGateLifecycleIntegrationTests: XCTestCase {

    // MARK: - Fixture helpers

    private func ticket(
        id: String = "tk-1"
    ) -> BASUpdateTicket {
        BASUpdateTicket(
            ticketID: id,
            sessionRef: "sess-test",
            summary: "test ticket",
            confidence: 0.5)
    }

    private func candidate(
        reviewState: BASSovereignReviewState = .pending,
        policy: BASShadowTrialPolicy = .standard
    ) -> BASForbiddenKnowledgeCandidate {
        BASForbiddenKnowledgeCandidate(
            candidateID: "fk-1",
            sourceRefs: ["src-1"],
            riskReasons: ["test"],
            contaminationRefs: [],
            coolingPeriod: 60,
            shadowTrialPolicy: policy,
            sovereignReviewState: reviewState)
    }

    private func makeCoordinator() -> BASUpdateTicketLifecycleCoordinator {
        BASUpdateTicketLifecycleCoordinator(
            clock: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    // MARK: - 1. nil candidate accepts

    func testSubmitWithNilForbiddenAccepts() async throws {
        let coord = makeCoordinator()
        let state = try await coord.submitWithForbiddenGate(
            ticket(), forbidden: nil)
        XCTAssertEqual(state, .proposed)
        let entry = await coord.entry(ticketID: "tk-1")
        XCTAssertEqual(entry?.state, .proposed)
    }

    // MARK: - 2. Permissive candidate accepts

    func testSubmitWithPermissiveForbiddenAccepts() async throws {
        let coord = makeCoordinator()
        let state = try await coord.submitWithForbiddenGate(
            ticket(),
            forbidden: candidate(reviewState: .pending))
        XCTAssertEqual(state, .proposed)
    }

    // MARK: - 3. Rejected sovereign refuses submission

    func testSubmitWithRejectedSovereignRefuses() async throws {
        let coord = makeCoordinator()
        let state = try await coord.submitWithForbiddenGate(
            ticket(),
            forbidden: candidate(reviewState: .rejected))
        XCTAssertEqual(state, .rejected)
        let entry = await coord.entry(ticketID: "tk-1")
        XCTAssertEqual(entry?.state, .rejected)
        // Reason codes from the gate must propagate to the
        // rejection.
        let history = entry?.history.last
        XCTAssertNotNil(history)
        XCTAssertTrue(
            history?.reasonCodes.contains(
                "lifecycle.gated:forbidden:sovereign-rejected"
            ) ?? false)
    }

    // MARK: - 4. Duplicate-tolerant idempotency

    func testSubmitWithForbiddenGateIsIdempotent() async throws {
        let coord = makeCoordinator()
        let first = try await coord.submitWithForbiddenGate(
            ticket(), forbidden: nil)
        XCTAssertEqual(first, .proposed)
        // Re-present same ticket — should not throw.
        let second = try await coord.submitWithForbiddenGate(
            ticket(), forbidden: nil)
        XCTAssertEqual(second, .proposed)
        // Only one entry exists.
        let count = await coord.count()
        XCTAssertEqual(count, 1)
    }

    // MARK: - 4b. Chapter 九十一 fix-pin — re-rejecting an
    //          already-rejected ticket is idempotent

    /// Pin chapter 九十一 deep-review fix #3: when a ticket has
    /// already been rejected (by a prior gate call or a
    /// concurrent caller), re-applying `submitWithForbiddenGate`
    /// with a refusing-gate candidate must NOT throw
    /// `LifecycleError.illegalTransition(from: .rejected, …)`.
    /// Pre-fix this would have thrown.
    func testReRejectingAlreadyRejectedTicketIsIdempotent()
    async throws {
        let coord = makeCoordinator()
        // First call: gate refuses → ticket .rejected.
        let firstState = try await coord.submitWithForbiddenGate(
            ticket(),
            forbidden: candidate(reviewState: .rejected))
        XCTAssertEqual(firstState, .rejected)
        // Second call with same (rejecting) candidate: must not
        // throw, must report .rejected, must leave the entry
        // unchanged.
        let secondState = try await coord
            .submitWithForbiddenGate(
                ticket(),
                forbidden: candidate(reviewState: .rejected))
        XCTAssertEqual(secondState, .rejected)
        let entry = await coord.entry(ticketID: "tk-1")
        XCTAssertEqual(entry?.state, .rejected)
        // Entry has exactly one rejection-transition in history
        // (no duplicate).
        let rejectionTransitions = entry?.history
            .filter { $0.to == .rejected }
            .count ?? 0
        XCTAssertEqual(rejectionTransitions, 1)
    }

    // MARK: - 5. Permissive candidate startTrial accepts

    func testStartTrialWithPermissiveCandidate() async throws {
        let coord = makeCoordinator()
        _ = try await coord.submit(ticket())
        try await coord.startTrialWithForbiddenGate(
            ticketID: "tk-1",
            trialRecordRef: "trial-x",
            forbidden: candidate(reviewState: .pending))
        let entry = await coord.entry(ticketID: "tk-1")
        XCTAssertEqual(entry?.state, .trialing)
    }

    // MARK: - 5b. Chapter 九十一.5 fix-pin — startTrial idempotent
    //          on already-rejected

    /// Pin chapter 九十一.5 honesty correction:
    /// `startTrialWithForbiddenGate` shares the idempotent-
    /// reject contract with `submitWithForbiddenGate`. When a
    /// ticket is already rejected and the gate refuses
    /// `.startShadowTrial`, calling `startTrialWithForbiddenGate`
    /// must NOT throw `illegalTransition(from: .rejected, _)`.
    /// Pre-correction this threw.
    func testStartTrialWithForbiddenGateIsIdempotentOnAlreadyRejected()
    async throws {
        let coord = makeCoordinator()
        // Get the ticket into .rejected via the submit path.
        let firstState = try await coord.submitWithForbiddenGate(
            ticket(),
            forbidden: candidate(reviewState: .rejected))
        XCTAssertEqual(firstState, .rejected)
        // Now call startTrialWithForbiddenGate against the SAME
        // ticket with a held-sovereign candidate (gate refuses
        // .startShadowTrial). Pre-correction this threw because
        // the underlying markRejected hits already-rejected.
        try await coord.startTrialWithForbiddenGate(
            ticketID: "tk-1",
            trialRecordRef: "trial-x",
            forbidden: candidate(reviewState: .held))
        // Entry stays .rejected; trial-record-ref code is NOT
        // appended a second time because the underlying
        // markRejected was idempotent (no new history
        // transition).
        let entry = await coord.entry(ticketID: "tk-1")
        XCTAssertEqual(entry?.state, .rejected)
        let rejectionTransitions = entry?.history
            .filter { $0.to == .rejected }
            .count ?? 0
        XCTAssertEqual(
            rejectionTransitions, 1,
            "idempotent rejection must not duplicate history")
    }

    // MARK: - 6. Held sovereign refuses startTrial

    func testStartTrialWithHeldSovereignRejects() async throws {
        let coord = makeCoordinator()
        _ = try await coord.submit(ticket())
        try await coord.startTrialWithForbiddenGate(
            ticketID: "tk-1",
            trialRecordRef: "trial-x",
            forbidden: candidate(reviewState: .held))
        let entry = await coord.entry(ticketID: "tk-1")
        XCTAssertEqual(entry?.state, .rejected)
        // Reason codes contain the gate's refusal AND the
        // trial-record ref so the audit trail shows what trial
        // was being attempted.
        let history = entry?.history.last
        XCTAssertNotNil(history)
        let codes = history?.reasonCodes ?? []
        XCTAssertTrue(codes.contains(
            "lifecycle.gated:forbidden:sovereign-held:trial-start-refused"))
        XCTAssertTrue(codes.contains("trial-record-ref:trial-x"))
    }

    // MARK: - 7. ingestTicketsWithForbiddenGate counts accepts

    func testIngestTicketsCountsAccepted() async throws {
        let coord = makeCoordinator()
        let tickets = [
            ticket(id: "tk-a"),
            ticket(id: "tk-b"),
            ticket(id: "tk-c"),
        ]
        let forbiddenMap: [String: BASForbiddenKnowledgeCandidate] = [
            "tk-b": candidate(reviewState: .rejected),
        ]
        let accepted = await coord.ingestTicketsWithForbiddenGate(
            tickets, forbiddenByTicketID: forbiddenMap)
        // tk-a no forbidden → accepted
        // tk-b sovereign-rejected → rejected
        // tk-c no forbidden → accepted
        XCTAssertEqual(accepted, 2)
        let stateA = await coord.entry(ticketID: "tk-a")?.state
        let stateB = await coord.entry(ticketID: "tk-b")?.state
        let stateC = await coord.entry(ticketID: "tk-c")?.state
        XCTAssertEqual(stateA, .proposed)
        XCTAssertEqual(stateB, .rejected)
        XCTAssertEqual(stateC, .proposed)
    }

    // audit hostkit-rest LOW-2 (sibling of ZoneGate MED-2): a re-presented already-rejected ticket
    // must report its true state, not a hardcoded .proposed that inflates the ingest accept count.
    func testResubmitOfRejectedTicketReportsTrueStateNotProposed() async throws {
        let coord = makeCoordinator()
        _ = try await coord.submit(ticket(id: "tk-1"))
        try await coord.markRejected(ticketID: "tk-1", reasonCodes: ["override"])
        // Re-present with no forbidden candidate → the gate allows → falls to the fixed return.
        let dupState = try await coord.submitWithForbiddenGate(ticket(id: "tk-1"), forbidden: nil)
        XCTAssertEqual(dupState, .rejected,
            "a re-presented already-rejected ticket must report its true state, not .proposed")
        let accepted = await coord.ingestTicketsWithForbiddenGate(
            [ticket(id: "tk-1"), ticket(id: "tk-2")], forbiddenByTicketID: [:])
        XCTAssertEqual(accepted, 1, "an already-rejected duplicate must not inflate the accept count")
        let e2 = await coord.entry(ticketID: "tk-2")?.state
        XCTAssertEqual(e2, .proposed, "the fresh ticket is genuinely proposed")
    }
}
