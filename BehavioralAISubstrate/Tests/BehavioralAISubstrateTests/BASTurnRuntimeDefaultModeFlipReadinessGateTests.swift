// MARK: - BASTurnRuntimeDefaultModeFlipReadinessGateTests
// chapter 六百七十三 / M2070 — Phase L readiness gate
//                              PROOF tests。 If this gate
//                              fails,chapter 674's M2074
//                              flip MUST NOT land。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASTurnRuntimeDefaultModeFlipReadinessGateTests:
    XCTestCase
{
    // MARK: - Gate identity

    func testInvocationsPerGateRunIs100() {
        XCTAssertEqual(
            BASTurnRuntimeDefaultModeFlipReadinessGate
                .invocationsPerGateRun, 100)
    }

    func testAcceptableDivergenceCountIsZero() {
        XCTAssertEqual(
            BASTurnRuntimeDefaultModeFlipReadinessGate
                .acceptableDivergenceCount, 0)
    }

    // MARK: - THE PHASE L FLIP GATE ASSERTION

    /// The single test that gates the M2074 flip。 If
    /// this fails,Phase L's chapter 674 commit MUST NOT
    /// land — V1+V2 byte-equality has not been proven。
    func testReadinessGateReturnsReadyVerdict()
        async throws
    {
        let verdict = await
            BASTurnRuntimeDefaultModeFlipReadinessGate
                .runGate {
                    BASCoordinatorTestStubs.makeStub()
                }

        XCTAssertTrue(verdict.isReady,
            "PHASE L FLIP GATE FAILED。" +
            " invocationsCompleted=\(verdict.invocationsCompleted)" +
            " totalFixtureComparisons=" +
            "\(verdict.totalFixtureComparisons)" +
            " totalDivergences=\(verdict.totalDivergences)" +
            " firstDivergingRunIndex=" +
            "\(String(describing: verdict.firstDivergingRunIndex))" +
            " firstDivergingFixtureLabel=" +
            "\(String(describing: verdict.firstDivergingFixtureLabel))" +
            " elapsedSeconds=\(verdict.elapsedSeconds)。" +
            " M2074 flip MUST NOT land while this gate" +
            " fails。")

        XCTAssertEqual(
            verdict.invocationsCompleted, 100,
            "Gate must complete all 100 invocations")
        XCTAssertEqual(
            verdict.totalDivergences, 0,
            "Phase L 0%-divergence tolerance contract" +
            " requires zero divergences across all" +
            " 6000 fixture comparisons")
        XCTAssertEqual(
            verdict.totalFixtureComparisons, 6000,
            "100 invocations × 60 canonical fixtures =" +
            " 6000 fixture comparisons")
        XCTAssertNil(
            verdict.firstDivergingRunIndex,
            "No divergence implies no diverging run index")
        XCTAssertNil(
            verdict.firstDivergingFixtureLabel,
            "No divergence implies no diverging fixture")
    }

    // MARK: - Verdict struct contract

    func testVerdictIsEquatable() {
        let v1 = BASTurnRuntimeDefaultModeFlipReadinessVerdict(
            invocationsCompleted: 100,
            totalFixtureComparisons: 6000,
            totalDivergences: 0,
            firstDivergingRunIndex: nil,
            firstDivergingFixtureLabel: nil,
            elapsedSeconds: 5.0,
            isReady: true)
        let v2 = BASTurnRuntimeDefaultModeFlipReadinessVerdict(
            invocationsCompleted: 100,
            totalFixtureComparisons: 6000,
            totalDivergences: 0,
            firstDivergingRunIndex: nil,
            firstDivergingFixtureLabel: nil,
            elapsedSeconds: 5.0,
            isReady: true)
        XCTAssertEqual(v1, v2)
    }

    func testVerdictDistinguishesReadyVsFailed() {
        let ready = BASTurnRuntimeDefaultModeFlipReadinessVerdict(
            invocationsCompleted: 100,
            totalFixtureComparisons: 6000,
            totalDivergences: 0,
            firstDivergingRunIndex: nil,
            firstDivergingFixtureLabel: nil,
            elapsedSeconds: 5.0,
            isReady: true)
        let failed = BASTurnRuntimeDefaultModeFlipReadinessVerdict(
            invocationsCompleted: 100,
            totalFixtureComparisons: 6000,
            totalDivergences: 7,
            firstDivergingRunIndex: 42,
            firstDivergingFixtureLabel: "fixture-x",
            elapsedSeconds: 5.0,
            isReady: false)
        XCTAssertNotEqual(ready, failed)
        XCTAssertTrue(ready.isReady)
        XCTAssertFalse(failed.isReady)
    }
}
