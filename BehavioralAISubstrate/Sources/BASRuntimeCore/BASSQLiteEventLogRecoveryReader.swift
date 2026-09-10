import Foundation
import SQLite3

/// Synchronous, non-owning reader used only while its storage actor is isolated.
/// The actor retains connection ownership; this value never closes or exposes it.
struct BASSQLiteEventLogRecoveryReader {
    private let db: OpaquePointer

    private enum DatabaseTextEncoding {
        case utf8
        case utf16LittleEndian
        case utf16BigEndian
    }

    init(db: OpaquePointer) {
        self.db = db
    }

    func read(
        sessionID: String,
        limits: BASEventLogRecoveryReadLimits,
        integrity: BASEventLogRecoveryIntegrityRequirement
    ) throws -> [BASEventLogEntry] {
        try execute("BEGIN DEFERRED;")
        do {
            let textEncoding = try databaseTextEncoding()
            var chargedBytes = 0
            let eventRowBytes = try preflightEvents(
                sessionID: sessionID,
                textEncoding: textEncoding,
                limits: limits,
                chargedBytes: &chargedBytes)
            let hasIntegrityTable: Bool
            switch integrity {
            case .none:
                hasIntegrityTable = false
            case .recordedChain:
                hasIntegrityTable = try preflightIntegrity(
                    sessionID: sessionID,
                    eventRowBytes: eventRowBytes,
                    textEncoding: textEncoding,
                    limits: limits,
                    chargedBytes: &chargedBytes)
            }

            let entries = try decodeEvents(
                sessionID: sessionID,
                expectedCount: eventRowBytes.count,
                limit: limits.maximumEventCount + 1)
            if integrity == .recordedChain {
                try verifyRecordedChain(
                    sessionID: sessionID,
                    entries: entries,
                    tableExists: hasIntegrityTable,
                    limit: limits.maximumEventCount + 1)
            }
            try execute("COMMIT;")
            return entries
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    private func preflightEvents(
        sessionID: String,
        textEncoding: DatabaseTextEncoding,
        limits: BASEventLogRecoveryReadLimits,
        chargedBytes: inout Int
    ) throws -> [Int] {
        let sql = """
            SELECT rowid,
                   typeof(event_id), typeof(session_id),
                   typeof(sequence_number), typeof(timestamp_ms),
                   typeof(kind), typeof(risk_band), typeof(payload_json),
                   typeof(payload_format),
                   CASE WHEN typeof(payload_format) = 'integer'
                        THEN payload_format ELSE NULL END,
                   typeof(payload_blob)
            FROM event_log
            WHERE session_id = ?
            ORDER BY sequence_number ASC
            LIMIT ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: sessionID)
        sqlite3_bind_int64(stmt, 2, Int64(limits.maximumEventCount + 1))

        var rowByteCounts: [Int] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { return rowByteCounts }
            guard rc == SQLITE_ROW else { throw stepError(sql) }
            guard rowByteCounts.count < limits.maximumEventCount else {
                throw BASEventLogRecoveryReadError.eventCountLimitExceeded
            }

            guard sqlite3_column_type(stmt, 0) == SQLITE_INTEGER,
                  try metadataText(stmt, 1) == "text",
                  try metadataText(stmt, 2) == "text",
                  try metadataText(stmt, 3) == "integer",
                  try metadataText(stmt, 4) == "integer",
                  try metadataText(stmt, 5) == "text",
                  try metadataText(stmt, 6) == "text",
                  try metadataText(stmt, 7) == "text",
                  try metadataText(stmt, 8) == "integer",
                  sqlite3_column_type(stmt, 9) == SQLITE_INTEGER
            else {
                throw BASEventLogRecoveryReadError.malformedRecord
            }
            let rowID = sqlite3_column_int64(stmt, 0)
            let format = sqlite3_column_int64(stmt, 9)
            let blobType = try metadataText(stmt, 10)
            switch format {
            case 1:
                guard blobType == "null" else {
                    throw BASEventLogRecoveryReadError.malformedRecord
                }
            case 2:
                guard blobType == "blob" else {
                    throw BASEventLogRecoveryReadError.malformedRecord
                }
            default:
                throw BASEventLogRecoveryReadError.unsupportedRecord
            }
            var rowBytes = 0
            for column in ["event_id", "session_id", "kind", "risk_band"] {
                try addColumnBytes(
                    table: "event_log", column: column, rowID: rowID,
                    isText: true, textEncoding: textEncoding,
                    rowBytes: &rowBytes, chargedBytes: chargedBytes, limits: limits)
            }
            let jsonBytes = try addColumnBytes(
                table: "event_log", column: "payload_json", rowID: rowID,
                isText: true, textEncoding: textEncoding,
                rowBytes: &rowBytes, chargedBytes: chargedBytes, limits: limits)
            var blobBytes = 0
            if format == 2 {
                blobBytes = try addColumnBytes(
                    table: "event_log", column: "payload_blob", rowID: rowID,
                    isText: false, textEncoding: textEncoding,
                    rowBytes: &rowBytes, chargedBytes: chargedBytes, limits: limits)
                guard jsonBytes == 0, blobBytes > 0 else {
                    throw BASEventLogRecoveryReadError.malformedRecord
                }
            }
            try charge(
                rowBytes: rowBytes,
                limits: limits,
                chargedBytes: &chargedBytes)
            rowByteCounts.append(rowBytes)
        }
    }

    private func preflightIntegrity(
        sessionID: String,
        eventRowBytes: [Int],
        textEncoding: DatabaseTextEncoding,
        limits: BASEventLogRecoveryReadLimits,
        chargedBytes: inout Int
    ) throws -> Bool {
        guard try integrityTableExists() else { return false }
        let sql = """
            SELECT rowid,
                   typeof(event_id), typeof(session_id),
                   typeof(sequence_number),
                   typeof(row_hash), typeof(prev_hash)
            FROM event_log_integrity
            WHERE session_id = ?
            ORDER BY sequence_number ASC
            LIMIT ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: sessionID)
        sqlite3_bind_int64(stmt, 2, Int64(limits.maximumEventCount + 1))

        var count = 0
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { return true }
            guard rc == SQLITE_ROW else { throw stepError(sql) }
            count += 1
            guard count <= limits.maximumEventCount else {
                throw BASEventLogRecoveryReadError.eventCountLimitExceeded
            }
            guard sqlite3_column_type(stmt, 0) == SQLITE_INTEGER,
                  try metadataText(stmt, 1) == "text",
                  try metadataText(stmt, 2) == "text",
                  try metadataText(stmt, 3) == "integer",
                  try metadataText(stmt, 4) == "text",
                  try metadataText(stmt, 5) == "text"
            else {
                throw BASEventLogRecoveryReadError.invalidIntegrity
            }
            let rowID = sqlite3_column_int64(stmt, 0)
            let eventBytes = count <= eventRowBytes.count
                ? eventRowBytes[count - 1]
                : 0
            var combinedRowBytes = eventBytes
            for column in ["event_id", "session_id", "row_hash", "prev_hash"] {
                try addColumnBytes(
                    table: "event_log_integrity", column: column, rowID: rowID,
                    isText: true, textEncoding: textEncoding,
                    rowBytes: &combinedRowBytes,
                    aggregateRowBase: eventBytes,
                    malformedError: .invalidIntegrity,
                    chargedBytes: chargedBytes, limits: limits)
            }
            let rowBytes = combinedRowBytes - eventBytes
            try chargeTotal(
                additionalBytes: rowBytes,
                limit: limits.maximumTotalEncodedBytes,
                chargedBytes: &chargedBytes)
        }
    }

    private func decodeEvents(
        sessionID: String,
        expectedCount: Int,
        limit: Int
    ) throws -> [BASEventLogEntry] {
        let sql = """
            SELECT event_id, session_id, sequence_number, timestamp_ms,
                   kind, risk_band, payload_json, payload_format, payload_blob
            FROM event_log
            WHERE session_id = ?
            ORDER BY sequence_number ASC
            LIMIT ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: sessionID)
        sqlite3_bind_int64(stmt, 2, Int64(limit))

        var entries: [BASEventLogEntry] = []
        entries.reserveCapacity(expectedCount)
        var previousSequence: Int64?
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw stepError(sql) }
            guard entries.count < expectedCount else {
                throw BASEventLogRecoveryReadError.malformedRecord
            }
            let entry = try decodeEventRow(stmt)
            guard entry.sessionID == sessionID,
                  entry.sequenceNumber >= 0,
                  previousSequence.map({ $0 < entry.sequenceNumber }) ?? true
            else {
                throw BASEventLogRecoveryReadError.malformedRecord
            }
            previousSequence = entry.sequenceNumber
            entries.append(entry)
        }
        guard entries.count == expectedCount else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        return entries
    }

    private func decodeEventRow(_ stmt: OpaquePointer) throws -> BASEventLogEntry {
        let eventID = try text(stmt, 0)
        let sessionID = try text(stmt, 1)
        guard sqlite3_column_type(stmt, 2) == SQLITE_INTEGER,
              sqlite3_column_type(stmt, 3) == SQLITE_INTEGER,
              sqlite3_column_type(stmt, 7) == SQLITE_INTEGER
        else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        let sequence = sqlite3_column_int64(stmt, 2)
        let timestamp = sqlite3_column_int64(stmt, 3)
        let kindRaw = try text(stmt, 4)
        let riskRaw = try text(stmt, 5)
        guard let kind = BASEventLogKind(rawValue: kindRaw),
              let risk = BASEventLogRiskBand(rawValue: riskRaw)
        else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }

        let format = sqlite3_column_int64(stmt, 7)
        let entry: BASEventLogEntry
        switch format {
        case 1:
            guard sqlite3_column_type(stmt, 6) == SQLITE_TEXT,
                  sqlite3_column_type(stmt, 8) == SQLITE_NULL
            else {
                throw BASEventLogRecoveryReadError.malformedRecord
            }
            let json = try textData(stmt, 6)
            do {
                entry = try JSONDecoder().decode(BASEventLogEntry.self, from: json)
            } catch {
                throw BASEventLogRecoveryReadError.malformedRecord
            }
        case 2:
            guard try text(stmt, 6).isEmpty,
                  sqlite3_column_type(stmt, 8) == SQLITE_BLOB,
                  sqlite3_column_bytes(stmt, 8) > 0
            else {
                throw BASEventLogRecoveryReadError.malformedRecord
            }
            entry = try decodeBinary(
                try blob(stmt, 8),
                eventID: eventID,
                sessionID: sessionID,
                sequence: sequence,
                timestamp: timestamp,
                kind: kind,
                risk: risk)
        default:
            throw BASEventLogRecoveryReadError.unsupportedRecord
        }
        guard entry.eventID == eventID,
              entry.sessionID == sessionID,
              entry.sequenceNumber == sequence,
              entry.timestampMs == timestamp,
              entry.kind == kind,
              entry.riskBand == risk,
              entry.confidence.isFinite,
              (0...1).contains(entry.confidence)
        else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        return entry
    }

    private func decodeBinary(
        _ data: Data,
        eventID: String,
        sessionID: String,
        sequence: Int64,
        timestamp: Int64,
        kind: BASEventLogKind,
        risk: BASEventLogRiskBand
    ) throws -> BASEventLogEntry {
        let binary: BASBinaryEventLogEntry
        do {
            binary = try BASEventLogBinaryCodec.decode(data)
            guard try BASEventLogBinaryCodec.encode(binary) == data else {
                throw BASEventLogRecoveryReadError.malformedRecord
            }
        } catch let error as BASEventLogRecoveryReadError {
            throw error
        } catch {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        guard binary.entryID == eventID,
              binary.sessionRef == sessionID,
              binary.timestampMs == timestamp,
              binary.kind == BASSQLiteEventLogStorage.binaryKind(for: kind),
              binary.provenanceSummary == nil,
              let payload = binary.payloadJson
        else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }

        let envelope: [String: String]
        do {
            envelope = try BASSQLiteEventLogStorage.decodePayloadEnvelope(payload)
        } catch {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        let requiredKeys: Set<String> = [
            "riskBand", "source", "rawInputDigest", "intent", "emotion",
            "project", "memoryRefs", "stateBeforeID", "stateAfterID",
            "confidence", "payloadJson", "actions",
        ]
        guard requiredKeys.isSubset(of: Set(envelope.keys)),
              envelope["riskBand"] == risk.rawValue,
              let confidenceRaw = envelope["confidence"],
              let confidence = Double(confidenceRaw),
              confidence.isFinite,
              (0...1).contains(confidence),
              let memoryRefsRaw = envelope["memoryRefs"],
              let actionsRaw = envelope["actions"]
        else {
            throw BASEventLogRecoveryReadError.unsupportedRecord
        }
        let optionalKeys = [
            "source", "rawInputDigest", "intent", "emotion", "project",
            "stateBeforeID", "stateAfterID", "payloadJson",
        ]
        guard !binary.turnRef.isEmpty,
              optionalKeys.allSatisfy({ envelope[$0]?.isEmpty == false })
        else {
            throw BASEventLogRecoveryReadError.unsupportedRecord
        }
        let memoryRefs = try decodeStringArray(
            memoryRefsRaw, allowLegacyCommaSeparated: true)
        let actions = try decodeStringArray(
            actionsRaw, allowLegacyCommaSeparated: false)
        return BASEventLogEntry(
            eventID: eventID,
            timestampMs: timestamp,
            kind: kind,
            sessionID: sessionID,
            sequenceNumber: sequence,
            source: optional(envelope["source"]),
            turnRef: binary.turnRef.isEmpty ? nil : binary.turnRef,
            rawInputDigest: optional(envelope["rawInputDigest"]),
            intent: optional(envelope["intent"]),
            emotion: optional(envelope["emotion"]),
            riskBand: risk,
            project: optional(envelope["project"]),
            memoryRefs: memoryRefs,
            stateBeforeID: optional(envelope["stateBeforeID"]),
            stateAfterID: optional(envelope["stateAfterID"]),
            actions: actions,
            confidence: confidence,
            payloadJson: optional(envelope["payloadJson"]))
    }

    private func decodeStringArray(
        _ value: String,
        allowLegacyCommaSeparated: Bool
    ) throws -> [String] {
        if value.isEmpty {
            guard allowLegacyCommaSeparated else {
                throw BASEventLogRecoveryReadError.malformedRecord
            }
            return []
        }
        if let data = value.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data)
        {
            return decoded
        }
        guard allowLegacyCommaSeparated,
              !value.hasPrefix("[")
        else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        return value.split(separator: ",").map(String.init)
    }

    private func verifyRecordedChain(
        sessionID: String,
        entries: [BASEventLogEntry],
        tableExists: Bool,
        limit: Int
    ) throws {
        guard tableExists else {
            if entries.isEmpty { return }
            throw BASEventLogRecoveryReadError.missingIntegrity
        }
        let rows = try integrityRows(sessionID: sessionID, limit: limit)
        if rows.count < entries.count {
            throw BASEventLogRecoveryReadError.missingIntegrity
        }
        guard rows.count == entries.count else {
            throw BASEventLogRecoveryReadError.invalidIntegrity
        }
        var previousHash: String?
        for (entry, row) in zip(entries, rows) {
            guard row.eventID == entry.eventID,
                  row.sessionID == entry.sessionID,
                  row.sequence == entry.sequenceNumber,
                  isDigest(row.rowHash),
                  row.prevHash.isEmpty || isDigest(row.prevHash),
                  previousHash.map({ $0 == row.prevHash }) ?? true
            else {
                throw BASEventLogRecoveryReadError.invalidIntegrity
            }
            let expected: String
            do {
                expected = try BASSQLiteEventLogStorage.integrityHash(
                    entry: entry, prevHash: row.prevHash)
            } catch {
                throw BASEventLogRecoveryReadError.invalidIntegrity
            }
            guard expected == row.rowHash else {
                throw BASEventLogRecoveryReadError.invalidIntegrity
            }
            previousHash = row.rowHash
        }
    }

    private struct IntegrityRow {
        let eventID: String
        let sessionID: String
        let sequence: Int64
        let rowHash: String
        let prevHash: String
    }

    private func integrityRows(sessionID: String, limit: Int) throws -> [IntegrityRow] {
        let sql = """
            SELECT event_id, session_id, sequence_number, row_hash, prev_hash
            FROM event_log_integrity
            WHERE session_id = ?
            ORDER BY sequence_number ASC
            LIMIT ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bindText(stmt, index: 1, value: sessionID)
        sqlite3_bind_int64(stmt, 2, Int64(limit))
        var rows: [IntegrityRow] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { return rows }
            guard rc == SQLITE_ROW,
                  sqlite3_column_type(stmt, 2) == SQLITE_INTEGER
            else {
                if rc != SQLITE_ROW { throw stepError(sql) }
                throw BASEventLogRecoveryReadError.invalidIntegrity
            }
            rows.append(IntegrityRow(
                eventID: try text(stmt, 0),
                sessionID: try text(stmt, 1),
                sequence: sqlite3_column_int64(stmt, 2),
                rowHash: try text(stmt, 3),
                prevHash: try text(stmt, 4)))
        }
    }

    private func integrityTableExists() throws -> Bool {
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name='event_log_integrity' LIMIT 1"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return false }
        guard rc == SQLITE_ROW else { throw stepError(sql) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw stepError(sql) }
        return true
    }

    private func databaseTextEncoding() throws -> DatabaseTextEncoding {
        let sql = "PRAGMA encoding"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw stepError(sql) }
        let value = try text(stmt, 0).lowercased()
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw stepError(sql) }
        switch value {
        case "utf-8":
            return .utf8
        case "utf-16le":
            return .utf16LittleEndian
        case "utf-16be":
            return .utf16BigEndian
        default:
            throw BASEventLogRecoveryReadError.unsupportedRecord
        }
    }

    @discardableResult
    private func addColumnBytes(
        table: String,
        column: String,
        rowID: Int64,
        isText: Bool,
        textEncoding: DatabaseTextEncoding,
        rowBytes: inout Int,
        aggregateRowBase: Int = 0,
        malformedError: BASEventLogRecoveryReadError = .malformedRecord,
        chargedBytes: Int,
        limits: BASEventLogRecoveryReadLimits
    ) throws -> Int {
        let rowRemaining = limits.maximumEncodedEventBytes - rowBytes
        guard rowBytes >= aggregateRowBase else {
            throw BASEventLogRecoveryReadError.totalByteLimitExceeded
        }
        let aggregateRowBytes = rowBytes - aggregateRowBase
        let totalAlready = try adding(chargedBytes, aggregateRowBytes)
        let totalRemaining = limits.maximumTotalEncodedBytes - totalAlready
        guard rowRemaining >= 0 else {
            throw BASEventLogRecoveryReadError.eventByteLimitExceeded
        }
        guard totalRemaining >= 0 else {
            throw BASEventLogRecoveryReadError.totalByteLimitExceeded
        }
        let cutoff = min(rowRemaining, totalRemaining)
        let exceededError: BASEventLogRecoveryReadError =
            rowRemaining <= totalRemaining
            ? .eventByteLimitExceeded
            : .totalByteLimitExceeded
        let length = try columnUTF8Length(
            table: table,
            column: column,
            rowID: rowID,
            isText: isText,
            textEncoding: textEncoding,
            cutoff: cutoff,
            malformedError: malformedError,
            exceededError: exceededError)
        rowBytes = try adding(rowBytes, length)
        return length
    }

    private func columnUTF8Length(
        table: String,
        column: String,
        rowID: Int64,
        isText: Bool,
        textEncoding: DatabaseTextEncoding,
        cutoff: Int,
        malformedError: BASEventLogRecoveryReadError,
        exceededError: BASEventLogRecoveryReadError
    ) throws -> Int {
        var handle: OpaquePointer?
        let openRC = sqlite3_blob_open(
            db, "main", table, column, rowID, 0, &handle)
        guard openRC == SQLITE_OK, let handle else {
            if let handle { sqlite3_blob_close(handle) }
            throw BASSQLiteEventLogStorage.StorageError.stepFailed(
                sql: "read recovery byte length for \(table).\(column)",
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_blob_close(handle) }
        let storedBytes = Int(sqlite3_blob_bytes(handle))
        guard storedBytes >= 0 else {
            throw malformedError
        }
        guard isText else {
            guard storedBytes <= cutoff else { throw exceededError }
            return storedBytes
        }
        switch textEncoding {
        case .utf8:
            guard storedBytes <= cutoff else { throw exceededError }
            return storedBytes
        case .utf16LittleEndian:
            return try utf8LengthOfUTF16Blob(
                handle, storedBytes: storedBytes, littleEndian: true,
                cutoff: cutoff, malformedError: malformedError,
                exceededError: exceededError)
        case .utf16BigEndian:
            return try utf8LengthOfUTF16Blob(
                handle, storedBytes: storedBytes, littleEndian: false,
                cutoff: cutoff, malformedError: malformedError,
                exceededError: exceededError)
        }
    }

    private func utf8LengthOfUTF16Blob(
        _ handle: OpaquePointer,
        storedBytes: Int,
        littleEndian: Bool,
        cutoff: Int,
        malformedError: BASEventLogRecoveryReadError,
        exceededError: BASEventLogRecoveryReadError
    ) throws -> Int {
        if storedBytes > 0, cutoff == 0 { throw exceededError }
        guard storedBytes.isMultiple(of: 2) else {
            throw malformedError
        }
        let chunkCapacity = 4_096
        var buffer = [UInt8](repeating: 0, count: chunkCapacity)
        var offset = 0
        var utf8Bytes = 0
        var pendingHighSurrogate: UInt16?

        while offset < storedBytes {
            let count = min(chunkCapacity, storedBytes - offset)
            let readRC = buffer.withUnsafeMutableBytes { raw in
                sqlite3_blob_read(handle, raw.baseAddress, Int32(count), Int32(offset))
            }
            guard readRC == SQLITE_OK else {
                throw BASSQLiteEventLogStorage.StorageError.stepFailed(
                    sql: "read bounded UTF-16 recovery length",
                    message: String(cString: sqlite3_errmsg(db)))
            }
            var index = 0
            while index < count {
                let unit: UInt16
                if littleEndian {
                    unit = UInt16(buffer[index]) | (UInt16(buffer[index + 1]) << 8)
                } else {
                    unit = (UInt16(buffer[index]) << 8) | UInt16(buffer[index + 1])
                }
                index += 2

                let scalarBytes: Int
                if let high = pendingHighSurrogate {
                    guard (0xDC00...0xDFFF).contains(unit),
                          (0xD800...0xDBFF).contains(high)
                    else {
                        throw malformedError
                    }
                    pendingHighSurrogate = nil
                    scalarBytes = 4
                } else if (0xD800...0xDBFF).contains(unit) {
                    pendingHighSurrogate = unit
                    continue
                } else {
                    guard !(0xDC00...0xDFFF).contains(unit) else {
                        throw malformedError
                    }
                    if unit <= 0x7F {
                        scalarBytes = 1
                    } else if unit <= 0x7FF {
                        scalarBytes = 2
                    } else {
                        scalarBytes = 3
                    }
                }
                utf8Bytes = try adding(utf8Bytes, scalarBytes)
                guard utf8Bytes <= cutoff else { throw exceededError }
            }
            offset += count
        }
        guard pendingHighSurrogate == nil else {
            throw malformedError
        }
        return utf8Bytes
    }

    private func adding(_ lhs: Int, _ rhs: Int) throws -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else {
            throw BASEventLogRecoveryReadError.totalByteLimitExceeded
        }
        return sum
    }

    private func charge(
        rowBytes: Int,
        limits: BASEventLogRecoveryReadLimits,
        chargedBytes: inout Int
    ) throws {
        guard rowBytes <= limits.maximumEncodedEventBytes else {
            throw BASEventLogRecoveryReadError.eventByteLimitExceeded
        }
        try chargeTotal(
            additionalBytes: rowBytes,
            limit: limits.maximumTotalEncodedBytes,
            chargedBytes: &chargedBytes)
    }

    private func chargeTotal(
        additionalBytes: Int,
        limit: Int,
        chargedBytes: inout Int
    ) throws {
        let (newTotal, overflow) = chargedBytes.addingReportingOverflow(additionalBytes)
        guard !overflow, newTotal <= limit else {
            throw BASEventLogRecoveryReadError.totalByteLimitExceeded
        }
        chargedBytes = newTotal
    }

    private func metadataText(_ stmt: OpaquePointer, _ column: Int32) throws -> String {
        try text(stmt, column)
    }

    private func text(_ stmt: OpaquePointer, _ column: Int32) throws -> String {
        guard sqlite3_column_type(stmt, column) == SQLITE_TEXT else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        let data = try textData(stmt, column)
        guard let result = String(data: data, encoding: .utf8) else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        return result
    }

    private func textData(_ stmt: OpaquePointer, _ column: Int32) throws -> Data {
        let count = Int(sqlite3_column_bytes(stmt, column))
        guard count >= 0 else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        if count == 0 { return Data() }
        guard let pointer = sqlite3_column_text(stmt, column) else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        return Data(bytes: pointer, count: count)
    }

    private func blob(_ stmt: OpaquePointer, _ column: Int32) throws -> Data {
        let count = Int(sqlite3_column_bytes(stmt, column))
        guard count > 0, let pointer = sqlite3_column_blob(stmt, column) else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        return Data(bytes: pointer, count: count)
    }

    private func optional(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private func isDigest(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        return bytes.count == 64 && bytes.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt
        else {
            throw BASSQLiteEventLogStorage.StorageError.prepareFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        return stmt
    }

    private func bindText(
        _ stmt: OpaquePointer,
        index: Int32,
        value: String
    ) throws {
        let bytes = Array(value.utf8)
        guard bytes.count <= Int(Int32.max) else {
            throw BASEventLogRecoveryReadError.malformedRecord
        }
        let rc = bytes.withUnsafeBytes { raw in
            sqlite3_bind_text(
                stmt,
                index,
                raw.baseAddress?.assumingMemoryBound(to: CChar.self),
                Int32(raw.count),
                transient)
        }
        guard rc == SQLITE_OK else {
            throw BASSQLiteEventLogStorage.StorageError.prepareFailed(
                sql: "bind recovery session identity",
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    private func execute(_ sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &message)
        guard rc == SQLITE_OK else {
            let detail = message.map { String(cString: $0) } ?? "sqlite3_exec rc=\(rc)"
            if let message { sqlite3_free(message) }
            throw BASSQLiteEventLogStorage.StorageError.prepareFailed(
                sql: sql, message: detail)
        }
    }

    private func stepError(_ sql: String) -> BASSQLiteEventLogStorage.StorageError {
        .stepFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
    }

    private var transient: sqlite3_destructor_type {
        unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
    }
}
