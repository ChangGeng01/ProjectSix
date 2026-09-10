// MARK: - BASObservationItem + BASObservationDerivable
// chapter 四百二十九 / M1089 — RADICAL EVOLUTION SWEEP Phase C
//
// Two protocols that name the canonical shape the
// substrate's 24 observation files keep reinventing:
// "given a turn-scoped input,derive a typed observation
// item with provenance"。
//
// ## Why this exists (system entropy framing)
//
// The 2026-04-26 audit identified ~24 observation
// derivation files (~800-1,000 LOC each) following
// nearly the same pattern:
//
//   1. Take typed input (frame / bundle / context)
//   2. Compute deterministic typed observation
//   3. Stamp with provenance (sourceID + derivedAtMs)
//   4. Return inside an envelope
//
// Each file ships its own protocol-or-no-protocol
// permutation,its own provenance fields,its own
// envelope shape。 The 5 audit `*Derivation` files
// inspected (BASUpdateTicketObservationDerivation,
// BASRiskCardObservationDerivation,etc.) duplicate
// 80% of the structure。
//
// `BASObservationItem` + `BASObservationDerivable` are
// the two protocols that name the canonical shape so
// future observation files can converge instead of
// diverge。 Existing files are NOT migrated at M1089
// (would touch 800+ LOC across 24 files);migration is
// per-domain opt-in under explicit user control。
//
// ## What this ships (M1089)
//
//   - `BASObservationItem` protocol — typed observation
//     payload with provenance + deterministic ID
//   - `BASObservationDerivable` protocol — pure
//     derivation function from typed input → typed
//     observation
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     protocols + named provenance fields)
//   - chapter 二百一一 — single source-of-truth (one
//     observation shape future code converges to)
//   - chapter 三百九二 — replay-determinism (protocol
//     constrains observationID derivation to be a pure
//     function of payload + sourceID for byte-stable
//     replay)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (purely additive protocols;no migration of
//     existing types)
//   - 红线 7 — hint-only (observations are observation
//     plumbing,not commitment authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation

// MARK: - BASObservationItem

/// Typed observation item:Sendable + Codable payload
/// with provenance + deterministic ID。 Conformers
/// represent a single observation derived from some
/// turn-scoped input。
///
/// Conformance contract:
///   - `observationID` MUST be deterministic given the
///     same `sourceID` + the encoded payload bytes
///     (chapter 三百九二 replay-determinism)
///   - `derivedAtMs` MUST be wall-clock at derivation
///     time (recorded for chronological replay,not for
///     determinism)
///   - `sourceID` MUST identify the input that produced
///     this observation (turn ID,frame ID,etc.)
public protocol BASObservationItem:
    Equatable, Hashable, Codable, Sendable
{

    /// Stable observation ID — deterministic per
    /// (sourceID,payload) pair。 Implementations
    /// typically derive via SHA256-prefix of
    /// sortedKeys-JSON encoding。
    var observationID: String { get }

    /// Wall-clock timestamp the observation was
    /// derived,milliseconds since UNIX epoch。
    var derivedAtMs: Int64 { get }

    /// Logical source identifier this observation was
    /// derived from (e.g. "turn-A:risk-card",
    /// "turn-A:context-frame")。
    var sourceID: String { get }
}

// MARK: - BASObservationDerivable

/// Pure derivation function from typed input to typed
/// observation item。 Conformers describe deterministic
/// derivation rules — same input produces same output
/// (chapter 三百九二)。
///
/// Conformance contract:
///   - `derive(from:atMs:)` MUST be a pure function:
///     same `Input` + same `atMs` (when ID-deterministic
///     paths use it) produce same `Observation`
///   - The returned observation's `derivedAtMs` MUST
///     equal the `atMs` parameter (caller controls the
///     timestamp for replay-determinism)
///   - The returned observation's `sourceID` MUST be
///     derivable from the `Input` alone (not random)
public protocol BASObservationDerivable: Sendable {

    /// Typed input shape this conformer derives from。
    associatedtype Input: Sendable

    /// Typed observation shape this conformer produces。
    associatedtype Observation: BASObservationItem

    /// Pure derivation entry point。 Called by the
    /// substrate's observation-collection harness with
    /// the wall-clock timestamp the harness wants the
    /// observation stamped with。
    func derive(
        from input: Input,
        atMs: Int64
    ) -> Observation
}

// MARK: - Convenience derivation helpers

extension BASObservationDerivable {

    /// Convenience that uses the current system clock
    /// for the timestamp。 Tests + replay paths SHOULD
    /// use the explicit `atMs:` form instead。
    public func deriveAtCurrentTime(
        from input: Input
    ) -> Observation {
        let nowMs = Int64(
            Date().timeIntervalSince1970 * 1000)
        return derive(from: input, atMs: nowMs)
    }
}
