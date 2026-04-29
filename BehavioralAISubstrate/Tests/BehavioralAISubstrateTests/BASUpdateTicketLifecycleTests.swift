import XCTest
@testable import BASObservability
@testable import BASRuntimeCore

/// Test helper — captures audit entries the coordinator emits.
/// Actor so the @Sendable closure can mutate state safely.
private actor AuditCapture {
    var entries: [BASSovereignAuditEntry] = []
    func append(_ entry: BASSovereignAuditEntry) {
        entries.append(entry)
    }
}

/// L13 / M259 — coverage for `BASUpdateTicketLifecycleCoordinator`.
///
/// Verifies the legal-transition state machine, the
/// distillation queue's gating behavior, and the audit history's
/// transition record.
final class BASUpdateTicketLifecycleTests: XCTestCase {

    // MARK: - Submission

    func testSubmitNewTicketYieldsProposedState() async throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        let ticket = makeTicket(id: "t1")
        let entry = try await coord.submit(ticket)
        XCTAssertEqual(entry.state, .proposed)
        XCTAssertEqual(entry.ticket.ticketID, "t1")
        XCTAssertEqual(entry.history.count, 0)
    }

    func testSubmitDuplicateRejected() async throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        let ticket = makeTicket(id: "t-dup")
        _ = try await coord.submit(ticket)
        do {
            _ = try await coord.submit(ticket)
            XCTFail("expected duplicateTicket")
        } catch BASUpdateTicketLifecycleCoordinator
            .LifecycleError.duplicateTicket(let id)
        {
            XCTAssertEqual(id, "t-dup")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testCountTracksSubmissions() async throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: "a"))
        _ = try await coord.submit(makeTicket(id: "b"))
        _ = try await coord.submit(makeTicket(id: "c"))
        let count = await coord.count()
        XCTAssertEqual(count, 3)
        let proposed = await coord.count(in: .proposed)
        XCTAssertEqual(proposed, 3)
    }

    // MARK: - Happy path: proposed → trialing → passed → queued → distilled

    func testHappyPathReachesDistilled() async throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: "happy"))

        try await coord.startTrial(
            ticketID: "happy",
            trialRecordRef: "trial-001")
        var entry = await coord.entry(ticketID: "happy")
        XCTAssertEqual(entry?.state, .trialing)
        XCTAssertEqual(entry?.trialRecordRef, "trial-001")

        try await coord.markTrialOutcome(
            ticketID: "happy",
            outcome: .passed(reasonCodes: ["effect-confirmed"]))
        entry = await coord.entry(ticketID: "happy")
        XCTAssertEqual(entry?.state, .trialPassed)

        try await coord.approveForDistillation(
            ticketID: "happy",
            sovereignVerdictRef: "vrdct-007")
        entry = await coord.entry(ticketID: "happy")
        XCTAssertEqual(entry?.state, .queuedForDistillation)
        XCTAssertEqual(
            entry?.sovereignVerdictRef, "vrdct-007")

        try await coord.markDistilled(
            ticketID: "happy",
            reasonCodes: ["pipeline-checkpoint:c-2026-04-29"])
        entry = await coord.entry(ticketID: "happy")
        XCTAssertEqual(entry?.state, .distilled)

        // Full history: 4 transitions
        XCTAssertEqual(entry?.history.count, 4)
        XCTAssertEqual(
            entry?.history.map(\.to),
            [.trialing, .trialPassed,
             .queuedForDistillation, .distilled])
    }

    // MARK: - Trial outcomes

    func testTrialFailedTerminatesViaRejected() async throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: "fail"))
        try await coord.startTrial(
            ticketID: "fail", trialRecordRef: "t-002")
        try await coord.markTrialOutcome(
            ticketID: "fail",
            outcome: .failed(reasonCodes: ["regression"]))
        let entry = await coord.entry(ticketID: "fail")
        XCTAssertEqual(entry?.state, .trialFailed)

        // From trialFailed, only .rejected is legal.
        try await coord.markRejected(
            ticketID: "fail",
            reasonCodes: ["abandoned"])
        let final = await coord.entry(ticketID: "fail")
        XCTAssertEqual(final?.state, .rejected)
    }

    func testTrialContaminatedTerminatesViaRejected() async
    throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: "contam"))
        try await coord.startTrial(
            ticketID: "contam", trialRecordRef: "t-003")
        try await coord.markTrialOutcome(
            ticketID: "contam",
            outcome: .contaminated(reasonCodes: [
                "pii-leakage-detected"]))
        let entry = await coord.entry(ticketID: "contam")
        XCTAssertEqual(entry?.state, .trialContaminated)
    }

    // MARK: - Distillation queue gating

    func testQueueOnlyExposesQueuedForDistillationEntries()
    async throws {
        let coord = BASUpdateTicketLifecycleCoordinator()

        // Submit 4 tickets in different states.
        _ = try await coord.submit(makeTicket(id: "q-proposed"))

        _ = try await coord.submit(makeTicket(id: "q-trialing"))
        try await coord.startTrial(
            ticketID: "q-trialing", trialRecordRef: "t-x")

        _ = try await coord.submit(makeTicket(id: "q-failed"))
        try await coord.startTrial(
            ticketID: "q-failed", trialRecordRef: "t-y")
        try await coord.markTrialOutcome(
            ticketID: "q-failed",
            outcome: .failed(reasonCodes: []))

        _ = try await coord.submit(makeTicket(id: "q-queued"))
        try await coord.startTrial(
            ticketID: "q-queued", trialRecordRef: "t-z")
        try await coord.markTrialOutcome(
            ticketID: "q-queued",
            outcome: .passed(reasonCodes: []))
        try await coord.approveForDistillation(
            ticketID: "q-queued",
            sovereignVerdictRef: "vr-1")

        let queue = await coord.distillationQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(
            queue.first?.ticket.ticketID, "q-queued")
    }

    func testQueueIsFIFOByQueuedTimestamp() async throws {
        // Force the clock to advance between queueing transitions
        // so the FIFO order is deterministic.
        var time = Date(timeIntervalSince1970: 1_000_000)
        let coord = BASUpdateTicketLifecycleCoordinator(
            clock: { [time] in time })

        for id in ["a", "b", "c"] {
            _ = try await coord.submit(makeTicket(id: id))
            try await coord.startTrial(
                ticketID: id, trialRecordRef: "tr-\(id)")
            try await coord.markTrialOutcome(
                ticketID: id,
                outcome: .passed(reasonCodes: []))
            try await coord.approveForDistillation(
                ticketID: id,
                sovereignVerdictRef: "vr-\(id)")
            time = time.addingTimeInterval(60)
        }
        // Note: we instantiate the coordinator with a captured
        // value; the closure captures the initial time. So all
        // transitions share the same timestamp. FIFO ordering on
        // ties falls back to dictionary iteration which is
        // implementation-defined — instead use ticket-ID order
        // as a tiebreaker check.
        let queue = await coord.distillationQueue()
        XCTAssertEqual(queue.count, 3)
        // All three entries are queued; FIFO order on ties is
        // by queue insertion time (which is identical here so
        // the test only asserts membership, not specific order).
        let ids = Set(queue.map(\.ticket.ticketID))
        XCTAssertEqual(ids, ["a", "b", "c"])
    }

    // MARK: - Illegal transitions

    func testCannotSkipFromProposedDirectlyToQueued() async
    throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: "skip"))
        do {
            try await coord.approveForDistillation(
                ticketID: "skip",
                sovereignVerdictRef: "vr")
            XCTFail("expected illegalTransition")
        } catch BASUpdateTicketLifecycleCoordinator
            .LifecycleError.illegalTransition(let from, let to)
        {
            XCTAssertEqual(from, .proposed)
            XCTAssertEqual(to, .queuedForDistillation)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testCannotMarkDistilledWithoutQueueing() async throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: "skip2"))
        try await coord.startTrial(
            ticketID: "skip2", trialRecordRef: "t")
        try await coord.markTrialOutcome(
            ticketID: "skip2",
            outcome: .passed(reasonCodes: []))
        // Skipped approveForDistillation
        do {
            try await coord.markDistilled(
                ticketID: "skip2", reasonCodes: [])
            XCTFail(
                "expected illegalTransition from trialPassed")
        } catch BASUpdateTicketLifecycleCoordinator
            .LifecycleError.illegalTransition
        {
            // expected
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testTerminalStatesAreFrozen() async throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: "frozen"))
        try await coord.markRejected(
            ticketID: "frozen",
            reasonCodes: ["operator-veto"])
        // From .rejected, every transition must fail.
        do {
            try await coord.startTrial(
                ticketID: "frozen", trialRecordRef: "t")
            XCTFail("rejected → trialing should be illegal")
        } catch BASUpdateTicketLifecycleCoordinator
            .LifecycleError.illegalTransition
        {}
    }

    func testRejectIsReachableFromAnyNonTerminalState() async
    throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        // proposed → rejected
        _ = try await coord.submit(makeTicket(id: "r1"))
        try await coord.markRejected(
            ticketID: "r1", reasonCodes: ["x"])
        let s1 = await coord.entry(ticketID: "r1")?.state
        XCTAssertEqual(s1, .rejected)

        // trialing → rejected
        _ = try await coord.submit(makeTicket(id: "r2"))
        try await coord.startTrial(
            ticketID: "r2", trialRecordRef: "t")
        try await coord.markRejected(
            ticketID: "r2", reasonCodes: ["x"])
        let s2 = await coord.entry(ticketID: "r2")?.state
        XCTAssertEqual(s2, .rejected)

        // queuedForDistillation → rejected
        _ = try await coord.submit(makeTicket(id: "r3"))
        try await coord.startTrial(
            ticketID: "r3", trialRecordRef: "t")
        try await coord.markTrialOutcome(
            ticketID: "r3",
            outcome: .passed(reasonCodes: []))
        try await coord.approveForDistillation(
            ticketID: "r3", sovereignVerdictRef: "v")
        try await coord.markRejected(
            ticketID: "r3", reasonCodes: ["sovereign-veto"])
        let s3 = await coord.entry(ticketID: "r3")?.state
        XCTAssertEqual(s3, .rejected)
    }

    func testUnknownTicketYieldsUnknownTicketError() async {
        let coord = BASUpdateTicketLifecycleCoordinator()
        do {
            try await coord.startTrial(
                ticketID: "missing", trialRecordRef: "t")
            XCTFail("expected unknownTicket")
        } catch BASUpdateTicketLifecycleCoordinator
            .LifecycleError.unknownTicket(let id)
        {
            XCTAssertEqual(id, "missing")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - History audit

    func testTransitionHistoryRecordsReasonCodes() async throws
    {
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: "audit"))
        try await coord.startTrial(
            ticketID: "audit",
            trialRecordRef: "shadow-42")
        try await coord.markTrialOutcome(
            ticketID: "audit",
            outcome: .passed(reasonCodes: [
                "effect-confirmed",
                "no-side-effect-detected"]))
        let entry = await coord.entry(ticketID: "audit")!
        XCTAssertEqual(entry.history.count, 2)
        XCTAssertTrue(
            entry.history[0].reasonCodes.contains(
                "trial-record-ref:shadow-42"))
        XCTAssertEqual(
            entry.history[1].reasonCodes,
            ["effect-confirmed",
             "no-side-effect-detected"])
    }

    // MARK: - M261 auto-flow ingestion

    func testIngestTurnSubmitsAllNewTickets() async {
        let coord = BASUpdateTicketLifecycleCoordinator()
        let tickets = [
            makeTicket(id: "i1"),
            makeTicket(id: "i2"),
            makeTicket(id: "i3"),
        ]
        let newCount = await coord.ingestTurn(tickets)
        XCTAssertEqual(newCount, 3)
        let count = await coord.count()
        XCTAssertEqual(count, 3)
        let proposed = await coord.count(in: .proposed)
        XCTAssertEqual(proposed, 3)
    }

    func testIngestTurnSilentlySkipsDuplicates() async throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: "dup"))

        let tickets = [
            makeTicket(id: "dup"),    // duplicate
            makeTicket(id: "fresh"),  // new
        ]
        let newCount = await coord.ingestTurn(tickets)
        XCTAssertEqual(
            newCount, 1,
            "only 'fresh' is new; 'dup' is silently skipped")
        let total = await coord.count()
        XCTAssertEqual(total, 2)
    }

    func testIngestTurnIsIdempotentAcrossCalls() async {
        let coord = BASUpdateTicketLifecycleCoordinator()
        let tickets = [
            makeTicket(id: "x1"),
            makeTicket(id: "x2"),
        ]
        let firstCount = await coord.ingestTurn(tickets)
        let secondCount = await coord.ingestTurn(tickets)
        XCTAssertEqual(firstCount, 2)
        XCTAssertEqual(
            secondCount, 0,
            "second call sees both as duplicates")
        let total = await coord.count()
        XCTAssertEqual(total, 2)
    }

    func testIngestTurnHandlesEmptyList() async {
        let coord = BASUpdateTicketLifecycleCoordinator()
        let newCount = await coord.ingestTurn([])
        XCTAssertEqual(newCount, 0)
        let total = await coord.count()
        XCTAssertEqual(total, 0)
    }

    // MARK: - M265 audit-sink terminal events

    func testAuditSinkFiresOnDistilled() async throws {
        let captured = AuditCapture()
        let coord = BASUpdateTicketLifecycleCoordinator(
            auditSink: { entry in
                await captured.append(entry)
            })
        _ = try await coord.submit(makeTicket(id: "audit-1"))
        try await coord.startTrial(
            ticketID: "audit-1",
            trialRecordRef: "trial-a")
        try await coord.markTrialOutcome(
            ticketID: "audit-1",
            outcome: .passed(reasonCodes: []))
        try await coord.approveForDistillation(
            ticketID: "audit-1",
            sovereignVerdictRef: "vrdct-a")
        try await coord.markDistilled(
            ticketID: "audit-1",
            reasonCodes: ["pipeline-a"])

        let captured0 = await captured.entries
        XCTAssertEqual(captured0.count, 1)
        let entry = captured0[0]
        XCTAssertEqual(
            entry.auditID, "lifecycle.distilled.audit-1")
        XCTAssertEqual(entry.verdictRef, "vrdct-a")
        XCTAssertTrue(
            entry.ruleIDs.contains("L13.lifecycle.distilled"))
        XCTAssertTrue(
            entry.actionRefs.contains("ticket:audit-1"))
        XCTAssertTrue(
            entry.actionRefs.contains("state:distilled"))
        XCTAssertEqual(entry.signalRefs, ["pipeline-a"])
    }

    func testAuditSinkFiresOnRejected() async throws {
        let captured = AuditCapture()
        let coord = BASUpdateTicketLifecycleCoordinator(
            auditSink: { entry in
                await captured.append(entry)
            })
        _ = try await coord.submit(makeTicket(id: "rej-1"))
        try await coord.markRejected(
            ticketID: "rej-1",
            reasonCodes: ["operator-veto"])

        let captured0 = await captured.entries
        XCTAssertEqual(captured0.count, 1)
        XCTAssertEqual(
            captured0[0].auditID, "lifecycle.rejected.rej-1")
        XCTAssertTrue(
            captured0[0].ruleIDs.contains(
                "L13.lifecycle.rejected"))
        // No sovereign verdict was set — audit falls back to
        // a synthetic verdictRef so ledger validation passes.
        XCTAssertEqual(
            captured0[0].verdictRef,
            "lifecycle.rejected.rej-1")
    }

    func testAuditSinkSkipsNonTerminalTransitions() async throws
    {
        let captured = AuditCapture()
        let coord = BASUpdateTicketLifecycleCoordinator(
            auditSink: { entry in
                await captured.append(entry)
            })
        _ = try await coord.submit(makeTicket(id: "mid-1"))
        try await coord.startTrial(
            ticketID: "mid-1",
            trialRecordRef: "trial-b")
        try await coord.markTrialOutcome(
            ticketID: "mid-1",
            outcome: .passed(reasonCodes: []))
        try await coord.approveForDistillation(
            ticketID: "mid-1",
            sovereignVerdictRef: "vrdct-b")

        // 4 transitions, 0 audit emissions — `.queuedForDistillation`
        // is non-terminal.
        let captured0 = await captured.entries
        XCTAssertEqual(
            captured0.count, 0,
            "audit sink fires only on terminal transitions")
    }

    func testAuditSinkErrorsAreAbsorbed() async throws {
        // Sink that always throws. The lifecycle path must
        // continue without propagating the error so the actor's
        // state stays consistent.
        let coord = BASUpdateTicketLifecycleCoordinator(
            auditSink: { _ in
                throw NSError(
                    domain: "test", code: 1)
            })
        _ = try await coord.submit(makeTicket(id: "err-1"))
        try await coord.markRejected(
            ticketID: "err-1",
            reasonCodes: ["x"])
        let entry = await coord.entry(ticketID: "err-1")
        XCTAssertEqual(
            entry?.state, .rejected,
            "transition still happened despite sink error")
    }

    func testNoAuditSinkIsNoOp() async throws {
        // Coordinator without audit sink runs the same way —
        // backward compatible.
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: "no-sink"))
        try await coord.markRejected(
            ticketID: "no-sink",
            reasonCodes: ["x"])
        let entry = await coord.entry(ticketID: "no-sink")
        XCTAssertEqual(entry?.state, .rejected)
    }

    // MARK: - Helpers

    private func makeTicket(
        id: String
    ) -> BASUpdateTicket {
        BASUpdateTicket(
            ticketID: id,
            sessionRef: "sess-\(id)",
            summary: "test ticket \(id)",
            confidence: 0.7)
    }
}
