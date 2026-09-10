// MARK: - BASCoreAIVerdictEvidenceComposer
//
// The WIRING between the shadow-trial ledger and the CoreML→CoreAI migration gate. Before this file the gate
// (`BASCoreAIMigrationVerdict`) existed as a pure decision function with no production caller — nothing folded
// the recorded `BASShadowTrialRecord`s back into `Evidence`. This composer closes that gap:
//
//   [BASShadowTrialRecord] ──parse──▶ [BASCoreAIShadowComparison.Result] ──aggregate──▶ ParitySummary
//        └── paired latencies ──────────────────────────────────────────────▶ Evidence ──decide──▶ Verdict
//
// ## Honesty rules (亏的不要 / R1)
//
// - PAIRED-ONLY latency: mean latencies are computed ONLY over records that carry BOTH the candidate and the
//   incumbent measurement for the SAME input. Unpaired records contribute parity but no latency evidence —
//   comparing a candidate mean against an incumbent mean from different inputs would be a dishonest comparison.
//   Zero paired records ⇒ both means nil ⇒ the gate reports LATENCY_NO_EVIDENCE (exactly today's reality for
//   ledgers recorded before pairing existed).
// - Malformed / foreign records are SKIPPED, never guessed at: a record with a different `trialScope`, or one
//   whose effects can't be parsed, contributes nothing (and `skippedRecordCount` reports it).
// - The composer never auto-promotes: `render` produces a report a HUMAN reads. Observation-only (红线 7); the
//   type is banned from the byte-deterministic spine alongside the rest of the Core AI surface.

import Foundation
import BASMemory   // BASShadowTrialRecord

public enum BASCoreAIVerdictEvidenceComposer {

    /// The trial scope this composer understands (must match `BASCoreAIShadowComparison.record`).
    public static let trialScope = "coreai-classifier"

    // MARK: - Parsing one record back into a comparison Result

    /// Parse one ledger record back into a `Result`, or nil if the record is not a coreai-classifier trial or
    /// its effects are malformed. Pure; tolerant only of ABSENT optional fields (MAE "n/a", missing incumbent
    /// latency), never of malformed required ones.
    ///
    /// T2.3 低熵 — fields come from `record.effectFields()`: typed-first when `typedObservedEffects` is
    /// present (typed/string disagreement ⇒ nil here ⇒ counted as a skipped record), legacy colon-string
    /// parse otherwise. Old ledgers parse exactly as before.
    public static func parse(
        record: BASShadowTrialRecord
    ) -> BASCoreAIShadowComparison.Result? {
        guard record.trialScope == trialScope else { return nil }
        guard let fields = record.effectFields() else { return nil }
        guard
            let incumbentLabel = fields["incumbent_label"], !incumbentLabel.isEmpty,
            let candidateLabel = fields["candidate_label"], !candidateLabel.isEmpty,
            let agreeRaw = fields["labels_agree"], let labelsAgree = Bool(agreeRaw),
            let candLatencyRaw = fields["candidate_latency_ms"], let candidateMs = Double(candLatencyRaw)
        else { return nil }
        // Optional fields: "n/a" MAE ⇒ nil (mismatched logits spaces); absent incumbent latency ⇒ nil (unpaired).
        let mae: Float?
        switch fields["logits_mae"] {
        case .none, .some("n/a"): mae = nil
        case .some(let raw):
            guard let parsed = Float(raw) else { return nil }   // present-but-malformed ⇒ reject the record
            mae = parsed
        }
        let incumbentMs = fields["incumbent_latency_ms"].flatMap(Double.init)
        return BASCoreAIShadowComparison.Result(
            incumbentLabel: incumbentLabel,
            candidateLabel: candidateLabel,
            labelsAgree: labelsAgree,
            logitsMAE: mae,
            candidateLatencyMillis: candidateMs,
            incumbentLatencyMillis: incumbentMs)
    }

    // MARK: - Composition

    /// The composed evidence plus composition bookkeeping (how much of the ledger was usable).
    public struct Composition: Equatable, Sendable {
        public let evidence: BASCoreAIMigrationVerdict.Evidence
        public let parsedRecordCount: Int
        public let skippedRecordCount: Int
        public let pairedLatencySampleCount: Int
    }

    /// Fold ledger records into gate `Evidence`. Pure + deterministic.
    ///
    /// - `distinctDeviceCount` and the peak-memory pair are caller-supplied: they are properties of the capture
    ///   campaign (which devices ran, what the process peak RSS was), not derivable from individual records.
    public static func compose(
        records: [BASShadowTrialRecord],
        distinctDeviceCount: Int,
        candidatePeakMemoryBytes: Int? = nil,
        incumbentPeakMemoryBytes: Int? = nil
    ) -> Composition {
        let scoped = records.filter { $0.trialScope == trialScope }
        let results = scoped.compactMap(parse(record:))
        let parity = BASCoreAIShadowComparison.aggregate(results)
        // PAIRED-ONLY latency means (see header). Unpaired records carry no latency evidence.
        let paired = results.compactMap { result -> (cand: Double, inc: Double)? in
            guard let inc = result.incumbentLatencyMillis else { return nil }
            return (result.candidateLatencyMillis, inc)
        }
        let candidateMean = paired.isEmpty
            ? nil : paired.map(\.cand).reduce(0, +) / Double(paired.count)
        let incumbentMean = paired.isEmpty
            ? nil : paired.map(\.inc).reduce(0, +) / Double(paired.count)
        let evidence = BASCoreAIMigrationVerdict.Evidence(
            parity: parity,
            candidateMeanLatencyMillis: candidateMean,
            incumbentMeanLatencyMillis: incumbentMean,
            candidatePeakMemoryBytes: candidatePeakMemoryBytes,
            incumbentPeakMemoryBytes: incumbentPeakMemoryBytes,
            distinctDeviceCount: distinctDeviceCount)
        return Composition(
            evidence: evidence,
            parsedRecordCount: results.count,
            skippedRecordCount: scoped.count - results.count,
            pairedLatencySampleCount: paired.count)
    }

    // MARK: - One-call ledger → verdict + human-readable report

    /// Compose evidence from `records` and run the gate. Returns the verdict plus the composition bookkeeping.
    public static func decide(
        records: [BASShadowTrialRecord],
        distinctDeviceCount: Int,
        candidatePeakMemoryBytes: Int? = nil,
        incumbentPeakMemoryBytes: Int? = nil,
        thresholds: BASCoreAIMigrationVerdict.Thresholds = .default
    ) -> (verdict: BASCoreAIMigrationVerdict.Verdict, composition: Composition) {
        let composition = compose(
            records: records,
            distinctDeviceCount: distinctDeviceCount,
            candidatePeakMemoryBytes: candidatePeakMemoryBytes,
            incumbentPeakMemoryBytes: incumbentPeakMemoryBytes)
        let verdict = BASCoreAIMigrationVerdict.decide(
            evidence: composition.evidence, thresholds: thresholds)
        return (verdict, composition)
    }

    /// Render a deterministic, human-readable report. The gate emits a RECOMMENDATION a human reads — it never
    /// promotes anything itself.
    public static func render(
        verdict: BASCoreAIMigrationVerdict.Verdict,
        composition: Composition
    ) -> String {
        let parity = verdict.evidence.parity
        let mae = parity.maxLogitsMAE.map { String(format: "%.6f", $0) } ?? "n/a"
        let candMs = verdict.evidence.candidateMeanLatencyMillis.map { String(format: "%.2f", $0) } ?? "n/a"
        let incMs = verdict.evidence.incumbentMeanLatencyMillis.map { String(format: "%.2f", $0) } ?? "n/a"
        return """
        coreai-migration-gate recommendation=\(verdict.recommendation.rawValue)
          reasons=\(verdict.reasonCodes.joined(separator: ","))
          parity: samples=\(parity.sampleCount) agree=\(parity.labelsAgreeCount) rate=\(String(format: "%.3f", parity.labelAgreementRate)) max_mae=\(mae)
          latency(paired n=\(composition.pairedLatencySampleCount)): candidate_ms=\(candMs) incumbent_ms=\(incMs)
          devices=\(verdict.evidence.distinctDeviceCount) parsed=\(composition.parsedRecordCount) skipped=\(composition.skippedRecordCount)
          (observation-only — a human decides; the gate never auto-promotes)
        """
    }
}
