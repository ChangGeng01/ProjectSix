// MARK: - BASChapter794L7StoresTests
// chapter 七百九十四 / M2621-M2625
//
// L7 unknown + contradiction ledger store tests (InMemory +
// SQLite + cross-store cold-restart equivalence)。

import XCTest
@testable import BASSovereign

final class BASChapter794L7StoresTests: XCTestCase {

    private var tempUnknownURL: URL!
    private var tempContradictionURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        let dir = FileManager.default.temporaryDirectory
        tempUnknownURL = dir.appendingPathComponent(
            "bas-test-unknown-\(UUID().uuidString).sqlite")
        tempContradictionURL = dir.appendingPathComponent(
            "bas-test-contradiction-\(UUID().uuidString).sqlite")
    }

    override func tearDown() async throws {
        for url in [tempUnknownURL, tempContradictionURL] {
            if let url = url,
               FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try await super.tearDown()
    }

    // MARK: - Unknown ledger

    func testInMemoryUnknownStoreAppendAndQuery() async throws {
        let store = BASInMemoryUnknownLedgerStore()
        let record = BASUnknownLedgerRecord(
            eventID: "u1", sessionID: "s1", turnID: "t1",
            unknownText: "decompose.low_confidence_classification",
            confidence: 0.42,
            discoveredAtMs: 1000)
        _ = try await store.appendRecord(record)
        let count = await store.count()
        XCTAssertEqual(count, 1)
        let sessRecords = await store.records(forSession: "s1")
        XCTAssertEqual(sessRecords, [record])
    }

    func testInMemoryUnknownStoreRejectsDuplicate() async throws {
        let store = BASInMemoryUnknownLedgerStore()
        let record = BASUnknownLedgerRecord(
            eventID: "u-dup", sessionID: "s", turnID: "t",
            unknownText: "x", confidence: 0.5,
            discoveredAtMs: 0)
        _ = try await store.appendRecord(record)
        do {
            _ = try await store.appendRecord(record)
            XCTFail("expected duplicate throw")
        } catch BASInMemoryUnknownLedgerStore.StoreError
            .duplicateEventID(let id) {
            XCTAssertEqual(id, "u-dup")
        }
    }

    func testSQLiteUnknownStoreColdRestart() async throws {
        let record = BASUnknownLedgerRecord(
            eventID: "u-cold", sessionID: "s-cold",
            turnID: "t-cold",
            unknownText: "decompose.low_confidence_classification",
            confidence: 0.62, discoveredAtMs: 2000)
        do {
            let store = try BASSQLiteUnknownLedgerStore(
                databaseURL: tempUnknownURL)
            _ = try await store.appendRecord(record)
        }
        let reopened = try BASSQLiteUnknownLedgerStore(
            databaseURL: tempUnknownURL)
        let count = await reopened.count()
        XCTAssertEqual(count, 1)
        let recovered = await reopened.records(
            forSession: "s-cold")
        XCTAssertEqual(recovered.count, 1)
        XCTAssertEqual(recovered[0], record)
    }

    func testSQLiteUnknownCrossMirrorWithInMemory() async throws {
        let records = [
            BASUnknownLedgerRecord(
                eventID: "u1", sessionID: "sess", turnID: "t1",
                unknownText: "x1", confidence: 0.3, discoveredAtMs: 1),
            BASUnknownLedgerRecord(
                eventID: "u2", sessionID: "sess", turnID: "t2",
                unknownText: "x2", confidence: 0.5, discoveredAtMs: 2),
            BASUnknownLedgerRecord(
                eventID: "u3", sessionID: "sess", turnID: "t3",
                unknownText: "x3", confidence: 0.7, discoveredAtMs: 3),
        ]
        let memStore = BASInMemoryUnknownLedgerStore()
        let sqlStore = try BASSQLiteUnknownLedgerStore(
            databaseURL: tempUnknownURL)
        for r in records {
            _ = try await memStore.appendRecord(r)
            _ = try await sqlStore.appendRecord(r)
        }
        let memQuery = await memStore.records(forSession: "sess")
        let sqlQuery = await sqlStore.records(forSession: "sess")
        XCTAssertEqual(memQuery, sqlQuery,
            "InMemory and SQLite must return identical records " +
            "(chapter 392 replay-determinism invariant)")
    }

    func testSQLiteUnknownRejectsDuplicate() async throws {
        let store = try BASSQLiteUnknownLedgerStore(
            databaseURL: tempUnknownURL)
        let record = BASUnknownLedgerRecord(
            eventID: "u-sql-dup", sessionID: "s", turnID: "t",
            unknownText: "x", confidence: 0.5, discoveredAtMs: 0)
        _ = try await store.appendRecord(record)
        do {
            _ = try await store.appendRecord(record)
            XCTFail("expected duplicate throw")
        } catch BASSQLiteUnknownLedgerStore.StorageError
            .duplicateEventID(let id) {
            XCTAssertEqual(id, "u-sql-dup")
        }
    }

    // MARK: - Contradiction ledger

    func testInMemoryContradictionStoreAppendAndQuery() async throws {
        let store = BASInMemoryContradictionLedgerStore()
        let record = BASContradictionLedgerRecord(
            eventID: "c1", sessionID: "s", turnID: "t",
            contradictionText: "decompose.conflict_pattern",
            salience: 0.7, confidence: 0.8,
            resolved: false, resolvedAtMs: nil)
        _ = try await store.appendRecord(record)
        let count = await store.count()
        XCTAssertEqual(count, 1)
    }

    func testInMemoryContradictionResolvedFlag() async throws {
        let store = BASInMemoryContradictionLedgerStore()
        let r1 = BASContradictionLedgerRecord(
            eventID: "c-open",
            sessionID: "s", turnID: "t1",
            contradictionText: "x", salience: 0.5,
            confidence: 0.5, resolved: false)
        let r2 = BASContradictionLedgerRecord(
            eventID: "c-closed",
            sessionID: "s", turnID: "t2",
            contradictionText: "x", salience: 0.6,
            confidence: 0.7, resolved: true,
            resolvedAtMs: 5000)
        _ = try await store.appendRecord(r1)
        _ = try await store.appendRecord(r2)
        let all = await store.records(forSession: "s")
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains { $0.eventID == "c-open" && !$0.resolved })
        XCTAssertTrue(all.contains { $0.eventID == "c-closed" && $0.resolved })
    }

    func testSQLiteContradictionColdRestart() async throws {
        let record = BASContradictionLedgerRecord(
            eventID: "c-cold", sessionID: "s-cold",
            turnID: "t-cold",
            contradictionText: "decompose.conflict_pattern",
            salience: 0.8, confidence: 0.6,
            resolved: true, resolvedAtMs: 7000)
        do {
            let store = try BASSQLiteContradictionLedgerStore(
                databaseURL: tempContradictionURL)
            _ = try await store.appendRecord(record)
        }
        let reopened = try BASSQLiteContradictionLedgerStore(
            databaseURL: tempContradictionURL)
        let recovered = await reopened.records(forTurn: "t-cold")
        XCTAssertEqual(recovered.count, 1)
        XCTAssertEqual(recovered[0], record,
            "Resolved flag + resolved_at_ms persist correctly")
    }

    func testSQLiteContradictionCrossMirrorWithInMemory() async throws {
        let records = [
            BASContradictionLedgerRecord(
                eventID: "c1", sessionID: "sess",
                turnID: "t", contradictionText: "x1",
                salience: 0.3, confidence: 0.4,
                resolved: false),
            BASContradictionLedgerRecord(
                eventID: "c2", sessionID: "sess",
                turnID: "t", contradictionText: "x2",
                salience: 0.5, confidence: 0.6,
                resolved: true, resolvedAtMs: 100),
        ]
        let memStore = BASInMemoryContradictionLedgerStore()
        let sqlStore = try BASSQLiteContradictionLedgerStore(
            databaseURL: tempContradictionURL)
        for r in records {
            _ = try await memStore.appendRecord(r)
            _ = try await sqlStore.appendRecord(r)
        }
        let memQuery = await memStore.records(forSession: "sess")
        let sqlQuery = await sqlStore.records(forSession: "sess")
        XCTAssertEqual(memQuery, sqlQuery)
    }

    // MARK: - Codable round-trip

    func testUnknownRecordCodableRoundTrip() throws {
        let record = BASUnknownLedgerRecord(
            eventID: "codable", sessionID: "s",
            turnID: "t", unknownText: "x",
            confidence: 0.42, discoveredAtMs: 12345)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(
            BASUnknownLedgerRecord.self, from: data)
        XCTAssertEqual(decoded, record)
    }

    func testContradictionRecordCodableRoundTrip() throws {
        let record = BASContradictionLedgerRecord(
            eventID: "codable", sessionID: "s",
            turnID: "t", contradictionText: "x",
            salience: 0.5, confidence: 0.6,
            resolved: true, resolvedAtMs: 99)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(
            BASContradictionLedgerRecord.self, from: data)
        XCTAssertEqual(decoded, record)
    }
}
