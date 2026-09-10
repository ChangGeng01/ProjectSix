// MARK: - BASRuntimeAuditEmissionSummaryDigest+FromSummary — chapter 四百二十 / M1051
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百二十 second cut:typed factory
// `.from(summary:producedAt:)` producing a digest from a
// BASRuntimeAuditEmissionSummary via SHA256 over the
// payloadJson()。 Future V1↔V2 stress sweep harnesses
// compare digests for byte-equality verification。
//
// ## Why this exists (system entropy framing)
//
// M1050 ships the typed digest value type but no factory
// that produces it from a summary instance。 Without this
// factory,every consumer would call payloadJson() and
// SHA256 inline → scattered "digest-derivation entropy"。
//
// `.from(summary:producedAt:)` ships the pure-function
// factory using `json-sha256-sortedKeys-utf8` algorithm:
//
//   1. Render the summary via payloadJson() (already
//      sorted-keys per M967 chapter 三百九二 anchor)
//   2. UTF-8 encode the JSON string
//   3. SHA256 hash the bytes via CryptoKit
//   4. Hex-encode the digest
//
// ## What this ships (M1051)
//
//   - `BASRuntimeAuditEmissionSummaryDigest.from(summary:
//     producedAt:)` static factory using SHA256
//   - `algorithmRawName: String` constant pin for the
//     algorithm identifier
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十九/四百二十 doctrine pins
//   - chapter 一百八十五 — typed factory + algorithm constant
//   - chapter 二百一一 — single source-of-truth for digest
//     derivation
//   - chapter 三百九二 — deterministic (sorted-key JSON +
//     SHA256 produces byte-stable digest for same input)
//   - ADR-014 OPT-IN — purely additive

import Foundation
import CryptoKit
import BASRuntimeCore

extension BASRuntimeAuditEmissionSummaryDigest {

    /// Pinned algorithm identifier for the SHA256-over-
    /// sorted-key-JSON digest produced by `.from(...)`。
    /// chapter 一百八十五:bumping this raw value requires
    /// explicit audit migration。
    public static let algorithmRawName: String =
        "json-sha256-sortedKeys-utf8"

    /// Build a typed digest from the given summary。 Pure;
    /// same summary + same producedAt → same digest (chapter
    /// 三百九二)。 Returns an empty digest when payloadJson
    /// encoding fails (defensive — should never happen for
    /// the typed Codable summary)。
    public static func from(
        summary: BASRuntimeAuditEmissionSummary,
        producedAt: Date
    ) -> BASRuntimeAuditEmissionSummaryDigest {
        guard let payload = summary.payloadJson(),
              let data = payload.data(using: .utf8)
        else {
            return BASRuntimeAuditEmissionSummaryDigest
                .empty(producedAt: producedAt)
        }
        let hash = SHA256.hash(data: data)
        // LEGACY (chapter 七百十九 第三刀 / M2268):
        //     let hex = hash.map {
        //         String(format: "%02x", $0) }.joined()
        let hex = BASAutoRouteRanker.bytesToHexLower(
            Array(hash))
        return BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: algorithmRawName,
            digestString: hex,
            producedAt: producedAt)
    }
}
