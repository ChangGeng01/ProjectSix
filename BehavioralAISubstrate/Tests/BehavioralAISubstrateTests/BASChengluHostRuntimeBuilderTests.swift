// MARK: - BASChengluHostRuntimeBuilderTests — chapter 三百二九 / M816
//
// Phase F (附录 X) 第八刀 测试覆盖:crown integration that
// composes chapters 三百二〇-三百二七 into one host-facing builder。
//
// Doctrine pins verified:
//   - Builder produces typed bundle wiring 4 outputs together
//   - Bundle.runtime has mesh registry wired (chapter 三百二三)
//   - Bundle.actors has 6 per-layer actors in priority order
//     (chapter 三百二七)
//   - Bundle.registrationReport reflects partial closure paths
//   - End-to-end: build → runtime.runChengluCanonicalSweep →
//     interpret → typed hints

import XCTest
@testable import BASAppleAdapters
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChengluHostRuntimeBuilderTests: XCTestCase {

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

    private func makeAllClosuresOptions()
        -> BASChengluMeshRegistration.ClosureRegistrationOptions
    {
        BASChengluMeshRegistration.ClosureRegistrationOptions(
            preflightClosure: makeStubClosure(
                scoreMap: ["afm_success_probability": 0.95]),
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
    }

    // MARK: - Bundle defaults

    func testBundlePackages4Outputs() async throws {
        let bundle = try await BASChengluHostRuntimeBuilder
            .build(
                configuration: makeMinimalConfiguration(),
                chengluClosures: makeAllClosuresOptions())
        XCTAssertNotNil(bundle.registry)
        XCTAssertNotNil(bundle.runtime)
        XCTAssertEqual(bundle.actors.count, 6)
        XCTAssertEqual(
            bundle.registrationReport.registeredHeadCount, 8)
    }

    // MARK: - Runtime mesh wiring

    func testBundleRuntimeHasMeshRegistry() async throws {
        let bundle = try await BASChengluHostRuntimeBuilder
            .build(
                configuration: makeMinimalConfiguration(),
                chengluClosures: makeAllClosuresOptions())
        XCTAssertTrue(bundle.runtime.hasMeshRegistry,
            "Bundle's runtime must have meshRegistry wired " +
            "(chapter 三百二三 contract)")
    }

    func testBundleRuntimeUsesProvidedRegistry() async throws {
        let bundle = try await BASChengluHostRuntimeBuilder
            .build(
                configuration: makeMinimalConfiguration(),
                chengluClosures: makeAllClosuresOptions())
        // Runtime's meshRegistry must be the same actor
        // instance as bundle.registry (single-source-of-truth
        // doctrine)。
        //
        // Chapter 三百三七 / M824 fix: previous version only
        // verified count + non-nil — a builder bug that
        // accidentally created two registries with identical
        // contents would have passed。This version uses Swift
        // actor `===` identity to pin same-instance。
        XCTAssertNotNil(bundle.runtime.meshRegistry)
        XCTAssertTrue(
            bundle.registry === bundle.runtime.meshRegistry,
            "Bundle.registry and bundle.runtime.meshRegistry " +
            "MUST be the same actor instance " +
            "(single-source-of-truth doctrine — chapter 二百一一)")
        let totalCount = await bundle.registry.totalHeadCount
        XCTAssertEqual(totalCount, 8)
    }

    // MARK: - Actor priority order

    func testBundleActorsInPriorityOrder() async throws {
        let bundle = try await BASChengluHostRuntimeBuilder
            .build(
                configuration: makeMinimalConfiguration(),
                chengluClosures: makeAllClosuresOptions())
        XCTAssertEqual(
            bundle.actors.map { $0.layerID },
            [.l1, .l4, .l6, .l8, .l11, .l12],
            "Actors must be in priority order matching " +
            "附录 X §X.2 doctrine")
    }

    // MARK: - Partial closures

    func testBundleWithPartialClosuresReportsMissing()
        async throws
    {
        let partial = BASChengluMeshRegistration
            .ClosureRegistrationOptions(
                preflightClosure: makeStubClosure(
                    scoreMap: [
                        "afm_success_probability": 0.95
                    ]))
        let bundle = try await BASChengluHostRuntimeBuilder
            .build(
                configuration: makeMinimalConfiguration(),
                chengluClosures: partial)
        XCTAssertEqual(
            bundle.registrationReport.registeredHeadCount, 1)
        XCTAssertFalse(
            bundle.registrationReport.isComplete)
        XCTAssertEqual(
            Set(bundle.registrationReport.missingMLModels),
            Set([
                "latencyHead", "multiHead",
                "permitPredict", "lengthHead"
            ]))
        XCTAssertEqual(bundle.actors.count, 6,
            "Actors are constructed regardless of how many " +
            "slots got registered (some will see empty " +
            "cascade)")
    }

    // MARK: - End-to-end pipeline

    func testEndToEndBuildAndCanonicalSweep() async throws {
        let bundle = try await BASChengluHostRuntimeBuilder
            .build(
                configuration: makeMinimalConfiguration(),
                chengluClosures: makeAllClosuresOptions())
        let ref = try BASChengluFeatureRefBuilder.build(
            tone: "anxious", domain: "medical",
            stake: "critical", timeframe: "today",
            confidant: "trusted-ai", askShape: "question",
            mutationSeed: 2)
        let input = BASLayerInferenceInput(
            layerID: .l1,
            featureRef: ref,
            confidenceFloor: .high)
        let sweep = try await bundle.runtime
            .runChengluCanonicalSweep(input: input)
        XCTAssertEqual(
            sweep.layerCount, 6,
            "Canonical sweep walks 6 layers")
        XCTAssertEqual(
            sweep.matchedLayerCount, 6,
            "All 6 layers match with high stub scores")

        let hints = BASChengluSweepInterpreter.interpret(sweep)
        XCTAssertNotNil(hints.preflight)
        XCTAssertEqual(hints.preflight?.route, .afm)
        XCTAssertNotNil(hints.length)
        XCTAssertEqual(
            hints.length?.predictedLengthChars ?? 0, 750,
            accuracy: 0.001)
    }

    // MARK: - Custom kill switch lookup propagates

    func testCustomKillSwitchLookupPropagatesToActors()
        async throws
    {
        let killSwitchLookup:
            @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState? = { id in
            // Active for L11 only
            guard id == .l11Risk else { return nil }
            return BASLayerKillSwitchState(
                switchID: id,
                active: true,
                reason: .manual,
                detail: "test-trip")
        }
        let bundle = try await BASChengluHostRuntimeBuilder
            .build(
                configuration: makeMinimalConfiguration(),
                chengluClosures: makeAllClosuresOptions(),
                killSwitchLookup: killSwitchLookup)

        // Find the L11 actor and run process — should
        // short-circuit
        let l11Actor = bundle.actors.first {
            $0.layerID == .l11
        }!
        let input = BASLayerActorInput(
            layerID: .l11,
            turnID: "turn-test",
            payloadRef: "payload-test",
            arrivedAt: Date())
        let output = try await l11Actor.process(input: input)
        XCTAssertEqual(
            output.status, .skippedByKill,
            "Custom kill switch must propagate from builder " +
            "into per-layer actor")
    }

    // MARK: - Empty closures path

    func testBundleWithNoClosures() async throws {
        let empty = BASChengluMeshRegistration
            .ClosureRegistrationOptions()
        let bundle = try await BASChengluHostRuntimeBuilder
            .build(
                configuration: makeMinimalConfiguration(),
                chengluClosures: empty)
        XCTAssertEqual(
            bundle.registrationReport.registeredHeadCount, 0)
        XCTAssertEqual(
            bundle.registrationReport.missingMLModels.count,
            5)
        XCTAssertTrue(bundle.runtime.hasMeshRegistry,
            "Runtime always has registry wired even when " +
            "no slots populated (registry exists, just empty)")
        XCTAssertEqual(bundle.actors.count, 6)
    }
}
