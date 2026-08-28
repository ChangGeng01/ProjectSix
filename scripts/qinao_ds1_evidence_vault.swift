import Foundation
import CryptoKit
import Security
import SQLite3
import Darwin

// A deliberately dependency-free, macOS-native custody tool for the first
// successful Deep Scan.  Plain SQLite bytes exist only in process memory.

private let envelopeMagic = Data("QDS1ENC1".utf8)
private let payloadMagic = Data("QDS1PAY1".utf8)
private let formatVersion = 1
private let scanNumber = 1
private let expectedOccurrenceCount = 111
private let expectedLocationCount = 2_716
private let encryptionService = "com.qinao.evidence-vault.encryption"
private let commitmentService = "com.qinao.evidence-vault.commitment"
private let keyAccessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private enum VaultError: Error, CustomStringConvertible {
    case usage(String)
    case failed(String)

    var description: String {
        switch self {
        case .usage(let message), .failed(let message): return message
        }
    }
}

private func fail(_ code: String) -> VaultError {
    .failed(code)
}

private extension Data {
    mutating func appendUInt32BE(_ value: UInt32) {
        var big = value.bigEndian
        Swift.withUnsafeBytes(of: &big) { append(contentsOf: $0) }
    }

    mutating func appendUInt64BE(_ value: UInt64) {
        var big = value.bigEndian
        Swift.withUnsafeBytes(of: &big) { append(contentsOf: $0) }
    }

    mutating func appendInt64BE(_ value: Int64) {
        appendUInt64BE(UInt64(bitPattern: value))
    }

    func uint64BE(at offset: Int) throws -> UInt64 {
        guard offset >= 0, count - offset >= 8 else { throw fail("truncated_uint64") }
        var value: UInt64 = 0
        for byte in self[offset..<(offset + 8)] {
            value = (value << 8) | UInt64(byte)
        }
        return value
    }

    var sha256Data: Data { Data(SHA256.hash(data: self)) }
    var sha256Hex: String { sha256Data.hex }

    var hex: String { map { String(format: "%02x", $0) }.joined() }

    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var result = Data()
        result.reserveCapacity(hex.count / 2)
        var cursor = hex.startIndex
        while cursor < hex.endIndex {
            let next = hex.index(cursor, offsetBy: 2)
            guard let byte = UInt8(hex[cursor..<next], radix: 16) else { return nil }
            result.append(byte)
            cursor = next
        }
        self = result
    }
}

private func canonicalJSON(_ object: Any) throws -> Data {
    guard JSONSerialization.isValidJSONObject(object) else { throw fail("invalid_json_object") }
    return try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
}

private func parseJSONObject(_ data: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw fail("json_root_not_object")
    }
    return object
}

private func printJSON(_ object: [String: Any]) throws {
    let data = try canonicalJSON(object)
    guard let text = String(data: data, encoding: .utf8) else { throw fail("json_utf8") }
    FileHandle.standardOutput.write(Data((text + "\n").utf8))
}

private func utcTimestamp() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: Date())
}

private func randomBytes(count: Int) throws -> Data {
    var data = Data(count: count)
    let status = data.withUnsafeMutableBytes { raw -> Int32 in
        guard let base = raw.baseAddress else { return errSecParam }
        return SecRandomCopyBytes(kSecRandomDefault, count, base)
    }
    guard status == errSecSuccess else { throw fail("secure_random_failed") }
    return data
}

private func loadOrCreateKey(service: String, account: String, create: Bool) throws -> Data {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecAttrSynchronizable: kCFBooleanFalse as Any,
        kSecReturnData: kCFBooleanTrue as Any,
        kSecMatchLimit: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecSuccess {
        guard let key = result as? Data, key.count == 32 else { throw fail("keychain_key_shape") }
        return key
    }
    guard status == errSecItemNotFound, create else { throw fail("keychain_key_unavailable") }

    let key = try randomBytes(count: 32)
    let add: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecAttrLabel: "Qinao Deep Scan #1 evidence key \(account)",
        kSecAttrSynchronizable: kCFBooleanFalse as Any,
        kSecAttrAccessible: keyAccessibility,
        kSecValueData: key,
    ]
    let addStatus = SecItemAdd(add as CFDictionary, nil)
    if addStatus == errSecSuccess { return key }
    if addStatus == errSecDuplicateItem {
        return try loadOrCreateKey(service: service, account: account, create: false)
    }
    throw fail("keychain_add_failed")
}

private func domainKey(master: Data, epoch: String, erasureScope: String, domain: String) -> SymmetricKey {
    let salt = Data("qinao-ds1/v1\u{0}\(epoch)\u{0}\(erasureScope)".utf8).sha256Data
    return HKDF<SHA256>.deriveKey(
        inputKeyMaterial: SymmetricKey(data: master),
        salt: salt,
        info: Data(domain.utf8),
        outputByteCount: 32
    )
}

private func keyedCommitment(
    master: Data,
    epoch: String,
    erasureScope: String,
    domain: String,
    scanID: String,
    targetRevision: String,
    context: String,
    bytes: Data
) -> String {
    let key = domainKey(master: master, epoch: epoch, erasureScope: erasureScope, domain: domain)
    var framed = Data("qinao-ds1-keyed-commitment/v1".utf8)
    for value in [domain, scanID, targetRevision, context] {
        let encoded = Data(value.utf8)
        framed.appendUInt64BE(UInt64(encoded.count))
        framed.append(encoded)
    }
    framed.appendUInt64BE(UInt64(bytes.count))
    framed.append(bytes)
    return Data(HMAC<SHA256>.authenticationCode(for: framed, using: key)).hex
}

private enum SQLiteValue: Equatable {
    case null
    case integer(Int64)
    case real(UInt64)
    case text(Data)
    case blob(Data)

    func appendCanonical(to output: inout Data) throws {
        switch self {
        case .null:
            output.append(0)
        case .integer(let value):
            output.append(1)
            output.appendInt64BE(value)
        case .real(let bits):
            let value = Double(bitPattern: bits)
            guard value.isFinite else { throw fail("non_finite_sqlite_real") }
            output.append(2)
            output.appendUInt64BE(bits)
        case .text(let bytes):
            guard String(data: bytes, encoding: .utf8) != nil else { throw fail("invalid_sqlite_utf8") }
            output.append(3)
            output.appendUInt64BE(UInt64(bytes.count))
            output.append(bytes)
        case .blob(let bytes):
            output.append(4)
            output.appendUInt64BE(UInt64(bytes.count))
            output.append(bytes)
        }
    }

    var textString: String? {
        guard case .text(let data) = self else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var integerValue: Int64? {
        guard case .integer(let value) = self else { return nil }
        return value
    }
}

private final class SQLiteDatabase {
    private(set) var handle: OpaquePointer?

    init(pathOrURI: String, flags: Int32) throws {
        var database: OpaquePointer?
        let status = sqlite3_open_v2(pathOrURI, &database, flags, nil)
        guard status == SQLITE_OK, let database else {
            if let database { sqlite3_close_v2(database) }
            throw fail("sqlite_open_failed")
        }
        handle = database
        sqlite3_extended_result_codes(database, 1)
        sqlite3_busy_timeout(database, 5_000)
    }

    deinit {
        if let handle { sqlite3_close_v2(handle) }
    }

    func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        if let errorMessage { sqlite3_free(errorMessage) }
        guard status == SQLITE_OK else { throw fail("sqlite_execute_failed") }
    }

    func query(_ sql: String, textBinding: String? = nil) throws -> [[SQLiteValue]] {
        var statement: OpaquePointer?
        let prepareStatus = sqlite3_prepare_v3(handle, sql, -1, UInt32(SQLITE_PREPARE_PERSISTENT), &statement, nil)
        guard prepareStatus == SQLITE_OK, let statement else {
            throw fail("sqlite_prepare_failed_\(prepareStatus)")
        }
        defer { sqlite3_finalize(statement) }
        if let textBinding {
            let index = sqlite3_bind_parameter_index(statement, ":scan_id")
            guard index > 0 else { throw fail("sqlite_missing_scan_binding") }
            let status = textBinding.withCString {
                sqlite3_bind_text(statement, index, $0, -1, transientDestructor)
            }
            guard status == SQLITE_OK else { throw fail("sqlite_bind_failed") }
        }

        var rows: [[SQLiteValue]] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return rows }
            guard status == SQLITE_ROW else { throw fail("sqlite_step_failed") }
            var row: [SQLiteValue] = []
            for index in 0..<sqlite3_column_count(statement) {
                switch sqlite3_column_type(statement, index) {
                case SQLITE_NULL:
                    row.append(.null)
                case SQLITE_INTEGER:
                    row.append(.integer(sqlite3_column_int64(statement, index)))
                case SQLITE_FLOAT:
                    row.append(.real(sqlite3_column_double(statement, index).bitPattern))
                case SQLITE_TEXT:
                    let count = Int(sqlite3_column_bytes(statement, index))
                    guard let pointer = sqlite3_column_text(statement, index) else {
                        throw fail("sqlite_text_pointer")
                    }
                    row.append(.text(Data(bytes: pointer, count: count)))
                case SQLITE_BLOB:
                    let count = Int(sqlite3_column_bytes(statement, index))
                    if count == 0 {
                        row.append(.blob(Data()))
                    } else {
                        guard let pointer = sqlite3_column_blob(statement, index) else {
                            throw fail("sqlite_blob_pointer")
                        }
                        row.append(.blob(Data(bytes: pointer, count: count)))
                    }
                default:
                    throw fail("sqlite_unknown_type")
                }
            }
            rows.append(row)
        }
    }

    func serialize() throws -> Data {
        var byteCount: sqlite3_int64 = 0
        guard let pointer = sqlite3_serialize(handle, "main", &byteCount, 0), byteCount > 0 else {
            throw fail("sqlite_serialize_failed")
        }
        defer { sqlite3_free(pointer) }
        return Data(bytes: pointer, count: Int(byteCount))
    }

    static func deserialize(_ bytes: Data) throws -> SQLiteDatabase {
        let database = try SQLiteDatabase(
            pathOrURI: ":memory:",
            flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        )
        guard let buffer = sqlite3_malloc64(sqlite3_uint64(bytes.count))?.assumingMemoryBound(to: UInt8.self) else {
            throw fail("sqlite_deserialize_allocation")
        }
        bytes.copyBytes(to: buffer, count: bytes.count)
        let flags = UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_READONLY)
        let status = sqlite3_deserialize(
            database.handle,
            "main",
            buffer,
            sqlite3_int64(bytes.count),
            sqlite3_int64(bytes.count),
            flags
        )
        guard status == SQLITE_OK else {
            sqlite3_free(buffer)
            throw fail("sqlite_deserialize_failed")
        }
        return database
    }
}

private func backupDatabase(sourcePath: String) throws -> Data {
    let source = try SQLiteDatabase(
        pathOrURI: sourcePath,
        flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
    )
    let destination = try SQLiteDatabase(
        pathOrURI: ":memory:",
        flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
    )
    guard let backup = sqlite3_backup_init(destination.handle, "main", source.handle, "main") else {
        throw fail("sqlite_backup_init_failed")
    }
    defer { sqlite3_backup_finish(backup) }
    let deadline = Date().addingTimeInterval(30)
    while true {
        let status = sqlite3_backup_step(backup, 256)
        if status == SQLITE_DONE { break }
        if status == SQLITE_OK { continue }
        if status == SQLITE_BUSY || status == SQLITE_LOCKED {
            guard Date() < deadline else { throw fail("sqlite_backup_timeout") }
            usleep(25_000)
            continue
        }
        throw fail("sqlite_backup_step_failed")
    }
    guard sqlite3_backup_remaining(backup) == 0 else { throw fail("sqlite_backup_incomplete") }
    // The source is WAL-backed.  A backup into an in-memory destination has no
    // sidecar, so normalize the destination journal state before serialization;
    // otherwise page 1 can retain WAL read/write-version bytes that require a
    // nonexistent SHM file when the serialized image is reopened.
    let journalRows = try destination.query("PRAGMA journal_mode=MEMORY;")
    guard journalRows.count == 1, journalRows[0].first?.textString == "memory" else {
        throw fail("sqlite_backup_journal_normalization")
    }
    var serialized = try destination.serialize()
    guard serialized.count > 100 else { throw fail("sqlite_backup_too_small") }
    // sqlite3_backup copies page 1 verbatim.  An in-memory destination cannot
    // own a WAL sidecar, and SQLite may leave the copied page-1 WAL markers at
    // offsets 18/19 even after switching its pager to OFF.  The backup already
    // contains the committed pages, so normalize only these documented file-
    // format bytes to the rollback-journal value before independent reopen.
    guard (serialized[18] == 1 && serialized[19] == 1)
            || (serialized[18] == 2 && serialized[19] == 2) else {
        throw fail("sqlite_backup_header_version")
    }
    serialized[18] = 1
    serialized[19] = 1
    return serialized
}

private struct QuerySpec {
    let id: String
    let columns: [String]
    let sql: String
}

private let querySpecs: [QuerySpec] = [
    QuerySpec(
        id: "Q01.scan",
        columns: [
            "id", "workspace_id", "target_path", "target_revision", "target_snapshot_digest",
            "scope", "mode", "user_context", "diff_target_kind", "diff_base_revision",
            "diff_head_revision", "diff_content_digest", "scan_dir", "status", "phase",
            "handoff_status", "failure_message", "started_at", "completed_at", "created_at",
            "updated_at", "handoff_claimed_at", "handoff_claim_token", "seal_manifest_digest",
            "target_device", "target_inode", "canceled_at", "deep_scan_owner_thread_id",
            "continuation_thread_id", "target_id", "target_summary", "recipe_json",
            "parent_scan_id", "cost_json", "model", "reasoning_effort",
            "completion_warnings_json", "retained_source_digests_json",
        ],
        sql: """
        SELECT id,workspace_id,target_path,target_revision,target_snapshot_digest,
               scope,mode,user_context,diff_target_kind,diff_base_revision,
               diff_head_revision,diff_content_digest,scan_dir,status,phase,
               handoff_status,failure_message,started_at,completed_at,created_at,
               updated_at,handoff_claimed_at,handoff_claim_token,seal_manifest_digest,
               target_device,target_inode,canceled_at,deep_scan_owner_thread_id,
               continuation_thread_id,target_id,target_summary,recipe_json,
               parent_scan_id,cost_json,model,reasoning_effort,
               completion_warnings_json,retained_source_digests_json
        FROM scans
        WHERE id=:scan_id
        ORDER BY id COLLATE BINARY;
        """
    ),
    QuerySpec(
        id: "Q02.progress",
        columns: [
            "scan_id", "review_items_total", "review_items_completed", "reportable_findings_count",
            "deep_review_pass", "updated_at", "scope_file_count", "phase_items_total",
            "phase_items_completed", "phase_progress_unit", "preflight_issues_json",
            "preflight_checks_total", "preflight_checks_completed",
        ],
        sql: """
        SELECT scan_id,review_items_total,review_items_completed,
               reportable_findings_count,deep_review_pass,updated_at,scope_file_count,
               phase_items_total,phase_items_completed,phase_progress_unit,
               preflight_issues_json,preflight_checks_total,preflight_checks_completed
        FROM scan_progress
        WHERE scan_id=:scan_id
        ORDER BY scan_id COLLATE BINARY;
        """
    ),
    QuerySpec(
        id: "Q03.findings",
        columns: ["id", "fingerprint", "rule_id", "identity_anchor", "identity_instance", "created_at", "updated_at"],
        sql: """
        SELECT id,fingerprint,rule_id,identity_anchor,identity_instance,created_at,updated_at
        FROM findings
        WHERE id IN (
          SELECT finding_id FROM finding_occurrences WHERE scan_id=:scan_id
        )
        ORDER BY id COLLATE BINARY;
        """
    ),
    QuerySpec(
        id: "Q04.occurrences",
        columns: ["id", "finding_id", "scan_id", "title", "summary", "severity", "confidence", "remediation", "created_at", "details_json"],
        sql: """
        SELECT id,finding_id,scan_id,title,summary,severity,confidence,
               remediation,created_at,details_json
        FROM finding_occurrences
        WHERE scan_id=:scan_id
        ORDER BY id COLLATE BINARY;
        """
    ),
    QuerySpec(
        id: "Q05.locations",
        columns: ["id", "occurrence_id", "relative_path", "start_line", "end_line", "role", "sort_order"],
        sql: """
        SELECT l.id,l.occurrence_id,l.relative_path,l.start_line,l.end_line,l.role,l.sort_order
        FROM finding_locations AS l
        JOIN finding_occurrences AS o ON o.id=l.occurrence_id
        WHERE o.scan_id=:scan_id
        ORDER BY l.occurrence_id COLLATE BINARY,l.sort_order,l.id;
        """
    ),
    QuerySpec(
        id: "Q06.artifacts",
        columns: ["scan_id", "kind", "path", "created_at"],
        sql: """
        SELECT scan_id,kind,path,created_at
        FROM scan_artifacts
        WHERE scan_id=:scan_id
        ORDER BY kind COLLATE BINARY,scan_id COLLATE BINARY;
        """
    ),
]

private func canonicalQuerySet() throws -> Data {
    let object = querySpecs.map { ["id": $0.id, "columns": $0.columns, "sql": $0.sql] as [String: Any] }
    return try canonicalJSON(object)
}

private func canonicalRows(spec: QuerySpec, rows: [[SQLiteValue]]) throws -> Data {
    var data = Data("qinao.ds1.typed-query-rows.v1".utf8)
    let queryID = Data(spec.id.utf8)
    data.appendUInt64BE(UInt64(queryID.count))
    data.append(queryID)
    data.appendUInt64BE(UInt64(spec.columns.count))
    for column in spec.columns {
        let bytes = Data(column.utf8)
        data.appendUInt64BE(UInt64(bytes.count))
        data.append(bytes)
    }
    data.appendUInt64BE(UInt64(rows.count))
    for (ordinal, row) in rows.enumerated() {
        guard row.count == spec.columns.count else { throw fail("query_column_count_drift") }
        data.appendUInt64BE(UInt64(ordinal))
        data.appendUInt64BE(UInt64(row.count))
        for value in row { try value.appendCanonical(to: &data) }
    }
    return data
}

private struct DeadProbe {
    let path: String
    let missingAt: String
}

private func noFollowMissingProbe(_ rawPath: String) throws -> DeadProbe {
    guard rawPath.hasPrefix("/") else { throw fail("artifact_path_not_absolute") }
    let standardized = URL(fileURLWithPath: rawPath).standardizedFileURL.path
    guard standardized == rawPath, !rawPath.contains("/../") else { throw fail("artifact_path_not_canonical") }
    var current = ""
    for component in rawPath.split(separator: "/", omittingEmptySubsequences: true) {
        current += "/" + component
        var info = stat()
        errno = 0
        if lstat(current, &info) == 0 {
            if (info.st_mode & S_IFMT) == S_IFLNK { throw fail("artifact_probe_symlink") }
            continue
        }
        guard errno == ENOENT else { throw fail("artifact_probe_not_enoent") }
        return DeadProbe(path: rawPath, missingAt: current)
    }
    throw fail("artifact_locator_is_live")
}

private func commonParent(_ paths: [String]) throws -> String {
    guard let first = paths.first else { throw fail("empty_artifact_paths") }
    let parents = paths.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
    guard parents.allSatisfy({ $0 == parents[0] }) else { throw fail("artifact_roots_diverge") }
    return URL(fileURLWithPath: first).deletingLastPathComponent().path
}

private struct AuditEvidence {
    let queryRows: [String: [[SQLiteValue]]]
    let queryRawRoots: [String: Data]
    let querySetBytes: Data
    let schemaBytes: Data
    let aggregateRawRoot: Data
    let deadRawRoot: Data
    let deadPrivate: [[String: Any]]
    let counts: [String: Any]
    let privateFragment: [String: Any]
}

private func auditSnapshot(_ snapshotBytes: Data, scanID: String, targetRevision: String) throws -> AuditEvidence {
    let database = try SQLiteDatabase.deserialize(snapshotBytes)
    let quick = try database.query("PRAGMA quick_check;")
    guard quick.count == 1, quick[0].count == 1, quick[0][0].textString == "ok" else {
        throw fail("quick_check_failed")
    }
    let foreignKeys = try database.query("PRAGMA foreign_key_check;")
    guard foreignKeys.isEmpty else { throw fail("foreign_key_check_failed") }

    var rowsByID: [String: [[SQLiteValue]]] = [:]
    var roots: [String: Data] = [:]
    var aggregate = Data("qinao.ds1.aggregate-query-root.v1".utf8)
    for spec in querySpecs {
        let rows = try database.query(spec.sql, textBinding: scanID)
        rowsByID[spec.id] = rows
        let bytes = try canonicalRows(spec: spec, rows: rows)
        let root = bytes.sha256Data
        roots[spec.id] = root
        let idBytes = Data(spec.id.utf8)
        aggregate.appendUInt64BE(UInt64(idBytes.count))
        aggregate.append(idBytes)
        aggregate.appendUInt64BE(UInt64(rows.count))
        aggregate.append(root)
    }
    let aggregateRoot = aggregate.sha256Data
    guard let scanRows = rowsByID["Q01.scan"], scanRows.count == 1 else { throw fail("scan_row_count") }
    let scanRow = scanRows[0]
    guard scanRow[0].textString == scanID,
          scanRow[3].textString == targetRevision,
          scanRow[6].textString == "deep",
          scanRow[13].textString == "complete" else {
        throw fail("scan_binding_mismatch")
    }
    guard let findingRows = rowsByID["Q03.findings"], findingRows.count == expectedOccurrenceCount,
          let occurrenceRows = rowsByID["Q04.occurrences"], occurrenceRows.count == expectedOccurrenceCount,
          let locationRows = rowsByID["Q05.locations"], locationRows.count == expectedLocationCount,
          let artifactRows = rowsByID["Q06.artifacts"], artifactRows.count == 4 else {
        throw fail("cardinality_mismatch")
    }

    let occurrenceIDs = occurrenceRows.compactMap { $0[0].textString }
    let findingIDs = occurrenceRows.compactMap { $0[1].textString }
    guard occurrenceIDs.count == expectedOccurrenceCount,
          Set(occurrenceIDs).count == expectedOccurrenceCount,
          findingIDs.count == expectedOccurrenceCount,
          Set(findingIDs).count == expectedOccurrenceCount else {
        throw fail("occurrence_identity_mismatch")
    }
    let locationOccurrenceIDs = Set(locationRows.compactMap { $0[1].textString })
    guard locationOccurrenceIDs == Set(occurrenceIDs) else { throw fail("location_coverage_mismatch") }

    var severity: [String: Int] = [:]
    var detailsLengths: [Int] = []
    for row in occurrenceRows {
        guard let value = row[5].textString else { throw fail("severity_type") }
        severity[value, default: 0] += 1
        guard case .text(let details) = row[9],
              (try? JSONSerialization.jsonObject(with: details)) != nil else {
            throw fail("details_json_invalid")
        }
        detailsLengths.append(details.count)
    }
    guard severity == ["high": 30, "medium": 65, "low": 16] else {
        throw fail("severity_mismatch")
    }
    guard detailsLengths.min() == 2_351,
          detailsLengths.max() == 703_607,
          detailsLengths.reduce(0, +) == 6_453_105 else {
        throw fail("details_length_mismatch")
    }

    let expectedKinds = ["coverage", "findings", "manifest", "markdownReport"]
    let kinds = artifactRows.compactMap { $0[1].textString }
    guard kinds == expectedKinds else { throw fail("artifact_kind_mismatch") }
    let paths = artifactRows.compactMap { $0[2].textString }
    guard paths.count == 4 else { throw fail("artifact_path_type") }
    let root = try commonParent(paths)
    let rootProbe = try noFollowMissingProbe(root)
    let probes = try paths.map(noFollowMissingProbe)
    var deadCanonical = Data("qinao.ds1.dead-locator-root.v1".utf8)
    var deadPrivate: [[String: Any]] = []
    for (kind, probe) in zip(kinds, probes) {
        for value in [kind, probe.path, probe.missingAt] {
            let bytes = Data(value.utf8)
            deadCanonical.appendUInt64BE(UInt64(bytes.count))
            deadCanonical.append(bytes)
        }
        deadPrivate.append([
            "kind": kind,
            "path": probe.path,
            "probe": "ENOENT",
            "missingAt": probe.missingAt,
        ])
    }
    for value in [rootProbe.path, rootProbe.missingAt] {
        let bytes = Data(value.utf8)
        deadCanonical.appendUInt64BE(UInt64(bytes.count))
        deadCanonical.append(bytes)
    }
    let deadRoot = deadCanonical.sha256Data

    let schemaRows = try database.query("""
        SELECT type,name,tbl_name,rootpage,sql
        FROM sqlite_schema
        ORDER BY type COLLATE BINARY,name COLLATE BINARY,tbl_name COLLATE BINARY,rootpage;
        """)
    let schemaSpec = QuerySpec(
        id: "SCHEMA.sqlite_schema",
        columns: ["type", "name", "tbl_name", "rootpage", "sql"],
        sql: "sqlite_schema ordered binary"
    )
    let schemaBytes = try canonicalRows(spec: schemaSpec, rows: schemaRows)
    let querySet = try canonicalQuerySet()
    let pageSize = try database.query("PRAGMA page_size;").first?.first?.integerValue ?? -1
    let pageCount = try database.query("PRAGMA page_count;").first?.first?.integerValue ?? -1
    let schemaVersion = try database.query("PRAGMA schema_version;").first?.first?.integerValue ?? -1
    let userVersion = try database.query("PRAGMA user_version;").first?.first?.integerValue ?? -1
    let applicationID = try database.query("PRAGMA application_id;").first?.first?.integerValue ?? -1
    let encoding = try database.query("PRAGMA encoding;").first?.first?.textString ?? ""

    let rootObject = roots.keys.sorted().map { ["queryID": $0, "rawRootSHA256": roots[$0]!.hex] }
    let counts: [String: Any] = [
        "occurrences": expectedOccurrenceCount,
        "distinctOccurrenceIDs": Set(occurrenceIDs).count,
        "distinctFindingIDs": Set(findingIDs).count,
        "findingRows": findingRows.count,
        "locations": locationRows.count,
        "occurrencesWithLocations": locationOccurrenceIDs.count,
        "artifactRows": artifactRows.count,
        "deadLocators": probes.count,
        "severityHigh": severity["high"]!,
        "severityMedium": severity["medium"]!,
        "severityLow": severity["low"]!,
        "detailsMinBytes": detailsLengths.min()!,
        "detailsMaxBytes": detailsLengths.max()!,
        "detailsTotalBytes": detailsLengths.reduce(0, +),
        "malformedDetails": 0,
        "foreignKeyRows": 0,
        "quickCheck": "ok",
    ]
    let privateFragment: [String: Any] = [
        "orderedQuerySet": try JSONSerialization.jsonObject(with: querySet),
        "queryRawRoots": rootObject,
        "aggregateRawRowRootSHA256": aggregateRoot.hex,
        "schemaRawSHA256": schemaBytes.sha256Hex,
        "querySetRawSHA256": querySet.sha256Hex,
        "deadLocatorRawRootSHA256": deadRoot.hex,
        "deadArtifactEvidence": deadPrivate,
        "deadCommonRoot": [
            "path": rootProbe.path,
            "probe": "ENOENT",
            "missingAt": rootProbe.missingAt,
        ],
        "integrityResults": counts,
        "sqliteMetadata": [
            "runtimeVersion": String(cString: sqlite3_libversion()),
            "pageSize": pageSize,
            "pageCount": pageCount,
            "schemaVersion": schemaVersion,
            "userVersion": userVersion,
            "applicationID": applicationID,
            "encoding": encoding,
        ],
    ]
    return AuditEvidence(
        queryRows: rowsByID,
        queryRawRoots: roots,
        querySetBytes: querySet,
        schemaBytes: schemaBytes,
        aggregateRawRoot: aggregateRoot,
        deadRawRoot: deadRoot,
        deadPrivate: deadPrivate,
        counts: counts,
        privateFragment: privateFragment
    )
}

private func makePayload(manifest: Data, sqlite: Data) -> Data {
    var payload = payloadMagic
    payload.appendUInt64BE(UInt64(manifest.count))
    payload.append(manifest)
    payload.appendUInt64BE(UInt64(sqlite.count))
    payload.append(sqlite)
    return payload
}

private func parsePayload(_ payload: Data) throws -> (manifest: Data, sqlite: Data) {
    guard payload.count >= payloadMagic.count + 16,
          payload.prefix(payloadMagic.count) == payloadMagic else { throw fail("payload_magic") }
    var cursor = payloadMagic.count
    let manifestLength = try Int(exactly: payload.uint64BE(at: cursor)).unwrap("manifest_length")
    cursor += 8
    guard manifestLength >= 2, payload.count - cursor >= manifestLength + 8 else { throw fail("payload_manifest_truncated") }
    let manifest = payload.subdata(in: cursor..<(cursor + manifestLength))
    cursor += manifestLength
    let sqliteLength = try Int(exactly: payload.uint64BE(at: cursor)).unwrap("sqlite_length")
    cursor += 8
    guard sqliteLength > 0, payload.count - cursor == sqliteLength else { throw fail("payload_sqlite_truncated") }
    return (manifest, payload.subdata(in: cursor..<payload.count))
}

private extension Optional {
    func unwrap(_ code: String) throws -> Wrapped {
        guard let self else { throw fail(code) }
        return self
    }
}

private func sealEnvelope(header: Data, payload: Data, key: Data) throws -> Data {
    var aad = envelopeMagic
    aad.appendUInt64BE(UInt64(header.count))
    aad.append(header)
    let sealed = try AES.GCM.seal(payload, using: SymmetricKey(data: key), authenticating: aad)
    guard let combined = sealed.combined else { throw fail("aead_combined_unavailable") }
    var envelope = aad
    envelope.append(combined)
    return envelope
}

private func openEnvelope(_ envelope: Data, key: Data) throws -> (header: Data, payload: Data) {
    guard envelope.count >= envelopeMagic.count + 8 + 12 + 16,
          envelope.prefix(envelopeMagic.count) == envelopeMagic else { throw fail("envelope_magic") }
    let headerLength = try Int(exactly: envelope.uint64BE(at: envelopeMagic.count)).unwrap("header_length")
    let headerStart = envelopeMagic.count + 8
    guard headerLength > 0, envelope.count - headerStart >= headerLength + 28 else {
        throw fail("envelope_truncated")
    }
    let headerEnd = headerStart + headerLength
    let header = envelope.subdata(in: headerStart..<headerEnd)
    let aad = envelope.subdata(in: 0..<headerEnd)
    let combined = envelope.subdata(in: headerEnd..<envelope.count)
    let sealed = try AES.GCM.SealedBox(combined: combined)
    let payload = try AES.GCM.open(sealed, using: SymmetricKey(data: key), authenticating: aad)
    return (header, payload)
}

private struct FileIdentity {
    let device: UInt64
    let inode: UInt64
    let size: UInt64
    let modificationSeconds: Int64
    let mode: UInt16
    let links: UInt64
    let owner: UInt32
}

private func fileIdentity(_ path: String, requireRegular: Bool = true) throws -> FileIdentity {
    var info = stat()
    guard lstat(path, &info) == 0 else { throw fail("file_lstat_failed") }
    if requireRegular, (info.st_mode & S_IFMT) != S_IFREG { throw fail("file_not_regular") }
    return FileIdentity(
        device: UInt64(info.st_dev),
        inode: UInt64(info.st_ino),
        size: UInt64(info.st_size),
        modificationSeconds: Int64(info.st_mtimespec.tv_sec),
        mode: UInt16(info.st_mode & 0o7777),
        links: UInt64(info.st_nlink),
        owner: info.st_uid
    )
}

private func ensurePrivateDirectory(_ path: String) throws {
    let manager = FileManager.default
    if !manager.fileExists(atPath: path) {
        try manager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    var info = stat()
    guard lstat(path, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR,
          (info.st_mode & 0o077) == 0, info.st_uid == getuid() else {
        throw fail("custody_directory_permissions")
    }
}

private func writeAll(fd: Int32, data: Data) throws {
    try data.withUnsafeBytes { raw in
        guard let base = raw.baseAddress else { throw fail("write_empty_buffer") }
        var offset = 0
        while offset < raw.count {
            let written = Darwin.write(fd, base.advanced(by: offset), raw.count - offset)
            guard written > 0 else { throw fail("file_write_failed") }
            offset += written
        }
    }
}

private func atomicWriteNoReplace(_ data: Data, destination: String, mode: mode_t) throws {
    let parent = URL(fileURLWithPath: destination).deletingLastPathComponent().path
    try ensurePrivateDirectory(parent)
    let temporary = parent + "/.qinao-vault-" + UUID().uuidString + ".tmp"
    let fd = Darwin.open(temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
    guard fd >= 0 else { throw fail("temporary_create_failed") }
    var keepTemporary = true
    defer {
        Darwin.close(fd)
        if keepTemporary { Darwin.unlink(temporary) }
    }
    try writeAll(fd: fd, data: data)
    guard fsync(fd) == 0, fchmod(fd, mode) == 0, fsync(fd) == 0 else {
        throw fail("file_durability_failed")
    }
    guard link(temporary, destination) == 0 else {
        if errno == EEXIST { throw fail("destination_exists") }
        throw fail("atomic_link_failed")
    }
    guard unlink(temporary) == 0 else { throw fail("temporary_unlink_failed") }
    keepTemporary = false
    let directoryFD = Darwin.open(parent, O_RDONLY | O_DIRECTORY)
    if directoryFD >= 0 {
        _ = fsync(directoryFD)
        Darwin.close(directoryFD)
    }
    let identity = try fileIdentity(destination)
    guard identity.links == 1, identity.owner == getuid(), (identity.mode & 0o077) == 0 else {
        throw fail("published_file_permissions")
    }
}

private func executableDigest() throws -> String {
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    return try Data(contentsOf: executable, options: [.mappedIfSafe]).sha256Hex
}

private func publicReceipt(
    captureID: String,
    createdAt: String,
    scanID: String,
    targetRevision: String,
    epoch: String,
    erasureScope: String,
    toolSourceSHA256: String,
    binarySHA256: String,
    audit: AuditEvidence,
    privateManifest: Data,
    sqlite: Data,
    envelope: Data,
    commitmentKey: Data,
    custodyClass: String
) -> [String: Any] {
    let commit: (String, String, Data) -> String = { domain, context, bytes in
        keyedCommitment(
            master: commitmentKey,
            epoch: epoch,
            erasureScope: erasureScope,
            domain: domain,
            scanID: scanID,
            targetRevision: targetRevision,
            context: context,
            bytes: bytes
        )
    }
    return [
        "schema": "qinao.ds1-encrypted-snapshot-public-receipt.v1",
        "status": "captured",
        "captureID": captureID,
        "semanticOperationID": "qinao.deep-scan-1.freeze.\(scanID).\(targetRevision)",
        "createdAtUTC": createdAt,
        "scanNumber": scanNumber,
        "scanID": scanID,
        "scanMode": "deep",
        "targetRevision": targetRevision,
        "officialIndexedState": "complete",
        "canonicalArtifactState": "canonicalUnavailable",
        "forensicStatus": "nonCanonicalForensicSnapshot",
        "captureMethod": "sqliteBackupAPI-to-memory-then-AES256GCM",
        "envelopeSchema": "qinao.ds1.envelope.v1",
        "payloadSchema": "qinao.ds1.sqlite-backup-payload.v1",
        "commitmentSuite": "qinao-ds1-keyed-commitment/v1/HKDF-SHA256/HMAC-SHA256",
        "keyEpoch": epoch,
        "erasureScope": erasureScope,
        "keyStorageClass": "AppleKeychain-local-this-device-only",
        "exporterSourceSHA256": toolSourceSHA256,
        "exporterBinarySHA256": binarySHA256,
        "sqliteRuntimeVersion": String(cString: sqlite3_libversion()),
        "counts": audit.counts,
        "querySetCommitment": commit("query-set", "ordered-query-set", audit.querySetBytes),
        "schemaCommitment": commit("schema", "sqlite-schema", audit.schemaBytes),
        "rawRowRootCommitment": commit("inventory-root", "ordered-query-roots", audit.aggregateRawRoot),
        "deadLocatorRootCommitment": commit("dead-locator", "four-dead-locators", audit.deadRawRoot),
        "snapshotBytesCommitment": commit("snapshot-bytes", "sqlite-backup", sqlite),
        "privateManifestCommitment": commit("private-manifest", "custody-manifest", privateManifest),
        "ciphertextBytes": envelope.count,
        "ciphertextSHA256": envelope.sha256Hex,
        "custodyClass": custodyClass,
        "custodyPermissions": "owner-only-read-only-after-capture",
        "deadLocatorProbe": "4/4 ENOENT with no-follow component walk; common root ENOENT",
        "quickCheck": "ok",
        "foreignKeyCheckRows": 0,
        "limitations": [
            "not canonical manifest/findings/coverage/report",
            "does not restore official artifact availability",
            "does not prove findings remediated",
            "does not authorize production changes or Deep Scan #3",
        ],
    ]
}

private struct Arguments {
    let command: String
    let values: [String: String]

    init(_ raw: [String]) throws {
        guard let first = raw.first else { throw VaultError.usage("missing_command") }
        command = first
        var parsed: [String: String] = [:]
        var index = 1
        while index < raw.count {
            let key = raw[index]
            guard key.hasPrefix("--"), index + 1 < raw.count else { throw VaultError.usage("invalid_argument_shape") }
            guard parsed[key] == nil else { throw VaultError.usage("duplicate_argument") }
            parsed[key] = raw[index + 1]
            index += 2
        }
        values = parsed
    }

    func required(_ key: String) throws -> String {
        guard let value = values[key], !value.isEmpty else { throw VaultError.usage("missing_\(key.dropFirst(2))") }
        return value
    }

    func validate(allowed: Set<String>) throws {
        let unknown = Set(values.keys).subtracting(allowed)
        guard unknown.isEmpty else { throw VaultError.usage("unknown_argument") }
    }
}

private let helpText = """
qinao-ds1-evidence-vault

Commands:
  freeze --source PATH --destination PATH --receipt PATH --scan-id UUID
         --target-revision SHA40 --key-epoch LABEL --erasure-scope LABEL
         --tool-source-sha256 SHA256
  verify --snapshot PATH --receipt PATH --verification-receipt PATH
         --scan-id UUID --target-revision SHA40 --key-epoch LABEL
         --erasure-scope LABEL
  help

All encryption and commitment keys are generated and retrieved through Apple
Keychain. The production CLI accepts no raw key material.
"""

private func validateIdentity(scanID: String, targetRevision: String, sourceSHA: String? = nil) throws {
    guard UUID(uuidString: scanID) != nil else { throw fail("invalid_scan_id") }
    let hex40 = try NSRegularExpression(pattern: "^[0-9a-f]{40}$")
    guard hex40.firstMatch(in: targetRevision, range: NSRange(targetRevision.startIndex..., in: targetRevision)) != nil else {
        throw fail("invalid_target_revision")
    }
    if let sourceSHA {
        let hex64 = try NSRegularExpression(pattern: "^[0-9a-f]{64}$")
        guard hex64.firstMatch(in: sourceSHA, range: NSRange(sourceSHA.startIndex..., in: sourceSHA)) != nil else {
            throw fail("invalid_tool_source_sha")
        }
    }
}

private func freeze(_ arguments: Arguments) throws {
    let allowed: Set<String> = [
        "--source", "--destination", "--receipt", "--scan-id", "--target-revision",
        "--key-epoch", "--erasure-scope", "--tool-source-sha256",
    ]
    try arguments.validate(allowed: allowed)
    let source = try arguments.required("--source")
    let destination = try arguments.required("--destination")
    let receiptPath = try arguments.required("--receipt")
    let scanID = try arguments.required("--scan-id")
    let targetRevision = try arguments.required("--target-revision")
    let epoch = try arguments.required("--key-epoch")
    let erasureScope = try arguments.required("--erasure-scope")
    let sourceSHA = try arguments.required("--tool-source-sha256")
    try validateIdentity(scanID: scanID, targetRevision: targetRevision, sourceSHA: sourceSHA)
    guard !destination.hasPrefix(FileManager.default.currentDirectoryPath + "/"),
          !receiptPath.hasPrefix(FileManager.default.currentDirectoryPath + "/") else {
        throw fail("snapshot_and_initial_receipt_must_be_repository_external")
    }
    let sourceBefore = try fileIdentity(source)
    let createdAt = utcTimestamp()
    let captureID = UUID().uuidString.lowercased()
    let binarySHA = try executableDigest()
    let sqliteBytes = try backupDatabase(sourcePath: source)
    let sourceAfter = try fileIdentity(source)
    guard sourceBefore.device == sourceAfter.device,
          sourceBefore.inode == sourceAfter.inode else { throw fail("source_identity_changed") }
    let audit = try auditSnapshot(sqliteBytes, scanID: scanID, targetRevision: targetRevision)
    let encryptionKey = try loadOrCreateKey(
        service: encryptionService,
        account: "ds1.encryption.\(epoch)",
        create: true
    )
    let commitmentKey = try loadOrCreateKey(
        service: commitmentService,
        account: "ds1.commitment.\(epoch)",
        create: true
    )
    guard encryptionKey != commitmentKey else { throw fail("key_separation_failed") }

    var privateManifest: [String: Any] = [
        "schemaVersion": "qinao.ds1-private-custody-manifest.v1",
        "manifestKind": "qinao-ds1-private-custody-manifest",
        "captureID": captureID,
        "semanticOperationID": "qinao.deep-scan-1.freeze.\(scanID).\(targetRevision)",
        "createdAtUTC": createdAt,
        "scanBinding": [
            "scanNumber": scanNumber,
            "scanID": scanID,
            "mode": "deep",
            "targetRevision": targetRevision,
            "officialState": "complete",
            "canonicalArtifactState": "canonicalUnavailable",
        ],
        "sourceDatabaseBinding": [
            "path": source,
            "device": String(sourceBefore.device),
            "inode": String(sourceBefore.inode),
            "sizeBefore": String(sourceBefore.size),
            "sizeAfter": String(sourceAfter.size),
            "mtimeBefore": String(sourceBefore.modificationSeconds),
            "mtimeAfter": String(sourceAfter.modificationSeconds),
            "sourceConnection": "ordinary SQLITE_OPEN_READONLY with WAL/SHM semantics",
        ],
        "captureBinding": [
            "method": "sqliteBackupAPI",
            "storageLifecycle": "backup and serialized SQLite bytes remained in process memory before AEAD",
            "plaintextSnapshotBytes": String(sqliteBytes.count),
            "plaintextSnapshotRawSHA256": sqliteBytes.sha256Hex,
        ],
        "exportToolBinding": [
            "sourceSHA256": sourceSHA,
            "binarySHA256": binarySHA,
            "sqliteRuntime": String(cString: sqlite3_libversion()),
            "formatVersion": formatVersion,
        ],
        "encryption": [
            "suite": "Apple CryptoKit AES-256-GCM",
            "keySeparation": "independent Keychain encryption and commitment master keys",
            "keyEpoch": epoch,
            "erasureScope": erasureScope,
            "keyAccessibility": "AfterFirstUnlockThisDeviceOnly",
            "synchronizable": false,
        ],
        "custody": [
            "destination": destination,
            "publication": "exclusive temporary create + fsync + atomic hard-link no-replace + unlink",
            "repositoryExternal": true,
        ],
        "officialReadError": "Codex Security scan artifact root is not a safe regular directory.",
    ]
    for (key, value) in audit.privateFragment { privateManifest[key] = value }
    let privateManifestBytes = try canonicalJSON(privateManifest)
    let payload = makePayload(manifest: privateManifestBytes, sqlite: sqliteBytes)
    let headerObject: [String: Any] = [
        "schema": "qinao.ds1-envelope-header.v1",
        "formatVersion": formatVersion,
        "captureID": captureID,
        "createdAtUTC": createdAt,
        "scanNumber": scanNumber,
        "scanID": scanID,
        "targetRevision": targetRevision,
        "keyEpoch": epoch,
        "erasureScope": erasureScope,
        "algorithm": "AES-256-GCM",
        "toolSourceSHA256": sourceSHA,
        "toolBinarySHA256": binarySHA,
    ]
    let header = try canonicalJSON(headerObject)
    let envelope = try sealEnvelope(header: header, payload: payload, key: encryptionKey)
    try atomicWriteNoReplace(envelope, destination: destination, mode: 0o400)
    let custody = try fileIdentity(destination)
    guard custody.size == UInt64(envelope.count), custody.mode == 0o400, custody.links == 1 else {
        throw fail("custody_post_publish_mismatch")
    }
    let receipt = publicReceipt(
        captureID: captureID,
        createdAt: createdAt,
        scanID: scanID,
        targetRevision: targetRevision,
        epoch: epoch,
        erasureScope: erasureScope,
        toolSourceSHA256: sourceSHA,
        binarySHA256: binarySHA,
        audit: audit,
        privateManifest: privateManifestBytes,
        sqlite: sqliteBytes,
        envelope: envelope,
        commitmentKey: commitmentKey,
        custodyClass: "repository-external-local-encrypted-regular-single-link"
    )
    try atomicWriteNoReplace(try canonicalJSON(receipt), destination: receiptPath, mode: 0o400)
    try printJSON([
        "schema": "qinao.ds1-freeze-operation-result.v1",
        "status": "captured",
        "captureID": captureID,
        "ciphertextBytes": envelope.count,
        "ciphertextSHA256": envelope.sha256Hex,
        "counts": audit.counts,
        "receiptPathClass": "repository-external-owner-read-only",
    ])
}

private func valueString(_ object: [String: Any], _ key: String) throws -> String {
    guard let value = object[key] as? String else { throw fail("missing_json_field") }
    return value
}

private func verify(_ arguments: Arguments) throws {
    let allowed: Set<String> = [
        "--snapshot", "--receipt", "--verification-receipt", "--scan-id",
        "--target-revision", "--key-epoch", "--erasure-scope",
    ]
    try arguments.validate(allowed: allowed)
    let snapshotPath = try arguments.required("--snapshot")
    let receiptPath = try arguments.required("--receipt")
    let verificationPath = try arguments.required("--verification-receipt")
    let scanID = try arguments.required("--scan-id")
    let targetRevision = try arguments.required("--target-revision")
    let epoch = try arguments.required("--key-epoch")
    let erasureScope = try arguments.required("--erasure-scope")
    try validateIdentity(scanID: scanID, targetRevision: targetRevision)
    let identity = try fileIdentity(snapshotPath)
    guard identity.mode == 0o400, identity.links == 1, identity.owner == getuid() else {
        throw fail("snapshot_custody_identity")
    }
    let envelope = try Data(contentsOf: URL(fileURLWithPath: snapshotPath), options: [.mappedIfSafe])
    let externalReceiptBytes = try Data(contentsOf: URL(fileURLWithPath: receiptPath), options: [.mappedIfSafe])
    let externalReceipt = try parseJSONObject(externalReceiptBytes)
    let encryptionKey = try loadOrCreateKey(
        service: encryptionService,
        account: "ds1.encryption.\(epoch)",
        create: false
    )
    let commitmentKey = try loadOrCreateKey(
        service: commitmentService,
        account: "ds1.commitment.\(epoch)",
        create: false
    )
    let opened = try openEnvelope(envelope, key: encryptionKey)
    let header = try parseJSONObject(opened.header)
    guard try valueString(header, "scanID") == scanID,
          try valueString(header, "targetRevision") == targetRevision,
          try valueString(header, "keyEpoch") == epoch,
          try valueString(header, "erasureScope") == erasureScope else {
        throw fail("envelope_header_binding")
    }
    let parsed = try parsePayload(opened.payload)
    let privateManifest = try parseJSONObject(parsed.manifest)
    guard let scanBinding = privateManifest["scanBinding"] as? [String: Any],
          try valueString(scanBinding, "scanID") == scanID,
          try valueString(scanBinding, "targetRevision") == targetRevision else {
        throw fail("private_manifest_binding")
    }
    let audit = try auditSnapshot(parsed.sqlite, scanID: scanID, targetRevision: targetRevision)
    let expected = publicReceipt(
        captureID: try valueString(header, "captureID"),
        createdAt: try valueString(header, "createdAtUTC"),
        scanID: scanID,
        targetRevision: targetRevision,
        epoch: epoch,
        erasureScope: erasureScope,
        toolSourceSHA256: try valueString(header, "toolSourceSHA256"),
        binarySHA256: try valueString(header, "toolBinarySHA256"),
        audit: audit,
        privateManifest: parsed.manifest,
        sqlite: parsed.sqlite,
        envelope: envelope,
        commitmentKey: commitmentKey,
        custodyClass: "repository-external-local-encrypted-regular-single-link"
    )
    let expectedReceiptBytes = try canonicalJSON(expected)
    let observedReceiptBytes = try canonicalJSON(externalReceipt)
    guard expectedReceiptBytes == observedReceiptBytes else {
        throw fail("public_receipt_mismatch")
    }
    let verification: [String: Any] = [
        "schema": "qinao.ds1-independent-reopen-receipt.v1",
        "status": "pass",
        "verifiedAtUTC": utcTimestamp(),
        "freshProcess": true,
        "captureID": try valueString(header, "captureID"),
        "scanNumber": scanNumber,
        "scanID": scanID,
        "targetRevision": targetRevision,
        "ciphertextBytes": envelope.count,
        "ciphertextSHA256": envelope.sha256Hex,
        "aeadAuthentication": "pass",
        "privateManifestRecomputed": true,
        "orderedQueriesRecomputed": querySpecs.count,
        "counts": audit.counts,
        "deadLocatorReopen": "4/4 ENOENT and common root ENOENT",
        "quickCheck": "ok",
        "foreignKeyCheckRows": 0,
        "plaintextFileCreated": false,
        "publicReceiptByteEquivalent": true,
        "verifierBinarySHA256": try executableDigest(),
        "keyEpoch": epoch,
        "erasureScope": erasureScope,
    ]
    try atomicWriteNoReplace(try canonicalJSON(verification), destination: verificationPath, mode: 0o400)
    try printJSON(verification)
}

#if QINAO_TESTING
private func createFixture(at path: String) throws -> OpaquePointer {
    var database: OpaquePointer?
    guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
          let database else { throw fail("fixture_open") }
    let sql = """
    PRAGMA journal_mode=WAL;
    CREATE TABLE fixture(id INTEGER PRIMARY KEY, body TEXT NOT NULL);
    INSERT INTO fixture(body) VALUES('first'),('second');
    """
    guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
        sqlite3_close_v2(database)
        throw fail("fixture_create")
    }
    guard sqlite3_wal_checkpoint_v2(database, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil) == SQLITE_OK else {
        sqlite3_close_v2(database)
        throw fail("fixture_checkpoint")
    }
    guard sqlite3_exec(database, "INSERT INTO fixture(body) VALUES('fixture secret finding body');", nil, nil, nil) == SQLITE_OK else {
        sqlite3_close_v2(database)
        throw fail("fixture_wal_insert")
    }
    return database
}

private func selfTest() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("qinao-vault-self-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appendingPathComponent("fixture.sqlite3")
    let fixture = try createFixture(at: databaseURL.path)
    defer { sqlite3_close_v2(fixture) }
    let beforeNames = try Set(FileManager.default.contentsOfDirectory(atPath: directory.path))
    let snapshot = try backupDatabase(sourcePath: databaseURL.path)
    let reopened = try SQLiteDatabase.deserialize(snapshot)
    let rows = try reopened.query("SELECT id,body FROM fixture ORDER BY id;")
    let walIncluded = rows.count == 3 && rows.last?[1].textString == "fixture secret finding body"
    let spec = QuerySpec(id: "fixture", columns: ["id", "body"], sql: "SELECT id,body FROM fixture ORDER BY id;")
    let encodingA = try canonicalRows(spec: spec, rows: rows)
    let encodingB = try canonicalRows(spec: spec, rows: rows)
    let key = try randomBytes(count: 32)
    let wrongKey = try randomBytes(count: 32)
    let header = try canonicalJSON(["schema": "test", "captureID": UUID().uuidString])
    let privateManifest = try canonicalJSON([
        "schema": "test-private",
        "rawSQLiteSHA256": snapshot.sha256Hex,
        "rawRowRoot": encodingA.sha256Hex,
    ])
    let payload = makePayload(manifest: privateManifest, sqlite: snapshot)
    let envelope = try sealEnvelope(header: header, payload: payload, key: key)
    let opened = try openEnvelope(envelope, key: key)
    let roundTrip = opened.header == header && opened.payload == payload

    func rejected(_ candidate: Data, key candidateKey: Data) -> Bool {
        do { _ = try openEnvelope(candidate, key: candidateKey); return false } catch { return true }
    }
    var bitFlipped = envelope
    bitFlipped[bitFlipped.count - 5] ^= 0x01
    var headerFlipped = envelope
    headerFlipped[envelopeMagic.count + 8 + 2] ^= 0x01
    let truncated = envelope.dropLast(1)
    let safeReceipt: [String: Any] = [
        "schema": "safe",
        "status": "pass",
        "ciphertextSHA256": envelope.sha256Hex,
        "rowCommitment": Data(HMAC<SHA256>.authenticationCode(for: encodingA, using: SymmetricKey(data: wrongKey))).hex,
    ]
    let safeText = String(data: try canonicalJSON(safeReceipt), encoding: .utf8)!
    let redacted = !safeText.contains("rawSQLiteSHA256")
        && !safeText.contains("rawRowRoot")
        && !safeText.contains("fixture secret finding body")
    let afterNames = try Set(FileManager.default.contentsOfDirectory(atPath: directory.path))
    let allowedNames = beforeNames.union([databaseURL.lastPathComponent + "-wal", databaseURL.lastPathComponent + "-shm"])
    let noPlaintext = afterNames.isSubset(of: allowedNames)
    let checks = [
        snapshot.count > 0,
        rows.count == 3,
        walIncluded,
        encodingA == encodingB,
        roundTrip,
        rejected(bitFlipped, key: key),
        rejected(envelope, key: wrongKey),
        rejected(headerFlipped, key: key),
        rejected(Data(truncated), key: key),
        redacted,
        noPlaintext,
        privateManifest.count > 0,
        envelope != payload,
        envelope.sha256Hex.count == 64,
    ]
    guard checks.allSatisfy({ $0 }) else { throw fail("self_test_check_failed") }
    try printJSON([
        "schema": "qinao.ds1-vault-self-test.v1",
        "status": "pass",
        "checksPassed": checks.count,
        "sqliteBackupRoundTrip": roundTrip,
        "walRowsIncluded": walIncluded,
        "deterministicRowEncoding": encodingA == encodingB,
        "tamperRejected": rejected(bitFlipped, key: key),
        "wrongKeyRejected": rejected(envelope, key: wrongKey),
        "headerTamperRejected": rejected(headerFlipped, key: key),
        "truncationRejected": rejected(Data(truncated), key: key),
        "publicReceiptRedacted": redacted,
        "noPlaintextFileCreated": noPlaintext,
    ])
}
#endif

private func run() throws {
    let arguments = try Arguments(Array(CommandLine.arguments.dropFirst()))
    switch arguments.command {
    case "help", "--help", "-h":
        guard arguments.values.isEmpty else { throw VaultError.usage("help_takes_no_arguments") }
        print(helpText)
    case "freeze":
        try freeze(arguments)
    case "verify":
        try verify(arguments)
    #if QINAO_TESTING
    case "self-test":
        guard arguments.values.isEmpty else { throw VaultError.usage("self_test_takes_no_arguments") }
        try selfTest()
    #endif
    default:
        throw VaultError.usage("unknown_command")
    }
}

do {
    try run()
} catch {
    let code = String(describing: error)
    let safe = code.replacingOccurrences(of: "\n", with: "_")
    FileHandle.standardError.write(Data("qinao-ds1-vault: \(safe)\n".utf8))
    exit(2)
}
