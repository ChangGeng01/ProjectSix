// ch1047 / v1.0 L13 — ProcessTrace → DistillationBank adapter (高质量 trace 进入蒸馏池).
//
// `BASDistillationBank` (BASMemory) ingests entries by REF and re-checks the red-line safety gates at
// admission. This adapter builds a pool entry from a governed LLM call trace (`BASProcessTrace`,
// BASOrgan) — the §6 step-19 connection "高质量 trace 进入蒸馏池". It lives in BASOrchestration because
// only that module imports both BASMemory and BASOrgan.
//
// A `BASProcessTrace` carries NO raw body, so referencing it is red-line-safe; but a trace cannot
// self-certify scrub/privacy/sovereign safety, so the CALLER must pass those flags from its own
// governance (the bank then re-checks them, fail-closed). Rejected traces (the model was never
// called → no output to distill) yield nil.

import Foundation
import BASMemory
import BASOrgan

public extension BASDistillationEntry {
    /// Build a pool entry from an ACCEPTED governed call trace. Returns nil for a rejected trace
    /// (no produced output to distill). The caller asserts the scrub/privacy/sovereign flags from its
    /// own governance — the bank re-checks them at admission.
    static func from(processTrace t: BASProcessTrace,
                     quality: BASDistillationQuality,
                     scrubbed: Bool,
                     privacySafe: Bool,
                     sovereignSafe: Bool) -> BASDistillationEntry? {
        guard t.verdict == .accepted else { return nil }
        return BASDistillationEntry(
            id: "dist:trace:" + t.traceID,
            sourceKind: .processTrace,
            sourceRef: t.traceID,
            purposeTag: t.purpose.rawValue,
            quality: quality,
            scrubbed: scrubbed, privacySafe: privacySafe, sovereignSafe: sovereignSafe,
            producedAt: t.producedAt)
    }
}
