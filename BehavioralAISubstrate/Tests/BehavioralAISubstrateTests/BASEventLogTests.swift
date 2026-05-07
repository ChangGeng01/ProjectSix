// MARK: - BASEventLogTests — chapter 三百五四 / M841
//
// Test coverage for G1 deliverable from chapter 三百五三 / M840
// roadmap:
//   - BASEventLogEntry Codable round-trip + clamp invariants
//   - BASInMemoryEventLogStorage append + idempotent retry +
//     session ordering + timestamp filter + count
//   - BASSQLiteEventLogStorage same contract + cross-session
//     persistence (the architectural pin from chapter 二百四十八
//     M735 doctrine)
//   - BASEventReplayRunner reducer fold + skip semantics +
//     per-session order

import XCTest
@testable import BASRuntimeCore

final class BASEventLogTests: XCTestCase {

    // MARK: - Test fixtures

    private var tempURL: URL?

    override func setUpWithError() throws {
        tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-eventlog-test-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-shm"))
        }
    }

    private func makeEntry(
        eventID: String = UUID().uuidString,
        timestampMs: Int64 = 1_700_000_000_000,
        kind: BASEventLogKind = .chat,
        sessionID: String = "test-session",
        sequenceNumber: Int64 = 0,
        riskBand: BASEventLogRiskBand = .low,
        confidence: Double = 0.85,
        memoryRefs: [String] = []
    ) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: eventID,
            timestampMs: timestampMs,
            kind: kind,
            sessionID: sessionID,
            sequenceNumber: sequenceNumber,
            source: "test-source",
            turnRef: "turn-1",
            rawInputDigest: "sha256:abc123",
            intent: "ask_question",
            emotion: "calm",
            riskBand: riskBand,
            project: "test-project",
            memoryRefs: memoryRefs,
            stateBeforeID: nil,
            stateAfterID: nil,
            actions: ["permit:answer"],
            confidence: confidence,
            payloadJson: nil)
    }

    // MARK: - BASEventLogEntry shape + invariants

    func testEntryConfidenceClampsAboveOne() {
        let entry = makeEntry(confidence: 1.5)
        XCTAssertEqual(
            entry.confidence, 1.0,
            "confidence > 1 must clamp to 1.0")
    }

    func testEntryConfidenceClampsBelowZero() {
        let entry = makeEntry(confidence: -0.5)
        XCTAssertEqual(
            entry.confidence, 0.0,
            "negative confidence must clamp to 0.0")
    }

    func testEntryCodableRoundTrip() throws {
        let original = makeEntry(memoryRefs: ["mem-1", "mem-2"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASEventLogEntry.self, from: data)
        XCTAssertEqual(decoded, original,
            "Codable must round-trip all fields")
    }

    func testEntryKindRawValueStability() {
        // Pin raw values for grep-friendliness across BAS audit
        XCTAssertEqual(
            BASEventLogKind.chat.rawValue, "chat")
        XCTAssertEqual(
            BASEventLogKind.toolInvocation.rawValue,
            "tool-invocation")
        XCTAssertEqual(
            BASEventLogKind.substrateAudit.rawValue,
            "substrate-audit")
        XCTAssertEqual(
            BASEventLogKind.sessionLifecycle.rawValue,
            "session-lifecycle")
    }

    func testEntryRiskBandRawValueStability() {
        XCTAssertEqual(
            BASEventLogRiskBand.low.rawValue, "low")
        XCTAssertEqual(
            BASEventLogRiskBand.medium.rawValue, "medium")
        XCTAssertEqual(
            BASEventLogRiskBand.high.rawValue, "high")
        XCTAssertEqual(
            BASEventLogRiskBand.unknown.rawValue, "unknown")
    }

    // MARK: - BASInMemoryEventLogStorage

    func testInMemoryAppendAssignsSequenceNumber() async throws {
        let store = BASInMemoryEventLogStorage()
        let entry = makeEntry(sequenceNumber: 999)  // ignored
        let result = try await store.append(entry)
        XCTAssertTrue(result.wasNew)
        XCTAssertEqual(
            result.assignedSequenceNumber, 0,
            "First event in session must get sequenceNumber=0 " +
            "regardless of caller's input value")
    }

    func testInMemoryAppendIsIdempotent() async throws {
        let store = BASInMemoryEventLogStorage()
        let entry = makeEntry(eventID: "fixed-id")
        let first = try await store.append(entry)
        let second = try await store.append(entry)
        XCTAssertTrue(first.wasNew)
        XCTAssertFalse(
            second.wasNew,
            "Re-appending same eventID must return wasNew=false")
        XCTAssertEqual(
            second.assignedSequenceNumber,
            first.assignedSequenceNumber,
            "Idempotent retry must return original seq number")
        let count = await store.totalCount
        XCTAssertEqual(count, 1,
            "Idempotent retry must not duplicate the row")
    }

    func testInMemorySessionOrderingPreserved() async throws {
        let store = BASInMemoryEventLogStorage()
        for i in 0..<5 {
            _ = try await store.append(makeEntry(
                eventID: "evt-\(i)",
                timestampMs: 1_700_000_000_000 + Int64(i),
                sessionID: "ssn-A"))
        }
        let events = await store.events(forSession: "ssn-A")
        XCTAssertEqual(events.count, 5)
        for (idx, event) in events.enumerated() {
            XCTAssertEqual(event.sequenceNumber, Int64(idx),
                "Events for session must be sequence-ordered")
            XCTAssertEqual(event.eventID, "evt-\(idx)")
        }
    }

    func testInMemoryMultipleSessionsTrackSeparateSequences()
        async throws
    {
        let store = BASInMemoryEventLogStorage()
        _ = try await store.append(makeEntry(
            eventID: "a-1", sessionID: "ssn-A"))
        _ = try await store.append(makeEntry(
            eventID: "b-1", sessionID: "ssn-B"))
        _ = try await store.append(makeEntry(
            eventID: "a-2", sessionID: "ssn-A"))
        let aEvents = await store.events(forSession: "ssn-A")
        let bEvents = await store.events(forSession: "ssn-B")
        XCTAssertEqual(aEvents.map { $0.sequenceNumber },
            [0, 1])
        XCTAssertEqual(bEvents.map { $0.sequenceNumber }, [0])
    }

    func testInMemorySinceTimestampFilter() async throws {
        let store = BASInMemoryEventLogStorage()
        for i in 0..<10 {
            _ = try await store.append(makeEntry(
                eventID: "evt-\(i)",
                timestampMs: 1_000 + Int64(i)))
        }
        let recent = await store.events(
            sinceTimestampMs: 1_005, limit: 100)
        XCTAssertEqual(recent.count, 5,
            "since-timestamp filter must include only " +
            "events at or after the threshold")
    }

    func testInMemorySinceTimestampLimitApplied() async throws {
        let store = BASInMemoryEventLogStorage()
        for i in 0..<20 {
            _ = try await store.append(makeEntry(
                eventID: "evt-\(i)",
                timestampMs: 1_000 + Int64(i)))
        }
        let limited = await store.events(
            sinceTimestampMs: 0, limit: 7)
        XCTAssertEqual(limited.count, 7,
            "limit must cap result count")
    }

    // MARK: - BASSQLiteEventLogStorage

    func testSQLiteOpenCreatesSchema() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        let count = await store.totalCount
        XCTAssertEqual(count, 0,
            "Fresh SQLite store must have 0 events")
    }

    func testSQLiteAppendThenFetch() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        let entry = makeEntry(
            eventID: "sqlite-test-1",
            sessionID: "ssn-sqlite")
        let result = try await store.append(entry)
        XCTAssertTrue(result.wasNew)
        let events = await store.events(
            forSession: "ssn-sqlite")
        XCTAssertEqual(events.count, 1)
        let fetched = try XCTUnwrap(events.first)
        XCTAssertEqual(fetched.eventID, "sqlite-test-1")
        XCTAssertEqual(fetched.sequenceNumber, 0)
    }

    func testSQLiteIdempotentRetry() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        let entry = makeEntry(eventID: "dup-test")
        _ = try await store.append(entry)
        let second = try await store.append(entry)
        XCTAssertFalse(second.wasNew,
            "SQLite store must honor idempotent retry contract")
        let count = await store.totalCount
        XCTAssertEqual(count, 1)
    }

    /// **Architectural pin** — chapter 二百四十八 M735 doctrine:
    /// SQLite-backed storage MUST preserve byte-equal semantics
    /// across process / actor restart. This test closes + reopens
    /// the store and verifies the events read back identical.
    func testSQLiteCrossSessionPersistence() async throws {
        let url = try XCTUnwrap(tempURL)
        let original: [BASEventLogEntry]
        do {
            let store = try BASSQLiteEventLogStorage(
                databaseURL: url)
            for i in 0..<5 {
                _ = try await store.append(makeEntry(
                    eventID: "persist-\(i)",
                    timestampMs: 1_000_000 + Int64(i),
                    sessionID: "persist-ssn"))
            }
            original = await store.events(
                forSession: "persist-ssn")
        }
        // First store deinits here -> sqlite3_close_v2 fires
        let reopened = try BASSQLiteEventLogStorage(
            databaseURL: url)
        let restored = await reopened.events(
            forSession: "persist-ssn")
        XCTAssertEqual(
            restored, original,
            "Events must round-trip byte-equal across " +
            "process restart (chapter 二百四十八 M735 idiom)")
    }

    func testSQLiteSchemaVersionPin() {
        XCTAssertEqual(
            BASSQLiteEventLogStorage.schemaVersion, 1,
            "Schema version pin: bump triggers explicit migration " +
            "review for any production event_log databases on disk")
    }

    // MARK: - M896 retention policy (chapter 三百九七)

    func testM896InMemoryPruneRemovesOldEvents() async throws {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<5 {
            _ = try await log.append(BASEventLogEntry(
                eventID: "e\(i)",
                timestampMs: Int64(1_000 + i * 100),
                kind: .substrateAudit,
                sessionID: "s",
                sequenceNumber: 0))
        }
        let countBefore = await log.totalCount
        XCTAssertEqual(countBefore, 5)
        // Cutoff at 1300 → remove e0 (1000), e1 (1100),
        // e2 (1200) → 3 events removed
        let removed = try await log.pruneEventsBefore(
            timestampMs: 1_300)
        XCTAssertEqual(removed, 3)
        let countAfter = await log.totalCount
        XCTAssertEqual(countAfter, 2)
        // Surviving events (e3 + e4) still queryable
        let survivors = await log.events(
            forSession: "s")
        XCTAssertEqual(
            survivors.map { $0.eventID }, ["e3", "e4"])
    }

    func testM896InMemoryPruneIdempotentOnRePrune()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(BASEventLogEntry(
            eventID: "e0",
            timestampMs: 100,
            kind: .substrateAudit,
            sessionID: "s",
            sequenceNumber: 0))
        let first = try await log.pruneEventsBefore(
            timestampMs: 50)
        XCTAssertEqual(first, 0,
            "No events older than cutoff → 0 removed")
        let second = try await log.pruneEventsBefore(
            timestampMs: 50)
        XCTAssertEqual(second, 0, "Idempotent on re-prune")
    }

    func testM896SQLitePruneRemovesOldEvents()
        async throws
    {
        let url = try XCTUnwrap(tempURL)
        let log = try BASSQLiteEventLogStorage(
            databaseURL: url)
        for i in 0..<5 {
            _ = try await log.append(BASEventLogEntry(
                eventID: "e\(i)",
                timestampMs: Int64(1_000 + i * 100),
                kind: .substrateAudit,
                sessionID: "s",
                sequenceNumber: 0))
        }
        let removed = try await log.pruneEventsBefore(
            timestampMs: 1_300)
        XCTAssertEqual(removed, 3,
            "SQLite prune removes 3 events (e0/e1/e2)")
        let count = await log.totalCount
        XCTAssertEqual(count, 2)
    }

    func testM896RetentionPolicyCutoffComputation() {
        let policy = BASEventLogRetentionPolicy(
            maxAgeSec: 3_600)  // 1h
        let nowMs: Int64 = 10_000_000
        let cutoff = policy.cutoff(nowMs: nowMs)
        // 1h = 3600 sec = 3_600_000 ms
        XCTAssertEqual(cutoff, 10_000_000 - 3_600_000)
    }

    func testM896RetentionPolicyZeroAgeMeansNoCutoff() {
        let policy = BASEventLogRetentionPolicy(
            maxAgeSec: 0)
        XCTAssertEqual(
            policy.cutoff(nowMs: 1_000_000), 0,
            "maxAgeSec=0 means retain everything → cutoff=0")
    }

    func testM896RetentionPolicyPresets() {
        XCTAssertEqual(
            BASEventLogRetentionPolicy.last24Hours.maxAgeSec,
            24 * 3600)
        XCTAssertEqual(
            BASEventLogRetentionPolicy.last24Hours
                .pruneCadenceSec, 3600)
        XCTAssertEqual(
            BASEventLogRetentionPolicy.lastWeek.maxAgeSec,
            7 * 24 * 3600)
    }

    func testM896RetentionPolicyMinCadenceClamp() {
        // Pin:cadence < 60 sec gets clamped up to 60
        // (prevents host from creating a tight loop that
        // hammers the DB with prune calls)
        let policy = BASEventLogRetentionPolicy(
            maxAgeSec: 100,
            pruneCadenceSec: 1)
        XCTAssertEqual(policy.pruneCadenceSec, 60)
    }

    // MARK: - BASEventReplayRunner

    func testReplaySessionFoldsEvents() async throws {
        let store = BASInMemoryEventLogStorage()
        for i in 0..<10 {
            _ = try await store.append(makeEntry(
                eventID: "fold-\(i)",
                timestampMs: 1_000 + Int64(i),
                sessionID: "fold-ssn",
                confidence: 0.5))
        }
        let result = await BASEventReplayRunner
            .replaySession(
                storage: store,
                sessionID: "fold-ssn",
                initial: 0.0
            ) { acc, event in
                acc + event.confidence
            }
        XCTAssertEqual(
            result.finalState, 5.0, accuracy: 1e-9,
            "Reducer fold over 10 × 0.5 must equal 5.0")
        XCTAssertEqual(result.eventsConsumed, 10)
        XCTAssertEqual(result.eventsSkipped, 0)
        XCTAssertEqual(result.lastConsumedSequence, 9)
    }

    func testReplaySkipsEventsWhenReducerReturnsNil()
        async throws
    {
        let store = BASInMemoryEventLogStorage()
        for i in 0..<10 {
            _ = try await store.append(makeEntry(
                eventID: "skip-\(i)",
                timestampMs: 1_000 + Int64(i),
                sessionID: "skip-ssn",
                riskBand: i % 2 == 0 ? .low : .high))
        }
        // Reducer counts only .low events; .high → nil (skip)
        let result = await BASEventReplayRunner
            .replaySession(
                storage: store,
                sessionID: "skip-ssn",
                initial: 0
            ) { acc, event in
                event.riskBand == .low ? acc + 1 : nil
            }
        XCTAssertEqual(result.finalState, 5,
            "5 of 10 events should be consumed (.low only)")
        XCTAssertEqual(result.eventsConsumed, 5)
        XCTAssertEqual(result.eventsSkipped, 5)
    }

    func testReplayEmptySessionReturnsInitial() async {
        let store = BASInMemoryEventLogStorage()
        let result = await BASEventReplayRunner
            .replaySession(
                storage: store,
                sessionID: "nonexistent",
                initial: "init"
            ) { _, _ in "should-not-be-called" }
        XCTAssertEqual(result.finalState, "init")
        XCTAssertEqual(result.eventsConsumed, 0)
        XCTAssertEqual(result.eventsSkipped, 0)
        XCTAssertNil(result.lastConsumedSequence)
    }

    func testReplaySinceTimestampRange() async throws {
        let store = BASInMemoryEventLogStorage()
        for i in 0..<10 {
            _ = try await store.append(makeEntry(
                eventID: "ts-\(i)",
                timestampMs: 1_000 + Int64(i),
                sessionID: "ts-ssn"))
        }
        let result = await BASEventReplayRunner.replay(
            storage: store,
            range: .sinceTimestamp(
                sinceMs: 1_005, limit: 100),
            initial: 0
        ) { acc, _ in acc + 1 }
        XCTAssertEqual(result.finalState, 5,
            "Events at ts >= 1005: ts=1005..1009 = 5 events")
        XCTAssertEqual(result.eventsConsumed, 5)
    }

    // MARK: - In-memory + SQLite contract parity

    /// Both conformers must produce identical results for the
    /// same input sequence (chapter 二百一一 single-source-of-truth
    /// — the protocol is the contract,both conformers obey)。
    func testInMemoryAndSQLiteContractParity() async throws {
        let url = try XCTUnwrap(tempURL)
        let memStore = BASInMemoryEventLogStorage()
        let sqlStore = try BASSQLiteEventLogStorage(
            databaseURL: url)
        let entries = (0..<5).map { i in
            makeEntry(
                eventID: "parity-\(i)",
                timestampMs: 1_000 + Int64(i),
                sessionID: "parity-ssn")
        }
        for entry in entries {
            _ = try await memStore.append(entry)
            _ = try await sqlStore.append(entry)
        }
        let memEvents = await memStore.events(
            forSession: "parity-ssn")
        let sqlEvents = await sqlStore.events(
            forSession: "parity-ssn")
        XCTAssertEqual(memEvents, sqlEvents,
            "In-memory + SQLite must produce byte-equal " +
            "results for the same input sequence")
    }
}
