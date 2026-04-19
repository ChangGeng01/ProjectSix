import Foundation

public struct BASExecutableProviderResolutionResult<Provider> {
    public var providers: [Provider]
    public var usedTestingOverride: Bool
    public var resolvedProviderIDs: [String]

    public init(
        providers: [Provider],
        usedTestingOverride: Bool,
        resolvedProviderIDs: [String]
    ) {
        self.providers = providers
        self.usedTestingOverride = usedTestingOverride
        self.resolvedProviderIDs = resolvedProviderIDs
    }
}

public struct BASExecutableProviderPlanningResult<Provider> {
    public var plan: BASProviderSelectionPlan
    public var resolution: BASExecutableProviderResolutionResult<Provider>

    public init(
        plan: BASProviderSelectionPlan,
        resolution: BASExecutableProviderResolutionResult<Provider>
    ) {
        self.plan = plan
        self.resolution = resolution
    }

    public var providers: [Provider] { resolution.providers }
    public var resolvedProviderIDs: [String] { resolution.resolvedProviderIDs }
    public var usedTestingOverride: Bool { resolution.usedTestingOverride }
}

public struct BASProviderRequestPlanSummary: Codable, Equatable, Sendable {
    public var task: BASAdaptiveTraceKind
    public var preferredProviderID: String
    public var orderedProviderIDs: [String]
    public var resolvedProviderIDs: [String]
    public var compatibleProviderIDs: [String]
    public var incompatibleProviderIDs: [String]
    public var suspendedProviderIDs: [String]
    public var appliedRoutingPolicyVersion: String?
    public var appliedRoutingRegistryVersion: String?
    public var usedTestingOverride: Bool
    public var providerSelectionDurationMs: Int

    public init(
        task: BASAdaptiveTraceKind,
        preferredProviderID: String,
        orderedProviderIDs: [String],
        resolvedProviderIDs: [String],
        compatibleProviderIDs: [String],
        incompatibleProviderIDs: [String],
        suspendedProviderIDs: [String],
        appliedRoutingPolicyVersion: String? = nil,
        appliedRoutingRegistryVersion: String? = nil,
        usedTestingOverride: Bool,
        providerSelectionDurationMs: Int
    ) {
        self.task = task
        self.preferredProviderID = preferredProviderID
        self.orderedProviderIDs = orderedProviderIDs
        self.resolvedProviderIDs = resolvedProviderIDs
        self.compatibleProviderIDs = compatibleProviderIDs
        self.incompatibleProviderIDs = incompatibleProviderIDs
        self.suspendedProviderIDs = suspendedProviderIDs
        self.appliedRoutingPolicyVersion = appliedRoutingPolicyVersion
        self.appliedRoutingRegistryVersion = appliedRoutingRegistryVersion
        self.usedTestingOverride = usedTestingOverride
        self.providerSelectionDurationMs = providerSelectionDurationMs
    }
}

public struct BASProviderRequestResolution<Result: Sendable, Assessment: Sendable>: Sendable {
    public var planSummary: BASProviderRequestPlanSummary
    public var execution: BASProviderExecutionResolution<Result, Assessment>

    public init(
        planSummary: BASProviderRequestPlanSummary,
        execution: BASProviderExecutionResolution<Result, Assessment>
    ) {
        self.planSummary = planSummary
        self.execution = execution
    }
}

public struct BASProviderRequestNoResult: Codable, Equatable, Sendable {
    public var planSummary: BASProviderRequestPlanSummary
    public var attemptedProviderIDs: [String]

    public init(
        planSummary: BASProviderRequestPlanSummary,
        attemptedProviderIDs: [String]
    ) {
        self.planSummary = planSummary
        self.attemptedProviderIDs = attemptedProviderIDs
    }
}

public struct BASProviderRequestAttemptEvent<Provider: Sendable, Result: Sendable, Assessment: Sendable>: Sendable {
    public var planSummary: BASProviderRequestPlanSummary
    public var provider: Provider
    public var result: Result
    public var assessment: Assessment
    public var attemptedProviderIDs: [String]

    public init(
        planSummary: BASProviderRequestPlanSummary,
        provider: Provider,
        result: Result,
        assessment: Assessment,
        attemptedProviderIDs: [String]
    ) {
        self.planSummary = planSummary
        self.provider = provider
        self.result = result
        self.assessment = assessment
        self.attemptedProviderIDs = attemptedProviderIDs
    }
}

public struct BASProviderRequestMissEvent<Provider: Sendable>: Sendable {
    public var planSummary: BASProviderRequestPlanSummary
    public var provider: Provider
    public var attemptedProviderIDs: [String]

    public init(
        planSummary: BASProviderRequestPlanSummary,
        provider: Provider,
        attemptedProviderIDs: [String]
    ) {
        self.planSummary = planSummary
        self.provider = provider
        self.attemptedProviderIDs = attemptedProviderIDs
    }
}

public enum BASProviderRequestOutcome<Result: Sendable, Assessment: Sendable>: Sendable {
    case templatePinned
    case admissionSkipped
    case resolved(BASProviderRequestResolution<Result, Assessment>)
    case noResult(BASProviderRequestNoResult)
}

public enum BASProviderRequestEvent<Provider: Sendable, Result: Sendable, Assessment: Sendable>: Sendable {
    case templatePinned
    case admissionSkipped
    case cachedRejected(BASProviderRequestAttemptEvent<Provider, Result, Assessment>)
    case cacheHit(BASProviderRequestAttemptEvent<Provider, Result, Assessment>)
    case providerRejected(BASProviderRequestAttemptEvent<Provider, Result, Assessment>)
    case providerSuccess(BASProviderRequestAttemptEvent<Provider, Result, Assessment>)
    case providerMiss(BASProviderRequestMissEvent<Provider>)
    case noResult(BASProviderRequestNoResult)
}

public enum BASProviderExecutionVerdict<Assessment: Sendable>: Sendable {
    case allow(Assessment)
    case reject(Assessment)

    public var assessment: Assessment {
        switch self {
        case .allow(let assessment), .reject(let assessment):
            return assessment
        }
    }

    public var isAllowed: Bool {
        switch self {
        case .allow:
            true
        case .reject:
            false
        }
    }
}

public enum BASProviderExecutionResolutionSource: String, Codable, Equatable, Sendable {
    case cacheHit = "cache_hit"
    case providerSuccess = "provider_success"
}

public struct BASProviderExecutionResolution<Result: Sendable, Assessment: Sendable>: Sendable {
    public var source: BASProviderExecutionResolutionSource
    public var providerID: String
    public var attemptedProviderIDs: [String]
    public var result: Result
    public var assessment: Assessment

    public init(
        source: BASProviderExecutionResolutionSource,
        providerID: String,
        attemptedProviderIDs: [String],
        result: Result,
        assessment: Assessment
    ) {
        self.source = source
        self.providerID = providerID
        self.attemptedProviderIDs = attemptedProviderIDs
        self.result = result
        self.assessment = assessment
    }
}

public enum BASProviderExecutionOutcome<Result: Sendable, Assessment: Sendable>: Sendable {
    case resolved(BASProviderExecutionResolution<Result, Assessment>)
    case noResult(attemptedProviderIDs: [String])
}

public enum BASExecutableProviderResolver {
    public static func resolve<Provider>(
        orderedProviderIDs: [String],
        testingOverrideProvider: Provider? = nil,
        providerID: (Provider) -> String,
        providerForID: (String) -> Provider?,
        isAvailable: (Provider) -> Bool
    ) -> BASExecutableProviderResolutionResult<Provider> {
        if let testingOverrideProvider {
            return BASExecutableProviderResolutionResult(
                providers: [testingOverrideProvider],
                usedTestingOverride: true,
                resolvedProviderIDs: [providerID(testingOverrideProvider)]
            )
        }

        var seen = Set<String>()
        var providers: [Provider] = []
        var resolvedIDs: [String] = []

        for candidateID in orderedProviderIDs {
            guard seen.insert(candidateID).inserted,
                  let provider = providerForID(candidateID),
                  isAvailable(provider)
            else {
                continue
            }

            providers.append(provider)
            resolvedIDs.append(candidateID)
        }

        return BASExecutableProviderResolutionResult(
            providers: providers,
            usedTestingOverride: false,
            resolvedProviderIDs: resolvedIDs
        )
    }
}

public enum BASExecutableProviderPlanner {
    public static func resolve<Provider>(
        task: BASAdaptiveTraceKind,
        preferredProviderID: String,
        allowFallbacks: Bool,
        deterministicProviderID: String,
        preferenceOrderings: [BASProviderPreferenceOrdering],
        appliedRoutingPolicyVersion: String? = nil,
        appliedRoutingRegistryVersion: String? = nil,
        suspendedProviderIDs: Set<String> = [],
        strategy: BASAdaptiveTaskStrategy? = nil,
        descriptors: [BASProviderDescriptor],
        testingOverrideProvider: Provider? = nil,
        providerID: (Provider) -> String,
        providerForID: (String) -> Provider?,
        isAvailable: (Provider) -> Bool
    ) -> BASExecutableProviderPlanningResult<Provider> {
        let plan = BASProviderRouteResolver.resolve(
            task: task,
            preferredProviderID: preferredProviderID,
            allowFallbacks: allowFallbacks,
            deterministicProviderID: deterministicProviderID,
            preferenceOrderings: preferenceOrderings,
            appliedRoutingPolicyVersion: appliedRoutingPolicyVersion,
            appliedRoutingRegistryVersion: appliedRoutingRegistryVersion,
            suspendedProviderIDs: suspendedProviderIDs,
            strategy: strategy,
            descriptors: descriptors
        )
        let resolution = BASExecutableProviderResolver.resolve(
            orderedProviderIDs: plan.orderedProviderIDs,
            testingOverrideProvider: testingOverrideProvider,
            providerID: providerID,
            providerForID: providerForID,
            isAvailable: isAvailable
        )

        return BASExecutableProviderPlanningResult(
            plan: plan,
            resolution: resolution
        )
    }
}

public enum BASProviderAttemptExecutor {
    public static func execute<Provider, Result: Sendable, Assessment: Sendable>(
        providers: [Provider],
        providerID: (Provider) -> String,
        loadCachedResult: (Provider) async -> Result?,
        assessCachedResult: (Result) -> BASProviderExecutionVerdict<Assessment>,
        quarantineCachedResult: (Provider) async -> Void,
        invokeProvider: (Provider) async -> Result?,
        assessProviderResult: (Result) -> BASProviderExecutionVerdict<Assessment>,
        onCachedRejected: ((Provider, Result, Assessment, [String]) async -> Void)? = nil,
        onCacheHit: ((Provider, Result, Assessment, [String]) async -> Void)? = nil,
        onProviderRejected: ((Provider, Result, Assessment, [String]) async -> Void)? = nil,
        onProviderSuccess: ((Provider, Result, Assessment, [String]) async -> Void)? = nil,
        onProviderMiss: ((Provider, [String]) async -> Void)? = nil
    ) async -> BASProviderExecutionOutcome<Result, Assessment> {
        var attemptedProviderIDs: [String] = []

        for provider in providers {
            attemptedProviderIDs.append(providerID(provider))

            if let cached = await loadCachedResult(provider) {
                let verdict = assessCachedResult(cached)
                switch verdict {
                case .allow(let assessment):
                    await onCacheHit?(provider, cached, assessment, attemptedProviderIDs)
                    return .resolved(
                        BASProviderExecutionResolution(
                            source: .cacheHit,
                            providerID: attemptedProviderIDs.last ?? providerID(provider),
                            attemptedProviderIDs: attemptedProviderIDs,
                            result: cached,
                            assessment: assessment
                        )
                    )
                case .reject(let assessment):
                    await quarantineCachedResult(provider)
                    await onCachedRejected?(provider, cached, assessment, attemptedProviderIDs)
                    continue
                }
            }

            guard let result = await invokeProvider(provider) else {
                await onProviderMiss?(provider, attemptedProviderIDs)
                continue
            }

            let verdict = assessProviderResult(result)
            switch verdict {
            case .allow(let assessment):
                await onProviderSuccess?(provider, result, assessment, attemptedProviderIDs)
                return .resolved(
                    BASProviderExecutionResolution(
                        source: .providerSuccess,
                        providerID: attemptedProviderIDs.last ?? providerID(provider),
                        attemptedProviderIDs: attemptedProviderIDs,
                        result: result,
                        assessment: assessment
                    )
                )
            case .reject(let assessment):
                await onProviderRejected?(provider, result, assessment, attemptedProviderIDs)
            }
        }

        return .noResult(attemptedProviderIDs: attemptedProviderIDs)
    }
}

public enum BASProviderRequestRunner {
    public static func executeObserved<Provider: Sendable, Result: Sendable, Assessment: Sendable>(
        task: BASAdaptiveTraceKind,
        preferredProviderID: String,
        allowFallbacks: Bool,
        deterministicProviderID: String,
        preferenceOrderings: [BASProviderPreferenceOrdering],
        appliedRoutingPolicyVersion: String? = nil,
        appliedRoutingRegistryVersion: String? = nil,
        suspendedProviderIDs: Set<String> = [],
        strategy: BASAdaptiveTaskStrategy? = nil,
        descriptors: [BASProviderDescriptor],
        testingOverrideProvider: Provider? = nil,
        providerID: (Provider) -> String,
        providerForID: (String) -> Provider?,
        isAvailable: (Provider) -> Bool,
        admissionAllowed: Bool,
        loadCachedResult: (Provider) async -> Result?,
        assessCachedResult: (Result) -> BASProviderExecutionVerdict<Assessment>,
        quarantineCachedResult: (Provider) async -> Void,
        invokeProvider: (Provider) async -> Result?,
        assessProviderResult: (Result) -> BASProviderExecutionVerdict<Assessment>,
        observe: ((BASProviderRequestEvent<Provider, Result, Assessment>) async -> Void)? = nil
    ) async -> BASProviderRequestOutcome<Result, Assessment> {
        guard preferredProviderID != deterministicProviderID else {
            await observe?(.templatePinned)
            return .templatePinned
        }

        guard admissionAllowed else {
            await observe?(.admissionSkipped)
            return .admissionSkipped
        }

        let outcome = await execute(
            task: task,
            preferredProviderID: preferredProviderID,
            allowFallbacks: allowFallbacks,
            deterministicProviderID: deterministicProviderID,
            preferenceOrderings: preferenceOrderings,
            appliedRoutingPolicyVersion: appliedRoutingPolicyVersion,
            appliedRoutingRegistryVersion: appliedRoutingRegistryVersion,
            suspendedProviderIDs: suspendedProviderIDs,
            strategy: strategy,
            descriptors: descriptors,
            testingOverrideProvider: testingOverrideProvider,
            providerID: providerID,
            providerForID: providerForID,
            isAvailable: isAvailable,
            admissionAllowed: true,
            loadCachedResult: loadCachedResult,
            assessCachedResult: assessCachedResult,
            quarantineCachedResult: quarantineCachedResult,
            invokeProvider: invokeProvider,
            assessProviderResult: assessProviderResult,
            onCachedRejected: { planSummary, provider, result, assessment, attemptedProviderIDs in
                await observe?(
                    .cachedRejected(
                        BASProviderRequestAttemptEvent(
                            planSummary: planSummary,
                            provider: provider,
                            result: result,
                            assessment: assessment,
                            attemptedProviderIDs: attemptedProviderIDs
                        )
                    )
                )
            },
            onCacheHit: { planSummary, provider, result, assessment, attemptedProviderIDs in
                await observe?(
                    .cacheHit(
                        BASProviderRequestAttemptEvent(
                            planSummary: planSummary,
                            provider: provider,
                            result: result,
                            assessment: assessment,
                            attemptedProviderIDs: attemptedProviderIDs
                        )
                    )
                )
            },
            onProviderRejected: { planSummary, provider, result, assessment, attemptedProviderIDs in
                await observe?(
                    .providerRejected(
                        BASProviderRequestAttemptEvent(
                            planSummary: planSummary,
                            provider: provider,
                            result: result,
                            assessment: assessment,
                            attemptedProviderIDs: attemptedProviderIDs
                        )
                    )
                )
            },
            onProviderSuccess: { planSummary, provider, result, assessment, attemptedProviderIDs in
                await observe?(
                    .providerSuccess(
                        BASProviderRequestAttemptEvent(
                            planSummary: planSummary,
                            provider: provider,
                            result: result,
                            assessment: assessment,
                            attemptedProviderIDs: attemptedProviderIDs
                        )
                    )
                )
            },
            onProviderMiss: { planSummary, provider, attemptedProviderIDs in
                await observe?(
                    .providerMiss(
                        BASProviderRequestMissEvent(
                            planSummary: planSummary,
                            provider: provider,
                            attemptedProviderIDs: attemptedProviderIDs
                        )
                    )
                )
            }
        )

        if case .noResult(let noResult) = outcome {
            await observe?(.noResult(noResult))
        }

        return outcome
    }

    public static func execute<Provider, Result: Sendable, Assessment: Sendable>(
        task: BASAdaptiveTraceKind,
        preferredProviderID: String,
        allowFallbacks: Bool,
        deterministicProviderID: String,
        preferenceOrderings: [BASProviderPreferenceOrdering],
        appliedRoutingPolicyVersion: String? = nil,
        appliedRoutingRegistryVersion: String? = nil,
        suspendedProviderIDs: Set<String> = [],
        strategy: BASAdaptiveTaskStrategy? = nil,
        descriptors: [BASProviderDescriptor],
        testingOverrideProvider: Provider? = nil,
        providerID: (Provider) -> String,
        providerForID: (String) -> Provider?,
        isAvailable: (Provider) -> Bool,
        admissionAllowed: Bool,
        loadCachedResult: (Provider) async -> Result?,
        assessCachedResult: (Result) -> BASProviderExecutionVerdict<Assessment>,
        quarantineCachedResult: (Provider) async -> Void,
        invokeProvider: (Provider) async -> Result?,
        assessProviderResult: (Result) -> BASProviderExecutionVerdict<Assessment>,
        onCachedRejected: ((BASProviderRequestPlanSummary, Provider, Result, Assessment, [String]) async -> Void)? = nil,
        onCacheHit: ((BASProviderRequestPlanSummary, Provider, Result, Assessment, [String]) async -> Void)? = nil,
        onProviderRejected: ((BASProviderRequestPlanSummary, Provider, Result, Assessment, [String]) async -> Void)? = nil,
        onProviderSuccess: ((BASProviderRequestPlanSummary, Provider, Result, Assessment, [String]) async -> Void)? = nil,
        onProviderMiss: ((BASProviderRequestPlanSummary, Provider, [String]) async -> Void)? = nil
    ) async -> BASProviderRequestOutcome<Result, Assessment> {
        guard preferredProviderID != deterministicProviderID else {
            return .templatePinned
        }

        guard admissionAllowed else {
            return .admissionSkipped
        }

        let clock = ContinuousClock()
        let selectionStart = clock.now
        let planning = BASExecutableProviderPlanner.resolve(
            task: task,
            preferredProviderID: preferredProviderID,
            allowFallbacks: allowFallbacks,
            deterministicProviderID: deterministicProviderID,
            preferenceOrderings: preferenceOrderings,
            appliedRoutingPolicyVersion: appliedRoutingPolicyVersion,
            appliedRoutingRegistryVersion: appliedRoutingRegistryVersion,
            suspendedProviderIDs: suspendedProviderIDs,
            strategy: strategy,
            descriptors: descriptors,
            testingOverrideProvider: testingOverrideProvider,
            providerID: providerID,
            providerForID: providerForID,
            isAvailable: isAvailable
        )
        let planSummary = BASProviderRequestPlanSummary(
            task: task,
            preferredProviderID: preferredProviderID,
            orderedProviderIDs: planning.plan.orderedProviderIDs,
            resolvedProviderIDs: planning.resolvedProviderIDs,
            compatibleProviderIDs: planning.plan.compatibleProviderIDs,
            incompatibleProviderIDs: planning.plan.incompatibleProviderIDs,
            suspendedProviderIDs: suspendedProviderIDs.sorted(),
            appliedRoutingPolicyVersion: planning.plan.appliedRoutingPolicyVersion,
            appliedRoutingRegistryVersion: planning.plan.appliedRoutingRegistryVersion,
            usedTestingOverride: planning.usedTestingOverride,
            providerSelectionDurationMs: elapsedMilliseconds(since: selectionStart, clock: clock)
        )

        let executionOutcome = await BASProviderAttemptExecutor.execute(
            providers: planning.providers,
            providerID: providerID,
            loadCachedResult: loadCachedResult,
            assessCachedResult: assessCachedResult,
            quarantineCachedResult: quarantineCachedResult,
            invokeProvider: invokeProvider,
            assessProviderResult: assessProviderResult,
            onCachedRejected: { provider, result, assessment, attemptedProviderIDs in
                await onCachedRejected?(planSummary, provider, result, assessment, attemptedProviderIDs)
            },
            onCacheHit: { provider, result, assessment, attemptedProviderIDs in
                await onCacheHit?(planSummary, provider, result, assessment, attemptedProviderIDs)
            },
            onProviderRejected: { provider, result, assessment, attemptedProviderIDs in
                await onProviderRejected?(planSummary, provider, result, assessment, attemptedProviderIDs)
            },
            onProviderSuccess: { provider, result, assessment, attemptedProviderIDs in
                await onProviderSuccess?(planSummary, provider, result, assessment, attemptedProviderIDs)
            },
            onProviderMiss: { provider, attemptedProviderIDs in
                await onProviderMiss?(planSummary, provider, attemptedProviderIDs)
            }
        )

        switch executionOutcome {
        case .resolved(let execution):
            return .resolved(
                BASProviderRequestResolution(
                    planSummary: planSummary,
                    execution: execution
                )
            )
        case .noResult(let attemptedProviderIDs):
            return .noResult(
                BASProviderRequestNoResult(
                    planSummary: planSummary,
                    attemptedProviderIDs: attemptedProviderIDs
                )
            )
        }
    }

    private static func elapsedMilliseconds(
        since start: ContinuousClock.Instant,
        clock: ContinuousClock
    ) -> Int {
        let duration = start.duration(to: clock.now)
        return Int(duration.components.seconds * 1_000)
            + Int(duration.components.attoseconds / 1_000_000_000_000_000)
    }
}
