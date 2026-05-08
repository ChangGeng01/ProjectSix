// MARK: - BASLLMVerifierPipelineTests — chapter 四百一 / M935

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASLLMVerifierPipelineTests: XCTestCase {

    private func makeDraft(
        body: String = "raw draft answer"
    ) -> BASOrganDraft {
        BASOrganDraft(
            requestID: "req-1",
            providerID: "test",
            role: .scout,
            body: body,
            inputTokensEstimated: 0,
            outputTokensEstimated: 0,
            producedAt: Date(),
            traceID: "trace")
    }

    private func makeTaskPackage() -> BASLLMTaskPackage {
        BASLLMTaskPackage(
            taskID: "t-1",
            originSessionID: "s-1",
            compiledAtMs: 1_000,
            intent: "ask",
            goal: "test")
    }

    /// Helper to construct a mock adapter that returns one
    /// scripted body。
    private func makeMock(
        body: String
    ) -> BASFoundationModelsMockSession {
        BASFoundationModelsMockSession(
            scriptedResponses: [.text(body: body)])
    }

    // MARK: - Stage enum

    func testStageEnumPinned() {
        XCTAssertEqual(
            BASLLMVerifierStage.allCases.count, 4)
    }

    func testStageRawValuesPinned() {
        XCTAssertEqual(
            BASLLMVerifierStage.reviewer.rawValue,
            "reviewer")
        XCTAssertEqual(
            BASLLMVerifierStage.redTeam.rawValue,
            "redTeam")
        XCTAssertEqual(
            BASLLMVerifierStage.factChecker.rawValue,
            "factChecker")
        XCTAssertEqual(
            BASLLMVerifierStage.compressor.rawValue,
            "compressor")
    }

    // MARK: - Empty pipeline (no adapters wired)

    func testEmptyPipelineFallsBackToDraftBody() async {
        let pipeline = BASLLMVerifierPipeline(
            adapters: [:])
        let report = await pipeline.verify(
            draft: makeDraft(body: "fallback"),
            taskPackage: makeTaskPackage())
        XCTAssertEqual(
            report.finalRecommendedAnswer, "fallback")
        XCTAssertEqual(report.perStage.count, 0)
        XCTAssertEqual(
            report.aggregatedCounterArguments, [])
    }

    // MARK: - Single stage

    func testReviewerOnlyStageRuns() async {
        let reviewer = makeMock(body: "PASS")
        let pipeline = BASLLMVerifierPipeline(
            adapters: [.reviewer: reviewer])
        let report = await pipeline.verify(
            draft: makeDraft(),
            taskPackage: makeTaskPackage())
        XCTAssertEqual(report.perStage.count, 1)
        XCTAssertNotNil(report.perStage[.reviewer])
        XCTAssertEqual(
            report.perStage[.reviewer]?.rawOutput,
            "PASS")
        XCTAssertTrue(
            report.perStage[.reviewer]?.succeeded ?? false)
    }

    func testRedTeamProducesCounterArgs() async {
        let redTeam = makeMock(body:
            "Counter 1\nCounter 2\nCounter 3")
        let pipeline = BASLLMVerifierPipeline(
            adapters: [.redTeam: redTeam])
        let report = await pipeline.verify(
            draft: makeDraft(),
            taskPackage: makeTaskPackage())
        XCTAssertEqual(
            report.aggregatedCounterArguments,
            ["Counter 1", "Counter 2", "Counter 3"])
    }

    // MARK: - Compressor stage

    func testCompressorBecomesFinalAnswer() async {
        let compressor = makeMock(
            body: "compressed final answer")
        let pipeline = BASLLMVerifierPipeline(
            adapters: [.compressor: compressor])
        let report = await pipeline.verify(
            draft: makeDraft(body: "raw"),
            taskPackage: makeTaskPackage())
        XCTAssertEqual(
            report.finalRecommendedAnswer,
            "compressed final answer")
    }

    // MARK: - All four stages

    func testAllFourStagesRun() async {
        let reviewer = makeMock(body: "reviewer-out")
        let redTeam = makeMock(
            body: "rt1\nrt2")
        let factChecker = makeMock(
            body: "fact: TRUE")
        let compressor = makeMock(
            body: "final answer")
        let pipeline = BASLLMVerifierPipeline(
            adapters: [
                .reviewer: reviewer,
                .redTeam: redTeam,
                .factChecker: factChecker,
                .compressor: compressor
            ])
        let report = await pipeline.verify(
            draft: makeDraft(),
            taskPackage: makeTaskPackage())
        XCTAssertEqual(report.perStage.count, 4)
        XCTAssertEqual(
            report.finalRecommendedAnswer, "final answer")
        XCTAssertEqual(
            report.aggregatedCounterArguments,
            ["rt1", "rt2"])
        for stage in BASLLMVerifierStage.allCases {
            XCTAssertTrue(
                report.perStage[stage]?.succeeded ?? false,
                "Stage \(stage.rawValue) must succeed")
        }
    }

    // MARK: - Stage failure

    func testFailingStageGracefullyMarkedFailed() async {
        let reviewer = BASFoundationModelsMockSession(
            scriptedResponses: [
                .error(reason: "test error")
            ])
        let pipeline = BASLLMVerifierPipeline(
            adapters: [.reviewer: reviewer])
        let report = await pipeline.verify(
            draft: makeDraft(),
            taskPackage: makeTaskPackage())
        XCTAssertFalse(
            report.perStage[.reviewer]?.succeeded ?? true)
        XCTAssertTrue(
            (report.perStage[.reviewer]?.errorMessage ?? "")
                .contains("test error"))
    }

    func testTelemetryCounters() async {
        let reviewer = makeMock(body: "ok")
        let pipeline = BASLLMVerifierPipeline(
            adapters: [.reviewer: reviewer])
        _ = await pipeline.verify(
            draft: makeDraft(),
            taskPackage: makeTaskPackage())
        let total = await pipeline.totalVerifyCalls
        XCTAssertEqual(total, 1)
        let perStage = await pipeline.perStageCalls
        XCTAssertEqual(perStage[.reviewer], 1)
    }

    // MARK: - Engine integration helper

    func testEngineCallbackProducesFeedback() async throws
    {
        let compressor = makeMock(
            body: "amended answer")
        let redTeam = makeMock(
            body: "weakness 1\nweakness 2")
        let pipeline = BASLLMVerifierPipeline(
            adapters: [
                .redTeam: redTeam,
                .compressor: compressor
            ])
        let callback = pipeline
            .makeEngineVerifierCallback()
        let feedback = try await callback(
            makeDraft(body: "raw"),
            makeTaskPackage())
        XCTAssertTrue(feedback.approved)
        XCTAssertEqual(
            feedback.amendedAnswer, "amended answer")
        XCTAssertEqual(
            feedback.counterArguments,
            ["weakness 1", "weakness 2"])
        XCTAssertNotNil(
            feedback.confidenceScores["overall"])
    }

    func testEngineCallbackNoAmendmentWhenSameAnswer()
        async throws
    {
        // Compressor returns SAME body as raw → no amendment
        let compressor = makeMock(body: "same")
        let pipeline = BASLLMVerifierPipeline(
            adapters: [.compressor: compressor])
        let callback = pipeline
            .makeEngineVerifierCallback()
        let feedback = try await callback(
            makeDraft(body: "same"),
            makeTaskPackage())
        XCTAssertNil(feedback.amendedAnswer,
            "When compressor output matches raw,don't amend")
    }

    // MARK: - End-to-end with M932 engine

    func testPipelineWiredIntoM932Engine() async throws {
        // Build a generator + reviewer + compressor;feed
        // pipeline into M932 engine via makeEngineVerifierCallback。
        let generator = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "first draft")
            ])
        let reviewer = makeMock(body: "PASS")
        let compressor = makeMock(
            body: "polished final")

        let pipeline = BASLLMVerifierPipeline(
            adapters: [
                .reviewer: reviewer,
                .compressor: compressor
            ])
        let log = BASInMemoryEventLogStorage()
        let engine = BASLLMExtractionEngine(
            adapter: generator,
            verifier: pipeline.makeEngineVerifierCallback(),
            eventLog: log)

        let result = try await engine.run(
            input: BASLLMRawInput(
                prompt: "test",
                sessionID: "s-e2e"),
            timestampMs: 1_000)

        XCTAssertEqual(
            result.byproducts.finalAnswer,
            "polished final",
            "Compressor's amendment becomes the final " +
            "answer in the engine's byproducts")
        XCTAssertEqual(
            result.byproducts.confidenceScores["overall"],
            BASLLMVerifierPipeline
                .defaultOverallConfidence)
    }
}
