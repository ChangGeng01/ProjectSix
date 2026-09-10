// MARK: - BASChapter848TurnWorkloadPerfTests
// chapter 八百四十八 / M2891-M2895 — turn-workload-style perf
// validation
//
// The post-v0.61.0 perf chapters (八百三十七 dominance order,
// 八百四十二 sort flip cascade) measured each flip in isolation
// with single-sort micro-benches。 The strict review (chapter
// 八百四十五 self-review,八百四十七 remediation) called out that
// "5-7 ms saved per turn" is a synthetic estimate compounding
// per-site measurements,not a measured per-turn workload。
//
// This chapter ships a HONEST cumulative measurement:simulate
// one realistic turn that exercises all 7 production flip
// sites at representative sizes,measure walltime for the
// routed path vs an equivalent pure-Swift baseline,report the
// genuine per-turn savings (or lack thereof)。
//
// Realistic per-turn N estimates (per production telemetry-
// agnostic guess — host workloads vary):
//
//   - candidateDominanceScore sort:     5-20 candidates
//   - TriSelf.merge sort:                5-20 candidates
//   - TriSelf viableScores sort:         3-15 scores
//   - TriSelf viableFallbacks sort:      3-15 scores
//   - Memory retrieve top-K sort:        50-1000 atoms
//   - Cognition compiler item sort:      20-200 items
//   - EBrainNeuralMaterialization dominance: 5-20 candidates
//
// Total per-turn floor:~100-1300 element sorts。

import XCTest
@testable import BASRuntimeCore

#if os(iOS) || os(macOS)

final class BASChapter848TurnWorkloadPerfTests: XCTestCase {

    // MARK: - Realistic per-turn workload

    /// Simulate ONE turn with all 7 flip sites firing。
    /// Uses representative N at each site based on production
    /// estimates (low-end:cold session,low-end model;
    /// high-end:long session,large frontier)。
    private struct TurnWorkload {
        let candidateDomScores: [Double]
        let triSelfMergeScores: [Double]
        let triSelfViableScores: [Double]
        let triSelfFallbackScores: [Double]
        let memoryRetrieveScores: [Double]
        let cognitionScores: [Double]
        let secondDominanceScores: [Double]
    }

    private func buildWorkload(scale: Int) -> TurnWorkload {
        var rng = SystemRandomNumberGenerator()
        func mkScores(_ n: Int) -> [Double] {
            (0..<n).map { _ in
                Double(rng.next() % 1_000_000) / 1_000_000.0
            }
        }
        return TurnWorkload(
            candidateDomScores:    mkScores(scale * 1),
            triSelfMergeScores:    mkScores(scale * 1),
            triSelfViableScores:   mkScores(scale * 1),
            triSelfFallbackScores: mkScores(scale * 1),
            memoryRetrieveScores:  mkScores(scale * 5),
            cognitionScores:       mkScores(scale * 2),
            secondDominanceScores: mkScores(scale * 1))
    }

    // MARK: - Routed (production) path

    /// Mirror the pattern at all 7 production flip sites:
    /// precompute Double scores → route through Rust f64 kernel
    /// → map indices back。
    private func runRoutedTurn(
        workload: TurnWorkload
    ) -> [Int] {
        var totalIndices: [Int] = []
        let sites: [[Double]] = [
            workload.candidateDomScores,
            workload.triSelfMergeScores,
            workload.triSelfViableScores,
            workload.triSelfFallbackScores,
            workload.memoryRetrieveScores,
            workload.cognitionScores,
            workload.secondDominanceScores,
        ]
        for scores in sites {
            if let indices = BASAutoRouteRanker
                .dreamLoopDominanceOrderDouble(scores: scores) {
                totalIndices.append(indices.count)
            } else {
                XCTFail("Routed path failed unexpectedly")
            }
        }
        return totalIndices
    }

    // MARK: - Swift baseline (V1 fallback equivalent)

    /// Equivalent Swift `.sorted` at each site,matching the V1
    /// fallback body retained at each flip site。
    private func runSwiftBaseline(
        workload: TurnWorkload
    ) -> [Int] {
        var totalIndices: [Int] = []
        let sites: [[Double]] = [
            workload.candidateDomScores,
            workload.triSelfMergeScores,
            workload.triSelfViableScores,
            workload.triSelfFallbackScores,
            workload.memoryRetrieveScores,
            workload.cognitionScores,
            workload.secondDominanceScores,
        ]
        for scores in sites {
            let indices: [Int32] = Array(0..<Int32(scores.count))
                .sorted { a, b in
                    let sa = scores[Int(a)]
                    let sb = scores[Int(b)]
                    if sa == sb { return a < b }
                    return sa > sb
                }
            totalIndices.append(indices.count)
        }
        return totalIndices
    }

    // MARK: - Tests

    /// Smallest realistic turn:cold session,small candidate frontier。
    func testTurnWorkloadSmallScale() {
        let workload = buildWorkload(scale: 5)
        // scale 5 = 5+5+5+5+25+10+5 = 60 element sorts per turn
        runComparison(workload: workload, label: "small (cold session)")
    }

    /// Medium turn:warm session,full frontier。
    func testTurnWorkloadMediumScale() {
        let workload = buildWorkload(scale: 20)
        // scale 20 = 20+20+20+20+100+40+20 = 240 element sorts
        runComparison(workload: workload, label: "medium (warm session)")
    }

    /// Large turn:long-running session,deep memory recall。
    func testTurnWorkloadLargeScale() {
        let workload = buildWorkload(scale: 100)
        // scale 100 = 100+100+100+100+500+200+100 = 1200 element sorts
        runComparison(workload: workload, label: "large (long session)")
    }

    // MARK: - Comparison runner

    private func runComparison(
        workload: TurnWorkload,
        label: String
    ) {
        // Warm up both paths to neutralize cold-start effects
        for _ in 0..<3 {
            _ = runRoutedTurn(workload: workload)
            _ = runSwiftBaseline(workload: workload)
        }

        // 100-turn replay for stable measurement
        let iterations = 100
        let routedNs = measureNanos {
            for _ in 0..<iterations {
                _ = runRoutedTurn(workload: workload)
            }
        }
        let swiftNs = measureNanos {
            for _ in 0..<iterations {
                _ = runSwiftBaseline(workload: workload)
            }
        }

        // Per-turn averages
        let routedPerTurnUs = Double(routedNs)
            / Double(iterations) / 1000.0
        let swiftPerTurnUs = Double(swiftNs)
            / Double(iterations) / 1000.0
        let savingsUs = swiftPerTurnUs - routedPerTurnUs
        let ratio = Double(routedNs) / Double(swiftNs)

        print("== chapter 848 TURN WORKLOAD [\(label)] " +
              "× \(iterations) turns ==")
        print(String(format:
            "   Swift  baseline: %.3f ms total / %.2f µs/turn",
            Double(swiftNs) / 1_000_000.0, swiftPerTurnUs))
        print(String(format:
            "   Routed (f64):    %.3f ms total / %.2f µs/turn",
            Double(routedNs) / 1_000_000.0, routedPerTurnUs))
        print(String(format:
            "   Per-turn delta:  %.2f µs (routed/swift = %.2f×)",
            savingsUs, ratio))
        if savingsUs > 0 {
            print(String(format:
                "   VERDICT: routed faster by %.2f µs/turn — " +
                "synthetic-claim VALIDATED",
                savingsUs))
        } else {
            print(String(format:
                "   VERDICT: routed SLOWER by %.2f µs/turn — " +
                "synthetic claim NOT validated at this scale",
                -savingsUs))
        }

        XCTAssertGreaterThan(routedNs, 0)
        XCTAssertGreaterThan(swiftNs, 0)
    }

    private func measureNanos(_ body: () -> Void) -> UInt64 {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let end = DispatchTime.now().uptimeNanoseconds
        return end - start
    }
}

#endif
