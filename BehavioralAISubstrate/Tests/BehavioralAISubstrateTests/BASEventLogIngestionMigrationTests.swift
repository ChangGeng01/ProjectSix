import Foundation
import SQLite3
import XCTest
@testable import BASRuntimeCore
@testable import BASMemory

final class BASEventLogIngestionMigrationTests: XCTestCase {
    private final class CloseCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        func increment() {
            lock.lock()
            value += 1
            lock.unlock()
        }

        func read() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    private func temporaryDatabase(_ name: String) throws -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-event-ingestion-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, directory.appendingPathComponent(name))
    }

    private func withDatabase<T>(
        _ url: URL,
        flags: Int32 = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
        _ body: (OpaquePointer) throws -> T
    ) throws -> T {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(url.path, &db, flags, nil)
        guard rc == SQLITE_OK, let db else {
            if let db { sqlite3_close_v2(db) }
            throw NSError(domain: "SQLiteTest", code: Int(rc))
        }
        defer { sqlite3_close_v2(db) }
        return try body(db)
    }

    private func exec(_ url: URL, _ sql: String) throws {
        try withDatabase(url) { db in
            var message: UnsafeMutablePointer<CChar>?
            let rc = sqlite3_exec(db, sql, nil, nil, &message)
            guard rc == SQLITE_OK else {
                let text = message.map { String(cString: $0) } ?? "rc=\(rc)"
                if let message { sqlite3_free(message) }
                throw NSError(
                    domain: "SQLiteTest", code: Int(rc),
                    userInfo: [NSLocalizedDescriptionKey: text])
            }
        }
    }

    private func scalarInt(_ url: URL, _ sql: String) throws -> Int64 {
        try withDatabase(url, flags: SQLITE_OPEN_READONLY) { db in
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
                  let stmt else { throw NSError(domain: "SQLiteTest", code: 1) }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else {
                throw NSError(domain: "SQLiteTest", code: 2)
            }
            return sqlite3_column_int64(stmt, 0)
        }
    }

    private func scalarText(_ url: URL, _ sql: String) throws -> String {
        try withDatabase(url, flags: SQLITE_OPEN_READONLY) { db in
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
                  let stmt else { throw NSError(domain: "SQLiteTest", code: 3) }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW,
                  let text = sqlite3_column_text(stmt, 0) else {
                throw NSError(domain: "SQLiteTest", code: 4)
            }
            return String(cString: text)
        }
    }

    private func entry(_ id: String, timestampMs: Int64, session: String = "s") -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: id,
            timestampMs: timestampMs,
            kind: .substrateAudit,
            sessionID: session,
            sequenceNumber: 0,
            actions: ["retain-test"])
    }

    private func openThenRelease(
        _ url: URL,
        nowMs: @escaping @Sendable () -> Int64,
        observer: @escaping @Sendable () -> Void
    ) async throws {
        var store: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(
            databaseURL: url, nowMs: nowMs, closeObserver: observer)
        let count = try await store?.totalCountOrThrow()
        XCTAssertEqual(count, 2)
        store = nil
    }

    func testV2MigrationRollsBackLateFailureClosesExactlyOnceAndNeverRestamps() async throws {
        let (directory, url) = try temporaryDatabase("migration.sqlite")
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        let json = try String(
            data: JSONEncoder().encode(BASEventLogEntry(
                eventID: "json",
                timestampMs: 1,
                kind: .chat,
                sessionID: "s",
                sequenceNumber: 0,
                actions: ["legacy-json"])),
            encoding: .utf8)!
        let actions = try String(
            data: JSONEncoder().encode(["legacy-action"]), encoding: .utf8)!
        let memoryRefs = try String(
            data: JSONEncoder().encode(["legacy-ref"]), encoding: .utf8)!
        let envelope = try String(
            data: JSONEncoder().encode([
                "actions": actions,
                "confidence": "0.75",
                "emotion": "legacy-emotion",
                "intent": "legacy-intent",
                "memoryRefs": memoryRefs,
                "payloadJson": "{\"inner\":true}",
                "project": "legacy-project",
                "rawInputDigest": "legacy-digest",
                "riskBand": "medium",
                "source": "legacy-source",
                "stateAfterID": "after",
                "stateBeforeID": "before",
            ]), encoding: .utf8)!
        let binary = try BASEventLogBinaryCodec.encode(BASBinaryEventLogEntry(
            entryID: "blob",
            kind: .hostInput,
            sessionRef: "s",
            turnRef: "legacy-turn",
            timestampMs: 2,
            payloadJson: envelope))
        let binaryHex = binary.map { String(format: "%02X", $0) }.joined()
        try exec(url, """
            PRAGMA user_version=2;
            CREATE TABLE event_log (
              event_id TEXT PRIMARY KEY NOT NULL, session_id TEXT NOT NULL,
              sequence_number INTEGER NOT NULL, timestamp_ms INTEGER NOT NULL,
              kind TEXT NOT NULL, risk_band TEXT NOT NULL, payload_json TEXT NOT NULL,
              payload_format INTEGER NOT NULL DEFAULT 1, payload_blob BLOB
            );
            INSERT INTO event_log VALUES ('json','s',0,1,'chat','low','\(json)',1,NULL);
            INSERT INTO event_log VALUES ('blob','s',1,2,'chat','medium','',2,X'\(binaryHex)');
            CREATE TRIGGER abort_ingestion_backfill BEFORE UPDATE ON event_log
            BEGIN SELECT RAISE(ABORT, 'abort ingestion backfill'); END;
            """)

        let closes = CloseCounter()
        XCTAssertThrowsError(try BASSQLiteEventLogStorage(
            databaseURL: url, nowMs: { 1_234 }, closeObserver: closes.increment))
        XCTAssertEqual(closes.read(), 1)
        XCTAssertEqual(try scalarInt(url, "PRAGMA user_version"), 2)
        XCTAssertEqual(
            try scalarInt(url, "SELECT count(*) FROM pragma_table_info('event_log') WHERE name='ingested_at_ms'"),
            0)
        XCTAssertEqual(try scalarText(url, "SELECT payload_json FROM event_log WHERE event_id='json'"), json)
        XCTAssertEqual(try scalarText(url, "SELECT hex(payload_blob) FROM event_log WHERE event_id='blob'"), binaryHex)

        try exec(url, "DROP TRIGGER abort_ingestion_backfill")
        try await openThenRelease(url, nowMs: { 1_234 }, observer: closes.increment)
        XCTAssertEqual(closes.read(), 2)
        XCTAssertEqual(try scalarInt(url, "PRAGMA user_version"), 3)
        XCTAssertEqual(try scalarInt(url, "SELECT min(ingested_at_ms) FROM event_log"), 1_234)
        XCTAssertEqual(try scalarInt(url, "SELECT max(ingested_at_ms) FROM event_log"), 1_234)
        XCTAssertEqual(try scalarText(url, "SELECT payload_json FROM event_log WHERE event_id='json'"), json)
        XCTAssertEqual(try scalarText(url, "SELECT hex(payload_blob) FROM event_log WHERE event_id='blob'"), binaryHex)

        try await openThenRelease(url, nowMs: { 9_999 }, observer: closes.increment)
        XCTAssertEqual(closes.read(), 3)
        XCTAssertEqual(try scalarInt(url, "SELECT max(ingested_at_ms) FROM event_log"), 1_234)

        var decodedStore: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(
            databaseURL: url, nowMs: { 99_999 }, closeObserver: closes.increment)
        let decoded = try await decodedStore?.eventsOrThrow(forSession: "s")
        let migratedBinary = try XCTUnwrap(decoded?.first { $0.eventID == "blob" })
        XCTAssertEqual(migratedBinary.timestampMs, 2)
        XCTAssertEqual(migratedBinary.sequenceNumber, 1)
        XCTAssertEqual(migratedBinary.turnRef, "legacy-turn")
        XCTAssertEqual(migratedBinary.source, "legacy-source")
        XCTAssertEqual(migratedBinary.intent, "legacy-intent")
        XCTAssertEqual(migratedBinary.emotion, "legacy-emotion")
        XCTAssertEqual(migratedBinary.riskBand, .medium)
        XCTAssertEqual(migratedBinary.project, "legacy-project")
        XCTAssertEqual(migratedBinary.memoryRefs, ["legacy-ref"])
        XCTAssertEqual(migratedBinary.stateBeforeID, "before")
        XCTAssertEqual(migratedBinary.stateAfterID, "after")
        XCTAssertEqual(migratedBinary.actions, ["legacy-action"])
        XCTAssertEqual(migratedBinary.confidence, 0.75)
        XCTAssertEqual(migratedBinary.payloadJson, "{\"inner\":true}")
        decodedStore = nil
        XCTAssertEqual(closes.read(), 4)
    }

    func testInvalidAndLegacyNullIngestionMetadataAreRetained() async throws {
        let (directory, url) = try temporaryDatabase("invalid-metadata.sqlite")
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        let clock = BASEventLogTestClock(1_000)
        let store = try BASSQLiteEventLogStorage(databaseURL: url, nowMs: clock.now)
        _ = try await store.append(entry("valid-old", timestampMs: 1))
        try exec(url, """
            INSERT INTO event_log(event_id,session_id,sequence_number,timestamp_ms,kind,risk_band,payload_json,payload_format,payload_blob,ingested_at_ms)
            VALUES ('legacy-null','s',1,1,'chat','low','{}',1,NULL,NULL);
            INSERT INTO event_log(event_id,session_id,sequence_number,timestamp_ms,kind,risk_band,payload_json,payload_format,payload_blob,ingested_at_ms)
            VALUES ('invalid-negative','s',2,1,'chat','low','{}',1,NULL,-1);
            INSERT INTO event_log(event_id,session_id,sequence_number,timestamp_ms,kind,risk_band,payload_json,payload_format,payload_blob,ingested_at_ms)
            VALUES ('invalid-real','s',3,1,'chat','low','{}',1,NULL,1.5);
            """)
        clock.advance(by: 259_200_001)
        let removed = try await store.pruneEventsBefore(timestampMs: 50)
        let count = try await store.totalCountOrThrow()
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(count, 3)
        XCTAssertEqual(
            try scalarText(url, "SELECT group_concat(event_id, ',') FROM (SELECT event_id FROM event_log ORDER BY sequence_number)"),
            "legacy-null,invalid-negative,invalid-real")
    }

    func testChainedNonmonotoneInteriorRetentionAndDeleteRollback() async throws {
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = true
        defer { BASSQLiteEventLogStorage.rowIntegrityChainEnabled = false }
        let (directory, url) = try temporaryDatabase("chain.sqlite")
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        let clock = BASEventLogTestClock(1_000)
        let store = try BASSQLiteEventLogStorage(databaseURL: url, nowMs: clock.now)
        for (index, timestamp) in [100, 1, 100].enumerated() {
            _ = try await store.append(entry("chain-\(index)", timestampMs: Int64(timestamp)))
        }
        clock.advance(by: 259_200_001)
        let prefixRemoved = try await store.pruneEventsBefore(timestampMs: 50)
        let prefixCount = try await store.totalCountOrThrow()
        XCTAssertEqual(prefixRemoved, 0)
        XCTAssertEqual(prefixCount, 3)
        try await store.verifyIntegrityChain(forSession: "s")

        let rollbackURL = directory.appendingPathComponent("rollback.sqlite")
        let rollbackClock = BASEventLogTestClock(1_000)
        let rollbackStore = try BASSQLiteEventLogStorage(
            databaseURL: rollbackURL, nowMs: rollbackClock.now)
        _ = try await rollbackStore.append(entry("rollback-0", timestampMs: 1, session: "r"))
        _ = try await rollbackStore.append(entry("rollback-1", timestampMs: 2, session: "r"))
        rollbackClock.advance(by: 259_200_001)
        try exec(rollbackURL, """
            CREATE TRIGGER abort_event_delete BEFORE DELETE ON event_log
            BEGIN SELECT RAISE(ABORT, 'abort event delete'); END;
            """)
        do {
            _ = try await rollbackStore.pruneEventsBefore(timestampMs: 50)
            XCTFail("the aborting DELETE trigger must fail the prune")
        } catch {}
        let countAfterRollback = try await rollbackStore.totalCountOrThrow()
        XCTAssertEqual(countAfterRollback, 2)
        XCTAssertEqual(try scalarInt(rollbackURL, "SELECT count(*) FROM event_log_integrity"), 2)
        try await rollbackStore.verifyIntegrityChain(forSession: "r")

        try exec(rollbackURL, "DROP TRIGGER abort_event_delete")
        let removedAfterRetry = try await rollbackStore.pruneEventsBefore(timestampMs: 50)
        XCTAssertEqual(removedAfterRetry, 2)
        XCTAssertEqual(try scalarInt(rollbackURL, "SELECT count(*) FROM event_log_integrity"), 0)
        try await rollbackStore.verifyIntegrityChain(forSession: "r")
    }

    func testSwiftRustMigrationDirectionsAndProductionOldABIStamp() async throws {
        let (directory, rustURL) = try temporaryDatabase("rust-first.sqlite")
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }

        var rustFirst: BASRoutedEventLogStorage? = try BASRoutedEventLogStorage(
            databaseURL: rustURL, nowMs: { 1_111 })
        _ = try await rustFirst?.append(entry("rust-first", timestampMs: 1))
        rustFirst = nil
        XCTAssertEqual(try scalarInt(rustURL, "PRAGMA user_version"), 0)
        XCTAssertEqual(try scalarInt(rustURL, "SELECT ingested_at_ms FROM event_log"), 1_111)

        var swiftSecond: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(
            databaseURL: rustURL, nowMs: { 9_999 })
        let swiftReadCount = try await swiftSecond?.totalCountOrThrow()
        XCTAssertEqual(swiftReadCount, 1)
        swiftSecond = nil
        XCTAssertEqual(try scalarInt(rustURL, "PRAGMA user_version"), 3)
        XCTAssertEqual(try scalarInt(rustURL, "SELECT ingested_at_ms FROM event_log"), 1_111)

        let swiftURL = directory.appendingPathComponent("swift-first.sqlite")
        var swiftFirst: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(
            databaseURL: swiftURL, nowMs: { 2_222 })
        _ = try await swiftFirst?.append(entry("swift-first", timestampMs: 1))
        swiftFirst = nil
        var rustSecond: BASRoutedEventLogStorage? = try BASRoutedEventLogStorage(
            databaseURL: swiftURL, nowMs: { 8_888 })
        let rustReadCount = await rustSecond?.totalCount
        XCTAssertEqual(rustReadCount, 1)
        rustSecond = nil
        XCTAssertEqual(try scalarInt(swiftURL, "PRAGMA user_version"), 3)
        XCTAssertEqual(try scalarInt(swiftURL, "SELECT ingested_at_ms FROM event_log"), 2_222)

        let productionURL = directory.appendingPathComponent("production-old-abi.sqlite")
        let before = Int64(Date().timeIntervalSince1970 * 1_000)
        var production: BASRoutedEventLogStorage? = try BASRoutedEventLogStorage(
            databaseURL: productionURL)
        _ = try await production?.append(entry("production", timestampMs: 1))
        let after = Int64(Date().timeIntervalSince1970 * 1_000)
        production = nil
        let stamp = try scalarInt(
            productionURL, "SELECT ingested_at_ms FROM event_log WHERE event_id='production'")
        XCTAssertGreaterThanOrEqual(stamp, before)
        XCTAssertLessThanOrEqual(stamp, after)
    }

    func testSwiftV1MigrationAndUnsupportedVersionRejection() async throws {
        let (directory, v1URL) = try temporaryDatabase("v1.sqlite")
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        let json = "{\"eventID\":\"v1\",\"kind\":\"chat\",\"riskBand\":\"low\",\"sequenceNumber\":4,\"sessionID\":\"legacy\",\"timestampMs\":1}"
        try exec(v1URL, """
            PRAGMA user_version=1;
            CREATE TABLE event_log (
              event_id TEXT PRIMARY KEY NOT NULL, session_id TEXT NOT NULL,
              sequence_number INTEGER NOT NULL, timestamp_ms INTEGER NOT NULL,
              kind TEXT NOT NULL, risk_band TEXT NOT NULL, payload_json TEXT NOT NULL
            );
            INSERT INTO event_log VALUES ('v1','legacy',4,1,'chat','low','\(json)');
            """)
        var migrated: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(
            databaseURL: v1URL, nowMs: { 3_333 })
        let append = try await migrated?.append(entry("after-v1", timestampMs: 2, session: "legacy"))
        XCTAssertEqual(append?.assignedSequenceNumber, 5)
        migrated = nil
        XCTAssertEqual(try scalarInt(v1URL, "PRAGMA user_version"), 3)
        XCTAssertEqual(try scalarInt(v1URL, "SELECT payload_format FROM event_log WHERE event_id='v1'"), 1)
        XCTAssertEqual(try scalarInt(v1URL, "SELECT ingested_at_ms FROM event_log WHERE event_id='v1'"), 3_333)
        XCTAssertEqual(try scalarText(v1URL, "SELECT payload_json FROM event_log WHERE event_id='v1'"), json)

        let unsupportedURL = directory.appendingPathComponent("unsupported.sqlite")
        try exec(unsupportedURL, "PRAGMA user_version=77")
        let closes = CloseCounter()
        XCTAssertThrowsError(try BASSQLiteEventLogStorage(
            databaseURL: unsupportedURL, nowMs: { 4_444 }, closeObserver: closes.increment))
        XCTAssertEqual(closes.read(), 1)
        XCTAssertEqual(try scalarInt(unsupportedURL, "PRAGMA user_version"), 77)
        XCTAssertEqual(
            try scalarInt(unsupportedURL, "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='event_log'"),
            0)
    }

    func testFullPruneHighWaterPersistsAcrossRealSwiftAndRoutedReopen() async throws {
        let (directory, swiftURL) = try temporaryDatabase("swift-hwm.sqlite")
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }

        let swiftClock = BASEventLogTestClock(1_000)
        let swiftCloses = CloseCounter()
        var swiftStore: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(
            databaseURL: swiftURL, nowMs: swiftClock.now,
            closeObserver: swiftCloses.increment)
        _ = try await swiftStore?.append(entry("swift-0", timestampMs: 1, session: "swift-hwm"))
        _ = try await swiftStore?.append(entry("swift-1", timestampMs: 2, session: "swift-hwm"))
        swiftClock.advance(by: 259_200_001)
        let swiftRemoved = try await swiftStore?.pruneEventsBefore(timestampMs: 50)
        XCTAssertEqual(swiftRemoved, 2)
        weak var releasedSwift = swiftStore
        swiftStore = nil
        XCTAssertNil(releasedSwift)
        XCTAssertEqual(swiftCloses.read(), 1)
        var reopenedSwift: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(
            databaseURL: swiftURL, nowMs: swiftClock.now,
            closeObserver: swiftCloses.increment)
        let swiftNext = try await reopenedSwift?.append(
            entry("swift-2", timestampMs: 100, session: "swift-hwm"))
        XCTAssertEqual(swiftNext?.assignedSequenceNumber, 2)
        reopenedSwift = nil
        XCTAssertEqual(swiftCloses.read(), 2)

        let routedURL = directory.appendingPathComponent("routed-hwm.sqlite")
        let routedClock = BASEventLogTestClock(1_000)
        var routedStore: BASRoutedEventLogStorage? = try BASRoutedEventLogStorage(
            databaseURL: routedURL, nowMs: routedClock.now)
        _ = try await routedStore?.append(entry("routed-0", timestampMs: 1, session: "routed-hwm"))
        _ = try await routedStore?.append(entry("routed-1", timestampMs: 2, session: "routed-hwm"))
        routedClock.advance(by: 259_200_001)
        let routedRemoved = try await routedStore?.pruneEventsBefore(timestampMs: 50)
        XCTAssertEqual(routedRemoved, 2)
        weak var releasedRouted = routedStore
        routedStore = nil
        XCTAssertNil(releasedRouted)
        var reopenedRouted: BASRoutedEventLogStorage? = try BASRoutedEventLogStorage(
            databaseURL: routedURL, nowMs: routedClock.now)
        let routedNext = try await reopenedRouted?.append(
            entry("routed-2", timestampMs: 100, session: "routed-hwm"))
        XCTAssertEqual(routedNext?.assignedSequenceNumber, 2)
        reopenedRouted = nil
    }

    func testSwiftChainClosedRoutedPrunedAndSwiftReopenedStillVerifies() async throws {
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = true
        defer { BASSQLiteEventLogStorage.rowIntegrityChainEnabled = false }
        let (directory, url) = try temporaryDatabase("cross-chain.sqlite")
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        let clock = BASEventLogTestClock(1_000)
        let closes = CloseCounter()
        var writer: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(
            databaseURL: url, nowMs: clock.now, closeObserver: closes.increment)
        for (index, timestamp) in [100, 1, 100].enumerated() {
            _ = try await writer?.append(entry(
                "nonmonotone-\(index)", timestampMs: Int64(timestamp), session: "nonmonotone"))
        }
        for (index, timestamp) in [1, 2, 100].enumerated() {
            _ = try await writer?.append(entry(
                "prefix-\(index)", timestampMs: Int64(timestamp), session: "prefix"))
        }
        try await writer?.verifyIntegrityChain(forSession: "nonmonotone")
        try await writer?.verifyIntegrityChain(forSession: "prefix")
        let hashesBefore = try scalarText(url, """
            SELECT group_concat(event_id || ':' || row_hash || ':' || prev_hash, '|')
            FROM (SELECT * FROM event_log_integrity
                  WHERE session_id='nonmonotone' ORDER BY sequence_number)
            """)
        weak var releasedWriter = writer
        writer = nil
        XCTAssertNil(releasedWriter)
        XCTAssertEqual(closes.read(), 1)

        clock.advance(by: 259_200_001)
        var routed: BASRoutedEventLogStorage? = try BASRoutedEventLogStorage(
            databaseURL: url, nowMs: clock.now)
        let removed = try await routed?.pruneEventsBefore(timestampMs: 50)
        XCTAssertEqual(removed, 2)
        weak var releasedRouted = routed
        routed = nil
        XCTAssertNil(releasedRouted)

        var verifier: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(
            databaseURL: url, nowMs: clock.now, closeObserver: closes.increment)
        let nonmonotone = try await verifier?.eventsOrThrow(forSession: "nonmonotone")
        let prefix = try await verifier?.eventsOrThrow(forSession: "prefix")
        XCTAssertEqual(nonmonotone?.map(\.eventID), [
            "nonmonotone-0", "nonmonotone-1", "nonmonotone-2",
        ])
        XCTAssertEqual(prefix?.map(\.eventID), ["prefix-2"])
        XCTAssertEqual(try scalarText(url, """
            SELECT group_concat(event_id || ':' || row_hash || ':' || prev_hash, '|')
            FROM (SELECT * FROM event_log_integrity
                  WHERE session_id='nonmonotone' ORDER BY sequence_number)
            """), hashesBefore)
        try await verifier?.verifyIntegrityChain(forSession: "nonmonotone")
        try await verifier?.verifyIntegrityChain(forSession: "prefix")
        verifier = nil
        XCTAssertEqual(closes.read(), 2)
    }
}
