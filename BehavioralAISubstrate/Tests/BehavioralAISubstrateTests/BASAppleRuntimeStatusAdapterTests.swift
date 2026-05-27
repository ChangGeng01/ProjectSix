import Testing
@testable import BASAppleAdapters
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASApple Runtime Status Adapter")
struct BASAppleRuntimeStatusAdapterTests {
    @Test("runtime status compiles package-owned active provider and detail")
    func runtimeStatusCompilesSummary() {
        let output = BASAppleProviderRuntimeStatusAdapter.runtimeStatus(
            from: BASAppleProviderRuntimeStatusInput(
                preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                allowFallbacks: true,
                runtimeEnabled: true,
                statusesByID: [
                    BASReferenceProviderRuntime.gemmaE4BProviderID: BASProviderStatusRecord(
                        providerID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                        isAvailable: false,
                        title: "Gemma",
                        detail: "Unavailable"
                    ),
                    BASReferenceProviderRuntime.foundationModelsProviderID: BASProviderStatusRecord(
                        providerID: BASReferenceProviderRuntime.foundationModelsProviderID,
                        isAvailable: true,
                        title: "Foundation",
                        detail: "Ready"
                    )
                ],
                routingPolicy: BASReferenceProviderRuntime.fixtureRoutingPolicy
            )
        )

        #expect(output.preferredProviderID == BASReferenceProviderRuntime.gemmaE4BProviderID)
        #expect(output.activeProviderID == BASReferenceProviderRuntime.foundationModelsProviderID)
        #expect(output.fallbackProviderID == BASReferenceProviderRuntime.foundationModelsProviderID)
        #expect(output.detail.lowercased().contains("foundation"))
    }

    @Test("host-visible runtime status preserves requested provider and uses profile detail when execution profile shifts")
    func hostVisibleRuntimeStatusPreservesRequestedNarrative() {
        let output = BASAppleProviderRuntimeStatusAdapter.hostVisibleRuntimeStatus(
            from: BASAppleHostVisibleRuntimeStatusInput(
                requestedProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                runtimeEnabled: true,
                statusesByID: [
                    BASReferenceProviderRuntime.gemmaE4BProviderID: BASProviderStatusRecord(
                        providerID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                        isAvailable: true,
                        title: "Gemma",
                        detail: "Ready"
                    )
                ],
                routingPolicy: BASReferenceProviderRuntime.fixtureRoutingPolicy,
                profileDetail: "iPhone 14 stays on deterministic local copy for this workload."
            )
        )

        #expect(output.preferredProviderID == BASReferenceProviderRuntime.gemmaE4BProviderID)
        #expect(output.activeProviderID == BASReferenceProviderRuntime.templateProviderID)
        #expect(output.fallbackProviderID == BASReferenceProviderRuntime.templateProviderID)
        #expect(output.detail == "iPhone 14 stays on deterministic local copy for this workload.")
    }

    @Test("runtime status honors injected routing policy orderings")
    func runtimeStatusHonorsInjectedRoutingPolicy() {
        let policy = BASProviderRoutingPolicy(
            schemaVersion: "custom.policy.v2",
            deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
            preferenceOrderings: [
                BASProviderPreferenceOrdering(
                    preferredProviderID: "custom-primary",
                    orderedProviderIDs: ["custom-primary", "custom-fallback"]
                )
            ]
        )

        let output = BASAppleProviderRuntimeStatusAdapter.runtimeStatus(
            from: BASAppleProviderRuntimeStatusInput(
                preferredProviderID: "custom-primary",
                allowFallbacks: true,
                runtimeEnabled: true,
                statusesByID: [
                    "custom-primary": BASProviderStatusRecord(
                        providerID: "custom-primary",
                        isAvailable: false,
                        title: "Custom primary",
                        detail: "Unavailable"
                    ),
                    "custom-fallback": BASProviderStatusRecord(
                        providerID: "custom-fallback",
                        isAvailable: true,
                        title: "Custom fallback",
                        detail: "Ready"
                    )
                ],
                routingPolicy: policy,
                routingRegistryVersion: "custom.registry.v2"
            )
        )

        #expect(output.activeProviderID == "custom-fallback")
        #expect(output.fallbackProviderID == "custom-fallback")
        #expect(output.orderedProviderIDs == ["custom-primary", "custom-fallback"])
    }
}
#endif
