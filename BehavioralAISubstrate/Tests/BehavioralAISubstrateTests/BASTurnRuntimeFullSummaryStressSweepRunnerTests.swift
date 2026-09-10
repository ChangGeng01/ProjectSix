// MARK: - BASTurnRuntimeFullSummaryStressSweepRunnerTests
// chapter 四百七十八 / M1290
//
// PROOF tests for the real-coordinator-driven stress
// sweep runner。 This is THE regression guard
// infrastructure for V1 fold byte-equality verification。
//
// Test coverage:
//   - dualV1Runner produces V1+V2 summary pair from stub
//     coordinator + canonical60 fixture key
//   - Multiple invocations produce IDENTICAL summary
//     digests (V1↔V1 determinism PROOF)
//   - End-to-end harness pipeline:run canonical60 with
//     the runner + verify all 60 fixtures pass
//   - defaultRequestBuilder maps fixture-key dimensions
//     into request fields deterministically
//   - Mid-fold sanity:after M1289 trio extraction is in
//     place,V1↔V1 stress-sweep over canonical60 still
//     yields 0 divergences (proves trio fold preserved
//     byte-equality)

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASTurnRuntimeFullSummaryStressSweepRunnerTests:
    XCTestCase
{

    // MARK: - Helpers

    private func sampleFixtureKey() -> BASTurnRuntimeStressFixtureKey {
        return BASStressSweepCanonical60Driver
            .canonicalKeyExpansion()
            .first!
    }

    // MARK: - defaultRequestBuilder

    func testDefaultRequestBuilderProducesDeterministicRequest() {
        let key = sampleFixtureKey()
        let req1 = BASTurnRuntimeFullSummaryStressSweepRunner
            .defaultRequestBuilder(for: key)
        let req2 = BASTurnRuntimeFullSummaryStressSweepRunner
            .defaultRequestBuilder(for: key)
        XCTAssertEqual(
            req1.userInput, req2.userInput,
            "same key → same userInput (chapter 三百九二)")
        XCTAssertEqual(
            req1.hostID, req2.hostID)
        XCTAssertEqual(
            req1.recordedAt, req2.recordedAt,
            "fixed epoch must be replay-deterministic")
        XCTAssertEqual(
            req1.deviceState.npuAvailable,
            key.neuralCoreWired,
            "neuralCoreWired flag flows to deviceState" +
            ".npuAvailable")
    }

    func testDefaultRequestBuilderFlowsRiskBucket() {
        let lowKey = BASStressSweepCanonical60Driver
            .canonicalKeyExpansion()
            .first { $0.risk == .low }!
        let highKey = BASStressSweepCanonical60Driver
            .canonicalKeyExpansion()
            .first { $0.risk == .high }!
        let lowReq = BASTurnRuntimeFullSummaryStressSweepRunner
            .defaultRequestBuilder(for: lowKey)
        let highReq = BASTurnRuntimeFullSummaryStressSweepRunner
            .defaultRequestBuilder(for: highKey)
        XCTAssertEqual(lowReq.riskHint, .low)
        XCTAssertEqual(highReq.riskHint, .high)
    }

    // MARK: - dualV1Runner per-fixture invocation

    func testDualV1RunnerProducesIdenticalSummaries() async {
        let runner = BASTurnRuntimeFullSummaryStressSweepRunner
            .dualV1Runner(
                coordinatorFactory: {
                    BASCoordinatorTestStubs.makeStub()
                },
                requestBuilder:
                    BASTurnRuntimeFullSummaryStressSweepRunner
                        .defaultRequestBuilder(for:))
        let key = sampleFixtureKey()
        let pair = await runner(key)
        XCTAssertNotNil(pair,
            "runner must produce a pair when stub" +
            " coordinator returns valid result")
        guard let pair = pair else { return }
        XCTAssertEqual(
            pair.v1Summary, pair.v2Summary,
            "V1↔V1 dual invocation must produce" +
            " identical summaries (V1 byte-equality)")
    }

    // MARK: - Determinism across repeat runner invocations

    func testRunnerIsDeterministicAcrossRepeatedInvocations()
        async
    {
        let runner = BASTurnRuntimeFullSummaryStressSweepRunner
            .dualV1Runner(
                coordinatorFactory: {
                    BASCoordinatorTestStubs.makeStub()
                },
                requestBuilder:
                    BASTurnRuntimeFullSummaryStressSweepRunner
                        .defaultRequestBuilder(for:))
        let key = sampleFixtureKey()
        guard let pair1 = await runner(key),
              let pair2 = await runner(key) else {
            XCTFail("runner must produce pairs")
            return
        }
        XCTAssertEqual(
            pair1.v1Summary, pair2.v1Summary,
            "repeat invocation must yield equal" +
            " v1Summary (chapter 三百九二)")
    }

    // MARK: - End-to-end harness pipeline

    func testCanonical60HarnessRunReportsAllPassing() async {
        let harness = BASStressSweepHarness()
        let fixtureSet = BASStressSweepCanonical60Driver
            .canonicalFixtureSet()
        let runner = BASTurnRuntimeFullSummaryStressSweepRunner
            .dualV1Runner(
                coordinatorFactory: {
                    BASCoordinatorTestStubs.makeStub()
                },
                requestBuilder:
                    BASTurnRuntimeFullSummaryStressSweepRunner
                        .defaultRequestBuilder(for:))
        let report = await harness.run(
            fixtureSet: fixtureSet,
            runner: runner)
        XCTAssertEqual(report.totalFixtures, 60,
            "canonical60 = 60 fixtures")
        XCTAssertEqual(
            report.divergentFixtureCount, 0,
            "V1↔V1 must show 0 divergences across all" +
            " 60 fixtures — chapter 478 fold preserved" +
            " byte-equality")
        XCTAssertEqual(
            report.passingFixtureCount, 60,
            "60-of-60 fixtures must pass")
    }

    // MARK: - 3-run flake detection

    /// chapter 三百九二 flake-detection — runs the full
    /// canonical60 sweep 3 times and asserts all 3 reports
    /// agree on every fixture's verdict。 Catches
    /// time-dependent non-determinism that single-run
    /// tests miss。
    func testCanonical60ThreeRunFlakeDetection() async {
        let harness = BASStressSweepHarness()
        let fixtureSet = BASStressSweepCanonical60Driver
            .canonicalFixtureSet()
        let runner = BASTurnRuntimeFullSummaryStressSweepRunner
            .dualV1Runner(
                coordinatorFactory: {
                    BASCoordinatorTestStubs.makeStub()
                },
                requestBuilder:
                    BASTurnRuntimeFullSummaryStressSweepRunner
                        .defaultRequestBuilder(for:))
        var reports: [BASStressSweepReport] = []
        for _ in 0..<3 {
            reports.append(
                await harness.run(
                    fixtureSet: fixtureSet,
                    runner: runner))
        }
        for report in reports {
            XCTAssertEqual(
                report.divergentFixtureCount, 0,
                "every run must show 0 divergences")
            XCTAssertEqual(
                report.passingFixtureCount, 60)
        }
    }
}
