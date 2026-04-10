import Testing
@testable import BASAppleAdapters
@testable import BASRuntimeCore

struct BASAppleExecutionProfileAdapterTests {
    @Test
    func disabledRuntimePinsDeterministicProfile() {
        let compilation = BASAppleExecutionProfileAdapter.compile(
            request: BASAppleExecutionProfileRequest(
                runtimeEnabled: false,
                preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                allowFallbacks: true,
                isSimulator: false,
                physicalMemoryGB: 8,
                isLowPowerModeEnabled: false,
                openModelAvailable: false,
                openModelDetail: "Reserved.",
                foundationAvailable: false,
                gemmaAvailable: true,
                preferredLanguages: ["en-AU"]
            )
        )

        #expect(compilation.tierID == "off")
        #expect(compilation.effectiveProviderID == BASReferenceProviderRuntime.templateProviderID)
        #expect(compilation.allowFallbacks == false)
    }

    @Test
    func foundationAvailabilityWinsWhenRuntimeIsEnabled() {
        let compilation = BASAppleExecutionProfileAdapter.compile(
            request: BASAppleExecutionProfileRequest(
                runtimeEnabled: true,
                preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                allowFallbacks: true,
                isSimulator: false,
                physicalMemoryGB: 6,
                isLowPowerModeEnabled: false,
                openModelAvailable: false,
                openModelDetail: "Reserved.",
                foundationAvailable: true,
                gemmaAvailable: true,
                preferredLanguages: ["zh-Hans"]
            )
        )

        #expect(compilation.tierID == "systemManaged")
        #expect(compilation.effectiveProviderID == BASReferenceProviderRuntime.foundationModelsProviderID)
        #expect(compilation.detail.contains("system-managed"))
    }

    @Test
    func openModelPreferenceBuildsPackageOwnedBalancedProfile() {
        let compilation = BASAppleExecutionProfileAdapter.compile(
            request: BASAppleExecutionProfileRequest(
                runtimeEnabled: true,
                preferredProviderID: BASReferenceProviderRuntime.openModelProviderID,
                allowFallbacks: true,
                isSimulator: false,
                physicalMemoryGB: 7,
                isLowPowerModeEnabled: false,
                openModelAvailable: true,
                openModelDetail: "Registered runtime is warm.",
                foundationAvailable: false,
                gemmaAvailable: false,
                preferredLanguages: ["en-AU", "zh-Hans"]
            )
        )

        #expect(compilation.tierID == "balancedGemma")
        #expect(compilation.effectiveProviderID == BASReferenceProviderRuntime.openModelProviderID)
        #expect(compilation.detail.contains("Registered runtime is warm."))
        #expect(compilation.preferredLanguages == ["en-AU", "zh-Hans"])
    }

    @Test
    func lowMemoryWithoutAssistiveProviderFallsBackToConservativeDeterministic() {
        let compilation = BASAppleExecutionProfileAdapter.compile(
            request: BASAppleExecutionProfileRequest(
                runtimeEnabled: true,
                preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                allowFallbacks: true,
                isSimulator: false,
                physicalMemoryGB: 6,
                isLowPowerModeEnabled: false,
                openModelAvailable: false,
                openModelDetail: "Reserved.",
                foundationAvailable: false,
                gemmaAvailable: false,
                preferredLanguages: ["en-AU"]
            )
        )

        #expect(compilation.tierID == "conservativeDeterministic")
        #expect(compilation.effectiveProviderID == BASReferenceProviderRuntime.templateProviderID)
        #expect(compilation.detail.contains("iPhone 14"))
    }
}
