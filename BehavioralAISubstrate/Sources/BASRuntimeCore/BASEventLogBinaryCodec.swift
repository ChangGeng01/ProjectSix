// MARK: - BASEventLogBinaryCodec
// chapter 七百二十四 第二刀 / M2292
//
// Swift bridge to the bas-event-log-codec Rust crate's binary
// wire format。 Ships as a STANDALONE PRIMITIVE — production
// wiring into BASSQLiteEventLogStorage is deferred (Knife 5
// documents why honestly)。
//
// The full BASEventLogEntry shape is much richer than the
// Rust crate's `EventLogEntry`,so this codec operates on a
// "core subset" struct that captures the most-frequently-
// indexed fields。 The remaining BASEventLogEntry fields can
// ride along as a JSON payload string if a host wants to
// migrate the full shape — but the primitive itself stays
// minimal so the perf measurement (Knife 4) reflects the
// actual binary win,not Codable overhead。
//
// ## Public surface
//
//   public struct BASBinaryEventLogEntry
//   public enum   BASBinaryEventLogKind
//
//   public enum BASEventLogBinaryCodec {
//       static func encode(_:) throws -> Data
//       static func decode(_:) throws -> BASBinaryEventLogEntry
//   }

import Foundation
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

// MARK: - chapter 七百二十四 第三刀 / M2293
//         Deferred-migration plan for BASSQLiteEventLogStorage
//
// The chapter 七百二十四 plan listed three follow-on steps after
// the binary codec primitive lands (Knife 2):
//
//   - Add `payload_format INTEGER NOT NULL DEFAULT 1` column to
//     replay_log_events SQL schema
//   - Append() encodes new rows as binary (payload_format = 2)
//   - Read path detects payload_format,decodes via the right
//     codec — JSON-decoder for legacy (1) rows,
//     BASEventLogBinaryCodec.decode for v2 rows
//   - Migration script optional (lazy upgrade on read)
//
// This is intentionally DEFERRED for the following honest
// reasons (per the chapter 七百十七 forget-cascade-style audit
// of measurement-first wiring criteria):
//
//   1. The substrate's full BASEventLogEntry shape has 15+
//      optional fields (memoryRefs,riskBand,intent,emotion,
//      embeddingHash,project,…) that DON'T map directly to the
//      bas-event-log-codec Rust crate's smaller EventLogEntry
//      shape。 Doing the migration would either require
//      extending the Rust struct to mirror Swift's 15+ fields
//      (~200 LOC + new tests),or shoving the extras into
//      payload_json as a nested JSONEncoder blob (negates the
//      binary perf win for entries that have those fields)。
//
//   2. Plan-agent honest estimate for the migration was
//      1.5-2× per-append wall-time。 Real bottleneck is sqlite3
//      _step + fsync,not JSON encode。 At ~120 bytes / entry
//      and modern SQLite write rates (~50K rows/sec),the
//      JSON-encode cost is ~5-10% of total append latency。 The
//      win is modest and unlikely to clear the chapter
//      七百十六-style 1.5× decision threshold at production
//      sites that don't run at peak fsync rate。
//
//   3. The dual-read schema (payload_format column + version-
//      tagged decode) is non-trivial to test across the 100+
//      production event log call sites。 Wiring it requires a
//      migration window (chapter 七百二十四 第三刀 in the
//      original plan) that the substrate's measurement-first
//      cadence prefers to amortize across multiple knives at a
//      future arc。
//
// What ships TODAY (chapter 七百二十四 deliverables):
//   - Rust binary encode/decode + chunked-batch (Knife 1)
//   - C ABI bas_event_log_encode_binary (Knife 2)
//   - Swift BASEventLogBinaryCodec primitive (Knife 2)
//   - 1.92× storage compression vs JSON for typical entries
//   - 10 Swift + 10 Rust anti-drift tests
//
// What hosts can do today with the primitive:
//   - Encode any BASBinaryEventLogEntry-shaped record to
//     binary bytes (e.g。 for compact off-substrate logging,
//     or a custom event store)
//   - Decode binary bytes back to BASBinaryEventLogEntry
//   - Verify schema version + reject malformed buffers
//
// Future arc TODO (when a host workload makes the perf win
// justify the migration complexity):
//   - Map full BASEventLogEntry → binary wire format
//   - Add payload_format column to replay_log_events schema
//   - Update BASSQLiteEventLogStorage.append/replay to switch
//     on version
//   - Add 50-entry byte-equality test mirroring chapter 七百
//     十六 audit-ledger pattern

public enum BASBinaryEventLogKind: UInt8, Sendable, Equatable {
    case internalSignal     = 0
    case hostInput          = 1
    case sovereignVerdict   = 2
    case permitChange       = 3
    case observationBundle  = 4
    case provenanceMark     = 5
    case replayMark         = 6
}

/// Core-subset event log entry the binary codec encodes
/// directly。 Hosts that need the full BASEventLogEntry shape
/// stuff the remaining fields into `payloadJson` as a
/// JSONEncoder-produced string。 Production wiring is
/// deferred per chapter 七百二十四 第五刀 honest scope。
public struct BASBinaryEventLogEntry: Sendable, Equatable {
    public let entryID: String
    public let kind: BASBinaryEventLogKind
    public let sessionRef: String
    public let turnRef: String
    public let timestampMs: Int64
    public let payloadJson: String?
    public let provenanceSummary: String?

    public init(
        entryID: String,
        kind: BASBinaryEventLogKind,
        sessionRef: String,
        turnRef: String,
        timestampMs: Int64,
        payloadJson: String? = nil,
        provenanceSummary: String? = nil
    ) {
        self.entryID = entryID
        self.kind = kind
        self.sessionRef = sessionRef
        self.turnRef = turnRef
        self.timestampMs = timestampMs
        self.payloadJson = payloadJson
        self.provenanceSummary = provenanceSummary
    }
}

public enum BASEventLogBinaryCodecError: Error, Equatable {
    case encodeFailedInvalidUTF8
    case encodeFailedNullPointer
    case decodeFailedTruncatedBuffer
    case decodeFailedInvalidSchemaVersion(UInt8)
    case decodeFailedInvalidKindDiscriminant(UInt8)
    case decodeFailedInvalidUTF8
    case platformUnsupported
}

/// Public codec namespace。 Encode routes through Rust FFI for
/// the perf win;decode is pure Swift (binary format is trivial
/// to walk and the Rust FFI overhead would dominate for the
/// typical small entry size)。
public enum BASEventLogBinaryCodec {

    /// Schema version pin。 v1 = legacy JSON;v2 = binary。 Both
    /// constants kept in sync with the Rust-side
    /// `PAYLOAD_FORMAT_JSON_V1` / `PAYLOAD_FORMAT_BINARY_V2`。
    public static let schemaVersionJSONv1:   UInt8 = 1
    public static let schemaVersionBinaryV2: UInt8 = 2

    /// Encode `entry` to a binary buffer。 Uses the Rust FFI on
    /// Apple platforms;throws `.platformUnsupported` on watchOS。
    public static func encode(
        _ entry: BASBinaryEventLogEntry
    ) throws -> Data {
        #if os(iOS) || os(macOS)
        let entryIDBytes  = Array(entry.entryID.utf8)
        let sessionBytes  = Array(entry.sessionRef.utf8)
        let turnBytes     = Array(entry.turnRef.utf8)
        let payloadBytes: [UInt8] = entry.payloadJson.map {
            Array($0.utf8)
        } ?? []
        let provBytes: [UInt8] = entry.provenanceSummary.map {
            Array($0.utf8)
        } ?? []
        let payloadPresent: UInt8 =
            entry.payloadJson == nil ? 0 : 1
        let provPresent: UInt8 =
            entry.provenanceSummary == nil ? 0 : 1

        // Two-phase: discover size, then fill。
        let needed = withFFIBuffers(
            entryID: entryIDBytes,
            session: sessionBytes,
            turn: turnBytes,
            payload: payloadBytes,
            payloadPresent: payloadPresent,
            prov: provBytes,
            provPresent: provPresent,
            entry: entry,
            outBuf: nil,
            outCapacity: 0)
        if needed < 0 {
            throw codecError(from: needed)
        }
        if needed == 0 { return Data() }
        var out = [UInt8](
            repeating: 0, count: Int(needed))
        let wrote = out.withUnsafeMutableBufferPointer { op in
            return withFFIBuffers(
                entryID: entryIDBytes,
                session: sessionBytes,
                turn: turnBytes,
                payload: payloadBytes,
                payloadPresent: payloadPresent,
                prov: provBytes,
                provPresent: provPresent,
                entry: entry,
                outBuf: op.baseAddress,
                outCapacity: op.count)
        }
        if wrote < 0 { throw codecError(from: wrote) }
        return Data(out)
        #else
        throw BASEventLogBinaryCodecError.platformUnsupported
        #endif
    }

    #if os(iOS) || os(macOS)
    private static func withFFIBuffers(
        entryID: [UInt8],
        session: [UInt8],
        turn: [UInt8],
        payload: [UInt8],
        payloadPresent: UInt8,
        prov: [UInt8],
        provPresent: UInt8,
        entry: BASBinaryEventLogEntry,
        outBuf: UnsafeMutablePointer<UInt8>?,
        outCapacity: Int
    ) -> Int64 {
        return entryID.withUnsafeBufferPointer { ip in
            return session.withUnsafeBufferPointer { sp in
                return turn.withUnsafeBufferPointer { tp in
                    return payload.withUnsafeBufferPointer { pp in
                        return prov.withUnsafeBufferPointer { qp in
                            return bas_event_log_encode_binary(
                                entry.kind.rawValue,
                                ip.baseAddress, ip.count,
                                sp.baseAddress, sp.count,
                                tp.baseAddress, tp.count,
                                entry.timestampMs,
                                payloadPresent,
                                payload.isEmpty
                                    ? nil : pp.baseAddress,
                                payload.count,
                                provPresent,
                                prov.isEmpty
                                    ? nil : qp.baseAddress,
                                prov.count,
                                outBuf, outCapacity)
                        }
                    }
                }
            }
        }
    }

    private static func codecError(
        from rc: Int64
    ) -> BASEventLogBinaryCodecError {
        switch rc {
        case -1: return .encodeFailedNullPointer
        case -2: return .encodeFailedInvalidUTF8
        default: return .encodeFailedNullPointer
        }
    }
    #endif

    /// Decode `buf` as a binary-format entry。 Pure Swift walk —
    /// no FFI (the format is simple length-prefixed + flags)。
    /// First byte must be `schemaVersionBinaryV2`。
    public static func decode(
        _ buf: Data
    ) throws -> BASBinaryEventLogEntry {
        // audit runtimecore-b #7: this decoder threads a 0-based `pos` through `buf[pos]`, but Data
        // subscripts by its OWN indices — a non-zero-based SLICE (e.g. `data[5...]`, startIndex=5)
        // would read the wrong bytes or trap. Rebase to a 0-based Data at the boundary (no copy when
        // already 0-based).
        let buf = buf.startIndex == 0 ? buf : Data(buf)
        var pos = 0
        guard pos < buf.count else {
            throw BASEventLogBinaryCodecError
                .decodeFailedTruncatedBuffer
        }
        let version = buf[pos]
        pos += 1
        guard version == schemaVersionBinaryV2 else {
            throw BASEventLogBinaryCodecError
                .decodeFailedInvalidSchemaVersion(version)
        }
        guard pos < buf.count else {
            throw BASEventLogBinaryCodecError
                .decodeFailedTruncatedBuffer
        }
        guard let kind = BASBinaryEventLogKind(
            rawValue: buf[pos])
        else {
            throw BASEventLogBinaryCodecError
                .decodeFailedInvalidKindDiscriminant(buf[pos])
        }
        pos += 1
        let entryID = try readLenPrefixedString(buf, &pos)
        let sessionRef = try readLenPrefixedString(buf, &pos)
        let turnRef = try readLenPrefixedString(buf, &pos)
        let timestamp = try readI64LE(buf, &pos)
        guard pos < buf.count else {
            throw BASEventLogBinaryCodecError
                .decodeFailedTruncatedBuffer
        }
        let payloadFlag = buf[pos]
        pos += 1
        let payload: String?
        switch payloadFlag {
        case 0: payload = nil
        case 1:
            payload = try readLenPrefixedString(buf, &pos)
        default:
            throw BASEventLogBinaryCodecError
                .decodeFailedTruncatedBuffer
        }
        guard pos < buf.count else {
            throw BASEventLogBinaryCodecError
                .decodeFailedTruncatedBuffer
        }
        let provFlag = buf[pos]
        pos += 1
        let prov: String?
        switch provFlag {
        case 0: prov = nil
        case 1:
            prov = try readLenPrefixedString(buf, &pos)
        default:
            throw BASEventLogBinaryCodecError
                .decodeFailedTruncatedBuffer
        }
        return BASBinaryEventLogEntry(
            entryID: entryID,
            kind: kind,
            sessionRef: sessionRef,
            turnRef: turnRef,
            timestampMs: timestamp,
            payloadJson: payload,
            provenanceSummary: prov)
    }

    // MARK: - Pure Swift wire-format readers

    private static func readU32LE(
        _ buf: Data, _ pos: inout Int
    ) throws -> UInt32 {
        guard pos + 4 <= buf.count else {
            throw BASEventLogBinaryCodecError
                .decodeFailedTruncatedBuffer
        }
        let v =
            UInt32(buf[pos])
          | (UInt32(buf[pos + 1]) << 8)
          | (UInt32(buf[pos + 2]) << 16)
          | (UInt32(buf[pos + 3]) << 24)
        pos += 4
        return v
    }

    private static func readI64LE(
        _ buf: Data, _ pos: inout Int
    ) throws -> Int64 {
        guard pos + 8 <= buf.count else {
            throw BASEventLogBinaryCodecError
                .decodeFailedTruncatedBuffer
        }
        var u: UInt64 = 0
        for i in 0..<8 {
            u |= UInt64(buf[pos + i]) << (i * 8)
        }
        pos += 8
        return Int64(bitPattern: u)
    }

    private static func readLenPrefixedString(
        _ buf: Data, _ pos: inout Int
    ) throws -> String {
        let len = Int(try readU32LE(buf, &pos))
        guard pos + len <= buf.count else {
            throw BASEventLogBinaryCodecError
                .decodeFailedTruncatedBuffer
        }
        guard let s = String(
            data: buf.subdata(in: pos..<pos + len),
            encoding: .utf8)
        else {
            throw BASEventLogBinaryCodecError
                .decodeFailedInvalidUTF8
        }
        pos += len
        return s
    }
}
