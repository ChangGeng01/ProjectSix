// MARK: - BASSpeculativeShadowComposer
//
// 结构大重构 — Phase 5. The WIRING between the shadow-trial ledger and the speculative-decoding ENABLE gate
// (`BASSpeculativeMigrationVerdict`). Mirrors `BASCoreAIVerdictEvidenceComposer`:
//
//   [BASShadowTrialRecord(trialScope="speculative-decode")] ──parse──▶ [ParsedTrial]
//        └── correctness AND · paired latency means · mean acceptance ──▶ Evidence ──decide──▶ Verdict
//
// ## Honesty rules (亏的不要 / R1)
//
// - PAIRED-ONLY latency: speculative/baseline means are computed ONLY over records carrying BOTH measurements for
//   the SAME input. Comparing means from different inputs would be dishonest. Zero paired records ⇒ both means
//   nil ⇒ LATENCY_NO_EVIDENCE.
// - CORRECTNESS is a hard AND: a single record reporting `correctness_verified: false` makes the aggregate false
//   (decisive doNotEnable) — a faster wrong answer is worse than a correct slow one. `true` only when ≥1 record
//   verifies it and NONE refute it; `nil` when no record measured it.
// - Malformed / foreign records are SKIPPED, never guessed at (`skippedRecordCount` reports them).
// - Never auto-enables: `render` produces a report a HUMAN reads. Observation-only (红线 7); banned from the spine.

import Foundation
import BASMemory   // BASShadowTrialRecord

public enum BASSpeculativeShadowComposer {

    /// The trial scope this composer understands.
    public static let trialScope = "speculative-decode"

    // MARK: - One parsed trial

    /// One parsed spec-decode trial. `mode` + `speculativeLatencyMillis` are required; the rest are optional.
    public struct ParsedTrial: Equatable, Sendable {
        public let mode: String
        public let correctnessVerified: Bool?
        public let acceptanceRate: Double?
        public let speculativeLatencyMillis: Double
        public let baselineLatencyMillis: Double?
    }

    /// Parse one ledger record, or nil if it is not a spec-decode trial or its effects are malformed. Tolerant
    /// only of ABSENT optional fields, never of malformed required ones.
    ///
    /// T2.3 低熵 — fields come from `record.effectFields()`: typed-first when `typedObservedEffects` is
    /// present (typed/string disagreement ⇒ nil ⇒ skipped record), legacy colon-string parse otherwise.
    public static func parse(record: BASShadowTrialRecord) -> ParsedTrial? {
        guard record.trialScope == trialScope else { return nil }
        guard let fields = record.effectFields() else { return nil }
        guard
            let mode = fields["mode"], !mode.isEmpty,
            let specRaw = fields["speculative_latency_ms"], let specMs = Double(specRaw),
            specMs.isFinite, specMs >= 0   // AUDIT hardening: "nan"/"inf"/negative parse as Double — reject (NaN
                                           // would poison the means; mirrors the CoreAI non-finite MAE guard)
        else { return nil }

        // Optional correctness — absent ⇒ nil; present-but-malformed ⇒ reject the record.
        let correctness: Bool?
        switch fields["correctness_verified"] {
        case .none: correctness = nil
        case .some(let raw):
            guard let parsed = Bool(raw) else { return nil }
            correctness = parsed
        }
        // Optional acceptance — absent ⇒ nil; present-but-malformed/non-finite/out-of-range ⇒ reject.
        let acceptance: Double?
        switch fields["acceptance_rate"] {
        case .none: acceptance = nil
        case .some(let raw):
            guard let parsed = Double(raw), parsed.isFinite, (0...1).contains(parsed) else { return nil }
            acceptance = parsed
        }
        // Optional baseline latency — absent ⇒ nil (unpaired); present-but-malformed/non-finite ⇒ reject.
        let baselineMs: Double?
        switch fields["baseline_latency_ms"] {
        case .none: baselineMs = nil
        case .some(let raw):
            guard let parsed = Double(raw), parsed.isFinite, parsed >= 0 else { return nil }
            baselineMs = parsed
        }
        return ParsedTrial(
            mode: mode,
            correctnessVerified: correctness,
            acceptanceRate: acceptance,
            speculativeLatencyMillis: specMs,
            baselineLatencyMillis: baselineMs)
    }

    // MARK: - Composition

    public struct Composition: Equatable, Sendable {
        public let evidence: BASSpeculativeMigrationVerdict.Evidence
        public let parsedRecordCount: Int
        public let skippedRecordCount: Int
        public let pairedLatencySampleCount: Int
    }

    /// Fold ledger records into gate `Evidence` for ONE lane. Pure + deterministic. `distinctDeviceCount`, the
    /// dual peak, and the memory budget are caller-supplied (capture-campaign / device properties, not per-record).
    ///
    /// AUDIT FIX — PER-MODE composition: `mode` is now a required filter. The previous shape pooled greedy AND
    /// sampling records into one Evidence (mode picked by arbitrary parse order, correctness AND'd across lanes,
    /// latency means mixing both lanes) — a dishonest conflation. Each lane is judged on its own records; valid
    /// records of OTHER modes are simply out of scope (neither counted nor skipped — `skippedRecordCount` keeps
    /// meaning "in-scope but malformed").
    public static func compose(
        records: [BASShadowTrialRecord],
        mode: String,
        distinctDeviceCount: Int,
        dualPeakMemoryBytes: Int? = nil,
        memoryBudgetBytes: Int? = nil
    ) -> Composition {
        let scoped = records.filter { $0.trialScope == trialScope }
        let parsed = scoped.compactMap(parse(record:))
        let trials = parsed.filter { $0.mode == mode }

        // Correctness is a hard AND: any false ⇒ false; ≥1 true and no false ⇒ true; none measured ⇒ nil.
        let correctnessValues = trials.compactMap(\.correctnessVerified)
        let correctness: Bool?
        if correctnessValues.isEmpty {
            correctness = nil
        } else {
            correctness = correctnessValues.allSatisfy { $0 }
        }

        // Mean acceptance over records that reported it.
        let acceptances = trials.compactMap(\.acceptanceRate)
        let meanAcceptance = acceptances.isEmpty
            ? nil : acceptances.reduce(0, +) / Double(acceptances.count)

        // PAIRED-ONLY latency means.
        let paired = trials.compactMap { t -> (spec: Double, base: Double)? in
            guard let base = t.baselineLatencyMillis else { return nil }
            return (t.speculativeLatencyMillis, base)
        }
        let specMean = paired.isEmpty ? nil : paired.map(\.spec).reduce(0, +) / Double(paired.count)
        let baseMean = paired.isEmpty ? nil : paired.map(\.base).reduce(0, +) / Double(paired.count)

        let evidence = BASSpeculativeMigrationVerdict.Evidence(
            mode: mode,
            correctnessVerified: correctness,
            acceptanceRate: meanAcceptance,
            speculativeMeanLatencyMillis: specMean,
            baselineMeanLatencyMillis: baseMean,
            dualPeakMemoryBytes: dualPeakMemoryBytes,
            memoryBudgetBytes: memoryBudgetBytes,
            sampleCount: trials.count,
            pairedLatencySampleCount: paired.count,
            distinctDeviceCount: distinctDeviceCount)

        return Composition(
            evidence: evidence,
            parsedRecordCount: trials.count,
            skippedRecordCount: scoped.count - parsed.count,
            pairedLatencySampleCount: paired.count)
    }

    // MARK: - One-call ledger → verdict + report

    public static func decide(
        records: [BASShadowTrialRecord],
        mode: String,
        distinctDeviceCount: Int,
        dualPeakMemoryBytes: Int? = nil,
        memoryBudgetBytes: Int? = nil,
        thresholds: BASSpeculativeMigrationVerdict.Thresholds = .default
    ) -> (verdict: BASSpeculativeMigrationVerdict.Verdict, composition: Composition) {
        let composition = compose(
            records: records,
            mode: mode,
            distinctDeviceCount: distinctDeviceCount,
            dualPeakMemoryBytes: dualPeakMemoryBytes,
            memoryBudgetBytes: memoryBudgetBytes)
        let verdict = BASSpeculativeMigrationVerdict.decide(
            evidence: composition.evidence, thresholds: thresholds)
        return (verdict, composition)
    }

    /// Render a deterministic, human-readable report. The gate emits a RECOMMENDATION a human reads — it never
    /// enables anything itself.
    public static func render(
        verdict: BASSpeculativeMigrationVerdict.Verdict,
        composition: Composition
    ) -> String {
        let e = verdict.evidence
        let specMs = e.speculativeMeanLatencyMillis.map { String(format: "%.2f", $0) } ?? "n/a"
        let baseMs = e.baselineMeanLatencyMillis.map { String(format: "%.2f", $0) } ?? "n/a"
        let accept = e.acceptanceRate.map { String(format: "%.3f", $0) } ?? "n/a"
        let correctness = e.correctnessVerified.map { $0 ? "verified" : "FAILED" } ?? "n/a"
        let peak = e.dualPeakMemoryBytes.map { "\($0 / (1024 * 1024))MB" } ?? "n/a"
        let budget = e.memoryBudgetBytes.map { "\($0 / (1024 * 1024))MB" } ?? "n/a"
        return """
        speculative-decode-gate mode=\(e.mode) recommendation=\(verdict.recommendation.rawValue)
          reasons=\(verdict.reasonCodes.joined(separator: ","))
          correctness=\(correctness) acceptance=\(accept)
          latency(paired n=\(composition.pairedLatencySampleCount)): speculative_ms=\(specMs) baseline_ms=\(baseMs)
          memory: dual_peak=\(peak) budget=\(budget)
          devices=\(e.distinctDeviceCount) parsed=\(composition.parsedRecordCount) skipped=\(composition.skippedRecordCount)
          (observation-only — a human decides; the gate never auto-enables)
        """
    }
}
