import Foundation
import BASMemory
import BASObservability
import BASRuntimeCore

public struct BASAppleRuntimeInspectionAdapterInput: Codable, Sendable, Equatable {
    public var activeProviderID: String
    public var fallbackProviderID: String?
    public var runtimeGear: BASRuntimeGear
    public var environmentClass: BASEnvironmentClass
    public var deviceClass: BASDevicePerformanceClass
    public var languageMode: BASLanguageMode
    public var taskEntropyByKind: [String: BASTaskEntropyClass]
    public var preferredProviderRawValueByKind: [String: String]
    public var strategyByKind: [String: BASAdaptiveTaskStrategy]
    public var effectivePreferredProviderRawValueByKind: [String: String]
    public var traceInputs: [BASRuntimeInspectionTraceInput]
    public var telemetrySummary: BASTelemetrySummary
    public var lifecycleSummary: BASLifecycleSummary
    public var neuralSummary: BASNeuralSummary
    public var brainSummary: BASBrainSummary
    public var totalCacheEntries: Int
    public var totalCacheLookupCount: Int
    public var totalCacheRejectedStores: Int
    public var totalCacheQuarantinedHits: Int
    public var dominantBackendID: String?
    public var registeredProviderCount: Int
    public var registeredOpenModelProviderCount: Int
    public var activeCircuitProviderIDs: [String]
    public var circuitTripCount: Int
    public var circuitTripCountByProvider: [String: Int]
    public var circuitTripCountByReason: [String: Int]
    public var traceCount: Int
    public var replayCount: Int

    public init(
        activeProviderID: String,
        fallbackProviderID: String?,
        runtimeGear: BASRuntimeGear,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass,
        languageMode: BASLanguageMode,
        taskEntropyByKind: [String: BASTaskEntropyClass],
        preferredProviderRawValueByKind: [String: String],
        strategyByKind: [String: BASAdaptiveTaskStrategy],
        effectivePreferredProviderRawValueByKind: [String: String],
        traceInputs: [BASRuntimeInspectionTraceInput],
        telemetrySummary: BASTelemetrySummary,
        lifecycleSummary: BASLifecycleSummary,
        neuralSummary: BASNeuralSummary,
        brainSummary: BASBrainSummary,
        totalCacheEntries: Int,
        totalCacheLookupCount: Int,
        totalCacheRejectedStores: Int,
        totalCacheQuarantinedHits: Int,
        dominantBackendID: String?,
        registeredProviderCount: Int,
        registeredOpenModelProviderCount: Int,
        activeCircuitProviderIDs: [String],
        circuitTripCount: Int,
        circuitTripCountByProvider: [String: Int],
        circuitTripCountByReason: [String: Int],
        traceCount: Int,
        replayCount: Int
    ) {
        self.activeProviderID = activeProviderID
        self.fallbackProviderID = fallbackProviderID
        self.runtimeGear = runtimeGear
        self.environmentClass = environmentClass
        self.deviceClass = deviceClass
        self.languageMode = languageMode
        self.taskEntropyByKind = taskEntropyByKind
        self.preferredProviderRawValueByKind = preferredProviderRawValueByKind
        self.strategyByKind = strategyByKind
        self.effectivePreferredProviderRawValueByKind = effectivePreferredProviderRawValueByKind
        self.traceInputs = traceInputs
        self.telemetrySummary = telemetrySummary
        self.lifecycleSummary = lifecycleSummary
        self.neuralSummary = neuralSummary
        self.brainSummary = brainSummary
        self.totalCacheEntries = totalCacheEntries
        self.totalCacheLookupCount = totalCacheLookupCount
        self.totalCacheRejectedStores = totalCacheRejectedStores
        self.totalCacheQuarantinedHits = totalCacheQuarantinedHits
        self.dominantBackendID = dominantBackendID
        self.registeredProviderCount = registeredProviderCount
        self.registeredOpenModelProviderCount = registeredOpenModelProviderCount
        self.activeCircuitProviderIDs = activeCircuitProviderIDs
        self.circuitTripCount = circuitTripCount
        self.circuitTripCountByProvider = circuitTripCountByProvider
        self.circuitTripCountByReason = circuitTripCountByReason
        self.traceCount = traceCount
        self.replayCount = replayCount
    }
}

public struct BASAppleRuntimeInspectionTraceSourceInput: Codable, Sendable, Equatable {
    public var lifecycle: BASLifecycleTraceInput?
    public var neural: BASNeuralTraceInput?
    public var brain: BASBrainTraceInput?
    public var runtimeInspection: BASRuntimeInspectionTraceInput

    public init(
        lifecycle: BASLifecycleTraceInput? = nil,
        neural: BASNeuralTraceInput? = nil,
        brain: BASBrainTraceInput? = nil,
        runtimeInspection: BASRuntimeInspectionTraceInput
    ) {
        self.lifecycle = lifecycle
        self.neural = neural
        self.brain = brain
        self.runtimeInspection = runtimeInspection
    }
}

public struct BASAppleRuntimeInspectionSourceInput: Codable, Sendable, Equatable {
    public var activeProviderID: String
    public var fallbackProviderID: String?
    public var runtimeGear: BASRuntimeGear
    public var environmentClass: BASEnvironmentClass
    public var deviceClass: BASDevicePerformanceClass
    public var languageMode: BASLanguageMode
    public var taskEntropyByKind: [String: BASTaskEntropyClass]
    public var preferredProviderRawValueByKind: [String: String]
    public var strategyByKind: [String: BASAdaptiveTaskStrategy]
    public var effectivePreferredProviderRawValueByKind: [String: String]
    public var traceSources: [BASAppleRuntimeInspectionTraceSourceInput]
    public var telemetrySummary: BASTelemetrySummary
    public var totalCacheEntries: Int
    public var totalCacheLookupCount: Int
    public var totalCacheRejectedStores: Int
    public var totalCacheQuarantinedHits: Int
    public var dominantBackendID: String?
    public var registeredProviderCount: Int
    public var registeredOpenModelProviderCount: Int
    public var activeCircuitProviderIDs: [String]
    public var circuitTripCount: Int
    public var circuitTripCountByProvider: [String: Int]
    public var circuitTripCountByReason: [String: Int]
    public var traceCount: Int
    public var replayCount: Int

    public init(
        activeProviderID: String,
        fallbackProviderID: String?,
        runtimeGear: BASRuntimeGear,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass,
        languageMode: BASLanguageMode,
        taskEntropyByKind: [String: BASTaskEntropyClass],
        preferredProviderRawValueByKind: [String: String],
        strategyByKind: [String: BASAdaptiveTaskStrategy],
        effectivePreferredProviderRawValueByKind: [String: String],
        traceSources: [BASAppleRuntimeInspectionTraceSourceInput],
        telemetrySummary: BASTelemetrySummary,
        totalCacheEntries: Int,
        totalCacheLookupCount: Int,
        totalCacheRejectedStores: Int,
        totalCacheQuarantinedHits: Int,
        dominantBackendID: String?,
        registeredProviderCount: Int,
        registeredOpenModelProviderCount: Int,
        activeCircuitProviderIDs: [String],
        circuitTripCount: Int,
        circuitTripCountByProvider: [String: Int],
        circuitTripCountByReason: [String: Int],
        traceCount: Int,
        replayCount: Int
    ) {
        self.activeProviderID = activeProviderID
        self.fallbackProviderID = fallbackProviderID
        self.runtimeGear = runtimeGear
        self.environmentClass = environmentClass
        self.deviceClass = deviceClass
        self.languageMode = languageMode
        self.taskEntropyByKind = taskEntropyByKind
        self.preferredProviderRawValueByKind = preferredProviderRawValueByKind
        self.strategyByKind = strategyByKind
        self.effectivePreferredProviderRawValueByKind = effectivePreferredProviderRawValueByKind
        self.traceSources = traceSources
        self.telemetrySummary = telemetrySummary
        self.totalCacheEntries = totalCacheEntries
        self.totalCacheLookupCount = totalCacheLookupCount
        self.totalCacheRejectedStores = totalCacheRejectedStores
        self.totalCacheQuarantinedHits = totalCacheQuarantinedHits
        self.dominantBackendID = dominantBackendID
        self.registeredProviderCount = registeredProviderCount
        self.registeredOpenModelProviderCount = registeredOpenModelProviderCount
        self.activeCircuitProviderIDs = activeCircuitProviderIDs
        self.circuitTripCount = circuitTripCount
        self.circuitTripCountByProvider = circuitTripCountByProvider
        self.circuitTripCountByReason = circuitTripCountByReason
        self.traceCount = traceCount
        self.replayCount = replayCount
    }
}

public struct BASAppleRuntimeInspectionCompilation: Codable, Sendable, Equatable {
    public var lifecycleSummary: BASLifecycleSummary
    public var neuralSummary: BASNeuralSummary
    public var brainSummary: BASBrainSummary
    public var runtimeInspectionInput: BASRuntimeInspectionInput
    public var runtimeInspectionSummary: BASRuntimeInspectionSummary

    public init(
        lifecycleSummary: BASLifecycleSummary,
        neuralSummary: BASNeuralSummary,
        brainSummary: BASBrainSummary,
        runtimeInspectionInput: BASRuntimeInspectionInput,
        runtimeInspectionSummary: BASRuntimeInspectionSummary
    ) {
        self.lifecycleSummary = lifecycleSummary
        self.neuralSummary = neuralSummary
        self.brainSummary = brainSummary
        self.runtimeInspectionInput = runtimeInspectionInput
        self.runtimeInspectionSummary = runtimeInspectionSummary
    }
}

public enum BASAppleRuntimeInspectionBuilder {
    public static func build(
        from input: BASAppleRuntimeInspectionSourceInput
    ) -> BASAppleRuntimeInspectionCompilation {
        let lifecycleTraceInputs = input.traceSources.compactMap(\.lifecycle)
        let neuralTraceInputs = input.traceSources.compactMap(\.neural)
        let brainTraceInputs = input.traceSources.compactMap(\.brain)
        let runtimeInspectionTraceInputs = input.traceSources.map(\.runtimeInspection)

        let lifecycleSummary = BASLifecycleSummaryBuilder.build(
            from: lifecycleTraceInputs
        )
        let neuralSummary = BASNeuralSummaryBuilder.build(
            from: neuralTraceInputs
        )
        let brainSummary = BASBrainSummaryBuilder.build(
            from: brainTraceInputs
        )
        let runtimeInspectionInput = BASAppleObservabilityAdapter.compileRuntimeInspectionInput(
            from: BASAppleRuntimeInspectionAdapterInput(
                activeProviderID: input.activeProviderID,
                fallbackProviderID: input.fallbackProviderID,
                runtimeGear: input.runtimeGear,
                environmentClass: input.environmentClass,
                deviceClass: input.deviceClass,
                languageMode: input.languageMode,
                taskEntropyByKind: input.taskEntropyByKind,
                preferredProviderRawValueByKind: input.preferredProviderRawValueByKind,
                strategyByKind: input.strategyByKind,
                effectivePreferredProviderRawValueByKind: input.effectivePreferredProviderRawValueByKind,
                traceInputs: runtimeInspectionTraceInputs,
                telemetrySummary: input.telemetrySummary,
                lifecycleSummary: lifecycleSummary,
                neuralSummary: neuralSummary,
                brainSummary: brainSummary,
                totalCacheEntries: input.totalCacheEntries,
                totalCacheLookupCount: input.totalCacheLookupCount,
                totalCacheRejectedStores: input.totalCacheRejectedStores,
                totalCacheQuarantinedHits: input.totalCacheQuarantinedHits,
                dominantBackendID: input.dominantBackendID,
                registeredProviderCount: input.registeredProviderCount,
                registeredOpenModelProviderCount: input.registeredOpenModelProviderCount,
                activeCircuitProviderIDs: input.activeCircuitProviderIDs,
                circuitTripCount: input.circuitTripCount,
                circuitTripCountByProvider: input.circuitTripCountByProvider,
                circuitTripCountByReason: input.circuitTripCountByReason,
                traceCount: input.traceCount,
                replayCount: input.replayCount
            )
        )

        return BASAppleRuntimeInspectionCompilation(
            lifecycleSummary: lifecycleSummary,
            neuralSummary: neuralSummary,
            brainSummary: brainSummary,
            runtimeInspectionInput: runtimeInspectionInput,
            runtimeInspectionSummary: BASRuntimeInspectionBuilder.build(from: runtimeInspectionInput)
        )
    }
}

public extension BASAppleObservabilityAdapter {
    static func compileRuntimeInspectionInput(
        from input: BASAppleRuntimeInspectionAdapterInput
    ) -> BASRuntimeInspectionInput {
        BASRuntimeInspectionInput(
            activeProviderID: input.activeProviderID,
            fallbackProviderID: input.fallbackProviderID,
            runtimeGear: input.runtimeGear,
            environmentClass: input.environmentClass,
            deviceClass: input.deviceClass,
            languageMode: input.languageMode,
            taskEntropyByKind: input.taskEntropyByKind,
            preferredProviderRawValueByKind: input.preferredProviderRawValueByKind,
            strategyByKind: input.strategyByKind,
            effectivePreferredProviderRawValueByKind: input.effectivePreferredProviderRawValueByKind,
            traceInputs: input.traceInputs,
            telemetrySummary: input.telemetrySummary,
            lifecycleSummary: input.lifecycleSummary,
            neuralSummary: input.neuralSummary,
            brainSummary: input.brainSummary,
            totalCacheEntries: input.totalCacheEntries,
            totalCacheLookupCount: input.totalCacheLookupCount,
            totalCacheRejectedStores: input.totalCacheRejectedStores,
            totalCacheQuarantinedHits: input.totalCacheQuarantinedHits,
            dominantBackendID: input.dominantBackendID,
            registeredProviderCount: input.registeredProviderCount,
            registeredOpenModelProviderCount: input.registeredOpenModelProviderCount,
            activeCircuitProviderIDs: input.activeCircuitProviderIDs,
            circuitTripCount: input.circuitTripCount,
            circuitTripCountByProvider: input.circuitTripCountByProvider,
            circuitTripCountByReason: input.circuitTripCountByReason,
            traceCount: input.traceCount,
            replayCount: input.replayCount
        )
    }
}
