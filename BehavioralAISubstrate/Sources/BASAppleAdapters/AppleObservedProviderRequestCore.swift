import Foundation
import BASOrchestration
import BASRuntimeCore

public enum BASAppleObservedProviderRequestExecutor {
    public static func execute<
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
        runtimeInput: BASAppleProviderRequestRuntimeInput<Provider>,
        observationContext: BASAppleHostProviderObservationContext<
            Kind,
            FrontstageState,
            ContextState,
            NeuralState,
            BrainState,
            RuntimeStrategy,
            PromptBudget,
            AdmissionDecision
        >,
        requestStart: ContinuousClock.Instant,
        clock: ContinuousClock,
        promptPreparedMs: Double,
        admissionEvaluatedMs: Double? = nil,
        providerID: @escaping (Provider) -> String,
        providerForID: @escaping (String) -> Provider?,
        isAvailable: @escaping (Provider) -> Bool,
        loadCachedResult: @escaping (Provider) async -> Result?,
        assessCachedResult: @escaping (Result) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment>,
        quarantineCachedResult: @escaping (Provider) async -> Void,
        invokeProvider: @escaping (Provider) async -> Result?,
        assessProviderResult: @escaping (Result) -> BASProviderExecutionVerdict<BASProviderReleaseAssessment>,
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
    ) async -> BASProviderRequestOutcome<Result, BASProviderReleaseAssessment> {
        await BASAppleProviderRequestRuntimeExecutor.executeObserved(
            input: runtimeInput,
            providerID: providerID,
            providerForID: providerForID,
            isAvailable: isAvailable,
            loadCachedResult: loadCachedResult,
            assessCachedResult: assessCachedResult,
            quarantineCachedResult: quarantineCachedResult,
            invokeProvider: invokeProvider,
            assessProviderResult: assessProviderResult,
            observe: { event in
                await BASAppleHostProviderObservationExecutor.handleEvent(
                    event,
                    context: observationContext,
                    durationMs: elapsedMilliseconds(
                        since: requestStart,
                        clock: clock
                    ),
                    promptPreparedMs: promptPreparedMs,
                    admissionEvaluatedMs: admissionEvaluatedMs,
                    providerID: providerID,
                    storeResolvedResult: storeResolvedResult,
                    applyCircuitEvent: applyCircuitEvent,
                    recordTelemetry: recordTelemetry,
                    recordTrace: recordTrace
                )
            }
        )
    }

    private static func elapsedMilliseconds(
        since start: ContinuousClock.Instant,
        clock: ContinuousClock
    ) -> Double {
        let duration = start.duration(to: clock.now)
        let components = duration.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return (seconds + attoseconds) * 1_000
    }
}
