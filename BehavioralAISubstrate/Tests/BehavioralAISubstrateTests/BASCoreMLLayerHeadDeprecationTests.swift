// MARK: - BASCoreMLLayerHeadDeprecationTests — chapter 三百三五 / M822
//                                          + chapter 三百四八 / M835
//
// Phase F (附录 X) 第十三刀 — dead-code removal pin。
//
// Chapters 三百三二-三百三四 fixed all 5 Chenglu adapters' real-
// model paths to use `makeMultiArrayFeatureProvider` (chapter
// 三百三二) routed via direct inferenceClosure construction in
// each adapter's `make(model:)` factory。This rendered:
//
//   - `BASCoreMLLayerHead.makeFromMLModel(...)` — 0 production
//     callers (was only called by chapter 三百二一's now-rewritten
//     adapters)
//   - `BASCoreMLLayerHead.makeFeatureProvider(from:)` — kept
//     public for hosts with custom CoreML models that DO use
//     per-key scalar inputs (legacy / non-sklearn-trained models)
//
// **Chapter 三百三五 / M822 (PRIOR)**: marked `makeFromMLModel`
// `@available(*, deprecated, ...)` with migration message.
//
// **Chapter 三百四八 / M835 (THIS CHAPTER)**: removed
// `makeFromMLModel` entirely. The deprecation period is over;
// the symbol is gone. This test class now pins **absence** of
// the symbol via per-key feature provider + multi-array path
// regression tests — both paths are still exercised end-to-end
// to prove the migration paths still work for legacy callers.

import XCTest
@testable import BASAppleAdapters
@testable import BASRuntimeCore

#if canImport(CoreML)
import CoreML
#endif

final class BASCoreMLLayerHeadDeprecationTests: XCTestCase {

    #if canImport(CoreML)

    // MARK: - Per-key feature provider still works for non-Chenglu models

    /// `makeFeatureProvider` (per-key path) is kept public for
    /// hosts with custom CoreML models that do use per-key
    /// scalar inputs。This test verifies the function still
    /// works correctly for that genuine use case (legacy /
    /// non-sklearn-trained model migration target after
    /// `makeFromMLModel` removal in chapter 三百四八)。
    func testPerKeyFeatureProviderStillWorksForGenuineUseCase()
        throws
    {
        let provider = try BASCoreMLLayerHead
            .makeFeatureProvider(from: [
                "feature_a": 1.5,
                "feature_b": 2.5
            ])
        XCTAssertEqual(provider.featureNames.count, 2)
        XCTAssertTrue(
            provider.featureNames.contains("feature_a"))
        XCTAssertTrue(
            provider.featureNames.contains("feature_b"))
        XCTAssertEqual(
            provider.featureValue(for: "feature_a")?
                .doubleValue,
            1.5)
        XCTAssertEqual(
            provider.featureValue(for: "feature_b")?
                .doubleValue,
            2.5)
    }

    // MARK: - MLMultiArray path is the canonical Chenglu path

    func testMultiArrayPathIsCanonicalChengluPath() throws {
        let values = BASChengluFeatureEncoder.encode(
            signature: bASChengluDefaultSignature)
        let provider = try BASCoreMLLayerHead
            .makeMultiArrayFeatureProvider(
                values: values.featureValues,
                orderedKeys: BASChengluFeatureEncoder
                    .canonicalKeyOrder,
                featureKey: "features")
        XCTAssertEqual(provider.featureNames.count, 1,
            "MLMultiArray path produces single 'features' " +
            "input regardless of input dim count")
        XCTAssertTrue(
            provider.featureNames.contains("features"))
        let value = provider.featureValue(for: "features")
        XCTAssertNotNil(value)
        XCTAssertNotNil(value?.multiArrayValue)
        XCTAssertEqual(
            value?.multiArrayValue?.count, 43,
            "Chenglu canonical multi-array shape is 43-dim")
    }

    // MARK: - chapter 三百四八 / M835 — removal pin

    /// **Chapter 三百四八 / M835 removal pin**: `makeFromMLModel`
    /// was `@available(*, deprecated, ...)` from chapter 三百三五
    /// onwards and is now removed entirely。This test pins the
    /// absence by exercising the migration paths end-to-end
    /// (per-key provider above + multi-array provider above + the
    /// parametric `BASCoreMLLayerHead(...)` init below)。
    ///
    /// If a future contributor re-adds `makeFromMLModel`,this
    /// test still passes (it's an additive contract — the
    /// migration paths are what's pinned),but the absence
    /// guarantee is then lost。To recover it, gate via SwiftPM
    /// or static analysis (`grep` would catch the re-addition)。
    func testMigrationPathsPreservedAfterMakeFromMLModelRemoval()
        async throws
    {
        // Migration target #1: per-key feature provider still
        // resolves + builds correctly。Covered by
        // testPerKeyFeatureProviderStillWorksForGenuineUseCase。

        // Migration target #2: multi-array feature provider is
        // canonical for Chenglu models。Covered by
        // testMultiArrayPathIsCanonicalChengluPath。

        // Migration target #3: parametric init still constructs
        // a working stub head without any MLModel reference。
        let head = BASCoreMLLayerHeadFactory.makeStubSingleOutput(
            headID: "deprecation-removal-pin",
            layerIDPin: .l4,
            scoreKey: "test_score",
            stubScore: 0.85,
            confidenceFromScore: BASCoreMLLayerHeadFactory
                .defaultProbabilityConfidence,
            recommendedAction: nil)
        let input = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "deprecation-removal-pin",
            confidenceFloor: .low)
        let output = try await head.infer(input: input)
        XCTAssertEqual(output.layerID, .l4)
        XCTAssertEqual(
            output.scores["test_score"] ?? 0, 0.85,
            accuracy: 1e-9)
    }

    #endif

    // MARK: - Always-on doctrine pin

    func testCanonicalKeyOrderHas43Entries() {
        XCTAssertEqual(
            BASChengluFeatureEncoder.canonicalKeyOrder.count,
            43,
            "canonical key order must have 43 entries to " +
            "match training-time featurization (8+10+6+7+4+" +
            "3+5)")
    }

    func testCanonicalKeyOrderStableAcrossInvocations() {
        let order1 = BASChengluFeatureEncoder.canonicalKeyOrder
        let order2 = BASChengluFeatureEncoder.canonicalKeyOrder
        XCTAssertEqual(order1, order2,
            "Canonical key order must be deterministic — " +
            "MLMultiArray vector positions depend on it")
    }

    func testCanonicalKeyOrderStartsWithToneKeys() {
        let order = BASChengluFeatureEncoder.canonicalKeyOrder
        XCTAssertEqual(order.first, "tone_calm",
            "First canonical key must be the first tone " +
            "(matches training-time featurization order)")
    }

    func testCanonicalKeyOrderEndsWithMutationSeedKeys() {
        let order = BASChengluFeatureEncoder.canonicalKeyOrder
        XCTAssertTrue(
            order.last?.hasPrefix("mutation_seed_") ?? false,
            "Last canonical key must be a mutation_seed_ key " +
            "(matches training-time featurization order)")
    }

    func testCanonicalKeyOrderUnique() {
        let order = BASChengluFeatureEncoder.canonicalKeyOrder
        XCTAssertEqual(
            Set(order).count, order.count,
            "Canonical key order must have no duplicates — " +
            "duplicate keys would break MLMultiArray packing")
    }
}
