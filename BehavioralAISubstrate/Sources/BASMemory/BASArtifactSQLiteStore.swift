import Crypto
import Foundation
import SQLite3
import BASRuntimeCore

public actor BASArtifactSQLiteStore: BASArtifactStorePort {
    public enum StorageError: Error, Sendable, Equatable {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case partialOrUnknownSchema(String)
        case commitmentKeyUnavailable(epoch: UInt64, reason: String)
        case recordNotFound(String)
        case corruptedRecord(artifactID: String, reason: String)
        case invalidAttestation(String)
        case invalidHeadExpectation
        case headCASConflict
        case headScopeMismatch
        case headRevisionOverflow
        case transactionRecoveryFailed(String)
    }

    public static let schemaVersion = 1

    private enum TextColumnMaximum {
        static let artifactID = 4_096
        static let uint64Decimal = 20
        // 24-byte versioned prefix plus 64 lowercase hex bytes.
        static let payloadReference = 88
        // Audited against the five generated Artifact Mesh v1 statements.
        static let schemaObjectName = 36
        static let schemaDefinition = 1_703
        static let columnName = 23
        static let declaredType = 4
        static let pragmaValue = 3
    }

    public let databaseURL: URL
    public let activeCommitmentKeyEpoch: UInt64
    public private(set) var fileProtectionError: Error?

    private let commitmentKeyResolver: BASArtifactCommitmentKeyResolver
    private nonisolated(unsafe) var db: OpaquePointer?

    public init(
        databaseURL: URL,
        activeCommitmentKeyEpoch: UInt64,
        commitmentKeyResolver: @escaping BASArtifactCommitmentKeyResolver
    ) throws {
        self.databaseURL = databaseURL
        self.activeCommitmentKeyEpoch = activeCommitmentKeyEpoch
        self.commitmentKeyResolver = commitmentKeyResolver
        self.fileProtectionError = nil
        self.db = nil

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_CREATE
            | SQLITE_OPEN_FULLMUTEX
        let openRC = sqlite3_open_v2(
            databaseURL.path, &handle, flags, nil)
        guard openRC == SQLITE_OK, let handle else {
            let message = handle.map {
                String(cString: sqlite3_errmsg($0))
            } ?? "sqlite3_open_v2 rc=\(openRC)"
            if handle != nil { sqlite3_close_v2(handle) }
            throw StorageError.openFailed(
                code: openRC, message: message)
        }
        self.db = handle
        var initializationSucceeded = false
        defer {
            if !initializationSucceeded {
                sqlite3_close_v2(handle)
                self.db = nil
            }
        }

        // Structural corruption is checked before any pragma or schema
        // operation that could alter the file.
        try BASSQLiteIntegrity.assertOK(
            db: handle, store: "artifact-mesh")
        sqlite3_busy_timeout(handle, 5_000)
        try Self.runExec(
            db: handle, sql: "PRAGMA journal_mode=WAL;")
        try Self.requirePragmaText(
            db: handle, sql: "PRAGMA journal_mode;", expected: "wal")
        if let secureDelete = BASSQLiteSecureDelete.openPragmaSQL {
            try Self.runExec(db: handle, sql: secureDelete)
        }
        try Self.runExec(
            db: handle, sql: "PRAGMA synchronous=NORMAL;")
        try Self.runExec(
            db: handle, sql: "PRAGMA foreign_keys=ON;")
        try Self.requirePragmaInteger(
            db: handle, sql: "PRAGMA foreign_keys;", expected: 1)
        try Self.runExec(
            db: handle, sql: "PRAGMA wal_autocheckpoint=200;")

        let version = try Self.readUserVersion(db: handle)
        switch version {
        case 0:
            let tables = try Self.applicationTableNames(db: handle)
            guard tables.isEmpty else {
                throw StorageError.partialOrUnknownSchema(
                    "user_version=0 with existing tables \(tables.sorted())")
            }
            try Self.runExec(db: handle, sql: "BEGIN IMMEDIATE;")
            do {
                try Self.runExec(
                    db: handle,
                    sql: ArtifactMeshV1Schema.allStatementsSQL)
                try Self.runExec(
                    db: handle,
                    sql: "PRAGMA user_version=\(Self.schemaVersion);")
                try Self.validateSchema(db: handle)
                try Self.runExec(db: handle, sql: "COMMIT;")
            } catch {
                try? Self.runExec(db: handle, sql: "ROLLBACK;")
                throw error
            }
        case Self.schemaVersion:
            try Self.validateSchema(db: handle)
        default:
            throw StorageError.schemaVersionMismatch(
                found: version, expected: Self.schemaVersion)
        }

        // Run only after migration/validation so its marker table cannot
        // make a partial v0 database appear fresh.
        BASSQLiteSecureDelete.runOneTimeLegacyVacuum(db: handle)
        try Self.validateSchema(db: handle)
        self.fileProtectionError = BASSQLiteFileProtection.apply(
            toDatabaseAt: databaseURL.path)
        initializationSucceeded = true
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    public func put(
        identityCore: BASArtifactIdentityCore,
        headUpdate: BASArtifactHeadCAS?
    ) async throws -> BASArtifactStoreReceipt {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "database handle unavailable")
        }
        let commitmentKey = try resolveKey(
            epoch: activeCommitmentKeyEpoch)
        let artifactID = try BASArtifactMesh.artifactID(
            for: identityCore,
            commitmentKey: commitmentKey,
            commitmentKeyEpoch: activeCommitmentKeyEpoch)
        if let headUpdate {
            guard headUpdate.replacementArtifactID == artifactID else {
                throw StorageError.invalidHeadExpectation
            }
            if let expected = headUpdate.expected,
               expected.key != headUpdate.key {
                throw StorageError.invalidHeadExpectation
            }
            try Self.requireScope(
                identityCore.scopeBinding,
                matches: headUpdate.key.scope)
        }
        let attestation: BASArtifactAttestationPayload?
        if identityCore.kind == "artifact-attestation" {
            do {
                attestation = try BASGovernedArtifactPayloadCodec
                    .decodeCurrent(
                        BASArtifactAttestationPayload.self,
                        from: identityCore.canonicalPayloadBytes)
            } catch {
                throw StorageError.invalidAttestation(
                    String(describing: error))
            }
        } else {
            attestation = nil
        }

        try Self.runExec(db: db, sql: "BEGIN IMMEDIATE;")
        do {
            let storage: BASArtifactStorageEnvelope
            if let row = try Self.fetchRecordRow(
                db: db, artifactID: artifactID)
            {
                let existing = try verifiedRecord(
                    row: row, expectedArtifactID: artifactID)
                guard existing.identityCore == identityCore else {
                    throw StorageError.corruptedRecord(
                        artifactID: try artifactID.storageScalar,
                        reason: "same keyed ID maps to different identity bytes")
                }
                storage = existing.storage
            } else {
                storage = BASArtifactStorageEnvelope(
                    artifactID: artifactID,
                    payloadRef: Self.randomPayloadRef(),
                    storedLength: identityCore.payloadLength,
                    storageEncoding: nil,
                    compression: nil,
                    encryptionKeyID: nil,
                    encryptionMetadata: [])
                let record = BASArtifactMeshRecord(
                    artifactID: artifactID,
                    identityCore: identityCore,
                    storage: storage)
                let recordBytes = try BASGovernedArtifactPayloadCodec
                    .canonicalBytes(for: record)
                try Self.insertRecord(
                    db: db,
                    artifactID: artifactID,
                    recordBytes: recordBytes,
                    payloadRef: storage.payloadRef)
            }

            if let attestation {
                guard let targetRow = try Self.fetchRecordRow(
                    db: db,
                    artifactID: attestation.targetArtifactID)
                else {
                    throw StorageError.invalidAttestation(
                        "target Artifact does not exist")
                }
                let target = try verifiedRecord(
                    row: targetRow,
                    expectedArtifactID: attestation.targetArtifactID)
                guard target.identityCore.scopeBinding
                        == identityCore.scopeBinding
                else {
                    throw StorageError.invalidAttestation(
                        "target and attestation scopes differ")
                }
                try Self.installAttestationIndex(
                    db: db,
                    attestationArtifactID: artifactID,
                    targetArtifactID: attestation.targetArtifactID)
            }

            let updatedHead: BASArtifactHead?
            if let headUpdate {
                updatedHead = try applyHeadCAS(
                    db: db,
                    cas: headUpdate,
                    replacementIdentity: identityCore)
            } else {
                updatedHead = nil
            }
            try Self.runExec(db: db, sql: "COMMIT;")
            return BASResult(
                success: true,
                body: BASArtifactStoreReceiptBody(
                    artifactID: artifactID,
                    storage: storage,
                    head: updatedHead),
                diagnostics: [])
        } catch {
            let originalError = error
            do {
                try Self.runExec(db: db, sql: "ROLLBACK;")
            } catch {
                let rollbackError = error
                sqlite3_close_v2(db)
                self.db = nil
                throw StorageError.transactionRecoveryFailed(
                    "original=\(originalError); rollback=\(rollbackError)")
            }
            throw originalError
        }
    }

    public func read(
        _ artifactID: BASArtifactID
    ) async throws -> BASArtifactMeshRecord {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "database handle unavailable")
        }
        guard let row = try Self.fetchRecordRow(
            db: db, artifactID: artifactID)
        else {
            throw StorageError.recordNotFound(
                try artifactID.storageScalar)
        }
        return try verifiedRecord(
            row: row, expectedArtifactID: artifactID)
    }

    public func head(
        _ key: BASArtifactHeadKey
    ) async throws -> BASArtifactHead? {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "database handle unavailable")
        }
        guard let storedHead = try Self.fetchHead(
            db: db, key: key)
        else {
            return nil
        }
        guard let row = try Self.fetchRecordRow(
            db: db, artifactID: storedHead.artifactID)
        else {
            throw StorageError.corruptedRecord(
                artifactID: try storedHead.artifactID.storageScalar,
                reason: "head references a missing Artifact")
        }
        let record = try verifiedRecord(
            row: row, expectedArtifactID: storedHead.artifactID)
        try Self.requireScope(
            record.identityCore.scopeBinding,
            matches: key.scope)
        return storedHead
    }

    public func attestationArtifactIDs(
        targeting artifactID: BASArtifactID
    ) async throws -> BASBundle<BASArtifactID> {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "database handle unavailable")
        }
        let targetScalar = try artifactID.storageScalar
        guard let targetRow = try Self.fetchRecordRow(
            db: db, artifactID: artifactID)
        else {
            throw StorageError.corruptedRecord(
                artifactID: targetScalar,
                reason: "attestation target Artifact is missing")
        }
        _ = try verifiedRecord(
            row: targetRow, expectedArtifactID: artifactID)
        let sql = """
            SELECT attestation_artifact_id
            FROM artifact_mesh_attestation_targets
            WHERE target_artifact_id = ?
            ORDER BY attestation_artifact_id ASC;
            """
        let statement = try Self.prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        Self.bindText(statement, 1, targetScalar)
        var artifactIDs: [BASArtifactID] = []
        var rc = sqlite3_step(statement)
        while rc == SQLITE_ROW {
            let scalar = try Self.columnText(
                statement,
                0,
                maximumBytes: TextColumnMaximum.artifactID,
                sql: sql,
                db: db)
            artifactIDs.append(
                try BASArtifactID(storageScalar: scalar))
            rc = sqlite3_step(statement)
        }
        guard rc == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        for childID in artifactIDs {
            guard let row = try Self.fetchRecordRow(
                db: db, artifactID: childID)
            else {
                throw StorageError.corruptedRecord(
                    artifactID: try childID.storageScalar,
                    reason: "attestation index references a missing Artifact")
            }
            let record = try verifiedRecord(
                row: row, expectedArtifactID: childID)
            guard record.identityCore.kind == "artifact-attestation",
                  let payload = try? BASGovernedArtifactPayloadCodec
                    .decodeCurrent(
                        BASArtifactAttestationPayload.self,
                        from: record.canonicalPayloadBytes),
                  payload.targetArtifactID == artifactID
            else {
                throw StorageError.corruptedRecord(
                    artifactID: try childID.storageScalar,
                    reason: "attestation target index disagrees with payload")
            }
        }
        return BASBundle(
            bundleID: "artifact-attestation-targets-v1:\(targetScalar)",
            items: artifactIDs,
            metadata: [:],
            recordedAt: Date(timeIntervalSince1970: 0))
    }

    private func resolveKey(epoch: UInt64) throws -> SymmetricKey {
        do {
            return try commitmentKeyResolver(epoch)
        } catch {
            throw StorageError.commitmentKeyUnavailable(
                epoch: epoch, reason: String(describing: error))
        }
    }

    private func verifiedRecord(
        row: RecordRow,
        expectedArtifactID: BASArtifactID
    ) throws -> BASArtifactMeshRecord {
        let expectedScalar = try expectedArtifactID.storageScalar
        do {
            guard row.artifactScalar == expectedScalar,
                  try BASArtifactID(storageScalar: row.artifactScalar)
                    == expectedArtifactID,
                  let epoch = UInt64(row.commitmentKeyEpoch),
                  row.commitmentKeyEpoch == String(epoch),
                  epoch == expectedArtifactID.commitmentKeyEpoch
            else {
                throw BASArtifactMeshError.malformedRecord(
                    "row key or commitment epoch is noncanonical")
            }
            let record = try BASGovernedArtifactPayloadCodec
                .decodeCurrent(
                    BASArtifactMeshRecord.self,
                    from: row.recordBytes)
            guard record.artifactID == expectedArtifactID,
                  record.storage.artifactID == expectedArtifactID,
                  record.storage.payloadRef == row.payloadRef,
                  record.storage.storedLength
                    == record.identityCore.payloadLength,
                  record.storage.storageEncoding == nil,
                  record.storage.compression == nil,
                  record.storage.encryptionKeyID == nil,
                  record.storage.encryptionMetadata.isEmpty,
                  Self.isCanonicalPayloadRef(record.storage.payloadRef)
            else {
                throw BASArtifactMeshError.malformedRecord(
                    "stored record envelope disagrees with indexed columns")
            }
            let key = try resolveKey(
                epoch: expectedArtifactID.commitmentKeyEpoch)
            try BASArtifactMesh.verify(record, commitmentKey: key)
            return record
        } catch let error as StorageError {
            throw error
        } catch {
            throw StorageError.corruptedRecord(
                artifactID: expectedScalar,
                reason: String(describing: error))
        }
    }

    private func applyHeadCAS(
        db: OpaquePointer,
        cas: BASArtifactHeadCAS,
        replacementIdentity: BASArtifactIdentityCore
    ) throws -> BASArtifactHead {
        try Self.requireScope(
            replacementIdentity.scopeBinding,
            matches: cas.key.scope)
        if let expected = cas.expected,
           expected.key != cas.key {
            throw StorageError.invalidHeadExpectation
        }
        let current = try Self.fetchHead(db: db, key: cas.key)
        if let current {
            guard let currentRow = try Self.fetchRecordRow(
                db: db, artifactID: current.artifactID)
            else {
                throw StorageError.corruptedRecord(
                    artifactID: try current.artifactID.storageScalar,
                    reason: "current head Artifact is missing")
            }
            let currentRecord = try verifiedRecord(
                row: currentRow,
                expectedArtifactID: current.artifactID)
            try Self.requireScope(
                currentRecord.identityCore.scopeBinding,
                matches: cas.key.scope)
        }
        let replacementRevision: UInt64
        if let expected = cas.expected {
            guard current == expected else {
                throw StorageError.headCASConflict
            }
            let addition = expected.revision.addingReportingOverflow(1)
            guard !addition.overflow else {
                throw StorageError.headRevisionOverflow
            }
            replacementRevision = addition.partialValue
        } else {
            guard current == nil else {
                throw StorageError.headCASConflict
            }
            replacementRevision = 0
        }

        let (scopeTag, scopeID) = try Self.headScopeColumns(
            cas.key.scope)
        let replacementScalar = try cas.replacementArtifactID.storageScalar
        if current == nil {
            let sql = """
                INSERT INTO artifact_mesh_heads (
                    scope_tag, scope_artifact_id, purpose,
                    artifact_id, revision
                ) VALUES (?, ?, ?, ?, ?);
                """
            let statement = try Self.prepare(db: db, sql: sql)
            defer { sqlite3_finalize(statement) }
            Self.bindText(statement, 1, scopeTag)
            Self.bindText(statement, 2, scopeID)
            Self.bindText(statement, 3, cas.key.purpose.rawValue)
            Self.bindText(statement, 4, replacementScalar)
            Self.bindText(statement, 5, String(replacementRevision))
            try Self.requireDone(statement, sql: sql, db: db)
        } else if let expected = cas.expected {
            let sql = """
                UPDATE artifact_mesh_heads
                SET artifact_id = ?, revision = ?
                WHERE scope_tag = ?
                  AND scope_artifact_id = ?
                  AND purpose = ?
                  AND artifact_id = ?
                  AND revision = ?;
                """
            let statement = try Self.prepare(db: db, sql: sql)
            defer { sqlite3_finalize(statement) }
            Self.bindText(statement, 1, replacementScalar)
            Self.bindText(statement, 2, String(replacementRevision))
            Self.bindText(statement, 3, scopeTag)
            Self.bindText(statement, 4, scopeID)
            Self.bindText(statement, 5, cas.key.purpose.rawValue)
            Self.bindText(
                statement, 6, try expected.artifactID.storageScalar)
            Self.bindText(statement, 7, String(expected.revision))
            try Self.requireDone(statement, sql: sql, db: db)
            guard sqlite3_changes(db) == 1 else {
                throw StorageError.headCASConflict
            }
        }
        return BASArtifactHead(
            key: cas.key,
            artifactID: cas.replacementArtifactID,
            revision: replacementRevision)
    }

    private struct RecordRow {
        let artifactScalar: String
        let recordBytes: Data
        let payloadRef: String
        let commitmentKeyEpoch: String
    }

    private static func fetchRecordRow(
        db: OpaquePointer,
        artifactID: BASArtifactID
    ) throws -> RecordRow? {
        let sql = """
            SELECT artifact_id, record_bytes, payload_ref,
                   commitment_key_epoch
            FROM artifact_mesh_records
            WHERE artifact_id = ?;
            """
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, try artifactID.storageScalar)
        let firstRC = sqlite3_step(statement)
        if firstRC == SQLITE_DONE { return nil }
        guard firstRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let row = RecordRow(
            artifactScalar: try columnText(
                statement,
                0,
                maximumBytes: TextColumnMaximum.artifactID,
                sql: sql,
                db: db),
            recordBytes: try columnBlob(
                statement, 1, sql: sql, db: db),
            payloadRef: try columnText(
                statement,
                2,
                maximumBytes: TextColumnMaximum.payloadReference,
                sql: sql,
                db: db),
            commitmentKeyEpoch: try columnText(
                statement,
                3,
                maximumBytes: TextColumnMaximum.uint64Decimal,
                sql: sql,
                db: db))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql, message: "duplicate primary-key rows")
        }
        return row
    }

    private static func insertRecord(
        db: OpaquePointer,
        artifactID: BASArtifactID,
        recordBytes: Data,
        payloadRef: String
    ) throws {
        let sql = """
            INSERT INTO artifact_mesh_records (
                artifact_id, record_bytes, payload_ref,
                commitment_key_epoch
            ) VALUES (?, ?, ?, ?);
            """
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, try artifactID.storageScalar)
        bindBlob(statement, 2, recordBytes)
        bindText(statement, 3, payloadRef)
        bindText(statement, 4, String(artifactID.commitmentKeyEpoch))
        try requireDone(statement, sql: sql, db: db)
    }

    private static func installAttestationIndex(
        db: OpaquePointer,
        attestationArtifactID: BASArtifactID,
        targetArtifactID: BASArtifactID
    ) throws {
        let attestationScalar = try attestationArtifactID.storageScalar
        let targetScalar = try targetArtifactID.storageScalar
        let selectSQL = """
            SELECT target_artifact_id
            FROM artifact_mesh_attestation_targets
            WHERE attestation_artifact_id = ?;
            """
        let select = try prepare(db: db, sql: selectSQL)
        defer { sqlite3_finalize(select) }
        bindText(select, 1, attestationScalar)
        let rc = sqlite3_step(select)
        if rc == SQLITE_ROW {
            let existingScalar = try columnText(
                select,
                0,
                maximumBytes: TextColumnMaximum.artifactID,
                sql: selectSQL,
                db: db)
            guard sqlite3_step(select) == SQLITE_DONE else {
                throw StorageError.stepFailed(
                    sql: selectSQL, message: "duplicate attestation index")
            }
            let existing: BASArtifactID
            do {
                existing = try BASArtifactID(
                    storageScalar: existingScalar)
            } catch {
                throw StorageError.corruptedRecord(
                    artifactID: attestationScalar,
                    reason: "attestation target ID is noncanonical")
            }
            guard existing == targetArtifactID else {
                throw StorageError.corruptedRecord(
                    artifactID: attestationScalar,
                    reason: "attestation target changed")
            }
            return
        }
        guard rc == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: selectSQL,
                message: String(cString: sqlite3_errmsg(db)))
        }

        let insertSQL = """
            INSERT INTO artifact_mesh_attestation_targets (
                attestation_artifact_id, target_artifact_id
            ) VALUES (?, ?);
            """
        let insert = try prepare(db: db, sql: insertSQL)
        defer { sqlite3_finalize(insert) }
        bindText(insert, 1, attestationScalar)
        bindText(insert, 2, targetScalar)
        try requireDone(insert, sql: insertSQL, db: db)
    }

    private static func fetchHead(
        db: OpaquePointer,
        key: BASArtifactHeadKey
    ) throws -> BASArtifactHead? {
        let (scopeTag, scopeID) = try headScopeColumns(key.scope)
        let sql = """
            SELECT artifact_id, revision
            FROM artifact_mesh_heads
            WHERE scope_tag = ?
              AND scope_artifact_id = ?
              AND purpose = ?;
            """
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, scopeTag)
        bindText(statement, 2, scopeID)
        bindText(statement, 3, key.purpose.rawValue)
        let rc = sqlite3_step(statement)
        if rc == SQLITE_DONE { return nil }
        guard rc == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let idScalar = try columnText(
            statement,
            0,
            maximumBytes: TextColumnMaximum.artifactID,
            sql: sql,
            db: db)
        let revisionScalar = try columnText(
            statement,
            1,
            maximumBytes: TextColumnMaximum.uint64Decimal,
            sql: sql,
            db: db)
        guard sqlite3_step(statement) == SQLITE_DONE,
              let revision = UInt64(revisionScalar),
              revisionScalar == String(revision)
        else {
            throw StorageError.stepFailed(
                sql: sql, message: "noncanonical or duplicate head row")
        }
        return BASArtifactHead(
            key: key,
            artifactID: try BASArtifactID(storageScalar: idScalar),
            revision: revision)
    }

    private static func headScopeColumns(
        _ scope: BASArtifactMutableHeadScope
    ) throws -> (String, String) {
        switch scope {
        case .workspaceAuthority(let id):
            return ("workspace-authority", try id.storageScalar)
        case .attempt(let id):
            return ("attempt", try id.storageScalar)
        }
    }

    private static func requireScope(
        _ identityScope: BASArtifactScopeBinding,
        matches headScope: BASArtifactMutableHeadScope
    ) throws {
        switch (identityScope, headScope) {
        case let (.workspaceAuthority(identityID),
                  .workspaceAuthority(headID))
            where identityID == headID:
            return
        case let (.attempt(identityID), .attempt(headID))
            where identityID == headID:
            return
        default:
            throw StorageError.headScopeMismatch
        }
    }

    private static func randomPayloadRef() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in
            UInt8.random(in: UInt8.min...UInt8.max, using: &generator)
        }
        return "bas-artifact-payload-v1-"
            + bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func isCanonicalPayloadRef(_ value: String) -> Bool {
        let prefix = "bas-artifact-payload-v1-"
        guard value.hasPrefix(prefix) else { return false }
        let suffix = value.dropFirst(prefix.count)
        return suffix.utf8.count == 64
            && suffix.utf8.allSatisfy { byte in
                (byte >= 48 && byte <= 57)
                    || (byte >= 97 && byte <= 102)
            }
    }

    private struct ColumnShape: Equatable {
        let name: String
        let type: String
        let notNull: Int32
        let primaryKeyPosition: Int32
    }

    private static func validateSchema(db: OpaquePointer) throws {
        try requireGeneratedSchemaDefinition(db: db)
        let requiredTables: Set<String> = [
            "artifact_mesh_records",
            "artifact_mesh_heads",
            "artifact_mesh_attestation_targets",
        ]
        let optionalPolicyTables: Set<String> = [
            "_bas_secure_delete_vacuumed",
        ]
        let tables = try applicationTableNames(db: db)
        guard requiredTables.isSubset(of: tables),
              tables.subtracting(requiredTables)
                .isSubset(of: optionalPolicyTables)
        else {
            throw StorageError.partialOrUnknownSchema(
                "unexpected table set \(tables.sorted())")
        }

        try requireColumns(
            db: db,
            table: "artifact_mesh_records",
            expected: [
                ColumnShape(name: "artifact_id", type: "TEXT",
                            notNull: 1, primaryKeyPosition: 1),
                ColumnShape(name: "record_bytes", type: "BLOB",
                            notNull: 1, primaryKeyPosition: 0),
                ColumnShape(name: "payload_ref", type: "TEXT",
                            notNull: 1, primaryKeyPosition: 0),
                ColumnShape(name: "commitment_key_epoch", type: "TEXT",
                            notNull: 1, primaryKeyPosition: 0),
            ])
        try requireColumns(
            db: db,
            table: "artifact_mesh_heads",
            expected: [
                ColumnShape(name: "scope_tag", type: "TEXT",
                            notNull: 1, primaryKeyPosition: 1),
                ColumnShape(name: "scope_artifact_id", type: "TEXT",
                            notNull: 1, primaryKeyPosition: 2),
                ColumnShape(name: "purpose", type: "TEXT",
                            notNull: 1, primaryKeyPosition: 3),
                ColumnShape(name: "artifact_id", type: "TEXT",
                            notNull: 1, primaryKeyPosition: 0),
                ColumnShape(name: "revision", type: "TEXT",
                            notNull: 1, primaryKeyPosition: 0),
            ])
        try requireColumns(
            db: db,
            table: "artifact_mesh_attestation_targets",
            expected: [
                ColumnShape(name: "attestation_artifact_id", type: "TEXT",
                            notNull: 1, primaryKeyPosition: 1),
                ColumnShape(name: "target_artifact_id", type: "TEXT",
                            notNull: 1, primaryKeyPosition: 0),
            ])

        let indexes = try namedIndexes(db: db)
        let expectedIndexes: Set<String> = [
            "artifact_mesh_attestation_target_idx",
            "artifact_mesh_head_artifact_idx",
        ]
        guard indexes == expectedIndexes else {
            throw StorageError.partialOrUnknownSchema(
                "unexpected index set \(indexes.sorted())")
        }
        let foreignKeySQL = "PRAGMA foreign_key_check;"
        let statement = try prepare(db: db, sql: foreignKeySQL)
        defer { sqlite3_finalize(statement) }
        let rc = sqlite3_step(statement)
        guard rc == SQLITE_DONE else {
            throw StorageError.partialOrUnknownSchema(
                "foreign-key validation failed")
        }
    }

    private static func requireGeneratedSchemaDefinition(
        db: OpaquePointer
    ) throws {
        guard ArtifactMeshV1Schema.statementCount == 5 else {
            throw StorageError.partialOrUnknownSchema(
                "generated schema statement count changed")
        }
        let expected = Set(
            ArtifactMeshV1Schema.allStatementsSQL
                .split(separator: ";")
                .compactMap(normalizedGeneratedStatement))
        guard expected.count == ArtifactMeshV1Schema.statementCount else {
            throw StorageError.partialOrUnknownSchema(
                "generated schema statements are ambiguous")
        }

        let sql = """
            SELECT name, sql
            FROM sqlite_master
            WHERE name NOT LIKE 'sqlite_%'
              AND type IN ('table', 'index', 'view', 'trigger')
            ORDER BY type ASC, name ASC;
            """
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        var actual: Set<String> = []
        var markerSeen = false
        var rc = sqlite3_step(statement)
        while rc == SQLITE_ROW {
            let name = try columnText(
                statement,
                0,
                maximumBytes: TextColumnMaximum.schemaObjectName,
                sql: sql,
                db: db)
            let definition = normalizedSchemaSQL(
                try columnText(
                    statement,
                    1,
                    maximumBytes: TextColumnMaximum.schemaDefinition,
                    sql: sql,
                    db: db))
            if name == "_bas_secure_delete_vacuumed" {
                guard !markerSeen,
                      definition == normalizedSchemaSQL(
                        "CREATE TABLE _bas_secure_delete_vacuumed "
                            + "(at_ms INTEGER NOT NULL)")
                else {
                    throw StorageError.partialOrUnknownSchema(
                        "secure-delete marker definition changed")
                }
                markerSeen = true
            } else {
                guard actual.insert(definition).inserted else {
                    throw StorageError.partialOrUnknownSchema(
                        "duplicate schema definition")
                }
            }
            rc = sqlite3_step(statement)
        }
        guard rc == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        guard actual == expected else {
            throw StorageError.partialOrUnknownSchema(
                "live schema differs from generated ArtifactMesh v1")
        }
    }

    private static func normalizedGeneratedStatement(
        _ raw: Substring
    ) -> String? {
        let uncommented = raw.split(
            separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                !line.trimmingCharacters(in: .whitespaces)
                    .hasPrefix("--")
            }
            .joined(separator: "\n")
        let normalized = normalizedSchemaSQL(uncommented)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedSchemaSQL(
        _ raw: String
    ) -> String {
        raw.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func applicationTableNames(
        db: OpaquePointer
    ) throws -> Set<String> {
        try schemaObjectNames(db: db, type: "table")
    }

    private static func namedIndexes(
        db: OpaquePointer
    ) throws -> Set<String> {
        try schemaObjectNames(db: db, type: "index")
    }

    private static func schemaObjectNames(
        db: OpaquePointer,
        type: String
    ) throws -> Set<String> {
        let sql = """
            SELECT name
            FROM sqlite_master
            WHERE type = ? AND name NOT LIKE 'sqlite_%'
            ORDER BY name ASC;
            """
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, type)
        var names: Set<String> = []
        var rc = sqlite3_step(statement)
        while rc == SQLITE_ROW {
            names.insert(try columnText(
                statement,
                0,
                maximumBytes: TextColumnMaximum.schemaObjectName,
                sql: sql,
                db: db))
            rc = sqlite3_step(statement)
        }
        guard rc == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return names
    }

    private static func requireColumns(
        db: OpaquePointer,
        table: String,
        expected: [ColumnShape]
    ) throws {
        let sql = "PRAGMA table_info(\"\(table)\");"
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        var columns: [ColumnShape] = []
        var rc = sqlite3_step(statement)
        while rc == SQLITE_ROW {
            columns.append(ColumnShape(
                name: try columnText(
                    statement,
                    1,
                    maximumBytes: TextColumnMaximum.columnName,
                    sql: sql,
                    db: db),
                type: try columnText(
                    statement,
                    2,
                    maximumBytes: TextColumnMaximum.declaredType,
                    sql: sql,
                    db: db),
                notNull: sqlite3_column_int(statement, 3),
                primaryKeyPosition: sqlite3_column_int(statement, 5)))
            rc = sqlite3_step(statement)
        }
        guard rc == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        guard columns == expected else {
            throw StorageError.partialOrUnknownSchema(
                "column mismatch for \(table)")
        }
    }

    private static func readUserVersion(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "PRAGMA user_version;"
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let version = Int(sqlite3_column_int64(statement, 0))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql, message: "user_version returned extra rows")
        }
        return version
    }

    private static func requirePragmaText(
        db: OpaquePointer,
        sql: String,
        expected: String
    ) throws {
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              try columnText(
                statement,
                0,
                maximumBytes: TextColumnMaximum.pragmaValue,
                sql: sql,
                db: db)
                .lowercased() == expected,
              sqlite3_step(statement) == SQLITE_DONE
        else {
            throw StorageError.stepFailed(
                sql: sql, message: "pragma policy was not effective")
        }
    }

    private static func requirePragmaInteger(
        db: OpaquePointer,
        sql: String,
        expected: Int64
    ) throws {
        let statement = try prepare(db: db, sql: sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              sqlite3_column_type(statement, 0) == SQLITE_INTEGER,
              sqlite3_column_int64(statement, 0) == expected,
              sqlite3_step(statement) == SQLITE_DONE
        else {
            throw StorageError.stepFailed(
                sql: sql, message: "pragma policy was not effective")
        }
    }

    private static func prepare(
        db: OpaquePointer,
        sql: String
    ) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil)
                == SQLITE_OK,
              let statement
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }

    private static func requireDone(
        _ statement: OpaquePointer,
        sql: String,
        db: OpaquePointer
    ) throws {
        let rc = sqlite3_step(statement)
        guard rc == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    private static func runExec(
        db: OpaquePointer,
        sql: String
    ) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        guard rc == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) }
                ?? String(cString: sqlite3_errmsg(db))
            if let errorMessage { sqlite3_free(errorMessage) }
            throw StorageError.stepFailed(sql: sql, message: message)
        }
    }

    private static func bindText(
        _ statement: OpaquePointer,
        _ index: Int32,
        _ value: String
    ) {
        sqlite3_bind_text(
            statement, index, value, -1,
            unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private static func bindBlob(
        _ statement: OpaquePointer,
        _ index: Int32,
        _ value: Data
    ) {
        _ = value.withUnsafeBytes { buffer in
            sqlite3_bind_blob(
                statement,
                index,
                buffer.baseAddress,
                Int32(buffer.count),
                unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
    }

    private static func columnText(
        _ statement: OpaquePointer,
        _ index: Int32,
        maximumBytes: Int,
        sql: String,
        db: OpaquePointer
    ) throws -> String {
        guard sqlite3_column_type(statement, index) == SQLITE_TEXT else {
            throw StorageError.stepFailed(
                sql: sql, message: "expected nonnull TEXT column")
        }
        let byteCount = sqlite3_column_bytes(statement, index)
        guard byteCount >= 0 else {
            throw StorageError.stepFailed(
                sql: sql, message: "TEXT column has a negative byte count")
        }
        let count = Int(byteCount)
        guard count <= maximumBytes else {
            throw StorageError.stepFailed(
                sql: sql,
                message: "TEXT column exceeds \(maximumBytes)-byte bound "
                    + "(actual: \(count))")
        }
        guard let pointer = sqlite3_column_text(statement, index) else {
            throw StorageError.stepFailed(
                sql: sql, message: "expected nonnull TEXT column")
        }
        let bytes = UnsafeBufferPointer(
            start: pointer, count: count)
        guard let value = String(bytes: bytes, encoding: .utf8) else {
            throw StorageError.stepFailed(
                sql: sql, message: "TEXT column is not valid UTF-8")
        }
        return value
    }

    private static func columnBlob(
        _ statement: OpaquePointer,
        _ index: Int32,
        sql: String,
        db: OpaquePointer
    ) throws -> Data {
        guard sqlite3_column_type(statement, index) == SQLITE_BLOB else {
            throw StorageError.stepFailed(
                sql: sql, message: "expected nonnull BLOB column")
        }
        let count = Int(sqlite3_column_bytes(statement, index))
        guard count > 0,
              count <= BASCanonicalPayloadValidator.maximumRecordBytes,
              let pointer = sqlite3_column_blob(statement, index)
        else {
            throw StorageError.stepFailed(
                sql: sql, message: "empty record BLOB")
        }
        return Data(bytes: pointer, count: count)
    }
}
