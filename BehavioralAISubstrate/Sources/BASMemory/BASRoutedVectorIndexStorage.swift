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
}
#endif
