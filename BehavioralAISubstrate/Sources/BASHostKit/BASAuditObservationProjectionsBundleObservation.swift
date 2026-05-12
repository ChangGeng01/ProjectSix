// MARK: - BASAuditObservationProjectionsBundleObservation
// chapter 五百十二 / M1425 — wire-in chain start for projection
//                            blocks
//
// Per-turn observation record capturing the chapter 511
// Kunlun + Cthulhu input blocks that fed
// `BASAuditObservationProjections` at audit-emission time。
//
// ## Why this exists
//
// Chapter 511 shipped 2 typed packaging blocks
// (`BASAuditObservationProjectionsKunlunInputs` +
// `BASAuditObservationProjectionsCthulhuInputs`)。 They
// flow per-turn into projections but no record of WHICH
// blocks fired,how many trio fields were live,or which
// turns had partial coverage exists today。
//
// This observation record closes that audit-replay seam:
//
//   - Captures turnID + sessionID (every audit emission
//     keys by these)
//   - References the Kunlun + Cthulhu input blocks via
//     value-typed copies (Hashable + Sendable means
//     replay can compare hashes directly)
//   - Records whether each block was actually populated
//     (audit walkers can grep for "kunlunCovered=false"
//     to find turns where projection emission ran cold)
//   - Pairs with a timestamp so cross-turn aggregation
//     orders correctly during replay
//
// ## Doctrine pins
//
//   - 不变量 #3:replay-deterministic — Codable + Sendable
//     + Hashable
//   - chapter 三百九二:1e-4 IEEE Float32 tolerance does
//     not apply (no Float fields)
//   - 红线 7:additive surface only — old projections
//     emission path unchanged
//   - chapter 四百二十九:typed-surface count 55 → 56
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1424 → M1425

import Foundation
import BASRuntimeCore

/// Per-turn observation of the chapter 511 projection
/// input blocks that drove the audit projections。 Hosts
/// emit ONE record per audit-projection emission;the
/// chapter 512 actor accumulator aggregates them into a
/// typed BASBundle for multi-turn replay。
public struct BASAuditObservationProjectionsBundleObservation:
    Hashable, Sendable, Codable
{

    // MARK: - Identity

    /// Turn that produced this projection emission。
    public let turnID: String

    /// Session the turn belongs to。
    public let sessionID: String

    /// Audit emission timestamp,UTC seconds since epoch。
    /// Stable in test fixtures via injected `Date` value;
    /// callers MUST pass deterministic dates for replay。
    public let emittedAt: Date

    // MARK: - Block coverage

    /// True when a `BASAuditObservationProjectionsKunlun
    /// Inputs` block was the source of the 18 Kunlun
    /// fields。 False when the projections init was called
    /// via the all-fields path (host bypass) — audit
    /// walkers can grep for `kunlunCovered=false` to find
    /// non-block paths。
    public let kunlunCovered: Bool

    /// True when a `BASAuditObservationProjectionsCthulhu
    /// Inputs` block was the source of the 8 Cthulhu
    /// fields。 Same semantics as `kunlunCovered`。
    public let cthulhuCovered: Bool

    // MARK: - Coverage fingerprint

    /// Hashable + Sendable digest of the Kunlun inputs
    /// block when `kunlunCovered`,nil otherwise。 Audit
    /// walkers comparing replays use this digest to
    /// detect drift across two runs of the same fixture。
    public let kunlunInputsHash: Int?

    /// Hashable + Sendable digest of the Cthulhu inputs
    /// block when `cthulhuCovered`,nil otherwise。
    public let cthulhuInputsHash: Int?

    // MARK: - Construction

    public init(
        turnID: String,
        sessionID: String,
        emittedAt: Date,
        kunlunCovered: Bool,
        cthulhuCovered: Bool,
        kunlunInputsHash: Int?,
        cthulhuInputsHash: Int?
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.emittedAt = emittedAt
        self.kunlunCovered = kunlunCovered
        self.cthulhuCovered = cthulhuCovered
        self.kunlunInputsHash = kunlunInputsHash
        self.cthulhuInputsHash = cthulhuInputsHash
    }

    // MARK: - Convenience factory

    /// Build a fully-covered observation from both
    /// blocks。 Uses each block's `hashValue` as the
    /// digest field — Hashable conformance guarantees
    /// stable across same-input invocations within a
    /// process。
    public static func fullyCovered(
        turnID: String,
        sessionID: String,
        emittedAt: Date,
        kunlunInputs:
            BASAuditObservationProjectionsKunlunInputs,
        cthulhuInputs:
            BASAuditObservationProjectionsCthulhuInputs
    ) -> BASAuditObservationProjectionsBundleObservation {
        return BASAuditObservationProjectionsBundleObservation(
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: emittedAt,
            kunlunCovered: true,
            cthulhuCovered: true,
            kunlunInputsHash: kunlunInputs.hashValue,
            cthulhuInputsHash: cthulhuInputs.hashValue)
    }

    /// Build a Kunlun-only observation (host did not use
    /// the Cthulhu convenience init this turn)。
    public static func kunlunOnly(
        turnID: String,
        sessionID: String,
        emittedAt: Date,
        kunlunInputs:
            BASAuditObservationProjectionsKunlunInputs
    ) -> BASAuditObservationProjectionsBundleObservation {
        return BASAuditObservationProjectionsBundleObservation(
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: emittedAt,
            kunlunCovered: true,
            cthulhuCovered: false,
            kunlunInputsHash: kunlunInputs.hashValue,
            cthulhuInputsHash: nil)
    }

    /// Build a Cthulhu-only observation (host did not use
    /// the Kunlun convenience init this turn)。
    public static func cthulhuOnly(
        turnID: String,
        sessionID: String,
        emittedAt: Date,
        cthulhuInputs:
            BASAuditObservationProjectionsCthulhuInputs
    ) -> BASAuditObservationProjectionsBundleObservation {
        return BASAuditObservationProjectionsBundleObservation(
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: emittedAt,
            kunlunCovered: false,
            cthulhuCovered: true,
            kunlunInputsHash: nil,
            cthulhuInputsHash: cthulhuInputs.hashValue)
    }

    /// Build a no-coverage observation (host used the
    /// all-fields init,no blocks fired)。 Useful for
    /// audit-walker queries that want to count cold
    /// turns。
    public static func uncovered(
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASAuditObservationProjectionsBundleObservation {
        return BASAuditObservationProjectionsBundleObservation(
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: emittedAt,
            kunlunCovered: false,
            cthulhuCovered: false,
            kunlunInputsHash: nil,
            cthulhuInputsHash: nil)
    }

    // MARK: - Coverage queries

    /// True when both Kunlun and Cthulhu blocks covered
    /// this turn's emission。
    public var hasBothBlocks: Bool {
        kunlunCovered && cthulhuCovered
    }

    /// True when neither block fired — host bypassed both
    /// convenience inits。
    public var hasNoBlocks: Bool {
        !kunlunCovered && !cthulhuCovered
    }

    /// Count of populated block hashes (0,1,or 2)。
    public var populatedBlockCount: Int {
        var n = 0
        if kunlunCovered { n += 1 }
        if cthulhuCovered { n += 1 }
        return n
    }
}
