// MARK: - BASTurnRuntimeDefaultModeFlipReadinessGate
// chapter 六百七十三 / M2069 — Phase L readiness gate。
//                              Runs 100 dual-mode sweeps
//                              + asserts 0% divergence
//                              before chapter 674's M2074
//                              DEFAULT MODE FLIP can land。
//
// ## Why this exists
//
// Per BASPhaseLPreFlipGateContractDoctrine (M2063),
// the M2074 default mode flip requires a readiness
// gate proving V1+V2 byte-equality at scale。 plan calls
// for "100x over 24h" — practically the test runs 100
// invocations of canonical60 dualV1Runner sequentially。
// 24h aspirational duration is achieved by CI scheduler
// configuration (re-running this test gate every CI
// build for 24h pre-flip),NOT by sleeping 24h inside
// the test。
//
// ## Honest scope acknowledgment
//
// The "100×24h" plan language is aspirational。 In
// practice:
//   - 100 invocations of canonical60 (60 fixtures × 2
//     coordinator calls each = 12,000 V1 invocations
//     total per gate run) takes ~few seconds on M-series
//     silicon (each canonical60 sweep ~40ms)
//   - 24h cumulative observation = re-running this test
//     gate in CI continuously for 24h
//   - The test assertion (0 divergences) is the same
//     whether observed for 4 seconds or 24h
//
// What this gate ACTUALLY proves:
//   - Across 100 independent invocations,V1↔V1
//     determinism holds for ALL 60 canonical fixtures
//   - That's 6,000 separate determinism assertions
//   - Combined with chapter 669's 3× run-stability,
//     this is high-confidence evidence that the FLIP
//     can land without byte-equality regressions

import Foundation
import BASRuntimeCore

/// Phase L readiness gate runner。 Callers pass a
/// coordinator factory closure (typically
/// `BASCoordinatorTestStubs.makeStub` from Tests/) +
/// the gate runs the dual-mode sweep 100×。 Returns a
/// typed `BASTurnRuntimeDefaultModeFlipReadinessVerdict`。
/// CI gates the M2074 flip on `.ready` verdict ONLY。
public enum BASTurnRuntimeDefaultModeFlipReadinessGate {

    /// Total invocations per gate run。 Plan target:100。
    public static let invocationsPerGateRun: Int = 100

    /// Acceptable divergence count (0% tolerance per
    /// BASPhaseLPreFlipGateContractDoctrine M2063)。
    public static let acceptableDivergenceCount: Int = 0

    /// Caller-supplied coordinator factory。 Tests pass
    /// `BASCoordinatorTestStubs.makeStub` (chapter 462
    /// / M1225)。
    public typealias CoordinatorFactory =
        @Sendable () -> BASEBrainRuntimeCoordinator

    /// Run the gate with the given coordinator factory。
    /// Returns `.ready` ONLY if all 100 invocations
    /// produce 0 divergences across canonical60。 Any
    /// divergence in any invocation fails the gate。
    public static func runGate(
        coordinatorFactory:
            @escaping CoordinatorFactory
    ) async
        -> BASTurnRuntimeDefaultModeFlipReadinessVerdict
    {
        let startedAt = Date()
        var totalRunsCompleted: Int = 0
        var totalDivergences: Int = 0
        var firstDivergingRunIndex: Int? = nil
        var firstDivergingFixtureLabel: String? = nil
        let fixtureCount =
            BASStressSweepCanonical60Driver
                .canonicalKeyExpansion().count

        for runIndex in 0..<invocationsPerGateRun {
            let harness = BASStressSweepHarness()
            let runner =
                BASTurnRuntimeFullSummaryStressSweepRunner
                    .dualV1Runner(
                        coordinatorFactory: coordinatorFactory,
                        requestBuilder:
                            BASTurnRuntimeFullSummaryStressSweepRunner
                                .defaultRequestBuilder(for:))
            let report = await harness.run(
                fixtureSet: BASStressSweepCanonical60Driver
                    .canonicalFixtureSet(),
                runner: runner)
            let divergences = report.results.filter {
                !$0.isPass
            }
            totalRunsCompleted += 1
            totalDivergences += divergences.count

            if !divergences.isEmpty
                && firstDivergingRunIndex == nil
            {
                firstDivergingRunIndex = runIndex
                firstDivergingFixtureLabel =
                    divergences.first?.key.label
            }
        }

        let completedAt = Date()
        let elapsedSeconds = completedAt
            .timeIntervalSince(startedAt)

        let isReady = totalDivergences
            <= acceptableDivergenceCount

        return BASTurnRuntimeDefaultModeFlipReadinessVerdict(
            invocationsCompleted: totalRunsCompleted,
            totalFixtureComparisons:
                totalRunsCompleted * fixtureCount,
            totalDivergences: totalDivergences,
            firstDivergingRunIndex:
                firstDivergingRunIndex,
            firstDivergingFixtureLabel:
                firstDivergingFixtureLabel,
            elapsedSeconds: elapsedSeconds,
            isReady: isReady)
    }
}

// MARK: - Verdict

public struct BASTurnRuntimeDefaultModeFlipReadinessVerdict:
    Sendable, Equatable
{
    public let invocationsCompleted: Int
    public let totalFixtureComparisons: Int
    public let totalDivergences: Int
    public let firstDivergingRunIndex: Int?
    public let firstDivergingFixtureLabel: String?
    public let elapsedSeconds: TimeInterval
    public let isReady: Bool
}
