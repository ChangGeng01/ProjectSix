import XCTest
import Foundation
@testable import BASOrgan
@testable import BASRuntimeCore

/// audit organ-eval MED-5 — a GATED-SKIP verification (no stage ran) must be
/// distinguishable from a genuinely-verified report. The old empty-`perStage`
/// report was identical whether verification was skipped, unwired, or
/// ran-and-passed, so skipping verification read as passing it (fail-open).
final class BASLLMVerifierGatedSkipTests: XCTestCase {

    private func makeDraft(_ body: String = "raw draft") -> BASOrganDraft {
        BASOrganDraft(requestID: "req", providerID: "test", role: .scout, body: body,
                      inputTokensEstimated: 0, outputTokensEstimated: 0,
                      producedAt: Date(), traceID: "tr")
    }
    private func makeTaskPackage() -> BASLLMTaskPackage {
        BASLLMTaskPackage(taskID: "t", originSessionID: "s", compiledAtMs: 0, intent: "i", goal: "g")
    }
    private func report(gated: Bool) -> BASLLMVerifierReport {
        BASLLMVerifierReport(perStage: [:], finalRecommendedAnswer: "d",
                             overallConfidence: 0.5, aggregatedCounterArguments: [], gatedSkip: gated)
    }

    // MARK: - audit organ-eval MED-5 clause 2 — failure labels in DETERMINISTIC order

    private func outcome(_ s: BASLLMVerifierStage, ok: Bool) -> BASLLMVerifierStageOutcome {
        BASLLMVerifierStageOutcome(stage: s, rawOutput: "", succeeded: ok,
                                   errorMessage: ok ? "" : "boom")
    }
    private func reportWith(_ perStage: [BASLLMVerifierStage: BASLLMVerifierStageOutcome]) -> BASLLMVerifierReport {
        BASLLMVerifierReport(perStage: perStage, finalRecommendedAnswer: "d",
                             overallConfidence: 0.5, aggregatedCounterArguments: [])
    }

    func testFailureLabelsFollowAllCasesOrderNotDictOrder() {
        // reviewer(0) + compressor(3) fail, factChecker(2) succeeds → canonical allCases order.
        let r = reportWith([
            .compressor: outcome(.compressor, ok: false),
            .reviewer: outcome(.reviewer, ok: false),
            .factChecker: outcome(.factChecker, ok: true),
        ])
        XCTAssertEqual(r.orderedFailureLabels,
            ["verifier-stage-failed:reviewer", "verifier-stage-failed:compressor"],
            "failure labels must be in BASLLMVerifierStage.allCases (declaration) order — reviewer "
            + "before compressor — never in nondeterministic Dictionary order (M892 replay-determinism)")
    }

    func testAllStagesFailedIsTheFullCanonicalSequence() {
        let r = reportWith(Dictionary(uniqueKeysWithValues:
            BASLLMVerifierStage.allCases.map { ($0, outcome($0, ok: false)) }))
        XCTAssertEqual(r.orderedFailureLabels,
            BASLLMVerifierStage.allCases.map { "verifier-stage-failed:" + $0.rawValue },
            "every failed stage in exact declaration order")
    }

    // MARK: report-level

    func testGatedSkipDistinguishesFromRanReportOfSameShape() {
        XCTAssertTrue(report(gated: true).gatedSkip)
        XCTAssertFalse(report(gated: false).gatedSkip)
        XCTAssertNotEqual(report(gated: true), report(gated: false),
            "a gated-skip (unreviewed) must differ from a ran report of the same empty shape")
    }

    func testCodableAbsentKeyDecodesAsNotGated() throws {
        var obj = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(report(gated: true))) as! [String: Any]
        obj.removeValue(forKey: "gatedSkip")   // simulate a report persisted before the field
        let legacy = try JSONSerialization.data(withJSONObject: obj)
        let decoded = try JSONDecoder().decode(BASLLMVerifierReport.self, from: legacy)
        XCTAssertFalse(decoded.gatedSkip, "an absent key decodes as not-gated (byte-stable)")
    }

    // MARK: pipeline-level

    func testGatedVerifyMarksGatedSkipTrue() async {
        let pipeline = BASLLMVerifierPipeline(adapters: [:], verifyGate: { _, _ in false })
        let r = await pipeline.verify(draft: makeDraft(), taskPackage: makeTaskPackage())
        XCTAssertTrue(r.gatedSkip,
            "a gated verify must mark gatedSkip=true — an unreviewed draft is not a passed one")
    }

    func testUngatedVerifyWithNoStagesIsNotAGatedSkip() async {
        let pipeline = BASLLMVerifierPipeline(adapters: [:], verifyGate: { _, _ in true })
        let r = await pipeline.verify(draft: makeDraft(), taskPackage: makeTaskPackage())
        XCTAssertFalse(r.gatedSkip, "an ungated verify (even with no stages wired) is NOT a gated-skip")
        XCTAssertTrue(r.perStage.isEmpty)
    }

    // MARK: consumer-boundary (makeEngineVerifierCallback) — the fail-open the write-only report
    // flag missed. The report-level gatedSkip was read by ZERO production consumers; the engine
    // callback collapsed a gated-skip (empty perStage ⇒ allSatisfy vacuously true) into a clean
    // approve. These pin the fix at the boundary the M932 engine + L11 gate actually consume.

    /// Reversal-red teeth: revert `approved = allSucceeded && !report.gatedSkip` back to
    /// `approved: allSucceeded` (or drop the feedback gatedSkip field) and this reds — a gated-skip
    /// draft reads as verifier-approved again, byte-identical to a clean all-pass.
    func testGatedSkipCallbackIsNotApprovedAndCarriesFlag() async throws {
        let pipeline = BASLLMVerifierPipeline(adapters: [:], verifyGate: { _, _ in false })
        let feedback = try await pipeline.makeEngineVerifierCallback()(makeDraft(), makeTaskPackage())
        XCTAssertFalse(feedback.approved,
            "a gated-skip (unverified) draft must NOT read as verifier-approved at the consumer boundary")
        XCTAssertTrue(feedback.gatedSkip,
            "the consumer feedback must carry gatedSkip so L11 can tell 'unverified' from 'a stage failed'")
        XCTAssertNotEqual(feedback, BASLLMVerifierFeedback.approvedNoAmendments,
            "an unverified draft's feedback must not equal a clean all-pass")
    }

    func testUngatedNoStagesCallbackStillApproves() async throws {
        let pipeline = BASLLMVerifierPipeline(adapters: [:], verifyGate: { _, _ in true })
        let feedback = try await pipeline.makeEngineVerifierCallback()(makeDraft(), makeTaskPackage())
        XCTAssertTrue(feedback.approved,
            "an ungated run with no wired stages still approves — the fix must not over-block real passes")
        XCTAssertFalse(feedback.gatedSkip)
    }

    func testFeedbackCodableAbsentGatedSkipDecodesAsFalse() throws {
        var obj = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(BASLLMVerifierFeedback(approved: false, gatedSkip: true))) as! [String: Any]
        obj.removeValue(forKey: "gatedSkip")   // simulate feedback persisted before the field
        let legacy = try JSONSerialization.data(withJSONObject: obj)
        let decoded = try JSONDecoder().decode(BASLLMVerifierFeedback.self, from: legacy)
        XCTAssertFalse(decoded.gatedSkip, "an absent gatedSkip key decodes as not-gated (byte-stable)")
    }
}
