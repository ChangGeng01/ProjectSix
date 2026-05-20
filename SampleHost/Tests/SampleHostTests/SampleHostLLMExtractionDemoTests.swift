// MARK: - SampleHostLLMExtractionDemoTests — chapter 四百一 / M934
//
// Tests for the SampleHost LLM Extraction Engine demo panel
// + the static `runDemo()` helper。Verifies the demo runs end-
// to-end on iOS Simulator without throwing AND emits all 9
// byproducts。

import XCTest
@testable import SampleHost
@testable import BASOrgan
@testable import BASRuntimeCore

@MainActor
final class SampleHostLLMExtractionDemoTests: XCTestCase {

    func testRunDemoProducesAll9Byproducts() async throws {
        let result = try await
            SampleHostLLMExtractionDemoModel.runDemo()

        // Byproduct 1: finalAnswer must be non-empty
        XCTAssertFalse(result.byproducts.finalAnswer.isEmpty)

        // Byproduct 2: structuredConclusion populated
        XCTAssertNotNil(
            result.byproducts.structuredConclusion)
        XCTAssertTrue(
            result.byproducts.structuredConclusion?
                .contains("decision") ?? false)

        // Byproduct 3: memoryUpdates ≥ 2 (demo seeds 2)
        XCTAssertGreaterThanOrEqual(
            result.byproducts.memoryUpdates.count, 2)

        // Byproduct 4: taskCandidates ≥ 1
        XCTAssertGreaterThanOrEqual(
            result.byproducts.taskCandidates.count, 1)

        // Byproduct 5: riskFlags non-empty
        XCTAssertFalse(
            result.byproducts.riskFlags.isEmpty)

        // Byproduct 6: confidenceScores has 3 axes
        XCTAssertGreaterThanOrEqual(
            result.byproducts.confidenceScores.count, 3)
        XCTAssertNotNil(
            result.byproducts
                .confidenceScores["factual"])
        XCTAssertNotNil(
            result.byproducts
                .confidenceScores["strategic"])

        // Byproduct 7: counterArguments non-empty
        XCTAssertFalse(
            result.byproducts.counterArguments.isEmpty)

        // Byproduct 8: evalCases ≥ 1
        XCTAssertGreaterThanOrEqual(
            result.byproducts.evalCases.count, 1)

        // Byproduct 9: trainingExamples ≥ 1
        XCTAssertGreaterThanOrEqual(
            result.byproducts.trainingExamples.count, 1)

        // Bundle is NOT text-only (proves all byproducts are
        // populated, not just the trivial finalAnswer)
        XCTAssertFalse(result.byproducts.isTextOnly,
            "M934 demo must populate all 9 byproducts")
    }

    func testDemoModelRunUpdatesStatus() async {
        let model = SampleHostLLMExtractionDemoModel()
        XCTAssertEqual(model.status, .idle)
        XCTAssertNil(model.lastResult)

        await model.run()

        XCTAssertEqual(model.status, .completed)
        XCTAssertNotNil(model.lastResult)
        XCTAssertNil(model.lastError)
    }

    func testDemoTaskPackageCarriesUserSession() async throws {
        let result = try await
            SampleHostLLMExtractionDemoModel.runDemo()
        XCTAssertTrue(
            result.taskPackage.originSessionID
                .hasPrefix("samplehost-demo-"),
            "Session ID must reflect the demo origin")
        XCTAssertFalse(result.taskPackage.taskID.isEmpty)
    }
}
