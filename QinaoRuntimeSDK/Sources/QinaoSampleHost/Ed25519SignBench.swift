import Foundation
import CryptoKit
import BASObservability
import BASSovereign

/// M380 — diagnostic bench isolating Ed25519 signing latency
/// from the rest of `BASSovereignAuditLedger.append(_:)` machinery.
///
/// Pre-M380 chapter 八十二.5 / 八十三.4 audit-ledger-bench measured
/// **outlier rate 1-3%** (vs 0.27% normal) on per-entry latency —
/// bimodal distribution, no diagnosis. Chapter 八十四.6 evolution log
/// flagged this as Open Opportunity C; chapter 八十五 ship of M375
/// `BASBenchHighResClock` made it actually investigable.
///
/// This bench drives `Curve25519.Signing.PrivateKey.signature(for:)`
/// in isolation 10K times. Comparing the resulting distribution to
/// the audit-ledger-bench distribution tells us:
///
/// - If Ed25519 alone shows 1-3% outliers → spike source is the
///   crypto primitive itself (likely OS-level entropy / fault-attack
///   randomness adding jitter to non-deterministic Ed25519 in
///   CryptoKit)
/// - If Ed25519 shows a clean distribution (< 0.5% outliers) → the
///   spike is downstream of signing (in-memory bookkeeping in the
///   ledger actor, dictionary/array growth, ARC pressure, etc.)
///
/// ## Doctrine — REGRESSION ALARM, NOT AN SLA
///
/// Inherits the M340 scope statement. Numbers measure pure
/// in-process Ed25519 signing on fixed input — no I/O, no network,
/// no ledger machinery. Signing throughput on Apple Silicon is
/// hardware-accelerated; numbers are useful for cross-revision
/// comparison only.
package struct Ed25519SignBench {

    package static let scopeStatement: String =
        "[scope] regression alarm, not an SLA. measures " +
        "pure in-process Ed25519 signing via " +
        "Curve25519.Signing.PrivateKey.signature(for:) — no " +
        "ledger machinery, no I/O, no actor hops. diagnostic " +
        "for chapter 八十四.6 Open Opportunity C audit-ledger " +
        "outlier-rate investigation. do not quote these " +
        "numbers as customer-facing latency."

    package struct Outcome: Sendable, Equatable {
        package let signCount: Int
        package let payloadBytes: Int
        package let elapsedSeconds: Double
        package let outcome: BASBenchWarmupOutcome
        package init(
            signCount: Int,
            payloadBytes: Int,
            elapsedSeconds: Double,
            outcome: BASBenchWarmupOutcome
        ) {
            self.signCount = signCount
            self.payloadBytes = payloadBytes
            self.elapsedSeconds = elapsedSeconds
            self.outcome = outcome
        }
    }

    /// Drive `signCount` Ed25519 signatures over the canonical
    /// 446-byte L13 input. Reports per-signature latency in
    /// milliseconds with M361 cold/warm split (first sample is
    /// cold; rest are warm).
    package static func run(
        signCount: Int = 10_000
    ) throws -> Outcome {
        let keyPair = try BASSovereignEd25519KeyPair
            .fromSeed("bench-m380-seed")
        let payload = Data(
            SHA256Bench.canonicalInput.utf8)

        var samplesMs = [Double]()
        samplesMs.reserveCapacity(signCount)
        let clock = BASBenchHighResClock()
        let startWall = Date()
        for _ in 0..<signCount {
            let elapsedMs = try clock
                .measureMilliseconds {
                    _ = try keyPair.privateKey
                        .signature(for: payload)
                }
            samplesMs.append(Swift.max(0, elapsedMs))
        }
        let elapsedSeconds = Date()
            .timeIntervalSince(startWall)

        let warmupOutcome = BASBenchWarmupOutcome.compute(
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
            signCount: signCount,
            payloadBytes: payload.count,
            elapsedSeconds: elapsedSeconds,
            outcome: warmupOutcome)
    }
}
