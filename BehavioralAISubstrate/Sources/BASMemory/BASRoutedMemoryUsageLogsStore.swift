// MARK: - BASRoutedMemoryUsageLogsStore
// chapter 九百二.5 / M3205 — sub-chapter 2 of MemoryUsageTracker
//
// L8 unification per RFC — Rust-backed bridge for the 2 sibling
// append-only Codable log tables of BASMemoryUsageTracker:
//
//   - memory_usage_replay_log  (BASReplayLogEntry append-only)
//   - memory_usage_audit_log   (BASAuditLogEntry append-only)
//
// Both schemas are bundled into ONE bridge actor because they
// share the「append-only Codable event」shape and Swift-side
// usage pattern。 Sub-chapter 902.6 ports the next slice (notes
// + bundles + tombstones)。
//
// # Apple boundary
//
// Date → epoch ms cast at the bridge:
//   Int64(recordedAt.timeIntervalSince1970 * 1000)
//
// Matches Swift `BASMemoryUsageTracker.appendReplayLog`/`Audit-
// Log` exactly for byte-equality。

import Foundation
import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
public actor BASRoutedMemoryUsageLogsStore {
    public enum StoreError: Error, Equatable, Sendable {
        case engineInitFailed
        case schemaInitFailed(table: String, code: Int32)
        case appendFailed(table: String, code: Int32)
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
        let r1 = bas_l8_memory_usage_replay_log_init_schema(
            engine)
        guard r1 == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(
                table: "replay_log", code: r1)
        }
        let r2 = bas_l8_memory_usage_audit_log_init_schema(
            engine)
        guard r2 == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(
                table: "audit_log", code: r2)
        }
    }

    deinit { _ = bas_l8_engine_close(enginePtr) }

    // MARK: - Replay log

    /// Append one replay log entry。 Returns the eventID written
    /// (caller-provided)。 Throws if SQLite rejects (e.g. dup PK)。
    @discardableResult
    public func appendReplayLog(
        eventID: String,
        eventType: String,
        payload: String,
        recordedAt: Date
    ) async throws -> String {
        let eid = Array(eventID.utf8)
        let et = Array(eventType.utf8)
        let pl = Array(payload.utf8)
        let recordedMs = Int64(
            recordedAt.timeIntervalSince1970 * 1000)
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
                        recordedMs)
                }
            }
        }
        guard rc == 0 else {
            throw StoreError.appendFailed(
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

    /// Returns the recorded_at_ms of the most-recent replay
    /// entry,or nil if the log is empty。 Used by tests to
    /// verify ordering parity with Swift `replayLogEntries-
    /// ViaSQL` ASC sort (max == last in ASC order)。
    public var latestReplayLogTimeMs: Int64? {
        get async {
            let v = bas_l8_memory_usage_replay_log_latest_time(
                enginePtr)
            return v < 0 ? nil : v
        }
    }

    // MARK: - Audit log

    @discardableResult
    public func appendAuditLog(
        entryID: String,
        actor: String,
        action: String,
        detail: String,
        recordedAt: Date
    ) async throws -> String {
        let eid = Array(entryID.utf8)
        let ac = Array(actor.utf8)
        let act = Array(action.utf8)
        let d = Array(detail.utf8)
        let recordedMs = Int64(
            recordedAt.timeIntervalSince1970 * 1000)
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
                            recordedMs)
                    }
                }
            }
        }
        guard rc == 0 else {
            throw StoreError.appendFailed(
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

    public var latestAuditLogTimeMs: Int64? {
        get async {
            let v = bas_l8_memory_usage_audit_log_latest_time(
                enginePtr)
            return v < 0 ? nil : v
        }
    }
}
#endif
