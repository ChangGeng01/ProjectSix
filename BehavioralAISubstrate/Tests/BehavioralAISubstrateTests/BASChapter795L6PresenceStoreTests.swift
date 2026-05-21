// MARK: - BASChapter795L6PresenceStoreTests
// chapter 七百九十五 / M2626-M2630
//
// L6 presence-observation store tests (InMemory + SQLite +
// cross-store cold-restart equivalence)。

import XCTest
@testable import BASSovereign

final class BASChapter795L6PresenceStoreTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        let dir = FileManager.default.temporaryDirectory
        tempURL = dir.appendingPathComponent(
            "bas-test-presence-\(UUID().uuidString).sqlite")
    }

    override func tearDown() async throws {
        if let url = tempURL,
           FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        try await super.tearDown()
    }

    // MARK: - In-memory basics

    func testInMemoryAppendAndQueryBySession() async throws {
        let store = BASInMemoryPresenceObservationStore()
        let record = BASPresenceObservationRecord(
            eventID: "p1", sessionID: "s",
            turnID: "t", channelKind: "task",
            salience: 0.7, confidence: 0.9,
            observedAtMs: 100)
        _ = try await store.appendRecord(record)
        let count = await store.count()
        XCTAssertEqual(count, 1)
        let sessRecords = await store.records(forSession: "s")
        XCTAssertEqual(sessRecords, [record])
    }

    func testInMemoryQueryByChannel() async throws {
        let store = BASInMemoryPresenceObservationStore()
        try await [
            BASPresenceObservationRecord(
                eventID: "p1", sessionID: "s", turnID: "t",
                channelKind: "task", salience: 0.5,
                confidence: 0.5, observedAtMs: 1),
            BASPresenceObservationRecord(
                eventID: "p2", sessionID: "s", turnID: "t",
                channelKind: "risk", salience: 0.7,
                confidence: 0.7, observedAtMs: 2),
            BASPresenceObservationRecord(
                eventID: "p3", sessionID: "s", turnID: "t",
                channelKind: "task", salience: 0.6,
                confidence: 0.6, observedAtMs: 3),
        ].forEachAsync { record in
            _ = try await store.appendRecord(record)
        }
        let taskRecords = await store.records(forChannel: "task")
        XCTAssertEqual(taskRecords.count, 2)
        XCTAssertEqual(taskRecords.map { $0.eventID }, ["p1", "p3"])
    }

    func testInMemoryRejectsDuplicate() async throws {
        let store = BASInMemoryPresenceObservationStore()
        let record = BASPresenceObservationRecord(
            eventID: "p-dup", sessionID: "s", turnID: "t",
            channelKind: "task", salience: 0.5,
            confidence: 0.5, observedAtMs: 0)
        _ = try await store.appendRecord(record)
        do {
            _ = try await store.appendRecord(record)
            XCTFail("expected duplicate throw")
        } catch BASInMemoryPresenceObservationStore.StoreError
            .duplicateEventID(let id) {
            XCTAssertEqual(id, "p-dup")
        }
    }

    // MARK: - SQLite cold-restart

    func testSQLiteColdRestart() async throws {
        let records = [
            BASPresenceObservationRecord(
                eventID: "p1", sessionID: "sess-cold",
                turnID: "t1", channelKind: "task",
                salience: 0.5, confidence: 0.8,
                observedAtMs: 100),
            BASPresenceObservationRecord(
                eventID: "p2", sessionID: "sess-cold",
                turnID: "t1", channelKind: "manipulation",
                salience: 0.9, confidence: 0.95,
                observedAtMs: 200),
        ]
        do {
            let store = try BASSQLitePresenceObservationStore(
                databaseURL: tempURL)
            for r in records {
                _ = try await store.appendRecord(r)
            }
        }
        let reopened = try BASSQLitePresenceObservationStore(
            databaseURL: tempURL)
        let recovered = await reopened.records(
            forSession: "sess-cold")
        XCTAssertEqual(recovered, records,
            "Cold restart preserves records insertion-order")
    }

    func testSQLiteCrossMirrorWithInMemory() async throws {
        var records: [BASPresenceObservationRecord] = []
        for i in 1...5 {
            records.append(BASPresenceObservationRecord(
                eventID: "p\(i)", sessionID: "sess",
                turnID: "t", channelKind: "task",
                salience: Double(i) * 0.1,
                confidence: 0.5,
                observedAtMs: Int64(i * 10)))
        }
        let memStore = BASInMemoryPresenceObservationStore()
        let sqlStore = try BASSQLitePresenceObservationStore(
            databaseURL: tempURL)
        for r in records {
            _ = try await memStore.appendRecord(r)
            _ = try await sqlStore.appendRecord(r)
        }
        let memQuery = await memStore.records(forSession: "sess")
        let sqlQuery = await sqlStore.records(forSession: "sess")
        XCTAssertEqual(memQuery, sqlQuery)
    }

    func testSQLiteChannelFilter() async throws {
        let store = try BASSQLitePresenceObservationStore(
            databaseURL: tempURL)
        for (i, ch) in ["task", "risk", "task", "manipulation"].enumerated() {
            _ = try await store.appendRecord(
                BASPresenceObservationRecord(
                    eventID: "p\(i)", sessionID: "s",
                    turnID: "t", channelKind: ch,
                    salience: 0.5, confidence: 0.5,
                    observedAtMs: Int64(i)))
        }
        let taskRecords = await store.records(forChannel: "task")
        XCTAssertEqual(taskRecords.count, 2)
        let riskRecords = await store.records(forChannel: "risk")
        XCTAssertEqual(riskRecords.count, 1)
    }

    func testSQLiteRejectsInvalidChannelKind() async throws {
        let store = try BASSQLitePresenceObservationStore(
            databaseURL: tempURL)
        // Schema 013 CHECK pins channel_kind to 5 values。
        // "invalid_channel" violates the constraint → throw。
        // Note:SQLite returns SQLITE_CONSTRAINT for both PRIMARY
        // KEY collisions and CHECK violations。 Our SQLite store
        // maps the broad SQLITE_CONSTRAINT to duplicateEventID
        // since the common case is PK collisions;CHECK
        // violations come through as the same error type but
        // are EXPECTED throws regardless。 Test just asserts
        // SOME throw — the CHECK behavior is verified at the
        // schema level (chapter 七百六十七 schema tests pin the
        // CHECK pattern in the SQL string)。
        var didThrow = false
        do {
            _ = try await store.appendRecord(
                BASPresenceObservationRecord(
                    eventID: "p-bad", sessionID: "s",
                    turnID: "t",
                    channelKind: "invalid_channel",
                    salience: 0.5, confidence: 0.5,
                    observedAtMs: 0))
        } catch {
            didThrow = true
        }
        XCTAssertTrue(didThrow,
            "Invalid channel_kind must throw (CHECK constraint)")
    }

    // MARK: - Codable

    func testRecordCodableRoundTrip() throws {
        let record = BASPresenceObservationRecord(
            eventID: "codable", sessionID: "s",
            turnID: "t", channelKind: "bodyRhythm",
            salience: 0.42, confidence: 0.84,
            observedAtMs: 99)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(
            BASPresenceObservationRecord.self, from: data)
        XCTAssertEqual(decoded, record)
    }
}

// MARK: - Async-iter convenience

private extension Array {
    func forEachAsync(
        _ body: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await body(element)
        }
    }
}
