// MARK: - BASSemanticCommitIndex — the semantic citation ASSISTANT's embedding index (hint-only)
//
// Grounding increment 2. The 2026-07-11 calibration probe (BASGroundingSemanticCalibrationProbe,
// n=10 paraphrase pairs vs all 3,887 real commit subjects) showed SEALED semantic grounding is a
// NO-GO: the true-pair and best-distractor cosine distributions OVERLAP (minTrue 0.252 vs
// maxFalseTop 0.614, rank1 6/10, worst margin −0.143) — this corpus is self-similar (many commits
// per subsystem), and MiniLM measures TOPIC similarity while grounding needs REFERENTIAL identity.
// At the (0.45, 0.05) gate, 2 of 5 resolutions would have sealed the WRONG commit — false grounding
// in a tamper-evident ledger. Per the eval-rigor doctrine an n=10 calibration cannot justify a
// sealed field, so the semantic rung ships as a HINT: `hint(for:)` proposes a citation for the
// OPERATOR to verify and cite; the deterministic git path (BASGitFactBank) then does the sealing.
// Nothing in this file ever touches a seal.
//
// The index caches one embedding per (sha8, providerVersion) in a rebuildable SQLite side file —
// the full-corpus backfill (~4.8 ms/subject ⇒ ~19 s for 3,887) runs once; every later refresh
// embeds only NEW commits. Provider-generic (BASMemory.BASEmbeddingProvider) so the unit teeth run
// on a deterministic fake with no CoreML; the CLI hands it the bundled MiniLM (fp32 CPU — the
// deliberately-deterministic configuration).

import Foundation
import SQLite3
import BASMemory

/// The hint gate. Calibrated on the n=10 probe: at (0.60, 0.05) the probe showed 2/2 correct hints
/// and 0 false — but n=10 with an observed 0.614 false-top is exactly why this gates a PRINTED HINT
/// (a wrong hint costs one glance at the shown subject) and never a sealed field.
public struct BASSemanticHintGate: Sendable {
    public let threshold: Float
    public let margin: Float
    public init(threshold: Float, margin: Float) {
        self.threshold = threshold
        self.margin = margin
    }
    public static let calibrated = BASSemanticHintGate(threshold: 0.60, margin: 0.05)
}

public enum BASSemanticCommitIndexError: Error, CustomStringConvertible {
    case openFailed(String)
    case sqlFailed(String)
    public var description: String {
        switch self {
        case .openFailed(let m): return "semantic index open failed: \(m)"
        case .sqlFailed(let m): return "semantic index sql failed: \(m)"
        }
    }
}

/// A rebuildable cache: (sha8, providerVersion) → embedding. NOT sovereign data — deleting the
/// file just costs a re-backfill. Single-task use (the CLI runs one command per process).
public final class BASSemanticCommitIndex {
    private var db: OpaquePointer?
    private let provider: any BASMemory.BASEmbeddingProvider

    public init(dbPath: String, provider: any BASMemory.BASEmbeddingProvider) throws {
        self.provider = provider
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else {
            throw BASSemanticCommitIndexError.openFailed(dbPath)
        }
        let create = """
            CREATE TABLE IF NOT EXISTS commit_embeddings (
                sha8 TEXT NOT NULL,
                provider TEXT NOT NULL,
                dim INTEGER NOT NULL,
                vec BLOB NOT NULL,
                PRIMARY KEY (sha8, provider)
            )
            """
        guard sqlite3_exec(db, create, nil, nil, nil) == SQLITE_OK else {
            throw BASSemanticCommitIndexError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    public func close() {
        if let db { sqlite3_close(db) }
        db = nil
    }

    /// How many of `subjectsBySha8` are NOT yet cached for this provider version — the honest
    /// backfill-notice count (a warm cache returns 0, so no "backfill" notice can lie).
    public func missingCount(subjectsBySha8: [String: String]) throws -> Int {
        let cached = try cachedSha8s()
        return subjectsBySha8.keys.filter { !cached.contains($0) }.count
    }

    /// Embed every subject not yet cached for THIS provider version. Returns the newly-embedded
    /// count (0 on a warm cache — the incremental property the teeth pin).
    @discardableResult
    public func refresh(subjectsBySha8: [String: String]) async throws -> Int {
        let cached = try cachedSha8s()
        var added = 0
        // deterministic order so a partial backfill (ctrl-C) resumes stably
        for (sha8, subject) in subjectsBySha8.sorted(by: { $0.key < $1.key }) {
            guard !cached.contains(sha8) else { continue }
            let vec = await provider.embed(subject).normalized.vector
            try insert(sha8: sha8, vector: vec)
            added += 1
        }
        return added
    }

    /// Top-1 cosine + CRAG-margin gate over the cached corpus. nil = no hint (abstain bias:
    /// below-threshold, ambiguous margin, or an empty cache all abstain).
    public func hint(
        for claim: String,
        gate: BASSemanticHintGate = .calibrated
    ) async -> (sha8: String, cosine: Float)? {
        guard let rows = try? allVectors(), !rows.isEmpty else { return nil }
        let q = await provider.embed(claim).normalized.vector
        var bestSha = "", best: Float = -.greatestFiniteMagnitude
        var second: Float = -.greatestFiniteMagnitude
        for (sha8, v) in rows {
            var c: Float = 0
            for i in 0..<min(q.count, v.count) { c += q[i] * v[i] }
            if c > best { second = best; best = c; bestSha = sha8 }
            else if c > second { second = c }
        }
        guard best >= gate.threshold, (best - second) >= gate.margin else { return nil }
        return (bestSha, best)
    }

    // MARK: - SQLite plumbing

    private func cachedSha8s() throws -> Set<String> {
        var stmt: OpaquePointer?
        let sql = "SELECT sha8 FROM commit_embeddings WHERE provider = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw BASSemanticCommitIndexError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, provider.providerVersion)
        var out: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.insert(String(cString: sqlite3_column_text(stmt, 0)))
        }
        return out
    }

    private func insert(sha8: String, vector: [Float]) throws {
        var stmt: OpaquePointer?
        let sql = "INSERT OR REPLACE INTO commit_embeddings (sha8, provider, dim, vec) VALUES (?,?,?,?)"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw BASSemanticCommitIndexError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, sha8)
        bindText(stmt, 2, provider.providerVersion)
        sqlite3_bind_int(stmt, 3, Int32(vector.count))
        vector.withUnsafeBufferPointer { buf in
            _ = sqlite3_bind_blob(stmt, 4, buf.baseAddress, Int32(buf.count * 4),
                                  unsafeBitCast(-1, to: sqlite3_destructor_type.self))   // SQLITE_TRANSIENT
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw BASSemanticCommitIndexError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func allVectors() throws -> [(String, [Float])] {
        var stmt: OpaquePointer?
        let sql = "SELECT sha8, dim, vec FROM commit_embeddings WHERE provider = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw BASSemanticCommitIndexError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, provider.providerVersion)
        var out: [(String, [Float])] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let sha8 = String(cString: sqlite3_column_text(stmt, 0))
            let dim = Int(sqlite3_column_int(stmt, 1))
            let bytes = Int(sqlite3_column_bytes(stmt, 2))
            guard dim > 0, bytes == dim * 4, let blob = sqlite3_column_blob(stmt, 2) else { continue }
            let vec = blob.withMemoryRebound(to: Float.self, capacity: dim) {
                Array(UnsafeBufferPointer(start: $0, count: dim))
            }
            out.append((sha8, vec))
        }
        return out
    }

    private func bindText(_ stmt: OpaquePointer, _ idx: Int32, _ s: String) {
        _ = s.utf8.withContiguousStorageIfAvailable { buf in
            sqlite3_bind_text(stmt, idx, buf.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) },
                              Int32(buf.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } ?? sqlite3_bind_text(stmt, idx, s, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
}
