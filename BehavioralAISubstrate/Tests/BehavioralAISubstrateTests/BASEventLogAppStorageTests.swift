import Foundation
import SQLite3
import XCTest
@testable import BASRuntimeCore

final class BASEventLogAppStorageTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        BASSQLiteEventLogStorage.useBinaryPayload = false
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = false
        BASSQLiteEventLogStorage.runIntegrityCheckOnOpen = false
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-app-storage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        BASSQLiteEventLogStorage.useBinaryPayload = false
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = false
        BASSQLiteEventLogStorage.runIntegrityCheckOnOpen = false
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    func testConfigurationAppliesAndVerifiesRequestedPragmas() throws {
        for (name, synchronization, expected) in [
            ("normal", BASSQLiteEventLogConfiguration.Synchronization.normal, Int64(1)),
            ("full", BASSQLiteEventLogConfiguration.Synchronization.full, Int64(2)),
        ] {
            let db = try open(databaseURL("\(name).sqlite"))
            defer { sqlite3_close_v2(db) }
            let configuration = BASSQLiteEventLogConfiguration(
                synchronization: synchronization)
            try configuration.apply(to: db)
            XCTAssertEqual(try pragmaText(db, "journal_mode").lowercased(), "wal")
            XCTAssertEqual(try pragmaInteger(db, "synchronous"), expected)
        }
    }

    func testConfigurationRejectsUnavailableWALAndTransactionConflict() throws {
        var memory: OpaquePointer?
        XCTAssertEqual(sqlite3_open(":memory:", &memory), SQLITE_OK)
        let memoryDB = try XCTUnwrap(memory)
        defer { sqlite3_close_v2(memoryDB) }
        XCTAssertThrowsError(try BASSQLiteEventLogConfiguration(
            synchronization: .full).apply(to: memoryDB))

        let db = try open(databaseURL("transaction.sqlite"))
        defer { sqlite3_close_v2(db) }
        try execute(db, "BEGIN;")
        defer { try? execute(db, "ROLLBACK;") }
        XCTAssertThrowsError(try BASSQLiteEventLogConfiguration(
            synchronization: .full).apply(to: db))
    }

    func testExplicitConfigurationIgnoresGlobalFlagChangesAcrossAppends() async throws {
        BASSQLiteEventLogStorage.useBinaryPayload = true
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = false
        let chainedURL = databaseURL("explicit-chain.sqlite")
        let chained = try BASSQLiteEventLogStorage(
            databaseURL: chainedURL,
            configuration: .init(
                synchronization: .full,
                useBinaryPayload: false,
                rowIntegrityChainEnabled: true))
        let first = entry(id: "first", session: "session", timestamp: 100)
        _ = try await chained.append(first)
        BASSQLiteEventLogStorage.useBinaryPayload = false
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = true
        let second = entry(id: "second", session: "session", timestamp: 101)
        _ = try await chained.append(second)
        let chainedRecovery = try await chained.recoveryEvents(
            forSession: "session", limits: recoveryLimits(), integrity: .recordedChain)
        XCTAssertEqual(chainedRecovery,
            [withSequence(first, 0), withSequence(second, 1)])
        XCTAssertEqual(try payloadFormats(chainedURL), [1, 1])

        BASSQLiteEventLogStorage.useBinaryPayload = false
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = true
        let binaryURL = databaseURL("explicit-binary.sqlite")
        let binary = try BASSQLiteEventLogStorage(
            databaseURL: binaryURL,
            configuration: .init(
                synchronization: .normal,
                useBinaryPayload: true,
                rowIntegrityChainEnabled: false))
        let third = entry(id: "third", session: "binary", timestamp: 102)
        _ = try await binary.append(third)
        XCTAssertEqual(try payloadFormats(binaryURL), [2])
        let binaryRecovery = try await binary.recoveryEvents(
            forSession: "binary", limits: recoveryLimits(), integrity: .none)
        XCTAssertEqual(binaryRecovery,
            [withSequence(third, 0)])
    }

    func testDiscoveryLimitsRejectInvalidValuesAndHugeValidCountDoesNotAllocate() async throws {
        for values in [
            (0, 1, 1), (-1, 1, 1), (Int.max, 1, 1),
            (1, 0, 1), (1, -1, 1), (1, 1, 0), (1, 1, -1),
        ] {
            XCTAssertThrowsError(try BASEventLogSessionDiscoveryLimits(
                maximumSessionCount: values.0,
                maximumSessionIDBytes: values.1,
                maximumTotalSessionIDBytes: values.2
            )) { XCTAssertEqual($0 as? BASEventLogSessionDiscoveryError, .invalidLimits) }
        }
        let store = try BASSQLiteEventLogStorage(databaseURL: databaseURL("huge-count.sqlite"))
        let limits = try BASEventLogSessionDiscoveryLimits(
            maximumSessionCount: Int.max - 1,
            maximumSessionIDBytes: 32,
            maximumTotalSessionIDBytes: 32)
        let empty = try await store.recoverySessionPage(
            prefix: "p/", after: nil, limits: limits)
        XCTAssertEqual(empty, .init(sessionIDs: [], nextAfter: nil))
        _ = try await store.append(entry(id: "one", session: "p/one", timestamp: 1))
        let one = try await store.recoverySessionPage(
            prefix: "p/", after: nil, limits: limits)
        XCTAssertEqual(one,
            .init(sessionIDs: ["p/one"], nextAfter: nil))
    }

    func testDiscoveryPagesDistinctExactLiteralAndUnicodeSessions() async throws {
        let store = try BASSQLiteEventLogStorage(databaseURL: databaseURL("pages.sqlite"))
        for (index, session) in [
            "other/p_a", "p%_/a", "p%_/a", "p%_/b", "p%_/会话", "pX_/wrong"
        ].enumerated() {
            _ = try await store.append(entry(
                id: "event-\(index)", session: session, timestamp: Int64(index)))
        }
        let limits = try discoveryLimits(count: 2, perID: 100, total: 200)
        let first = try await store.recoverySessionPage(prefix: "p%_/", after: nil, limits: limits)
        XCTAssertEqual(first, .init(sessionIDs: ["p%_/a", "p%_/b"], nextAfter: "p%_/b"))
        let second = try await store.recoverySessionPage(
            prefix: "p%_/", after: first.nextAfter, limits: limits)
        XCTAssertEqual(second, .init(sessionIDs: ["p%_/会话"], nextAfter: nil))
    }

    func testDiscoverySupportsEmbeddedNULAndExactRawCursorValidation() async throws {
        let store = try BASSQLiteEventLogStorage(databaseURL: databaseURL("nul.sqlite"))
        for (index, session) in ["n\0/a", "n\0/b", "né/x"].enumerated() {
            _ = try await store.append(entry(
                id: "nul-\(index)", session: session, timestamp: Int64(index)))
        }
        let limits = try discoveryLimits(count: 10, perID: 40, total: 100)
        let page = try await store.recoverySessionPage(
            prefix: "n\0/", after: nil, limits: limits)
        XCTAssertEqual(page.sessionIDs, ["n\0/a", "n\0/b"])
        await assertDiscoveryError(.invalidQuery) {
            try await store.recoverySessionPage(
                prefix: "né/", after: "ne\u{301}/x", limits: limits)
        }
    }

    func testDiscoveryRejectsInvalidQueriesBeforeSQL() async throws {
        let store = try BASSQLiteEventLogStorage(databaseURL: databaseURL("query.sqlite"))
        let limits = try discoveryLimits(count: 2, perID: 4, total: 20)
        for (prefix, cursor) in [
            ("", nil), ("12345", nil), ("p/", "q/a"), ("p/", "p/123"),
        ] {
            await assertDiscoveryError(.invalidQuery) {
                try await store.recoverySessionPage(prefix: prefix, after: cursor, limits: limits)
            }
        }
    }

    func testDiscoveryByteBoundariesAndLookaheadDoNotMaterializeExtraIdentity() async throws {
        let store = try BASSQLiteEventLogStorage(databaseURL: databaseURL("bounds.sqlite"))
        for (index, session) in [
            "p/aé", "p/b😀", "p/" + String(repeating: "z", count: 80)
        ].enumerated() {
            _ = try await store.append(entry(
                id: "bound-\(index)", session: session, timestamp: Int64(index)))
        }
        let exact = try discoveryLimits(count: 2, perID: 7, total: 12)
        let first = try await store.recoverySessionPage(prefix: "p/", after: nil, limits: exact)
        XCTAssertEqual(first, .init(sessionIDs: ["p/aé", "p/b😀"], nextAfter: "p/b😀"))
        await assertDiscoveryError(.sessionIDByteLimitExceeded) {
            try await store.recoverySessionPage(prefix: "p/", after: first.nextAfter, limits: exact)
        }
        await assertDiscoveryError(.sessionIDByteLimitExceeded) {
            try await store.recoverySessionPage(
                prefix: "p/", after: nil,
                limits: try self.discoveryLimits(count: 2, perID: 6, total: 20))
        }
        await assertDiscoveryError(.totalSessionIDBytesExceeded) {
            try await store.recoverySessionPage(
                prefix: "p/", after: nil,
                limits: try self.discoveryLimits(count: 2, perID: 7, total: 11))
        }
    }

    func testDiscoveryChargesPublicUTF8BytesInUTF16Databases() async throws {
        for encoding in ["UTF-16le", "UTF-16be"] {
            let url = databaseURL("\(encoding).sqlite")
            let seed = try open(url)
            try execute(seed, "PRAGMA encoding='\(encoding)'; CREATE TABLE seed(value TEXT); DROP TABLE seed;")
            sqlite3_close_v2(seed)
            let store = try BASSQLiteEventLogStorage(databaseURL: url)
            // 2 prefix scalars + 2,045 ASCII scalars place the high surrogate
            // in the final UTF-16 code unit of the reader's 4 KiB chunk.
            let session = "p/" + String(repeating: "a", count: 2_045) + "😀"
            _ = try await store.append(entry(id: "utf16", session: session, timestamp: 1))
            let bytes = session.utf8.count
            let page = try await store.recoverySessionPage(
                prefix: "p/", after: nil,
                limits: try discoveryLimits(count: 1, perID: bytes, total: bytes))
            XCTAssertEqual(page.sessionIDs, [session])
            await assertDiscoveryError(.sessionIDByteLimitExceeded) {
                try await store.recoverySessionPage(
                    prefix: "p/", after: nil,
                    limits: try self.discoveryLimits(count: 1, perID: bytes - 1, total: bytes))
            }
            await assertDiscoveryError(.totalSessionIDBytesExceeded) {
                try await store.recoverySessionPage(
                    prefix: "p/", after: nil,
                    limits: try self.discoveryLimits(count: 1, perID: bytes, total: bytes - 1))
            }
        }
    }

    func testDiscoveryRefreshFindsNewEarlierSession() async throws {
        let store = try BASSQLiteEventLogStorage(databaseURL: databaseURL("refresh.sqlite"))
        _ = try await store.append(entry(id: "b", session: "p/b", timestamp: 1))
        _ = try await store.append(entry(id: "c", session: "p/c", timestamp: 2))
        let limits = try discoveryLimits(count: 1, perID: 20, total: 20)
        let first = try await store.recoverySessionPage(prefix: "p/", after: nil, limits: limits)
        XCTAssertEqual(first.sessionIDs, ["p/b"])
        _ = try await store.append(entry(id: "a", session: "p/a", timestamp: 3))
        let afterCursor = try await store.recoverySessionPage(
            prefix: "p/", after: first.nextAfter, limits: limits)
        XCTAssertEqual(afterCursor.sessionIDs, ["p/c"])
        let refreshed = try await store.recoverySessionPage(
            prefix: "p/", after: nil, limits: limits)
        XCTAssertEqual(refreshed.sessionIDs, ["p/a"])
    }

    func testDiscoveryRejectsMalformedMatchingIdentityAndRollsBack() async throws {
        let url = databaseURL("malformed.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        _ = try await store.append(entry(id: "good", session: "bad/good", timestamp: 1))
        try insertInvalidUTF8Session(url)
        let limits = try discoveryLimits(count: 10, perID: 100, total: 500)
        await assertDiscoveryError(.malformedIdentity) {
            try await store.recoverySessionPage(prefix: "bad/", after: nil, limits: limits)
        }
        _ = try await store.append(entry(id: "later", session: "ok/later", timestamp: 2))
        let page = try await store.recoverySessionPage(
            prefix: "ok/", after: nil, limits: limits)
        XCTAssertEqual(page.sessionIDs, ["ok/later"])
    }

    func testDiscoverySurfacesMissingTableAndDoesNotLeakTransaction() async throws {
        let url = databaseURL("missing-table.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        try execute(url, "ALTER TABLE event_log RENAME TO event_log_hidden;")
        do {
            _ = try await store.recoverySessionPage(
                prefix: "p/", after: nil, limits: try discoveryLimits())
            XCTFail("expected SQLite failure")
        } catch is BASSQLiteEventLogStorage.StorageError {
        } catch {
            XCTFail("expected storage error, got \(error)")
        }
        try execute(url, "ALTER TABLE event_log_hidden RENAME TO event_log;")
        _ = try await store.append(entry(id: "restored", session: "p/restored", timestamp: 1))
        let restored = try await store.recoverySessionPage(
            prefix: "p/", after: nil, limits: try discoveryLimits())
        XCTAssertEqual(restored.sessionIDs, ["p/restored"])
    }

    func testDiscoveryIgnoresMalformedAndLargePayloadButStrictRecoveryRefusesIt() async throws {
        let url = databaseURL("payload.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        _ = try await store.append(entry(id: "payload", session: "p/payload", timestamp: 1))
        try execute(url, "UPDATE event_log SET payload_json = '\(String(repeating: "{", count: 20_000))' WHERE event_id = 'payload';")
        let page = try await store.recoverySessionPage(
            prefix: "p/", after: nil, limits: try discoveryLimits())
        XCTAssertEqual(page.sessionIDs, ["p/payload"])
        do {
            _ = try await store.recoveryEvents(
                forSession: "p/payload", limits: recoveryLimits(), integrity: .none)
            XCTFail("expected malformed recovery payload")
        } catch let error as BASEventLogRecoveryReadError {
            XCTAssertEqual(error, .malformedRecord)
        }
    }

    func testReopenDiscoversAndRecoversExactOriginalRecords() async throws {
        let url = databaseURL("reopen.sqlite")
        let original = entry(id: "persisted", session: "app/session", timestamp: 42)
        do {
            let store = try BASSQLiteEventLogStorage(
                databaseURL: url,
                configuration: .init(
                    synchronization: .full,
                    rowIntegrityChainEnabled: true))
            _ = try await store.append(original)
        }
        let reopened = try BASSQLiteEventLogStorage(
            databaseURL: url,
            configuration: .init(
                synchronization: .full,
                rowIntegrityChainEnabled: true))
        let page = try await reopened.recoverySessionPage(
            prefix: "app/", after: nil, limits: try discoveryLimits())
        XCTAssertEqual(page.sessionIDs, ["app/session"])
        let recovery = try await reopened.recoveryEvents(
            forSession: "app/session", limits: recoveryLimits(), integrity: .recordedChain)
        XCTAssertEqual(recovery,
            [withSequence(original, 0)])
    }

    func testIdentitySelectInterruptionPreservesSQLiteStorageError() async throws {
        let url = databaseURL("identity-interrupt.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        _ = try await store.append(entry(
            id: "interrupt", session: "p/interrupt", timestamp: 1))
        let db = try open(url)
        defer { sqlite3_close_v2(db) }
        let rowID = try scalarInteger(
            db, "SELECT rowid FROM event_log WHERE event_id = 'interrupt'")
        var callbackDB: OpaquePointer? = db
        withUnsafeMutablePointer(to: &callbackDB) { context in
            sqlite3_progress_handler(db, 1, { rawContext in
                guard let rawContext,
                      let callbackDB = rawContext
                        .assumingMemoryBound(to: OpaquePointer?.self).pointee
                else { return 0 }
                var statement = sqlite3_next_stmt(callbackDB, nil)
                while let current = statement {
                    if let sql = sqlite3_sql(current),
                       String(cString: sql)
                        == "SELECT session_id FROM event_log WHERE rowid = ?" {
                        return 1
                    }
                    statement = sqlite3_next_stmt(callbackDB, current)
                }
                return 0
            }, context)
            defer { sqlite3_progress_handler(db, 0, nil, nil) }
            do {
                _ = try BASSQLiteEventLogRecoveryReader(db: db).sessionIdentity(
                    rowID: rowID, storedType: "text", maximumUTF8Bytes: 100)
                XCTFail("expected interrupted identity SELECT")
            } catch let error as BASSQLiteEventLogStorage.StorageError {
                guard case let .stepFailed(sql, message) = error else {
                    return XCTFail("expected stepFailed, got \(error)")
                }
                XCTAssertEqual(sql, "SELECT session_id FROM event_log WHERE rowid = ?")
                XCTAssertTrue(message.lowercased().contains("interrupt"), message)
            } catch {
                XCTFail("expected SQLite storage error, got \(error)")
            }
        }
    }

    func testEmptyBoundStringsRemainTextIncludingChainRoot() async throws {
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = true
        let chainURL = databaseURL("empty-chain.sqlite")
        let chain = try BASSQLiteEventLogStorage(databaseURL: chainURL)
        _ = try await chain.append(entry(id: "root", session: "p/root", timestamp: 1))
        XCTAssertEqual(try scalarText(
            chainURL,
            "SELECT typeof(prev_hash) || ':' || length(prev_hash) "
                + "FROM event_log_integrity WHERE event_id = 'root'"), "text:0")

        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = false
        BASSQLiteEventLogStorage.useBinaryPayload = true
        let binaryURL = databaseURL("empty-binary-json.sqlite")
        let binary = try BASSQLiteEventLogStorage(databaseURL: binaryURL)
        _ = try await binary.append(entry(
            id: "binary-empty", session: "p/binary", timestamp: 2))
        XCTAssertEqual(try scalarText(
            binaryURL,
            "SELECT typeof(payload_json) || ':' || length(payload_json) "
                + "FROM event_log WHERE event_id = 'binary-empty'"), "text:0")
    }

    func testLoweredSQLiteLengthLimitSurfacesCheckedBindFailure() async throws {
        let store = try BASSQLiteEventLogStorage(
            databaseURL: databaseURL("bind-limit.sqlite"),
            nowMs: { 1 },
            closeObserver: nil,
            connectionSetup: { db in
                _ = sqlite3_limit(db, SQLITE_LIMIT_LENGTH, 32)
            })
        do {
            _ = try await store.append(entry(
                id: String(repeating: "x", count: 128),
                session: "p/limit", timestamp: 1))
            XCTFail("expected checked bind failure")
        } catch let error as BASSQLiteEventLogStorage.StorageError {
            guard case let .prepareFailed(sql, message) = error else {
                return XCTFail("expected prepareFailed bind error, got \(error)")
            }
            XCTAssertTrue(sql.contains("event_id = ?"), sql)
            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("expected SQLite storage error, got \(error)")
        }
    }

    func testOversizedPrefixAndCursorRejectAtByteBudget() async throws {
        let store = try BASSQLiteEventLogStorage(databaseURL: databaseURL("large-query.sqlite"))
        let limits = try discoveryLimits(count: 1, perID: 4, total: 4)
        let huge = String(repeating: "😀", count: 250_000)
        await assertDiscoveryError(.invalidQuery) {
            try await store.recoverySessionPage(prefix: huge, after: nil, limits: limits)
        }
        await assertDiscoveryError(.invalidQuery) {
            try await store.recoverySessionPage(prefix: "p/", after: "p/" + huge, limits: limits)
        }
    }

    private func databaseURL(_ name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    private func entry(id: String, session: String, timestamp: Int64) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: id, timestampMs: timestamp, kind: .chat,
            sessionID: session, sequenceNumber: 0,
            source: "app", turnRef: "turn", rawInputDigest: "digest",
            intent: "ask", emotion: "calm", riskBand: .medium, project: "project",
            memoryRefs: ["memory"], stateBeforeID: "before", stateAfterID: "after",
            actions: ["answer"], confidence: 0.75, payloadJson: #"{"key":"value"}"#)
    }

    private func withSequence(_ entry: BASEventLogEntry, _ sequence: Int64) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: entry.eventID, timestampMs: entry.timestampMs, kind: entry.kind,
            sessionID: entry.sessionID, sequenceNumber: sequence, source: entry.source,
            turnRef: entry.turnRef, rawInputDigest: entry.rawInputDigest, intent: entry.intent,
            emotion: entry.emotion, riskBand: entry.riskBand, project: entry.project,
            memoryRefs: entry.memoryRefs, stateBeforeID: entry.stateBeforeID,
            stateAfterID: entry.stateAfterID, actions: entry.actions,
            confidence: entry.confidence, payloadJson: entry.payloadJson)
    }

    private func discoveryLimits(
        count: Int = 50, perID: Int = 512, total: Int = 25_600
    ) throws -> BASEventLogSessionDiscoveryLimits {
        try BASEventLogSessionDiscoveryLimits(
            maximumSessionCount: count,
            maximumSessionIDBytes: perID,
            maximumTotalSessionIDBytes: total)
    }

    private func recoveryLimits() -> BASEventLogRecoveryReadLimits {
        try! BASEventLogRecoveryReadLimits(
            maximumEventCount: 100,
            maximumEncodedEventBytes: 100_000,
            maximumTotalEncodedBytes: 1_000_000)
    }

    private func assertDiscoveryError<T>(
        _ expected: BASEventLogSessionDiscoveryError,
        operation: () async throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await operation()
            XCTFail("expected discovery error \(expected)", file: file, line: line)
        } catch let error as BASEventLogSessionDiscoveryError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("expected discovery error \(expected), got \(error)", file: file, line: line)
        }
    }

    private func open(
        _ url: URL, flags: Int32 = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
    ) throws -> OpaquePointer {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(url.path, &db, flags, nil)
        guard rc == SQLITE_OK, let db else {
            if let db { sqlite3_close_v2(db) }
            throw NSError(domain: "BASEventLogAppStorageTests", code: Int(rc))
        }
        return db
    }

    private func execute(_ url: URL, _ sql: String) throws {
        let db = try open(url)
        defer { sqlite3_close_v2(db) }
        try execute(db, sql)
    }

    private func execute(_ db: OpaquePointer, _ sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &message)
        guard rc == SQLITE_OK else {
            let detail = message.map { String(cString: $0) } ?? "rc=\(rc)"
            if let message { sqlite3_free(message) }
            throw NSError(domain: "BASEventLogAppStorageTests", code: Int(rc),
                userInfo: [NSLocalizedDescriptionKey: detail])
        }
    }

    private func pragmaText(_ db: OpaquePointer, _ name: String) throws -> String {
        var statement: OpaquePointer?
        let sql = "PRAGMA \(name);"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { throw NSError(domain: "pragma", code: 1) }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0)
        else { throw NSError(domain: "pragma", code: 2) }
        return String(cString: text)
    }

    private func pragmaInteger(_ db: OpaquePointer, _ name: String) throws -> Int64 {
        var statement: OpaquePointer?
        let sql = "PRAGMA \(name);"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { throw NSError(domain: "pragma", code: 3) }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw NSError(domain: "pragma", code: 4)
        }
        return sqlite3_column_int64(statement, 0)
    }

    private func scalarInteger(_ db: OpaquePointer, _ sql: String) throws -> Int64 {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { throw NSError(domain: "scalar", code: 1) }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw NSError(domain: "scalar", code: 2)
        }
        return sqlite3_column_int64(statement, 0)
    }

    private func scalarText(_ url: URL, _ sql: String) throws -> String {
        let db = try open(url, flags: SQLITE_OPEN_READONLY)
        defer { sqlite3_close_v2(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { throw NSError(domain: "scalar", code: 3) }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let value = sqlite3_column_text(statement, 0) else {
            throw NSError(domain: "scalar", code: 4)
        }
        return String(cString: value)
    }

    private func payloadFormats(_ url: URL) throws -> [Int64] {
        let db = try open(url, flags: SQLITE_OPEN_READONLY)
        defer { sqlite3_close_v2(db) }
        var statement: OpaquePointer?
        let sql = "SELECT payload_format FROM event_log ORDER BY sequence_number"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { throw NSError(domain: "payload", code: 1) }
        defer { sqlite3_finalize(statement) }
        var formats: [Int64] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            formats.append(sqlite3_column_int64(statement, 0))
        }
        return formats
    }

    private func insertInvalidUTF8Session(_ url: URL) throws {
        let db = try open(url)
        defer { sqlite3_close_v2(db) }
        let sql = """
            INSERT INTO event_log (
                event_id, session_id, sequence_number, timestamp_ms, kind,
                risk_band, payload_json, payload_format, payload_blob, ingested_at_ms
            ) VALUES ('invalid-id', CAST(? AS TEXT), 0, 0, 'chat', 'medium', '{}', 1, NULL, 0)
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { throw NSError(domain: "malformed", code: 1) }
        defer { sqlite3_finalize(statement) }
        let bytes: [UInt8] = Array("bad/".utf8) + [0xFF]
        let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
        let bindRC = bytes.withUnsafeBytes {
            sqlite3_bind_blob(statement, 1, $0.baseAddress, Int32($0.count), transient)
        }
        guard bindRC == SQLITE_OK, sqlite3_step(statement) == SQLITE_DONE else {
            throw NSError(domain: "malformed", code: 2)
        }
    }
}
