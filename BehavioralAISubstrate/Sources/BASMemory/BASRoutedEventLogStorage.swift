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

    /// audit memory-b F12 — OPT-IN diagnostic hook (default nil), mirroring
    /// BASSQLiteEventLogStorage.onSilentFailure. The non-throwing read
    /// accessors route a swallowed FFI/decode error here BEFORE defaulting to
    /// [], so a host can tell "no events" (genuinely empty session) from
    /// "event log CORRUPT" (which the read used to present as an empty store =
    /// false total-amnesia). Fires only on the error path ⇒ byte-equal on
    /// success + genuine-empty. Default nil ⇒ today's exact behavior.
    public var onSilentFailure: (@Sendable (Error) -> Void)?

    /// Wire the diagnostic hook (actor-isolated; set once at setup).
    public func setOnSilentFailure(_ handler: (@Sendable (Error) -> Void)?) {
        self.onSilentFailure = handler
    }

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
        // chapter 九百三十八 / M3395 — USER-PASS substance fix #5
        // (FINAL — closes the USER-PASS arc)。 Append stores full
        // BASEventLogEntry as payload_json (format=1) so read-back
        // just concatenates payload_json bytes into JSON array。
        // audit memory-b F12: route a corrupt/error read to onSilentFailure
        // before defaulting to [] (was silent corrupt-as-empty).
        do {
            return try Self.eventsArrayViaJsonFfiThrowing(
                engine: enginePtr, sessionID: sessionID,
                sinceMs: nil, limit: nil)
        } catch { onSilentFailure?(error); return [] }
    }

    public func events(
        sinceTimestampMs since: Int64,
        limit: Int
    ) async -> [BASEventLogEntry] {
        // chapter 九百三十八 / M3395 — see events(forSession:)
        do {
            return try Self.eventsArrayViaJsonFfiThrowing(
                engine: enginePtr, sessionID: nil,
                sinceMs: since, limit: limit)
        } catch { onSilentFailure?(error); return [] }
    }

    /// audit memory-b F12 — THROWING sibling of `events(forSession:)`。 A
    /// corrupt / unreadable event log throws `StoreError.readFailed` instead of
    /// presenting as an empty session (false total-amnesia). A genuinely empty
    /// session still returns []。 Consumers that must not project amnesia over a
    /// corrupt log (e.g. BASMemoryAtomReducer) read through this.
    public func eventsOrThrow(
        forSession sessionID: String
    ) async throws -> [BASEventLogEntry] {
        try Self.eventsArrayViaJsonFfiThrowing(
            engine: enginePtr, sessionID: sessionID,
            sinceMs: nil, limit: nil)
    }

    /// audit memory-b F12 — THROWING sibling of `events(sinceTimestampMs:limit:)`。
    public func eventsOrThrow(
        sinceTimestampMs since: Int64,
        limit: Int
    ) async throws -> [BASEventLogEntry] {
        try Self.eventsArrayViaJsonFfiThrowing(
            engine: enginePtr, sessionID: nil,
            sinceMs: since, limit: limit)
    }

    public var totalCount: Int {
        get async {
            let c = bas_l8_event_log_count(enginePtr)
            // audit memory-b F12: a negative count is an error, not "0 events" —
            // surface it to the hook before defaulting (byte-equal return).
            if c < 0 {
                onSilentFailure?(StoreError.readFailed(code: Int32(clamping: c)))
                return 0
            }
            return Int(c)
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

    /// chapter 九百三十八 / M3395 — shared probe+fill helper for
    /// the two events query variants。 `sessionID` non-nil →
    /// session-filtered;`sinceMs` non-nil → timestamp+limit
    /// filtered。 Mutually exclusive (helper enforces by
    /// dispatching to the correct FFI symbol)。
    /// H10 (mega-audit, 2026-07-08): per-session cursor page size. The full history is read
    /// in batches of this many events so a single FFI String allocation stays bounded while
    /// the projection still sees EVERY event (the un-paginated read capped at the oldest
    /// 100k and silently dropped late removed/quarantined events → resurrected deleted atoms).
    // `internal` (not private) + `var` so tests can lower it to force the multi-page loop
    // over a small corpus. Production default stays 10k and is NEVER mutated at runtime —
    // only test setUp/tearDown assigns it, single-threaded, so `nonisolated(unsafe)` is sound.
    nonisolated(unsafe) static var sessionPageSize = 10_000

    // audit memory-b F12 — THROWING core. Every path that used to collapse a
    // read ERROR (negative FFI code, cursor anomaly, non-empty-buffer decode
    // failure) into an empty [] now throws StoreError.readFailed;a GENUINELY
    // empty result still returns [] (a real "[]" decodes without throwing).
    // The non-throwing `events(...)` catch → onSilentFailure → [] for
    // byte-equal behavior; `eventsOrThrow(...)` lets it propagate.
    private static func eventsArrayViaJsonFfiThrowing(
        engine: OpaquePointer,
        sessionID: String?,
        sinceMs: Int64?,
        limit: Int?
    ) throws -> [BASEventLogEntry] {
        // Session-filtered read: PAGINATE the full history by sequence_number cursor. The
        // cursor is exclusive (`seq > after`), so it starts at -1 to include seq 0, and
        // advances to the last event's seq each batch.
        //
        // H10 fail-CLOSED (adversarial review, 2026-07-08): termination is on a genuinely
        // EMPTY page, NOT a short one — a short-but-non-empty page (e.g. a filtered row) still
        // fetches once more so the tail is never dropped. And a page READ ERROR (FFI failure
        // or decode failure — `nil`, distinct from an empty `[]`) fails the WHOLE read to
        // empty rather than returning a partial/torn history: a partial projection would omit
        // late removed/quarantined events and resurrect deleted atoms (the exact bug), whereas
        // an empty projection resurrects nothing. Never silently return an incomplete history.
        if let sid = sessionID {
            var acc: [BASEventLogEntry] = []
            var afterSeq: Int64 = -1
            while true {
                guard let page = fetchSessionPage(
                    engine: engine, sessionID: sid,
                    afterSeq: afterSeq, limit: Int64(sessionPageSize))
                else {
                    // read error mid-stream (fetchSessionPage nil = FFI/decode failure,
                    // distinct from an empty page) → THROW, don't present as empty history。
                    throw StoreError.readFailed(code: -1)
                }
                if page.isEmpty { break }   // genuine end of stream
                acc.append(contentsOf: page)
                // The cursor MUST advance on a non-empty page (Rust returns seq > afterSeq,
                // ascending); if it somehow can't, that is an anomaly → THROW.
                guard let last = page.last, last.sequenceNumber > afterSeq else {
                    throw StoreError.readFailed(code: -2)
                }
                afterSeq = last.sequenceNumber
            }
            return acc
        }

        // Timestamp-window read (bounded-preview path, caller supplies the limit)。
        // audit memory-b F12: a NEGATIVE size probe is an error (throw); a genuinely
        // empty window ("[]", needed 2 — or a 0/1 non-negative probe) returns [].
        let needed = bas_l8_event_log_events_since_ts(
            engine, sinceMs ?? 0, Int64(limit ?? 0), nil, 0)
        if needed < 0 { throw StoreError.readFailed(code: needed) }
        guard needed >= 2 else { return [] }
        var buf = [UInt8](repeating: 0, count: Int(needed))
        let written = buf.withUnsafeMutableBufferPointer { oBuf in
            bas_l8_event_log_events_since_ts(
                engine, sinceMs ?? 0, Int64(limit ?? 0),
                oBuf.baseAddress, oBuf.count)
        }
        guard written >= 0 else { throw StoreError.readFailed(code: written) }
        // A non-empty buffer that fails to decode is CORRUPT → throw (was ?? []).
        return try JSONDecoder().decode(
            [BASEventLogEntry].self,
            from: Data(buf.prefix(Int(written))))
    }

    /// One paginated batch: events with `sequence_number > afterSeq`, up to `limit`, via the
    /// two-call size-probe FFI.
    ///
    /// Returns `nil` on ANY read failure — a negative FFI code (SQLite error / buffer race /
    /// i32 overflow) OR a JSON decode failure of a non-empty buffer. It returns an EMPTY
    /// array ONLY for a genuinely empty page (`"[]"`, exactly 2 bytes). The caller relies on
    /// this `nil`-vs-`[]` distinction to fail closed on error instead of mistaking a failed
    /// page for end-of-stream and silently truncating the authoritative history (H10).
    private static func fetchSessionPage(
        engine: OpaquePointer,
        sessionID: String,
        afterSeq: Int64,
        limit: Int64
    ) -> [BASEventLogEntry]? {
        let bytes = Array(sessionID.utf8)
        func call(_ oBuf: UnsafeMutableBufferPointer<UInt8>?) -> Int32 {
            bytes.withUnsafeBufferPointer { kBuf in
                bas_l8_event_log_events_for_session_page(
                    engine,
                    kBuf.baseAddress.map {
                        UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)
                    },
                    kBuf.count,
                    afterSeq, limit,
                    oBuf?.baseAddress, oBuf?.count ?? 0)
            }
        }
        let needed = call(nil)
        // A valid JSON array is at least "[]" (2 bytes). needed < 2 (incl. negative FFI
        // codes) is a read error, NOT an empty page.
        guard needed >= 2 else { return nil }
        var buf = [UInt8](repeating: 0, count: Int(needed))
        let written = buf.withUnsafeMutableBufferPointer { call($0) }
        guard written >= 2 else { return nil }
        // Decode failure of a non-empty buffer is a real error (schema drift / corruption),
        // never an empty page — must be `nil` so the caller fails closed.
        return try? JSONDecoder().decode(
            [BASEventLogEntry].self,
            from: Data(buf.prefix(Int(written))))
    }
}
#endif
