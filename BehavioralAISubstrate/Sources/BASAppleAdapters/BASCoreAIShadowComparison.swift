// MARK: - BASCoreAIShadowComparison
//
// Observation-only dual-run wiring for the Core AI classifier candidate vs the CoreML incumbent. Given two
// already-computed `(label, logits)` results on the SAME input, it computes a parity summary (label agreement +
// logits MAE + candidate latency) and records it as a PENDING `BASShadowTrialRecord` in an immutable
// `BASShadowTrialFeedbackLedger`.
//
// ## Guardrails (红线 7 / observation-only)
//
// This type is PURE + framework-free — it never runs a model, never touches the turn, never writes governance.
// The candidate's output is logged for comparison ONLY; it cannot promote itself (the record's `completionState`
// is "observing", which the ledger's evaluator maps to "stay in flight" — no auto-promotion). The incumbent
// path is never mutated. It logs the input LENGTH, never the input text (no PII into the trial ledger).

import Foundation
import BASMemory   // BASShadowTrialFeedbackLedger + BASShadowTrialRecord

public enum BASCoreAIShadowComparison {

    /// Mean absolute error between two equal-length logits vectors, or `nil` if they differ in length / are
    /// empty (a parity comparison only makes sense over the same logits space).
    public static func logitsMAE(_ lhs: [Float], _ rhs: [Float]) -> Float? {
        guard !lhs.isEmpty, lhs.count == rhs.count else { return nil }
        var sum: Float = 0
        for i in lhs.indices { sum += abs(lhs[i] - rhs[i]) }
        return sum / Float(lhs.count)
    }

    /// A parity summary of one candidate-vs-incumbent comparison. `incumbentLatencyMillis` is the PAIRED
    /// incumbent-side measurement on the SAME input (nil when the probe didn't capture it — the migration
    /// gate then reports LATENCY_NO_EVIDENCE rather than comparing unpaired numbers).
    public struct Result: Equatable, Sendable {
        public let incumbentLabel: String
        public let candidateLabel: String
        public let labelsAgree: Bool
        public let logitsMAE: Float?
        public let candidateLatencyMillis: Double
        public let incumbentLatencyMillis: Double?

        public init(
            incumbentLabel: String,
            candidateLabel: String,
            labelsAgree: Bool,
            logitsMAE: Float?,
            candidateLatencyMillis: Double,
            incumbentLatencyMillis: Double? = nil
        ) {
            self.incumbentLabel = incumbentLabel
            self.candidateLabel = candidateLabel
            self.labelsAgree = labelsAgree
            self.logitsMAE = logitsMAE
            self.candidateLatencyMillis = candidateLatencyMillis
            self.incumbentLatencyMillis = incumbentLatencyMillis
        }
    }

    /// Compute the parity summary for one input. Pure.
    public static func compare(
        incumbentLabel: String, incumbentLogits: [Float],
        candidateLabel: String, candidateLogits: [Float],
        candidateLatencyMillis: Double,
        incumbentLatencyMillis: Double? = nil
    ) -> Result {
        Result(
            incumbentLabel: incumbentLabel,
            candidateLabel: candidateLabel,
            labelsAgree: incumbentLabel == candidateLabel,
            logitsMAE: logitsMAE(incumbentLogits, candidateLogits),
            candidateLatencyMillis: candidateLatencyMillis,
            incumbentLatencyMillis: incumbentLatencyMillis)
    }

    // MARK: - Corpus aggregation (n > 1 — evidence for the migration verdict)

    /// Aggregate parity statistics across a CORPUS of single-comparison `Result`s. The migration verdict
    /// (`BASCoreAIMigrationVerdict`) judges parity off this — n=1 is never enough to retire an incumbent.
    ///
    /// Honest on empty input: zero samples ⇒ `labelAgreementRate == 0` (NOT 1 — "no evidence of agreement"),
    /// and the MAE fields are `nil` (no comparable logits seen). `maeSampleCount` counts only the comparisons
    /// whose logits shared a space (`logitsMAE != nil`) — a future model revision with a different logits width
    /// contributes a label datapoint but not an MAE datapoint, so the two counts can legitimately differ.
    public struct ParitySummary: Equatable, Sendable {
        public let sampleCount: Int
        public let labelsAgreeCount: Int
        public let labelAgreementRate: Double
        public let maeSampleCount: Int
        public let meanLogitsMAE: Float?
        public let maxLogitsMAE: Float?

        public init(
            sampleCount: Int,
            labelsAgreeCount: Int,
            labelAgreementRate: Double,
            maeSampleCount: Int,
            meanLogitsMAE: Float?,
            maxLogitsMAE: Float?
        ) {
            self.sampleCount = sampleCount
            self.labelsAgreeCount = labelsAgreeCount
            self.labelAgreementRate = labelAgreementRate
            self.maeSampleCount = maeSampleCount
            self.meanLogitsMAE = meanLogitsMAE
            self.maxLogitsMAE = maxLogitsMAE
        }
    }

    /// Fold a corpus of comparisons into a `ParitySummary`. Pure + deterministic.
    public static func aggregate(_ results: [Result]) -> ParitySummary {
        let sampleCount = results.count
        let labelsAgreeCount = results.reduce(0) { $0 + ($1.labelsAgree ? 1 : 0) }
        let rate = sampleCount == 0 ? 0 : Double(labelsAgreeCount) / Double(sampleCount)
        let maes = results.compactMap(\.logitsMAE)
        // CORRUPTION GUARD: a non-finite MAE (NaN/Inf — from NaN logits, numeric overflow, GPU corruption) must
        // surface as a non-finite MAX so the verdict's parity check FAILS it. `Array.max()` uses `<` and SILENTLY
        // DROPS a non-first NaN (returning a finite value), so a single corrupted sample could otherwise slip
        // through as PARITY_MET. We force `.nan` whenever ANY sample is non-finite — the gate then rejects it.
        let hasNonFinite = maes.contains { !$0.isFinite }
        let mean: Float? = maes.isEmpty ? nil : maes.reduce(0, +) / Float(maes.count)
        let maxMAE: Float? = maes.isEmpty ? nil : (hasNonFinite ? Float.nan : maes.max())
        return ParitySummary(
            sampleCount: sampleCount,
            labelsAgreeCount: labelsAgreeCount,
            labelAgreementRate: rate,
            maeSampleCount: maes.count,
            meanLogitsMAE: mean,
            maxLogitsMAE: maxMAE)
    }

    /// Append a PENDING ("observing") shadow-trial record for `comparison` to `ledger`, returning a NEW ledger
    /// (the receiver is untouched — immutability). The record is observation-only; it never auto-promotes.
    /// Timestamps are caller-supplied (no internal clock) so the result is deterministic + replay-stable.
    public static func record(
        into ledger: BASShadowTrialFeedbackLedger,
        trialID: String,
        inputLength: Int,
        comparison: Result,
        startAt: Date,
        endAt: Date,
        candidateRef: String = BASCoreAIClassifierMetadata.candidateRef
    ) -> BASShadowTrialFeedbackLedger {
        let maeString = comparison.logitsMAE.map { "\($0)" } ?? "n/a"
        var effects = [
            "input_len: \(inputLength)",
            "incumbent_label: \(comparison.incumbentLabel)",
            "candidate_label: \(comparison.candidateLabel)",
            "labels_agree: \(comparison.labelsAgree)",
            "logits_mae: \(maeString)",
            "candidate_latency_ms: \(comparison.candidateLatencyMillis)",
        ]
        // 全面进化 T2.3 低熵 — DUAL-WRITE: typed effects beside the legacy colon-strings。 The strings stay
        // the source of record (older composers parse them);typed pairs are the parallel low-entropy lane。
        // Any field added to `effects` below MUST gain its typed twin here — the composers count a
        // typed/string disagreement as a skipped record, so drift is loud, not silent.
        var typed: [BASShadowTrialTypedEffect] = [
            .init(key: "input_len", value: "\(inputLength)", kind: .metric),
            .init(key: "incumbent_label", value: comparison.incumbentLabel, kind: .label),
            .init(key: "candidate_label", value: comparison.candidateLabel, kind: .label),
            .init(key: "labels_agree", value: "\(comparison.labelsAgree)", kind: .flag),
            .init(key: "logits_mae", value: maeString, kind: .metric),
            .init(key: "candidate_latency_ms", value: "\(comparison.candidateLatencyMillis)", kind: .metric),
        ]
        // PAIRED incumbent latency (additive — absent on pre-pairing records; the evidence composer treats a
        // missing line as nil so old ledgers stay parseable and the gate honestly reports LATENCY_NO_EVIDENCE).
        if let incumbentMs = comparison.incumbentLatencyMillis {
            effects.append("incumbent_latency_ms: \(incumbentMs)")
            typed.append(.init(key: "incumbent_latency_ms", value: "\(incumbentMs)", kind: .metric))
        }
        let record = BASShadowTrialRecord(
            trialID: trialID,
            candidateRef: candidateRef,
            trialScope: "coreai-classifier",
            startAt: startAt,
            endAt: endAt,
            observedEffects: effects,
            failConditions: [],
            completionState: "observing",
            typedObservedEffects: typed)
        return ledger.appending(record)
    }
}
