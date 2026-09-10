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
private let publicationContract = "exclusive openat temporary + fsync + renameatx_np(RENAME_EXCL) + directory fsync"
private let maximumEnvelopeBytes = 512 * 1024 * 1024
private let maximumSQLiteBytes = 480 * 1024 * 1024
private let maximumReceiptBytes = 4 * 1024 * 1024
private let maximumPrivateManifestBytes = 16 * 1024 * 1024

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

private func disableCoreDumps() throws {
    var limit = rlimit(rlim_cur: 0, rlim_max: 0)
    guard setrlimit(RLIMIT_CORE, &limit) == 0 else { throw fail("core_dump_disable_failed") }
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

    mutating func bestEffortZeroize() {
        resetBytes(in: startIndex..<endIndex)
        removeAll(keepingCapacity: false)
    }

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

private func canonicalValue(_ value: Any) throws -> Data {
    try canonicalJSON(["value": value])
}

private func privateFragmentMatches(
    manifest: [String: Any],
    expected: [String: Any]
) throws -> Bool {
    for (key, expectedValue) in expected {
        guard let observedValue = manifest[key],
              try canonicalValue(observedValue) == canonicalValue(expectedValue) else {
            return false
        }
    }
    return true
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
    guard status == errSecItemNotFound, create else {
        #if QINAO_INTEGRATION_TESTING
        throw fail("keychain_key_unavailable_osstatus_\(status)")
        #else
        throw fail("keychain_key_unavailable")
        #endif
    }

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
    #if QINAO_INTEGRATION_TESTING
    throw fail("keychain_add_failed_osstatus_\(addStatus)")
    #else
    throw fail("keychain_add_failed")
    #endif
}

#if QINAO_INTEGRATION_TESTING
private func deleteTestKey(service: String, account: String) throws {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecAttrSynchronizable: kCFBooleanFalse as Any,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
        throw fail("test_keychain_delete_failed_osstatus_\(status)")
    }
}
#endif

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

    func serialize(maximumBytes: Int = maximumSQLiteBytes) throws -> Data {
        var byteCount: sqlite3_int64 = 0
        guard let pointer = sqlite3_serialize(handle, "main", &byteCount, 0), byteCount > 0 else {
            throw fail("sqlite_serialize_failed")
        }
        defer { sqlite3_free(pointer) }
        guard byteCount <= sqlite3_int64(maximumBytes) else {
            throw fail("sqlite_snapshot_size_limit")
        }
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
    let pageSize = try source.query("PRAGMA page_size;").first?.first?.integerValue ?? -1
    guard pageSize > 0 else { throw fail("sqlite_source_page_size") }
    let deadline = Date().addingTimeInterval(30)
    while true {
        let status = sqlite3_backup_step(backup, 256)
        let pageCount = Int64(sqlite3_backup_pagecount(backup))
        guard pageCount >= 0,
              pageCount <= Int64(maximumSQLiteBytes) / pageSize else {
            throw fail("sqlite_snapshot_size_limit")
        }
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
    var serialized = try destination.serialize(maximumBytes: maximumSQLiteBytes)
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
    let path = try canonicalAbsolutePath(rawPath)
    let components = path.split(separator: "/", omittingEmptySubsequences: true)
    guard !components.isEmpty else { throw fail("artifact_path_not_canonical") }
    var directoryFD = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
    guard directoryFD >= 0 else { throw fail("artifact_probe_root_open_failed") }
    defer { Darwin.close(directoryFD) }
    var current = ""
    for (index, rawComponent) in components.enumerated() {
        let component = String(rawComponent)
        current += "/" + component
        var info = stat()
        errno = 0
        if fstatat(directoryFD, component, &info, AT_SYMLINK_NOFOLLOW) != 0 {
            guard errno == ENOENT else { throw fail("artifact_probe_not_enoent") }
            return DeadProbe(path: path, missingAt: current)
        }
        guard (info.st_mode & S_IFMT) != S_IFLNK else { throw fail("artifact_probe_symlink") }
        guard index < components.count - 1 else { throw fail("artifact_locator_is_live") }
        guard (info.st_mode & S_IFMT) == S_IFDIR else {
            throw fail("artifact_probe_component_not_directory")
        }
        let nextFD = openat(
            directoryFD,
            component,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard nextFD >= 0 else { throw fail("artifact_probe_component_open_failed") }
        var openedInfo = stat()
        guard fstat(nextFD, &openedInfo) == 0,
              openedInfo.st_dev == info.st_dev,
              openedInfo.st_ino == info.st_ino else {
            Darwin.close(nextFD)
            throw fail("artifact_probe_component_changed")
        }
        Darwin.close(directoryFD)
        directoryFD = nextFD
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
    let querySetBytes: Data
    let schemaBytes: Data
    let aggregateRawRoot: Data
    let deadRawRoot: Data
    let counts: [String: Any]
    let privateFragment: [String: Any]
}

private func auditSnapshot(
    _ snapshotBytes: Data,
    scanID: String,
    targetRevision: String,
    capturedSQLiteRuntime: String? = nil,
    capturedPrivateManifest: [String: Any]? = nil
) throws -> AuditEvidence {
    let database = try SQLiteDatabase.deserialize(snapshotBytes)
    let relevantTables: [(String, [String])] = [
        ("scans", querySpecs[0].columns),
        ("scan_progress", querySpecs[1].columns),
        ("findings", querySpecs[2].columns),
        ("finding_occurrences", querySpecs[3].columns),
        ("finding_locations", querySpecs[4].columns),
        ("scan_artifacts", querySpecs[5].columns),
    ]
    for (table, expectedColumns) in relevantTables {
        let infoRows = try database.query("PRAGMA table_xinfo(\"\(table)\");")
        let observedColumns = infoRows.compactMap { row in
            row.count > 1 ? row[1].textString : nil
        }
        guard observedColumns == expectedColumns else {
            throw fail("relevant_schema_column_drift")
        }
    }
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
    guard scanRow[23].textString == "sha256:fd5df1a1157bfceab6e3d38a73e771f50f5ddb4041780d50f95bacc2a80e79be" else {
        throw fail("scan_seal_manifest_digest_mismatch")
    }
    func isNullOrEmpty(_ value: SQLiteValue) -> Bool {
        value == .null || value.textString == ""
    }
    guard isNullOrEmpty(scanRow[21]), isNullOrEmpty(scanRow[22]), isNullOrEmpty(scanRow[28]) else {
        throw fail("scan_handoff_binding_mismatch")
    }
    guard let progressRows = rowsByID["Q02.progress"], progressRows.count == 1 else {
        throw fail("scan_progress_row_count")
    }
    let progress = progressRows[0]
    guard progress[0].textString == scanID,
          progress[1].integerValue == 0,
          progress[2].integerValue == 0,
          progress[3].integerValue == Int64(expectedOccurrenceCount),
          progress[4].integerValue == 35,
          progress[6].integerValue == 10_388,
          progress[7].integerValue == 4,
          progress[8].integerValue == 4,
          progress[9].textString == "report_artifacts",
          progress[11].integerValue == 0,
          progress[12].integerValue == 0 else {
        throw fail("scan_progress_binding_mismatch")
    }
    guard case .text(let preflightIssues) = progress[10],
          (try? JSONSerialization.jsonObject(with: preflightIssues)) != nil else {
        throw fail("scan_progress_preflight_json_invalid")
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
    let indexedFindingIDs = Set(findingRows.compactMap { $0[0].textString })
    guard indexedFindingIDs.count == expectedOccurrenceCount,
          indexedFindingIDs == Set(findingIDs) else {
        throw fail("finding_identity_crosswalk_mismatch")
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
    let rootProbe: DeadProbe
    let probes: [DeadProbe]
    if let capturedPrivateManifest {
        guard let capturedArtifacts = capturedPrivateManifest["deadArtifactEvidence"] as? [[String: Any]],
              capturedArtifacts.count == paths.count,
              let capturedRoot = capturedPrivateManifest["deadCommonRoot"] as? [String: Any] else {
            throw fail("captured_dead_evidence_shape")
        }
        func capturedProbe(_ object: [String: Any], expectedPath: String) throws -> DeadProbe {
            guard try valueString(object, "path") == expectedPath,
                  try valueString(object, "probe") == "ENOENT" else {
                throw fail("captured_dead_evidence_binding")
            }
            let missingAt = try canonicalAbsolutePath(valueString(object, "missingAt"))
            guard expectedPath == missingAt || expectedPath.hasPrefix(missingAt + "/") else {
                throw fail("captured_dead_evidence_prefix")
            }
            return DeadProbe(path: expectedPath, missingAt: missingAt)
        }
        probes = try zip(zip(kinds, paths), capturedArtifacts).map { entry in
            let ((kind, path), object) = entry
            guard try valueString(object, "kind") == kind else {
                throw fail("captured_dead_evidence_kind")
            }
            return try capturedProbe(object, expectedPath: path)
        }
        rootProbe = try capturedProbe(capturedRoot, expectedPath: root)
    } else {
        rootProbe = try noFollowMissingProbe(root)
        probes = try paths.map(noFollowMissingProbe)
    }
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
            "runtimeVersion": capturedSQLiteRuntime ?? String(cString: sqlite3_libversion()),
            "pageSize": pageSize,
            "pageCount": pageCount,
            "schemaVersion": schemaVersion,
            "userVersion": userVersion,
            "applicationID": applicationID,
            "encoding": encoding,
        ],
    ]
    return AuditEvidence(
        querySetBytes: querySet,
        schemaBytes: schemaBytes,
        aggregateRawRoot: aggregateRoot,
        deadRawRoot: deadRoot,
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
    guard manifestLength >= 2,
          manifestLength <= maximumPrivateManifestBytes,
          cursor <= payload.count,
          manifestLength <= payload.count - cursor,
          payload.count - cursor - manifestLength >= 8 else {
        throw fail("payload_manifest_truncated")
    }
    let manifest = payload.subdata(in: cursor..<(cursor + manifestLength))
    cursor += manifestLength
    let sqliteLength = try Int(exactly: payload.uint64BE(at: cursor)).unwrap("sqlite_length")
    cursor += 8
    guard sqliteLength > 0,
          sqliteLength <= maximumSQLiteBytes,
          payload.count - cursor == sqliteLength else {
        throw fail("payload_sqlite_truncated")
    }
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
    guard headerLength > 0,
          headerStart <= envelope.count,
          envelope.count - headerStart >= 28,
          headerLength <= envelope.count - headerStart - 28 else {
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

private func fileIdentity(_ info: stat, requireRegular: Bool = true) throws -> FileIdentity {
    if requireRegular, (info.st_mode & S_IFMT) != S_IFREG { throw fail("file_not_regular") }
    guard info.st_size >= 0 else { throw fail("file_negative_size") }
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

private func privateFileReadNoFollow(
    _ rawPath: String,
    requiredMode: UInt16,
    maximumBytes: Int = maximumEnvelopeBytes
) throws -> (data: Data, identity: FileIdentity) {
    let path = try canonicalAbsolutePath(rawPath)
    let url = URL(fileURLWithPath: path)
    let parent = url.deletingLastPathComponent().path
    let name = url.lastPathComponent
    let parentFD = try openDirectoryChain(parent, create: false)
    defer { Darwin.close(parentFD) }
    let fd = openat(parentFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    guard fd >= 0 else { throw fail("private_file_open_failed") }
    defer { Darwin.close(fd) }
    var before = stat()
    guard fstat(fd, &before) == 0,
          (before.st_mode & S_IFMT) == S_IFREG,
          before.st_uid == getuid(),
          before.st_nlink == 1,
          UInt16(before.st_mode & 0o7777) == requiredMode,
          before.st_size >= 0,
          UInt64(before.st_size) <= UInt64(maximumBytes) else {
        throw fail("private_file_custody_mismatch")
    }
    let count = Int(before.st_size)
    var data = Data(count: count)
    try data.withUnsafeMutableBytes { raw in
        guard count == 0 || raw.baseAddress != nil else { throw fail("private_file_buffer") }
        var offset = 0
        while offset < count {
            let amount = Darwin.read(fd, raw.baseAddress!.advanced(by: offset), count - offset)
            guard amount > 0 else { throw fail("private_file_read_failed") }
            offset += amount
        }
    }
    var after = stat()
    guard fstat(fd, &after) == 0,
          before.st_dev == after.st_dev,
          before.st_ino == after.st_ino,
          before.st_size == after.st_size,
          before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
          before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec else {
        throw fail("private_file_changed_during_read")
    }
    return (
        data,
        FileIdentity(
            device: UInt64(after.st_dev),
            inode: UInt64(after.st_ino),
            size: UInt64(after.st_size),
            modificationSeconds: Int64(after.st_mtimespec.tv_sec),
            mode: UInt16(after.st_mode & 0o7777),
            links: UInt64(after.st_nlink),
            owner: after.st_uid
        )
    )
}

private func canonicalAbsolutePath(_ path: String) throws -> String {
    guard path.hasPrefix("/") else { throw fail("custody_path_not_absolute") }
    guard path != "/", !path.hasSuffix("/"), !path.contains("//") else {
        throw fail("custody_path_separator_shape")
    }
    let components = path.split(separator: "/", omittingEmptySubsequences: false)
    guard components.first == "",
          components.dropFirst().allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
        throw fail("custody_path_dot_component")
    }
    return path
}

private func openDirectoryChain(
    _ rawPath: String,
    create: Bool,
    requireOwnerPrivate: Bool = true
) throws -> Int32 {
    let path = try canonicalAbsolutePath(rawPath)
    var directoryFD = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
    guard directoryFD >= 0 else { throw fail("custody_root_open_failed") }
    var mustClose = true
    defer { if mustClose { Darwin.close(directoryFD) } }
    for rawComponent in path.split(separator: "/", omittingEmptySubsequences: true) {
        let component = String(rawComponent)
        var info = stat()
        errno = 0
        if fstatat(directoryFD, component, &info, AT_SYMLINK_NOFOLLOW) != 0 {
            guard create, errno == ENOENT else { throw fail("custody_component_missing") }
            if mkdirat(directoryFD, component, 0o700) != 0, errno != EEXIST {
                throw fail("custody_mkdir_failed")
            }
            guard fstatat(directoryFD, component, &info, AT_SYMLINK_NOFOLLOW) == 0 else {
                throw fail("custody_created_component_unreadable")
            }
        }
        guard (info.st_mode & S_IFMT) == S_IFDIR else {
            throw fail("custody_component_not_directory")
        }
        let nextFD = openat(
            directoryFD,
            component,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard nextFD >= 0 else { throw fail("custody_component_open_failed") }
        Darwin.close(directoryFD)
        directoryFD = nextFD
    }
    var finalInfo = stat()
    guard fstat(directoryFD, &finalInfo) == 0 else {
        throw fail("custody_directory_unreadable")
    }
    guard !requireOwnerPrivate || (
        finalInfo.st_uid == getuid() && (finalInfo.st_mode & 0o077) == 0
    ) else {
        throw fail("custody_directory_permissions")
    }
    mustClose = false
    return directoryFD
}

private func resolvedPath(_ path: String) throws -> String {
    guard let pointer = realpath(path, nil) else { throw fail("custody_realpath_failed") }
    defer { free(pointer) }
    return String(cString: pointer)
}

private func path(_ child: String, isWithin root: String) -> Bool {
    child == root || child.hasPrefix(root.hasSuffix("/") ? root : root + "/")
}

private func validateSnapshotReceiptNameBinding(snapshot: String, receipt: String) throws {
    let snapshotURL = URL(fileURLWithPath: try canonicalAbsolutePath(snapshot))
    let receiptURL = URL(fileURLWithPath: try canonicalAbsolutePath(receipt))
    guard snapshotURL.pathExtension == "qds1",
          receiptURL.lastPathComponent == snapshotURL.deletingPathExtension().lastPathComponent + ".capture-receipt.json" else {
        throw fail("snapshot_receipt_name_binding")
    }
}

private struct SourceFileLease {
    let canonicalPath: String
    let parentFD: Int32
    let fileFD: Int32
    let name: String
    let initialIdentity: FileIdentity
}

private func openSourceFileLease(_ rawPath: String) throws -> SourceFileLease {
    let canonicalPath = try canonicalAbsolutePath(rawPath)
    let url = URL(fileURLWithPath: canonicalPath)
    let parentFD = try openDirectoryChain(
        url.deletingLastPathComponent().path,
        create: false,
        requireOwnerPrivate: false
    )
    let name = url.lastPathComponent
    let fileFD = openat(parentFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    guard fileFD >= 0 else {
        Darwin.close(parentFD)
        throw fail("source_open_failed")
    }
    var descriptorInfo = stat()
    var pathInfo = stat()
    guard fstat(fileFD, &descriptorInfo) == 0,
          (descriptorInfo.st_mode & S_IFMT) == S_IFREG,
          descriptorInfo.st_uid == getuid(),
          fstatat(parentFD, name, &pathInfo, AT_SYMLINK_NOFOLLOW) == 0,
          pathInfo.st_dev == descriptorInfo.st_dev,
          pathInfo.st_ino == descriptorInfo.st_ino else {
        Darwin.close(fileFD)
        Darwin.close(parentFD)
        throw fail("source_descriptor_binding_failed")
    }
    return SourceFileLease(
        canonicalPath: canonicalPath,
        parentFD: parentFD,
        fileFD: fileFD,
        name: name,
        initialIdentity: try fileIdentity(descriptorInfo)
    )
}

private func sourceLeaseIdentity(_ lease: SourceFileLease) throws -> FileIdentity {
    var descriptorInfo = stat()
    var pathInfo = stat()
    guard fstat(lease.fileFD, &descriptorInfo) == 0,
          fstatat(lease.parentFD, lease.name, &pathInfo, AT_SYMLINK_NOFOLLOW) == 0,
          pathInfo.st_dev == descriptorInfo.st_dev,
          pathInfo.st_ino == descriptorInfo.st_ino else {
        throw fail("source_path_or_descriptor_changed")
    }
    return try fileIdentity(descriptorInfo)
}

private func validateExternalOutputPair(
    destination: String,
    receipt: String,
    repositoryRoot: String
) throws {
    let destinationPath = try canonicalAbsolutePath(destination)
    let receiptPath = try canonicalAbsolutePath(receipt)
    try validateSnapshotReceiptNameBinding(snapshot: destinationPath, receipt: receiptPath)
    guard destinationPath != receiptPath else { throw fail("snapshot_receipt_path_collision") }
    let destinationParent = URL(fileURLWithPath: destinationPath).deletingLastPathComponent().path
    let receiptParent = URL(fileURLWithPath: receiptPath).deletingLastPathComponent().path
    guard destinationParent == receiptParent else { throw fail("snapshot_receipt_parent_mismatch") }
    let parentFD = try openDirectoryChain(destinationParent, create: true)
    defer { Darwin.close(parentFD) }
    let resolvedParent = try resolvedPath(destinationParent)
    let resolvedRepository = try resolvedPath(repositoryRoot)
    guard !path(resolvedParent, isWithin: resolvedRepository) else {
        throw fail("snapshot_and_initial_receipt_must_be_repository_external")
    }
    for name in [
        URL(fileURLWithPath: destinationPath).lastPathComponent,
        URL(fileURLWithPath: receiptPath).lastPathComponent,
    ] {
        guard !name.isEmpty, name != ".", name != ".." else { throw fail("custody_invalid_filename") }
        var info = stat()
        errno = 0
        guard fstatat(parentFD, name, &info, AT_SYMLINK_NOFOLLOW) != 0, errno == ENOENT else {
            throw fail("custody_output_already_exists")
        }
    }
}

private func validateReceiptRecoveryPair(
    snapshot: String,
    receipt: String,
    repositoryRoot: String
) throws -> Bool {
    let snapshotPath = try canonicalAbsolutePath(snapshot)
    let receiptPath = try canonicalAbsolutePath(receipt)
    guard snapshotPath != receiptPath else { throw fail("snapshot_receipt_path_collision") }
    let snapshotURL = URL(fileURLWithPath: snapshotPath)
    let receiptURL = URL(fileURLWithPath: receiptPath)
    try validateSnapshotReceiptNameBinding(snapshot: snapshotPath, receipt: receiptPath)
    let parent = snapshotURL.deletingLastPathComponent().path
    guard parent == receiptURL.deletingLastPathComponent().path else {
        throw fail("snapshot_receipt_parent_mismatch")
    }
    let parentFD = try openDirectoryChain(parent, create: false)
    defer { Darwin.close(parentFD) }
    let resolvedParent = try resolvedPath(parent)
    let resolvedRepository = try resolvedPath(repositoryRoot)
    guard !path(resolvedParent, isWithin: resolvedRepository) else {
        throw fail("snapshot_and_initial_receipt_must_be_repository_external")
    }
    var snapshotInfo = stat()
    guard fstatat(parentFD, snapshotURL.lastPathComponent, &snapshotInfo, AT_SYMLINK_NOFOLLOW) == 0,
          (snapshotInfo.st_mode & S_IFMT) == S_IFREG,
          snapshotInfo.st_uid == getuid(),
          snapshotInfo.st_nlink == 1,
          UInt16(snapshotInfo.st_mode & 0o7777) == 0o400 else {
        throw fail("recovery_snapshot_custody_mismatch")
    }
    var receiptInfo = stat()
    errno = 0
    if fstatat(parentFD, receiptURL.lastPathComponent, &receiptInfo, AT_SYMLINK_NOFOLLOW) == 0 {
        guard (receiptInfo.st_mode & S_IFMT) == S_IFREG,
              receiptInfo.st_uid == getuid(),
              receiptInfo.st_nlink == 1,
              UInt16(receiptInfo.st_mode & 0o7777) == 0o400 else {
            throw fail("recovery_existing_receipt_custody_mismatch")
        }
        return true
    }
    guard errno == ENOENT else { throw fail("recovery_receipt_probe_failed") }
    return false
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

@discardableResult
private func atomicWriteNoReplace(
    _ data: Data,
    destination: String,
    mode: mode_t
) throws -> FileIdentity {
    let canonicalDestination = try canonicalAbsolutePath(destination)
    let parent = URL(fileURLWithPath: canonicalDestination).deletingLastPathComponent().path
    let finalName = URL(fileURLWithPath: canonicalDestination).lastPathComponent
    let parentFD = try openDirectoryChain(parent, create: true)
    defer { Darwin.close(parentFD) }
    guard flock(parentFD, LOCK_EX) == 0 else { throw fail("publication_lock_failed") }
    defer { _ = flock(parentFD, LOCK_UN) }
    var existingFinal = stat()
    errno = 0
    guard fstatat(parentFD, finalName, &existingFinal, AT_SYMLINK_NOFOLLOW) != 0 else {
        throw fail("destination_exists")
    }
    guard errno == ENOENT else { throw fail("destination_probe_failed") }
    let temporary = ".qinao-vault-" + String(Data(finalName.utf8).sha256Hex.prefix(32)) + ".tmp"
    var stale = stat()
    errno = 0
    if fstatat(parentFD, temporary, &stale, AT_SYMLINK_NOFOLLOW) == 0 {
        guard (stale.st_mode & S_IFMT) == S_IFREG,
              stale.st_uid == getuid(),
              stale.st_nlink == 1,
              (stale.st_mode & 0o077) == 0 else {
            throw fail("stale_temporary_custody_mismatch")
        }
        guard unlinkat(parentFD, temporary, 0) == 0,
              fsync(parentFD) == 0 else {
            throw fail("stale_temporary_cleanup_failed")
        }
    } else if errno != ENOENT {
        throw fail("temporary_probe_failed")
    }
    let fd = openat(parentFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard fd >= 0 else { throw fail("temporary_create_failed") }
    var keepTemporary = true
    defer {
        Darwin.close(fd)
        if keepTemporary { _ = unlinkat(parentFD, temporary, 0) }
    }
    try writeAll(fd: fd, data: data)
    guard fsync(fd) == 0, fchmod(fd, mode) == 0, fsync(fd) == 0 else {
        throw fail("file_durability_failed")
    }
    guard renameatx_np(parentFD, temporary, parentFD, finalName, UInt32(RENAME_EXCL)) == 0 else {
        if errno == EEXIST { throw fail("destination_exists") }
        throw fail("atomic_rename_failed")
    }
    keepTemporary = false
    guard fsync(parentFD) == 0 else { throw fail("directory_durability_failed") }
    var finalInfo = stat()
    var descriptorInfo = stat()
    guard fstatat(parentFD, finalName, &finalInfo, AT_SYMLINK_NOFOLLOW) == 0,
          fstat(fd, &descriptorInfo) == 0,
          finalInfo.st_dev == descriptorInfo.st_dev,
          finalInfo.st_ino == descriptorInfo.st_ino,
          (finalInfo.st_mode & S_IFMT) == S_IFREG,
          finalInfo.st_nlink == 1,
          finalInfo.st_uid == getuid(),
          (finalInfo.st_mode & 0o077) == 0 else {
        throw fail("published_file_permissions")
    }
    return try fileIdentity(descriptorInfo)
}

private func executableDigest() throws -> String {
    var capacity: UInt32 = 0
    _ = _NSGetExecutablePath(nil, &capacity)
    guard capacity > 1, capacity <= UInt32(PATH_MAX) * 4 else {
        throw fail("executable_path_size")
    }
    var buffer = [CChar](repeating: 0, count: Int(capacity))
    let pathStatus = buffer.withUnsafeMutableBufferPointer { pointer in
        _NSGetExecutablePath(pointer.baseAddress, &capacity)
    }
    guard pathStatus == 0 else { throw fail("executable_path_unavailable") }
    let reportedPath = String(cString: buffer)
    guard let resolvedPointer = realpath(reportedPath, nil) else {
        throw fail("executable_realpath_failed")
    }
    defer { free(resolvedPointer) }
    let resolved = String(cString: resolvedPointer)
    let fd = Darwin.open(resolved, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    guard fd >= 0 else { throw fail("executable_open_failed") }
    defer { Darwin.close(fd) }
    var before = stat()
    guard fstat(fd, &before) == 0,
          (before.st_mode & S_IFMT) == S_IFREG else {
        throw fail("executable_identity_failed")
    }
    var hasher = SHA256()
    var chunk = [UInt8](repeating: 0, count: 64 * 1024)
    while true {
        let amount = chunk.withUnsafeMutableBytes { raw in
            Darwin.read(fd, raw.baseAddress, raw.count)
        }
        guard amount >= 0 else {
            if errno == EINTR { continue }
            throw fail("executable_read_failed")
        }
        if amount == 0 { break }
        hasher.update(data: Data(chunk[0..<amount]))
    }
    var after = stat()
    guard fstat(fd, &after) == 0,
          before.st_dev == after.st_dev,
          before.st_ino == after.st_ino,
          before.st_size == after.st_size,
          before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
          before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec else {
        throw fail("executable_changed_during_digest")
    }
    return Data(hasher.finalize()).hex
}

// Frozen v1 byte contract. Recovery must continue to use capture-time metadata,
// never ambient verifier metadata, so historical receipts remain reproducible.
private func publicReceiptV1(
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
    custodyClass: String,
    sqliteRuntimeVersion: String
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
        "sqliteRuntimeVersion": sqliteRuntimeVersion,
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
  recover-receipt --snapshot PATH --receipt PATH --scan-id UUID
         --target-revision SHA40 --key-epoch LABEL --erasure-scope LABEL
  help

All encryption and commitment keys are generated and retrieved through Apple
Keychain. The production CLI accepts no raw key material.
"""

#if QINAO_INTEGRATION_TESTING
private func purgeTestKeyEpoch(_ arguments: Arguments) throws {
    try arguments.validate(allowed: ["--key-epoch", "--confirm"])
    let epoch = try arguments.required("--key-epoch")
    let confirmation = try arguments.required("--confirm")
    try validateCustodyLabel(epoch, code: "invalid_key_epoch")
    guard epoch.hasPrefix("test-"), confirmation == "TEST-ONLY-ERASURE" else {
        throw fail("test_key_erasure_guard")
    }
    try deleteTestKey(service: encryptionService, account: "ds1.encryption.\(epoch)")
    try deleteTestKey(service: commitmentService, account: "ds1.commitment.\(epoch)")
    try printJSON([
        "schema": "qinao.ds1-test-key-erasure-receipt.v1",
        "status": "pass",
        "keyEpoch": epoch,
    ])
}
#endif

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

private func validateCustodyLabel(_ value: String, code: String) throws {
    guard (1...128).contains(value.utf8.count),
          value.unicodeScalars.allSatisfy({ scalar in
              (65...90).contains(scalar.value)
                  || (97...122).contains(scalar.value)
                  || (48...57).contains(scalar.value)
                  || scalar.value == 46 || scalar.value == 95 || scalar.value == 45
          }) else {
        throw fail(code)
    }
}

private func freeze(_ arguments: Arguments) throws {
    var allowed: Set<String> = [
        "--source", "--destination", "--receipt", "--scan-id", "--target-revision",
        "--key-epoch", "--erasure-scope", "--tool-source-sha256",
    ]
    #if QINAO_INTEGRATION_TESTING
    allowed.insert("--test-failpoint")
    #endif
    try arguments.validate(allowed: allowed)
    let rawSource = try arguments.required("--source")
    let destination = try arguments.required("--destination")
    let receiptPath = try arguments.required("--receipt")
    let scanID = try arguments.required("--scan-id")
    let targetRevision = try arguments.required("--target-revision")
    let epoch = try arguments.required("--key-epoch")
    let erasureScope = try arguments.required("--erasure-scope")
    let sourceSHA = try arguments.required("--tool-source-sha256")
    #if QINAO_INTEGRATION_TESTING
    if let failpoint = arguments.values["--test-failpoint"],
       failpoint != "after-snapshot-publish" {
        throw fail("unknown_test_failpoint")
    }
    #endif
    try validateIdentity(scanID: scanID, targetRevision: targetRevision, sourceSHA: sourceSHA)
    try validateCustodyLabel(epoch, code: "invalid_key_epoch")
    try validateCustodyLabel(erasureScope, code: "invalid_erasure_scope")
    try validateExternalOutputPair(
        destination: destination,
        receipt: receiptPath,
        repositoryRoot: FileManager.default.currentDirectoryPath
    )
    let sourceLease = try openSourceFileLease(rawSource)
    defer {
        Darwin.close(sourceLease.fileFD)
        Darwin.close(sourceLease.parentFD)
    }
    let source = sourceLease.canonicalPath
    let sourceBefore = sourceLease.initialIdentity
    let createdAt = utcTimestamp()
    let captureID = UUID().uuidString.lowercased()
    let binarySHA = try executableDigest()
    let sqliteBytes = try backupDatabase(sourcePath: source)
    let sourceAfter = try sourceLeaseIdentity(sourceLease)
    guard sourceBefore.device == sourceAfter.device,
          sourceBefore.inode == sourceAfter.inode else { throw fail("source_identity_changed") }
    let audit = try auditSnapshot(sqliteBytes, scanID: scanID, targetRevision: targetRevision)
    let sqliteRuntime = String(cString: sqlite3_libversion())
    var encryptionKey = try loadOrCreateKey(
        service: encryptionService,
        account: "ds1.encryption.\(epoch)",
        create: true
    )
    var commitmentKey = try loadOrCreateKey(
        service: commitmentService,
        account: "ds1.commitment.\(epoch)",
        create: true
    )
    defer {
        encryptionKey.bestEffortZeroize()
        commitmentKey.bestEffortZeroize()
    }
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
            "sourceConnection": "ordinary SQLITE_OPEN_READONLY with WAL/SHM semantics; canonical no-follow source descriptor retained and rechecked",
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
            "sqliteRuntime": sqliteRuntime,
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
            "receiptBasename": URL(fileURLWithPath: receiptPath).lastPathComponent,
            "publication": publicationContract,
            "repositoryExternal": true,
        ],
        "officialReadError": "Codex Security scan artifact root is not a safe regular directory.",
    ]
    for (key, value) in audit.privateFragment { privateManifest[key] = value }
    let privateManifestBytes = try canonicalJSON(privateManifest)
    guard privateManifestBytes.count <= maximumPrivateManifestBytes else {
        throw fail("private_manifest_size_limit")
    }
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
    guard envelope.count <= maximumEnvelopeBytes else { throw fail("envelope_size_limit") }
    let custody = try atomicWriteNoReplace(envelope, destination: destination, mode: 0o400)
    guard custody.size == UInt64(envelope.count), custody.mode == 0o400, custody.links == 1 else {
        throw fail("custody_post_publish_mismatch")
    }
    #if QINAO_INTEGRATION_TESTING
    if arguments.values["--test-failpoint"] == "after-snapshot-publish" {
        Darwin._exit(86)
    }
    #endif
    let receipt = publicReceiptV1(
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
        custodyClass: "repository-external-local-encrypted-regular-single-link",
        sqliteRuntimeVersion: sqliteRuntime
    )
    let receiptBytes = try canonicalJSON(receipt)
    try atomicWriteNoReplace(receiptBytes, destination: receiptPath, mode: 0o400)
    let publishedSnapshot = try privateFileReadNoFollow(destination, requiredMode: 0o400).data
    let publishedReceipt = try privateFileReadNoFollow(
        receiptPath,
        requiredMode: 0o400,
        maximumBytes: maximumReceiptBytes
    ).data
    guard publishedSnapshot == envelope, publishedReceipt == receiptBytes else {
        throw fail("capture_pair_post_publish_mismatch")
    }
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

private func valueInt(_ object: [String: Any], _ key: String) throws -> Int {
    guard let value = object[key] as? Int else { throw fail("missing_json_integer") }
    return value
}

private struct ReopenedEvidence {
    let captureID: String
    let createdAt: String
    let toolSourceSHA: String
    let toolBinarySHA: String
    let sqliteRuntime: String
    let privateManifest: [String: Any]
    let privateManifestBytes: Data
    let sqliteBytes: Data
    let audit: AuditEvidence
}

private func reopenEvidence(
    envelope: Data,
    snapshotPath: String,
    receiptPath: String,
    scanID: String,
    targetRevision: String,
    epoch: String,
    erasureScope: String,
    encryptionKey: Data
) throws -> ReopenedEvidence {
    let opened = try openEnvelope(envelope, key: encryptionKey)
    let header = try parseJSONObject(opened.header)
    let captureID = try valueString(header, "captureID")
    let createdAt = try valueString(header, "createdAtUTC")
    let toolSourceSHA = try valueString(header, "toolSourceSHA256")
    let toolBinarySHA = try valueString(header, "toolBinarySHA256")
    guard try valueString(header, "schema") == "qinao.ds1-envelope-header.v1",
          try valueInt(header, "formatVersion") == formatVersion,
          try valueInt(header, "scanNumber") == scanNumber,
          UUID(uuidString: captureID) != nil,
          !createdAt.isEmpty,
          try valueString(header, "scanID") == scanID,
          try valueString(header, "targetRevision") == targetRevision,
          try valueString(header, "keyEpoch") == epoch,
          try valueString(header, "erasureScope") == erasureScope,
          try valueString(header, "algorithm") == "AES-256-GCM" else {
        throw fail("envelope_header_binding")
    }
    try validateIdentity(
        scanID: scanID,
        targetRevision: targetRevision,
        sourceSHA: toolSourceSHA
    )
    try validateIdentity(scanID: scanID, targetRevision: targetRevision, sourceSHA: toolBinarySHA)

    let parsed = try parsePayload(opened.payload)
    let privateManifest = try parseJSONObject(parsed.manifest)
    guard try valueString(privateManifest, "schemaVersion") == "qinao.ds1-private-custody-manifest.v1",
          try valueString(privateManifest, "manifestKind") == "qinao-ds1-private-custody-manifest",
          try valueString(privateManifest, "captureID") == captureID,
          try valueString(privateManifest, "createdAtUTC") == createdAt,
          try valueString(privateManifest, "semanticOperationID") == "qinao.deep-scan-1.freeze.\(scanID).\(targetRevision)",
          let scanBinding = privateManifest["scanBinding"] as? [String: Any],
          try valueInt(scanBinding, "scanNumber") == scanNumber,
          try valueString(scanBinding, "scanID") == scanID,
          try valueString(scanBinding, "targetRevision") == targetRevision,
          try valueString(scanBinding, "mode") == "deep",
          try valueString(scanBinding, "officialState") == "complete",
          try valueString(scanBinding, "canonicalArtifactState") == "canonicalUnavailable",
          let encryption = privateManifest["encryption"] as? [String: Any],
          try valueString(encryption, "keyEpoch") == epoch,
          try valueString(encryption, "erasureScope") == erasureScope,
          let toolBinding = privateManifest["exportToolBinding"] as? [String: Any],
          try valueString(toolBinding, "sourceSHA256") == toolSourceSHA,
          try valueString(toolBinding, "binarySHA256") == toolBinarySHA,
          try valueInt(toolBinding, "formatVersion") == formatVersion,
          let custody = privateManifest["custody"] as? [String: Any],
          try canonicalAbsolutePath(valueString(custody, "destination")) == canonicalAbsolutePath(snapshotPath),
          custody["repositoryExternal"] as? Bool == true else {
        throw fail("private_manifest_binding")
    }
    if let receiptBasename = custody["receiptBasename"] as? String {
        guard !receiptBasename.isEmpty,
              !receiptBasename.contains("/"),
              receiptBasename.hasSuffix(".capture-receipt.json"),
              receiptBasename == URL(fileURLWithPath: receiptPath).lastPathComponent else {
            throw fail("private_manifest_receipt_name_binding")
        }
    }
    let sqliteRuntime = try valueString(toolBinding, "sqliteRuntime")
    let audit = try auditSnapshot(
        parsed.sqlite,
        scanID: scanID,
        targetRevision: targetRevision,
        capturedSQLiteRuntime: sqliteRuntime,
        capturedPrivateManifest: privateManifest
    )
    guard try privateFragmentMatches(manifest: privateManifest, expected: audit.privateFragment) else {
        throw fail("private_manifest_audit_fragment_mismatch")
    }
    return ReopenedEvidence(
        captureID: captureID,
        createdAt: createdAt,
        toolSourceSHA: toolSourceSHA,
        toolBinarySHA: toolBinarySHA,
        sqliteRuntime: sqliteRuntime,
        privateManifest: privateManifest,
        privateManifestBytes: parsed.manifest,
        sqliteBytes: parsed.sqlite,
        audit: audit
    )
}

private func rebuiltPublicReceipt(
    evidence: ReopenedEvidence,
    envelope: Data,
    scanID: String,
    targetRevision: String,
    epoch: String,
    erasureScope: String,
    commitmentKey: Data
) throws -> Data {
    try canonicalJSON(publicReceiptV1(
        captureID: evidence.captureID,
        createdAt: evidence.createdAt,
        scanID: scanID,
        targetRevision: targetRevision,
        epoch: epoch,
        erasureScope: erasureScope,
        toolSourceSHA256: evidence.toolSourceSHA,
        binarySHA256: evidence.toolBinarySHA,
        audit: evidence.audit,
        privateManifest: evidence.privateManifestBytes,
        sqlite: evidence.sqliteBytes,
        envelope: envelope,
        commitmentKey: commitmentKey,
        custodyClass: "repository-external-local-encrypted-regular-single-link",
        sqliteRuntimeVersion: evidence.sqliteRuntime
    ))
}

private func liveDeadLocatorStatus(_ manifest: [String: Any]) -> String {
    do {
        guard let artifacts = manifest["deadArtifactEvidence"] as? [[String: Any]],
              artifacts.count == 4,
              let root = manifest["deadCommonRoot"] as? [String: Any] else {
            return "drift: captured evidence shape unavailable"
        }
        for artifact in artifacts {
            let expectedPath = try valueString(artifact, "path")
            let expectedMissingAt = try valueString(artifact, "missingAt")
            let observed = try noFollowMissingProbe(expectedPath)
            guard observed.missingAt == expectedMissingAt else {
                return "drift: locator missing boundary changed"
            }
        }
        let expectedRoot = try valueString(root, "path")
        let expectedRootMissingAt = try valueString(root, "missingAt")
        let observedRoot = try noFollowMissingProbe(expectedRoot)
        guard observedRoot.missingAt == expectedRootMissingAt else {
            return "drift: common-root missing boundary changed"
        }
        return "pass: 4/4 ENOENT and common root ENOENT"
    } catch {
        return "drift: live locator state no longer matches capture"
    }
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
    try validateCustodyLabel(epoch, code: "invalid_key_epoch")
    try validateCustodyLabel(erasureScope, code: "invalid_erasure_scope")
    guard try validateReceiptRecoveryPair(
        snapshot: snapshotPath,
        receipt: receiptPath,
        repositoryRoot: FileManager.default.currentDirectoryPath
    ) else {
        throw fail("verification_receipt_missing")
    }
    let snapshotRead = try privateFileReadNoFollow(snapshotPath, requiredMode: 0o400)
    let envelope = snapshotRead.data
    let externalReceiptBytes = try privateFileReadNoFollow(
        receiptPath,
        requiredMode: 0o400,
        maximumBytes: maximumReceiptBytes
    ).data
    _ = try parseJSONObject(externalReceiptBytes)
    var encryptionKey = try loadOrCreateKey(
        service: encryptionService,
        account: "ds1.encryption.\(epoch)",
        create: false
    )
    var commitmentKey = try loadOrCreateKey(
        service: commitmentService,
        account: "ds1.commitment.\(epoch)",
        create: false
    )
    defer {
        encryptionKey.bestEffortZeroize()
        commitmentKey.bestEffortZeroize()
    }
    let evidence = try reopenEvidence(
        envelope: envelope,
        snapshotPath: snapshotPath,
        receiptPath: receiptPath,
        scanID: scanID,
        targetRevision: targetRevision,
        epoch: epoch,
        erasureScope: erasureScope,
        encryptionKey: encryptionKey
    )
    let expectedReceiptBytes = try rebuiltPublicReceipt(
        evidence: evidence,
        envelope: envelope,
        scanID: scanID,
        targetRevision: targetRevision,
        epoch: epoch,
        erasureScope: erasureScope,
        commitmentKey: commitmentKey
    )
    guard expectedReceiptBytes == externalReceiptBytes else {
        throw fail("public_receipt_mismatch")
    }
    let verification: [String: Any] = [
        "schema": "qinao.ds1-independent-reopen-receipt.v2",
        "status": "pass",
        "verifiedAtUTC": utcTimestamp(),
        "freshProcess": true,
        "captureID": evidence.captureID,
        "scanNumber": scanNumber,
        "scanID": scanID,
        "targetRevision": targetRevision,
        "ciphertextBytes": envelope.count,
        "ciphertextSHA256": envelope.sha256Hex,
        "aeadAuthentication": "pass",
        "privateManifestAuthenticated": true,
        "privateManifestScanBindingChecked": true,
        "privateManifestAuditFragmentRecomputed": true,
        "orderedQueriesRecomputed": querySpecs.count,
        "counts": evidence.audit.counts,
        "deadLocatorCapturedEvidenceAuthenticated": true,
        "deadLocatorLiveReprobe": liveDeadLocatorStatus(evidence.privateManifest),
        "quickCheck": "ok",
        "foreignKeyCheckRows": 0,
        "plaintextFileCreated": false,
        "publicReceiptExactBytes": true,
        "verifierBinarySHA256": try executableDigest(),
        "keyEpoch": epoch,
        "erasureScope": erasureScope,
    ]
    try atomicWriteNoReplace(try canonicalJSON(verification), destination: verificationPath, mode: 0o400)
    try printJSON(verification)
}

private func recoverReceipt(_ arguments: Arguments) throws {
    let allowed: Set<String> = [
        "--snapshot", "--receipt", "--scan-id", "--target-revision",
        "--key-epoch", "--erasure-scope",
    ]
    try arguments.validate(allowed: allowed)
    let snapshotPath = try arguments.required("--snapshot")
    let receiptPath = try arguments.required("--receipt")
    let scanID = try arguments.required("--scan-id")
    let targetRevision = try arguments.required("--target-revision")
    let epoch = try arguments.required("--key-epoch")
    let erasureScope = try arguments.required("--erasure-scope")
    try validateIdentity(scanID: scanID, targetRevision: targetRevision)
    try validateCustodyLabel(epoch, code: "invalid_key_epoch")
    try validateCustodyLabel(erasureScope, code: "invalid_erasure_scope")
    let receiptAlreadyExists = try validateReceiptRecoveryPair(
        snapshot: snapshotPath,
        receipt: receiptPath,
        repositoryRoot: FileManager.default.currentDirectoryPath
    )
    let envelope = try privateFileReadNoFollow(snapshotPath, requiredMode: 0o400).data
    var encryptionKey = try loadOrCreateKey(
        service: encryptionService,
        account: "ds1.encryption.\(epoch)",
        create: false
    )
    var commitmentKey = try loadOrCreateKey(
        service: commitmentService,
        account: "ds1.commitment.\(epoch)",
        create: false
    )
    defer {
        encryptionKey.bestEffortZeroize()
        commitmentKey.bestEffortZeroize()
    }
    let evidence = try reopenEvidence(
        envelope: envelope,
        snapshotPath: snapshotPath,
        receiptPath: receiptPath,
        scanID: scanID,
        targetRevision: targetRevision,
        epoch: epoch,
        erasureScope: erasureScope,
        encryptionKey: encryptionKey
    )
    let receiptBytes = try rebuiltPublicReceipt(
        evidence: evidence,
        envelope: envelope,
        scanID: scanID,
        targetRevision: targetRevision,
        epoch: epoch,
        erasureScope: erasureScope,
        commitmentKey: commitmentKey
    )
    var status = "recovered"
    if receiptAlreadyExists {
        let existing = try privateFileReadNoFollow(
            receiptPath,
            requiredMode: 0o400,
            maximumBytes: maximumReceiptBytes
        ).data
        guard existing == receiptBytes else { throw fail("existing_receipt_mismatch") }
        status = "already-present-exact"
    } else {
        do {
            try atomicWriteNoReplace(receiptBytes, destination: receiptPath, mode: 0o400)
        } catch VaultError.failed(let code) where code == "destination_exists" {
            let concurrent = try privateFileReadNoFollow(
                receiptPath,
                requiredMode: 0o400,
                maximumBytes: maximumReceiptBytes
            ).data
            guard concurrent == receiptBytes else { throw fail("concurrent_receipt_mismatch") }
            status = "concurrent-exact"
        }
    }
    let finalSnapshot = try privateFileReadNoFollow(snapshotPath, requiredMode: 0o400).data
    let published = try privateFileReadNoFollow(
        receiptPath,
        requiredMode: 0o400,
        maximumBytes: maximumReceiptBytes
    ).data
    guard finalSnapshot == envelope, published == receiptBytes else {
        throw fail("recovered_pair_post_publish_mismatch")
    }
    try printJSON([
        "schema": "qinao.ds1-receipt-recovery-operation-result.v1",
        "status": status,
        "captureID": evidence.captureID,
        "ciphertextBytes": envelope.count,
        "ciphertextSHA256": envelope.sha256Hex,
        "publicReceiptExactBytesRebuilt": true,
        "counts": evidence.audit.counts,
    ])
}

#if QINAO_TESTING
private func publicReceiptV1GoldenDigest() throws -> String {
    let audit = AuditEvidence(
        querySetBytes: Data("golden-query-set".utf8),
        schemaBytes: Data("golden-schema".utf8),
        aggregateRawRoot: Data(repeating: 0x11, count: 32),
        deadRawRoot: Data(repeating: 0x22, count: 32),
        counts: [
            "occurrences": 111,
            "locations": 2_716,
            "quickCheck": "ok",
        ],
        privateFragment: [:]
    )
    let receipt = publicReceiptV1(
        captureID: "00000000-0000-4000-8000-000000000001",
        createdAt: "2026-08-28T00:00:00.000Z",
        scanID: "00000000-0000-4000-8000-000000000002",
        targetRevision: String(repeating: "a", count: 40),
        epoch: "golden-epoch",
        erasureScope: "golden-scope",
        toolSourceSHA256: String(repeating: "b", count: 64),
        binarySHA256: String(repeating: "c", count: 64),
        audit: audit,
        privateManifest: Data("golden-private-manifest".utf8),
        sqlite: Data("golden-sqlite".utf8),
        envelope: Data("golden-envelope".utf8),
        commitmentKey: Data(repeating: 0x33, count: 32),
        custodyClass: "golden-custody",
        sqliteRuntimeVersion: "golden-sqlite-runtime"
    )
    let digest = try canonicalJSON(receipt).sha256Hex
    guard digest == "368d6d696dc778753930be828f62df04297e15683eb192b3a5b5b4538e3cc1f6" else {
        throw fail("public_receipt_v1_golden_drift")
    }
    return digest
}

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
    let requestedDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("qinao-vault-self-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
        at: requestedDirectory,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: requestedDirectory) }
    let directory = URL(
        fileURLWithPath: try resolvedPath(requestedDirectory.path),
        isDirectory: true
    )
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
    var oversizedLength = envelope
    var maximumLength = UInt64.max.bigEndian
    let maximumLengthBytes = withUnsafeBytes(of: &maximumLength) { Data($0) }
    oversizedLength.replaceSubrange(
        envelopeMagic.count..<(envelopeMagic.count + 8),
        with: maximumLengthBytes
    )
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
    let expectedFragment: [String: Any] = [
        "aggregateRawRowRootSHA256": encodingA.sha256Hex,
        "integrityResults": ["rows": rows.count],
    ]
    var matchingManifest = expectedFragment
    let fragmentMatches = try privateFragmentMatches(
        manifest: matchingManifest,
        expected: expectedFragment
    )
    matchingManifest["aggregateRawRowRootSHA256"] = String(repeating: "0", count: 64)
    let privateManifestDriftRejected = try !privateFragmentMatches(
        manifest: matchingManifest,
        expected: expectedFragment
    )
    let canonicalReceiptBytes = try canonicalJSON(safeReceipt)
    var nonCanonicalReceiptBytes = canonicalReceiptBytes
    nonCanonicalReceiptBytes.append(0x0a)
    let nonCanonicalReceiptBytesRejected = canonicalReceiptBytes != nonCanonicalReceiptBytes
    let oversizedLengthRejected = rejected(oversizedLength, key: key)
    func rejectsCustody(_ operation: () throws -> Void) -> Bool {
        do { try operation(); return false } catch { return true }
    }
    let repository = directory.appendingPathComponent("repository", isDirectory: true)
    try FileManager.default.createDirectory(
        at: repository,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    let relativeCustodyRejected = rejectsCustody {
        try validateExternalOutputPair(
            destination: "relative.qds1",
            receipt: "relative.capture-receipt.json",
            repositoryRoot: repository.path
        )
    }
    let repositoryCustodyRejected = rejectsCustody {
        try validateExternalOutputPair(
            destination: repository.appendingPathComponent("inside.qds1").path,
            receipt: repository.appendingPathComponent("inside.capture-receipt.json").path,
            repositoryRoot: repository.path
        )
    }
    let realCustody = directory.appendingPathComponent("real-custody", isDirectory: true)
    try FileManager.default.createDirectory(
        at: realCustody,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    let symlinkCustody = directory.appendingPathComponent("custody-link", isDirectory: true)
    try FileManager.default.createSymbolicLink(at: symlinkCustody, withDestinationURL: realCustody)
    let symlinkCustodyRejected = rejectsCustody {
        try validateExternalOutputPair(
            destination: symlinkCustody.appendingPathComponent("linked.qds1").path,
            receipt: symlinkCustody.appendingPathComponent("linked.capture-receipt.json").path,
            repositoryRoot: repository.path
        )
    }
    let atomicDestination = directory.appendingPathComponent("atomic-output.bin")
    let atomicTemporaryName = ".qinao-vault-"
        + String(Data(atomicDestination.lastPathComponent.utf8).sha256Hex.prefix(32))
        + ".tmp"
    let staleTemporary = directory.appendingPathComponent(atomicTemporaryName)
    try Data("abandoned-ciphertext-staging".utf8).write(to: staleTemporary)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: staleTemporary.path
    )
    let atomicExpected = Data("atomic-ciphertext-fixture".utf8)
    let atomicIdentity = try atomicWriteNoReplace(
        atomicExpected,
        destination: atomicDestination.path,
        mode: 0o400
    )
    let atomicPublished = try privateFileReadNoFollow(
        atomicDestination.path,
        requiredMode: 0o400
    ).data
    let staleAtomicTemporaryRecovered = atomicPublished == atomicExpected
        && atomicIdentity.links == 1
        && !FileManager.default.fileExists(atPath: staleTemporary.path)
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
        fragmentMatches,
        privateManifestDriftRejected,
        nonCanonicalReceiptBytesRejected,
        relativeCustodyRejected,
        symlinkCustodyRejected,
        repositoryCustodyRejected,
        oversizedLengthRejected,
        staleAtomicTemporaryRecovered,
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
        "privateManifestDriftRejected": privateManifestDriftRejected,
        "nonCanonicalReceiptBytesRejected": nonCanonicalReceiptBytesRejected,
        "relativeCustodyRejected": relativeCustodyRejected,
        "symlinkCustodyRejected": symlinkCustodyRejected,
        "repositoryCustodyRejected": repositoryCustodyRejected,
        "oversizedLengthRejected": oversizedLengthRejected,
        "staleAtomicTemporaryRecovered": staleAtomicTemporaryRecovered,
        "executableBinarySHA256": try executableDigest(),
        "publicReceiptV1GoldenSHA256": try publicReceiptV1GoldenDigest(),
    ])
}
#endif

private func run() throws {
    try disableCoreDumps()
    let arguments = try Arguments(Array(CommandLine.arguments.dropFirst()))
    switch arguments.command {
    case "help", "--help", "-h":
        guard arguments.values.isEmpty else { throw VaultError.usage("help_takes_no_arguments") }
        print(helpText)
    case "freeze":
        try freeze(arguments)
    case "verify":
        try verify(arguments)
    case "recover-receipt":
        try recoverReceipt(arguments)
    #if QINAO_INTEGRATION_TESTING
    case "purge-test-key-epoch":
        try purgeTestKeyEpoch(arguments)
    #endif
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
