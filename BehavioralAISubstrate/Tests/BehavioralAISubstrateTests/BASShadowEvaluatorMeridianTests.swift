import XCTest
@testable import BASEvaluation

/// chapter 二百七十 / M757 — multi-head meridian + 2 stub heads
/// coverage.
final class BASShadowEvaluatorMeridianTests: XCTestCase {

    // MARK: - 1. Empty heads → empty result

    func testEmptyMeridianReturnsEmptyResult() async {
        let m = BASShadowEvaluatorMeridian(heads: [])
        let r = await m.evaluate(
            prompt: "x", body: "y",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertEqual(r.perHead.count, 0)
        XCTAssertFalse(r.mergedShifted)
        XCTAssertEqual(r.nonSkippedHeadCount, 0)
        XCTAssertEqual(r.shiftedHeadCount, 0)
    }

    // MARK: - 2. Quality head: very-short body flagged

    func testQualityHeadFlagsShortBody() async {
        let head = BASQualityShadowHead(
            minAcceptableLength: 10)
        let r = await head.evaluate(
            prompt: "x",
            body: "ok",
            prePermitMode: "answer",
            sessionRef: "s",
            turnRef: "t")
        XCTAssertTrue(r.shifted)
        XCTAssertTrue(
            r.reasonCodes.contains(where: {
                $0.hasPrefix("quality:flag:very-short:")
            }))
    }

    // MARK: - 3. Quality head: repetitive body flagged

    func testQualityHeadFlagsRepetitiveBody() async {
        let head = BASQualityShadowHead(
            minAcceptableLength: 1,
            maxRepetitionRatio: 0.5)
        // 100 chars, all 'x' → 1 distinct → ratio = 1 - 1/100
        // = 0.99 > 0.5
        let r = await head.evaluate(
            prompt: "x",
            body: String(repeating: "x", count: 100),
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertTrue(r.shifted)
        XCTAssertTrue(
            r.reasonCodes.contains(where: {
                $0.hasPrefix("quality:flag:repetitive:")
            }))
    }

    // MARK: - 4. Quality head: ok body not flagged

    func testQualityHeadOkBodyNotFlagged() async {
        let head = BASQualityShadowHead()
        let r = await head.evaluate(
            prompt: "x",
            body: "This is a perfectly fine, varied response.",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertFalse(r.shifted)
        XCTAssertEqual(r.reasonCodes, ["quality:ok"])
    }

    // MARK: - 5. Quality head: empty body skipped

    func testQualityHeadEmptyBodySkipped() async {
        let head = BASQualityShadowHead()
        let r = await head.evaluate(
            prompt: "x",
            body: "",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertNil(r.postPermitMode)
        XCTAssertFalse(r.shifted)
    }

    // MARK: - 6. Hallucination head: pattern match flagged

    func testHallucinationHeadFlagsSuspiciousPattern() async {
        let head = BASHallucinationShadowHead()
        let r = await head.evaluate(
            prompt: "x",
            body: "Studies show that everyone agrees with X.",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertTrue(r.shifted)
        XCTAssertTrue(
            r.reasonCodes.contains(where: {
                $0.hasPrefix(
                    "hallucination:flag:suspicious-pattern:")
            }))
    }

    // MARK: - 7. Hallucination head: clean body not flagged

    func testHallucinationHeadCleanBodyNotFlagged() async {
        let head = BASHallucinationShadowHead()
        let r = await head.evaluate(
            prompt: "x",
            body: "I think you should consider Y first.",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertFalse(r.shifted)
        XCTAssertEqual(r.reasonCodes, ["hallucination:ok"])
    }

    // MARK: - 8. Meridian: 2-head + anyShifted

    func testMeridianTwoHeadAnyShifted() async {
        let meridian = BASShadowEvaluatorMeridian(
            heads: [
                BASQualityShadowHead(),  // ok body → no shift
                BASHallucinationShadowHead()  // suspicious → shift
            ],
            mergeStrategy: .anyShifted)
        let r = await meridian.evaluate(
            prompt: "x",
            body: "Studies show this is fine quality output.",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertEqual(r.perHead.count, 2)
        // Meridian-level merge per anyShifted: hallucination
        // shifts → merged shifted true
        XCTAssertTrue(r.mergedShifted)
        XCTAssertEqual(r.shiftedHeadCount, 1)
    }

    // MARK: - 9. Meridian: 2-head + allShifted requires both

    func testMeridianAllShiftedRequiresBoth() async {
        // Body is OK (quality won't shift) but suspicious
        // (hallucination will shift). With allShifted →
        // mergedShifted = false because not all shifted.
        let meridian = BASShadowEvaluatorMeridian(
            heads: [
                BASQualityShadowHead(),
                BASHallucinationShadowHead()
            ],
            mergeStrategy: .allShifted)
        let r = await meridian.evaluate(
            prompt: "x",
            body: "Studies show this is fine quality output.",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertFalse(r.mergedShifted)
    }

    // MARK: - 10. Per-head detail preserved

    func testPerHeadDetailPreserved() async {
        let qHead = BASQualityShadowHead()
        let hHead = BASHallucinationShadowHead()
        let meridian = BASShadowEvaluatorMeridian(
            heads: [qHead, hHead])
        let r = await meridian.evaluate(
            prompt: "x",
            body: "Studies show this is fine output.",
            prePermitMode: "answer",
            sessionRef: "s", turnRef: "t")
        XCTAssertEqual(r.perHead.count, 2)
        XCTAssertEqual(
            r.perHead[0].evaluatorVersion,
            "quality-rules-v1")
        XCTAssertEqual(
            r.perHead[1].evaluatorVersion,
            "hallucination-rules-v1")
    }

    // MARK: - 11. Auto-derived meridianVersion

    func testAutoDerivedMeridianVersion() async {
        let meridian = BASShadowEvaluatorMeridian(
            heads: [
                BASQualityShadowHead(),
                BASHallucinationShadowHead()
            ],
            mergeStrategy: .anyShifted)
        let v = await meridian.meridianVersion
        XCTAssertEqual(
            v,
            "meridian:any-shifted:" +
            "[quality-rules-v1+hallucination-rules-v1]")
    }

    // MARK: - 12. Custom meridianVersion override

    func testCustomMeridianVersionOverride() async {
        let meridian = BASShadowEvaluatorMeridian(
            heads: [BASQualityShadowHead()],
            meridianVersion: "custom-meridian-v9")
        let v = await meridian.meridianVersion
        XCTAssertEqual(v, "custom-meridian-v9")
    }

    // MARK: - 13. Schema version pinned

    func testMeridianResultSchemaVersionPinned() {
        XCTAssertEqual(
            BASShadowEvaluatorMeridianResult
                .currentSchemaVersion,
            "1.0.0")
    }

    // MARK: - 14. Init clamping (max-repetition + min-length)

    func testQualityHeadInitClamping() {
        let h = BASQualityShadowHead(
            minAcceptableLength: 0,
            maxRepetitionRatio: 5.0)
        XCTAssertEqual(h.minAcceptableLength, 1)
        XCTAssertEqual(h.maxRepetitionRatio, 1.0)
    }

    // MARK: - 15. Hallucination head init filters empty patterns

    func testHallucinationHeadFiltersEmptyPatterns() {
        let h = BASHallucinationShadowHead(
            suspiciousClaimPatterns: [
                "  Studies Show  ",
                "",
                "Everyone Knows"
            ])
        XCTAssertEqual(
            h.suspiciousClaimPatterns,
            ["studies show", "everyone knows"])
    }
}
