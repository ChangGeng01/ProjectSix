// MARK: - BASEBrainTurnResultReplayDigest — Step 1 (byte-equal replay safety net)
//
// A stable identity hash for ONE full `BASEBrainTurnResult`, used by
// `BASEBrainTurnResultReplayHarness` to prove byte-equality across re-runs / Codable
// round-trips / V1-vs-runWithPlan parity.
//
// Algorithm `ebrain-turn-result-json-sha256-sortedKeys-utf8`:
//   1. (optional, default ON) canonicalize via `BASEBrainTurnResultReplayCanonicalizer`
//      (pin the observation-clock fields that legitimately drift)
//   2. `JSONEncoder` with `.sortedKeys` (deterministic key order at every nesting level)
//   3. UTF-8 encode
//   4. SHA256 (CryptoKit)
//   5. lowercase hex via `BASAutoRouteRanker.bytesToHexLower`
//
// Mirrors `BASRuntimeAuditEmissionSummaryDigest` (which digests the ~10-field SUMMARY); this
// digests the FULL ~55-field result — closing the gap that the summary-digest stress sweep left
// open. chapter 二百一一 single-source-of-truth for full-result digest derivation;
// chapter 三百九二 deterministic (same canonicalized result → same digest). ADR-014 — additive.

import Foundation
import CryptoKit
import BASRuntimeCore

public struct BASEBrainTurnResultReplayDigest:
    Codable, Equatable, Sendable, Hashable
{
    /// Algorithm name producing the digest. Pinned so future migrations to a different
    /// hashing surface are detectable via raw-value compare.
    public let algorithmName: String

    /// The digest payload (lowercase hex of the SHA256).
    public let digestString: String

    /// Wall-clock timestamp the digest was produced. Metadata only — NOT part of the hash,
    /// so it never affects byte-equality comparisons.
    public let producedAt: Date

    public init(
        algorithmName: String,
        digestString: String,
        producedAt: Date
    ) {
        self.algorithmName = algorithmName
        self.digestString = digestString
        self.producedAt = producedAt
    }

    /// Pinned algorithm identifier. chapter 一百八十五 — bumping this raw value requires an
    /// explicit audit migration.
    public static let algorithmRawName: String =
        "ebrain-turn-result-json-sha256-sortedKeys-utf8"

    /// Empty digest placeholder (used defensively if encoding fails — should never happen for
    /// the typed Codable result).
    public static func empty(
        producedAt: Date
    ) -> BASEBrainTurnResultReplayDigest {
        BASEBrainTurnResultReplayDigest(
            algorithmName: "", digestString: "", producedAt: producedAt)
    }

    /// Build a digest from a full turn result. Pure; same (canonicalized) result → same digest.
    ///
    /// - Parameter canonicalize: when `true` (default) the observation-clock drift fields are
    ///   pinned first so the digest is replay-stable. Pass `false` for the raw-bytes /
    ///   negative-control path (which deliberately surfaces the drift).
    public static func from(
        result: BASEBrainTurnResult,
        producedAt: Date,
        canonicalize: Bool = true
    ) -> BASEBrainTurnResultReplayDigest {
        let subject = canonicalize
            ? BASEBrainTurnResultReplayCanonicalizer.canonicalized(result)
            : result
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(subject) else {
            return .empty(producedAt: producedAt)
        }
        let hash = SHA256.hash(data: data)
        let hex = BASAutoRouteRanker.bytesToHexLower(Array(hash))
        return BASEBrainTurnResultReplayDigest(
            algorithmName: algorithmRawName,
            digestString: hex,
            producedAt: producedAt)
    }
}
