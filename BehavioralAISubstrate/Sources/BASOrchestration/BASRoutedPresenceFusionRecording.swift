// MARK: - BASRoutedPresenceFusionRecording
// chapter 七百九十八 / M2641-M2645 — L6 fusion recording activation
//
// Opt-in side-channel that pairs the production-default
// `BASRoutedPresenceFusion.fuse(observations:)` with persistent
// observation records via a host-supplied
// `BASPresenceObservationStore` (chapter 七百九十五)。
//
// ## Why a separate file
//
// `BASRoutedPresenceFusion.fuse(...)` (chapter 七百八十) is a
// pure (sync) function — STRONG-FLIP measured at 7.51× speedup
// over Swift inline。 Adding a host-supplied store to that hot
// path would force every caller into async + carry an optional
// dependency unrelated to the math。 Instead this file vends a
// NEW `fuseAndRecord(...)` async overload that hosts opt into
// EXPLICITLY when they want observation persistence。
//
// 「依旧 不删除 只 comment」 — the original `fuse(...)` keeps
// being the live default and is NOT modified by this file。
// Activation is purely additive。 ADR-014 OPT-IN preserved。
//
// ## Channel byte ↔ kind name mapping
//
// `BASChannelObservationInput.channelByte` is a UInt8 (0..4)
// matching the Rust `PresenceChannel` discriminant。 The L6
// store uses the schema-013 CHECK string ("task" / "risk" /
// "manipulation" / "environment" / "bodyRhythm")。 The mapper
// below pins the two encodings so flips don't silently corrupt
// the audit trail。

import Foundation
import BASSovereign

extension BASRoutedPresenceFusion {

    // MARK: - Channel byte ↔ schema-013 string mapping

    /// Schema-013 channel_kind strings indexed by the Rust
    /// `PresenceChannel` byte discriminant。 PUBLIC for hosts that
    /// build their own observation records ad-hoc。
    public static let channelKindByByte: [String] = [
        "task",          // 0
        "risk",          // 1
        "manipulation",  // 2
        "environment",   // 3
        "bodyRhythm",    // 4
    ]

    /// Translate a channel byte to the schema-013 CHECK string。
    /// Returns nil for out-of-range bytes (caller's responsibility
    /// to filter — same contract as `BASRoutedPresenceFusion.fuse`)。
    public static func channelKind(forByte byte: UInt8) -> String? {
        let idx = Int(byte)
        guard idx < channelKindByByte.count else { return nil }
        return channelKindByByte[idx]
    }

    // MARK: - fuseAndRecord opt-in seam

    /// One-pass fuse + record。 Calls the existing production-
    /// default `fuse(observations:)` for the math AND appends
    /// one `BASPresenceObservationRecord` per input observation
    /// to the host-supplied store。
    ///
    /// - Parameters:
    ///   - observations: same inputs the pure `fuse(...)` accepts
    ///   - sessionID: schema-013 session_id column
    ///   - turnID: schema-013 turn_id column
    ///   - store: any conformer of `BASPresenceObservationStore`
    ///   - eventIDPrefix: unique-per-call prefix (caller supplies
    ///     to avoid PK collisions across batches)
    ///   - nowMs: epoch ms timestamp written to observed_at_ms
    ///
    /// - Returns: the fused [0, 1] confidence (identical to what
    ///   `fuse(observations:)` returns for the same input — no
    ///   behavior change to the math path)
    ///
    /// - Throws: if the store rejects any record (e.g。 duplicate
    ///   eventID — caller must ensure `eventIDPrefix` is unique)
    ///
    /// Observations with out-of-range `channelByte` are SKIPPED
    /// for recording but STILL counted in the fusion (matches
    /// the existing fuse(...) contract — it filters out-of-range
    /// internally as well)。
    public static func fuseAndRecord(
        observations: [BASChannelObservationInput],
        sessionID: String,
        turnID: String,
        store: BASPresenceObservationStore,
        eventIDPrefix: String,
        nowMs: Int64
    ) async throws -> Double {
        // Compute the fused value FIRST so a store-side failure
        // doesn't corrupt the math contract。 Same value the
        // production-default fuse(...) returns。
        let fused = fuse(observations: observations)
        // Append records in input order with stable index-suffixed
        // event IDs。 Each record carries the same observed_at_ms
        // because they share the same fusion-call timestamp。
        //
        // chapter 八百二十四 review note:the index suffix here
        // encodes the ORIGINAL input position (not the persisted
        // position)。 Out-of-range observations leave GAPS in the
        // suffix sequence — that's the deliberate「traceability」
        // contract pinned by chapter 798's
        // testFuseAndRecordSkipsOutOfRangeChannelByte (the
        // recovered eventIDs are `[ev-skip-0, ev-skip-2]` for an
        // input `[valid, invalid, valid]`)。 The 严查 review
        // agent flagged a「collision risk」 that on closer
        // inspection does NOT exist:hosts who reuse the same
        // `eventIDPrefix` across calls collide on the SAME
        // suffix (e.g。 two calls with `[valid]` both write
        // `prefix-0`),which surfaces as the store's
        // `duplicateEventID` throw — exactly the documented
        // contract。 Hosts must use a unique prefix per call
        // (e.g。 `"p-turn-\(turnID)"` or UUID-based)。
        for (idx, obs) in observations.enumerated() {
            guard let kind = channelKind(forByte: obs.channelByte)
            else { continue }
            let record = BASPresenceObservationRecord(
                eventID: "\(eventIDPrefix)-\(idx)",
                sessionID: sessionID,
                turnID: turnID,
                channelKind: kind,
                salience: obs.salience,
                confidence: obs.confidence,
                observedAtMs: nowMs)
            _ = try await store.appendRecord(record)
        }
        return fused
    }

    // MARK: - Replay helper (chapter 八百九)

    /// Map a `BASPresenceObservationRecord` back into the
    /// `BASChannelObservationInput` runtime form。 Closes the
    /// recording loop for hosts that want to resume presence
    /// state on cold start。 Returns nil for records whose
    /// `channelKind` doesn't match any schema-013 CHECK literal
    /// (defensive — should not happen for valid persisted rows)。
    public static func observationInput(
        from record: BASPresenceObservationRecord
    ) -> BASChannelObservationInput? {
        guard let byte = channelByte(forKind: record.channelKind)
        else { return nil }
        return BASChannelObservationInput(
            channelByte: byte,
            salience: record.salience,
            confidence: record.confidence)
    }

    /// Inverse of `channelKind(forByte:)` — schema-013 string →
    /// Rust `PresenceChannel` byte。 Returns nil for unrecognized
    /// strings。 Linear scan since there are only 5 entries。
    public static func channelByte(forKind kind: String) -> UInt8? {
        for (idx, k) in channelKindByByte.enumerated()
            where k == kind {
            return UInt8(idx)
        }
        return nil
    }
}
