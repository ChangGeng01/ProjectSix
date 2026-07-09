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
}
