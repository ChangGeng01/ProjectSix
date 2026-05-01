import Foundation
import BASMemory
import BASObservability

/// M363 — bench mode for L13 lifecycle state-machine traversal
/// throughput.
///
/// Pure value-type `BASEvolutionLifecycleSession.applying(_:)`
/// transitions are sub-microsecond by construction (no I/O, no
/// actor crossing, immutable struct copy). M363 measures the
/// per-transition cost as a substrate-internal floor reference —
/// any future PR that pushes transition cost into the µs-or-larger
/// territory regresses against this baseline.
///
/// ## Doctrine — REGRESSION ALARM, NOT AN SLA
///
/// Inherits the M340 scope statement. Numbers measure pure
/// in-process value-type lifecycle traversal — no audit ledger
/// I/O, no AFM inference, no actor hops. This is the sub-µs
/// floor reference for the bench suite.
///
/// ## Output
///
/// `BASBenchWarmupOutcome` (M361) with cold/warm split. Cold
/// samples (typically the first one) capture allocator/JIT
/// warmup; warm samples reflect steady-state.
public struct LifecycleBench {

    public static let scopeStatement: String =
        "[scope] regression alarm, not an SLA. measures " +
        "pure in-process value-type L13 lifecycle " +
        "traversal — no audit ledger I/O, no AFM " +
        "inference, no actor hops. sub-µs floor reference. " +
        "do not quote these numbers as customer-facing latency."

    public struct Outcome: Sendable, Equatable {
        public let traversalCount: Int
        public let elapsedSeconds: Double
        public let outcome: BASBenchWarmupOutcome
        public init(
            traversalCount: Int,
            elapsedSeconds: Double,
            outcome: BASBenchWarmupOutcome
        ) {
            self.traversalCount = traversalCount
            self.elapsedSeconds = elapsedSeconds
            self.outcome = outcome
        }
    }

    /// Drive `traversalCount` complete promotion + retraction
    /// cycles (5 transitions per traversal: registerCandidate →
    /// startShadowTrial → finalizeTrial → promote → retract).
    /// Reports per-traversal latency in milliseconds (consistent
    /// with all other bench modes for suite uniformity; sub-µs
    /// values appear as e.g. 0.0040 ms).
    public static func run(
        traversalCount: Int = 100_000
    ) -> Outcome {
        var samplesMs: [Double] = []
        samplesMs.reserveCapacity(traversalCount)
        let startWall = Date()
        for index in 0..<traversalCount {
            let t0 = Date()
            traverseFullCycle(
                candidateID: "bench-\(index)")
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
            traversalCount: traversalCount,
            elapsedSeconds: elapsedSeconds,
            outcome: outcome)
    }

    /// Walk a single ticket through the full L13 lifecycle
    /// (proposed → ... → promoted → retracted). 5 transitions
    /// per call. Returns nothing — all state is discarded
    /// after the call.
    @discardableResult
    private static func traverseFullCycle(
        candidateID: String
    ) -> Bool {
        var session = BASEvolutionLifecycleSession(
            candidateID: candidateID)
        guard let s1 = session.applying(
            .registerCandidate) else { return false }
        session = s1
        guard let s2 = session.applying(
            .startShadowTrial) else { return false }
        session = s2
        guard let s3 = session.applying(
            .finalizeTrial) else { return false }
        session = s3
        guard let s4 = session.applying(.promote)
        else { return false }
        session = s4
        guard let s5 = session.applying(.retract)
        else { return false }
        session = s5
        return true
    }
}
