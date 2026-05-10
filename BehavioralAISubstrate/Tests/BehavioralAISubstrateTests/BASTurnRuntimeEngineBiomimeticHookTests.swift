// MARK: - BASTurnRuntimeEngineBiomimeticHookTests
// chapter 四百六十一 / M1222 PROOF tests
//
// Verifies the integration shipped in chapter 461 —
// real wire from BASTurnRuntimeEngineConfiguration
// to BASBiomimeticTurnObserver。 Closes the
// integration debt surfaced by chapter 459 self-audit:
// before this chapter NO CONFIGURATION SLOT existed
// for the substrate-side observer + NO HOOK was
// invoked from runWithPlan。 After chapter 461 both
// exist。
//
// ## Honest test-scope acknowledgment
//
// Full end-to-end "real turn fires observer" via
// `engine.runWithPlan(...)` requires constructing a
// real `BASEBrainRuntimeCoordinator` with all 10
// services (powerClock,hostProfile,context,
// decompose,memory,neuralCore,loop,triSelf,risk,
// action,evolution)。 No test-infra for that exists
// in the BAS test target — every other engine-related
// test (BASTurnRuntimeEngineRunWithPlanTests etc.)
// tests the DELEGATE directly,not the engine。 So
// chapter 461's PROOF tests verify what's testable
// at THIS layer:
//
//   1. Configuration slots exist + default to nil
//      (ADR-014 OPT-IN preserved)
//   2. Configuration immutable updaters thread the
//      slots correctly
//   3. The observer + signal-builder pipeline used
//      by the engine's hook block produces the
//      expected primitive-side state (simulated
//      against the SAME observer + builder closure
//      shape the engine uses)
//
// Full end-to-end coordinator-level test is deferred
// to whenever a test-friendly coordinator factory
// exists (separate infra concern;not chapter 461's
// debt scope)。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASTurnRuntimeEngineBiomimeticHookTests:
    XCTestCase
{

    // MARK: - 1. Default config carries nil observer

    func testDefaultConfigHasNilObserver() {
        let config = BASTurnRuntimeEngineConfiguration
            .default()
        XCTAssertNil(config.biomimeticTurnObserver,
            "ADR-014 OPT-IN:default config must" +
            " carry NO observer so V1 byte-equality" +
            " is preserved out-of-the-box")
        XCTAssertNil(
            config.biomimeticTurnSignalBuilder,
            "default builder must also be nil")
    }

    // MARK: - 2. Configuration immutable updaters

    func testWithBiomimeticTurnObserverUpdater() {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.1,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        let updated = BASTurnRuntimeEngineConfiguration
            .default()
            .with(
                biomimeticTurnObserver: observer)
        XCTAssertNotNil(updated.biomimeticTurnObserver)
        XCTAssertNil(
            updated.biomimeticTurnSignalBuilder,
            "with(biomimeticTurnObserver:) must NOT" +
            " touch the builder slot")
        // Original config unchanged (immutability)
        let original = BASTurnRuntimeEngineConfiguration
            .default()
        XCTAssertNil(original.biomimeticTurnObserver)
    }

    func testWithBiomimeticTurnSignalBuilderUpdater() {
        let builder: @Sendable (BASEBrainTurnResult)
            -> BASBiomimeticTurnSignal = { _ in
            BASBiomimeticTurnSignal()
        }
        let updated = BASTurnRuntimeEngineConfiguration
            .default()
            .with(
                biomimeticTurnSignalBuilder: builder)
        XCTAssertNotNil(
            updated.biomimeticTurnSignalBuilder)
        XCTAssertNil(updated.biomimeticTurnObserver,
            "with(biomimeticTurnSignalBuilder:) must" +
            " NOT touch the observer slot")
    }

    func testUpdatersComposeIndependently() {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.5,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        let builder: @Sendable (BASEBrainTurnResult)
            -> BASBiomimeticTurnSignal = { _ in
            BASBiomimeticTurnSignal(
                predictiveObservation: [1.0])
        }
        let composed = BASTurnRuntimeEngineConfiguration
            .default()
            .with(biomimeticTurnObserver: observer)
            .with(
                biomimeticTurnSignalBuilder: builder)
        XCTAssertNotNil(
            composed.biomimeticTurnObserver)
        XCTAssertNotNil(
            composed.biomimeticTurnSignalBuilder)
    }

    func testOtherUpdatersPreserveBiomimeticSlots() {
        // Wire the biomimetic slots first
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.1,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        let configWithBio =
            BASTurnRuntimeEngineConfiguration
                .default()
                .with(
                    biomimeticTurnObserver: observer)
        // Now use a DIFFERENT updater — biomimetic
        // slots must survive
        let configWithMode = configWithBio.with(
            runtimeMode: .nativeV2)
        XCTAssertNotNil(
            configWithMode.biomimeticTurnObserver,
            "with(runtimeMode:) must thread biomimetic" +
            " slots through unchanged")
        XCTAssertEqual(
            configWithMode.runtimeMode, .nativeV2)
    }

    // MARK: - 3. Observer + builder pipeline

    /// Simulates what the engine's runWithPlan hook
    /// block does:builder produces signal,observer
    /// receives it。 The actual engine code is 7 LOC
    /// + identical to this simulation。 We verify the
    /// PIPELINE without needing a fully-constructed
    /// BASEBrainTurnResult (the builder closure's
    /// argument is opaque to the observer pipeline)。
    func testObserverFiresWithBuilderProducedSignal()
        async throws
    {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 1.0,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        // The signal-builder transform from chapter
        // 461 — its argument type is BASEBrainTurnResult
        // but the observer pipeline only consumes the
        // OUTPUT signal,which we construct directly。
        let signal = BASBiomimeticTurnSignal(
            predictiveObservation: [0.7])
        // Engine hook block (verbatim):
        //   if let observer = biomimeticTurnObserver {
        //       let signal = builder?(result)
        //                    ?? BASBiomimeticTurnSignal()
        //       _ = try? await observer.observe(signal)
        //   }
        _ = try? await observer.observe(signal)
        let prediction = await probe
            .currentPredictionSnapshot()
        XCTAssertEqual(prediction[0], 0.7,
            accuracy: 1e-6,
            "α=1 + builder-produced obs=0.7 → μ snaps" +
            " to 0.7;proves the builder→observer→" +
            "primitive pipeline drives state")
        let count = await observer.turnsObservedCount()
        XCTAssertEqual(count, 1,
            "observer turn-count increments per fire")
    }

    func testObserverFiresWithEmptySignalWhenNoBuilder()
        async throws
    {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 1.0,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        // Simulate engine hook with builder = nil →
        // empty signal default
        let signal = BASBiomimeticTurnSignal()  // empty
        _ = try? await observer.observe(signal)
        let prediction = await probe
            .currentPredictionSnapshot()
        XCTAssertEqual(prediction[0], 0,
            accuracy: 1e-9,
            "empty signal → probe not driven →" +
            " prediction stays at initial")
        let count = await observer.turnsObservedCount()
        XCTAssertEqual(count, 1,
            "turn counter still increments (turn-" +
            "counter-only audit mode)")
    }

    // MARK: - 4. Configuration carries through hook

    /// Compile-time + structure check:the new init
    /// signature accepts both new params + propagates
    /// to the engine。 Doesn't exercise runWithPlan
    /// (full coordinator construction is out-of-scope
    /// for chapter 461 — see test-scope acknowledgment
    /// at top of file)。
    func testEngineConfigurationRoundtrip() {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.1,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        let builder: @Sendable (BASEBrainTurnResult)
            -> BASBiomimeticTurnSignal = { _ in
            BASBiomimeticTurnSignal(
                predictiveObservation: [0.5])
        }
        let config = BASTurnRuntimeEngineConfiguration(
            biomimeticTurnObserver: observer,
            biomimeticTurnSignalBuilder: builder)
        XCTAssertNotNil(config.biomimeticTurnObserver)
        XCTAssertNotNil(
            config.biomimeticTurnSignalBuilder)
        // Round-trip through with(...) updater chain
        let roundtrip = config
            .with(
                biomimeticTurnObserver:
                    config.biomimeticTurnObserver)
            .with(
                biomimeticTurnSignalBuilder:
                    config.biomimeticTurnSignalBuilder)
        XCTAssertNotNil(
            roundtrip.biomimeticTurnObserver)
        XCTAssertNotNil(
            roundtrip.biomimeticTurnSignalBuilder)
    }

}
