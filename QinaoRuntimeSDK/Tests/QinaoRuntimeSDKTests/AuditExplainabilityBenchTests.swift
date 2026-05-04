import XCTest
@testable import QinaoLoop

/// M549-M554 (chapter 一百三十七) — pin AuditExplainabilityBench
/// helper functions + plumbing.
///
/// Strategy:
///   - Unit tests verify parsing helpers (parseConfidence /
///     containsDecisionKeywords / aggregate stats) without
///     requiring AFM
///   - Integration test uses a deterministic stub endpoint to
///     verify end-to-end plumbing
///   - Real AFM-gated explainability test (requires
///     QINAO_FM_E2E=1) is the sample-host run, not a unit test
final class AuditExplainabilityBenchTests: XCTestCase {

    // MARK: - 1. parseConfidence — happy path

    func testParseConfidenceClean() {
        let response = """
            The system likely chose to compare candidates because
            the risk was elevated. CONFIDENCE: 75
            """
        XCTAssertEqual(
            AuditExplainabilityBench.parseConfidence(response),
            75)
    }

    // MARK: - 2. parseConfidence — case insensitive

    func testParseConfidenceCaseInsensitive() {
        let response = """
            ... confidence: 50 ...
            """
        XCTAssertEqual(
            AuditExplainabilityBench.parseConfidence(response),
            50)
    }

    // MARK: - 3. parseConfidence — clamps out-of-range

    func testParseConfidenceClamps() {
        XCTAssertEqual(
            AuditExplainabilityBench.parseConfidence(
                "CONFIDENCE: 0"),
            0)
        XCTAssertEqual(
            AuditExplainabilityBench.parseConfidence(
                "CONFIDENCE: 100"),
            100)
    }

    // MARK: - 4. parseConfidence — missing returns 0

    func testParseConfidenceMissingReturnsZero() {
        let response = "I have no idea what happened."
        XCTAssertEqual(
            AuditExplainabilityBench.parseConfidence(response),
            0)
    }

    // MARK: - 5. containsDecisionKeywords

    func testContainsDecisionKeywords() {
        XCTAssertTrue(
            AuditExplainabilityBench.containsDecisionKeywords(
                in: "The system made a decision"))
        XCTAssertTrue(
            AuditExplainabilityBench.containsDecisionKeywords(
                in: "Permit was set to compare"))
        XCTAssertTrue(
            AuditExplainabilityBench.containsDecisionKeywords(
                in: "Verdict: rollback"))
        XCTAssertFalse(
            AuditExplainabilityBench.containsDecisionKeywords(
                in: "Hello world"))
    }

    // MARK: - 6. buildPrompt includes signalRefs

    func testBuildPromptIncludesSignalRefs() {
        let codes = ["permit:answer", "risk:low",
                     "kunlun.axis.center:0.85"]
        let prompt = AuditExplainabilityBench.buildPrompt(
            signalRefs: codes)
        for code in codes {
            XCTAssertTrue(
                prompt.contains(code),
                "Prompt MUST embed signal-ref code '\(code)'")
        }
        XCTAssertTrue(prompt.contains("CONFIDENCE:"),
            "Prompt MUST request CONFIDENCE marker")
    }

    // MARK: - 7. aggregate — empty

    func testAggregateEmpty() {
        let result = AuditExplainabilityBench.aggregate(
            scores: [])
        XCTAssertEqual(result.turnCount, 0)
        XCTAssertEqual(result.medianConfidence, 0)
        XCTAssertEqual(result.p25Confidence, 0)
        XCTAssertEqual(result.p75Confidence, 0)
    }

    // MARK: - 8. aggregate — typical

    func testAggregateMedianAndPercentiles() {
        let scores: [AuditExplainabilityScore] = [
            .init(confidence: 30, responseLength: 100,
                  containsDecisionKeywords: false,
                  turnID: "t1"),
            .init(confidence: 50, responseLength: 200,
                  containsDecisionKeywords: true,
                  turnID: "t2"),
            .init(confidence: 70, responseLength: 300,
                  containsDecisionKeywords: true,
                  turnID: "t3"),
            .init(confidence: 90, responseLength: 400,
                  containsDecisionKeywords: true,
                  turnID: "t4"),
        ]
        let result = AuditExplainabilityBench.aggregate(
            scores: scores)
        XCTAssertEqual(result.turnCount, 4)
        // Sorted: [30, 50, 70, 90]; median = sorted[2] = 70
        XCTAssertEqual(result.medianConfidence, 70)
        // p25 = sorted[1] = 50
        XCTAssertEqual(result.p25Confidence, 50)
        // p75 = sorted[3] = 90
        XCTAssertEqual(result.p75Confidence, 90)
    }

    // MARK: - 9. Threshold constants stable

    func testThresholdsAreNamed() {
        XCTAssertEqual(
            AuditExplainabilityBench.opaqueTrailThreshold, 60,
            "anti-magic-number: opaque threshold pinned at 60")
        XCTAssertEqual(
            AuditExplainabilityBench
                .reconstructableTrailThreshold, 80,
            "anti-magic-number: reconstructable threshold pinned at 80")
    }

    // MARK: - 10. End-to-end plumbing with stub endpoint

    /// Verifies the bench evaluates a turn end-to-end without
    /// requiring AFM. Uses a deterministic stub endpoint that
    /// returns a canned response.
    func testEvaluateWithStubEndpoint() async throws {
        let stub = StubExplainabilityEndpoint(cannedResponse: """
            The system probably chose to answer because risk was low.
            Top 3 reasons:
            1. permit:answer (proceed)
            2. risk:low (no escalation)
            3. fold:turn-1-clean (clean state)
            No red lines triggered.
            CONFIDENCE: 75
            """)
        let score = try await AuditExplainabilityBench.evaluate(
            signalRefs: ["permit:answer", "risk:low",
                         "fold:turn-1-clean"],
            turnID: "stub-turn-1",
            endpoint: stub,
            sessionID: "stub-session")
        XCTAssertEqual(score.confidence, 75)
        XCTAssertGreaterThan(score.responseLength, 50)
        XCTAssertTrue(score.containsDecisionKeywords)
        XCTAssertEqual(score.turnID, "stub-turn-1")
    }
}

// MARK: - Stub endpoint for plumbing tests

private struct StubExplainabilityEndpoint: QinaoOrganEndpoint {
    let cannedResponse: String

    func produceBody(
        prompt: String,
        context: [String],
        role: QinaoLoop.OrganRole,
        sessionID: String
    ) async throws -> QinaoLoop.OrganResponse {
        QinaoLoop.OrganResponse(
            body: cannedResponse,
            providerID: "stub-explainability",
            traceID: "stub-trace-\(sessionID)")
    }
}
