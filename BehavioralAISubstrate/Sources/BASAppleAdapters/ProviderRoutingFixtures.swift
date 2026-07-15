// MARK: - BASReferenceProviderRuntime fixtures — moved from BASRuntimeCore (charter audit 2026-07-12)
//
// Charter finding ④: the deterministic core shipped model-named DEFAULT DATA — the
// Gemma-first fixture routing registry lived in BASRuntimeCore. The core keeps the
// provider-ID constants and the generic registry RESOLVERS (model-neutral, injected
// registry); the FIXTURE registry/policy/orderings (reference wiring with a concrete
// model preference) belongs in the adapter ring. Static stored properties are legal in
// extensions, so every call site stays textually identical — only test imports change.
// Zero live production consumers of fixtureRouting* exist (verified 2026-07-12);
// consumers are tests + the dormant Archive/Legacy app (which compiles via BASHostKit's
// re-export).

import Foundation
import BASRuntimeCore

extension BASReferenceProviderRuntime {

    public static let fixtureRoutingPolicyID = "reference-provider-policy.v1"
    public static let fixtureRoutingRegistry = BASProviderRoutingPolicyRegistry(
        schemaVersion: "reference-provider-registry.v1",
        defaultPolicyID: fixtureRoutingPolicyID,
        policiesByID: [
            fixtureRoutingPolicyID: BASProviderRoutingPolicy(
                schemaVersion: fixtureRoutingPolicyID,
                deterministicProviderID: templateProviderID,
                testingOverrideProviderID: testingStubProviderID,
                preferenceOrderings: [
                    BASProviderPreferenceOrdering(
                        preferredProviderID: gemmaE4BProviderID,
                        orderedProviderIDs: [
                            gemmaE4BProviderID,
                            foundationModelsProviderID
                        ]
                    ),
                    BASProviderPreferenceOrdering(
                        preferredProviderID: openModelProviderID,
                        orderedProviderIDs: [
                            openModelProviderID,
                            gemmaE4BProviderID,
                            foundationModelsProviderID
                        ]
                    ),
                    BASProviderPreferenceOrdering(
                        preferredProviderID: foundationModelsProviderID,
                        orderedProviderIDs: [
                            foundationModelsProviderID,
                            gemmaE4BProviderID
                        ]
                    ),
                    BASProviderPreferenceOrdering(
                        preferredProviderID: templateProviderID,
                        orderedProviderIDs: [
                            templateProviderID
                        ]
                    )
                ]
            )
        ]
    )

    public static var fixtureRoutingPolicy: BASProviderRoutingPolicy {
        fixtureRoutingRegistry.policyOrMissing()
    }

    public static var fixtureRoutingSource: BASProviderRoutingPolicySource {
        BASProviderRoutingPolicySource(
            registry: fixtureRoutingRegistry,
            policyID: fixtureRoutingPolicyID
        )
    }

    public static var fixturePreferenceOrderings: [BASProviderPreferenceOrdering] {
        fixtureRoutingPolicy.preferenceOrderings
    }

    public static func registryUsesFixtureCatalog(
        _ registry: BASProviderRoutingPolicyRegistry,
        policyID: String? = nil
    ) -> Bool {
        if registry.schemaVersion == fixtureRoutingRegistry.schemaVersion ||
            registry.defaultPolicyID == fixtureRoutingPolicyID ||
            policyID == fixtureRoutingPolicyID {
            return true
        }

        return registry.policyIfAvailable(for: policyID) == fixtureRoutingPolicy
    }

    @available(*, unavailable, renamed: "fixtureRoutingPolicyID", message: "Use fixtureRoutingPolicyID only for package fixtures; production code should inject a routing registry.")
    public static let referenceRoutingPolicyID = fixtureRoutingPolicyID

    @available(*, unavailable, renamed: "fixtureRoutingRegistry", message: "Use fixtureRoutingRegistry only for package fixtures; production code should inject a routing registry.")
    public static let referenceRoutingRegistry = fixtureRoutingRegistry

    @available(*, unavailable, renamed: "fixtureRoutingPolicy", message: "Use fixtureRoutingPolicy only for package fixtures; production code should inject a routing policy source.")
    public static var referenceRoutingPolicy: BASProviderRoutingPolicy {
        fixtureRoutingPolicy
    }

    @available(*, unavailable, renamed: "fixtureRoutingSource", message: "Use fixtureRoutingSource only for package fixtures; production code should inject a routing policy source.")
    public static var referenceRoutingSource: BASProviderRoutingPolicySource {
        fixtureRoutingSource
    }

    @available(*, unavailable, renamed: "fixturePreferenceOrderings", message: "Use fixturePreferenceOrderings only for package fixtures; production code should inject a routing policy source.")
    public static var referencePreferenceOrderings: [BASProviderPreferenceOrdering] {
        fixturePreferenceOrderings
    }

    @available(*, unavailable, renamed: "fixtureRoutingPolicyID", message: "Use fixtureRoutingPolicyID only for package fixtures; production code should inject a routing registry.")
    public static let fallbackRoutingPolicyID = fixtureRoutingPolicyID

    @available(*, unavailable, renamed: "fixtureRoutingRegistry", message: "Use fixtureRoutingRegistry only for package fixtures; production code should inject a routing registry.")
    public static let fallbackRoutingRegistry = fixtureRoutingRegistry

    @available(*, unavailable, renamed: "fixtureRoutingPolicy", message: "Use fixtureRoutingPolicy only for package fixtures; production code should inject a routing policy source.")
    public static var fallbackRoutingPolicy: BASProviderRoutingPolicy {
        fixtureRoutingPolicy
    }

    @available(*, unavailable, renamed: "fixtureRoutingSource", message: "Use fixtureRoutingSource only for package fixtures; production code should inject a routing policy source.")
    public static var fallbackRoutingSource: BASProviderRoutingPolicySource {
        fixtureRoutingSource
    }

    @available(*, unavailable, renamed: "fixturePreferenceOrderings", message: "Use fixturePreferenceOrderings only for package fixtures; production code should inject a routing policy source.")
    public static var fallbackPreferenceOrderings: [BASProviderPreferenceOrdering] {
        fixturePreferenceOrderings
    }
}
