import Foundation

public enum BASAppleAppLifecycleOrchestrationExecutor {
    public static func consumeEntriesIfNeeded<Envelope, PendingRequest>(
        consumeHandoff: () -> Envelope?,
        handleHandoff: (Envelope) -> Void,
        consumePendingRequest: () -> PendingRequest?,
        handlePendingRequest: (PendingRequest) -> Void
    ) {
        BASAppleLifecycleEntrySourceExecutor.execute(
            consumeHandoff: consumeHandoff,
            handleHandoff: handleHandoff,
            consumePendingRequest: consumePendingRequest,
            handlePendingRequest: handlePendingRequest
        )
    }

    public static func execute<Envelope, PendingRequest>(
        phase: BASAppleLifecycleBootstrapPhase,
        behavior: BASAppleLifecycleBootstrapBehavior = .generic,
        refreshMemoryProjection: () -> Void,
        refreshCurrentBrain: (String) -> Void,
        presentPendingReflection: () -> Void,
        consumeHandoff: () -> Envelope?,
        handleHandoff: (Envelope) -> Void,
        consumePendingRequest: () -> PendingRequest?,
        handlePendingRequest: (PendingRequest) -> Void,
        restoreActiveWorkspace: () -> Void,
        refreshPredictedIntervention: () -> Void,
        syncWidgetSnapshot: () -> Void = {}
    ) {
        BASAppleLifecycleBootstrapExecutor.execute(
            phase: phase,
            behavior: behavior,
            refreshMemoryProjection: refreshMemoryProjection,
            refreshCurrentBrain: refreshCurrentBrain,
            presentPendingReflection: presentPendingReflection,
            consumePendingLaunchRequest: {
                consumeEntriesIfNeeded(
                    consumeHandoff: consumeHandoff,
                    handleHandoff: handleHandoff,
                    consumePendingRequest: consumePendingRequest,
                    handlePendingRequest: handlePendingRequest
                )
            },
            restoreActiveWorkspace: restoreActiveWorkspace,
            refreshPredictedIntervention: refreshPredictedIntervention,
            syncWidgetSnapshot: syncWidgetSnapshot
        )
    }
}
