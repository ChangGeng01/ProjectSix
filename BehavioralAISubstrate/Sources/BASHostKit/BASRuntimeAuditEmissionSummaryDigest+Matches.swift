// MARK: - BASRuntimeAuditEmissionSummaryDigest+Matches — chapter 四百二十 / M1052
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百二十 third cut:typed
// `.matches(other:)` comparison method that compares two
// digests by content (algorithmName + digestString)
// while ignoring producedAt timestamp。 Future V1↔V2
// stress harnesses use this to detect summary-content
// drift independent of when each digest was computed。
//
// ## Why this exists (system entropy framing)
//
// M1051 ships SHA256-based digest production。 But the
// typed Equatable conformance compares ALL fields
// (including producedAt timestamp) — too strict for
// content-equality verification where two digests of the
// same content but different timestamps SHOULD be treated
// as matching。
//
// Without `.matches(_:)`,every stress harness would
// inline `lhs.algorithmName == rhs.algorithmName &&
// lhs.digestString == rhs.digestString` → scattered
// "digest-content-comparison entropy"。
//
// `.matches(other:)` ships the typed content-equality
// predicate as one source-of-truth (chapter 二百一一)。
//
// ## What this ships (M1052)
//
//   - `.matches(_:)` instance method:Bool true iff
//     algorithmName + digestString match (producedAt
//     ignored)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百十九/四百二十 doctrine pins
//   - chapter 一百八十五 — typed comparison
//   - chapter 二百一一 — single source-of-truth for content
//     equality predicate
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASRuntimeAuditEmissionSummaryDigest {

    /// Compare two digests by content (algorithm + digest
    /// string),ignoring producedAt timestamp。 Returns
    /// true when both fields match exactly。 Use this for
    /// summary-content drift detection;use Equatable for
    /// strict instance-identity comparison (algorithm +
    /// digest + producedAt)。
    public func matches(
        _ other: BASRuntimeAuditEmissionSummaryDigest
    ) -> Bool {
        algorithmName == other.algorithmName
            && digestString == other.digestString
    }
}
