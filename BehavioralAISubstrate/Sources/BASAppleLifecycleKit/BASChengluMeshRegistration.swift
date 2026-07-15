// charter audit 2026-07-12 T4: the pure closure-based registration enum moved to
// BASAppleLifecycleKit; the MLModel-bound RegistrationOptions/assemble stay in
// BASAppleAdapters (BASChengluMeshRegistration+CoreML.swift).
// MARK: - BASChengluMeshRegistration — chapter 三百二一 / M808
//
// Phase F (附录 X) 第二刀 cont.:assembly helper that registers
// the 5 Chenglu adapters into a `BASLayerMLHeadRegistry` at 8
// canonical slots per附录 X §X.2 doctrine mapping。
//
// One-line host adoption pattern:
//
//     let report = try await BASChengluMeshRegistration.assemble(
//         into: registry,
//         options: BASChengluMeshRegistration.RegistrationOptions(
//             preflightModel: preflightMLModel,
//             multiHeadModel: multiHeadMLModel,
//             permitPredictModel: permitPredictMLModel,
//             lengthHeadModel: lengthHeadMLModel,
//             latencyHeadModel: latencyHeadMLModel))
//     // report.registeredHeadCount == 8 (when all 5 models present)
//     // report.missingMLModels reports any unset .nil refs
//
// ## Slot mapping (附录 X §X.2 doctrine)
//
//   - L1.wake-policy ← ChengluPreflight (router → wake decision)
//   - L1.compute-cost-predictor ← ChengluLatencyHead (duration)
//   - L4.question-type ← ChengluMultiHead.intent
//   - L6.emotion-classifier ← ChengluMultiHead.emotion
//   - L8.importance-scorer ← ChengluMultiHead.memory_importance
//   - L11.risk-scorer ← ChengluMultiHead.risk
//   - L11.safety-action-selector ← ChengluPermitPredict
//   - L12.density-controller ← ChengluLengthHead
//
// **8 canonical slots** filled with real CoreML heads (out of 41
// total = 19.5% coverage)。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — all heads hint-class
//   - 红线 7 watcher hint only
//   - 单提交口 (L11/L14) 不变 — registration is config plane
//   - chapter 二百一一 single-source-of-truth: ONE assembly
//     entry point for canonical Chenglu mesh registration
//   - chapter 一百八十一 multi-head shared encoder doctrine: 4
//     outputs from one MLModel = 4 distinct registry slots
//   - chapter 一百七十七 vision § "14 层 × CoreML head mapping":
//     typed encoding of recommended slot doctrine
//   - chapter 三百一七 (M804) BAS14LayerMeshAssembler precedent:
//     idempotence + reason-code emission patterns

import Foundation
import BASRuntimeCore

// MARK: - Registration namespace
//
// `BASChengluMeshRegistrationReport` value type lives in
// BASRuntimeCore/BASCoreMLFrames.swift (cross-platform) so the
// governance registry can reference it without importing this
// Apple-platform-only target。

/// Namespace for canonical Chenglu mesh registration helpers。
public enum BASChengluMeshRegistration {

    // MARK: - Doctrine constants

    /// Canonical headID prefix for Chenglu adapters。
    public static let headIDPrefix = "chenglu"

    /// Build a canonical headID per附录 X §X.2 doctrine。
    public static func canonicalHeadID(
        layer: BASMotherboardLayer14,
        role: String
    ) -> String {
        "\(headIDPrefix).\(layer.rawValue).\(role)"
    }

    // MARK: - Registration options (Sendable)

    /// Bundle of optional Sendable inference closures, one per
    /// .mlpackage。Closure-based variant lets tests register
    /// stub closures without `MLModel` references。
    public struct ClosureRegistrationOptions: Sendable {
        public typealias InferenceClosure =
            @Sendable (BASCoreMLFeatureFrame) async throws
                -> BASCoreMLPredictionFrame

        public let preflightClosure: InferenceClosure?
        public let multiHeadClosure: InferenceClosure?
        public let permitPredictClosure: InferenceClosure?
        public let lengthHeadClosure: InferenceClosure?
        public let latencyHeadClosure: InferenceClosure?

        public init(
            preflightClosure: InferenceClosure? = nil,
            multiHeadClosure: InferenceClosure? = nil,
            permitPredictClosure: InferenceClosure? = nil,
            lengthHeadClosure: InferenceClosure? = nil,
            latencyHeadClosure: InferenceClosure? = nil
        ) {
            self.preflightClosure = preflightClosure
            self.multiHeadClosure = multiHeadClosure
            self.permitPredictClosure = permitPredictClosure
            self.lengthHeadClosure = lengthHeadClosure
            self.latencyHeadClosure = latencyHeadClosure
        }
    }

    // MARK: - Closure-based assembly (testable, no MLModel)

    /// Register Chenglu heads from inference closures into the
    /// canonical mesh slots per附录 X §X.2 doctrine。Tests use
    /// this variant with stub closures。Production callers use
    /// the `assemble(into:options:)` variant that takes MLModel
    /// references (Apple-platform-only, below)。
    ///
    /// - Throws: `BASLayerMLHeadRegistrationError.duplicateHeadID`
    ///   if the registry already has a head with the same ID.
    public static func assembleFromClosures(
        into registry: BASLayerMLHeadRegistry,
        options: ClosureRegistrationOptions
    ) async throws -> BASChengluMeshRegistrationReport {
        // Chapter 三百四八 / M835: tally + register ritual now
        // routes through `BASLayerMLHeadRegistrar` to share with
        // `BAS14LayerMeshAssembler` (eliminates pattern drift
        // per MEDIUM #8 backlog item)。`missing` stays local
        // because it tracks which optional closures the caller
        // omitted — independent of registrar tally state。
        var registrar = BASLayerMLHeadRegistrar()
        var missing: [String] = []
        let priority = BAS14LayerMeshMap
            .coremlOnDeviceTierPriority

        // L1.wake-policy ← Preflight
        if let preflight = options.preflightClosure {
            let head = BASChengluPreflightAdapter.make(
                headID: canonicalHeadID(
                    layer: .l1, role: "wake-policy"),
                layerIDPin: .l1,
                inferenceClosure: preflight)
            try await registrar.register(
                head: head, into: registry,
                layerID: .l1, priority: priority)
        } else {
            missing.append("preflight")
        }

        // L1.compute-cost-predictor ← LatencyHead
        if let latency = options.latencyHeadClosure {
            let head = BASChengluLatencyHeadAdapter.make(
                headID: canonicalHeadID(
                    layer: .l1,
                    role: "compute-cost-predictor"),
                layerIDPin: .l1,
                inferenceClosure: latency)
            try await registrar.register(
                head: head, into: registry,
                layerID: .l1, priority: priority)
        } else {
            missing.append("latencyHead")
        }

        // MultiHead → 4 slots (intent / emotion / memory_importance / risk)
        if let multiHead = options.multiHeadClosure {
            let multiHeadSlots: [(BASMotherboardLayer14,
                String, String)] = [
                (.l4, "question-type",
                    BASChengluMultiHeadAdapter.intentKey),
                (.l6, "emotion-classifier",
                    BASChengluMultiHeadAdapter.emotionKey),
                (.l8, "importance-scorer",
                    BASChengluMultiHeadAdapter
                        .memoryImportanceKey),
                (.l11, "risk-scorer",
                    BASChengluMultiHeadAdapter.riskKey)
            ]
            for (layer, role, outputKey) in multiHeadSlots {
                let head = BASChengluMultiHeadAdapter.make(
                    headID: canonicalHeadID(
                        layer: layer, role: role),
                    layerIDPin: layer,
                    outputKey: outputKey,
                    inferenceClosure: multiHead)
                try await registrar.register(
                    head: head, into: registry,
                    layerID: layer, priority: priority)
            }
        } else {
            missing.append("multiHead")
        }

        // L11.safety-action-selector ← PermitPredict
        if let permit = options.permitPredictClosure {
            let head = BASChengluPermitPredictAdapter.make(
                headID: canonicalHeadID(
                    layer: .l11,
                    role: "safety-action-selector"),
                layerIDPin: .l11,
                inferenceClosure: permit)
            try await registrar.register(
                head: head, into: registry,
                layerID: .l11, priority: priority)
        } else {
            missing.append("permitPredict")
        }

        // L12.density-controller ← LengthHead
        if let length = options.lengthHeadClosure {
            let head = BASChengluLengthHeadAdapter.make(
                headID: canonicalHeadID(
                    layer: .l12,
                    role: "density-controller"),
                layerIDPin: .l12,
                inferenceClosure: length)
            try await registrar.register(
                head: head, into: registry,
                layerID: .l12, priority: priority)
        } else {
            missing.append("lengthHead")
        }

        let perLayerByRawValue =
            registrar.perLayerCountsByRawValue
        let reasonCodes = makeReasonCodes(
            registered: registrar.registeredHeadCount,
            missing: missing,
            perLayerCounts: perLayerByRawValue)
        return BASChengluMeshRegistrationReport(
            registeredHeadCount: registrar.registeredHeadCount,
            perLayerCounts: perLayerByRawValue,
            missingMLModels: missing,
            reasonCodes: reasonCodes)
    }

    // MARK: - Reason code emission

    /// Emit canonical typed reason codes for assembly result。
    public static func makeReasonCodes(
        registered: Int,
        missing: [String],
        perLayerCounts: [String: Int]
    ) -> [String] {
        var codes: [String] = [
            "mesh-coreml:registered:\(registered)",
            "mesh-coreml:expected:8"
        ]
        for model in missing.sorted() {
            codes.append("mesh-coreml:missing:\(model)")
        }
        for layer in BASMotherboardLayer14.allCases {
            if let count = perLayerCounts[layer.rawValue],
               count > 0
            {
                codes.append(
                    "mesh-coreml:layer-\(layer.rawValue):" +
                    "\(count)")
            }
        }
        return codes
    }
}

