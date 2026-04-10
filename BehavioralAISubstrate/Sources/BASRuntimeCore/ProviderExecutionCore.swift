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
