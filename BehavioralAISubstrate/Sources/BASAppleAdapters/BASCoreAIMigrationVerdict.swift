// MARK: - BASCoreAIMigrationVerdict
//
// The CoreML → Core AI migration GATE, in executable form. The Core AI arc proved the candidate *matches* the
// CoreML incumbent at n=1 (label parity + logits MAE ~1e-6 on the iPhone Air). Matching is NOT winning. This
// type is the strict, default-deny decision function that says — given accumulated shadow evidence — whether
// the substrate should `migrate`, `doNotMigrate`, or declares the evidence `insufficient`. It exists so the
// operator's doctrine ("亏的不要" — never take on a net-negative; "migrate CoreML→Core AI only if it WINS") is
// a verifiable code path, not a narrative claim.
//
// ## Why default-deny (亏的不要)
//
// Retiring a working incumbent is irreversible churn with real cost. So this gate refuses to recommend
// migration unless the candidate *provably wins* on EVERY dimension that matters — parity, latency, AND
// memory — with adequate sample size across ≥2 distinct devices. A TIE is not a win (no benefit ⇒ don't pay
// the migration cost). A MISSING dimension is not a win (we cannot certify what we did not measure). A single
// device is not enough (n=1/single-device bounds, R1). Run against today's evidence — n=1, single device,
// parity-only — `decide` is *forced* to return `.insufficientEvidence`: CoreML stands.
//
// ## Guardrails (红线 7 / observation-only)
//
// PURE + framework-free + deterministic. It never runs a model, never mutates the incumbent, never auto-
// promotes (its output is a recommendation a HUMAN reads — it cannot itself flip any provider). It is
// reasoning-side and is BANNED from the byte-deterministic spine (`BASMetalDeterminismBoundaryTests`).

import Foundation

public enum BASCoreAIMigrationVerdict {

    // MARK: - Evidence (what the shadow corpus + device measurement captured)

    /// Aggregated, multi-sample, multi-device evidence the gate judges. `parity` always carries the pure
    /// shadow-corpus parity (available today). `latency` / `memory` are PAIRED candidate-vs-incumbent
    /// measurements — present only once device instrumentation captures BOTH sides; `nil` means "not measured"
    /// (→ NO_EVIDENCE → never a win). `distinctDeviceCount` is how many distinct devices the evidence spans.
    public struct Evidence: Equatable, Sendable {
        public let parity: BASCoreAIShadowComparison.ParitySummary
        public let candidateMeanLatencyMillis: Double?
        public let incumbentMeanLatencyMillis: Double?
        public let candidatePeakMemoryBytes: Int?
        public let incumbentPeakMemoryBytes: Int?
        public let distinctDeviceCount: Int

        public init(
            parity: BASCoreAIShadowComparison.ParitySummary,
            candidateMeanLatencyMillis: Double? = nil,
            incumbentMeanLatencyMillis: Double? = nil,
            candidatePeakMemoryBytes: Int? = nil,
            incumbentPeakMemoryBytes: Int? = nil,
            distinctDeviceCount: Int = 0
        ) {
            self.parity = parity
            self.candidateMeanLatencyMillis = candidateMeanLatencyMillis
            self.incumbentMeanLatencyMillis = incumbentMeanLatencyMillis
            self.candidatePeakMemoryBytes = candidatePeakMemoryBytes
            self.incumbentPeakMemoryBytes = incumbentPeakMemoryBytes
            self.distinctDeviceCount = distinctDeviceCount
        }
    }

    // MARK: - Thresholds (the bar the candidate must clear to WIN)

    /// The bar. Defaults are deliberately strict: a 100% label-agreement floor, a tight MAE epsilon, a
    /// meaningful (not within-noise) latency/memory improvement margin, ≥50 samples, and ≥2 distinct devices.
    public struct Thresholds: Equatable, Sendable {
        public let minSamples: Int
        public let minDistinctDevices: Int
        public let maxAcceptableMAE: Float
        public let requiredLabelAgreementRate: Double
        /// Candidate must be `<= incumbent * (1 - margin)` to count as a WIN — a margin > 0 means a tie or a
        /// within-noise improvement is NOT enough to justify migration churn.
        public let latencyWinMarginFraction: Double
        public let memoryWinMarginFraction: Double

        public init(
            minSamples: Int = 50,
            minDistinctDevices: Int = 2,
            maxAcceptableMAE: Float = 1e-3,
            requiredLabelAgreementRate: Double = 1.0,
            latencyWinMarginFraction: Double = 0.05,
            memoryWinMarginFraction: Double = 0.05
        ) {
            self.minSamples = minSamples
            self.minDistinctDevices = minDistinctDevices
            self.maxAcceptableMAE = maxAcceptableMAE
            self.requiredLabelAgreementRate = requiredLabelAgreementRate
            self.latencyWinMarginFraction = latencyWinMarginFraction
            self.memoryWinMarginFraction = memoryWinMarginFraction
        }

        public static let `default` = Thresholds()
    }

    // MARK: - Verdict

    public enum Recommendation: String, Equatable, Sendable, Codable {
        /// Candidate provably WINS on parity AND latency AND memory, with adequate samples across ≥2 devices.
        case migrate
        /// Candidate LOSES (regresses) on ≥1 dimension, OR has full evidence but no net benefit (a tie).
        case doNotMigrate
        /// Cannot decide — a required dimension was not measured, or sample / device coverage is below the bar.
        case insufficientEvidence
    }

    /// Stable, machine-readable reason codes (logged verbatim into the shadow / audit trail). The verdict
    /// always carries the FULL set that applied, sorted, so a reader sees exactly why it landed where it did.
    public enum Reason {
        public static let parityMet = "PARITY_MET"
        public static let parityFailedLabel = "PARITY_FAILED_LABEL"
        public static let parityFailedMAE = "PARITY_FAILED_MAE"
        public static let parityNoEvidence = "PARITY_NO_EVIDENCE"
        public static let latencyWin = "LATENCY_WIN"
        public static let latencyLoss = "LATENCY_LOSS"
        public static let latencyTie = "LATENCY_TIE"
        public static let latencyNoEvidence = "LATENCY_NO_EVIDENCE"
        public static let memoryWin = "MEMORY_WIN"
        public static let memoryLoss = "MEMORY_LOSS"
        public static let memoryTie = "MEMORY_TIE"
        public static let memoryNoEvidence = "MEMORY_NO_EVIDENCE"
        public static let samplesBelowMin = "SAMPLES_BELOW_MIN"
        public static let devicesBelowMin = "DEVICES_BELOW_MIN"
    }

    public struct Verdict: Equatable, Sendable {
        public let recommendation: Recommendation
        public let reasonCodes: [String]
        public let evidence: Evidence

        public init(recommendation: Recommendation, reasonCodes: [String], evidence: Evidence) {
            self.recommendation = recommendation
            self.reasonCodes = reasonCodes
            self.evidence = evidence
        }
    }

    // MARK: - Per-dimension evaluation

    private enum ParityStatus { case met, failed, noEvidence }
    private enum CompareStatus { case win, loss, tie, noEvidence }

    private struct DimensionOutcome {
        let parity: ParityStatus
        let latency: CompareStatus
        let memory: CompareStatus
    }

    private static func evaluateParity(
        _ p: BASCoreAIShadowComparison.ParitySummary, _ t: Thresholds
    ) -> (ParityStatus, [String]) {
        // No comparable logits (or no samples at all) ⇒ we cannot certify parity, full stop.
        guard p.sampleCount > 0, p.maeSampleCount > 0, let maxMAE = p.maxLogitsMAE else {
            return (.noEvidence, [Reason.parityNoEvidence])
        }
        var reasons: [String] = []
        if p.labelAgreementRate < t.requiredLabelAgreementRate { reasons.append(Reason.parityFailedLabel) }
        // NaN-SAFE comparison: `!(x <= ε)` is TRUE for NaN, so a corrupted (non-finite) max MAE FAILS parity.
        // The naive `x > ε` is FALSE for NaN (IEEE-754) and would mislabel NaN-corrupted logits as PARITY_MET —
        // letting a candidate that emits NaN reach `.migrate`. Defense-in-depth with aggregate's non-finite guard.
        if !(maxMAE <= t.maxAcceptableMAE) { reasons.append(Reason.parityFailedMAE) }
        if reasons.isEmpty { return (.met, [Reason.parityMet]) }
        return (.failed, reasons)
    }

    /// A lower-is-better paired metric (latency ms, memory bytes). WIN iff candidate clears the margin; LOSS
    /// iff candidate is strictly worse; TIE iff within the margin band (measured, but no meaningful benefit).
    private static func evaluateLowerIsBetter(
        candidate: Double?, incumbent: Double?, marginFraction: Double,
        win: String, loss: String, tie: String, noEvidence: String
    ) -> (CompareStatus, [String]) {
        guard let c = candidate, let i = incumbent, i > 0, c >= 0 else {
            return (.noEvidence, [noEvidence])
        }
        if c <= i * (1 - marginFraction) { return (.win, [win]) }
        if c > i { return (.loss, [loss]) }
        return (.tie, [tie])
    }

    // MARK: - The gate (strict, default-deny)

    /// Decide migrate / don't-migrate / insufficient from `evidence` against `thresholds`. Pure + total +
    /// deterministic. Priority (highest first):
    ///   1. any proven LOSS (regression)            → `.doNotMigrate`   (decisive — never migrate into a regression)
    ///   2. any NO_EVIDENCE / below-min coverage     → `.insufficientEvidence`
    ///   3. WIN on every dimension                   → `.migrate`
    ///   4. full evidence, no loss, but ≥1 tie       → `.doNotMigrate`   (no net benefit — don't churn)
    public static func decide(evidence: Evidence, thresholds: Thresholds = .default) -> Verdict {
        let (parity, parityReasons) = evaluateParity(evidence.parity, thresholds)
        let (latency, latencyReasons) = evaluateLowerIsBetter(
            candidate: evidence.candidateMeanLatencyMillis, incumbent: evidence.incumbentMeanLatencyMillis,
            marginFraction: thresholds.latencyWinMarginFraction,
            win: Reason.latencyWin, loss: Reason.latencyLoss,
            tie: Reason.latencyTie, noEvidence: Reason.latencyNoEvidence)
        let (memory, memoryReasons) = evaluateLowerIsBetter(
            candidate: evidence.candidatePeakMemoryBytes.map(Double.init),
            incumbent: evidence.incumbentPeakMemoryBytes.map(Double.init),
            marginFraction: thresholds.memoryWinMarginFraction,
            win: Reason.memoryWin, loss: Reason.memoryLoss,
            tie: Reason.memoryTie, noEvidence: Reason.memoryNoEvidence)

        var reasons = parityReasons + latencyReasons + memoryReasons
        let samplesShort = evidence.parity.sampleCount < thresholds.minSamples
        let devicesShort = evidence.distinctDeviceCount < thresholds.minDistinctDevices
        if samplesShort { reasons.append(Reason.samplesBelowMin) }
        if devicesShort { reasons.append(Reason.devicesBelowMin) }

        let outcome = DimensionOutcome(parity: parity, latency: latency, memory: memory)
        let recommendation = resolve(outcome, samplesShort: samplesShort, devicesShort: devicesShort)
        return Verdict(
            recommendation: recommendation,
            reasonCodes: reasons.sorted(),
            evidence: evidence)
    }

    private static func resolve(
        _ o: DimensionOutcome, samplesShort: Bool, devicesShort: Bool
    ) -> Recommendation {
        let hasLoss = o.parity == .failed || o.latency == .loss || o.memory == .loss
        if hasLoss { return .doNotMigrate }   // a known regression is decisive, regardless of other gaps

        let hasGap = o.parity == .noEvidence || o.latency == .noEvidence || o.memory == .noEvidence
            || samplesShort || devicesShort
        if hasGap { return .insufficientEvidence }

        let allWin = o.parity == .met && o.latency == .win && o.memory == .win
        if allWin { return .migrate }

        // Full evidence, no loss, but at least one tie ⇒ measured no-net-benefit ⇒ don't pay migration cost.
        return .doNotMigrate
    }
}
