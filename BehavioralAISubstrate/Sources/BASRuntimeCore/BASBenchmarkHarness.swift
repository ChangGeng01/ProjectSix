// MARK: - BASBenchmarkHarness
// chapter 七百六 第一刀 / M2201
//
// Rigorous multi-iteration timing infrastructure for cross-
// language perf comparison。 The substrate's "if Swift is faster
// use Swift, if Rust is faster use Rust" routing decisions need
// statistically meaningful measurements — not a single noisy
// wall-clock read。
//
// ## Method
//
//   1. Warmup phase: run the workload N_warm times,discard
//      timings (prime caches,JIT,GPU pipelines)
//   2. Measurement phase: run R independent rounds,each round
//      executes the workload N_inner times,reports per-round
//      median per-iteration nanoseconds
//   3. Aggregate the R round-medians into min / median / p99 /
//      max / mean
//
// Per-iteration nanoseconds = round_wall_clock_ns / N_inner。
// Reporting per-iteration timing makes results comparable across
// workloads of different inherent durations。
//
// ## Statistical reliability
//
// Multiple rounds (default R=5) defeat thermal-throttling +
// scheduler noise that a single timer read can't see。 We take
// the MEDIAN of the per-round medians as the headline number —
// resistant to one outlier round。
//
// ## Surface
//
//   - BASBenchSummary  — typed result struct
//   - BASBenchmarkHarness.run(...) — generic over closure
//   - BASBenchmarkHarness.compare(...) — A/B helper that runs two
//     closures + reports which won + by what factor

import Foundation

/// Typed timing summary。 All values are PER-ITERATION nanoseconds
/// computed by dividing round wall-clock by `iterations`。
public struct BASBenchSummary:
    Sendable, Equatable, Hashable, Codable
{
    public let label: String
    public let rounds: Int
    public let iterationsPerRound: Int
    /// Smallest per-iteration ns observed across all rounds。
    public let minNsPerIter: Double
    /// Median of round-medians — the headline number。
    public let medianNsPerIter: Double
    /// 99th percentile estimated from round-maxes。
    public let p99NsPerIter: Double
    /// Largest per-iteration ns observed。
    public let maxNsPerIter: Double
    /// Mean of round-medians — useful for averaging across
    /// many summaries。
    public let meanNsPerIter: Double

    public init(
        label: String,
        rounds: Int,
        iterationsPerRound: Int,
        minNsPerIter: Double,
        medianNsPerIter: Double,
        p99NsPerIter: Double,
        maxNsPerIter: Double,
        meanNsPerIter: Double
    ) {
        self.label = label
        self.rounds = rounds
        self.iterationsPerRound = iterationsPerRound
        self.minNsPerIter = minNsPerIter
        self.medianNsPerIter = medianNsPerIter
        self.p99NsPerIter = p99NsPerIter
        self.maxNsPerIter = maxNsPerIter
        self.meanNsPerIter = meanNsPerIter
    }

    /// Human-readable single-line summary for printing in test
    /// output。 Format chosen to be grep-friendly。
    public var formatted: String {
        // %@ accepts Swift String via NSString bridge。 %s with
        // a Swift String segfaults at format-time (C expects
        // a NUL-terminated char *)。
        let labelPadded = label
            .padding(toLength: 36, withPad: " ",
                startingAt: 0)
        return String(
            format:
                "%@ %6d iters × %2d rounds — "
                + "min=%.0fns p50=%.0fns p99=%.0fns max=%.0fns",
            labelPadded as NSString,
            iterationsPerRound, rounds,
            minNsPerIter,
            medianNsPerIter,
            p99NsPerIter,
            maxNsPerIter)
    }
}

/// A/B comparison result — which implementation won and by
/// what multiple of speed。
public struct BASBenchCompareResult:
    Sendable, Equatable, Codable
{
    public enum Winner: String, Sendable, Codable {
        case a
        case b
        case tie
    }
    public let summaryA: BASBenchSummary
    public let summaryB: BASBenchSummary
    public let winner: Winner
    /// Speedup of the winner over the loser, computed as
    /// loser.median / winner.median。 1.0 means tie。
    public let speedupRatio: Double

    public var formatted: String {
        let winLabel: String
        switch winner {
        case .a:   winLabel = "A wins"
        case .b:   winLabel = "B wins"
        case .tie: winLabel = "TIE"
        }
        return "  → \(winLabel) (\(speedupRatio)x)\n"
            + "    \(summaryA.formatted)\n"
            + "    \(summaryB.formatted)"
    }
}

public enum BASBenchmarkHarness {

    /// Run a closure-based benchmark with warmup + multiple
    /// rounds + statistical aggregation。
    ///
    /// - Parameters:
    ///   - label: human-readable name for the summary
    ///   - warmup: warmup iterations (default 100)
    ///   - rounds: independent measurement rounds (default 5)
    ///   - iterations: inner-loop iterations per round (default
    ///     1000)
    ///   - body: closure to time。 Single iteration of the
    ///     workload。
    public static func run(
        label: String,
        warmup: Int = 100,
        rounds: Int = 5,
        iterations: Int = 1_000,
        body: () -> Void
    ) -> BASBenchSummary {
        // Warmup — prime caches, GPU pipelines, etc。
        for _ in 0..<warmup { body() }

        // R rounds, each measuring N_inner iterations。
        var roundMedians: [Double] = []
        var globalMin: Double = .infinity
        var globalMax: Double = 0

        for _ in 0..<rounds {
            // Collect per-batch timings inside the round so
            // we can take a robust per-round median。 We
            // bucket the N_inner iterations into 10 sub-batches。
            let batches = max(1, iterations / 10)
            let perBatchN = iterations / batches
            var batchTimings: [Double] = []
            batchTimings.reserveCapacity(batches)
            for _ in 0..<batches {
                let start =
                    DispatchTime.now().uptimeNanoseconds
                for _ in 0..<perBatchN { body() }
                let end = DispatchTime.now().uptimeNanoseconds
                let nsPerIter =
                    Double(end - start) / Double(perBatchN)
                batchTimings.append(nsPerIter)
                globalMin = min(globalMin, nsPerIter)
                globalMax = max(globalMax, nsPerIter)
            }
            batchTimings.sort()
            roundMedians.append(
                batchTimings[batchTimings.count / 2])
        }

        let sortedRoundMedians = roundMedians.sorted()
        let medianOfMedians =
            sortedRoundMedians[
                sortedRoundMedians.count / 2]
        let p99Index = max(0,
            Int(Double(sortedRoundMedians.count) * 0.99) - 1)
        let p99 = sortedRoundMedians[
            min(p99Index, sortedRoundMedians.count - 1)]
        let mean = roundMedians.reduce(0, +)
            / Double(roundMedians.count)

        return BASBenchSummary(
            label: label,
            rounds: rounds,
            iterationsPerRound: iterations,
            minNsPerIter: globalMin,
            medianNsPerIter: medianOfMedians,
            p99NsPerIter: p99,
            maxNsPerIter: globalMax,
            meanNsPerIter: mean)
    }

    /// A/B comparison — runs both closures with the same settings
    /// and decides the winner。 A is considered the winner if its
    /// median is ≥ 5% faster than B's;within ±5% is a tie。
    public static func compare(
        labelA: String, bodyA: () -> Void,
        labelB: String, bodyB: () -> Void,
        warmup: Int = 100,
        rounds: Int = 5,
        iterations: Int = 1_000
    ) -> BASBenchCompareResult {
        let a = run(
            label: labelA,
            warmup: warmup, rounds: rounds,
            iterations: iterations,
            body: bodyA)
        let b = run(
            label: labelB,
            warmup: warmup, rounds: rounds,
            iterations: iterations,
            body: bodyB)
        let aMed = a.medianNsPerIter
        let bMed = b.medianNsPerIter
        let winner: BASBenchCompareResult.Winner
        let ratio: Double
        if abs(aMed - bMed) / max(aMed, bMed) < 0.05 {
            winner = .tie
            ratio = 1.0
        } else if aMed < bMed {
            winner = .a
            ratio = bMed / aMed
        } else {
            winner = .b
            ratio = aMed / bMed
        }
        return BASBenchCompareResult(
            summaryA: a, summaryB: b,
            winner: winner, speedupRatio: ratio)
    }

    /// Tournament — N-way comparison across multiple
    /// implementations。 Returns the index of the winner +
    /// every summary。 Useful for "Swift vs Rust scalar vs
    /// Rust SIMD vs Metal" 4-way races。
    public static func tournament(
        warmup: Int = 100,
        rounds: Int = 5,
        iterations: Int = 1_000,
        contestants: [(label: String, body: () -> Void)]
    ) -> (winnerIndex: Int, summaries: [BASBenchSummary]) {
        var summaries: [BASBenchSummary] = []
        for c in contestants {
            summaries.append(run(
                label: c.label,
                warmup: warmup, rounds: rounds,
                iterations: iterations, body: c.body))
        }
        var bestIdx = 0
        var bestNs = summaries[0].medianNsPerIter
        for (i, s) in summaries.enumerated() {
            if s.medianNsPerIter < bestNs {
                bestNs = s.medianNsPerIter
                bestIdx = i
            }
        }
        return (bestIdx, summaries)
    }
}
