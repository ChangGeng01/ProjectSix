// MARK: - BASLLMExtractionEngineTests — chapter 四百一 / M932
//
// End-to-end engine tests using M920 BASFoundationModelsMockSession
// as the LLM adapter。Verifies the 6-module composition produces
// the typed 9-byproduct bundle + appends typed audit events to
// the M841 event log。

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASLLMExtractionEngineTests: XCTestCase {

    private func makeRawInput() -> BASLLMRawInput {
        BASLLMRawInput(
            prompt: "test query",
            sessionID: "s-engine")
    }

    // MARK: - Minimal engine (no retriever / no verifier)

    func testMinimalEnginePopulatesFinalAnswer() async
        throws
    {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "engine answer")
            ])
        let log = BASInMemoryEventLogStorage()
        let engine = BASLLMExtractionEngine(
            adapter: mock, eventLog: log)

        let result = try await engine.run(
            input: makeRawInput(),
            timestampMs: 1_000)

        XCTAssertEqual(result.byproducts.finalAnswer,
            "engine answer")
        XCTAssertTrue(result.byproducts.isTextOnly,
            "Default policy = text-only extraction")
    }

    // MARK: - Audit events

    func testEngineAppendsStartAndCompleteEvents() async
        throws
    {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "x")
            ])
        let log = BASInMemoryEventLogStorage()
        let engine = BASLLMExtractionEngine(
            adapter: mock, eventLog: log)

        _ = try await engine.run(
            input: makeRawInput(),
            timestampMs: 1_000)

        let events = await log.events(
            forSession: "s-engine")
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].source,
            "llm-engine:start")
        XCTAssertEqual(events[1].source,
            "llm-engine:complete")
        XCTAssertEqual(events[0].kind, .substrateAudit)
        XCTAssertEqual(events[1].kind, .substrateAudit)
        XCTAssertNotNil(events[1].payloadJson,
            "complete event carries summary payload")
        XCTAssertTrue(
            events[1].payloadJson?.contains("taskID")
                ?? false)
    }

    // MARK: - Retrieval callback

    func testRetrievalCallbackEnrichesContext() async throws {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "answered")
            ])
        let log = BASInMemoryEventLogStorage()
        let retriever: BASLLMEngineRetrievalCallback = {
            _ in
            return ["mem-bullet-1", "mem-bullet-2"]
        }
        let engine = BASLLMExtractionEngine(
            retriever: retriever,
            adapter: mock,
            eventLog: log)

        let result = try await engine.run(
            input: makeRawInput(),
            timestampMs: 1_000)

        XCTAssertEqual(result.taskPackage.contextBlobs.count,
            2)
        XCTAssertTrue(result.taskPackage.contextBlobs
            .contains("mem-bullet-1"))
    }

    func testRetrievalEmptyResultIncrementsMisses() async
        throws
    {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "x")
            ])
        let log = BASInMemoryEventLogStorage()
        let engine = BASLLMExtractionEngine(
            retriever: { _ in [] },
            adapter: mock,
            eventLog: log)

        _ = try await engine.run(
            input: makeRawInput(),
            timestampMs: 1_000)

        let misses = await engine.totalRetrievalMisses
        XCTAssertEqual(misses, 1)
    }

    // MARK: - Verifier callback

    func testVerifierFeedbackMergedIntoByproducts() async
        throws
    {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "raw answer")
            ])
        let log = BASInMemoryEventLogStorage()
        let verifier: BASLLMEngineVerifierCallback = {
            _, _ in
            BASLLMVerifierFeedback(
                approved: true,
                amendedAnswer: "amended answer",
                counterArguments: ["counter1", "counter2"],
                confidenceScores: [
                    "factual": 0.7, "strategic": 0.85
                ])
        }
        let engine = BASLLMExtractionEngine(
            adapter: mock,
            verifier: verifier,
            eventLog: log)

        let result = try await engine.run(
            input: makeRawInput(),
            timestampMs: 1_000)

        XCTAssertEqual(result.byproducts.finalAnswer,
            "amended answer",
            "Amended answer replaces raw")
        XCTAssertEqual(
            result.byproducts.counterArguments,
            ["counter1", "counter2"])
        XCTAssertEqual(
            result.byproducts.confidenceScores["factual"],
            0.7)
        XCTAssertEqual(
            result.byproducts.confidenceScores["strategic"],
            0.85)

        let amendments = await engine
            .totalVerifierAmendments
        XCTAssertEqual(amendments, 1)
    }

    func testVerifierApprovedNoAmendmentsLeavesAnswerAsIs()
        async throws
    {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "raw answer")
            ])
        let log = BASInMemoryEventLogStorage()
        let engine = BASLLMExtractionEngine(
            adapter: mock,
            verifier: { _, _ in
                .approvedNoAmendments
            },
            eventLog: log)

        let result = try await engine.run(
            input: makeRawInput(),
            timestampMs: 1_000)

        XCTAssertEqual(result.byproducts.finalAnswer,
            "raw answer")
        XCTAssertEqual(
            result.byproducts.counterArguments, [])
    }

    // MARK: - Custom extractor policy

    func testCustomExtractorPolicyProducesAllNineFields()
        async throws
    {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "answer")
            ])
        let log = BASInMemoryEventLogStorage()
        let policy: BASLLMOutputParserPolicy = {
            draft, pkg, ts in
            BASLLMExtractionByproducts(
                finalAnswer: draft.body,
                structuredConclusion: "{\"ok\":true}",
                memoryUpdates: [
                    BASMemoryUpdateCandidate(
                        kind: "test", content: "x",
                        confidence: 0.5)
                ],
                taskCandidates: [
                    BASTaskCandidate(
                        title: "t",
                        priority: .low,
                        deadlineMs: nil,
                        parentSessionID:
                            pkg.originSessionID)
                ],
                riskFlags: ["r"],
                confidenceScores: ["c": 0.9],
                counterArguments: ["ca"],
                evalCases: [
                    BASEvalCaseCandidate(
                        inputText: "i",
                        expectedBehavior: "e",
                        scoringMethod: .humanReview)
                ],
                trainingExamples: [
                    BASTrainingExampleCandidate(
                        inputText: "t",
                        contextSummary: "s",
                        goodAnswerTraits: [],
                        badAnswerTraits: [],
                        score: 0.5)
                ],
                extractedAtMs: ts)
        }
        let engine = BASLLMExtractionEngine(
            adapter: mock,
            extractorPolicy: policy,
            eventLog: log)

        let result = try await engine.run(
            input: makeRawInput(),
            timestampMs: 1_000)

        XCTAssertFalse(result.byproducts.isTextOnly,
            "Custom policy populates 9 byproducts")
        XCTAssertEqual(result.byproducts.memoryUpdates.count,
            1)
        XCTAssertEqual(result.byproducts.taskCandidates
            .count, 1)
        XCTAssertEqual(result.byproducts.evalCases.count, 1)
        XCTAssertEqual(result.byproducts.trainingExamples
            .count, 1)
    }

    // MARK: - Adapter failure

    func testAdapterFailureWrapsError() async {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .error(reason: "test failure")
            ])
        let log = BASInMemoryEventLogStorage()
        let engine = BASLLMExtractionEngine(
            adapter: mock, eventLog: log)

        do {
            _ = try await engine.run(
                input: makeRawInput(),
                timestampMs: 1_000)
            XCTFail("Must throw")
        } catch BASLLMExtractionEngineError
            .adapterFailed(let reason)
        {
            XCTAssertTrue(reason.contains("test failure"))
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - Determinism

    func testEngineIsDeterministicAcrossRuns() async throws
    {
        // Two engines with same scripted mock + same timestamp
        // should produce the same final result。
        func runOnce() async throws ->
            BASLLMExtractionByproducts
        {
            let mock = BASFoundationModelsMockSession(
                scriptedResponses: [
                    .text(body: "deterministic")
                ])
            let log = BASInMemoryEventLogStorage()
            let engine = BASLLMExtractionEngine(
                adapter: mock, eventLog: log)
            let result = try await engine.run(
                input: makeRawInput(),
                timestampMs: 1_700_000_000_000)
            return result.byproducts
        }
        let bp1 = try await runOnce()
        let bp2 = try await runOnce()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(
            try encoder.encode(bp1),
            try encoder.encode(bp2),
            "M892 replay-determinism: same inputs → " +
            "byte-stable byproducts")
    }

    // MARK: - Telemetry

    func testTotalCallsCounter() async throws {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "a"),
                .text(body: "b"),
                .text(body: "c")
            ])
        let log = BASInMemoryEventLogStorage()
        let engine = BASLLMExtractionEngine(
            adapter: mock, eventLog: log)

        for _ in 0..<3 {
            _ = try await engine.run(
                input: makeRawInput(),
                timestampMs: 1_000)
        }
        let count = await engine.totalCalls
        XCTAssertEqual(count, 3)
    }
}
