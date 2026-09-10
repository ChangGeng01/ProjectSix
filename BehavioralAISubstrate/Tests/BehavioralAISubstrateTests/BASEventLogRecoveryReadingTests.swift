import Foundation
import SQLite3
import XCTest
@testable import BASRuntimeCore

final class BASEventLogRecoveryReadingTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        BASSQLiteEventLogStorage.useBinaryPayload = false
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = false
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-recovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        BASSQLiteEventLogStorage.useBinaryPayload = false
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = false
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    func testLimitsRejectNonpositiveValuesAndCountOverflow() {
        for values in [
            (0, 1, 1), (-1, 1, 1),
            (1, 0, 1), (1, -1, 1),
            (1, 1, 0), (1, 1, -1),
            (Int.max, 1, 1),
        ] {
            XCTAssertThrowsError(try BASEventLogRecoveryReadLimits(
                maximumEventCount: values.0,
                maximumEncodedEventBytes: values.1,
                maximumTotalEncodedBytes: values.2
            )) { error in
                XCTAssertEqual(error as? BASEventLogRecoveryReadError, .invalidLimits)
            }
        }
    }

    func testLargestValidCountLimitDoesNotDrivePreflightAllocation() async throws {
        let store = try BASSQLiteEventLogStorage(
            databaseURL: databaseURL("large-count-limit.sqlite"))
        let limits = try BASEventLogRecoveryReadLimits(
            maximumEventCount: Int.max - 1,
            maximumEncodedEventBytes: 100_000,
            maximumTotalEncodedBytes: 100_000)

        let empty = try await store.recoveryEvents(
            forSession: "session", limits: limits, integrity: .none)
        XCTAssertEqual(empty, [])
        _ = try await store.append(entry(id: "one", timestamp: 100))
        let one = try await store.recoveryEvents(
            forSession: "session", limits: limits, integrity: .none)
        XCTAssertEqual(one.count, 1)
    }

    func testJSONAndBinaryFullFieldRowsAndEmptySessionRoundTrip() async throws {
        let url = databaseURL("formats.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        let json = entry(id: "json", timestamp: 101)
        _ = try await store.append(json)
        BASSQLiteEventLogStorage.useBinaryPayload = true
        let binary = entry(id: "binary", timestamp: 102)
        _ = try await store.append(binary)

        let recovered = try await store.recoveryEvents(
            forSession: "session", limits: generousLimits(), integrity: .none)
        XCTAssertEqual(recovered, [withSequence(json, 0), withSequence(binary, 1)])
        let empty = try await store.recoveryEvents(
            forSession: "absent", limits: generousLimits(), integrity: .none)
        XCTAssertEqual(empty, [])
    }

    func testCountLimitRejectsCompleteReadInsteadOfReturningPrefix() async throws {
        let store = try BASSQLiteEventLogStorage(databaseURL: databaseURL("count.sqlite"))
        _ = try await store.append(entry(id: "event-0", timestamp: 100))
        _ = try await store.append(entry(id: "event-1", timestamp: 101))

        await assertRecoveryError(.eventCountLimitExceeded) {
            try await store.recoveryEvents(
                forSession: "session",
                limits: try self.limits(count: 1, row: 10_000, total: 20_000),
                integrity: .none)
        }
        _ = try await store.append(entry(id: "event-2", timestamp: 102))
        let count = try await store.totalCountOrThrow()
        XCTAssertEqual(count, 3)
    }

    func testExactPerRowAndTotalByteBoundariesPassAndOneByteLessFails() async throws {
        let url = databaseURL("bytes.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        _ = try await store.append(entry(id: "short", timestamp: 100))
        _ = try await store.append(entry(id: "事件-long", timestamp: 101))
        let rowBytes = try encodedEventRowBytes(url, session: "session")
        let largest = try XCTUnwrap(rowBytes.max())
        let total = rowBytes.reduce(0, +)

        let exactBoundary = try await store.recoveryEvents(
            forSession: "session",
            limits: try limits(count: 2, row: largest, total: total),
            integrity: .none)
        XCTAssertEqual(exactBoundary.count, 2)
        await assertRecoveryError(.eventByteLimitExceeded) {
            try await store.recoveryEvents(
                forSession: "session",
                limits: try self.limits(count: 2, row: largest - 1, total: total),
                integrity: .none)
        }
        await assertRecoveryError(.totalByteLimitExceeded) {
            try await store.recoveryEvents(
                forSession: "session",
                limits: try self.limits(count: 2, row: largest, total: total - 1),
                integrity: .none)
        }
    }

    func testMultibyteAndEmbeddedNULIdentitiesUseExactUTF8Lengths() async throws {
        let url = databaseURL("nul.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        let session = "会话\0suffix"
        let expected = entry(
            id: "事件\0identity", session: session, timestamp: 333, sequence: 0)
        try insertJSONRow(url, entry: expected)
        let exact = try XCTUnwrap(encodedEventRowBytes(url, session: session).first)

        let recovered = try await store.recoveryEvents(
            forSession: session,
            limits: try limits(count: 1, row: exact, total: exact),
            integrity: .none)
        XCTAssertEqual(recovered, [expected])
    }

    func testUTF16DatabasesStillChargePublicUTF8ByteLengths() async throws {
        for encoding in ["UTF-16le", "UTF-16be"] {
            let url = databaseURL("\(encoding)-accounting.sqlite")
            let setup = try open(url, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            do {
                try execute(setup, """
                    PRAGMA encoding='\(encoding)';
                    CREATE TABLE encoding_seed(value TEXT);
                    DROP TABLE encoding_seed;
                    """)
            } catch {
                sqlite3_close_v2(setup)
                throw error
            }
            sqlite3_close_v2(setup)
            XCTAssertEqual(try databaseEncoding(url).lowercased(), encoding.lowercased())

            let store = try BASSQLiteEventLogStorage(databaseURL: url)
            let splitSurrogateID = String(repeating: "a", count: 2_047) + "😀"
            let expected = entry(id: splitSurrogateID, session: "会话", timestamp: 100)
            _ = try await store.append(expected)
            let exactUTF8Bytes = try XCTUnwrap(
                utf8EncodedEventRowBytes(url, session: "会话").first)

            let recovered = try await store.recoveryEvents(
                forSession: "会话",
                limits: try limits(count: 1, row: exactUTF8Bytes, total: exactUTF8Bytes),
                integrity: .none)
            XCTAssertEqual(recovered, [withSequence(expected, 0)])
            await assertRecoveryError(.eventByteLimitExceeded) {
                try await store.recoveryEvents(
                    forSession: "会话",
                    limits: try self.limits(
                        count: 1, row: exactUTF8Bytes - 1, total: exactUTF8Bytes),
                    integrity: .none)
            }
        }
    }

    func testOversizedMalformedPayloadFailsBoundsBeforeDecode() async throws {
        let url = databaseURL("oversized-malformed.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        _ = try await store.append(entry(id: "bad", timestamp: 100))
        try updatePayloadText(url, eventID: "bad", bytes: Array(repeating: 0x7b, count: 512))

        await assertRecoveryError(.eventByteLimitExceeded) {
            try await store.recoveryEvents(
                forSession: "session",
                limits: try self.limits(count: 1, row: 128, total: 1_000),
                integrity: .none)
        }
        _ = try await store.append(entry(id: "after-bound", timestamp: 101))
    }

    func testOversizedTextPreflightRejectsWithoutReadingOverflowPages() async throws {
        let url = databaseURL("metadata-only-length.sqlite")
        var store: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(databaseURL: url)
        _ = try await store?.append(entry(id: "large", timestamp: 100))
        store = nil
        try execute(url,
            "UPDATE event_log SET payload_json=CAST(zeroblob(1048576) AS TEXT) WHERE event_id='large'")

        let db = try open(url)
        defer { sqlite3_close_v2(db) }
        let previousLengthLimit = sqlite3_limit(db, SQLITE_LIMIT_LENGTH, 1_024)
        defer { sqlite3_limit(db, SQLITE_LIMIT_LENGTH, previousLengthLimit) }
        try execute(db, "PRAGMA cache_size=8; PRAGMA shrink_memory;")
        let before = try cacheMisses(db)
        XCTAssertThrowsError(try BASSQLiteEventLogRecoveryReader(db: db).read(
            sessionID: "session",
            limits: try limits(count: 1, row: 128, total: 128),
            integrity: .none
        )) { error in
            XCTAssertEqual(error as? BASEventLogRecoveryReadError, .eventByteLimitExceeded)
        }
        let misses = try cacheMisses(db) - before
        XCTAssertLessThan(misses, 32,
            "metadata-only rejection must not traverse the stored value's overflow pages")
        try execute(db, "BEGIN IMMEDIATE; ROLLBACK;")
    }

    func testMalformedVariableTypesRejectWithoutReadingOverflowPages() async throws {
        for (name, mutation) in [
            ("format", "payload_format=CAST(zeroblob(1048576) AS TEXT)"),
            ("blob", "payload_format=2, payload_json='', payload_blob=CAST(zeroblob(1048576) AS TEXT)"),
        ] {
            let url = databaseURL("metadata-only-type-\(name).sqlite")
            var store: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(databaseURL: url)
            _ = try await store?.append(entry(id: "bad", timestamp: 100))
            store = nil
            try execute(url, "UPDATE event_log SET \(mutation) WHERE event_id='bad'")

            let db = try open(url)
            defer { sqlite3_close_v2(db) }
            try execute(db, "PRAGMA cache_size=8; PRAGMA shrink_memory;")
            let before = try cacheMisses(db)
            XCTAssertThrowsError(try BASSQLiteEventLogRecoveryReader(db: db).read(
                sessionID: "session",
                limits: generousLimits(),
                integrity: .none
            )) { error in
                XCTAssertEqual(error as? BASEventLogRecoveryReadError, .malformedRecord)
            }
            let misses = try cacheMisses(db) - before
            XCTAssertLessThan(misses, 32,
                "type rejection must not materialize malformed \(name) content")
            try execute(db, "BEGIN IMMEDIATE; ROLLBACK;")
        }
    }

    func testMalformedLaterJSONUnknownFormatInvalidUTF8AndIdentityMismatchFailCompletely() async throws {
        for corruption in Corruption.allCases {
            let url = databaseURL("strict-\(corruption.rawValue).sqlite")
            let store = try BASSQLiteEventLogStorage(databaseURL: url)
            _ = try await store.append(entry(id: "good", timestamp: 100))
            _ = try await store.append(entry(id: "bad", timestamp: 101))
            switch corruption {
            case .malformedJSON:
                try updatePayloadText(url, eventID: "bad", bytes: Array("{".utf8))
            case .unknownFormat:
                try execute(url, "UPDATE event_log SET payload_format=9 WHERE event_id='bad'")
            case .invalidUTF8:
                try updatePayloadText(url, eventID: "bad", bytes: [0xff, 0xfe])
            case .identityMismatch:
                let wrong = entry(id: "different", timestamp: 101, sequence: 1)
                try updatePayloadText(
                    url, eventID: "bad", bytes: Array(try JSONEncoder().encode(wrong)))
            }

            let expected: BASEventLogRecoveryReadError =
                corruption == .unknownFormat ? .unsupportedRecord : .malformedRecord
            await assertRecoveryError(expected) {
                try await store.recoveryEvents(
                    forSession: "session",
                    limits: self.generousLimits(),
                    integrity: .none)
            }
            _ = try await store.append(entry(id: "after-\(corruption.rawValue)", timestamp: 102))
        }
    }

    func testMalformedBinaryEnvelopeFailsWithoutLegacyDefaulting() async throws {
        let url = databaseURL("binary-envelope.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        _ = try await store.append(entry(id: "good", timestamp: 100))
        _ = try await store.append(entry(id: "binary-bad", timestamp: 101))
        let malformed = try BASEventLogBinaryCodec.encode(BASBinaryEventLogEntry(
            entryID: "binary-bad", kind: .hostInput, sessionRef: "session",
            turnRef: "turn", timestampMs: 101, payloadJson: "{",
            provenanceSummary: nil))
        try updateBinaryPayload(url, eventID: "binary-bad", blob: malformed)

        await assertRecoveryError(.malformedRecord) {
            try await store.recoveryEvents(
                forSession: "session", limits: self.generousLimits(), integrity: .none)
        }
        let legacy = try await store.eventsOrThrow(forSession: "session")
        XCTAssertEqual(legacy.count, 2,
            "legacy decoder behavior remains available and does not poison the handle")
    }

    func testBinaryEnvelopeRejectsEmptyActionsInsteadOfInventingEmptyArray() async throws {
        let url = databaseURL("binary-empty-actions.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        _ = try await store.append(entry(id: "empty-actions", timestamp: 100))
        var envelope = validBinaryEnvelope()
        envelope["actions"] = ""
        try updateBinaryPayload(
            url, eventID: "empty-actions",
            blob: try binaryBlob(
                eventID: "empty-actions", timestamp: 100,
                turnRef: "turn-1", envelope: envelope))

        await assertRecoveryError(.malformedRecord) {
            try await store.recoveryEvents(
                forSession: "session", limits: self.generousLimits(), integrity: .none)
        }
        let legacy = try await store.eventsOrThrow(forSession: "session")
        XCTAssertEqual(legacy.first?.actions, [])
        _ = try await store.append(entry(id: "after-empty-actions", timestamp: 101))
    }

    func testBinaryEnvelopeRefusesAmbiguousEmptyOptionalAndTurnFields() async throws {
        let optionalURL = databaseURL("binary-empty-optional.sqlite")
        let optionalStore = try BASSQLiteEventLogStorage(databaseURL: optionalURL)
        _ = try await optionalStore.append(entry(id: "empty-optional", timestamp: 100))
        var emptyOptional = validBinaryEnvelope()
        emptyOptional["source"] = ""
        try updateBinaryPayload(
            optionalURL, eventID: "empty-optional",
            blob: try binaryBlob(
                eventID: "empty-optional", timestamp: 100,
                turnRef: "turn-1", envelope: emptyOptional))
        await assertRecoveryError(.unsupportedRecord) {
            try await optionalStore.recoveryEvents(
                forSession: "session", limits: self.generousLimits(), integrity: .none)
        }
        let optionalLegacy = try await optionalStore.eventsOrThrow(forSession: "session")
        XCTAssertNil(optionalLegacy.first?.source)
        _ = try await optionalStore.append(entry(id: "after-empty-optional", timestamp: 101))

        let turnURL = databaseURL("binary-empty-turn.sqlite")
        let turnStore = try BASSQLiteEventLogStorage(databaseURL: turnURL)
        _ = try await turnStore.append(entry(id: "empty-turn", timestamp: 100))
        try updateBinaryPayload(
            turnURL, eventID: "empty-turn",
            blob: try binaryBlob(
                eventID: "empty-turn", timestamp: 100,
                turnRef: "", envelope: validBinaryEnvelope()))
        await assertRecoveryError(.unsupportedRecord) {
            try await turnStore.recoveryEvents(
                forSession: "session", limits: self.generousLimits(), integrity: .none)
        }
        let turnLegacy = try await turnStore.eventsOrThrow(forSession: "session")
        XCTAssertNil(turnLegacy.first?.turnRef)
        _ = try await turnStore.append(entry(id: "after-empty-turn", timestamp: 101))
    }

    func testSQLReadFailureIsNotReportedAsEmpty() async throws {
        let url = databaseURL("sql-error.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        try execute(url, "DROP TABLE event_log")

        do {
            _ = try await store.recoveryEvents(
                forSession: "session", limits: generousLimits(), integrity: .none)
            XCTFail("missing storage must not be reported as an empty session")
        } catch is BASSQLiteEventLogStorage.StorageError {
            // Existing SQLite errors intentionally propagate.
        }
    }

    func testRecordedChainAcceptsValidRowsAndRejectsMissingTamperedAndOrphanEvidence() async throws {
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = true
        let validURL = databaseURL("chain-valid.sqlite")
        let valid = try BASSQLiteEventLogStorage(databaseURL: validURL)
        for index in 0..<3 {
            _ = try await valid.append(entry(id: "v\(index)", timestamp: Int64(100 + index)))
        }
        let validRows = try await valid.recoveryEvents(
            forSession: "session", limits: generousLimits(), integrity: .recordedChain)
        XCTAssertEqual(validRows.count, 3)

        let missingURL = databaseURL("chain-missing.sqlite")
        let missing = try BASSQLiteEventLogStorage(databaseURL: missingURL)
        _ = try await missing.append(entry(id: "missing", timestamp: 100))
        try execute(missingURL, "DELETE FROM event_log_integrity WHERE event_id='missing'")
        await assertRecoveryError(.missingIntegrity) {
            try await missing.recoveryEvents(
                forSession: "session", limits: self.generousLimits(), integrity: .recordedChain)
        }
        _ = try await missing.append(entry(id: "missing-after", timestamp: 101))

        let tamperedURL = databaseURL("chain-tampered.sqlite")
        let tampered = try BASSQLiteEventLogStorage(databaseURL: tamperedURL)
        _ = try await tampered.append(entry(id: "tampered", timestamp: 100))
        try execute(tamperedURL,
            "UPDATE event_log_integrity SET row_hash='ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' WHERE event_id='tampered'")
        await assertRecoveryError(.invalidIntegrity) {
            try await tampered.recoveryEvents(
                forSession: "session", limits: self.generousLimits(), integrity: .recordedChain)
        }

        let orphanURL = databaseURL("chain-orphan.sqlite")
        let orphan = try BASSQLiteEventLogStorage(databaseURL: orphanURL)
        _ = try await orphan.append(entry(id: "orphan", timestamp: 100))
        try execute(orphanURL, "DELETE FROM event_log WHERE event_id='orphan'")
        await assertRecoveryError(.invalidIntegrity) {
            try await orphan.recoveryEvents(
                forSession: "session", limits: self.generousLimits(), integrity: .recordedChain)
        }
    }

    func testRecordedChainAcceptsLegitimatelyPrefixPrunedRows() async throws {
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = true
        let clock = LockedClock(1_000)
        let url = databaseURL("chain-pruned.sqlite")
        let store = try BASSQLiteEventLogStorage(
            databaseURL: url, nowMs: clock.now, closeObserver: nil)
        for index in 0..<3 {
            _ = try await store.append(entry(id: "p\(index)", timestamp: Int64(100 + index)))
        }
        clock.value = 1_000 + BASEventLogRecoveryRetention.minimumIngestionAgeMs + 1
        let pruned = try await store.pruneEventsBefore(timestampMs: 101)
        XCTAssertEqual(pruned, 1)

        let recovered = try await store.recoveryEvents(
            forSession: "session", limits: generousLimits(), integrity: .recordedChain)
        XCTAssertEqual(recovered.map(\.eventID), ["p1", "p2"])
    }

    func testRecordedChainChargesMatchingEvidenceToTheSamePerEventBudget() async throws {
        BASSQLiteEventLogStorage.rowIntegrityChainEnabled = true
        let url = databaseURL("chain-budget.sqlite")
        let store = try BASSQLiteEventLogStorage(databaseURL: url)
        _ = try await store.append(entry(id: "budgeted", timestamp: 100))
        let eventBytes = try XCTUnwrap(encodedEventRowBytes(url, session: "session").first)
        let integrityBytes = try XCTUnwrap(
            encodedIntegrityRowBytes(url, session: "session").first)
        let combined = eventBytes + integrityBytes

        let exact = try await store.recoveryEvents(
            forSession: "session",
            limits: try limits(count: 1, row: combined, total: combined),
            integrity: .recordedChain)
        XCTAssertEqual(exact.count, 1)
        await assertRecoveryError(.eventByteLimitExceeded) {
            try await store.recoveryEvents(
                forSession: "session",
                limits: try self.limits(count: 1, row: combined - 1, total: combined),
                integrity: .recordedChain)
        }
    }

    func testCloseObserverAndReopenPreserveRecoveryEquality() async throws {
        let closes = LockedCounter()
        let url = databaseURL("reopen.sqlite")
        let expected = withSequence(entry(id: "persisted", timestamp: 100), 0)
        var store: BASSQLiteEventLogStorage? = try BASSQLiteEventLogStorage(
            databaseURL: url, nowMs: { 1_000 }, closeObserver: closes.increment)
        _ = try await store?.append(entry(id: "persisted", timestamp: 100))
        let firstRead = try await store?.recoveryEvents(
            forSession: "session", limits: generousLimits(), integrity: .none)
        XCTAssertEqual(firstRead, [expected])
        store = nil
        XCTAssertEqual(closes.value, 1, "the original SQLite handle closes before reopen")

        let reopened = try BASSQLiteEventLogStorage(databaseURL: url)
        let reopenedRead = try await reopened.recoveryEvents(
            forSession: "session", limits: generousLimits(), integrity: .none)
        XCTAssertEqual(reopenedRead, [expected])
    }

    private enum Corruption: String, CaseIterable {
        case malformedJSON
        case unknownFormat
        case invalidUTF8
        case identityMismatch
    }

    private func databaseURL(_ name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    private func entry(
        id: String,
        session: String = "session",
        timestamp: Int64,
        sequence: Int64 = 0
    ) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: id, timestampMs: timestamp, kind: .chat,
            sessionID: session, sequenceNumber: sequence,
            source: "source-世界", turnRef: "turn-1", rawInputDigest: "digest",
            intent: "ask", emotion: "calm", riskBand: .medium, project: "project",
            memoryRefs: ["memory,one", "memory-two"],
            stateBeforeID: "before", stateAfterID: "after",
            actions: ["answer", "audit,record"], confidence: 0.75,
            payloadJson: #"{"key":"value"}"#)
    }

    private func withSequence(_ entry: BASEventLogEntry, _ sequence: Int64) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: entry.eventID, timestampMs: entry.timestampMs, kind: entry.kind,
            sessionID: entry.sessionID, sequenceNumber: sequence,
            source: entry.source, turnRef: entry.turnRef,
            rawInputDigest: entry.rawInputDigest, intent: entry.intent,
            emotion: entry.emotion, riskBand: entry.riskBand, project: entry.project,
            memoryRefs: entry.memoryRefs, stateBeforeID: entry.stateBeforeID,
            stateAfterID: entry.stateAfterID, actions: entry.actions,
            confidence: entry.confidence, payloadJson: entry.payloadJson)
    }

    private func limits(count: Int, row: Int, total: Int) throws -> BASEventLogRecoveryReadLimits {
        try BASEventLogRecoveryReadLimits(
            maximumEventCount: count,
            maximumEncodedEventBytes: row,
            maximumTotalEncodedBytes: total)
    }

    private func generousLimits() -> BASEventLogRecoveryReadLimits {
        try! BASEventLogRecoveryReadLimits(
            maximumEventCount: 100,
            maximumEncodedEventBytes: 100_000,
            maximumTotalEncodedBytes: 1_000_000)
    }

    private func assertRecoveryError(
        _ expected: BASEventLogRecoveryReadError,
        operation: () async throws -> [BASEventLogEntry],
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await operation()
            XCTFail("expected recovery error \(expected)", file: file, line: line)
        } catch let error as BASEventLogRecoveryReadError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("expected recovery error \(expected), got \(error)", file: file, line: line)
        }
    }

    private func open(_ url: URL, flags: Int32 = SQLITE_OPEN_READWRITE) throws -> OpaquePointer {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(url.path, &db, flags, nil)
        guard rc == SQLITE_OK, let db else {
            if let db { sqlite3_close_v2(db) }
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: Int(rc))
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
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: Int(rc),
                userInfo: [NSLocalizedDescriptionKey: detail])
        }
    }

    private func cacheMisses(_ db: OpaquePointer) throws -> Int32 {
        var current: Int32 = 0
        var highwater: Int32 = 0
        let rc = sqlite3_db_status(
            db, SQLITE_DBSTATUS_CACHE_MISS, &current, &highwater, 0)
        guard rc == SQLITE_OK else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: Int(rc))
        }
        return current
    }

    private func databaseEncoding(_ url: URL) throws -> String {
        let db = try open(url, flags: SQLITE_OPEN_READONLY)
        defer { sqlite3_close_v2(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA encoding", -1, &stmt, nil) == SQLITE_OK,
              let stmt
        else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 11)
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let raw = sqlite3_column_text(stmt, 0)
        else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 12)
        }
        return String(cString: raw)
    }

    private func encodedEventRowBytes(_ url: URL, session: String) throws -> [Int] {
        let db = try open(url, flags: SQLITE_OPEN_READONLY)
        defer { sqlite3_close_v2(db) }
        let sql = """
            SELECT length(CAST(event_id AS BLOB))
                 + length(CAST(session_id AS BLOB))
                 + length(CAST(kind AS BLOB))
                 + length(CAST(risk_band AS BLOB))
                 + length(CAST(payload_json AS BLOB))
                 + COALESCE(length(payload_blob), 0)
            FROM event_log WHERE session_id=? ORDER BY sequence_number
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 1)
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, index: 1, value: session)
        var result: [Int] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { return result }
            guard rc == SQLITE_ROW else {
                throw NSError(domain: "BASEventLogRecoveryReadingTests", code: Int(rc))
            }
            result.append(Int(sqlite3_column_int64(stmt, 0)))
        }
    }

    private func utf8EncodedEventRowBytes(_ url: URL, session: String) throws -> [Int] {
        let db = try open(url, flags: SQLITE_OPEN_READONLY)
        defer { sqlite3_close_v2(db) }
        let sql = """
            SELECT event_id, session_id, kind, risk_band, payload_json
            FROM event_log WHERE session_id=? ORDER BY sequence_number
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 9)
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, index: 1, value: session)
        var result: [Int] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { return result }
            guard rc == SQLITE_ROW else {
                throw NSError(domain: "BASEventLogRecoveryReadingTests", code: Int(rc))
            }
            var bytes = 0
            for column in 0..<5 {
                guard sqlite3_column_text(stmt, Int32(column)) != nil else {
                    throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 10)
                }
                bytes += Int(sqlite3_column_bytes(stmt, Int32(column)))
            }
            result.append(bytes)
        }
    }

    private func encodedIntegrityRowBytes(_ url: URL, session: String) throws -> [Int] {
        let db = try open(url, flags: SQLITE_OPEN_READONLY)
        defer { sqlite3_close_v2(db) }
        let sql = """
            SELECT length(CAST(event_id AS BLOB))
                 + length(CAST(session_id AS BLOB))
                 + length(CAST(row_hash AS BLOB))
                 + length(CAST(prev_hash AS BLOB))
            FROM event_log_integrity WHERE session_id=? ORDER BY sequence_number
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 8)
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, index: 1, value: session)
        var result: [Int] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { return result }
            guard rc == SQLITE_ROW else {
                throw NSError(domain: "BASEventLogRecoveryReadingTests", code: Int(rc))
            }
            result.append(Int(sqlite3_column_int64(stmt, 0)))
        }
    }

    private func insertJSONRow(_ url: URL, entry: BASEventLogEntry) throws {
        let db = try open(url)
        defer { sqlite3_close_v2(db) }
        let sql = """
            INSERT INTO event_log
              (event_id,session_id,sequence_number,timestamp_ms,kind,risk_band,
               payload_json,payload_format,payload_blob,ingested_at_ms)
            VALUES (?,?,?,?,?,?,?,1,NULL,0)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 2)
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, index: 1, value: entry.eventID)
        bindText(stmt, index: 2, value: entry.sessionID)
        sqlite3_bind_int64(stmt, 3, entry.sequenceNumber)
        sqlite3_bind_int64(stmt, 4, entry.timestampMs)
        bindText(stmt, index: 5, value: entry.kind.rawValue)
        bindText(stmt, index: 6, value: entry.riskBand.rawValue)
        bindBytesAsText(stmt, index: 7, bytes: Array(try JSONEncoder().encode(entry)))
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 3)
        }
    }

    private func updatePayloadText(_ url: URL, eventID: String, bytes: [UInt8]) throws {
        let db = try open(url)
        defer { sqlite3_close_v2(db) }
        let sql = "UPDATE event_log SET payload_json=?, payload_format=1, payload_blob=NULL WHERE event_id=?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 4)
        }
        defer { sqlite3_finalize(stmt) }
        bindBytesAsText(stmt, index: 1, bytes: bytes)
        bindText(stmt, index: 2, value: eventID)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 5)
        }
    }

    private func updateBinaryPayload(_ url: URL, eventID: String, blob: Data) throws {
        let db = try open(url)
        defer { sqlite3_close_v2(db) }
        let sql = "UPDATE event_log SET payload_json='', payload_format=2, payload_blob=? WHERE event_id=?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 6)
        }
        defer { sqlite3_finalize(stmt) }
        _ = blob.withUnsafeBytes { raw in
            sqlite3_bind_blob(stmt, 1, raw.baseAddress, Int32(raw.count), transient)
        }
        bindText(stmt, index: 2, value: eventID)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw NSError(domain: "BASEventLogRecoveryReadingTests", code: 7)
        }
    }

    private func validBinaryEnvelope() -> [String: String] {
        [
            "riskBand": BASEventLogRiskBand.medium.rawValue,
            "source": "source-世界",
            "rawInputDigest": "digest",
            "intent": "ask",
            "emotion": "calm",
            "project": "project",
            "memoryRefs": #"["memory,one","memory-two"]"#,
            "stateBeforeID": "before",
            "stateAfterID": "after",
            "confidence": "0.75",
            "payloadJson": #"{"key":"value"}"#,
            "actions": #"["answer","audit,record"]"#,
        ]
    }

    private func binaryBlob(
        eventID: String,
        timestamp: Int64,
        turnRef: String,
        envelope: [String: String]
    ) throws -> Data {
        let envelopeData = try JSONEncoder().encode(envelope)
        let envelopeString = try XCTUnwrap(String(data: envelopeData, encoding: .utf8))
        return try BASEventLogBinaryCodec.encode(BASBinaryEventLogEntry(
            entryID: eventID,
            kind: .hostInput,
            sessionRef: "session",
            turnRef: turnRef,
            timestampMs: timestamp,
            payloadJson: envelopeString,
            provenanceSummary: nil))
    }

    private func bindText(_ stmt: OpaquePointer, index: Int32, value: String) {
        _ = value.utf8CString.withUnsafeBufferPointer { buffer in
            sqlite3_bind_text(stmt, index, buffer.baseAddress, Int32(buffer.count - 1), transient)
        }
    }

    private func bindBytesAsText(_ stmt: OpaquePointer, index: Int32, bytes: [UInt8]) {
        _ = bytes.withUnsafeBytes { raw in
            sqlite3_bind_text(stmt, index,
                raw.baseAddress?.assumingMemoryBound(to: CChar.self),
                Int32(raw.count), transient)
        }
    }

    private var transient: sqlite3_destructor_type {
        unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int { lock.withLock { storage } }
    func increment() { lock.withLock { storage += 1 } }
}

private final class LockedClock: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Int64

    init(_ value: Int64) { storage = value }
    var value: Int64 {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
    func now() -> Int64 { value }
}
