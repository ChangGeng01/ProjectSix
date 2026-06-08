// MARK: - BASRoutedVectorIndexStorage
// chapter 九百 / M3190 — L8 unification MED-risk migration #5
//
// Swift bridge for BASSQLiteVectorIndexStorage per RFC。 Per-turn
// retrieval hot path。 Embedding stored as variable-size BLOB
// (dim × 4 bytes per f32 little-endian)。

import Foundation
import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
public actor BASRoutedVectorIndexStorage {
    public enum StoreError: Error, Equatable, Sendable {
        case engineInitFailed
        case schemaInitFailed(code: Int32)
        case upsertFailed(code: Int32)
        case removeFailed(code: Int32)
        case metadataEncodingFailed
        /// chapter 九百十八 / M3295 fix:reject invalid
        /// limit values (k ≤ 0 or k > LIMIT_CAP) via throw
        /// instead of `precondition` (which aborts the
        /// process in release builds)。
        case invalidArgument(reason: String)
        /// chapter 九百十九 / M3300 CRITICAL fix C1:read
        /// operations (cosineTopK,readEmbeddingBytes) now
        /// throw `.readFailed` instead of misleading
        /// `.upsertFailed`,which previously triggered
        /// rollback logic in consumer catch-by-case handlers
        /// for a read that had no transaction to roll back。
        case readFailed(code: Int32)
    }

    /// chapter 九百十八 / M3295 fix:upper bound on k/limit
    /// to prevent OOM via `[Int64](repeating: 0, count: k)`
    /// when caller passes `k = Int.max`。 100k entries × 16
    /// bytes (i64+f32+pad) = ~2MB allocation,well within
    /// safe production bounds for top-k queries。
    public static let limitCap: Int = 100_000

    /// chapter 九百二十六 / M3335 fix HIGH-2 — Swift-side
    /// dim cap (matches Rust MAX_EMBEDDING_BYTES = 65_536
    /// = 16384 × 4 bytes per f32)。 Surfaces the bound at
    /// the Swift API boundary instead of relying on the
    /// FFI to return -3 with no diagnostic。
    public static let queryDimCap: Int = 16_384

    /// chapter 九百三十九 / M3400 fix MED-6 — companion to
    /// `validateQueryBytes` for the [Float] cosineTopK overload。
    /// Both validators apply the SAME logical checks (dim cap +
    /// finiteness)。 Discipline:any change to one MUST be
    /// mirrored in the other (drift surface concentrated to
    /// this pair)。 Tests should exercise both paths with
    /// equivalent inputs (10P-LOW-3 carryover fix)。
    fileprivate static func validateQueryFloats(
        _ query: [Float]
    ) throws {
        guard !query.isEmpty else {
            throw StoreError.invalidArgument(
                reason: "query is empty")
        }
        guard query.count <= queryDimCap else {
            throw StoreError.invalidArgument(
                reason: "query dimension \(query.count) " +
                "exceeds cap \(queryDimCap) " +
                "(matches Rust MAX_EMBEDDING_BYTES = " +
                "\(queryDimCap * 4))")
        }
        guard query.allSatisfy({ $0.isFinite }) else {
            throw StoreError.invalidArgument(
                reason: "query contains non-finite values " +
                "(NaN or Inf) — would corrupt cosine scores")
        }
    }

    /// chapter 九百二十六 / M3335 fix HIGH-2 — shared
    /// validator for [UInt8] query bytes,used by both
    /// `cosineTopK` and `cosineTopKWithSkipped` [UInt8]
    /// overloads。 Decodes bytes as f32 LE,verifies dim
    /// cap and NaN/Inf-freeness。 Without this both [UInt8]
    /// overloads bypassed the ch 924 NH4 guard which only
    /// covered the [Float] overload。
    ///
    /// chapter 九百三十九 / M3400 fix MED-6:companion
    /// `validateQueryFloats` added above — both validators
    /// MUST apply same logical checks (drift surface
    /// concentrated to this pair)。
    fileprivate static func validateQueryBytes(
        _ bytes: [UInt8]
    ) throws {
        guard !bytes.isEmpty else {
            throw StoreError.invalidArgument(
                reason: "query bytes empty")
        }
        guard bytes.count % 4 == 0 else {
            throw StoreError.invalidArgument(
                reason: "query bytes length " +
                "\(bytes.count) not divisible by 4")
        }
        let dim = bytes.count / 4
        guard dim <= queryDimCap else {
            throw StoreError.invalidArgument(
                reason: "query dimension \(dim) exceeds " +
                "cap \(queryDimCap) (matches Rust " +
                "MAX_EMBEDDING_BYTES = \(queryDimCap * 4))")
        }
        // Decode + check NaN/Inf。 Per-element decode rather
        // than withMemoryRebound to avoid alignment assumption
        // on caller's [UInt8] storage。
        for i in 0..<dim {
            let start = i * 4
            let f = Float(bitPattern: UInt32(bytes[start])
                | (UInt32(bytes[start + 1]) << 8)
                | (UInt32(bytes[start + 2]) << 16)
                | (UInt32(bytes[start + 3]) << 24))
            guard f.isFinite else {
                throw StoreError.invalidArgument(
                    reason: "query bytes contain non-finite " +
                    "value at index \(i) (NaN or Inf — would " +
                    "corrupt cosine scores)")
            }
        }
    }

    public let databaseURL: URL
    private nonisolated(unsafe) let enginePtr: OpaquePointer

    #if DEBUG
    // 先稳 P0 — DEBUG-only concurrency tripwire for `cosineTopKAtomIDsSync`'s contract ("no concurrent
    // upsert/remove during the nonisolated sync read"). The actor-isolated mutators raise a flag across
    // their FFI; the nonisolated reader checks it. NSLock-guarded (no new dep); compiles out ENTIRELY in
    // release (the hot path stays byte-identical). The violation handler is swappable so a test can RECORD
    // instead of abort. ADR-037 acknowledged this footgun in prose; this makes it catchable.
    private nonisolated(unsafe) let _writeLock = NSLock()
    private nonisolated(unsafe) var _writeInFlightCount = 0
    public nonisolated(unsafe) static var _concurrencyViolationHandler: @Sendable (String) -> Void = {
        assertionFailure($0)
    }
    private nonisolated func _enterWrite() {
        _writeLock.lock(); _writeInFlightCount += 1; _writeLock.unlock()
    }
    private nonisolated func _exitWrite() {
        _writeLock.lock(); _writeInFlightCount -= 1; _writeLock.unlock()
    }
    private nonisolated func _assertNoConcurrentWrite() {
        _writeLock.lock(); let n = _writeInFlightCount; _writeLock.unlock()
        if n != 0 {
            Self._concurrencyViolationHandler(
                "BASRoutedVectorIndexStorage.cosineTopKAtomIDsSync raced \(n) concurrent upsert/remove " +
                "— turn-phase separation violated (the nonisolated sync read is unsafe during a mutation)")
        }
    }
    #endif

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        let pathStr = databaseURL.path
        let pathBytes = Array(pathStr.utf8)
        let engine = pathBytes.withUnsafeBufferPointer { buf in
            bas_l8_engine_init(
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        guard let engine else {
            throw StoreError.engineInitFailed
        }
        self.enginePtr = engine
        let rc = bas_l8_vector_index_init_schema(engine)
        guard rc == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(code: rc)
        }
    }

    /// ADR-037 — IN-MEMORY engine (`:memory:`), NOT file-backed. Backs the OPT-IN global-recall
    /// corpus: a SEPARATE Rust L8 engine that must NOT share the durable WAL file with the
    /// system-SQLite `BASSQLiteVectorIndexStorage` (rusqlite-bundled SQLite vs system SQLite3 on one
    /// `-shm` = corruption). Passes `(nil, 0)` to `bas_l8_engine_init` ⇒ `open_in_memory()`
    /// (Cargo/bas-l8-engine/src/lib.rs:366). The host rebuilds it from the durable store at startup
    /// (no re-embed), so the durable index stays the untouched source of truth and this is a derived,
    /// rebuildable replica. Mirrors `init(databaseURL:)`'s two-step init + schema, sans the file path.
    public init(inMemory: Void) throws {
        self.databaseURL = URL(fileURLWithPath: ":memory:")  // sentinel — introspection only
        guard let engine = bas_l8_engine_init(nil, 0) else {
            throw StoreError.engineInitFailed
        }
        self.enginePtr = engine
        let rc = bas_l8_vector_index_init_schema(engine)
        guard rc == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(code: rc)
        }
    }

    deinit { _ = bas_l8_engine_close(enginePtr) }

    /// UPSERT。 Returns true on insert,false on replace
    /// (matches BASSQLiteVectorIndexStorage.upsert semantics)。
    @discardableResult
    /// chapter 九百二十七 / M3340 fix HIGH-2 — extracted from
    /// `upsert(_:)` body so tests can assert determinism on
    /// the production encoder directly (the ch 926 test
    /// asserted UPSERT-REPLACE semantics which hold whether
    /// sortedKeys is active or not — fake coverage)。
    ///
    /// If `.sortedKeys` were removed,JSONEncoder emits keys
    /// in hash-table-iteration order which is process-
    /// random — the sibling test `testMetadataKeysAreSorted
    /// Lexicographically` constructs a multi-key dict and
    /// asserts exact JSON byte order,catching this。
    internal static func encodeMetadata(
        _ metadata: [String: String]
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(metadata)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    public func upsert(
        _ entry: BASVectorIndexEntry
    ) async throws -> Bool {
        #if DEBUG
        _enterWrite(); defer { _exitWrite() }
        #endif
        // Encode metadata as JSON via Apple boundary
        // chapter 九百二十二 / M3315 CRITICAL fix NC3:
        // .sortedKeys for deterministic encoding (was the
        // ONE L8 routed bridge the chapter 919 C2 fix missed
        // — every other routed bridge already uses sorted)。
        //
        // chapter 九百二十七 / M3340 fix HIGH-2:extracted
        // encoding to `encodeMetadata(_:)` static helper so
        // tests can directly assert byte-order without going
        // through round-trip storage layer。
        let metadataJson: String
        do {
            metadataJson = try Self.encodeMetadata(
                entry.metadata)
        } catch {
            throw StoreError.metadataEncodingFailed
        }
        let aid = Array(entry.atomID.utf8)
        let pv = Array(
            entry.normalizedEmbedding.providerVersion.utf8)
        let domain = Array(entry.domain.utf8)
        let mj = Array(metadataJson.utf8)
        let dimension = Int64(
            entry.normalizedEmbedding.dimension)

        // [Float] → BLOB bytes via direct memory layout
        // (little-endian f32 matches Swift actor's encodeFloatArray)
        let rc = entry.normalizedEmbedding.vector
            .withUnsafeBufferPointer { vecBuf -> Int32 in
            let embPtr = vecBuf.baseAddress.map {
                UnsafeRawPointer($0)
                    .assumingMemoryBound(to: UInt8.self)
            }
            let embLen = vecBuf.count
                * MemoryLayout<Float>.size
            return aid.withUnsafeBufferPointer { aidBuf in
                pv.withUnsafeBufferPointer { pvBuf in
                    domain.withUnsafeBufferPointer { domBuf in
                        mj.withUnsafeBufferPointer { mjBuf in
                            bas_l8_vector_index_upsert(
                                enginePtr,
                                aidBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                aidBuf.count,
                                dimension,
                                pvBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                pvBuf.count,
                                embPtr,
                                embLen,
                                domBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                domBuf.count,
                                mjBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                mjBuf.count)
                        }
                    }
                }
            }
        }
        switch rc {
        case 1: return true
        case 0: return false
        default:
            throw StoreError.upsertFailed(code: rc)
        }
    }

    @discardableResult
    public func remove(atomID: String) async throws -> Bool {
        #if DEBUG
        _enterWrite(); defer { _exitWrite() }
        #endif
        let bytes = Array(atomID.utf8)
        let rc = bytes.withUnsafeBufferPointer { buf in
            bas_l8_vector_index_remove(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        switch rc {
        case 1: return true
        case 0: return false
        default:
            throw StoreError.removeFailed(code: rc)
        }
    }

    public var totalCount: Int {
        get async {
            let c = bas_l8_vector_index_count(enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    public func countForDomain(_ domain: String) async -> Int {
        let bytes = Array(domain.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_vector_index_count_for_domain(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return c < 0 ? 0 : Int(c)
    }

    public func countForProvider(
        _ providerVersion: String
    ) async -> Int {
        let bytes = Array(providerVersion.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_vector_index_count_for_provider(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return c < 0 ? 0 : Int(c)
    }

    // MARK: - chapter 九百六 hot-path consolidation primitives

    /// Read one embedding_blob for an atom_id。 Returns nil
    /// if absent。 Used as the orchestrated baseline in
    /// chapter 906 perf bench (N round-trip FFI reads vs the
    /// integrated cosine-topk single-hop path)。
    public func readEmbeddingBytes(
        forAtomID atomID: String
    ) async throws -> [UInt8]? {
        let bytes = Array(atomID.utf8)
        let needed = bytes.withUnsafeBufferPointer { buf in
            bas_l8_vector_index_read_embedding_for_atom(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count,
                nil, 0)
        }
        if needed == -2 { return nil }
        if needed < 0 {
            throw StoreError.readFailed(code: needed)
        }
        if needed == 0 { return [] }
        var outBuf = [UInt8](repeating: 0, count: Int(needed))
        let written = bytes.withUnsafeBufferPointer { buf in
            outBuf.withUnsafeMutableBufferPointer { ob in
                bas_l8_vector_index_read_embedding_for_atom(
                    enginePtr,
                    buf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(
                                to: CChar.self)
                    },
                    buf.count,
                    ob.baseAddress, ob.count)
            }
        }
        guard written == needed else {
            throw StoreError.readFailed(code: written)
        }
        return outBuf
    }

    /// chapter 九百十二 / M3265 — Swift wrapper for the chapter
    /// 九百十 `with_skipped` FFI variant。 Same as cosineTopK
    /// but also returns the count of dim-mismatched rows
    /// silently skipped during the scan。 Production consumers
    /// can detect provider upgrades that left mixed-dim
    /// corpora behind。
    public func cosineTopKWithSkipped(
        forDomain domain: String,
        queryBytes: [UInt8],
        k: Int
    ) async throws -> (
        results: [(rowid: Int64, score: Float)],
        skipped: Int
    ) {
        guard k > 0 && k <= Self.limitCap else {
            throw StoreError.invalidArgument(
                reason: "k must be in 1...\(Self.limitCap), got \(k)")
        }
        // chapter 九百二十六 / M3335 fix HIGH-2:Swift-side
        // dim cap + NaN/Inf guard for the [UInt8] overload
        // — ch 924 NH4 added these only to the [Float]
        // overload,leaving direct-bytes callers unprotected。
        try Self.validateQueryBytes(queryBytes)
        let dom = Array(domain.utf8)
        var rowids = [Int64](repeating: 0, count: k)
        var scores = [Float](repeating: 0, count: k)
        var skipped: Int64 = 0
        let n = dom.withUnsafeBufferPointer { domBuf in
            queryBytes.withUnsafeBufferPointer { qBuf in
                rowids.withUnsafeMutableBufferPointer { rBuf in
                    scores.withUnsafeMutableBufferPointer { sBuf in
                        bas_l8_vector_index_cosine_topk_for_domain_with_skipped(
                            enginePtr,
                            domBuf.baseAddress.map {
                                UnsafeRawPointer($0)
                                    .assumingMemoryBound(
                                        to: CChar.self)
                            },
                            domBuf.count,
                            qBuf.baseAddress,
                            qBuf.count,
                            k,
                            rBuf.baseAddress,
                            sBuf.baseAddress,
                            &skipped)
                    }
                }
            }
        }
        guard n >= 0 else {
            throw StoreError.readFailed(code: n)
        }
        var out: [(rowid: Int64, score: Float)] = []
        out.reserveCapacity(Int(n))
        for i in 0..<Int(n) {
            out.append((rowid: rowids[i], score: scores[i]))
        }
        return (results: out, skipped: Int(skipped))
    }

    /// INTEGRATED cosine top-k:fetches all embeddings for a
    /// domain + dot-product scores them against the query in
    /// ONE FFI call (vs N round-trip reads + Swift compute)。
    /// chapter 九百二十一 / M3310 MED fix:ergonomic [Float]
    /// overload that does the f32 → byte packing internally。
    /// Most consumers have a `[Float]` query vector — making
    /// them pack to `[UInt8]` themselves invites endian /
    /// width-mismatch bugs。
    ///
    /// chapter 九百二十四 / M3325 fix NH4:reject queries
    /// containing NaN/Inf — they cause every score to be
    /// non-finite,which the chapter 918 NaN filter rejects,
    /// returning an empty result with no diagnostic。 Surface
    /// the bad query as an error instead of silent empty。
    public func cosineTopK(
        forDomain domain: String,
        query: [Float],
        k: Int
    ) async throws -> [(rowid: Int64, score: Float)] {
        // chapter 九百三十九 / M3400 fix MED-6 (10P-LOW-3
        // carryover):use shared `validateQueryFloats` helper
        // — companion to `validateQueryBytes`,both apply the
        // SAME logical checks (dim cap + finiteness)。 Reduces
        // drift surface to ONE pair of validators in ONE file
        // (previously [Float] inline,[UInt8] via helper —
        // changes to one didn't propagate to the other)。
        try Self.validateQueryFloats(query)
        // Pack [Float] → [UInt8] little-endian
        var bytes: [UInt8] = []
        bytes.reserveCapacity(query.count * 4)
        for v in query {
            var x = v
            withUnsafeBytes(of: &x) { raw in
                bytes.append(contentsOf: raw)
            }
        }
        // chapter 九百二十七 / M3340 fix MED-1:skip
        // re-validation in the bytes path — the [Float]
        // overload above already validated dim cap +
        // NaN/Inf,re-decoding 16K floats from bytes for a
        // second check inverts the hot-path win the ch 923
        // arc fought for。 Internal entry trusts caller。
        return try await _cosineTopKBytesAfterValidation(
            domain: domain,
            queryBytes: bytes,
            k: k)
    }

    /// Returns top-k (rowid, score) pairs sorted descending
    /// by score。
    public func cosineTopK(
        forDomain domain: String,
        queryBytes: [UInt8],
        k: Int
    ) async throws -> [(rowid: Int64, score: Float)] {
        // chapter 九百二十六 / M3335 fix HIGH-2:see overload
        // above — same dim-cap + NaN guard,extracted into
        // a shared helper to avoid drift between siblings。
        try Self.validateQueryBytes(queryBytes)
        return try await _cosineTopKBytesAfterValidation(
            domain: domain,
            queryBytes: queryBytes,
            k: k)
    }

    /// chapter 九百二十七 / M3340 fix MED-1 — internal-entry
    /// bytes path that skips Swift-side dim+NaN re-validation。
    /// Used by:
    ///   - public [Float] overload (already validated upstream)
    ///   - public [UInt8] overload (validated via
    ///     validateQueryBytes(_:) immediately above the call)
    /// Both PUBLIC entrypoints validate; this private trampoline
    /// is the only call site that skips the per-element scan,
    /// preserving the chapter 923 hot-path perf win。
    ///
    /// chapter 九百二十八 / M3345 fix MED-1:renamed from
    /// `_cosineTopKBytesUnchecked` → `_cosineTopKBytesAfter
    /// Validation` to make the contract explicit at the call
    /// site。「Unchecked」 invited「seems safe,let me skip
    /// validation」 misreadings;「AfterValidation」 documents
    /// that the caller MUST have already validated。 If a new
    /// caller adds itself,the name forces them to think about
    /// the validation contract。
    private func _cosineTopKBytesAfterValidation(
        domain: String,
        queryBytes: [UInt8],
        k: Int
    ) async throws -> [(rowid: Int64, score: Float)] {
        guard k > 0 && k <= Self.limitCap else {
            throw StoreError.invalidArgument(
                reason: "k must be in 1...\(Self.limitCap), got \(k)")
        }
        let dom = Array(domain.utf8)
        var rowids = [Int64](repeating: 0, count: k)
        var scores = [Float](repeating: 0, count: k)
        let n = dom.withUnsafeBufferPointer { domBuf in
            queryBytes.withUnsafeBufferPointer { qBuf in
                rowids.withUnsafeMutableBufferPointer { rBuf in
                    scores.withUnsafeMutableBufferPointer { sBuf in
                        bas_l8_vector_index_cosine_topk_for_domain(
                            enginePtr,
                            domBuf.baseAddress.map {
                                UnsafeRawPointer($0)
                                    .assumingMemoryBound(
                                        to: CChar.self)
                            },
                            domBuf.count,
                            qBuf.baseAddress,
                            qBuf.count,
                            k,
                            rBuf.baseAddress,
                            sBuf.baseAddress)
                    }
                }
            }
        }
        guard n >= 0 else {
            throw StoreError.readFailed(code: n)
        }
        var out: [(rowid: Int64, score: Float)] = []
        out.reserveCapacity(Int(n))
        for i in 0..<Int(n) {
            out.append((rowid: rowids[i], score: scores[i]))
        }
        return out
    }

    // MARK: - chapter 一千〇六十二 / WS3 — SYNC cosine top-K → atom_ids

    /// SYNCHRONOUS cosine top-K that resolves each result's rowid back to its atom_id (via the
    /// new `bas_l8_vector_index_atom_id_for_rowid` FFI), returning `(atomID, score)` descending
    /// by score. `nonisolated` so the ch883 SYNC L8 retrieve hot path can call it WITHOUT an actor
    /// hop (the underlying FFIs are synchronous — the actor only wrapped them for isolation). One
    /// topK FFI call + K cheap rowid→atom_id lookups (K≪N corpus). This is the host-injected
    /// perf-fast retrieve path (audit ch1040 WS3); it is NOT byte-equal to the orchestrated
    /// score-all path (the index ties by rowid, not atomID, and truncates before the Swift-side
    /// floor/constitution filter).
    ///
    /// CONCURRENCY CONTRACT: bypasses the actor's serialization — reads `enginePtr` directly (as
    /// `deinit` already does). The caller MUST guarantee no concurrent `upsert`/`remove` during the
    /// call. The L8 retrieve hot path satisfies this by turn-phase separation: retrieve runs
    /// synchronously WITHIN a turn; the durable upsert/drain runs asynchronously BETWEEN turns.
    public nonisolated func cosineTopKAtomIDsSync(
        forDomain domain: String,
        query: [Float],
        k: Int
    ) throws -> [(atomID: String, score: Float)] {
        #if DEBUG
        _assertNoConcurrentWrite()
        #endif
        try Self.validateQueryFloats(query)
        guard k > 0 && k <= Self.limitCap else {
            throw StoreError.invalidArgument(
                reason: "k must be in 1...\(Self.limitCap), got \(k)")
        }
        // Pack [Float] → [UInt8] little-endian (same wire format as the async path).
        var bytes: [UInt8] = []
        bytes.reserveCapacity(query.count * 4)
        for v in query {
            var x = v
            withUnsafeBytes(of: &x) { raw in bytes.append(contentsOf: raw) }
        }
        let dom = Array(domain.utf8)
        var rowids = [Int64](repeating: 0, count: k)
        var scores = [Float](repeating: 0, count: k)
        let n = dom.withUnsafeBufferPointer { domBuf in
            bytes.withUnsafeBufferPointer { qBuf in
                rowids.withUnsafeMutableBufferPointer { rBuf in
                    scores.withUnsafeMutableBufferPointer { sBuf in
                        bas_l8_vector_index_cosine_topk_for_domain(
                            enginePtr,
                            domBuf.baseAddress.map {
                                UnsafeRawPointer($0)
                                    .assumingMemoryBound(to: CChar.self)
                            },
                            domBuf.count,
                            qBuf.baseAddress, qBuf.count,
                            k, rBuf.baseAddress, sBuf.baseAddress)
                    }
                }
            }
        }
        guard n >= 0 else { throw StoreError.readFailed(code: n) }
        var out: [(atomID: String, score: Float)] = []
        out.reserveCapacity(Int(n))
        for i in 0..<Int(n) {
            if let aid = Self.atomIDForRowidSync(enginePtr, rowids[i]) {
                out.append((atomID: aid, score: scores[i]))
            }
        }
        // 先稳 P2 — deterministic ORDER: re-sort the engine's (score, rowid)-ordered top-K by
        // (score DESC, atomID ASC). atomID is content-derived (stable across engine rebuilds), so the
        // RETURNED ORDER no longer depends on rowid assignment (which the in-memory ADR-037 engine
        // reassigns on every rebuild). NOTE: this pins the ORDER; the K-th-boundary MEMBERSHIP at an EXACT
        // score tie is still rowid-decided inside the engine — a rare, ACCEPTED non-byte-equal (ADR-036:
        // this is the opt-in fast retrieve path, never the byte-deterministic spine). A full membership
        // fix is the Rust-side `, atom_id` tiebreaker (requires an XCFramework rebuild — deferred).
        out.sort { a, b in a.score != b.score ? a.score > b.score : a.atomID < b.atomID }
        return out
    }

    /// SYNC rowid → atom_id via the probe-mode FFI (null buf returns the size). Returns nil on
    /// not-found / decode failure (the caller skips that entry).
    private nonisolated static func atomIDForRowidSync(
        _ engine: OpaquePointer, _ rowid: Int64
    ) -> String? {
        let needed = bas_l8_vector_index_atom_id_for_rowid(engine, rowid, nil, 0)
        guard needed > 0 else { return nil }  // -2 not found / -1 null / 0 empty
        var buf = [UInt8](repeating: 0, count: Int(needed))
        let wrote = buf.withUnsafeMutableBufferPointer { b in
            bas_l8_vector_index_atom_id_for_rowid(
                engine, rowid, b.baseAddress, b.count)
        }
        guard wrote == needed else { return nil }
        return String(decoding: buf, as: UTF8.self)
    }
}
#endif
