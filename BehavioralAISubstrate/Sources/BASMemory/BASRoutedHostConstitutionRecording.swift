// MARK: - BASRoutedHostConstitutionRecording
// chapter 八百一 / M2656-M2660 — L5 host-constitution recording activation
//
// Opt-in recorders that wire L5 mutations into the storage
// adapters shipped at chapter 七百九十六:
//
//   - BASHostConstitutionVersionTreeStore       (schema 014)
//   - BASHostConstitutionDeletionManifestStore  (schema 015)
//
// ## Why
//
// `BASHostConstitutionSQLiteStorage` (chapter 二百四十九) already
// persists the constitution itself。 The version tree + deletion
// manifest schemas (chapters 七百九十六) carry the AUDIT lineage:
// who descended from whom,what got rolled back,which deletions
// cascaded vs were selective。 This file vends the host-facing
// API that turns a raw mutation event into a typed audit row。
//
// ## Doctrine
//
// 「依旧 不删除 只 comment」 — `BASHostConstitutionSQLiteStorage`
// stays the source of truth for the constitution。 These
// recorders are PURELY ADDITIVE — hosts opt in。 Default
// substrate behavior unchanged。
//
// ADR-014 OPT-IN — both stores are addressable seams supplied
// by the host (InMemory reference or SQLite-backed)。
//
// ## SHA-256 path
//
// Uses CryptoKit's SHA-256 (hardware-accelerated on Apple
// Silicon AMX engine,~34× faster than pure-Rust software
// SHA-256 per chapter 七百四 measurement)。 The
// `bas_substrate_sha256` Rust ABI remains available for cross-
// platform-stable replay verification — see
// `BASMemoryAtomEventPayload.sha256HexRust` doctrine notes。
// Default path is CryptoKit per 「整体 性能 效果 一定要 更好」。

import Foundation
import CryptoKit

public enum BASRoutedHostConstitutionRecording {

    // MARK: - Deletion type literal (schema 015 CHECK)

    /// Schema 015 deletion_type CHECK literals。 Pinned as a Swift
    /// enum so hosts can't accidentally write a string the schema
    /// would reject downstream。
    public enum DeletionType: String, Sendable, CaseIterable {
        case cascade
        case selective
        case rollback
    }

    // MARK: - Version tree recorder

    /// Build a `BASHostConstitutionVersionRecord` from the
    /// canonical bytes of one constitution version + lineage
    /// fields。 Computes SHA-256 of the canonical bytes for the
    /// `signature_hash` column。 Persists via host-supplied
    /// `BASHostConstitutionVersionTreeStore`。
    ///
    /// - Parameters:
    ///   - versionID: unique handle for this version (caller
    ///     supplied — typically UUID or content-addressed hash hex)
    ///   - vaultID: foreign-key to the constitution vault
    ///   - parentVersionID: nil for genesis,otherwise the
    ///     immediate ancestor in the lineage tree
    ///   - canonicalBytes: stable byte serialization the
    ///     signature_hash will commit to。 Caller's responsibility
    ///     to compute canonical form (sort keys / pin float repr
    ///     / pin newlines etc。)
    ///   - createdAtMs: epoch ms timestamp
    ///   - isRollbackPoint: true if this version is a designated
    ///     restore target
    ///   - mergedFromVersionIDs: when non-nil,encoded as JSON
    ///     array for the `merged_from_json` column。 Pass nil for
    ///     ordinary single-parent edits。
    ///   - store: any conformer of `BASHostConstitutionVersionTreeStore`
    ///
    /// - Returns: the persisted record
    /// - Throws: store-side errors (e.g。 duplicate versionID)
    @discardableResult
    public static func recordVersion(
        versionID: String,
        vaultID: String,
        parentVersionID: String? = nil,
        canonicalBytes: Data,
        createdAtMs: Int64,
        isRollbackPoint: Bool = false,
        mergedFromVersionIDs: [String]? = nil,
        store: BASHostConstitutionVersionTreeStore
    ) async throws -> BASHostConstitutionVersionRecord {
        let signatureHash = sha256Data(canonicalBytes)
        let mergedFromJson = try encodeMergedFrom(mergedFromVersionIDs)
        let record = BASHostConstitutionVersionRecord(
            versionID: versionID,
            vaultID: vaultID,
            parentVersionID: parentVersionID,
            createdAtMs: createdAtMs,
            signatureHash: signatureHash,
            isRollbackPoint: isRollbackPoint,
            mergedFromJson: mergedFromJson)
        return try await store.appendVersion(record)
    }

    // MARK: - Deletion manifest recorder

    /// Build a `BASHostConstitutionDeletionRecord` from the
    /// target refs + deletion type + optional cascade + optional
    /// versionRef。 Persists via host-supplied
    /// `BASHostConstitutionDeletionManifestStore`。
    ///
    /// - Parameters:
    ///   - manifestID: unique handle for this deletion event
    ///   - vaultID: foreign-key to the constitution vault
    ///   - targetRefs: domain references being deleted (encoded
    ///     as JSON array for schema 015's target_refs_json column)
    ///   - deletionType: cascade / selective / rollback — enum
    ///     pinned to schema 015 CHECK
    ///   - appliedAtMs: epoch ms timestamp
    ///   - cascadedRefs: optional list of follow-on refs the
    ///     cascade reached (nil for selective / rollback typically)
    ///   - versionRef: optional version_id when this deletion
    ///     ties to a specific lineage row (used for rollback)
    ///   - store: any conformer of `BASHostConstitutionDeletionManifestStore`
    ///
    /// - Returns: the persisted record
    /// - Throws: store-side errors + JSON encoding failures
    @discardableResult
    public static func recordDeletion(
        manifestID: String,
        vaultID: String,
        targetRefs: [String],
        deletionType: DeletionType,
        appliedAtMs: Int64,
        cascadedRefs: [String]? = nil,
        versionRef: String? = nil,
        store: BASHostConstitutionDeletionManifestStore
    ) async throws -> BASHostConstitutionDeletionRecord {
        let targetRefsJson = try encodeRefList(targetRefs)
        let cascadedRefsJson = try encodeOptionalRefList(cascadedRefs)
        let record = BASHostConstitutionDeletionRecord(
            manifestID: manifestID,
            vaultID: vaultID,
            targetRefsJson: targetRefsJson,
            deletionType: deletionType.rawValue,
            appliedAtMs: appliedAtMs,
            cascadedRefsJson: cascadedRefsJson,
            versionRef: versionRef)
        return try await store.appendManifest(record)
    }

    // MARK: - Helpers

    /// SHA-256 of arbitrary bytes,returned as 32-byte Data。
    /// Uses CryptoKit (hardware-accelerated on Apple Silicon)。
    public static func sha256Data(_ bytes: Data) -> Data {
        let digest = SHA256.hash(data: bytes)
        return Data(digest)
    }

    /// JSON-encode a list of refs as a stable array literal。
    /// Empty list → "[]" (still a valid JSON array)。
    public static func encodeRefList(
        _ refs: [String]
    ) throws -> String {
        let data = try JSONEncoder().encode(refs)
        return String(decoding: data, as: UTF8.self)
    }

    /// JSON-encode an optional ref list。 Returns nil for nil
    /// input (schema column stays NULL),"[]" for empty input
    /// (explicit empty-list distinguished from absence)。
    public static func encodeOptionalRefList(
        _ refs: [String]?
    ) throws -> String? {
        guard let refs else { return nil }
        return try encodeRefList(refs)
    }

    /// JSON-encode a merged-from list。 Returns nil for nil or
    /// empty input — schema 014 stores nil to indicate「not a
    /// merge」 (single-parent edit) regardless of whether the
    /// caller passed nil or []。
    public static func encodeMergedFrom(
        _ refs: [String]?
    ) throws -> String? {
        guard let refs, !refs.isEmpty else { return nil }
        return try encodeRefList(refs)
    }
}
