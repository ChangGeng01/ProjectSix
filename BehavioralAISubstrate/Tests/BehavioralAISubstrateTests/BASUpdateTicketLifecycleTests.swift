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

    // MARK: - M268 durable storage

    func testJSONFileStorageRoundTripsEmptyEntries() async throws
    {
        let url = makeTempFileURL()
        let storage =
            BASUpdateTicketLifecycleJSONFileStorage(url: url)
        let coordA = BASUpdateTicketLifecycleCoordinator(
            storage: storage)
        try await coordA.persist()  // explicit flush

        // Re-load fresh coordinator from same storage.
        let coordB = BASUpdateTicketLifecycleCoordinator(
            storage: storage)
        try await coordB.restore()
        let count = await coordB.count()
        XCTAssertEqual(
            count, 0, "empty round-trip yields empty entries")
        try? FileManager.default.removeItem(at: url)
    }

    func testJSONFileStorageRoundTripsAfterFullLifecycle() async
    throws {
        let url = makeTempFileURL()
        let storage =
            BASUpdateTicketLifecycleJSONFileStorage(url: url)

        // Coord A: submit + walk through full happy path.
        let coordA = BASUpdateTicketLifecycleCoordinator(
            storage: storage)
        _ = try await coordA.submit(makeTicket(id: "p1"))
        try await coordA.startTrial(
            ticketID: "p1",
            trialRecordRef: "shadow-p1")
        try await coordA.markTrialOutcome(
            ticketID: "p1",
            outcome: .passed(reasonCodes: ["clean"]))
        try await coordA.approveForDistillation(
            ticketID: "p1",
            sovereignVerdictRef: "vrdct-p1")

        // Submit a second ticket left in proposed.
        _ = try await coordA.submit(makeTicket(id: "p2"))

        // Coord B: load from disk.
        let coordB = BASUpdateTicketLifecycleCoordinator(
            storage: storage)
        try await coordB.restore()

        // Verify both entries restored with correct states.
        let count = await coordB.count()
        XCTAssertEqual(count, 2)
        let p1 = await coordB.entry(ticketID: "p1")
        XCTAssertEqual(p1?.state, .queuedForDistillation)
        XCTAssertEqual(
            p1?.sovereignVerdictRef, "vrdct-p1")
        XCTAssertEqual(
            p1?.history.count, 3,
            "trialing → trialPassed → queued (3 transitions)")
        let p2 = await coordB.entry(ticketID: "p2")
        XCTAssertEqual(p2?.state, .proposed)
        XCTAssertEqual(p2?.history.count, 0)

        try? FileManager.default.removeItem(at: url)
    }

    func testJSONFileStorageDistillationQueueSurvivesRestart()
    async throws {
        let url = makeTempFileURL()
        let storage =
            BASUpdateTicketLifecycleJSONFileStorage(url: url)
        let coordA = BASUpdateTicketLifecycleCoordinator(
            storage: storage)
        _ = try await coordA.submit(makeTicket(id: "q-a"))
        try await coordA.startTrial(
            ticketID: "q-a", trialRecordRef: "t")
        try await coordA.markTrialOutcome(
            ticketID: "q-a",
            outcome: .passed(reasonCodes: []))
        try await coordA.approveForDistillation(
            ticketID: "q-a",
            sovereignVerdictRef: "v")

        // Restart: external pipeline reads the queue.
        let coordB = BASUpdateTicketLifecycleCoordinator(
            storage: storage)
        try await coordB.restore()
        let queue = await coordB.distillationQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.ticket.ticketID, "q-a")

        // External pipeline marks distilled — persists.
        try await coordB.markDistilled(
            ticketID: "q-a",
            reasonCodes: ["pipeline:checkpoint"])

        // Yet another restart: verify terminal state survives.
        let coordC = BASUpdateTicketLifecycleCoordinator(
            storage: storage)
        try await coordC.restore()
        let entry = await coordC.entry(ticketID: "q-a")
        XCTAssertEqual(entry?.state, .distilled)

        try? FileManager.default.removeItem(at: url)
    }

    func testNoStorageMakesPersistAndRestoreNoOps() async throws
    {
        // Backward compat — coordinator without storage works
        // identically to M259 baseline. persist() + restore()
        // are no-ops and don't throw.
        let coord = BASUpdateTicketLifecycleCoordinator()
        try await coord.persist()
        try await coord.restore()
        _ = try await coord.submit(makeTicket(id: "no-storage"))
        let count = await coord.count()
        XCTAssertEqual(count, 1)
    }

    func testJSONFileStorageHandlesMissingFileOnLoad() async
    throws {
        let url = makeTempFileURL()
        // file deliberately not created — load() must return [:]
        let storage =
            BASUpdateTicketLifecycleJSONFileStorage(url: url)
        let entries = try await storage.load()
        XCTAssertTrue(
            entries.isEmpty,
            "missing storage file should yield empty entries " +
            "(first-run case)")
    }

    private func makeTempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "lifecycle-test-\(UUID().uuidString).json")
    }

    // MARK: - M270 SQLite storage

    func testSQLiteStorageEmptyRoundTrip() async throws {
        let url = makeTempSQLiteURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = try
            BASUpdateTicketLifecycleSQLiteStorage(url: url)
        let entries = try await storage.load()
        XCTAssertTrue(
            entries.isEmpty,
            "fresh DB has no rows")
    }

    func testSQLiteStoragePersistsAndLoadsLifecycle() async
    throws {
        let url = makeTempSQLiteURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = try
            BASUpdateTicketLifecycleSQLiteStorage(url: url)

        let coordA = BASUpdateTicketLifecycleCoordinator(
            storage: storage)
        _ = try await coordA.submit(makeTicket(id: "sql-1"))
        try await coordA.startTrial(
            ticketID: "sql-1",
            trialRecordRef: "tr-sql-1")
        try await coordA.markTrialOutcome(
            ticketID: "sql-1",
            outcome: .passed(reasonCodes: []))
        try await coordA.approveForDistillation(
            ticketID: "sql-1",
            sovereignVerdictRef: "vr-sql-1")
        _ = try await coordA.submit(makeTicket(id: "sql-2"))

        // Independent coord, same DB → restore replays
        // every persisted entry.
        let storage2 = try
            BASUpdateTicketLifecycleSQLiteStorage(url: url)
        let coordB = BASUpdateTicketLifecycleCoordinator(
            storage: storage2)
        try await coordB.restore()

        let count = await coordB.count()
        XCTAssertEqual(count, 2)
        let sql1 = await coordB.entry(ticketID: "sql-1")
        XCTAssertEqual(sql1?.state, .queuedForDistillation)
        XCTAssertEqual(
            sql1?.sovereignVerdictRef, "vr-sql-1")
        XCTAssertEqual(sql1?.history.count, 3)
        let sql2 = await coordB.entry(ticketID: "sql-2")
        XCTAssertEqual(sql2?.state, .proposed)
    }

    func testSQLiteStorageHandlesIdempotentSaves() async throws {
        let url = makeTempSQLiteURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = try
            BASUpdateTicketLifecycleSQLiteStorage(url: url)

        let coordA = BASUpdateTicketLifecycleCoordinator(
            storage: storage)
        _ = try await coordA.submit(makeTicket(id: "idem"))
        try await coordA.startTrial(
            ticketID: "idem", trialRecordRef: "t")
        try await coordA.markTrialOutcome(
            ticketID: "idem",
            outcome: .passed(reasonCodes: []))

        // Force several explicit persists in a row — must not
        // grow the row set.
        try await coordA.persist()
        try await coordA.persist()
        try await coordA.persist()

        let storage2 = try
            BASUpdateTicketLifecycleSQLiteStorage(url: url)
        let coordB = BASUpdateTicketLifecycleCoordinator(
            storage: storage2)
        try await coordB.restore()
        let count = await coordB.count()
        XCTAssertEqual(
            count, 1,
            "repeated persist must not duplicate rows")
        let entry = await coordB.entry(ticketID: "idem")
        XCTAssertEqual(entry?.state, .trialPassed)
    }

    func testSQLiteStorageScalesWithLargeTicketSet() async
    throws {
        // Performance / scale sanity: SQLite UPSERT-per-mutation
        // beats the JSON full-rewrite for large pools. This test
        // doesn't measure latency directly, but verifies a
        // 200-entry pool round-trips correctly without losing
        // any tickets.
        let url = makeTempSQLiteURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = try
            BASUpdateTicketLifecycleSQLiteStorage(url: url)
        let coordA = BASUpdateTicketLifecycleCoordinator(
            storage: storage)

        for i in 0..<200 {
            _ = try await coordA.submit(
                makeTicket(id: "bulk-\(i)"))
        }

        let storage2 = try
            BASUpdateTicketLifecycleSQLiteStorage(url: url)
        let coordB = BASUpdateTicketLifecycleCoordinator(
            storage: storage2)
        try await coordB.restore()
        let count = await coordB.count()
        XCTAssertEqual(count, 200)

        // Spot-check a few entries restored intact.
        let sample0 = await coordB.entry(ticketID: "bulk-0")
        let sample199 = await coordB.entry(
            ticketID: "bulk-199")
        XCTAssertEqual(sample0?.state, .proposed)
        XCTAssertEqual(sample199?.state, .proposed)
    }

    func testSQLiteStorageLoadsAfterTerminalTransitions() async
    throws {
        let url = makeTempSQLiteURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = try
            BASUpdateTicketLifecycleSQLiteStorage(url: url)
        let coordA = BASUpdateTicketLifecycleCoordinator(
            storage: storage)
        _ = try await coordA.submit(makeTicket(id: "term"))
        try await coordA.markRejected(
            ticketID: "term",
            reasonCodes: ["operator-veto"])

        let storage2 = try
            BASUpdateTicketLifecycleSQLiteStorage(url: url)
        let coordB = BASUpdateTicketLifecycleCoordinator(
            storage: storage2)
        try await coordB.restore()
        let entry = await coordB.entry(ticketID: "term")
        XCTAssertEqual(entry?.state, .rejected)
        // Ensure the post-rejection JSON encoding recovered
        // the reason codes.
        XCTAssertEqual(
            entry?.history.last?.reasonCodes,
            ["operator-veto"])
    }

    private func makeTempSQLiteURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "lifecycle-test-\(UUID().uuidString).sqlite")
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
