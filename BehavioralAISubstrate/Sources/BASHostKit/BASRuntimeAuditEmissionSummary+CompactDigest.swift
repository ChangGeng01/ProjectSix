// MARK: - BASRuntimeAuditEmissionSummary+CompactDigest — chapter 四百二十三 / M1064
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百二十三 third cut:typed
// `compactDigest()` accessor producing a one-line
// representation of `BASRuntimeAuditEmissionSummary` for
// log streams + dashboards where the full sortedKeys JSON
// is too verbose。
//
// ## Why this exists (system entropy framing)
//
// M1051 ships SHA256 byte-stable digest (64 hex chars,
// opaque to humans)。 M967 ships sortedKeys JSON via
// payloadJson (~300+ char one-line JSON,verbose)。 But
// log streams want a compact human-readable one-line
// representation that highlights the load-bearing fields
// (trace / verdict / permit / ticket count / stage count)
// without needing to parse JSON。
//
// Without a typed compact-digest accessor,every log
// formatter would compose this inline → scattered
// "compact log formatting entropy"。
//
// ## What this ships (M1064)
//
//   - `BASRuntimeAuditEmissionSummary.compactDigest()`
//     returning a one-line compact key=value rendering:
//     "trace=<id> verdict=<level> permit=<mode>
//      ticket=<n> audit=<id> stages=<n>/<failed>/<ms>
//      parallel=<groups>grp/<ms> coherent=<bool>"
//   - Pure;same summary → same digest (chapter 三百九二)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/…/四百二十二 doctrine pins
//   - chapter 一百八十五 — typed accessor
//   - chapter 二百一一 — single source-of-truth for compact
//     log formatting
//   - chapter 三百九二 — deterministic
//   - ADR-014 OPT-IN — purely additive

import Foundation

extension BASRuntimeAuditEmissionSummary {

    /// Compact one-line key=value rendering of the summary
    /// for log streams。 Shows the load-bearing fields:
    /// trace / verdict / permit / ticket / audit / stage
    /// counts + durations / parallel summary aggregates /
    /// coherence Bool。 Pure;same summary → same digest
    /// (chapter 三百九二)。
    public func compactDigest() -> String {
        let parts: [String] = [
            "trace=\(traceID)",
            "verdict=\(verdictLevelRaw)",
            "permit=\(permitModeRaw)",
            "ticket=\(ticketCount)",
            "audit=\(auditID)",
            "stages=\(stageCount)/" +
                "\(failedStageCount)/" +
                "\(totalStageDurationMs)ms",
            "parallel=" +
                "\(nonEmptyParallelGroupCount)grp/" +
                "\(parallelDispatchTotalDurationMs)ms",
            "coherent=\(planLedgerIsCoherent)"
        ]
        return parts.joined(separator: " ")
    }
}
