// MARK: - BASRuntimeAuditEmissionSummaryDigest — chapter 四百二十 / M1050
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百二十 entry:typed digest value
// type wrapping a stable hash over a BASRuntimeAuditEmission
// Summary's payloadJson()。 Future V1↔V2 stress sweep
// harnesses compare digests to detect summary-level drift。
//
// ## Why this exists (system entropy framing)
//
// M967 ships BASRuntimeAuditEmissionSummary with payloadJson()
// returning a sorted-key JSON string。 But comparing two
// summaries for byte-equality requires either string-equality
// or a typed digest。 Without a typed digest primitive,future
// stress harnesses would each compute their own hash inline →
// scattered "summary-digest entropy"。
//
// `BASRuntimeAuditEmissionSummaryDigest` ships the typed
// digest value (algorithmName + digestString + producedAt)
// as one source-of-truth for stable summary identity。
//
// ## What this ships (M1050)
//
//   - `BASRuntimeAuditEmissionSummaryDigest` Codable Sendable
//     value type with 3 typed slots:
//       * algorithmName: String (e.g. "json-sortedKeys-utf8")
//       * digestString: String (the actual digest payload)
//       * producedAt: Date
//   - `.empty(producedAt:)` factory (no digest yet)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十九 doctrine pins
//   - chapter 一百八十五 — typed digest,not raw string
//   - chapter 二百一一 — single source-of-truth for digest
//     shape
//   - chapter 三百九二 — same input → same digest every call
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed digest value type wrapping a stable identity hash
/// for one `BASRuntimeAuditEmissionSummary` instance。
public struct BASRuntimeAuditEmissionSummaryDigest:
    Codable, Equatable, Sendable, Hashable
{

    // MARK: - Storage

    /// Algorithm name producing the digest。 Pinned so
    /// future migrations to different hashing surfaces can
    /// be detected via raw-value compare。
    public let algorithmName: String

    /// The digest payload (raw byte representation as
    /// string for portability across SQLite + JSON audit
    /// stores)。
    public let digestString: String

    /// Wall-clock timestamp the digest was produced。
    public let producedAt: Date

    // MARK: - Init

    public init(
        algorithmName: String,
        digestString: String,
        producedAt: Date
    ) {
        self.algorithmName = algorithmName
        self.digestString = digestString
        self.producedAt = producedAt
    }

    // MARK: - Convenience factories

    /// Empty digest (algorithmName + digestString empty,
    /// timestamp captured)。 Useful as a placeholder before
    /// digest computation lands。
    public static func empty(
        producedAt: Date
    ) -> BASRuntimeAuditEmissionSummaryDigest {
        BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "",
            digestString: "",
            producedAt: producedAt)
    }
}
