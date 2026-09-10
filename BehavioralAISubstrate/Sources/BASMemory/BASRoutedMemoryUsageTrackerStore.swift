// MARK: - BASRoutedMemoryUsageTrackerStore
// chapter 九百四 / M3220 — unified facade for the 6-table port
//
// L8 unification — single actor that bundles the 3 chapter 902.x
// sub-stores (records + logs + extras) under ONE shared L8 engine
// pointer。 Mirrors the public surface of BASMemoryUsageTracker
// so consumers can adopt the Rust-backed path with a one-line
// swap (drop-in replacement)。
//
// # Why a single facade
//
// Chapters 九百二 + 九百二.5 + 九百二.6 each shipped their own
// sub-store actor with its own engine pointer。 That's correct
// for byte-equality testing (per-table verification) but wasteful
// for production:3 engine pointers = 3 SQLite file handles + 3
// WAL files + 3 schema_version pragmas。 The facade collapses
// all of that into ONE engine while preserving the per-table
// initialization order。
//
// # Public surface parity
//
// Mirrors BASMemoryUsageTracker:
//   - record / markHelped / usageCount / recordCount
//   - appendReplayLog / appendAuditLog
//   - attachNotes
//   - tombstoneRecord / isTombstoned / tombstoneCount
//
// Bundles + first-vault-for-host queries shipped in the per-table
// sub-stores — added here as convenience methods for the bundle
// hot path (chapter 七百二十三 multi-row batch consumers)。
//
// # Discipline
//
// - 不变量 #1/#2/#3 preserved (storage doesn't change runtime
//   ordering or grant permits)
// - 红线 7 — BASMemoryUsageTracker Swift body preserved as the
//   live fallback。 This actor is an additive opt-in path,not a
//   replacement of the existing actor
// - 整体 性能 一定要 更好 — chapter 905 will measure this facade
//   vs the Swift actor and make the flip-or-decline decision

import Foundation
import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
public actor BASRoutedMemoryUsageTrackerStore {
    public enum StoreError: Error, Equatable, Sendable {
        case engineInitFailed
        case schemaInitFailed(table: String, code: Int32)
        case upsertFailed(table: String, code: Int32)
        case readFailed(table: String, code: Int32)
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
        // Initialize all 6 table schemas under the single engine
        try Self.initOneSchema(engine, label: "records") {
            bas_l8_memory_usage_records_init_schema($0) }
        try Self.initOneSchema(engine, label: "replay_log") {
            bas_l8_memory_usage_replay_log_init_schema($0) }
        try Self.initOneSchema(engine, label: "audit_log") {
            bas_l8_memory_usage_audit_log_init_schema($0) }
        try Self.initOneSchema(engine, label: "notes") {
            bas_l8_memory_usage_notes_init_schema($0) }
        try Self.initOneSchema(engine, label: "bundles") {
            bas_l8_memory_usage_bundles_init_schema($0) }
        try Self.initOneSchema(engine, label: "tombstones") {
            bas_l8_memory_usage_tombstones_init_schema($0) }
    }

    private static func initOneSchema(
        _ engine: OpaquePointer,
        label: String,
        _ fn: (OpaquePointer) -> Int32
    ) throws {
        let rc = fn(engine)
        guard rc == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(
                table: label, code: rc)
        }
    }

    deinit { _ = bas_l8_engine_close(enginePtr) }

    // MARK: - Records (chapter 902 surface)

    /// Append one retrieval event。 Mints a UUID recordID,
    /// inserts with helpedFlag = .unknown,returns the
    /// recordID for later markHelped propagation。 Mirrors
    /// Swift `BASMemoryUsageTracker.record(...)` exactly。
    @discardableResult
    public func record(
        atomID: String,
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        retrievedAt: Date = Date()
    ) async throws -> String {
        let recordID = UUID().uuidString
        try upsertRecord(
            recordID: recordID,
            atomID: atomID,
            retrievedAt: retrievedAt,
            sessionRef: sessionRef,
            turnRef: turnRef,
            permitMode: permitMode,
            helpedState: "unknown")
        return recordID
    }

    /// Mark a previously-recorded event as helped / not-helped。
    /// Throws if the recordID is unknown (mirrors Swift's
    /// `unknownRecord` error path)。
    ///
    /// Implementation:uses the dedicated `update_helped_state`
    /// Rust primitive (chapter 904 fix) which does NOT insert
    /// placeholder rows on unknown record_id。 Returns 0 from
    /// Rust = not found,1 = updated,which we map to throw/ok。
    public func markHelped(
        recordID: String,
        helped: Bool
    ) async throws {
        let newState = helped ? "helped" : "notHelped"
        let rid = Array(recordID.utf8)
        let hs = Array(newState.utf8)
        let rc = rid.withUnsafeBufferPointer { ridBuf in
            hs.withUnsafeBufferPointer { hsBuf in
                bas_l8_memory_usage_records_update_helped_state(
                    enginePtr,
                    ridBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(
                                to: CChar.self)
                    },
                    ridBuf.count,
                    hsBuf.baseAddress.map {
                        UnsafeRawPointer($0)
                            .assumingMemoryBound(
                                to: CChar.self)
                    },
                    hsBuf.count)
            }
        }
        switch rc {
        case 1: return  // updated
        case 0:
            // Unknown record_id — mirror Swift's `unknownRecord`
            // throw path (chapter 902 byte-eq pin)
            throw StoreError.upsertFailed(
                table: "records", code: -2)
        default:
            throw StoreError.upsertFailed(
                table: "records", code: rc)
        }
    }

    /// UPSERT one record。 The lower-level primitive — public
    /// so consumers can replay logs or bulk-load records with
    /// pre-existing IDs。 Returns true if a new row was
    /// inserted,false if helped_state was updated on conflict。
    @discardableResult
    public func upsertRecord(
        recordID: String,
        atomID: String,
        retrievedAt: Date,
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        helpedState: String
    ) throws -> Bool {
        let rid = Array(recordID.utf8)
        let aid = Array(atomID.utf8)
        let sid = Array(sessionRef.utf8)
        let tid = Array(turnRef.utf8)
        let pm = Array(permitMode.utf8)
        let hs = Array(helpedState.utf8)
        let ms = Int64(retrievedAt.timeIntervalSince1970 * 1000)
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
                                    ms,
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
        case 1: return true
        case 0: return false
        default:
            throw StoreError.upsertFailed(
                table: "records", code: rc)
        }
    }

    public var recordCount: Int {
        get async {
            let c = bas_l8_memory_usage_records_count(
                enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    public func usageCount(
        forAtomID atomID: String
    ) async -> Int {
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

    public func countForSession(_ sessionRef: String) async
        -> Int
    {
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

    public func helpedState(
        forRecordID recordID: String
    ) throws -> String? {
        let bytes = Array(recordID.utf8)
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
        if needed == -2 { return nil }
        if needed < 0 {
            throw StoreError.readFailed(
                table: "records", code: needed)
        }
        if needed == 0 { return "" }
        var outBuf = [UInt8](repeating: 0, count: Int(needed))
        let written = bytes.withUnsafeBufferPointer { buf in
            outBuf.withUnsafeMutableBufferPointer { ob in
                bas_l8_memory_usage_records_helped_state_for_record(
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
            throw StoreError.readFailed(
                table: "records", code: written)
        }
        return String(bytes: outBuf, encoding: .utf8)
    }

    // MARK: - Replay log (chapter 902.5 surface)

    @discardableResult
    public func appendReplayLog(
        eventType: String,
        payload: String,
        recordedAt: Date = Date()
    ) async throws -> String {
        let eventID = UUID().uuidString
        let eid = Array(eventID.utf8)
        let et = Array(eventType.utf8)
        let pl = Array(payload.utf8)
        let ms = Int64(recordedAt.timeIntervalSince1970 * 1000)
        let rc = eid.withUnsafeBufferPointer { eidBuf in
            et.withUnsafeBufferPointer { etBuf in
                pl.withUnsafeBufferPointer { plBuf in
                    bas_l8_memory_usage_replay_log_append(
                        enginePtr,
                        eidBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        eidBuf.count,
                        etBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        etBuf.count,
                        plBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        plBuf.count,
                        ms)
                }
            }
        }
        guard rc == 0 else {
            throw StoreError.upsertFailed(
                table: "replay_log", code: rc)
        }
        return eventID
    }

    public var replayLogCount: Int {
        get async {
            let c = bas_l8_memory_usage_replay_log_count(
                enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    // MARK: - Audit log (chapter 902.5 surface)

    @discardableResult
    public func appendAuditLog(
        actor: String,
        action: String,
        detail: String,
        recordedAt: Date = Date()
    ) async throws -> String {
        let entryID = UUID().uuidString
        let eid = Array(entryID.utf8)
        let ac = Array(actor.utf8)
        let act = Array(action.utf8)
        let d = Array(detail.utf8)
        let ms = Int64(recordedAt.timeIntervalSince1970 * 1000)
        let rc = eid.withUnsafeBufferPointer { eidBuf in
            ac.withUnsafeBufferPointer { acBuf in
                act.withUnsafeBufferPointer { actBuf in
                    d.withUnsafeBufferPointer { dBuf in
                        bas_l8_memory_usage_audit_log_append(
                            enginePtr,
                            eidBuf.baseAddress.map {
                                UnsafeRawPointer($0)
                                    .assumingMemoryBound(
                                        to: CChar.self)
                            },
                            eidBuf.count,
                            acBuf.baseAddress.map {
                                UnsafeRawPointer($0)
                                    .assumingMemoryBound(
                                        to: CChar.self)
                            },
                            acBuf.count,
                            actBuf.baseAddress.map {
                                UnsafeRawPointer($0)
                                    .assumingMemoryBound(
                                        to: CChar.self)
                            },
                            actBuf.count,
                            dBuf.baseAddress.map {
                                UnsafeRawPointer($0)
                                    .assumingMemoryBound(
                                        to: CChar.self)
                            },
                            dBuf.count,
                            ms)
                    }
                }
            }
        }
        guard rc == 0 else {
            throw StoreError.upsertFailed(
                table: "audit_log", code: rc)
        }
        return entryID
    }

    public var auditLogCount: Int {
        get async {
            let c = bas_l8_memory_usage_audit_log_count(
                enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    // MARK: - Notes (chapter 902.6 surface)

    public func attachNotes(
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
            throw StoreError.upsertFailed(
                table: "notes", code: rc)
        }
    }

    public var notesCount: Int {
        get async {
            let c = bas_l8_memory_usage_notes_count(enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    // MARK: - Tombstones (chapter 902.6 surface)

    public func tombstoneRecord(
        recordID: String,
        tombstonedAt: Date = Date()
    ) async throws {
        let bytes = Array(recordID.utf8)
        let ms = Int64(
            tombstonedAt.timeIntervalSince1970 * 1000)
        let rc = bytes.withUnsafeBufferPointer { buf in
            bas_l8_memory_usage_tombstones_upsert(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count,
                ms)
        }
        guard rc == 0 else {
            throw StoreError.upsertFailed(
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

    public func isTombstoned(recordID: String) async -> Bool {
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
