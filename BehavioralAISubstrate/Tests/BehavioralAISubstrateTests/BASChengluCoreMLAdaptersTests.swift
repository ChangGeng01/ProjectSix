// MARK: - BASChengluCoreMLAdaptersTests — chapter 三百二一 / M808
//
// Phase F (附录 X) 第二刀 测试覆盖第一部分:5 concrete Chenglu
// adapters + canonical 43-dim feature encoder + 8 canonical slot
// layer ID assignments per附录 X §X.2 doctrine。
//
// Tests use parametric closure init throughout so no real
// `.mlpackage` binary is required in BAS test target — keeps
// BAS cross-platform clean (matches chapter 三百二〇 pattern)。
//
// Doctrine pins verified:
//   - chapter 一百八十一 multi-head shared encoder: 4 outputs from
//     one MLModel = 4 distinct registry slots
//   - chapter 一百七十七 v0.4 confidence boundaries
//   - chapter 二百一一 single-source-of-truth for feature encoding

import XCTest
@testable import BASAppleAdapters
@testable import BASRuntimeCore

final class BASChengluCoreMLAdaptersTests: XCTestCase {

    // MARK: - Test fixtures

    private func makeInput(
        layerID: BASMotherboardLayer14 = .l4,
        featureRef: String =
            "anxious|medical|critical|today|trusted-ai|question|2"
    ) -> BASLayerInferenceInput {
        BASLayerInferenceInput(
            layerID: layerID,
            featureRef: featureRef,
            confidenceFloor: .medium)
    }

    private func makeStubClosure(
        score: Double,
        outputKey: String,
        latencyMs: Double = 0.5
    ) -> @Sendable (BASCoreMLFeatureFrame) async throws
        -> BASCoreMLPredictionFrame
    {
        return { _ in
            BASCoreMLPredictionFrame(
                scores: [outputKey: score],
                modelDescription: "stub",
                inferenceLatencyMs: latencyMs)
        }
    }

    // MARK: - BASChengluFeatureEncoder

    func testFeatureEncoderTotalDimensionIs43() {
        XCTAssertEqual(
            BASChengluFeatureEncoder.totalDimension, 43,
            "Canonical dimension count must match Python " +
            "schema: 8 tones + 10 domains + 6 stakes + 7 " +
            "timeframes + 4 confidants + 3 askshapes + 5 " +
            "mutation seeds = 43")
    }

    func testFeatureEncoderCategoryCardinalities() {
        XCTAssertEqual(BASChengluFeatureEncoder.tones.count, 8)
        XCTAssertEqual(
            BASChengluFeatureEncoder.domains.count, 10)
        XCTAssertEqual(BASChengluFeatureEncoder.stakes.count, 6)
        XCTAssertEqual(
            BASChengluFeatureEncoder.timeframes.count, 7)
        XCTAssertEqual(
            BASChengluFeatureEncoder.confidants.count, 4)
        XCTAssertEqual(
            BASChengluFeatureEncoder.askShapes.count, 3)
        XCTAssertEqual(
            BASChengluFeatureEncoder.mutationSeedCount, 5)
    }

    func testFeatureEncoderProducesCorrectShape() {
        let signature = BASChengluPromptSignature(
            tone: "anxious",
            domain: "medical",
            stake: "critical",
            timeframe: "today",
            confidant: "trusted-ai",
            askShape: "question",
            mutationSeed: 2)
        let frame = BASChengluFeatureEncoder.encode(
            signature: signature)

        // Total keys must equal 43
        XCTAssertEqual(
            frame.featureValues.count, 43,
            "Frame must have exactly 43 keys")

        // Sum of one-hot must equal 7 (one per categorical dim)
        let sum = frame.featureValues.values.reduce(0, +)
        XCTAssertEqual(
            sum, 7.0, accuracy: 0.0001,
            "Sum of one-hots must equal 7 (one per " +
            "categorical field + one mutation seed)")

        // Verify specific keys are 1.0
        XCTAssertEqual(
            frame.featureValues["tone_anxious"], 1.0)
        XCTAssertEqual(
            frame.featureValues["domain_medical"], 1.0)
        XCTAssertEqual(
            frame.featureValues["stake_critical"], 1.0)
        XCTAssertEqual(
            frame.featureValues["timeframe_today"], 1.0)
        XCTAssertEqual(
            frame.featureValues["confidant_trusted-ai"], 1.0)
        XCTAssertEqual(
            frame.featureValues["askshape_question"], 1.0)
        XCTAssertEqual(
            frame.featureValues["mutation_seed_2"], 1.0)

        // Verify a non-matched key is 0.0
        XCTAssertEqual(
            frame.featureValues["tone_calm"], 0.0)
        XCTAssertEqual(
            frame.featureValues["mutation_seed_0"], 0.0)
    }

    func testFeatureEncoderUnknownCategoryProducesAllZeros() {
        let signature = BASChengluPromptSignature(
            tone: "unknown-tone-not-in-list",
            domain: "medical",
            stake: "low",
            timeframe: "indefinite",
            confidant: "trusted-ai",
            askShape: "question",
            mutationSeed: 0)
        let frame = BASChengluFeatureEncoder.encode(
            signature: signature)
        // All tone slots zero (unknown tone)
        for tone in BASChengluFeatureEncoder.tones {
            XCTAssertEqual(
                frame.featureValues["tone_\(tone)"], 0.0,
                "Unknown tone must produce all-zero tone slots")
        }
        // Domain still set (recognized)
        XCTAssertEqual(
            frame.featureValues["domain_medical"], 1.0)
    }

    func testFeatureEncoderOutOfRangeMutationSeedProducesAllZeros()
    {
        let signature = BASChengluPromptSignature(
            tone: "calm", domain: "medical",
            stake: "low", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 99)
        let frame = BASChengluFeatureEncoder.encode(
            signature: signature)
        for i in 0..<5 {
            XCTAssertEqual(
                frame.featureValues["mutation_seed_\(i)"], 0.0,
                "Out-of-range seed must produce all-zero " +
                "mutation slots")
        }
    }

    // MARK: - parseBASChengluSignature

    func testParseSignatureCanonicalFormat() {
        let parsed = parseBASChengluSignature(
            from:
                "anxious|medical|critical|today|trusted-ai|" +
                "question|2")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.tone, "anxious")
        XCTAssertEqual(parsed?.domain, "medical")
        XCTAssertEqual(parsed?.stake, "critical")
        XCTAssertEqual(parsed?.timeframe, "today")
        XCTAssertEqual(parsed?.confidant, "trusted-ai")
        XCTAssertEqual(parsed?.askShape, "question")
        XCTAssertEqual(parsed?.mutationSeed, 2)
    }

    func testParseSignatureWrongFieldCountReturnsNil() {
        XCTAssertNil(parseBASChengluSignature(
            from: "too|few|fields"))
        XCTAssertNil(parseBASChengluSignature(from: ""))
        XCTAssertNil(parseBASChengluSignature(
            from: "a|b|c|d|e|f|g|h"))  // 8 fields
    }

    func testParseSignatureNonNumericMutationSeedReturnsNil() {
        XCTAssertNil(parseBASChengluSignature(
            from: "a|b|c|d|e|f|notanint"))
    }

    // MARK: - BASChengluPreflightAdapter

    func testPreflightAdapterAFMRouteOnHighScore() async throws {
        let head = BASChengluPreflightAdapter.makeWithClosure(
            headID: "test.preflight",
            layerIDPin: .l1,
            inferenceClosure: makeStubClosure(
                score: 0.95,
                outputKey: BASChengluPreflightAdapter
                    .outputKey))
        let output = try await head.infer(
            input: makeInput(layerID: .l1))
        XCTAssertEqual(output.recommendedAction, "afm-route")
        XCTAssertEqual(output.confidence, .high)
        XCTAssertEqual(output.layerID, .l1)
        XCTAssertTrue(output.reasonCodes.contains(
            "coreml-head:chenglu-preflight"))
    }

    func testPreflightAdapterGemmaRouteOnLowScore() async throws {
        let head = BASChengluPreflightAdapter.makeWithClosure(
            headID: "test.preflight",
            layerIDPin: .l1,
            inferenceClosure: makeStubClosure(
                score: 0.2,
                outputKey: BASChengluPreflightAdapter
                    .outputKey))
        let output = try await head.infer(
            input: makeInput(layerID: .l1))
        XCTAssertEqual(output.recommendedAction, "gemma-route")
        XCTAssertEqual(output.confidence, .high)
    }

    func testPreflightAdapterMediumConfidenceNearBoundary()
        async throws
    {
        // |0.55 - 0.5| = 0.05, which is < 0.10 threshold → low
        let head = BASChengluPreflightAdapter.makeWithClosure(
            headID: "test.preflight",
            layerIDPin: .l1,
            inferenceClosure: makeStubClosure(
                score: 0.55,
                outputKey: BASChengluPreflightAdapter
                    .outputKey))
        let output = try await head.infer(
            input: makeInput(layerID: .l1))
        XCTAssertEqual(output.confidence, .low)
        XCTAssertEqual(output.recommendedAction, "afm-route")
    }

    // MARK: - BASChengluMultiHeadAdapter

    func testMultiHeadAdapterAllOutputKeysSet() {
        XCTAssertEqual(
            BASChengluMultiHeadAdapter.intentKey, "intent")
        XCTAssertEqual(
            BASChengluMultiHeadAdapter.emotionKey, "emotion")
        XCTAssertEqual(
            BASChengluMultiHeadAdapter.riskKey, "risk")
        XCTAssertEqual(
            BASChengluMultiHeadAdapter.memoryImportanceKey,
            "memory_importance")
        XCTAssertEqual(
            BASChengluMultiHeadAdapter.allOutputKeys.count, 4)
    }

    func testMultiHeadAdapterUsesSpecifiedOutputKey()
        async throws
    {
        // Chapter 三百三七 / M824 fix: previous version only
        // checked reasonCode strings — would pass even if
        // adapter ignored outputKey and always used "intent"。
        // This version constructs TWO adapters with different
        // outputKey values from the SAME inference closure
        // (returns same multi-output frame),then asserts that
        // each adapter's confidence + reason code reflects its
        // specific outputKey's score。
        let scores: [String: Double] = [
            "intent": 0.95,            // → high confidence
            "emotion": 0.50,           // → low (= midpoint)
            "risk": 0.40,              // → medium
            "memory_importance": 0.60  // → low
        ]
        let sharedClosure:
            @Sendable (BASCoreMLFeatureFrame) async throws
                -> BASCoreMLPredictionFrame = { _ in
            BASCoreMLPredictionFrame(
                scores: scores,
                inferenceLatencyMs: 0.3)
        }
        let intentHead = BASChengluMultiHeadAdapter
            .makeWithClosure(
                headID: "intent-head",
                layerIDPin: .l4,
                outputKey: "intent",
                inferenceClosure: sharedClosure)
        let emotionHead = BASChengluMultiHeadAdapter
            .makeWithClosure(
                headID: "emotion-head",
                layerIDPin: .l4,
                outputKey: "emotion",
                inferenceClosure: sharedClosure)

        let intentOutput = try await intentHead.infer(
            input: makeInput(layerID: .l4))
        let emotionOutput = try await emotionHead.infer(
            input: makeInput(layerID: .l4))

        // Different outputKeys must produce DIFFERENT
        // confidence + reason codes from same inference frame
        XCTAssertNotEqual(
            intentOutput.confidence,
            emotionOutput.confidence,
            "Different outputKey values against the same " +
            "inference frame must produce DIFFERENT confidence " +
            "outcomes (intent=0.95→.high vs emotion=0.50→.low)")
        XCTAssertEqual(intentOutput.confidence, .high)
        XCTAssertEqual(emotionOutput.confidence, .low)
        XCTAssertTrue(intentOutput.reasonCodes.contains(
            "coreml-output-key:intent"))
        XCTAssertTrue(emotionOutput.reasonCodes.contains(
            "coreml-output-key:emotion"))
        // Original assertions preserved for backward compat:
        XCTAssertTrue(intentOutput.reasonCodes.contains(
            "coreml-head:chenglu-multihead"))
    }

    // MARK: - BASChengluPermitPredictAdapter

    func testPermitPredictAdapterBlockOnHighProbability()
        async throws
    {
        let head = BASChengluPermitPredictAdapter
            .makeWithClosure(
                headID: "test.permitpredict",
                layerIDPin: .l11,
                inferenceClosure: makeStubClosure(
                    score: 0.90,
                    outputKey:
                        BASChengluPermitPredictAdapter
                            .outputKey))
        let output = try await head.infer(
            input: makeInput(layerID: .l11))
        XCTAssertEqual(output.recommendedAction, "block")
        XCTAssertTrue(output.reasonCodes.contains(
            "coreml-policy-hint:block"))
    }

    func testPermitPredictAdapterDelayOnLowProbability()
        async throws
    {
        let head = BASChengluPermitPredictAdapter
            .makeWithClosure(
                headID: "test.permitpredict",
                layerIDPin: .l11,
                inferenceClosure: makeStubClosure(
                    score: 0.15,
                    outputKey:
                        BASChengluPermitPredictAdapter
                            .outputKey))
        let output = try await head.infer(
            input: makeInput(layerID: .l11))
        XCTAssertEqual(output.recommendedAction, "delay")
        XCTAssertTrue(output.reasonCodes.contains(
            "coreml-policy-hint:delay"))
    }

    // MARK: - BASChengluLengthHeadAdapter

    func testLengthHeadAdapterRegressionOutput() async throws {
        let head = BASChengluLengthHeadAdapter.makeWithClosure(
            headID: "test.length",
            layerIDPin: .l12,
            inferenceClosure: makeStubClosure(
                score: 850.5,
                outputKey:
                    BASChengluLengthHeadAdapter.outputKey))
        let output = try await head.infer(
            input: makeInput(layerID: .l12))
        XCTAssertEqual(output.confidence, .high)
        XCTAssertEqual(output.layerID, .l12)
        XCTAssertTrue(output.reasonCodes.contains(
            "coreml-head:chenglu-length-head"))
        XCTAssertTrue(output.reasonCodes.contains(
            "coreml-prediction:body_length:850.5"))
    }

    func testLengthHeadAdapterOutOfRangeReturnsLowConfidence()
        async throws
    {
        // length = 75000 > maxSensible 50000 → .low
        let head = BASChengluLengthHeadAdapter.makeWithClosure(
            headID: "test.length",
            layerIDPin: .l12,
            inferenceClosure: makeStubClosure(
                score: 75000,
                outputKey:
                    BASChengluLengthHeadAdapter.outputKey))
        let output = try await head.infer(
            input: makeInput(layerID: .l12))
        XCTAssertEqual(output.confidence, .low)
    }

    // MARK: - BASChengluLatencyHeadAdapter

    func testLatencyHeadAdapterRegressionOutput() async throws {
        let head = BASChengluLatencyHeadAdapter.makeWithClosure(
            headID: "test.latency",
            layerIDPin: .l1,
            inferenceClosure: makeStubClosure(
                score: 2500,
                outputKey:
                    BASChengluLatencyHeadAdapter.outputKey))
        let output = try await head.infer(
            input: makeInput(layerID: .l1))
        XCTAssertEqual(output.confidence, .high)
        XCTAssertEqual(output.layerID, .l1)
        XCTAssertTrue(output.reasonCodes.contains(
            "coreml-head:chenglu-latency-head"))
    }

    func testLatencyHeadAdapterNegativeScoreLowConfidence()
        async throws
    {
        let head = BASChengluLatencyHeadAdapter.makeWithClosure(
            headID: "test.latency",
            layerIDPin: .l1,
            inferenceClosure: makeStubClosure(
                score: -10,
                outputKey:
                    BASChengluLatencyHeadAdapter.outputKey))
        let output = try await head.infer(
            input: makeInput(layerID: .l1))
        XCTAssertEqual(output.confidence, .low,
            "Negative latency below minSensible (0) must " +
            "yield .low confidence")
    }

    // MARK: - bASChengluRegressionConfidence

    func testRegressionConfidenceFiniteInRangeIsHigh() {
        XCTAssertEqual(
            bASChengluRegressionConfidence(
                score: 100,
                minSensible: 0,
                maxSensible: 200),
            .high)
    }

    func testRegressionConfidenceOutOfRangeIsLow() {
        XCTAssertEqual(
            bASChengluRegressionConfidence(
                score: 250,
                minSensible: 0,
                maxSensible: 200),
            .low)
        XCTAssertEqual(
            bASChengluRegressionConfidence(
                score: -1,
                minSensible: 0,
                maxSensible: 200),
            .low)
    }

    func testRegressionConfidenceNonFiniteIsUnknown() {
        XCTAssertEqual(
            bASChengluRegressionConfidence(
                score: .nan,
                minSensible: 0,
                maxSensible: 200),
            .unknown)
        XCTAssertEqual(
            bASChengluRegressionConfidence(
                score: .infinity,
                minSensible: 0,
                maxSensible: 200),
            .unknown)
    }

    // MARK: - Layer ID assignment doctrine (附录 X §X.2)

    func testHeadLayerIDAssignmentsMatchCanonicalDoctrine() {
        // Per附录 X §X.2 doctrine,each adapter must pin to
        // its canonical layer。`layerIDPin` is nonisolated so
        // accessible synchronously。
        let preflightHead = BASChengluPreflightAdapter
            .makeWithClosure(
                headID: "p", layerIDPin: .l1,
                inferenceClosure: makeStubClosure(
                    score: 0.5,
                    outputKey: BASChengluPreflightAdapter
                        .outputKey))
        XCTAssertEqual(preflightHead.layerIDPin, .l1)

        let multiHeadIntent = BASChengluMultiHeadAdapter
            .makeWithClosure(
                headID: "mh1", layerIDPin: .l4,
                outputKey: BASChengluMultiHeadAdapter
                    .intentKey,
                inferenceClosure: makeStubClosure(
                    score: 0.5, outputKey: "intent"))
        XCTAssertEqual(multiHeadIntent.layerIDPin, .l4)

        let permitPredict = BASChengluPermitPredictAdapter
            .makeWithClosure(
                headID: "pp", layerIDPin: .l11,
                inferenceClosure: makeStubClosure(
                    score: 0.5,
                    outputKey: BASChengluPermitPredictAdapter
                        .outputKey))
        XCTAssertEqual(permitPredict.layerIDPin, .l11)

        let length = BASChengluLengthHeadAdapter
            .makeWithClosure(
                headID: "len", layerIDPin: .l12,
                inferenceClosure: makeStubClosure(
                    score: 100,
                    outputKey: BASChengluLengthHeadAdapter
                        .outputKey))
        XCTAssertEqual(length.layerIDPin, .l12)

        let latency = BASChengluLatencyHeadAdapter
            .makeWithClosure(
                headID: "lat", layerIDPin: .l1,
                inferenceClosure: makeStubClosure(
                    score: 1000,
                    outputKey: BASChengluLatencyHeadAdapter
                        .outputKey))
        XCTAssertEqual(latency.layerIDPin, .l1)
    }
}
