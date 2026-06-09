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

    /// A parity summary of one candidate-vs-incumbent comparison.
    public struct Result: Equatable, Sendable {
        public let incumbentLabel: String
        public let candidateLabel: String
        public let labelsAgree: Bool
        public let logitsMAE: Float?
        public let candidateLatencyMillis: Double

        public init(
            incumbentLabel: String,
            candidateLabel: String,
            labelsAgree: Bool,
            logitsMAE: Float?,
            candidateLatencyMillis: Double
        ) {
            self.incumbentLabel = incumbentLabel
            self.candidateLabel = candidateLabel
            self.labelsAgree = labelsAgree
            self.logitsMAE = logitsMAE
            self.candidateLatencyMillis = candidateLatencyMillis
        }
    }

    /// Compute the parity summary for one input. Pure.
    public static func compare(
        incumbentLabel: String, incumbentLogits: [Float],
        candidateLabel: String, candidateLogits: [Float],
        candidateLatencyMillis: Double
    ) -> Result {
        Result(
            incumbentLabel: incumbentLabel,
            candidateLabel: candidateLabel,
            labelsAgree: incumbentLabel == candidateLabel,
            logitsMAE: logitsMAE(incumbentLogits, candidateLogits),
            candidateLatencyMillis: candidateLatencyMillis)
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
        let record = BASShadowTrialRecord(
            trialID: trialID,
            candidateRef: candidateRef,
            trialScope: "coreai-classifier",
            startAt: startAt,
            endAt: endAt,
            observedEffects: [
                "input_len: \(inputLength)",
                "incumbent_label: \(comparison.incumbentLabel)",
                "candidate_label: \(comparison.candidateLabel)",
                "labels_agree: \(comparison.labelsAgree)",
                "logits_mae: \(maeString)",
                "candidate_latency_ms: \(comparison.candidateLatencyMillis)",
            ],
            failConditions: [],
            completionState: "observing")
        return ledger.appending(record)
    }
}
