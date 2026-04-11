import Foundation
import BASRuntimeCore

public struct BASAppleProviderRequestRuntimeInput<Provider: Sendable>: Sendable {
    public var task: BASAdaptiveTraceKind
    public var preferredProviderID: String
    public var allowFallbacks: Bool
    public var suspendedProviderIDs: Set<String>
    public var strategy: BASAdaptiveTaskStrategy?
    public var descriptors: [BASProviderDescriptor]
    public var testingOverrideProvider: Provider?
    public var admissionAllowed: Bool

    public init(
        task: BASAdaptiveTraceKind,
        preferredProviderID: String,
        allowFallbacks: Bool,
        suspendedProviderIDs: Set<String> = [],
        strategy: BASAdaptiveTaskStrategy? = nil,
        descriptors: [BASProviderDescriptor],
        testingOverrideProvider: Provider? = nil,
        admissionAllowed: Bool
    ) {
        self.task = task
        self.preferredProviderID = preferredProviderID
        self.allowFallbacks = allowFallbacks
        self.suspendedProviderIDs = suspendedProviderIDs
        self.strategy = strategy
        self.descriptors = descriptors
        self.testingOverrideProvider = testingOverrideProvider
        self.admissionAllowed = admissionAllowed
    }
}

public enum BASAppleProviderRequestRuntimeExecutor {
    public static func executeObserved<
        Provider: Sendable,
        Result: Sendable,
        Assessment: Sendable
    >(
        input: BASAppleProviderRequestRuntimeInput<Provider>,
        providerID: (Provider) -> String,
        providerForID: (String) -> Provider?,
        isAvailable: (Provider) -> Bool,
        loadCachedResult: (Provider) async -> Result?,
        assessCachedResult: (Result) -> BASProviderExecutionVerdict<Assessment>,
        quarantineCachedResult: (Provider) async -> Void,
        invokeProvider: (Provider) async -> Result?,
        assessProviderResult: (Result) -> BASProviderExecutionVerdict<Assessment>,
        observe: ((BASProviderRequestEvent<Provider, Result, Assessment>) async -> Void)? = nil
    ) async -> BASProviderRequestOutcome<Result, Assessment> {
        await BASProviderRequestRunner.executeObserved(
            task: input.task,
            preferredProviderID: input.preferredProviderID,
            allowFallbacks: input.allowFallbacks,
            deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
            preferenceOrderings: BASReferenceProviderRuntime.preferenceOrderings,
            suspendedProviderIDs: input.suspendedProviderIDs,
            strategy: input.strategy,
            descriptors: input.descriptors,
            testingOverrideProvider: input.testingOverrideProvider,
            providerID: providerID,
            providerForID: providerForID,
            isAvailable: isAvailable,
            admissionAllowed: input.admissionAllowed,
            loadCachedResult: loadCachedResult,
            assessCachedResult: assessCachedResult,
            quarantineCachedResult: quarantineCachedResult,
            invokeProvider: invokeProvider,
            assessProviderResult: assessProviderResult,
            observe: observe
        )
    }
}
