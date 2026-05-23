// MARK: - BASRoutedMemoryUsageRecordsStore
// chapter 九百二 / M3200 — HIGH-risk migration #2 SCOPED
//
// L8 unification per RFC — Rust-backed bridge for the
// `memory_usage_records` table ONLY (1 of 6 tables in the legacy
// BASMemoryUsageTracker actor)。 Per 「细心继续」 discipline the
// remaining 5 tables ship in sub-chapters 902.5/902.6/903。
//
// # Scope (chapter 902)
//
// Minimum viable bridge for the per-retrieval write hot path:
//   - upsertRecord (returns wasNew Bool — true on INSERT,
//     false on UPSERT-only-helped_state on conflict)
//   - recordCount (total rows)
//   - usageCount(forAtomID:)
//   - countForSession(_:)
//   - helpedState(forRecordID:) — returns String? (nil if not
//     found) — used by tests to verify UPSERT propagation
//
// markHelped / recordBatch / fetchAllRecords / SQL query paths
// ship in sub-chapter 902.5 once the records-only base is byte-eq
// proved against BASMemoryUsageTracker。
//
// # UPSERT semantics
//
// On conflict (existing record_id),the Rust side updates ONLY
// the `helped_state` column。 All other fields stay at their
// original insert values。 This matches Swift `upsertRecord`
// exactly — the host's markHelped flow re-issues an UPSERT with
// the new flag without rewriting the rest of the record。

import Foundation
import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
public actor BASRoutedMemoryUsageRecordsStore {
    public enum StoreError: Error, Equatable, Sendable {
        case engineInitFailed
        case schemaInitFailed(code: Int32)
        case upsertFailed(code: Int32)
        case recordNotFound(recordID: String)
        case helpedStateReadFailed(code: Int32)
        /// chapter 九百十八 / M3295 fix
        case invalidArgument(reason: String)
    }

    /// chapter 九百十八 / M3295 fix:upper bound on limit
    /// to prevent OOM via [Int64] allocation。
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
        let rc = bas_l8_memory_usage_records_init_schema(engine)
        guard rc == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(code: rc)
        }
    }

    deinit { _ = bas_l8_engine_close(enginePtr) }

    // MARK: - Records-table API

    /// UPSERT one retrieval record。 Returns true if a new row
    /// was inserted,false if the record_id already existed and
    /// ONLY the helped_state column was updated (matches Swift
    /// `BASMemoryUsageTracker.upsertRecord` exactly)。
    ///
    /// The Apple-boundary date conversion (Date → epoch ms)
    /// mirrors the Swift actor's `Int64(retrievedAt.
    /// timeIntervalSince1970 * 1000)` cast for byte-equality。
    @discardableResult
    public func upsertRecord(
        recordID: String,
        atomID: String,
        retrievedAt: Date,
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        helpedState: String
    ) async throws -> Bool {
        let rid = Array(recordID.utf8)
        let aid = Array(atomID.utf8)
        let sid = Array(sessionRef.utf8)
        let tid = Array(turnRef.utf8)
        let pm = Array(permitMode.utf8)
        let hs = Array(helpedState.utf8)
        let retrievedMs = Int64(
            retrievedAt.timeIntervalSince1970 * 1000)

        let rc = rid.withUnsafeBufferPointer { ridBuf in
            aid.withUnsafeBufferPointer { aidBuf in
                sid.withUnsafeBufferPointer { sidBuf in
                    tid.withUnsafeBufferPointer { tidBuf in
                        pm.withUnsafeBufferPointer { pmBuf in
                            hs.withUnsafeBufferPointer { hsBuf in
                                bas_l8_memory_usage_records_upsert(
                                    enginePtr,
                                    ridBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    ridBuf.count,
                                    aidBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    aidBuf.count,
                                    retrievedMs,
                                    sidBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    sidBuf.count,
                                    tidBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    tidBuf.count,
                                    pmBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    pmBuf.count,
                                    hsBuf.baseAddress.map {
                                        UnsafeRawPointer($0)
                                            .assumingMemoryBound(
                                                to: CChar.self)
                                    },
                                    hsBuf.count)
                            }
                        }
                    }
                }
            }
        }
        switch rc {
        case 1: return true   // new row inserted
        case 0: return false  // existing row's helped_state updated
        default:
            throw StoreError.upsertFailed(code: rc)
        }
    }

    public var recordCount: Int {
        get async {
            let c = bas_l8_memory_usage_records_count(enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    public func usageCount(forAtomID atomID: String) async -> Int {
        let bytes = Array(atomID.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_memory_usage_records_usage_count_for_atom(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return c < 0 ? 0 : Int(c)
    }

    public func countForSession(_ sessionRef: String) async -> Int {
        let bytes = Array(sessionRef.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_memory_usage_records_count_for_session(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return c < 0 ? 0 : Int(c)
    }

    /// Returns the current helped_state string for the given
    /// recordID,or nil if the recordID is unknown。 Used by tests
    /// to verify UPSERT semantics propagate through Rust。
    public func helpedState(
        forRecordID recordID: String
    ) async throws -> String? {
        let bytes = Array(recordID.utf8)
        // Probe size first
        let needed = bytes.withUnsafeBufferPointer { buf in
            bas_l8_memory_usage_records_helped_state_for_record(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count,
                nil, 0)
        }
        if needed == -2 { return nil }  // record not found
        if needed < 0 {
            throw StoreError.helpedStateReadFailed(code: needed)
        }
        if needed == 0 { return "" }
        var outBuf = [UInt8](repeating: 0, count: Int(needed))
        let written = bytes.withUnsafeBufferPointer { buf in
            outBuf.withUnsafeMutableBufferPointer { ob in
                bas_l8_memory_usage_records_helped_state_for_record(
                    enginePtr,
                    buf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(to: CChar.self)
                    },
                    buf.count,
                    ob.baseAddress, ob.count)
            }
        }
        guard written == needed else {
            throw StoreError.helpedStateReadFailed(code: written)
        }
        return String(bytes: outBuf, encoding: .utf8)
    }

    // MARK: - chapter 九百十一 hot-path consolidation #3

    /// INTEGRATED fetch of N most-recent records for an atom_id。
    /// Returns parallel (timestampMs, helpedFlag) tuples sorted
    /// DESC by timestamp in ONE FFI call。 Extends the chapter
    /// 906/909 hot-path consolidation pattern to records table。
    public func recentRecords(
        forAtomID atomID: String,
        limit: Int
    ) async throws
        -> [(timestampMs: Int64, helped: String)]
    {
        guard limit > 0 && limit <= Self.limitCap else {
            throw StoreError.invalidArgument(
                reason: "limit must be in 1...\(Self.limitCap), got \(limit)")
        }
        let bytes = Array(atomID.utf8)
        var timestamps = [Int64](repeating: 0, count: limit)
        var helpedCodes = [Int64](repeating: 0, count: limit)
        let n = bytes.withUnsafeBufferPointer { aidBuf in
            timestamps.withUnsafeMutableBufferPointer { tBuf in
                helpedCodes.withUnsafeMutableBufferPointer { hBuf in
                    bas_l8_memory_usage_records_recent_for_atom(
                        enginePtr,
                        aidBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        aidBuf.count,
                        limit,
                        tBuf.baseAddress,
                        hBuf.baseAddress)
                }
            }
        }
        guard n >= 0 else {
            throw StoreError.upsertFailed(code: n)
        }
        var out: [(timestampMs: Int64, helped: String)] = []
        out.reserveCapacity(Int(n))
        for i in 0..<Int(n) {
            let helpedStr: String
            switch helpedCodes[i] {
            case 0: helpedStr = "unknown"
            case 1: helpedStr = "helped"
            case 2: helpedStr = "notHelped"
            default: helpedStr = "other"
            }
            out.append((
                timestampMs: timestamps[i],
                helped: helpedStr))
        }
        return out
    }
}
#endif
