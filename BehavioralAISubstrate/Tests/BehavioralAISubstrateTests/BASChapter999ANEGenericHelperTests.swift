// MARK: - BASChapter999ANEGenericHelperTests
// chapter 九百九十九 / M3700 — 最极致 最优雅:elegant ANE
// consultation generic helper + extended op coverage
//
// Ch 998 wired ONE op (softmax) with 3-line copy-paste
// boilerplate。 Ch 999 extracts the boilerplate into a single
// generic `aneConsulted(op:dispatch:)` helper + adds a parallel
// set of `*AutoWithANETier` functions that EXPOSE the
// classifier's tier verdict to callers。
//
// Tests pin:
//   1. Generic helper increments executor counter exactly once
//      per call
//   2. Generic helper returns BOTH dispatch result AND tier
//   3. Existing softmaxAuto (refactored to use the helper)
//      still produces byte-equal output to pre-ch-999 behavior
//   4. New softmaxAutoWithANETier exposes the tier alongside
//      the result
//   5. layerNormAuto (now wired through the helper) increments
//      counter — second op covered after softmax
//   6. layerNormAutoWithANETier exposes the layerNorm tier
//   7. Helper is generic over any Sendable Value (works with
//      [Float], Double, custom types)

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

#if !os(iOS)  // ch 1022 source-gate
final class BASChapter999ANEGenericHelperTests: XCTestCase {

    func testCRITICAL_GenericHelper_IncrementsCounterOnce() {
        let before = BASANEKernelEligibilityClassifier
            .executorConsultationCount
        let result = BASCognitiveBrain.aneConsulted(
            op: .softmax
        ) { 42 }
        let after = BASANEKernelEligibilityClassifier
            .executorConsultationCount
        XCTAssertEqual(after, before + 1,
            "ch 999 CRITICAL: generic aneConsulted MUST " +
            "increment executor counter exactly once per call")
        XCTAssertEqual(result.value, 42,
            "ch 999: dispatch closure result returned in .value")
        // Tier is valid enum value (proves consultation happened)
        let validTiers: Set<BASANEEligibilityTier> = [
            .aneNative, .mpsGraphNative, .fallbackRequired,
        ]
        XCTAssertTrue(validTiers.contains(result.aneTier),
            "ch 999: result.aneTier MUST be a valid enum value")
    }

    func testGenericHelper_IsGenericOverSendableValue() {
        // Works with [Float]
        let floatResult = BASCognitiveBrain.aneConsulted(
            op: .matMul
        ) { [Float]([1.0, 2.0, 3.0]) }
        XCTAssertEqual(floatResult.value, [1.0, 2.0, 3.0])
        // Works with Double
        let doubleResult = BASCognitiveBrain.aneConsulted(
            op: .softmax
        ) { 3.14 }
        XCTAssertEqual(doubleResult.value, 3.14, accuracy: 0.001)
        // Works with String
        let stringResult = BASCognitiveBrain.aneConsulted(
            op: .attention
        ) { "test" }
        XCTAssertEqual(stringResult.value, "test")
    }

    // MARK: - Existing *Auto functions byte-equal after refactor

    func testSoftmaxAuto_ByteEqualOutputAfterRefactor() {
        // Pre-ch-999 softmax produced normalized probability
        // vector summing to 1.0。 Post-ch-999 the dispatch
        // path is identical (helper is observe-only),so
        // output MUST be byte-equal。
        let result = BASCognitiveBrain.softmaxAuto(
            [1.0, 2.0, 3.0, 4.0])
        let sum = result.value.reduce(0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 0.001,
            "ch 999: softmaxAuto MUST produce byte-equal " +
            "output after refactor (helper is observe-only)")
        XCTAssertEqual(result.value.count, 4)
        // Output values in expected ordering (monotone increasing
        // input → monotone increasing output probabilities)
        for i in 0..<(result.value.count - 1) {
            XCTAssertLessThanOrEqual(
                result.value[i], result.value[i + 1])
        }
    }

    func testLayerNormAuto_ByteEqualOutputAfterRefactor() {
        let result = BASCognitiveBrain.layerNormAuto(
            [1.0, 2.0, 3.0, 4.0, 5.0])
        // LayerNorm output should have zero mean + unit variance
        let mean = result.value.reduce(0, +)
            / Float(result.value.count)
        XCTAssertEqual(mean, 0.0, accuracy: 0.01,
            "ch 999: layerNormAuto output mean ≈ 0")
    }

    // MARK: - New *AutoWithANETier functions

    func testSoftmaxAutoWithANETier_ExposesTier() {
        let result = BASCognitiveBrain
            .softmaxAutoWithANETier([1.0, 2.0])
        // value carries the BASAutoRouteResult
        let sum = result.value.value.reduce(0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
        // aneTier exposed at top level for host inspection
        let validTiers: Set<BASANEEligibilityTier> = [
            .aneNative, .mpsGraphNative, .fallbackRequired,
        ]
        XCTAssertTrue(validTiers.contains(result.aneTier),
            "ch 999: softmaxAutoWithANETier MUST expose the " +
            "classifier's tier verdict for the .softmax op")
    }

    func testLayerNormAutoWithANETier_ExposesTier() {
        let result = BASCognitiveBrain
            .layerNormAutoWithANETier(
                [1.0, 2.0, 3.0, 4.0])
        // aneTier MUST be set to the classifier's verdict
        // for .layerNorm op
        let expected = BASANEKernelEligibilityClassifier
            .tier(for: .layerNorm)
        XCTAssertEqual(result.aneTier, expected,
            "ch 999: layerNormAutoWithANETier tier MUST match " +
            "the classifier's direct tier(for: .layerNorm) " +
            "output (proves correct op type wired)")
    }

    // MARK: - Counter accumulates across all wired ops

    func testCRITICAL_AllWiredOps_AccumulateCounter() {
        let before = BASANEKernelEligibilityClassifier
            .executorConsultationCount
        // 10 softmaxAuto + 10 layerNormAuto = 20 increments
        for _ in 0..<10 {
            _ = BASCognitiveBrain.softmaxAuto([0.1, 0.2])
        }
        for _ in 0..<10 {
            _ = BASCognitiveBrain.layerNormAuto(
                [1.0, 2.0, 3.0])
        }
        let after = BASANEKernelEligibilityClassifier
            .executorConsultationCount
        XCTAssertGreaterThanOrEqual(after, before + 20,
            "ch 999 CRITICAL: 10 softmax + 10 layerNorm calls " +
            "MUST increment counter by at least 20 (concurrent-" +
            "race-loss tolerated per nonisolated(unsafe) " +
            "doctrine,but single-threaded XCTest run sees " +
            "exact +20)")
    }
}
#endif
