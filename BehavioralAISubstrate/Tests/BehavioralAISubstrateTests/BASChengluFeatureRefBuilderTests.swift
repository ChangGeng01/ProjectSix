// MARK: - BASChengluFeatureRefBuilderTests — chapter 三百二二 / M809
//
// Phase F (附录 X) 第三刀 测试覆盖:typed builder + round-trip
// invariant with `parseBASChengluSignature(...)` (chapter 三百二一)
// + end-to-end cascade integration via `BASLayerCascadeRunner`
// (chapter 三百一二) using all 5 chapter 三百二一 adapters。
//
// This is the FIRST TEST that exercises the full compose chain:
//   featureRef builder → parser → adapter feature extractor →
//   stub inference closure → output transformer →
//   layer cascade runner → typed cascade outcome
//
// Doctrine pins verified:
//   - chapter 二百一一 single-source-of-truth (builder ↔ parser
//     are sole entry/exit for featureRef format)
//   - chapter 一百八十五 anti-magic-number (separator constant)
//   - chapter 三百一二 cascade runner integration
//   - chapter 三百二一 (M808) all 5 adapters compose correctly

import XCTest
@testable import BASAppleAdapters
@testable import BASRuntimeCore

final class BASChengluFeatureRefBuilderTests: XCTestCase {

    // MARK: - Constants pinning

    func testCanonicalFieldCountIs7() {
        XCTAssertEqual(
            BASChengluFeatureRefBuilder.canonicalFieldCount, 7,
            "Canonical format must have exactly 7 fields per " +
            "chapter 三百二一 parser doctrine")
    }

    func testFieldSeparatorIsPipe() {
        XCTAssertEqual(
            BASChengluFeatureRefBuilder.fieldSeparator, "|",
            "Separator must be `|` to match parser at " +
            "chapter 三百二一 line 191")
    }

    // MARK: - containsSeparator predicate

    func testContainsSeparatorPositive() {
        XCTAssertTrue(
            BASChengluFeatureRefBuilder.containsSeparator(
                "has|pipe"))
    }

    func testContainsSeparatorNegative() {
        XCTAssertFalse(
            BASChengluFeatureRefBuilder.containsSeparator(
                "no-pipe-here"))
        XCTAssertFalse(
            BASChengluFeatureRefBuilder.containsSeparator(""))
    }

    // MARK: - Happy path build

    func testBuildFromSignatureCanonicalShape() throws {
        let signature = BASChengluPromptSignature(
            tone: "anxious",
            domain: "medical",
            stake: "critical",
            timeframe: "today",
            confidant: "trusted-ai",
            askShape: "question",
            mutationSeed: 2)
        let ref = try BASChengluFeatureRefBuilder.build(
            from: signature)
        XCTAssertEqual(
            ref,
            "anxious|medical|critical|today|trusted-ai|question|2")
    }

    func testBuildDefaultMutationSeed() throws {
        let signature = bASChengluDefaultSignature
        let ref = try BASChengluFeatureRefBuilder.build(
            from: signature)
        XCTAssertEqual(
            ref,
            "neutral|practical|low|indefinite|trusted-ai|" +
            "question|0")
    }

    func testBuildFromRawFieldsConvenience() throws {
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: "calm",
            domain: "creative",
            stake: "low",
            timeframe: "this-week",
            confidant: "peer",
            askShape: "request",
            mutationSeed: 3)
        XCTAssertEqual(
            ref,
            "calm|creative|low|this-week|peer|request|3")
    }

    // MARK: - Round-trip invariant (chapter 三百二一 parser ↔ this builder)

    func testRoundTripInvariantViaParser() throws {
        let original = BASChengluPromptSignature(
            tone: "grieving",
            domain: "emotional",
            stake: "high",
            timeframe: "this-month",
            confidant: "professional",
            askShape: "statement",
            mutationSeed: 4)
        let ref = try BASChengluFeatureRefBuilder.build(
            from: original)
        let parsed = parseBASChengluSignature(from: ref)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed, original)
    }

    func testRoundTripStableAcrossAllCanonicalCategories()
        throws
    {
        // Sample 1 value from each canonical category set
        // (cross-references chapter 三百二一 BASChengluFeatureEncoder)
        let signature = BASChengluPromptSignature(
            tone: BASChengluFeatureEncoder.tones[0],
            domain: BASChengluFeatureEncoder.domains[0],
            stake: BASChengluFeatureEncoder.stakes[0],
            timeframe: BASChengluFeatureEncoder.timeframes[0],
            confidant: BASChengluFeatureEncoder.confidants[0],
            askShape: BASChengluFeatureEncoder.askShapes[0],
            mutationSeed: 0)
        let ref = try BASChengluFeatureRefBuilder.build(
            from: signature)
        let parsed = parseBASChengluSignature(from: ref)
        XCTAssertEqual(parsed, signature)
    }

    // MARK: - Error path: separator in field

    func testBuildThrowsOnSeparatorInTone() {
        let signature = BASChengluPromptSignature(
            tone: "an|gry",  // contains separator
            domain: "medical",
            stake: "low",
            timeframe: "today",
            confidant: "trusted-ai",
            askShape: "question",
            mutationSeed: 0)
        XCTAssertThrowsError(
            try BASChengluFeatureRefBuilder.build(
                from: signature)
        ) { error in
            guard let typed = error
                as? BASChengluFeatureRefBuilderError
            else {
                XCTFail("Wrong error type: \(error)")
                return
            }
            XCTAssertEqual(
                typed,
                .fieldContainsSeparator(
                    fieldName: "tone", value: "an|gry"))
        }
    }

    func testBuildThrowsOnSeparatorInAnyField() {
        for fieldName in [
            "domain", "stake", "timeframe",
            "confidant", "askShape"
        ] {
            var sig = bASChengluDefaultSignature
            switch fieldName {
            case "domain":
                sig = BASChengluPromptSignature(
                    tone: sig.tone, domain: "bad|val",
                    stake: sig.stake, timeframe: sig.timeframe,
                    confidant: sig.confidant,
                    askShape: sig.askShape,
                    mutationSeed: sig.mutationSeed)
            case "stake":
                sig = BASChengluPromptSignature(
                    tone: sig.tone, domain: sig.domain,
                    stake: "bad|val",
                    timeframe: sig.timeframe,
                    confidant: sig.confidant,
                    askShape: sig.askShape,
                    mutationSeed: sig.mutationSeed)
            case "timeframe":
                sig = BASChengluPromptSignature(
                    tone: sig.tone, domain: sig.domain,
                    stake: sig.stake, timeframe: "bad|val",
                    confidant: sig.confidant,
                    askShape: sig.askShape,
                    mutationSeed: sig.mutationSeed)
            case "confidant":
                sig = BASChengluPromptSignature(
                    tone: sig.tone, domain: sig.domain,
                    stake: sig.stake,
                    timeframe: sig.timeframe,
                    confidant: "bad|val",
                    askShape: sig.askShape,
                    mutationSeed: sig.mutationSeed)
            case "askShape":
                sig = BASChengluPromptSignature(
                    tone: sig.tone, domain: sig.domain,
                    stake: sig.stake,
                    timeframe: sig.timeframe,
                    confidant: sig.confidant,
                    askShape: "bad|val",
                    mutationSeed: sig.mutationSeed)
            default: continue
            }
            XCTAssertThrowsError(
                try BASChengluFeatureRefBuilder.build(
                    from: sig),
                "Builder must throw for separator in " +
                "\(fieldName)")
        }
    }

    // MARK: - buildOrNil non-throwing variant

    func testBuildOrNilSucceedsForValidInput() {
        let ref = BASChengluFeatureRefBuilder.buildOrNil(
            from: bASChengluDefaultSignature)
        XCTAssertNotNil(ref)
    }

    func testBuildOrNilReturnsNilForInvalidInput() {
        let signature = BASChengluPromptSignature(
            tone: "bad|tone", domain: "medical",
            stake: "low", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 0)
        XCTAssertNil(
            BASChengluFeatureRefBuilder.buildOrNil(
                from: signature))
    }

    // MARK: - End-to-end cascade integration (chapters 三百二〇 +
    // 三百二一 + 三百二二)

    private func makeStubClosure(
        scoreMap: [String: Double]
    ) -> @Sendable (BASCoreMLFeatureFrame) async throws
        -> BASCoreMLPredictionFrame
    {
        return { _ in
            BASCoreMLPredictionFrame(
                scores: scoreMap, inferenceLatencyMs: 0.5)
        }
    }

    private func makeAllClosuresOptions()
        -> BASChengluMeshRegistration.ClosureRegistrationOptions
    {
        BASChengluMeshRegistration.ClosureRegistrationOptions(
            preflightClosure: makeStubClosure(
                scoreMap: ["afm_success_probability": 0.95]),
            multiHeadClosure: makeStubClosure(scoreMap: [
                "intent": 0.85,
                "emotion": 0.75,
                "risk": 0.65,
                "memory_importance": 0.80
            ]),
            permitPredictClosure: makeStubClosure(
                scoreMap: ["block_probability": 0.90]),
            lengthHeadClosure: makeStubClosure(
                scoreMap: ["body_length": 850]),
            latencyHeadClosure: makeStubClosure(
                scoreMap: ["duration_ms": 1200]))
    }

    func testEndToEndCascadeFiresPreflightAtL1() async throws {
        // Builder → Parser → Adapter → Cascade
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: "anxious", domain: "medical",
            stake: "critical", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 2)
        let registry = BASLayerMLHeadRegistry()
        _ = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry,
                options: makeAllClosuresOptions())

        let input = BASLayerInferenceInput(
            layerID: .l1,
            featureRef: ref,
            confidenceFloor: .high)
        let result = try await BASLayerCascadeRunner.run(
            input: input,
            registry: registry,
            layerID: .l1)

        // L1 has 2 slots: wake-policy (preflight) +
        // compute-cost-predictor (latency)。Preflight is registered
        // first via assembleFromClosures, so it runs first。
        // Stub returns 0.95 → high confidence → exactly meets
        // floor (.high == .high) → outcome is .floorMet。
        // (.headMatched is reserved for output > floor;
        // .floorMet for output == floor — both are match outcomes)
        XCTAssertTrue(
            result.outcome == .floorMet
            || result.outcome == .headMatched,
            "Expected match outcome, got \(result.outcome)")
        XCTAssertEqual(
            result.matchedHeadID,
            "chenglu.l1.wake-policy")
        // Preflight transformer maps prob > 0.5 → "afm-route"
        XCTAssertEqual(
            result.matchedOutput?.recommendedAction,
            "afm-route")
    }

    func testEndToEndCascadeFiresMultiHeadAtL11() async throws {
        // L11 has 2 slots: risk-scorer (multihead.risk) +
        // safety-action-selector (permit-predict)。
        let ref = try BASChengluFeatureRefBuilder.build(
            from: bASChengluDefaultSignature)
        let registry = BASLayerMLHeadRegistry()
        _ = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry,
                options: makeAllClosuresOptions())

        let input = BASLayerInferenceInput(
            layerID: .l11,
            featureRef: ref,
            confidenceFloor: .high)
        let result = try await BASLayerCascadeRunner.run(
            input: input,
            registry: registry,
            layerID: .l11)

        // multihead.risk = 0.65 → |0.65 - 0.5| = 0.15 → medium
        // confidence (0.10 < 0.15 < 0.20)
        // permit-predict = 0.90 → |0.90 - 0.5| = 0.40 → high
        // Stop at first head meeting floor; multihead.risk is
        // medium (< high floor) so cascade falls through to
        // permit-predict which is high → exactly meets floor
        // (.high == .high) → .floorMet。
        XCTAssertTrue(
            result.outcome == .floorMet
            || result.outcome == .headMatched,
            "Expected match outcome, got \(result.outcome)")
        XCTAssertEqual(
            result.matchedHeadID,
            "chenglu.l11.safety-action-selector")
        XCTAssertEqual(
            result.matchedOutput?.recommendedAction,
            "block")
        XCTAssertEqual(result.triedHeads.count, 2,
            "Cascade must walk 2 L11 slots before matching")
    }

    func testEndToEndCascadeFallthroughWhenAllLowConfidence()
        async throws
    {
        // Stub all heads to return scores producing low confidence
        let ref = try BASChengluFeatureRefBuilder.build(
            from: bASChengluDefaultSignature)
        let registry = BASLayerMLHeadRegistry()
        let lowConfidenceOptions = BASChengluMeshRegistration
            .ClosureRegistrationOptions(
                preflightClosure: makeStubClosure(
                    scoreMap: [
                        "afm_success_probability": 0.55
                    ]),  // |0.55 - 0.5| = 0.05 → low
                multiHeadClosure: makeStubClosure(scoreMap: [
                    "intent": 0.55, "emotion": 0.55,
                    "risk": 0.55, "memory_importance": 0.55
                ]),
                permitPredictClosure: makeStubClosure(
                    scoreMap: ["block_probability": 0.55]),
                lengthHeadClosure: makeStubClosure(
                    scoreMap: ["body_length": 60_000]),
                    // out-of-range → low
                latencyHeadClosure: makeStubClosure(
                    scoreMap: ["duration_ms": 70_000]))
                    // out-of-range → low
        _ = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry,
                options: lowConfidenceOptions)

        let input = BASLayerInferenceInput(
            layerID: .l8,
            featureRef: ref,
            confidenceFloor: .high)
        let result = try await BASLayerCascadeRunner.run(
            input: input,
            registry: registry,
            layerID: .l8)

        // L8 has 1 slot (multihead.memory_importance) → 0.55
        // is low confidence → < high floor → fallthrough
        XCTAssertEqual(result.outcome, .fallenThrough)
        XCTAssertNil(result.matchedHeadID)
        XCTAssertEqual(result.triedHeads.count, 1)
    }

    func testCascadeNoHeadsRegisteredOnUnpopulatedLayer()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        _ = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry,
                options: makeAllClosuresOptions())

        // L2 has no Chenglu slots per附录 X §X.2 doctrine
        let input = BASLayerInferenceInput(
            layerID: .l2,
            featureRef: "any|any|any|any|any|any|0",
            confidenceFloor: .high)
        let result = try await BASLayerCascadeRunner.run(
            input: input,
            registry: registry,
            layerID: .l2)
        XCTAssertEqual(result.outcome, .noHeadsRegistered)
        XCTAssertTrue(result.triedHeads.isEmpty)
    }
}
