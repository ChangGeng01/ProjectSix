// MARK: - BASEBrainTurnResultReplayCanonicalizer — Step 1 (byte-equal replay safety net)
//
// Canonicalizes a `BASEBrainTurnResult` for byte-equal replay comparison by pinning the
// OBSERVATION-CLOCK fields that legitimately drift across re-runs of the SAME request to a
// fixed sentinel. Today there is exactly ONE such field:
//
//   • `memoryBundle.retrievedAt` — `BASMemoryBundle.retrievedAt` defaults to `.now`
//     (`EBrainKnowledgePlaneCore.swift:236`) and the memory service stamps it per retrieval,
//     so it differs nanosecond-to-nanosecond between two runs of the same turn.
//
// ## Contract (R1 / 诚实 — load-bearing)
//
// Canonicalization pins OBSERVATION-clock fields ONLY. It MUST NOT touch any
// authorization-bearing field (sovereignVerdict / sovereignCommitTokens / sovereignWarrants /
// sovereignActuationCommands / sovereignExecutionReceipts / actionPermit / riskCard /
// sovereignAuditEntry / sovereignLock / quarantineRecords / recoveryDisposition / mergedChoice /
// hostGateValue / updateTickets / renderedOutput / …). Adding a field to `canonicalizedFields`
// WIDENS what the harness treats as "allowed to differ", so it is an R1-reviewed event — it must
// never be used to paper over a real consequential drift. The over-reach guard test
// (`testCanonicalizerChangesOnlyTheObservationClockField`) pins this contract: after pinning the
// same field on the raw result, the two results must be FULLY `Equatable`-equal.
//
// ## Provenance of the drift
//
// Independently established by `BASCoordinatorTurnDeterminismTests` (ch1044 DEFER-3): under a
// pinned-`recordedAt` request, only the memory bundle's retrieval clock varies —
// `sovereignAuditEntry.appendedAt` derives from `runtimeTrace.recordedAt = request.recordedAt`,
// so the audit entry is deterministic and is NOT canonicalized here.
//
// Pure value semantics: returns a NEW result (value-type copy); the input is never mutated.
// ADR-014 — purely additive.

import Foundation
import BASMemory

public enum BASEBrainTurnResultReplayCanonicalizer {

    /// Fixed sentinel the observation-clock fields are pinned to before hashing.
    /// chapter 一百八十五 — named, not a magic literal.
    public static let zeroSentinel = Date(timeIntervalSince1970: 0)

    /// Audited single-source-of-truth list of the fields canonicalization pins.
    /// OBSERVATION-clock ONLY — see the file-header contract. Exposed for the over-reach
    /// guard test + audit review (chapter 二百一一).
    public static let canonicalizedFields: [String] = [
        "memoryBundle.retrievedAt",
        // substrate #77 per-stage wall-clock timings — observation drift, collapsed to nil
        // alongside the retrievedAt clock (added 2026-07-11 to close the layerTimingsMs
        // Codable-vs-Equatable inconsistency; both are HOW-LONG, not WHAT-was-decided).
        "layerTimingsMs"
    ]

    /// Return a NEW result with the observation-clock fields pinned to `zeroSentinel`.
    /// The input is not mutated (value-type copy); every other field — and in particular
    /// every authorization-bearing field — is carried through byte-identical.
    public static func canonicalized(
        _ result: BASEBrainTurnResult
    ) -> BASEBrainTurnResult {
        var out = result
        out.memoryBundle.retrievedAt = zeroSentinel
        // substrate #77 per-stage wall-clock timings are observation drift (like the retrievedAt
        // clock): two identical turns differ only in microseconds. Collapse to nil so the canonical
        // form — and its SHA digest — reflect the DECISION, not how long it took. Uncollapsed, two
        // fresh turns (determinism probe) and with/without-honesty-sink runs canonicalize UNEQUAL.
        out.layerTimingsMs = nil
        return out
    }
}
