// MARK: - BASRoutedMemoryUsageExtrasStore
// chapter 九百二.6 / M3210 — sub-chapter 3 of MemoryUsageTracker
//
// L8 unification — closes out the 6-table port by bridging
// the remaining 3 tables of BASMemoryUsageTracker:
//
//   - memory_usage_record_notes (UPSERT keyed by record_id)
//   - memory_usage_bundles (composite PK bundle_id+record_id,
//     position_in_bundle ordering)
//   - memory_usage_tombstones (INSERT OR REPLACE single-col PK)
//
// FTS5 virtual table (`memory_usage_record_notes_fts`) is
// deferred to sub-chapter 902.6.5 once measured consumer
// pressure arises (per 亏的不要硬上 + chapter 884 DECLINE-
// PENDING-CONSUMER pattern)。

import Foundation
import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
public actor BASRoutedMemoryUsageExtrasStore {
    public enum StoreError: Error, Equatable, Sendable {
        case engineInitFailed
        case schemaInitFailed(table: String, code: Int32)
        case writeFailed(table: String, code: Int32)
        case notesReadFailed(code: Int32)
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
        let r1 = bas_l8_memory_usage_notes_init_schema(engine)
        guard r1 == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(
                table: "notes", code: r1)
        }
        let r2 = bas_l8_memory_usage_bundles_init_schema(engine)
        guard r2 == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(
                table: "bundles", code: r2)
        }
        let r3 = bas_l8_memory_usage_tombstones_init_schema(
            engine)
        guard r3 == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(
                table: "tombstones", code: r3)
        }
    }

    deinit { _ = bas_l8_engine_close(enginePtr) }

    // MARK: - Notes (UPSERT on conflict, notes column)

    public func upsertNotes(
        recordID: String,
        notes: String
    ) async throws {
        let rid = Array(recordID.utf8)
        let n = Array(notes.utf8)
        let rc = rid.withUnsafeBufferPointer { ridBuf in
            n.withUnsafeBufferPointer { nBuf in
                bas_l8_memory_usage_notes_upsert(
                    enginePtr,
                    ridBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(
                                to: CChar.self)
                    },
                    ridBuf.count,
                    nBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(
                                to: CChar.self)
                    },
                    nBuf.count)
            }
        }
        guard rc == 0 else {
            throw StoreError.writeFailed(
                table: "notes", code: rc)
        }
    }

    public var notesCount: Int {
        get async {
            let c = bas_l8_memory_usage_notes_count(enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    public func notes(
        forRecordID recordID: String
    ) async throws -> String? {
        let bytes = Array(recordID.utf8)
        let needed = bytes.withUnsafeBufferPointer { buf in
            bas_l8_memory_usage_notes_for_record(
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
            throw StoreError.notesReadFailed(code: needed)
        }
        if needed == 0 { return "" }
        var outBuf = [UInt8](repeating: 0, count: Int(needed))
        let written = bytes.withUnsafeBufferPointer { buf in
            outBuf.withUnsafeMutableBufferPointer { ob in
                bas_l8_memory_usage_notes_for_record(
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
            throw StoreError.notesReadFailed(code: written)
        }
        return String(bytes: outBuf, encoding: .utf8)
    }

    // MARK: - Bundles (composite PK)

    /// Insert one bundle row。 Composite (bundle_id, record_id)
    /// must be unique — duplicate raises a SQLite PRIMARY KEY
    /// violation (-2 from FFI)。 Use a higher-level wrapper
    /// for full-bundle insertion that drives this in a loop
    /// (e.g. recordBundle in chapter 903 unified bridge)。
    public func insertBundleRow(
        bundleID: String,
        recordID: String,
        positionInBundle: Int64,
        createdAtMs: Int64
    ) async throws {
        let bid = Array(bundleID.utf8)
        let rid = Array(recordID.utf8)
        let rc = bid.withUnsafeBufferPointer { bidBuf in
            rid.withUnsafeBufferPointer { ridBuf in
                bas_l8_memory_usage_bundles_insert_row(
                    enginePtr,
                    bidBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(
                                to: CChar.self)
                    },
                    bidBuf.count,
                    ridBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(
                                to: CChar.self)
                    },
                    ridBuf.count,
                    positionInBundle,
                    createdAtMs)
            }
        }
        guard rc == 0 else {
            throw StoreError.writeFailed(
                table: "bundles", code: rc)
        }
    }

    public var totalBundleRows: Int {
        get async {
            let c = bas_l8_memory_usage_bundles_total_rows(
                enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    public var distinctBundleCount: Int {
        get async {
            let c =
                bas_l8_memory_usage_bundles_distinct_count(
                    enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    public func countRecordsInBundle(_ bundleID: String) async
        -> Int
    {
        let bytes = Array(bundleID.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_memory_usage_bundles_count_in_bundle(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return c < 0 ? 0 : Int(c)
    }

    // MARK: - Tombstones (INSERT OR REPLACE)

    public func upsertTombstone(
        recordID: String,
        tombstonedAtMs: Int64
    ) async throws {
        let bytes = Array(recordID.utf8)
        let rc = bytes.withUnsafeBufferPointer { buf in
            bas_l8_memory_usage_tombstones_upsert(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count,
                tombstonedAtMs)
        }
        guard rc == 0 else {
            throw StoreError.writeFailed(
                table: "tombstones", code: rc)
        }
    }

    public var tombstoneCount: Int {
        get async {
            let c = bas_l8_memory_usage_tombstones_count(
                enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    public func isTombstoned(
        recordID: String
    ) async -> Bool {
        let bytes = Array(recordID.utf8)
        let rc = bytes.withUnsafeBufferPointer { buf in
            bas_l8_memory_usage_tombstones_is_tombstoned(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return rc == 1
    }
}
#endif
