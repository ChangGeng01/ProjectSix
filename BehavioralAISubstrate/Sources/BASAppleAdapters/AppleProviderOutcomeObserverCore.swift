import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public struct BASAppleProviderTraceObservation: Codable, Sendable, Equatable {
    public var detail: String
    public var compilation: BASAppleProviderTraceCompilation

    public init(
        detail: String,
        compilation: BASAppleProviderTraceCompilation
    ) {
        self.detail = detail
        self.compilation = compilation
    }
}

public struct BASAppleProviderTelemetryObservation: Codable, Sendable, Equatable {
    public var input: BASAppleTelemetryRecordInput
    public var compilation: BASAppleTelemetryRecordCompilation

    public init(
        input: BASAppleTelemetryRecordInput,
        compilation: BASAppleTelemetryRecordCompilation
    ) {
        self.input = input
        self.compilation = compilation
    }
}

public struct BASAppleProviderProfile: Codable, Sendable, Equatable {
    public var providerID: String
    public var title: String
    public var activeResolutionDetail: String?
    public var activeBackendID: String?

    public init(
        providerID: String,
        title: String,
        activeResolutionDetail: String? = nil,
        activeBackendID: String? = nil
    ) {
        self.providerID = providerID
        self.title = title
        self.activeResolutionDetail = activeResolutionDetail
        self.activeBackendID = activeBackendID
    }
}

public struct BASAppleProviderObservationNarrative: Codable, Sendable, Equatable {
    public var templatePinnedDetail: String
    public var admissionSkippedDetailPrefix: String
    public var deterministicFallbackBase: String
    public var cachedConsistencySource: String
    public var providerConsistencySource: String

    public init(
        templatePinnedDetail: String,
        admissionSkippedDetailPrefix: String,
        deterministicFallbackBase: String,
        cachedConsistencySource: String,
        providerConsistencySource: String
    ) {
        self.templatePinnedDetail = templatePinnedDetail
        self.admissionSkippedDetailPrefix = admissionSkippedDetailPrefix
        self.deterministicFallbackBase = deterministicFallbackBase
        self.cachedConsistencySource = cachedConsistencySource
        self.providerConsistencySource = providerConsistencySource
    }
}

public struct BASAppleProviderObservationNarrativeBehavior: Codable, Sendable, Equatable {
    public static let generic = BASAppleProviderObservationNarrativeBehavior()

    public var narrativesByKindID: [String: BASAppleProviderObservationNarrative]
    public var fallbackNarrative: BASAppleProviderObservationNarrative

    public init(
        narrativesByKindID: [String: BASAppleProviderObservationNarrative] = [
            BASDecisionMode.primaryID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the primary pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the primary pass.",
                deterministicFallbackBase: "No provider returned a primary-pass result, so the host kept the deterministic copy.",
                cachedConsistencySource: "cached primary pass",
                providerConsistencySource: "provider primary pass"
            ),
            BASDecisionMode.comparativeID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the comparative pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the comparative pass.",
                deterministicFallbackBase: "No provider returned a comparative-pass result, so the host kept the deterministic copy.",
                cachedConsistencySource: "cached comparative pass",
                providerConsistencySource: "provider comparative pass"
            ),
            BASDecisionMode.reflectiveID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the reflective pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the reflective pass.",
                deterministicFallbackBase: "No provider returned a reflective-pass result, so the host kept the deterministic copy.",
                cachedConsistencySource: "cached reflective pass",
                providerConsistencySource: "provider reflective pass"
            ),
            "reminder": BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for reminder selection.",
                admissionSkippedDetailPrefix: "Admission controller skipped reminder selection.",
                deterministicFallbackBase: "No provider returned a reminder selection, so the host kept the deterministic reminder ordering.",
                cachedConsistencySource: "cached reminder selection",
                providerConsistencySource: "provider reminder selection"
            )
        ],
        fallbackNarrative: BASAppleProviderObservationNarrative = BASAppleProviderObservationNarrative(
            templatePinnedDetail: "Template mode is pinned, so no model provider was used.",
            admissionSkippedDetailPrefix: "Admission controller skipped provider execution.",
            deterministicFallbackBase: "No provider returned a result, so the host kept the deterministic copy.",
            cachedConsistencySource: "cached provider result",
            providerConsistencySource: "provider result"
        )
    ) {
        self.narrativesByKindID = narrativesByKindID
        self.fallbackNarrative = fallbackNarrative
    }

    public func narrative(for kindID: String) -> BASAppleProviderObservationNarrative {
        for alias in Self.kindAliases(for: kindID) {
            if let configured = narrativesByKindID[alias] {
                return configured
            }
        }
        return fallbackNarrative
    }

    private static func kindAliases(for kindID: String) -> [String] {
        switch kindID {
        case "quick", BASDecisionMode.primaryID:
            [kindID, BASDecisionMode.primaryID, "quick"]
        case "balance", BASDecisionMode.comparativeID:
            [kindID, BASDecisionMode.comparativeID, "balance"]
        case "mirror", BASDecisionMode.reflectiveID:
            [kindID, BASDecisionMode.reflectiveID, "mirror"]
        default:
            [kindID]
        }
    }
}

public struct BASAppleHostProviderObservationContext<
    Kind: Equatable & Sendable,
    FrontstageState: Equatable & Sendable,
    ContextState: Equatable & Sendable,
    NeuralState: Equatable & Sendable,
    BrainState: Equatable & Sendable,
    RuntimeStrategy: Equatable & Sendable,
    PromptBudget: Equatable & Sendable,
    AdmissionDecision: Equatable & Sendable
>: Equatable, Sendable {
    public var kind: Kind
    public var frontstageState: FrontstageState?
    public var contextState: ContextState?
    public var neuralState: NeuralState?
    public var brainState: BrainState?
    public var runtimeStrategy: RuntimeStrategy?
    public var promptBudget: PromptBudget?
    public var admissionDecision: AdmissionDecision?
    public var substrateContext: BASAppleProviderObservationContext

    public init(
        kind: Kind,
        frontstageState: FrontstageState? = nil,
        contextState: ContextState? = nil,
        neuralState: NeuralState? = nil,
        brainState: BrainState? = nil,
        runtimeStrategy: RuntimeStrategy? = nil,
        promptBudget: PromptBudget? = nil,
        admissionDecision: AdmissionDecision? = nil,
        substrateContext: BASAppleProviderObservationContext
    ) {
        self.kind = kind
        self.frontstageState = frontstageState
        self.contextState = contextState
        self.neuralState = neuralState
        self.brainState = brainState
        self.runtimeStrategy = runtimeStrategy
        self.promptBudget = promptBudget
        self.admissionDecision = admissionDecision
        self.substrateContext = substrateContext
    }
}

public struct BASAppleHostProviderTraceRecord<
    Kind: Equatable & Sendable,
    FrontstageState: Equatable & Sendable,
    ContextState: Equatable & Sendable,
    NeuralState: Equatable & Sendable,
    BrainState: Equatable & Sendable,
    RuntimeStrategy: Equatable & Sendable,
    PromptBudget: Equatable & Sendable,
    AdmissionDecision: Equatable & Sendable
>: Equatable, Sendable {
    public var kind: Kind
    public var preferredProviderID: String
    public var activeProviderID: String?
    public var attemptedProviderIDs: [String]
    public var allowFallbacks: Bool
    public var usedFallback: Bool
    public var frontstageState: FrontstageState?
    public var contextState: ContextState?
    public var neuralState: NeuralState?
    public var brainState: BrainState?
    public var runtimeStrategy: RuntimeStrategy?
    public var promptBudget: PromptBudget?
    public var admissionDecision: AdmissionDecision?
    public var semanticPromptFingerprint: String?
    public var stablePrefixFingerprint: String?
    public var consistencyCheck: BASConsistencyCheckResult?
    public var consistencyRejected: Bool
    public var substrateTrace: BASExecutionTrace?
    public var prompt: String
    public var outputPreview: String
    public var detail: String

    public init(
        kind: Kind,
        preferredProviderID: String,
        activeProviderID: String?,
        attemptedProviderIDs: [String],
        allowFallbacks: Bool,
        usedFallback: Bool,
        frontstageState: FrontstageState? = nil,
        contextState: ContextState? = nil,
        neuralState: NeuralState? = nil,
        brainState: BrainState? = nil,
        runtimeStrategy: RuntimeStrategy? = nil,
        promptBudget: PromptBudget? = nil,
        admissionDecision: AdmissionDecision? = nil,
        semanticPromptFingerprint: String? = nil,
        stablePrefixFingerprint: String? = nil,
        consistencyCheck: BASConsistencyCheckResult? = nil,
        consistencyRejected: Bool = false,
        substrateTrace: BASExecutionTrace? = nil,
        prompt: String,
        outputPreview: String,
        detail: String
    ) {
        self.kind = kind
        self.preferredProviderID = preferredProviderID
        self.activeProviderID = activeProviderID
        self.attemptedProviderIDs = attemptedProviderIDs
        self.allowFallbacks = allowFallbacks
        self.usedFallback = usedFallback
        self.frontstageState = frontstageState
        self.contextState = contextState
        self.neuralState = neuralState
        self.brainState = brainState
        self.runtimeStrategy = runtimeStrategy
        self.promptBudget = promptBudget
        self.admissionDecision = admissionDecision
        self.semanticPromptFingerprint = semanticPromptFingerprint
        self.stablePrefixFingerprint = stablePrefixFingerprint
        self.consistencyCheck = consistencyCheck
        self.consistencyRejected = consistencyRejected
        self.substrateTrace = substrateTrace
        self.prompt = prompt
        self.outputPreview = outputPreview
        self.detail = detail
    }
}

public enum BASAppleHostProviderObservationBridge {
    public static func context<
        Kind: Equatable & Sendable,
        FrontstageState: Equatable & Sendable,
        ContextState: Equatable & Sendable,
        NeuralState: Equatable & Sendable,
        BrainState: Equatable & Sendable,
        RuntimeStrategy: Equatable & Sendable,
        PromptBudget: Equatable & Sendable,
        AdmissionDecision: Equatable & Sendable
    >(
        kind: Kind,
        frontstageState: FrontstageState? = nil,
        contextState: ContextState? = nil,
        neuralState: NeuralState? = nil,
        brainState: BrainState? = nil,
        runtimeStrategy: RuntimeStrategy? = nil,
        promptBudget: PromptBudget? = nil,
        admissionDecision: AdmissionDecision? = nil,
        sourceInput: BASAppleProviderObservationSourceInput
    ) -> BASAppleHostProviderObservationContext<
        Kind,
        FrontstageState,
        ContextState,
        NeuralState,
        BrainState,
        RuntimeStrategy,
        PromptBudget,
        AdmissionDecision
    > {
        BASAppleHostProviderObservationContext(
            kind: kind,
            frontstageState: frontstageState,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState,
            runtimeStrategy: runtimeStrategy,
            promptBudget: promptBudget,
            admissionDecision: admissionDecision,
            substrateContext: BASAppleProviderObservationContextBuilder.build(
                from: sourceInput
            )
        )
    }

    public static func providerProfiles<Descriptor>(
        descriptors: [Descriptor],
        providerID: (Descriptor) -> String,
        title: (Descriptor) -> String,
        activeResolutionDetail: (Descriptor) -> String?,
        activeBackendID: (Descriptor) -> String?
    ) -> [String: BASAppleProviderProfile] {
        Dictionary(
            uniqueKeysWithValues: descriptors.map { descriptor in
                let id = providerID(descriptor)
                return (
                    id,
                    BASAppleProviderProfile(
                        providerID: id,
                        title: title(descriptor),
                        activeResolutionDetail: activeResolutionDetail(descriptor),
                        activeBackendID: activeBackendID(descriptor)
                    )
                )
            }
        )
    }

    public static func traceRecord<
        Kind: Equatable & Sendable,
        FrontstageState: Equatable & Sendable,
        ContextState: Equatable & Sendable,
        NeuralState: Equatable & Sendable,
        BrainState: Equatable & Sendable,
        RuntimeStrategy: Equatable & Sendable,
        PromptBudget: Equatable & Sendable,
        AdmissionDecision: Equatable & Sendable
    >(
        context: BASAppleHostProviderObservationContext<
            Kind,
            FrontstageState,
            ContextState,
            NeuralState,
            BrainState,
            RuntimeStrategy,
            PromptBudget,
            AdmissionDecision
        >,
        observedTrace: BASAppleObservedProviderTrace
    ) -> BASAppleHostProviderTraceRecord<
        Kind,
        FrontstageState,
        ContextState,
        NeuralState,
        BrainState,
        RuntimeStrategy,
        PromptBudget,
        AdmissionDecision
    > {
        BASAppleHostProviderTraceRecord(
            kind: context.kind,
            preferredProviderID: context.substrateContext.preferredProviderID,
            activeProviderID: observedTrace.activeProviderID,
            attemptedProviderIDs: observedTrace.attemptedProviderIDs,
            allowFallbacks: context.substrateContext.allowFallbacks,
            usedFallback: observedTrace.activeProviderID != nil
                && observedTrace.activeProviderID != context.substrateContext.preferredProviderID,
            frontstageState: context.frontstageState,
            contextState: context.contextState,
            neuralState: context.neuralState,
            brainState: context.brainState,
            runtimeStrategy: context.runtimeStrategy,
            promptBudget: context.promptBudget,
            admissionDecision: context.admissionDecision,
            semanticPromptFingerprint: context.substrateContext.semanticPromptFingerprint,
            stablePrefixFingerprint: context.substrateContext.stablePrefixFingerprint,
            consistencyCheck: observedTrace.consistencyCheck,
            consistencyRejected: observedTrace.consistencyRejected,
            substrateTrace: observedTrace.observation.compilation.executionTrace,
            prompt: observedTrace.observation.compilation.storedPrompt,
            outputPreview: observedTrace.observation.compilation.storedOutputPreview,
            detail: observedTrace.observation.detail
        )
    }

    public static func applyCircuitEvent<ProviderID, Kind>(
        _ event: BASAppleProviderCircuitEvent,
        providerForID: (String) -> ProviderID?,
        kindForID: (String) -> Kind?,
        onCacheHit: (ProviderID) async -> Void,
        onProviderFailure: (ProviderID) async -> Void,
        onProviderSuccess: (ProviderID, Kind, Double) async -> Void
    ) async {
        switch event {
        case .cacheHit(let providerID):
            guard let provider = providerForID(providerID) else { return }
            await onCacheHit(provider)
        case .providerFailure(let providerID):
            guard let provider = providerForID(providerID) else { return }
            await onProviderFailure(provider)
        case .providerSuccess(let providerID, let kindID, let durationMs):
            guard let provider = providerForID(providerID),
                  let kind = kindForID(kindID)
            else {
                return
            }
            await onProviderSuccess(provider, kind, durationMs)
        }
    }
}

public enum BASAppleHostProviderObservationExecutor {
    public static func handleEvent<
        Provider: Sendable,
        Result: Sendable,
        Kind: Equatable & Sendable,
        FrontstageState: Equatable & Sendable,
        ContextState: Equatable & Sendable,
        NeuralState: Equatable & Sendable,
        BrainState: Equatable & Sendable,
        RuntimeStrategy: Equatable & Sendable,
        PromptBudget: Equatable & Sendable,
        AdmissionDecision: Equatable & Sendable
    >(
        _ event: BASProviderRequestEvent<Provider, Result, BASProviderReleaseAssessment>,
        context: BASAppleHostProviderObservationContext<
            Kind,
            FrontstageState,
            ContextState,
            NeuralState,
            BrainState,
            RuntimeStrategy,
            PromptBudget,
            AdmissionDecision
        >,
        durationMs: Double,
        promptPreparedMs: Double,
        admissionEvaluatedMs: Double? = nil,
        providerID: (Provider) -> String,
        storeResolvedResult: ((Provider, Result) async -> Void)? = nil,
        applyCircuitEvent: @escaping (BASAppleProviderCircuitEvent) async -> Void,
        recordTelemetry: @escaping (BASAppleProviderTelemetryObservation) async -> Void,
        recordTrace: @escaping @MainActor (
            BASAppleHostProviderTraceRecord<
                Kind,
                FrontstageState,
                ContextState,
                NeuralState,
                BrainState,
                RuntimeStrategy,
                PromptBudget,
                AdmissionDecision
            >
        ) async -> Void
    ) async {
        if case .providerSuccess(let attempt) = event {
            await storeResolvedResult?(attempt.provider, attempt.result)
        }

        let observation = BASAppleProviderOutcomeObserver.observeEvent(
            event,
            context: context.substrateContext,
            durationMs: durationMs,
            promptPreparedMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            providerID: providerID
        )

        for event in observation.circuitEvents {
            await applyCircuitEvent(event)
        }

        if let telemetryObservation = observation.telemetryObservation {
            await recordTelemetry(telemetryObservation)
        }

        if let trace = observation.trace {
            await recordTrace(
                BASAppleHostProviderObservationBridge.traceRecord(
                    context: context,
                    observedTrace: trace
                )
            )
        }
    }
}

public struct BASAppleProviderObservationContext: Codable, Sendable, Equatable {
    public var kind: String
    public var preferredProviderID: String
    public var allowFallbacks: Bool
    public var providerProfilesByID: [String: BASAppleProviderProfile]
    public var promptBudget: BASPromptBudget?
    public var brainState: BASDecisionBrainState?
    public var admissionPressureID: String?
    public var admissionSkipReasonID: String?
    public var reminderSelectionNeedID: String?
    public var runtimeTimeBudgetMs: Int?
    public var admissionReason: String?
    public var semanticPromptFingerprint: String?
    public var stablePrefixFingerprint: String?
    public var prompt: String
    public var templatePinnedOutputPreview: String
    public var admissionSkippedOutputPreview: String
    public var deterministicFallbackOutputPreview: String
    public var templatePinnedDetail: String
    public var admissionSkippedDetailPrefix: String
    public var deterministicFallbackBase: String
    public var cachedConsistencySource: String
    public var providerConsistencySource: String
    public var recordsTemplatePinnedTrace: Bool

    public init(
        kind: String,
        preferredProviderID: String,
        allowFallbacks: Bool,
        providerProfilesByID: [String: BASAppleProviderProfile],
        promptBudget: BASPromptBudget? = nil,
        brainState: BASDecisionBrainState? = nil,
        admissionPressureID: String? = nil,
        admissionSkipReasonID: String? = nil,
        reminderSelectionNeedID: String? = nil,
        runtimeTimeBudgetMs: Int? = nil,
        admissionReason: String? = nil,
        semanticPromptFingerprint: String? = nil,
        stablePrefixFingerprint: String? = nil,
        prompt: String,
        templatePinnedOutputPreview: String,
        admissionSkippedOutputPreview: String,
        deterministicFallbackOutputPreview: String,
        templatePinnedDetail: String,
        admissionSkippedDetailPrefix: String,
        deterministicFallbackBase: String,
        cachedConsistencySource: String,
        providerConsistencySource: String,
        recordsTemplatePinnedTrace: Bool
    ) {
        self.kind = kind
        self.preferredProviderID = preferredProviderID
        self.allowFallbacks = allowFallbacks
        self.providerProfilesByID = providerProfilesByID
        self.promptBudget = promptBudget
        self.brainState = brainState
        self.admissionPressureID = admissionPressureID
        self.admissionSkipReasonID = admissionSkipReasonID
        self.reminderSelectionNeedID = reminderSelectionNeedID
        self.runtimeTimeBudgetMs = runtimeTimeBudgetMs
        self.admissionReason = admissionReason
        self.semanticPromptFingerprint = semanticPromptFingerprint
        self.stablePrefixFingerprint = stablePrefixFingerprint
        self.prompt = prompt
        self.templatePinnedOutputPreview = templatePinnedOutputPreview
        self.admissionSkippedOutputPreview = admissionSkippedOutputPreview
        self.deterministicFallbackOutputPreview = deterministicFallbackOutputPreview
        self.templatePinnedDetail = templatePinnedDetail
        self.admissionSkippedDetailPrefix = admissionSkippedDetailPrefix
        self.deterministicFallbackBase = deterministicFallbackBase
        self.cachedConsistencySource = cachedConsistencySource
        self.providerConsistencySource = providerConsistencySource
        self.recordsTemplatePinnedTrace = recordsTemplatePinnedTrace
    }
}

public struct BASAppleProviderObservationSourceInput: Codable, Sendable, Equatable {
    public var kind: String
    public var preferredProviderID: String
    public var allowFallbacks: Bool
    public var providerProfilesByID: [String: BASAppleProviderProfile]
    public var promptBudget: BASPromptBudget?
    public var brainState: BASDecisionBrainState?
    public var admissionPressureID: String?
    public var admissionSkipReasonID: String?
    public var reminderSelectionNeedID: String?
    public var runtimeTimeBudgetMs: Int?
    public var admissionReason: String?
    public var semanticPromptFingerprint: String?
    public var stablePrefixFingerprint: String?
    public var narrativeOverride: BASAppleProviderObservationNarrative?
    public var prompt: String
    public var baselineOutputPreview: String
    public var deterministicFallbackOutputPreview: String
    public var recordsTemplatePinnedTrace: Bool

    public init(
        kind: String,
        preferredProviderID: String,
        allowFallbacks: Bool,
        providerProfilesByID: [String: BASAppleProviderProfile],
        promptBudget: BASPromptBudget? = nil,
        brainState: BASDecisionBrainState? = nil,
        admissionPressureID: String? = nil,
        admissionSkipReasonID: String? = nil,
        reminderSelectionNeedID: String? = nil,
        runtimeTimeBudgetMs: Int? = nil,
        admissionReason: String? = nil,
        semanticPromptFingerprint: String? = nil,
        stablePrefixFingerprint: String? = nil,
        narrativeOverride: BASAppleProviderObservationNarrative? = nil,
        prompt: String,
        baselineOutputPreview: String,
        deterministicFallbackOutputPreview: String,
        recordsTemplatePinnedTrace: Bool
    ) {
        self.kind = kind
        self.preferredProviderID = preferredProviderID
        self.allowFallbacks = allowFallbacks
        self.providerProfilesByID = providerProfilesByID
        self.promptBudget = promptBudget
        self.brainState = brainState
        self.admissionPressureID = admissionPressureID
        self.admissionSkipReasonID = admissionSkipReasonID
        self.reminderSelectionNeedID = reminderSelectionNeedID
        self.runtimeTimeBudgetMs = runtimeTimeBudgetMs
        self.admissionReason = admissionReason
        self.semanticPromptFingerprint = semanticPromptFingerprint
        self.stablePrefixFingerprint = stablePrefixFingerprint
        self.narrativeOverride = narrativeOverride
        self.prompt = prompt
        self.baselineOutputPreview = baselineOutputPreview
        self.deterministicFallbackOutputPreview = deterministicFallbackOutputPreview
        self.recordsTemplatePinnedTrace = recordsTemplatePinnedTrace
    }
}

public enum BASAppleProviderObservationContextBuilder {
    public static func build(
        from input: BASAppleProviderObservationSourceInput
    ) -> BASAppleProviderObservationContext {
        let narrative = input.narrativeOverride ?? BASAppleProviderObservationNarrativeBehavior.generic.narrative(for: input.kind)
        return BASAppleProviderObservationContext(
            kind: input.kind,
            preferredProviderID: input.preferredProviderID,
            allowFallbacks: input.allowFallbacks,
            providerProfilesByID: input.providerProfilesByID,
            promptBudget: input.promptBudget,
            brainState: input.brainState,
            admissionPressureID: input.admissionPressureID,
            admissionSkipReasonID: input.admissionSkipReasonID,
            reminderSelectionNeedID: input.reminderSelectionNeedID,
            runtimeTimeBudgetMs: input.runtimeTimeBudgetMs,
            admissionReason: input.admissionReason,
            semanticPromptFingerprint: input.semanticPromptFingerprint,
            stablePrefixFingerprint: input.stablePrefixFingerprint,
            prompt: input.prompt,
            templatePinnedOutputPreview: input.baselineOutputPreview,
            admissionSkippedOutputPreview: input.baselineOutputPreview,
            deterministicFallbackOutputPreview: input.deterministicFallbackOutputPreview,
            templatePinnedDetail: narrative.templatePinnedDetail,
            admissionSkippedDetailPrefix: narrative.admissionSkippedDetailPrefix,
            deterministicFallbackBase: narrative.deterministicFallbackBase,
            cachedConsistencySource: narrative.cachedConsistencySource,
            providerConsistencySource: narrative.providerConsistencySource,
            recordsTemplatePinnedTrace: input.recordsTemplatePinnedTrace
        )
    }
}

public enum BASAppleProviderCircuitEvent: Codable, Sendable, Equatable {
    case cacheHit(providerID: String)
    case providerFailure(providerID: String)
    case providerSuccess(providerID: String, kind: String, durationMs: Double)
}

public struct BASAppleObservedProviderTrace: Codable, Sendable, Equatable {
    public var activeProviderID: String?
    public var attemptedProviderIDs: [String]
    public var consistencyCheck: BASConsistencyCheckResult?
    public var consistencyRejected: Bool
    public var observation: BASAppleProviderTraceObservation

    public init(
        activeProviderID: String?,
        attemptedProviderIDs: [String],
        consistencyCheck: BASConsistencyCheckResult? = nil,
        consistencyRejected: Bool = false,
        observation: BASAppleProviderTraceObservation
    ) {
        self.activeProviderID = activeProviderID
        self.attemptedProviderIDs = attemptedProviderIDs
        self.consistencyCheck = consistencyCheck
        self.consistencyRejected = consistencyRejected
        self.observation = observation
    }
}

public struct BASAppleObservedProviderEvent: Codable, Sendable, Equatable {
    public var telemetryObservation: BASAppleProviderTelemetryObservation?
    public var trace: BASAppleObservedProviderTrace?
    public var circuitEvents: [BASAppleProviderCircuitEvent]

    public init(
        telemetryObservation: BASAppleProviderTelemetryObservation? = nil,
        trace: BASAppleObservedProviderTrace? = nil,
        circuitEvents: [BASAppleProviderCircuitEvent] = []
    ) {
        self.telemetryObservation = telemetryObservation
        self.trace = trace
        self.circuitEvents = circuitEvents
    }
}

public enum BASAppleProviderOutcomeObserver {
    public static func lifecycleMetrics(
        promptPreparedMs: Double,
        admissionEvaluatedMs: Double? = nil,
        providerSelectionMs: Double? = nil,
        firstPresentableMs: Double
    ) -> BASRequestLifecycleMetrics {
        BASAppleObservabilityAdapter.compileLifecycleMetrics(
            promptPreparedMs: promptPreparedMs,
            admissionEvaluatedMs: admissionEvaluatedMs,
            providerSelectionMs: providerSelectionMs,
            firstPresentableMs: firstPresentableMs
        )
    }

    public static func providerDetail(
        preferredTitle: String,
        activeTitle: String,
        allowFallbacks: Bool,
        activeResolutionDetail: String? = nil
    ) -> String {
        BASAppleObservabilityAdapter.providerDetail(
            preferredTitle: preferredTitle,
            activeTitle: activeTitle,
            allowFallbacks: allowFallbacks,
            activeResolutionDetail: activeResolutionDetail
        )
    }

    public static func cachedProviderDetail(
        preferredTitle: String,
        activeTitle: String,
        allowFallbacks: Bool,
        activeResolutionDetail: String? = nil
    ) -> String {
        BASAppleObservabilityAdapter.cachedProviderDetail(
            preferredTitle: preferredTitle,
            activeTitle: activeTitle,
            allowFallbacks: allowFallbacks,
            activeResolutionDetail: activeResolutionDetail
        )
    }

    public static func deterministicFallbackDetail(
        base: String,
        suspendedProviderTitles: [String]
    ) -> String {
        BASAppleObservabilityAdapter.deterministicFallbackDetail(
            base: base,
            suspendedProviderTitles: suspendedProviderTitles
        )
    }

    public static func rejectedConsistencyDetail(
        base: String,
        result: BASConsistencyCheckResult,
        source: String
    ) -> String {
        BASAppleProviderReleaseAdapter.rejectedConsistencyDetail(
            base: base,
            result: result,
            source: source
        )
    }

    public static func traceObservation(
        from input: BASAppleProviderTraceInput
    ) -> BASAppleProviderTraceObservation {
        let compilation = BASAppleObservabilityAdapter.compileProviderTrace(from: input)
        return BASAppleProviderTraceObservation(
            detail: input.detail,
            compilation: compilation
        )
    }

    public static func telemetryObservation(
        from input: BASAppleTelemetryRecordInput
    ) -> BASAppleProviderTelemetryObservation {
        let compilation = BASAppleObservabilityAdapter.compileTelemetryRecord(from: input)
        return BASAppleProviderTelemetryObservation(
            input: input,
            compilation: compilation
        )
    }

    public static func observeEvent<Provider: Sendable, Result: Sendable>(
        _ event: BASProviderRequestEvent<Provider, Result, BASProviderReleaseAssessment>,
        context: BASAppleProviderObservationContext,
        durationMs: Double,
        promptPreparedMs: Double,
        admissionEvaluatedMs: Double? = nil,
        providerID: (Provider) -> String
    ) -> BASAppleObservedProviderEvent {
        switch event {
        case .templatePinned:
            return BASAppleObservedProviderEvent(
                telemetryObservation: telemetryObservation(
                    from: BASAppleTelemetryRecordInput(
                        kind: context.kind,
                        outcome: .templatePinned,
                        activeProviderID: nil,
                        attemptedProviderIDs: [],
                        usedFallback: false,
                        durationMs: durationMs,
                        lifecycleMetrics: lifecycleMetrics(
                            promptPreparedMs: promptPreparedMs,
                            admissionEvaluatedMs: admissionEvaluatedMs,
                            providerSelectionMs: nil,
                            firstPresentableMs: durationMs
                        ),
                        promptBudget: context.promptBudget,
                        runtimeTimeBudgetMs: context.runtimeTimeBudgetMs,
                        admissionPressureID: context.admissionPressureID,
                        admissionSkipReasonID: context.admissionSkipReasonID,
                        reminderSelectionNeedID: context.reminderSelectionNeedID
                    )
                ),
                trace: context.recordsTemplatePinnedTrace
                    ? BASAppleObservedProviderTrace(
                        activeProviderID: nil,
                        attemptedProviderIDs: [BASReferenceProviderRuntime.templateProviderID],
                        observation: traceObservation(
                            context: context,
                            activeProviderID: nil,
                            attemptedProviderIDs: [BASReferenceProviderRuntime.templateProviderID],
                            outputPreview: context.templatePinnedOutputPreview,
                            detail: context.templatePinnedDetail
                        )
                    )
                    : nil
            )
        case .admissionSkipped:
            return BASAppleObservedProviderEvent(
                telemetryObservation: telemetryObservation(
                    from: BASAppleTelemetryRecordInput(
                        kind: context.kind,
                        outcome: .admissionSkipped,
                        activeProviderID: nil,
                        attemptedProviderIDs: [],
                        usedFallback: false,
                        durationMs: durationMs,
                        lifecycleMetrics: lifecycleMetrics(
                            promptPreparedMs: promptPreparedMs,
                            admissionEvaluatedMs: admissionEvaluatedMs,
                            providerSelectionMs: nil,
                            firstPresentableMs: durationMs
                        ),
                        promptBudget: context.promptBudget,
                        runtimeTimeBudgetMs: context.runtimeTimeBudgetMs,
                        admissionPressureID: context.admissionPressureID,
                        admissionSkipReasonID: context.admissionSkipReasonID,
                        reminderSelectionNeedID: context.reminderSelectionNeedID
                    )
                ),
                trace: BASAppleObservedProviderTrace(
                    activeProviderID: nil,
                    attemptedProviderIDs: [],
                    observation: traceObservation(
                        context: context,
                        activeProviderID: nil,
                        attemptedProviderIDs: [],
                        outputPreview: context.admissionSkippedOutputPreview,
                        detail: "\(context.admissionSkippedDetailPrefix) \(context.admissionReason ?? "")"
                    )
                )
            )
        case .cachedRejected(let attempt):
            let activeProviderID = providerID(attempt.provider)
            guard let consistencyCheck = attempt.assessment.consistencyCheck else {
                return BASAppleObservedProviderEvent()
            }

            return BASAppleObservedProviderEvent(
                trace: BASAppleObservedProviderTrace(
                    activeProviderID: activeProviderID,
                    attemptedProviderIDs: attempt.attemptedProviderIDs,
                    consistencyCheck: consistencyCheck,
                    consistencyRejected: true,
                    observation: traceObservation(
                        context: context,
                        activeProviderID: activeProviderID,
                        attemptedProviderIDs: attempt.attemptedProviderIDs,
                        consistencyCheck: consistencyCheck,
                        consistencyRejected: true,
                        outputPreview: attempt.assessment.outputPreview,
                        detail: rejectedConsistencyDetail(
                            base: cachedProviderDetail(
                                context: context,
                                activeProviderID: activeProviderID
                            ),
                            result: consistencyCheck,
                            source: context.cachedConsistencySource
                        )
                    )
                )
            )
        case .cacheHit(let attempt):
            let activeProviderID = providerID(attempt.provider)
            return BASAppleObservedProviderEvent(
                telemetryObservation: telemetryObservation(
                    from: BASAppleTelemetryRecordInput(
                        kind: context.kind,
                        outcome: .cacheHit,
                        activeProviderID: activeProviderID,
                        attemptedProviderIDs: attempt.attemptedProviderIDs,
                        usedFallback: activeProviderID != context.preferredProviderID,
                        durationMs: durationMs,
                        lifecycleMetrics: lifecycleMetrics(
                            promptPreparedMs: promptPreparedMs,
                            admissionEvaluatedMs: admissionEvaluatedMs,
                            providerSelectionMs: Double(attempt.planSummary.providerSelectionDurationMs),
                            firstPresentableMs: durationMs
                        ),
                        promptBudget: context.promptBudget,
                        runtimeTimeBudgetMs: context.runtimeTimeBudgetMs,
                        admissionPressureID: context.admissionPressureID,
                        admissionSkipReasonID: context.admissionSkipReasonID,
                        reminderSelectionNeedID: context.reminderSelectionNeedID,
                        activeBackendID: backendID(for: activeProviderID, context: context)
                    )
                ),
                trace: BASAppleObservedProviderTrace(
                    activeProviderID: activeProviderID,
                    attemptedProviderIDs: attempt.attemptedProviderIDs,
                    consistencyCheck: attempt.assessment.consistencyCheck,
                    observation: traceObservation(
                        context: context,
                        activeProviderID: activeProviderID,
                        attemptedProviderIDs: attempt.attemptedProviderIDs,
                        consistencyCheck: attempt.assessment.consistencyCheck,
                        outputPreview: attempt.assessment.outputPreview,
                        detail: cachedProviderDetail(
                            context: context,
                            activeProviderID: activeProviderID
                        )
                    )
                ),
                circuitEvents: [.cacheHit(providerID: activeProviderID)]
            )
        case .providerRejected(let attempt):
            let activeProviderID = providerID(attempt.provider)
            guard let consistencyCheck = attempt.assessment.consistencyCheck else {
                return BASAppleObservedProviderEvent(
                    circuitEvents: [.providerFailure(providerID: activeProviderID)]
                )
            }

            return BASAppleObservedProviderEvent(
                trace: BASAppleObservedProviderTrace(
                    activeProviderID: activeProviderID,
                    attemptedProviderIDs: attempt.attemptedProviderIDs,
                    consistencyCheck: consistencyCheck,
                    consistencyRejected: true,
                    observation: traceObservation(
                        context: context,
                        activeProviderID: activeProviderID,
                        attemptedProviderIDs: attempt.attemptedProviderIDs,
                        consistencyCheck: consistencyCheck,
                        consistencyRejected: true,
                        outputPreview: attempt.assessment.outputPreview,
                        detail: rejectedConsistencyDetail(
                            base: providerDetail(
                                context: context,
                                activeProviderID: activeProviderID
                            ),
                            result: consistencyCheck,
                            source: context.providerConsistencySource
                        )
                    )
                ),
                circuitEvents: [.providerFailure(providerID: activeProviderID)]
            )
        case .providerSuccess(let attempt):
            let activeProviderID = providerID(attempt.provider)
            return BASAppleObservedProviderEvent(
                telemetryObservation: telemetryObservation(
                    from: BASAppleTelemetryRecordInput(
                        kind: context.kind,
                        outcome: .providerSuccess,
                        activeProviderID: activeProviderID,
                        attemptedProviderIDs: attempt.attemptedProviderIDs,
                        usedFallback: activeProviderID != context.preferredProviderID,
                        durationMs: durationMs,
                        lifecycleMetrics: lifecycleMetrics(
                            promptPreparedMs: promptPreparedMs,
                            admissionEvaluatedMs: admissionEvaluatedMs,
                            providerSelectionMs: Double(attempt.planSummary.providerSelectionDurationMs),
                            firstPresentableMs: durationMs
                        ),
                        promptBudget: context.promptBudget,
                        runtimeTimeBudgetMs: context.runtimeTimeBudgetMs,
                        admissionPressureID: context.admissionPressureID,
                        admissionSkipReasonID: context.admissionSkipReasonID,
                        reminderSelectionNeedID: context.reminderSelectionNeedID,
                        activeBackendID: backendID(for: activeProviderID, context: context)
                    )
                ),
                trace: BASAppleObservedProviderTrace(
                    activeProviderID: activeProviderID,
                    attemptedProviderIDs: attempt.attemptedProviderIDs,
                    consistencyCheck: attempt.assessment.consistencyCheck,
                    observation: traceObservation(
                        context: context,
                        activeProviderID: activeProviderID,
                        attemptedProviderIDs: attempt.attemptedProviderIDs,
                        consistencyCheck: attempt.assessment.consistencyCheck,
                        outputPreview: attempt.assessment.outputPreview,
                        detail: providerDetail(
                            context: context,
                            activeProviderID: activeProviderID
                        )
                    )
                ),
                circuitEvents: [
                    .providerSuccess(
                        providerID: activeProviderID,
                        kind: context.kind,
                        durationMs: durationMs
                    )
                ]
            )
        case .providerMiss(let miss):
            return BASAppleObservedProviderEvent(
                circuitEvents: [.providerFailure(providerID: providerID(miss.provider))]
            )
        case .noResult(let noResult):
            let suspendedProviderTitles = noResult.planSummary.suspendedProviderIDs.compactMap {
                context.providerProfilesByID[$0]?.title
            }
            return BASAppleObservedProviderEvent(
                telemetryObservation: telemetryObservation(
                    from: BASAppleTelemetryRecordInput(
                        kind: context.kind,
                        outcome: .deterministicFallback,
                        activeProviderID: nil,
                        attemptedProviderIDs: noResult.attemptedProviderIDs,
                        usedFallback: false,
                        durationMs: durationMs,
                        lifecycleMetrics: lifecycleMetrics(
                            promptPreparedMs: promptPreparedMs,
                            admissionEvaluatedMs: admissionEvaluatedMs,
                            providerSelectionMs: Double(noResult.planSummary.providerSelectionDurationMs),
                            firstPresentableMs: durationMs
                        ),
                        promptBudget: context.promptBudget,
                        runtimeTimeBudgetMs: context.runtimeTimeBudgetMs,
                        admissionPressureID: context.admissionPressureID,
                        admissionSkipReasonID: context.admissionSkipReasonID,
                        reminderSelectionNeedID: context.reminderSelectionNeedID
                    )
                ),
                trace: BASAppleObservedProviderTrace(
                    activeProviderID: nil,
                    attemptedProviderIDs: noResult.attemptedProviderIDs,
                    observation: traceObservation(
                        context: context,
                        activeProviderID: nil,
                        attemptedProviderIDs: noResult.attemptedProviderIDs,
                        outputPreview: context.deterministicFallbackOutputPreview,
                        detail: deterministicFallbackDetail(
                            base: context.deterministicFallbackBase,
                            suspendedProviderTitles: suspendedProviderTitles
                        )
                    )
                )
            )
        }
    }

    private static func traceObservation(
        context: BASAppleProviderObservationContext,
        activeProviderID: String?,
        attemptedProviderIDs: [String],
        consistencyCheck: BASConsistencyCheckResult? = nil,
        consistencyRejected: Bool = false,
        outputPreview: String,
        detail: String
    ) -> BASAppleProviderTraceObservation {
        traceObservation(
            from: BASAppleProviderTraceInput(
                testingOverridePresent: false,
                kind: context.kind,
                preferredProviderID: context.preferredProviderID,
                activeProviderID: activeProviderID,
                attemptedProviderIDs: attemptedProviderIDs,
                allowFallbacks: context.allowFallbacks,
                prompt: context.prompt,
                outputPreview: outputPreview,
                detail: detail,
                semanticPromptFingerprint: context.semanticPromptFingerprint,
                stablePrefixFingerprint: context.stablePrefixFingerprint,
                promptBudget: context.promptBudget,
                brainState: context.brainState,
                consistencyRejected: consistencyRejected,
                consistencyViolationKinds: consistencyCheck?.violations.map(\.kind.rawValue) ?? []
            )
        )
    }

    private static func providerDetail(
        context: BASAppleProviderObservationContext,
        activeProviderID: String
    ) -> String {
        let preferredProfile = providerProfile(
            for: context.preferredProviderID,
            context: context
        )
        let activeProfile = providerProfile(for: activeProviderID, context: context)
        return providerDetail(
            preferredTitle: preferredProfile.title,
            activeTitle: activeProfile.title,
            allowFallbacks: context.allowFallbacks,
            activeResolutionDetail: activeProfile.activeResolutionDetail
        )
    }

    private static func cachedProviderDetail(
        context: BASAppleProviderObservationContext,
        activeProviderID: String
    ) -> String {
        let preferredProfile = providerProfile(
            for: context.preferredProviderID,
            context: context
        )
        let activeProfile = providerProfile(for: activeProviderID, context: context)
        return cachedProviderDetail(
            preferredTitle: preferredProfile.title,
            activeTitle: activeProfile.title,
            allowFallbacks: context.allowFallbacks,
            activeResolutionDetail: activeProfile.activeResolutionDetail
        )
    }

    private static func providerProfile(
        for providerID: String,
        context: BASAppleProviderObservationContext
    ) -> BASAppleProviderProfile {
        context.providerProfilesByID[providerID] ?? BASAppleProviderProfile(
            providerID: providerID,
            title: providerID
        )
    }

    private static func backendID(
        for activeProviderID: String,
        context: BASAppleProviderObservationContext
    ) -> String? {
        providerProfile(for: activeProviderID, context: context).activeBackendID
    }
}
