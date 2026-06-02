// ch1055 / v1.0 §6 step 19 — the distillation ingest HOOK: feed a turn's governed-call traces into
// the pool. The gap audit found `BASDistillationBank` had zero production callers. After a turn whose
// LLM calls were contract-installed (a `traceSink` collected their `BASProcessTrace`s — ADR-031 §4.1),
// the host calls this to ingest the high-quality ones, closing the "高质量 trace 进入蒸馏池" loop.
//
// Opt-in / immutable: returns a NEW bank; nothing calls it unless the host does (byte-equal-off).

import Foundation
import BASMemory
import BASOrgan

public extension BASDistillationBank {
    /// Ingest a turn's collected `BASProcessTrace`s. The host supplies the per-trace quality (a trace
    /// cannot self-certify) and the safety flags (the bank re-checks them at admission, fail-closed).
    /// Rejected traces (no output to distill) are skipped, as are entries the policy/dedup rejects.
    /// Returns the new bank + a per-attempted-entry admission verdict (skipped rejected-traces omitted).
    func ingestingTraces(
        _ traces: [BASProcessTrace],
        quality: (BASProcessTrace) -> BASDistillationQuality,
        scrubbed: Bool,
        privacySafe: Bool,
        sovereignSafe: Bool
    ) -> (bank: BASDistillationBank, admissions: [BASDistillationAdmission]) {
        var bank = self
        var admissions: [BASDistillationAdmission] = []
        for t in traces {
            guard let entry = BASDistillationEntry.from(
                processTrace: t, quality: quality(t),
                scrubbed: scrubbed, privacySafe: privacySafe, sovereignSafe: sovereignSafe)
            else { continue }   // rejected trace → no produced output to distill
            let (next, admission) = bank.ingesting(entry)
            bank = next
            admissions.append(admission)
        }
        return (bank, admissions)
    }
}
