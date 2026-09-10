// MARK: - BASTurnRuntimeEngineRunWithPlanRealCoordinatorDualModeTests
// chapter 六百六十九 / M2054 — real-coordinator-driven
//                              dual-mode stress sweep test。
//                              Uses BASCoordinatorTestStubs
//                              .makeStub() instead of stub
//                              summary runners — drives
//                              actual coordinator.runTurn
//                              calls so the dual-mode
//                              comparison exercises the
//                              real V1 path (chapter 669
//                              第二刀)。
//
// ## How this differs from M2053
//
// M2053 used the identity stub runner that returns
// pre-baked identical V1+V2 summaries — proves the
// HARNESS PIPELINE works。 M2054 swaps in the real
// coordinator via BASTurnRuntimeFullSummaryStressSweep
// Runner.dualV1Runner — every fixture invokes the actual
// coordinator twice and compares the resulting
// BASRuntimeAuditEmissionSummary digests。 This catches
// V1↔V1 determinism violations (chapter 三百九二) as well
// as exercising real ADR-014 OPT-IN service wiring。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASTurnRuntimeEngineRunWithPlanRealCoordinatorDualModeTests:
    XCTestCase
{
    // MARK: - V1↔V1 determinism across full canonical60

    /// Real-coordinator V1↔V1 determinism check。 Each
    /// canonical60 fixture invokes
    /// `BASCoordinatorTestStubs.makeStub().runTurn(_:)`
    /// twice + compares the two resulting summaries。
    /// chapter 三百九二 violation if any pair diverges。
    func testRealCoordinatorV1V1DeterminismAcrossCanonical60()
        async throws
    {
        let harness = BASStressSweepHarness()
        let runner = BASTurnRuntimeFullSummaryStressSweepRunner
            .dualV1Runner(
                coordinatorFactory: {
                    BASCoordinatorTestStubs.makeStub()
                },
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
        XCTAssertEqual(divergences.count, 0,
            "Real-coordinator V1↔V1 must be deterministic" +
            " across all 60 canonical fixtures。" +
            " divergences: \(divergences.map { $0.key.label })")
        XCTAssertEqual(report.results.count, 60)
    }

    // MARK: - 3x flake-detect across full canonical60

    func testRealCoordinatorIs3xStableAcrossCanonical60()
        async throws
    {
        for runIndex in 0..<3 {
            let harness = BASStressSweepHarness()
            let runner =
                BASTurnRuntimeFullSummaryStressSweepRunner
                    .dualV1Runner(
                        coordinatorFactory: {
                            BASCoordinatorTestStubs
                                .makeStub()
                        },
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
            XCTAssertEqual(divergences.count, 0,
                "Run \(runIndex):real-coordinator V1↔V1" +
                " must be deterministic across canonical60。" +
                " divergences:" +
                " \(divergences.map { $0.key.label })")
        }
    }
}
