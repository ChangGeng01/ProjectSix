// MARK: - BASChengluHintSetReasonCodesTests — chapter 三百三〇 / M817
//
// Phase F (附录 X) 第九刀 测试覆盖:typed audit emission helper
// for hint set。
//
// Doctrine pins verified:
//   - Prefix constant typed-pinned ("chenglu-hint")
//   - Per-family code count + format
//   - Aggregated `codes(for: hintSet)` ordering
//   - fullySaturatedCodeCount = 18 (sum of per-family counts)
//   - Empty hint set → empty code array

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChengluHintSetReasonCodesTests: XCTestCase {

    // MARK: - Prefix pin

    func testPrefixIsChengluHint() {
        XCTAssertEqual(
            BASChengluHintSetReasonCodes.prefix,
            "chenglu-hint")
    }

    // MARK: - Per-family code synthesis

    func testPreflightHintEmits3Codes() {
        let hint = BASChengluPreflightHint(
            route: .afm,
            probability: 0.95,
            confidence: .high)
        let codes = BASChengluHintSetReasonCodes.codes(
            forPreflight: hint)
        XCTAssertEqual(codes.count, 3)
        XCTAssertTrue(codes.contains(
            "chenglu-hint:preflight:route:afm-route"))
        XCTAssertTrue(codes.contains(
            "chenglu-hint:preflight:probability:0.9500"))
        XCTAssertTrue(codes.contains(
            "chenglu-hint:preflight:confidence:high"))
    }

    func testPreflightGemmaRouteCodes() {
        let hint = BASChengluPreflightHint(
            route: .gemma,
            probability: 0.30,
            confidence: .medium)
        let codes = BASChengluHintSetReasonCodes.codes(
            forPreflight: hint)
        XCTAssertTrue(codes.contains(
            "chenglu-hint:preflight:route:gemma-route"))
        XCTAssertTrue(codes.contains(
            "chenglu-hint:preflight:confidence:medium"))
    }

    func testLengthHintEmits2Codes() {
        let hint = BASChengluLengthHint(
            predictedLengthChars: 750.5,
            confidence: .high)
        let codes = BASChengluHintSetReasonCodes.codes(
            forLength: hint)
        XCTAssertEqual(codes.count, 2)
        XCTAssertTrue(codes.contains(
            "chenglu-hint:length:predicted-chars:750.5"))
        XCTAssertTrue(codes.contains(
            "chenglu-hint:length:confidence:high"))
    }

    func testLatencyHintEmits2Codes() {
        let hint = BASChengluLatencyHint(
            predictedDurationMs: 1500,
            confidence: .low)
        let codes = BASChengluHintSetReasonCodes.codes(
            forLatency: hint)
        XCTAssertEqual(codes.count, 2)
        XCTAssertTrue(codes.contains(
            "chenglu-hint:latency:predicted-ms:1500.0"))
        XCTAssertTrue(codes.contains(
            "chenglu-hint:latency:confidence:low"))
    }

    func testMultiHeadHintEmits2CodesWithOutputKeyPrefix() {
        let intent = BASChengluMultiHeadHint(
            outputKey: "intent",
            score: 0.85,
            confidence: .high)
        let codes = BASChengluHintSetReasonCodes.codes(
            forMultiHead: intent)
        XCTAssertEqual(codes.count, 2)
        XCTAssertTrue(codes.contains(
            "chenglu-hint:intent:score:0.8500"))
        XCTAssertTrue(codes.contains(
            "chenglu-hint:intent:confidence:high"))
    }

    func testMultiHeadHintForRiskKey() {
        let risk = BASChengluMultiHeadHint(
            outputKey: "risk",
            score: 0.42,
            confidence: .medium)
        let codes = BASChengluHintSetReasonCodes.codes(
            forMultiHead: risk)
        XCTAssertTrue(codes.contains(
            "chenglu-hint:risk:score:0.4200"))
        XCTAssertTrue(codes.contains(
            "chenglu-hint:risk:confidence:medium"))
    }

    func testPermitPredictHintEmits3Codes() {
        let hint = BASChengluPermitPredictHint(
            policy: .block,
            blockProbability: 0.92,
            confidence: .high)
        let codes = BASChengluHintSetReasonCodes.codes(
            forPermitPredict: hint)
        XCTAssertEqual(codes.count, 3)
        XCTAssertTrue(codes.contains(
            "chenglu-hint:permit-predict:policy:block"))
        XCTAssertTrue(codes.contains(
            "chenglu-hint:permit-predict:block-probability:" +
            "0.9200"))
        XCTAssertTrue(codes.contains(
            "chenglu-hint:permit-predict:confidence:high"))
    }

    func testPermitPredictDelayPolicy() {
        let hint = BASChengluPermitPredictHint(
            policy: .delay,
            blockProbability: 0.20,
            confidence: .high)
        let codes = BASChengluHintSetReasonCodes.codes(
            forPermitPredict: hint)
        XCTAssertTrue(codes.contains(
            "chenglu-hint:permit-predict:policy:delay"))
    }

    // MARK: - Aggregated hint set codes

    func testEmptyHintSetEmitsNoCodes() {
        let codes = BASChengluHintSetReasonCodes.codes(
            for: .empty)
        XCTAssertTrue(codes.isEmpty)
    }

    func testFullyPopulatedHintSetEmits18Codes() {
        let hintSet = BASChengluHintSet(
            preflight: BASChengluPreflightHint(
                route: .afm, probability: 0.95,
                confidence: .high),
            length: BASChengluLengthHint(
                predictedLengthChars: 800,
                confidence: .high),
            latency: BASChengluLatencyHint(
                predictedDurationMs: 1200,
                confidence: .high),
            intent: BASChengluMultiHeadHint(
                outputKey: "intent", score: 0.85,
                confidence: .high),
            emotion: BASChengluMultiHeadHint(
                outputKey: "emotion", score: 0.82,
                confidence: .high),
            risk: BASChengluMultiHeadHint(
                outputKey: "risk", score: 0.78,
                confidence: .medium),
            memoryImportance: BASChengluMultiHeadHint(
                outputKey: "memory_importance",
                score: 0.92, confidence: .high),
            permitPredict: BASChengluPermitPredictHint(
                policy: .block, blockProbability: 0.90,
                confidence: .high))
        let codes = BASChengluHintSetReasonCodes.codes(
            for: hintSet)
        XCTAssertEqual(
            codes.count,
            BASChengluHintSetReasonCodes
                .fullySaturatedCodeCount,
            "Fully saturated hint set must emit 18 codes")
        XCTAssertEqual(codes.count, 18)
    }

    func testAggregatedCodesPreservesFamilyOrder() {
        let hintSet = BASChengluHintSet(
            preflight: BASChengluPreflightHint(
                route: .afm, probability: 0.95,
                confidence: .high),
            permitPredict: BASChengluPermitPredictHint(
                policy: .block, blockProbability: 0.90,
                confidence: .high))
        let codes = BASChengluHintSetReasonCodes.codes(
            for: hintSet)
        XCTAssertEqual(codes.count, 6,
            "preflight (3) + permitPredict (3) = 6")
        // Preflight codes must come before permit-predict codes
        let preflightIndex = codes.firstIndex(where: {
            $0.hasPrefix("chenglu-hint:preflight:")
        })
        let permitPredictIndex = codes.firstIndex(where: {
            $0.hasPrefix("chenglu-hint:permit-predict:")
        })
        XCTAssertNotNil(preflightIndex)
        XCTAssertNotNil(permitPredictIndex)
        XCTAssertLessThan(preflightIndex!, permitPredictIndex!)
    }

    func testAggregatedCodesPartialPopulation() {
        let hintSet = BASChengluHintSet(
            length: BASChengluLengthHint(
                predictedLengthChars: 500,
                confidence: .high))
        let codes = BASChengluHintSetReasonCodes.codes(
            for: hintSet)
        XCTAssertEqual(codes.count, 2,
            "Single-field hint set emits per-family count " +
            "(length = 2 codes)")
    }

    // MARK: - fullySaturatedCodeCount pin

    func testFullySaturatedCountIs18() {
        XCTAssertEqual(
            BASChengluHintSetReasonCodes
                .fullySaturatedCodeCount,
            18,
            "3 (preflight) + 2 (length) + 2 (latency) + " +
            "4×2 (multi-head) + 3 (permit-predict) = 18")
    }
}
