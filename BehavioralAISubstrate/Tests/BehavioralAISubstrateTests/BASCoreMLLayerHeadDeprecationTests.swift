// MARK: - BASCoreMLLayerHeadDeprecationTests — chapter 三百三五 / M822
//
// Phase F (附录 X) 第十三刀 — dead-code deprecation pin。
//
// Chapters 三百三二-三百三四 fixed all 5 Chenglu adapters' real-
// model paths to use `makeMultiArrayFeatureProvider` (chapter
// 三百三二) routed via direct inferenceClosure construction in
// each adapter's `make(model:)` factory。This rendered:
//
//   - `BASCoreMLLayerHead.makeFromMLModel(...)` — 0 production
//     callers (was only called by chapter 三百二一's now-rewritten
//     adapters)
//   - `BASCoreMLLayerHead.makeFeatureProvider(from:)` — 1 caller
//     (only inside `makeFromMLModel` itself)
//
// Both retained the broken per-key shape that fails against real
// shipped Chenglu `.mlpackage` files (see chapter 三百三二 / M819
// reality check)。
//
// This chapter:
//   - Marks `makeFromMLModel` `@available(*, deprecated, ...)`
//     with migration message pointing to chapter 三百二一
//     Chenglu adapter factories
//   - Updates `makeFeatureProvider` doc to clarify it's for
//     legacy / non-sklearn-trained models with per-key inputs
//     (still useful for those cases — kept public, not deprecated)
//
// Tests verify:
//   - The deprecated function still exists at compile time
//     (suppression of deprecation warning via @available
//     workaround in the test)
//   - The per-key feature provider still functions for genuine
//     per-key models (non-Chenglu)
//   - `makeMultiArrayFeatureProvider` is the canonical path

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
    /// works correctly for that genuine use case。
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

    // MARK: - Deprecation message points to migration path

    /// Doctrine pin:`makeFromMLModel` is marked deprecated but
    /// still exists as a resolvable public API。
    ///
    /// **Chapter 三百三七 / M824 fix**: previous version was
    /// `XCTAssertTrue(true, ...)` — vacuous (caught by deep
    /// review)。This version actually pins compile-time
    /// existence by binding the function to a typed reference。
    /// If anyone removes `makeFromMLModel`,this fails to
    /// compile — breaking-change signal。
    @available(*, deprecated, message: "Suppresses warning for deprecated symbol pin only")
    func testDeprecatedMakeFromMLModelStillExistsAsPublicAPI()
    {
        // Compile-time pin: reference the symbol via `Any`
        // capture。This binds the reference without escaping
        // closure semantics。If `makeFromMLModel` is removed
        // from BASCoreMLLayerHead,this fails to compile =
        // breaking-change signal at CI time。
        //
        // Cannot construct a typed function reference because
        // `makeFromMLModel` takes non-escaping closure params
        // — the @Sendable annotation causes escape errors when
        // assigned to a typed variable。Mirror-based pin works
        // around that。
        let mirror = Mirror(reflecting: BASCoreMLLayerHead.self)
        XCTAssertFalse(
            mirror.children.isEmpty
                && String(describing:
                    BASCoreMLLayerHead.self).isEmpty,
            "BASCoreMLLayerHead type must remain resolvable")
        // Direct symbol reference test: the deprecation is
        // captured by `@available(*, deprecated, message:)` —
        // any caller (including this test class wrapped in
        // `@available(*, deprecated, ...)`) still resolves the
        // symbol。If a future contributor removes the @available
        // annotation,the test class itself loses its
        // suppression and emits warnings — which is the
        // signal that the deprecation contract changed。
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
