import Foundation
import BASLeaseLife
import BASMemory
import BASRuntimeCore

/// M334 — throughput + thermal/breath quantification bench.
///
/// Drives N turns of representative substrate work (lifecycle
/// transitions + thermal/breath cycling) under a `BASLeaseLife
/// Coordinator` and reports:
///
///   - Per-turn latency (p50 / p95 / p99 / min / max / mean) in
///     milliseconds.
///   - Thermal evolution: lung pressure trajectory + guardLevel
///     escalation history + cancelledBreath counter.
///
/// Pre-M334 the M179 perf test (in
/// `QinaoRuntime14LayerSaturationTests`) measured the observation
/// pipeline at 100 fully-loaded turns (p95 ~1.16 ms baseline).
/// M334 ships a sample-host equivalent so hosts can measure the
/// same envelope on their own hardware without going through
/// XCTest. Default = 100 turns; override via
/// `QINAO_BENCH_TURN_COUNT=N`.
///
/// ## Doctrine
///
/// - **Regression alarm, not perf goal.** Same model as M179:
///   p95 < 100ms ceiling exists to alarm if a new dependency
///   adds slow I/O on the hot path. Tight ceilings would invite
///   premature optimization.
/// - **No model inference.** The bench drives lifecycle + thermal
///   state, not LLM inference. Real-model latency is the
///   `--multi-turn-demo` (M314 + M325) territory.
/// - **Pure self-contained workload.** Each turn does a fixed
///   value-type lifecycle traversal; no actor crossing, no IO.
///   This makes the latency reproducible across runs.
public struct ThroughputBenchDemo {

    public struct LatencyStats: Sendable, Equatable {
        public let count: Int
        public let min: Double
        public let max: Double
        public let mean: Double
        public let p50: Double
        public let p95: Double
        public let p99: Double

        public init(
            count: Int, min: Double, max: Double,
            mean: Double, p50: Double, p95: Double,
            p99: Double
        ) {
            self.count = count
            self.min = min
            self.max = max
            self.mean = mean
            self.p50 = p50
            self.p95 = p95
            self.p99 = p99
        }

        /// Compute stats from a list of latencies (any order;
        /// internally sorted). Returns nil for empty input.
        public static func compute(
            latenciesMs: [Double]
        ) -> LatencyStats? {
            guard !latenciesMs.isEmpty else { return nil }
            let sorted = latenciesMs.sorted()
            let n = sorted.count
            let sum = sorted.reduce(0, +)
            return LatencyStats(
                count: n,
                min: sorted.first!,
                max: sorted.last!,
                mean: sum / Double(n),
                p50: percentile(sorted: sorted, p: 0.50),
                p95: percentile(sorted: sorted, p: 0.95),
                p99: percentile(sorted: sorted, p: 0.99))
        }

        /// Nearest-rank percentile (mirror M179
        /// `LatencyStats.percentile`). Use `Swift.min`/`Swift.max`
        /// explicitly because the enclosing struct shadows
        /// `min`/`max` as stored properties.
        private static func percentile(
            sorted: [Double], p: Double
        ) -> Double {
            let n = sorted.count
            let idx = Swift.max(
                0,
                Swift.min(
                    n - 1,
                    Int(ceil(p * Double(n))) - 1))
            return sorted[idx]
        }
    }

    public struct ThermalCycleStats: Sendable, Equatable {
        public let firstPressure: Double
        public let finalPressure: Double
        public let peakPressure: Double
        public let firstGuardLevel: String
        public let finalGuardLevel: String
        public let guardEscalations: Int
        public let cancelledBreathTotal: Int

        public init(
            firstPressure: Double,
            finalPressure: Double,
            peakPressure: Double,
            firstGuardLevel: String,
            finalGuardLevel: String,
            guardEscalations: Int,
            cancelledBreathTotal: Int
        ) {
            self.firstPressure = firstPressure
            self.finalPressure = finalPressure
            self.peakPressure = peakPressure
            self.firstGuardLevel = firstGuardLevel
            self.finalGuardLevel = finalGuardLevel
            self.guardEscalations = guardEscalations
            self.cancelledBreathTotal = cancelledBreathTotal
        }
    }

    public struct Outcome: Sendable, Equatable {
        public let turnCount: Int
        public let elapsedSeconds: Double
        public let latency: LatencyStats
        public let thermal: ThermalCycleStats

        public init(
            turnCount: Int,
            elapsedSeconds: Double,
            latency: LatencyStats,
            thermal: ThermalCycleStats
        ) {
            self.turnCount = turnCount
            self.elapsedSeconds = elapsedSeconds
            self.latency = latency
            self.thermal = thermal
        }
    }

    /// Drive the bench. Each turn:
    ///   1. Start a ContinuousClock timer.
    ///   2. Run a deterministic lifecycle traversal (12
    ///      transitions across promote+retract / failure /
    ///      withdrawal paths) — representative substrate work.
    ///   3. Measure elapsed time in ms.
    ///   4. Call `leaseLife.recordTurn(.engage,
    ///      durationSeconds: elapsedSec)` to feed the thermal
    ///      twin.
    ///   5. Capture the resulting `TurnRecorded` for thermal
    ///      stats.
    public static func run(
        turnCount: Int = 100
    ) async -> Outcome {
        let leaseLife = BASLeaseLifeCoordinator.makeDefault()
        var latencies: [Double] = []
        latencies.reserveCapacity(turnCount)
        var thermalReadings: [BASThermalTwin.Reading] = []
        thermalReadings.reserveCapacity(turnCount)
        var cancelledBreathTotal = 0

        let started = ContinuousClock().now
        for _ in 0..<turnCount {
            let turnStart = ContinuousClock().now
            // Deterministic representative workload —
            // 12 lifecycle transitions across 3 paths.
            self.runRepresentativeWork()
            let turnElapsed = ContinuousClock().now - turnStart
            let turnElapsedMs = Self.toMilliseconds(
                turnElapsed)
            let turnElapsedSec = turnElapsedMs / 1000.0
            latencies.append(turnElapsedMs)

            let recorded = await leaseLife.recordTurn(
                runMode: .engage,
                durationSeconds: turnElapsedSec)
            thermalReadings.append(recorded.thermal)
            cancelledBreathTotal += recorded
                .cancelledBreathIDs.count
        }
        let elapsed = ContinuousClock().now - started
        let elapsedSec = Self.toMilliseconds(elapsed) / 1000.0

        // Compute stats. We know latencies is non-empty since
        // turnCount > 0 in default; guard anyway for safety.
        let latency = LatencyStats.compute(
            latenciesMs: latencies)
            ?? LatencyStats(
                count: 0, min: 0, max: 0, mean: 0,
                p50: 0, p95: 0, p99: 0)
        let thermal = Self.computeThermalStats(
            readings: thermalReadings,
            cancelledBreathTotal: cancelledBreathTotal)
        return Outcome(
            turnCount: turnCount,
            elapsedSeconds: elapsedSec,
            latency: latency,
            thermal: thermal)
    }

    /// Representative deterministic workload — chains 3 lifecycle
    /// paths (full promotion / failure / withdrawal). Total = 9
    /// applying() calls + a few aggregate computations.
    private static func runRepresentativeWork() {
        // Path 1: full promotion path (4 transitions).
        var s1 = BASEvolutionLifecycleSession(
            candidateID: "bench-promote")
        s1 = s1.applying(.registerCandidate)!
            .applying(.startShadowTrial)!
            .applying(.finalizeTrial)!
            .applying(.promote)!
        // Path 2: failure (3 transitions).
        var s2 = BASEvolutionLifecycleSession(
            candidateID: "bench-fail")
        s2 = s2.applying(.registerCandidate)!
            .applying(.startShadowTrial)!
            .applying(.fail)!
        // Path 3: withdrawal (1 transition).
        var s3 = BASEvolutionLifecycleSession(
            candidateID: "bench-withdraw")
        s3 = s3.applying(.withdraw)!
        // Aggregate over 3 sessions.
        _ = BASEvolutionLifecycleSession.aggregate(
            [s1, s2, s3])
    }

    private static func computeThermalStats(
        readings: [BASThermalTwin.Reading],
        cancelledBreathTotal: Int
    ) -> ThermalCycleStats {
        guard let first = readings.first,
              let last = readings.last
        else {
            return ThermalCycleStats(
                firstPressure: 0,
                finalPressure: 0,
                peakPressure: 0,
                firstGuardLevel: "n/a",
                finalGuardLevel: "n/a",
                guardEscalations: 0,
                cancelledBreathTotal: cancelledBreathTotal)
        }
        let peak = readings.map(\.accumulatedPressure).max()
            ?? 0
        // Count guardLevel escalations: each transition where
        // adjacent reading's guardLevel changes counts. Rough
        // proxy for "thermal volatility".
        var escalations = 0
        var lastLevel = first.guardLevel
        for r in readings.dropFirst() {
            if r.guardLevel != lastLevel {
                escalations += 1
                lastLevel = r.guardLevel
            }
        }
        return ThermalCycleStats(
            firstPressure: first.accumulatedPressure,
            finalPressure: last.accumulatedPressure,
            peakPressure: peak,
            firstGuardLevel: first.guardLevel.rawValue,
            finalGuardLevel: last.guardLevel.rawValue,
            guardEscalations: escalations,
            cancelledBreathTotal: cancelledBreathTotal)
    }

    private static func toMilliseconds(
        _ d: Duration
    ) -> Double {
        let comps = d.components
        return Double(comps.seconds) * 1000.0
            + Double(comps.attoseconds) / 1.0e15
    }
}
