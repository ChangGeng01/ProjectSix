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
    }

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
        let metadataJson: String
        do {
            let data = try JSONEncoder()
                .encode(entry.metadata)
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
            throw StoreError.upsertFailed(code: needed)
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
            throw StoreError.upsertFailed(code: written)
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
        precondition(k > 0, "Top-k must be positive")
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
            throw StoreError.upsertFailed(code: n)
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
    /// Returns top-k (rowid, score) pairs sorted descending
    /// by score。
    public func cosineTopK(
        forDomain domain: String,
        queryBytes: [UInt8],
        k: Int
    ) async throws -> [(rowid: Int64, score: Float)] {
        precondition(k > 0,
            "Top-k must be positive")
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
            throw StoreError.upsertFailed(code: n)
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
