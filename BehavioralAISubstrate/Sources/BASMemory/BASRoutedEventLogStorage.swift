// MARK: - BASRoutedEventLogStorage
// chapter 九百一 / M3195 — L8 unification HIGH-risk migration #1
//
// Swift bridge for BASSQLiteEventLogStorage per RFC。 Per-event
// turn-loop hot path — every turn lifecycle event flows through
// here。 Auto-sequence + idempotent append + prune semantics
// match the Swift actor exactly。
//
// 「细心开发」 discipline:more rigorous than ch 895-900 bridges。
// Tests include duplicate-event-id idempotency,sequence number
// ordering verification,prune row-count return correctness,and
// full byte-equality vs BASSQLiteEventLogStorage。
//
// # Scope (chapter 901)
//
// Minimum viable bridge for the turn-loop hot path:
//   - append (returns (wasNew, assignedSequenceNumber))
//   - totalCount
//   - countForSession + countForKind + nextSequence
//   - pruneEventsBefore (returns Int row count)
//
// events(forSession:) + events(sinceTimestampMs:limit:) full-
// list query support deferred to ch 901.5 — requires Rust FFI
// extension returning serialized row blobs。

import Foundation
import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
public actor BASRoutedEventLogStorage: BASEventLogStorage {
    public enum StoreError: Error, Equatable, Sendable {
        case engineInitFailed
        case schemaInitFailed(code: Int32)
        case appendFailed(code: Int64)
        case payloadEncodingFailed
        case pruneFailed(code: Int64)
        /// chapter 九百十八 / M3295 fix
        case invalidArgument(reason: String)
        /// chapter 九百十九 / M3300 CRITICAL fix C1
        case readFailed(code: Int32)
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
        let rc = bas_l8_event_log_init_schema(engine)
        guard rc == 0 else {
            _ = bas_l8_engine_close(engine)
            throw StoreError.schemaInitFailed(code: rc)
        }
    }

    deinit { _ = bas_l8_engine_close(enginePtr) }

    // MARK: - BASEventLogStorage conformance

    @discardableResult
    public func append(
        _ entry: BASEventLogEntry
    ) async throws -> (
        wasNew: Bool, assignedSequenceNumber: Int64)
    {
        // JSON-encode the full entry into payload_json for v1
        // format (matches legacy Swift actor's JSON path)。
        // Apple boundary:JSONEncoder。
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(entry),
              let payloadJson = String(
                data: data, encoding: .utf8)
        else {
            throw StoreError.payloadEncodingFailed
        }
        let eid = Array(entry.eventID.utf8)
        let sid = Array(entry.sessionID.utf8)
        let kind = Array(entry.kind.rawValue.utf8)
        let riskBand = Array(entry.riskBand.rawValue.utf8)
        let pj = Array(payloadJson.utf8)

        var wasNewFlag: Int32 = -1
        let seq = eid.withUnsafeBufferPointer { eidBuf in
            sid.withUnsafeBufferPointer { sidBuf in
                kind.withUnsafeBufferPointer { kindBuf in
                    riskBand.withUnsafeBufferPointer { rbBuf in
                        pj.withUnsafeBufferPointer { pjBuf in
                            bas_l8_event_log_append(
                                enginePtr,
                                eidBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                eidBuf.count,
                                sidBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                sidBuf.count,
                                entry.timestampMs,
                                kindBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                kindBuf.count,
                                rbBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                rbBuf.count,
                                pjBuf.baseAddress.map {
                                    UnsafeRawPointer($0)
                                        .assumingMemoryBound(
                                            to: CChar.self)
                                },
                                pjBuf.count,
                                1,  // payload_format = 1 (json)
                                nil, 0,  // no blob
                                &wasNewFlag)
                        }
                    }
                }
            }
        }
        guard seq >= 0 else {
            throw StoreError.appendFailed(code: seq)
        }
        return (
            wasNew: wasNewFlag == 1,
            assignedSequenceNumber: seq)
    }

    public func events(
        forSession sessionID: String
    ) async -> [BASEventLogEntry] {
        // Chapter 901 partial conformance — full row query
        // deferred to chapter 901.5。
        return []
    }

    public func events(
        sinceTimestampMs since: Int64,
        limit: Int
    ) async -> [BASEventLogEntry] {
        return []
    }

    public var totalCount: Int {
        get async {
            let c = bas_l8_event_log_count(enginePtr)
            return c < 0 ? 0 : Int(c)
        }
    }

    @discardableResult
    public func pruneEventsBefore(
        timestampMs cutoff: Int64
    ) async throws -> Int {
        let n = bas_l8_event_log_prune_before(
            enginePtr, cutoff)
        guard n >= 0 else {
            throw StoreError.pruneFailed(code: n)
        }
        return Int(n)
    }

    // MARK: - Extra helpers (for tests + future query-FFI wiring)

    public func countForSession(_ sessionID: String) async -> Int {
        let bytes = Array(sessionID.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_event_log_count_for_session(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return c < 0 ? 0 : Int(c)
    }

    public func countForKind(_ kind: String) async -> Int {
        let bytes = Array(kind.utf8)
        let c = bytes.withUnsafeBufferPointer { buf in
            bas_l8_event_log_count_for_kind(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return c < 0 ? 0 : Int(c)
    }

    public func nextSequence(
        forSession sessionID: String
    ) async -> Int64 {
        let bytes = Array(sessionID.utf8)
        let n = bytes.withUnsafeBufferPointer { buf in
            bas_l8_event_log_next_sequence(
                enginePtr,
                buf.baseAddress.map {
                    UnsafeRawPointer($0)
                        .assumingMemoryBound(to: CChar.self)
                },
                buf.count)
        }
        return n
    }

    // MARK: - chapter 九百九 / M3250 hot-path consolidation #2

    /// INTEGRATED fetch of the N most-recent events for a
    /// session — returns parallel (timestampMs, sequence)
    /// tuples sorted DESC by timestamp in ONE FFI call。
    /// Extends the chapter 906 cosine_topk consolidation
    /// pattern to event_log。
    public func recentTimestamps(
        forSession sessionID: String,
        limit: Int
    ) async throws -> [(timestampMs: Int64, seq: Int64)] {
        guard limit > 0 && limit <= Self.limitCap else {
            throw StoreError.invalidArgument(
                reason: "limit must be in 1...\(Self.limitCap), got \(limit)")
        }
        let bytes = Array(sessionID.utf8)
        var timestamps = [Int64](repeating: 0, count: limit)
        var sequences = [Int64](repeating: 0, count: limit)
        let n = bytes.withUnsafeBufferPointer { sidBuf in
            timestamps.withUnsafeMutableBufferPointer { tBuf in
                sequences.withUnsafeMutableBufferPointer { sBuf in
                    bas_l8_event_log_recent_timestamps_for_session(
                        enginePtr,
                        sidBuf.baseAddress.map {
                            UnsafeRawPointer($0)
                                .assumingMemoryBound(
                                    to: CChar.self)
                        },
                        sidBuf.count,
                        limit,
                        tBuf.baseAddress,
                        sBuf.baseAddress)
                }
            }
        }
        guard n >= 0 else {
            // chapter 九百十九 / M3300 CRITICAL fix C1:
            // this is a READ path,not an append。 The
            // misleading `.appendFailed` previously triggered
            // wrong catch-by-case logic in consumers。
            throw StoreError.readFailed(code: n)
        }
        var out: [(timestampMs: Int64, seq: Int64)] = []
        out.reserveCapacity(Int(n))
        for i in 0..<Int(n) {
            out.append((
                timestampMs: timestamps[i],
                seq: sequences[i]))
        }
        return out
    }
}
#endif
