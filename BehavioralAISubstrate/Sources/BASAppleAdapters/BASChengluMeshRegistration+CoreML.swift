// MARK: - BASChengluMeshRegistration MLModel half — split from the pure enum
// (charter audit 2026-07-12 T4).

import Foundation
import BASRuntimeCore
import BASAppleLifecycleKit
#if canImport(CoreML)
import CoreML
#endif

#if canImport(CoreML)

public extension BASChengluMeshRegistration {

    /// Bundle of optional `MLModel` references, one per
    /// `.mlpackage`。Caller loads MLModels from app bundle then
    /// passes references here。Missing MLModels (set to nil) are
    /// reported in the registration report's `missingMLModels`。
    /// Chapter 三百四七 / M834 fix: explicit `@unchecked Sendable`
    /// conformance。Real consequence of NOT having this:
    /// `SampleHostChengluStressRunner.loadAndBuildOffActor()`
    /// returns this struct from a `nonisolated static` context
    /// then crosses an `await` boundary into
    /// `BASChengluHostRuntimeBuilder.build(...)`。Under Swift 6
    /// strict concurrency,a non-Sendable struct silently
    /// auto-promotes to `@unchecked` at the cross,masking the
    /// safety story。Mark explicit + document the contract:
    /// MLModel reference itself is read-only post-load, so the struct
    /// can safely CROSS actor boundaries。 NOTE (corrected): Apple's
    /// `MLModel.prediction(from:)` is NOT thread-safe — concurrent
    /// predictions must be serialized by the caller; this struct only
    /// moves the model across the boundary, it does not invoke
    /// concurrent predictions itself。Same
    /// pattern as the private `ChengluModelBox: @unchecked
    /// Sendable` (line 390)。
    struct RegistrationOptions: @unchecked Sendable {
        public let preflightModel: MLModel?
        public let multiHeadModel: MLModel?
        public let permitPredictModel: MLModel?
        public let lengthHeadModel: MLModel?
        public let latencyHeadModel: MLModel?

        public init(
            preflightModel: MLModel? = nil,
            multiHeadModel: MLModel? = nil,
            permitPredictModel: MLModel? = nil,
            lengthHeadModel: MLModel? = nil,
            latencyHeadModel: MLModel? = nil
        ) {
            self.preflightModel = preflightModel
            self.multiHeadModel = multiHeadModel
            self.permitPredictModel = permitPredictModel
            self.lengthHeadModel = lengthHeadModel
            self.latencyHeadModel = latencyHeadModel
        }
    }

    /// Production assembly path bound to real `MLModel` references。
    /// Internally constructs inference closures from each MLModel
    /// then delegates to `assembleFromClosures(...)`。
    static func assemble(
        into registry: BASLayerMLHeadRegistry,
        options: RegistrationOptions
    ) async throws -> BASChengluMeshRegistrationReport {
        let closureOptions = ClosureRegistrationOptions(
            preflightClosure: options.preflightModel.map {
                makeMLModelInferenceClosure(
                    model: $0,
                    description: "ChengluPreflight_v0")
            },
            multiHeadClosure: options.multiHeadModel.map {
                makeMLModelInferenceClosure(
                    model: $0,
                    description: "ChengluMultiHead_v0")
            },
            permitPredictClosure:
                options.permitPredictModel.map {
                    makeMLModelInferenceClosure(
                        model: $0,
                        description: "ChengluPermitPredict_v0")
                },
            lengthHeadClosure: options.lengthHeadModel.map {
                makeMLModelInferenceClosure(
                    model: $0,
                    description: "ChengluLengthHead_v0")
            },
            latencyHeadClosure: options.latencyHeadModel.map {
                makeMLModelInferenceClosure(
                    model: $0,
                    description: "ChengluLatencyHead_v0")
            })
        return try await assembleFromClosures(
            into: registry, options: closureOptions)
    }

    /// Build a Sendable inference closure from a real MLModel。
    /// Wraps model in unchecked-Sendable box (safe inside the
    /// registry actor's isolation domain at infer time)。
    /// Build a Sendable inference closure from a real MLModel。
    /// Uses chapter 三百三二's `makeMultiArrayFeatureProvider`
    /// path with `BASChengluFeatureEncoder.canonicalKeyOrder`
    /// because real shipped Chenglu `.mlpackage` files expect
    /// a single `features: MLMultiArray(shape: [1, 43])` Float32
    /// input — NOT 43 individual scalar feature entries
    /// (chapter 三百三四 fix: prior implementation used the
    /// per-key `makeFeatureProvider` which crashed with
    /// "Feature features is required but not specified" on
    /// every real `.mlpackage`)。
    private static func makeMLModelInferenceClosure(
        model: MLModel,
        description: String
    ) -> @Sendable (BASCoreMLFeatureFrame) async throws
        -> BASCoreMLPredictionFrame
    {
        let modelBox = ChengluModelBox(model: model)
        return { frame in
            let startTime = Date()
            let provider = try BASCoreMLLayerHead
                .makeMultiArrayFeatureProvider(
                    values: frame.featureValues,
                    orderedKeys: BASChengluFeatureEncoder
                        .canonicalKeyOrder,
                    featureKey: "features")
            let result = try modelBox.model.prediction(
                from: provider)
            let scores = BASCoreMLLayerHead.extractScores(
                from: result)
            let elapsed = Date()
                .timeIntervalSince(startTime) * 1000
            return BASCoreMLPredictionFrame(
                scores: scores,
                modelDescription: description,
                inferenceLatencyMs: elapsed)
        }
    }
}

private struct ChengluModelBox: @unchecked Sendable {
    let model: MLModel
}

#endif

