// MARK: - BASSpeculativeMigrationVerdict
//
// 结构大重构 — Phase 5. The speculative-decoding ENABLE gate, in executable form. Mirrors
// `BASCoreAIMigrationVerdict` (same default-deny doctrine), adapted to spec-decode's dimensions: CORRECTNESS
// (greedy token-identity / sampling distribution-equivalence), LATENCY (speculative vs single-model baseline —
// must WIN), and MEMORY FIT (dual residency must fit a device budget — speculative decoding INCREASES memory, so
// the gate checks it doesn't OOM, not that it beats the incumbent).
//
// ## Why default-deny (亏的不要)
//
// Speculative decoding pays a real cost (a second resident model, more memory, verify overhead). It is worth
// enabling ONLY when it provably WINS on latency WITHOUT breaking correctness or exceeding the memory budget,
// with adequate samples across ≥2 devices. A correctness failure is decisive (a faster wrong answer is worse
// than a correct slow one). A latency TIE is no benefit (don't pay the cost). A memory OVERFLOW is a loss (it
// OOMs/wedges). A MISSING dimension is never a win (we cannot certify what we did not measure).
//
// ## Guardrails (红线 7 / observation-only)
//
// PURE + framework-free + deterministic. It never runs a model, never flips the `speculativeDecoding` flag,
// never auto-enables — its output is a recommendation a HUMAN reads. Reasoning-side; BANNED from the
// byte-deterministic spine (`BASMetalDeterminismBoundaryTests`).

import Foundation

public enum BASSpeculativeMigrationVerdict {

    // MARK: - Evidence

    /// Aggregated, multi-sample, multi-device evidence the gate judges. Latency is a PAIRED speculative-vs-baseline
    /// mean; memory is the dual-residency peak measured against a device budget. `nil` fields mean "not measured"
    /// (→ NO_EVIDENCE → never a win).
    public struct Evidence: Equatable, Sendable {
        /// "greedy" or "sampling" — drives the correctness semantics in the rendered report (token-identity vs
        /// distribution-equivalence). Advisory; the gate logic is identical for both.
        public let mode: String
        /// Greedy: did the speculative stream match greedy target-only token-for-token? Sampling: was the emitted
        /// distribution within the equivalence tolerance? nil ⇒ not measured.
        public let correctnessVerified: Bool?
        /// Observed mean draft-acceptance rate (diagnostic only — a low rate manifests as a latency loss/tie,
        /// which the latency dimension already gates).
        public let acceptanceRate: Double?
        public let speculativeMeanLatencyMillis: Double?
        public let baselineMeanLatencyMillis: Double?
        /// Peak resident bytes with BOTH models loaded (target + draft).
        public let dualPeakMemoryBytes: Int?
        /// The device memory budget the dual residency must fit under (e.g. an 8 GB device's safe ceiling).
        public let memoryBudgetBytes: Int?
        public let sampleCount: Int
        /// AUDIT FIX: how many of the samples carry a PAIRED speculative+baseline latency. Unpaired records
        /// contribute correctness but no latency evidence — without this floor, unpaired records could inflate
        /// `sampleCount` past `minSamples` while the latency means rest on a tiny paired subset.
        public let pairedLatencySampleCount: Int
        public let distinctDeviceCount: Int

        public init(
            mode: String,
            correctnessVerified: Bool? = nil,
            acceptanceRate: Double? = nil,
            speculativeMeanLatencyMillis: Double? = nil,
            baselineMeanLatencyMillis: Double? = nil,
            dualPeakMemoryBytes: Int? = nil,
            memoryBudgetBytes: Int? = nil,
            sampleCount: Int = 0,
            pairedLatencySampleCount: Int = 0,
            distinctDeviceCount: Int = 0
        ) {
            self.mode = mode
            self.correctnessVerified = correctnessVerified
            self.acceptanceRate = acceptanceRate
            self.speculativeMeanLatencyMillis = speculativeMeanLatencyMillis
            self.baselineMeanLatencyMillis = baselineMeanLatencyMillis
            self.dualPeakMemoryBytes = dualPeakMemoryBytes
            self.memoryBudgetBytes = memoryBudgetBytes
            self.sampleCount = sampleCount
            self.pairedLatencySampleCount = pairedLatencySampleCount
            self.distinctDeviceCount = distinctDeviceCount
        }
    }

    // MARK: - Thresholds

    public struct Thresholds: Equatable, Sendable {
        public let minSamples: Int
        public let minDistinctDevices: Int
        /// Speculative mean must be `<= baseline * (1 - margin)` to count as a WIN (a within-noise improvement
        /// or a tie is not enough to justify the dual-residency cost).
        public let latencyWinMarginFraction: Double

        public init(
            minSamples: Int = 50,
            minDistinctDevices: Int = 2,
            latencyWinMarginFraction: Double = 0.05
        ) {
            self.minSamples = minSamples
            self.minDistinctDevices = minDistinctDevices
            self.latencyWinMarginFraction = latencyWinMarginFraction
        }

        public static let `default` = Thresholds()
    }

    // MARK: - Verdict

    public enum Recommendation: String, Equatable, Sendable, Codable {
        /// Speculative decoding provably WINS on latency, correctness holds, AND it fits memory — across ≥2 devices.
        case enable
        /// Correctness failed, latency regressed/tied, OR memory overflowed — a net-negative or no-benefit.
        case doNotEnable
        /// A required dimension was not measured, or sample / device coverage is below the bar.
        case insufficientEvidence
    }

    public enum Reason {
        public static let correctnessVerified = "CORRECTNESS_VERIFIED"
        public static let correctnessFailed = "CORRECTNESS_FAILED"
        public static let correctnessNoEvidence = "CORRECTNESS_NO_EVIDENCE"
        public static let latencyWin = "LATENCY_WIN"
        public static let latencyLoss = "LATENCY_LOSS"
        public static let latencyTie = "LATENCY_TIE"
        public static let latencyNoEvidence = "LATENCY_NO_EVIDENCE"
        public static let memoryFits = "MEMORY_FITS"
        public static let memoryExceeds = "MEMORY_EXCEEDS"
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

    private enum CorrectnessStatus { case met, failed, noEvidence }
    private enum CompareStatus { case win, loss, tie, noEvidence }
    private enum FitStatus { case fits, exceeds, noEvidence }

    private static func evaluateCorrectness(_ verified: Bool?) -> (CorrectnessStatus, [String]) {
        switch verified {
        case .none: return (.noEvidence, [Reason.correctnessNoEvidence])
        case .some(false): return (.failed, [Reason.correctnessFailed])
        case .some(true): return (.met, [Reason.correctnessVerified])
        }
    }

    /// Latency is lower-is-better (speculative vs baseline). WIN iff speculative clears the margin; LOSS iff
    /// strictly worse; TIE iff within the margin band.
    private static func evaluateLatency(
        speculative: Double?, baseline: Double?, marginFraction: Double
    ) -> (CompareStatus, [String]) {
        guard let s = speculative, let b = baseline, b > 0, s >= 0 else {
            return (.noEvidence, [Reason.latencyNoEvidence])
        }
        if s <= b * (1 - marginFraction) { return (.win, [Reason.latencyWin]) }
        if s > b { return (.loss, [Reason.latencyLoss]) }
        return (.tie, [Reason.latencyTie])
    }

    /// Memory FIT: the dual-residency peak must be within the device budget. (Unlike a migration's
    /// lower-is-better memory, speculative decoding is EXPECTED to use more — the gate only refuses an OVERFLOW.)
    /// AUDIT FIX: `peak > 0` (was `>= 0`) — a ZERO peak is a missing measurement (MLX stats unavailable /
    /// simulator), not a fit; letting 0 through made MEMORY_FITS vacuously true with no data.
    private static func evaluateMemoryFit(dualPeak: Int?, budget: Int?) -> (FitStatus, [String]) {
        guard let peak = dualPeak, let budget, budget > 0, peak > 0 else {
            return (.noEvidence, [Reason.memoryNoEvidence])
        }
        return peak <= budget ? (.fits, [Reason.memoryFits]) : (.exceeds, [Reason.memoryExceeds])
    }

    // MARK: - The gate (strict, default-deny)

    /// Decide enable / don't-enable / insufficient. Pure + total + deterministic. Priority (highest first):
    ///   1. correctness FAILED, latency LOSS, or memory EXCEEDS → `.doNotEnable` (decisive — net-negative)
    ///   2. any NO_EVIDENCE / below-min coverage                → `.insufficientEvidence`
    ///   3. correctness MET + latency WIN + memory FITS          → `.enable`
    ///   4. full evidence, no loss, but a latency TIE            → `.doNotEnable` (no net benefit — don't pay the cost)
    public static func decide(evidence: Evidence, thresholds: Thresholds = .default) -> Verdict {
        let (correctness, correctnessReasons) = evaluateCorrectness(evidence.correctnessVerified)
        let (latency, latencyReasons) = evaluateLatency(
            speculative: evidence.speculativeMeanLatencyMillis,
            baseline: evidence.baselineMeanLatencyMillis,
            marginFraction: thresholds.latencyWinMarginFraction)
        let (memory, memoryReasons) = evaluateMemoryFit(
            dualPeak: evidence.dualPeakMemoryBytes, budget: evidence.memoryBudgetBytes)

        var reasons = correctnessReasons + latencyReasons + memoryReasons
        // AUDIT FIX: the sample floor also binds the PAIRED latency count whenever latency evidence exists —
        // unpaired records must not inflate the count past minSamples while the latency means rest on fewer pairs.
        let samplesShort = evidence.sampleCount < thresholds.minSamples
            || (latency != .noEvidence && evidence.pairedLatencySampleCount < thresholds.minSamples)
        let devicesShort = evidence.distinctDeviceCount < thresholds.minDistinctDevices
        if samplesShort { reasons.append(Reason.samplesBelowMin) }
        if devicesShort { reasons.append(Reason.devicesBelowMin) }

        let hasLoss = correctness == .failed || latency == .loss || memory == .exceeds
        let recommendation: Recommendation
        if hasLoss {
            recommendation = .doNotEnable   // a known regression is decisive, regardless of other gaps
        } else {
            let hasGap = correctness == .noEvidence || latency == .noEvidence || memory == .noEvidence
                || samplesShort || devicesShort
            if hasGap {
                recommendation = .insufficientEvidence
            } else if correctness == .met && latency == .win && memory == .fits {
                recommendation = .enable
            } else {
                // Full evidence, no loss, but a tie ⇒ measured no-net-benefit ⇒ don't enable.
                recommendation = .doNotEnable
            }
        }

        return Verdict(
            recommendation: recommendation,
            reasonCodes: reasons.sorted(),
            evidence: evidence)
    }
}
