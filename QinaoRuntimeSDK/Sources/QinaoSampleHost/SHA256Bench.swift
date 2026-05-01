import Foundation
import BASMemory
import BASObservability

/// M364 — bench mode for the M341 pure-Swift SHA-256 hasher
/// throughput.
///
/// `BASEvolutionLifecycleStructuralFingerprintHasher.sha256Hex`
/// is the load-bearing hash for the L13 v6 doctrine
/// regression-gate fingerprint. M364 measures its throughput on
/// a representative input size (the L13 canonical encoding ~440
/// bytes) so any future refactor that pessimizes the hash
/// (switching to CryptoKit, adding bounds checks, etc.) shows up
/// as a regression.
///
/// ## Doctrine — REGRESSION ALARM, NOT AN SLA
///
/// Inherits the M340 scope statement. Numbers measure pure
/// in-process SHA-256 over a fixed input — no I/O, no actor
/// hops. Sub-µs floor reference for cryptographic primitives.
public struct SHA256Bench {

    public static let scopeStatement: String =
        "[scope] regression alarm, not an SLA. measures " +
        "pure in-process SHA-256 hasher (M341 pure-Swift " +
        "implementation) — no I/O, no actor hops. " +
        "sub-µs floor for cryptographic primitives. do not " +
        "quote these numbers as customer-facing latency."

    /// Representative input — the L13 canonical encoding
    /// (chapter 八十一.3 verified against Python hashlib).
    /// 446 bytes UTF-8.
    public static let canonicalInput =
        "candidateRegistered|startShadowTrial=" +
        "shadowTrialing;candidateRegistered|" +
        "withdraw=withdrawn;promoted|retract=retracted;" +
        "proposed|registerCandidate=candidateRegistered;" +
        "proposed|withdraw=withdrawn;rejected|" +
        "<terminal>;retracted|<terminal>;shadowTrialing|" +
        "fail=rejected;shadowTrialing|" +
        "finalizeTrial=trialFinalized;shadowTrialing|" +
        "withdraw=withdrawn;trialFinalized|" +
        "fail=rejected;trialFinalized|promote=promoted;" +
        "trialFinalized|withdraw=withdrawn;withdrawn|" +
        "<terminal>"

    public struct Outcome: Sendable, Equatable {
        public let hashCount: Int
        public let inputBytes: Int
        public let elapsedSeconds: Double
        public let outcome: BASBenchWarmupOutcome
        public init(
            hashCount: Int,
            inputBytes: Int,
            elapsedSeconds: Double,
            outcome: BASBenchWarmupOutcome
        ) {
            self.hashCount = hashCount
            self.inputBytes = inputBytes
            self.elapsedSeconds = elapsedSeconds
            self.outcome = outcome
        }
    }

    /// Compute SHA-256 over the canonical input N times.
    /// Reports per-hash latency in milliseconds (consistent
    /// with all other bench modes for suite uniformity).
    public static func run(
        hashCount: Int = 100_000
    ) -> Outcome {
        var samplesMs: [Double] = []
        samplesMs.reserveCapacity(hashCount)
        let input = canonicalInput
        let startWall = Date()
        for _ in 0..<hashCount {
            let t0 = Date()
            _ = BASEvolutionLifecycleStructuralFingerprint
                .sha256Hex(of: input)
            let elapsedMs = Date()
                .timeIntervalSince(t0) * 1_000.0
            samplesMs.append(Swift.max(0, elapsedMs))
        }
        let elapsedSeconds = Date()
            .timeIntervalSince(startWall)
        let outcome = BASBenchWarmupOutcome.compute(
            samples: samplesMs,
            config: .strictFirstSample)
            ?? BASBenchWarmupOutcome(
                combined: BASBenchLatencyStats(
                    sampleCount: 0, min: 0, max: 0,
                    mean: 0, p50: 0, p95: 0, p99: 0,
                    p999: 0,
                    standardDeviation: 0,
                    outlierCount: 0),
                cold: nil, warm: nil,
                config: .strictFirstSample)
        return Outcome(
            hashCount: hashCount,
            inputBytes: input.utf8.count,
            elapsedSeconds: elapsedSeconds,
            outcome: outcome)
    }
}
