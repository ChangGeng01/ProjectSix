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
