import XCTest
@testable import QinaoSeats
@testable import QinaoWorldPrior

/// 六十八 — parser robustness tests for AI reviewer
/// simulation. Each test pins a real-AFM-output edge case
/// the parser now handles correctly (didn't before chapter
/// 六十八 fixes).
final class QinaoWorldPriorAIReviewerSimulationRobustnessTests:
    XCTestCase
{

    // MARK: - PASS word-boundary

    func test_passatNotMisclassifiedAsPass() throws {
        // PASSAT (made-up word starting with PASS) must
        // NOT classify as PASS. The fix uses word-boundary
        // detection.
        let reply = """
            CHECK_1: PASSAT — id format
            CHECK_2: PASS - desc adequate
            CHECK_3: PASS - perturb ok
            CHECK_4: PASS - rungs ok
            CHECK_5: PASS - consistent
            CHECK_6: PASS - no bias
            RECOMMENDATION: approveSuggested
            JUSTIFICATION: ok.
            """
        let report = try XCTUnwrap(
            BASWorldPriorAIReviewerSimulation
                .parseReviewReport(
                    from: reply,
                    templateID: "tmpl-x-y"))
        // CHECK_1 ("PASSAT") MUST classify as FAIL —
        // word-boundary check catches non-exact match.
        XCTAssertFalse(
            report.checklistResults[0].pass,
            "PASSAT must NOT classify as PASS")
        // Others all pass.
        XCTAssertTrue(
            report.checklistResults[1].pass)
    }

    // MARK: - Em-dash priority over ASCII hyphen

    func test_emDashPriorityOverAsciiHyphen() throws {
        // Comment "see e-mail" contains ASCII hyphen.
        // Em-dash is the actual separator. Parser must
        // split on em-dash, not on the first ASCII hyphen.
        let reply = """
            CHECK_1: PASS — see e-mail for details
            CHECK_2: PASS - ok
            CHECK_3: PASS - ok
            CHECK_4: PASS - ok
            CHECK_5: PASS - ok
            CHECK_6: PASS - ok
            RECOMMENDATION: approveSuggested
            JUSTIFICATION: ok.
            """
        let report = try XCTUnwrap(
            BASWorldPriorAIReviewerSimulation
                .parseReviewReport(
                    from: reply,
                    templateID: "tmpl-x-y"))
        // Comment must be the WHOLE em-dashed comment,
        // not split at "e-mail"'s hyphen.
        XCTAssertEqual(
            report.checklistResults[0].comment,
            "see e-mail for details",
            "em-dash takes priority; ASCII hyphen inside " +
            "comment must NOT split early")
    }

    // MARK: - Duplicate CHECK_n line tolerance (last-wins)

    func test_duplicateCheckLinesLastWriteWins() throws {
        // AFM occasionally echoes the prompt format then
        // provides actual answers. Parser should tolerate
        // and use last value.
        let reply = """
            CHECK_1: <PASS or FAIL> - <comment>
            CHECK_2: <PASS or FAIL> - <comment>
            CHECK_3: <PASS or FAIL> - <comment>
            CHECK_4: <PASS or FAIL> - <comment>
            CHECK_5: <PASS or FAIL> - <comment>
            CHECK_6: <PASS or FAIL> - <comment>
            CHECK_1: PASS - actual answer 1
            CHECK_2: FAIL - actual answer 2
            CHECK_3: PASS - actual answer 3
            CHECK_4: PASS - actual answer 4
            CHECK_5: PASS - actual answer 5
            CHECK_6: PASS - actual answer 6
            RECOMMENDATION: needsExpertJudgment
            JUSTIFICATION: actual.
            """
        let report = try XCTUnwrap(
            BASWorldPriorAIReviewerSimulation
                .parseReviewReport(
                    from: reply,
                    templateID: "tmpl-x-y"))
        XCTAssertEqual(
            report.checklistResults.count, 6)
        // Last write wins — actual answers retained.
        XCTAssertTrue(
            report.checklistResults[0].pass,
            "CHECK_1 last-write should be PASS")
        XCTAssertFalse(
            report.checklistResults[1].pass,
            "CHECK_2 last-write should be FAIL")
        XCTAssertEqual(
            report.checklistResults[0].comment,
            "actual answer 1")
    }

    // MARK: - Reject-over-approve precedence

    func test_rejectBecauseNotApproveWorthy() throws {
        // AFM saying "reject because not approve-worthy" —
        // contains both "reject" and "approve". Parser
        // must classify as REJECT, not APPROVE.
        let reply = """
            CHECK_1: PASS - ok
            CHECK_2: PASS - ok
            CHECK_3: PASS - ok
            CHECK_4: PASS - ok
            CHECK_5: PASS - ok
            CHECK_6: PASS - ok
            RECOMMENDATION: rejectSuggested because not approve-worthy
            JUSTIFICATION: too narrow.
            """
        let report = try XCTUnwrap(
            BASWorldPriorAIReviewerSimulation
                .parseReviewReport(
                    from: reply,
                    templateID: "tmpl-x-y"))
        XCTAssertEqual(
            report.overallRecommendation,
            .rejectSuggested,
            "reject takes priority over approve when both " +
            "appear in the recommendation line")
    }

    func test_approveOnlyClassifiesApprove() throws {
        // Sanity: pure "approve" with no "reject" still
        // approves.
        let reply = """
            CHECK_1: PASS - ok
            CHECK_2: PASS - ok
            CHECK_3: PASS - ok
            CHECK_4: PASS - ok
            CHECK_5: PASS - ok
            CHECK_6: PASS - ok
            RECOMMENDATION: approveSuggested
            JUSTIFICATION: ok.
            """
        let report = try XCTUnwrap(
            BASWorldPriorAIReviewerSimulation
                .parseReviewReport(
                    from: reply,
                    templateID: "tmpl-x-y"))
        XCTAssertEqual(
            report.overallRecommendation,
            .approveSuggested)
    }

    // MARK: - Persona reviewer (same robustness pattern)

    func test_personaParserRejectOverApprove() throws {
        let reply = """
            RECOMMENDATION: rejectSuggested - not approve-quality
            DOMAIN_COMMENT: Misses the key dimension.
            CITED_CONCEPTS: x
            """
        let review = try XCTUnwrap(
            BASWorldPriorAIPersonaReviewer
                .parsePersonaReview(
                    from: reply,
                    persona: .relationshipTherapist,
                    templateID: "tmpl-relationship-test"))
        XCTAssertEqual(
            review.recommendation, .rejectSuggested,
            "persona parser must also prefer reject over approve")
    }

    // MARK: - concurrencyPhase totality

    func test_everySeatHasAssignedPhase() {
        // After fix, no fallback — fatalError if not mapped.
        // Verify all 9 seats are exhaustively mapped (no
        // crash means no fallback path triggered).
        for seat in QinaoSeat.allCases {
            // Just access it; if any seat hadn't been
            // mapped to a phase, this would crash.
            _ = seat.concurrencyPhase
        }
    }
}
