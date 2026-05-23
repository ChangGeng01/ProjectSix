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

    public let databaseURL: URL
    private nonisolated(unsafe) let enginePtr: OpaquePointer

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

    deinit { _ = bas_l8_engine_close(enginePtr) }

    /// UPSERT。 Returns true on insert,false on replace
    /// (matches BASSQLiteVectorIndexStorage.upsert semantics)。
    @discardableResult
    public func upsert(
        _ entry: BASVectorIndexEntry
    ) async throws -> Bool {
        // Encode metadata as JSON via Apple boundary
        // chapter 九百二十二 / M3315 CRITICAL fix NC3:
        // .sortedKeys for deterministic encoding (was the
        // ONE L8 routed bridge the chapter 919 C2 fix missed
        // — every other routed bridge already uses sorted)。
        let metadataJson: String
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(entry.metadata)
            metadataJson = String(
                data: data, encoding: .utf8) ?? "{}"
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
        // Bound query dimension — same cap as stored
        // embeddings to prevent OOM via huge Vec allocation
        guard query.count <= 16_384 else {
            throw StoreError.invalidArgument(
                reason: "query dimension \(query.count) " +
                "exceeds cap 16384 (4 bytes × 16K floats = " +
                "64 KB,matching stored embedding cap)")
        }
        // Reject NaN/Inf — chapter 918 NaN filter on the
        // Rust side would silently drop every row otherwise
        guard query.allSatisfy({ $0.isFinite }) else {
            throw StoreError.invalidArgument(
                reason: "query contains non-finite values " +
                "(NaN or Inf) — would corrupt cosine scores")
        }
        // Pack [Float] → [UInt8] little-endian
        var bytes: [UInt8] = []
        bytes.reserveCapacity(query.count * 4)
        for v in query {
            var x = v
            withUnsafeBytes(of: &x) { raw in
                bytes.append(contentsOf: raw)
            }
        }
        return try await cosineTopK(
            forDomain: domain,
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
}
#endif
