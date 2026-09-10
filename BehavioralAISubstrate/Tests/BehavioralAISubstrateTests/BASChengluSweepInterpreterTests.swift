// MARK: - BASChengluSweepInterpreterTests — chapter 三百二六 / M813
//
// Phase F (附录 X) 第六刀 测试覆盖:typed sweep interpreter +
// 5 hint family value types + canonical head ID constants。
//
// Doctrine pins verified:
//   - Canonical head IDs match chapter 三百二一 §X.2 doctrine
//     (anti-drift)
//   - All 5 hint families decoded correctly from matched cascade
//     output
//   - Empty / partial sweeps yield correct partial hint sets
//   - Hint set isComplete only when all 8 slots populated
//   - Confidence carryover from BASLayerInferenceConfidence

import XCTest
@testable import BASAppleAdapters
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChengluSweepInterpreterTests: XCTestCase {

    // MARK: - Helpers

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

    private func makeMinimalConfiguration()
        -> BASHostConfiguration
    {
        BASHostConfiguration.fixtureGeneric
    }

    private func makeFullSweepRuntime() async throws
        -> BASHostRuntime
    {
        let registry = BASLayerMLHeadRegistry()
        let options = BASChengluMeshRegistration
            .ClosureRegistrationOptions(
                preflightClosure: makeStubClosure(
                    scoreMap: [
                        "afm_success_probability": 0.95
                    ]),
                multiHeadClosure: makeStubClosure(scoreMap: [
                    "intent": 0.85,
                    "emotion": 0.95,
                    "risk": 0.82,
                    "memory_importance": 0.92
                ]),
                permitPredictClosure: makeStubClosure(
                    scoreMap: ["block_probability": 0.90]),
                lengthHeadClosure: makeStubClosure(
                    scoreMap: ["body_length": 750]),
                latencyHeadClosure: makeStubClosure(
                    scoreMap: ["duration_ms": 1500]))
        _ = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry, options: options)
        return BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
    }

    private func makeInput(
        layerID: BASMotherboardLayer14 = .l1
    ) throws -> BASLayerInferenceInput {
        let ref = try BASChengluFeatureRefBuilder.build(
            from: bASChengluDefaultSignature)
        return BASLayerInferenceInput(
            layerID: layerID,
            featureRef: ref,
            confidenceFloor: .high)
    }

    // MARK: - Canonical head IDs (anti-drift pin)

    func testCanonicalHeadIDsMatchAppendixXDoctrine() {
        // 附录 X §X.2 — 8 slots
        XCTAssertEqual(
            BASChengluCanonicalHeadIDs.l1WakePolicy,
            "chenglu.l1.wake-policy")
        XCTAssertEqual(
            BASChengluCanonicalHeadIDs.l1ComputeCostPredictor,
            "chenglu.l1.compute-cost-predictor")
        XCTAssertEqual(
            BASChengluCanonicalHeadIDs.l4QuestionType,
            "chenglu.l4.question-type")
        XCTAssertEqual(
            BASChengluCanonicalHeadIDs.l6EmotionClassifier,
            "chenglu.l6.emotion-classifier")
        XCTAssertEqual(
            BASChengluCanonicalHeadIDs.l8ImportanceScorer,
            "chenglu.l8.importance-scorer")
        XCTAssertEqual(
            BASChengluCanonicalHeadIDs.l11RiskScorer,
            "chenglu.l11.risk-scorer")
        XCTAssertEqual(
            BASChengluCanonicalHeadIDs
                .l11SafetyActionSelector,
            "chenglu.l11.safety-action-selector")
        XCTAssertEqual(
            BASChengluCanonicalHeadIDs.l12DensityController,
            "chenglu.l12.density-controller")
    }

    func testCanonicalHeadIDsAllListHas8Entries() {
        XCTAssertEqual(
            BASChengluCanonicalHeadIDs.all.count, 8,
            "Must match附录 X §X.2 8-slot doctrine")
        // No duplicates
        XCTAssertEqual(
            Set(BASChengluCanonicalHeadIDs.all).count, 8)
    }

    // MARK: - Hint confidence carryover

    func testHintConfidenceCarryoverFromInferenceConfidence() {
        XCTAssertEqual(
            BASChengluHintConfidence.from(.high), .high)
        XCTAssertEqual(
            BASChengluHintConfidence.from(.medium), .medium)
        XCTAssertEqual(
            BASChengluHintConfidence.from(.low), .low)
        XCTAssertEqual(
            BASChengluHintConfidence.from(.unknown), .unknown)
    }

    // MARK: - Hint set defaults + invariants

    func testEmptyHintSetHasZeroPopulated() {
        let empty = BASChengluHintSet.empty
        XCTAssertEqual(empty.populatedCount, 0)
        XCTAssertFalse(empty.isComplete)
        XCTAssertNil(empty.preflight)
        XCTAssertNil(empty.length)
        XCTAssertNil(empty.latency)
        XCTAssertNil(empty.intent)
        XCTAssertNil(empty.emotion)
        XCTAssertNil(empty.risk)
        XCTAssertNil(empty.memoryImportance)
        XCTAssertNil(empty.permitPredict)
    }

    func testHintSetIsCompleteOnlyAt8Populated() {
        let partial = BASChengluHintSet(
            preflight: BASChengluPreflightHint(
                route: .afm, probability: 0.9,
                confidence: .high),
            permitPredict: BASChengluPermitPredictHint(
                policy: .block, blockProbability: 0.9,
                confidence: .high))
        XCTAssertEqual(partial.populatedCount, 2)
        XCTAssertFalse(partial.isComplete)
    }

    // MARK: - Empty sweep → empty hint set

    func testInterpretEmptySweepReturnsEmptyHintSet() {
        let empty = BASHostMeshSweepResult(
            layerEntries: [], aggregatedReasonCodes: [])
        let hints = BASChengluSweepInterpreter.interpret(
            empty)
        XCTAssertEqual(hints, .empty)
        XCTAssertEqual(hints.populatedCount, 0)
    }

    // MARK: - Full canonical sweep

    func testFullCanonicalSweepProducesAllHints() async throws {
        let runtime = try await makeFullSweepRuntime()
        let sweep = try await runtime
            .runChengluCanonicalSweep(
                input: try makeInput())
        let hints = BASChengluSweepInterpreter.interpret(sweep)

        // All 6 layers consulted, each has 1 matched head per
        // priority order. 6 layers × matched head → 8 slot
        // populations expected? No — wait — 6 layers but 8 slots
        // because L1 has 2 slots and L11 has 2 slots. Cascade
        // matches FIRST head per layer with sufficient confidence,
        // so L1 only contributes 1 hint (preflight wins),
        // L11 only contributes 1 hint (whichever cascades first).
        // Per chapter 三百二一 assembly order: preflight → latency
        // → multihead intent → multihead emotion → multihead
        // memory_importance → multihead risk → permit-predict →
        // length. Cascade walks layer slots in priority order
        // (all priority 10 → insertion order).

        // L1: preflight wins (registered first), so preflight
        // hint populated, latency hint NOT (cascade stops at
        // first match)
        XCTAssertNotNil(hints.preflight)
        XCTAssertNil(
            hints.latency,
            "L1 cascade matches preflight first; latency " +
            "compute-cost-predictor only fires when preflight " +
            "doesn't meet floor")

        // L4 single-slot: intent
        XCTAssertNotNil(hints.intent)

        // L6 single-slot: emotion
        XCTAssertNotNil(hints.emotion)

        // L8 single-slot: memory_importance
        XCTAssertNotNil(hints.memoryImportance)

        // L11: risk-scorer registered first via multiHead
        // closure path. With high stub scores risk-scorer wins.
        XCTAssertNotNil(hints.risk)
        XCTAssertNil(
            hints.permitPredict,
            "L11 cascade matches risk-scorer first (high " +
            "stub); permit-predict only fires when risk falls " +
            "below floor")

        // L12 single-slot: length
        XCTAssertNotNil(hints.length)

        // 6 layers each contribute 1 matched head =
        // 6 hint populations
        XCTAssertEqual(hints.populatedCount, 6)
    }

    // MARK: - Preflight decoding

    func testPreflightHintDecodesAfmRouteOnHighProbability()
        async throws
    {
        let runtime = try await makeFullSweepRuntime()
        let sweep = try await runtime
            .runChengluCanonicalSweep(
                input: try makeInput())
        let hints = BASChengluSweepInterpreter.interpret(sweep)
        let preflight = hints.preflight
        XCTAssertNotNil(preflight)
        XCTAssertEqual(preflight?.route, .afm)
        XCTAssertEqual(
            preflight?.probability ?? 0, 0.95,
            accuracy: 0.001)
        XCTAssertEqual(preflight?.confidence, .high)
    }

    // MARK: - Length hint decoding

    func testLengthHintDecodesBodyLength() async throws {
        let runtime = try await makeFullSweepRuntime()
        let sweep = try await runtime
            .runChengluCanonicalSweep(
                input: try makeInput())
        let hints = BASChengluSweepInterpreter.interpret(sweep)
        XCTAssertEqual(
            hints.length?.predictedLengthChars ?? 0, 750,
            accuracy: 0.001)
        XCTAssertEqual(hints.length?.confidence, .high)
    }

    // MARK: - Multi-head decoding

    func testIntentHintDecodesScore() async throws {
        let runtime = try await makeFullSweepRuntime()
        let sweep = try await runtime
            .runChengluCanonicalSweep(
                input: try makeInput())
        let hints = BASChengluSweepInterpreter.interpret(sweep)
        XCTAssertEqual(hints.intent?.outputKey, "intent")
        XCTAssertEqual(
            hints.intent?.score ?? 0, 0.85, accuracy: 0.001)
    }

    func testEmotionHintDecodesScore() async throws {
        let runtime = try await makeFullSweepRuntime()
        let sweep = try await runtime
            .runChengluCanonicalSweep(
                input: try makeInput())
        let hints = BASChengluSweepInterpreter.interpret(sweep)
        XCTAssertEqual(hints.emotion?.outputKey, "emotion")
        XCTAssertEqual(
            hints.emotion?.score ?? 0, 0.95, accuracy: 0.001)
    }

    func testMemoryImportanceHintDecodesScore() async throws {
        let runtime = try await makeFullSweepRuntime()
        let sweep = try await runtime
            .runChengluCanonicalSweep(
                input: try makeInput())
        let hints = BASChengluSweepInterpreter.interpret(sweep)
        XCTAssertEqual(
            hints.memoryImportance?.outputKey,
            "memory_importance")
        XCTAssertEqual(
            hints.memoryImportance?.score ?? 0, 0.92,
            accuracy: 0.001)
    }

    func testRiskHintDecodesScore() async throws {
        let runtime = try await makeFullSweepRuntime()
        let sweep = try await runtime
            .runChengluCanonicalSweep(
                input: try makeInput())
        let hints = BASChengluSweepInterpreter.interpret(sweep)
        XCTAssertEqual(hints.risk?.outputKey, "risk")
        XCTAssertEqual(
            hints.risk?.score ?? 0, 0.82, accuracy: 0.001)
    }

    // MARK: - L11 cascade with low risk → permit-predict wins

    func testL11PermitPredictHintWhenRiskFallsThrough()
        async throws
    {
        // Stub multihead.risk = 0.55 → low confidence → fall
        // through to permit-predict (high confidence)
        let registry = BASLayerMLHeadRegistry()
        let options = BASChengluMeshRegistration
            .ClosureRegistrationOptions(
                preflightClosure: makeStubClosure(
                    scoreMap: [
                        "afm_success_probability": 0.95
                    ]),
                multiHeadClosure: makeStubClosure(scoreMap: [
                    "intent": 0.95, "emotion": 0.95,
                    "risk": 0.55,  // low confidence
                    "memory_importance": 0.95
                ]),
                permitPredictClosure: makeStubClosure(
                    scoreMap: ["block_probability": 0.92]),
                lengthHeadClosure: makeStubClosure(
                    scoreMap: ["body_length": 500]),
                latencyHeadClosure: makeStubClosure(
                    scoreMap: ["duration_ms": 1000]))
        _ = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry, options: options)
        let runtime = BASHostRuntime(
            configuration: makeMinimalConfiguration(),
            meshRegistry: registry)
        let sweep = try await runtime
            .runChengluCanonicalSweep(
                input: try makeInput())
        let hints = BASChengluSweepInterpreter.interpret(sweep)
        // Risk falls through (low) → permit-predict wins
        XCTAssertNil(hints.risk,
            "Risk hint must be nil when risk-scorer fell " +
            "through")
        XCTAssertNotNil(hints.permitPredict,
            "Permit-predict hint must be populated when " +
            "risk-scorer fell through")
        XCTAssertEqual(
            hints.permitPredict?.policy, .block)
        XCTAssertEqual(
            hints.permitPredict?.blockProbability ?? 0, 0.92,
            accuracy: 0.001)
    }

    // MARK: - Unknown head ID → no hint

    func testUnknownHeadIDProducesNoHint() {
        // Construct synthetic sweep with non-canonical head ID
        let cascade = BASLayerCascadeResult(
            outcome: .headMatched,
            layerID: .l4,
            matchedHeadID: "host.custom-head",
            matchedOutput: BASLayerInferenceOutput(
                layerID: .l4,
                scores: ["intent": 0.99],
                confidence: .high))
        let entry = BASHostMeshSweepLayerEntry(
            layerID: .l4,
            consultation: BASHostMeshConsultationResult(
                cascadeResult: cascade,
                reasonCodes: []))
        let result = BASHostMeshSweepResult(
            layerEntries: [entry],
            aggregatedReasonCodes: [])
        let hints = BASChengluSweepInterpreter.interpret(result)
        XCTAssertEqual(hints.populatedCount, 0,
            "Custom head ID not in canonical map → no hint " +
            "derived")
    }
}
