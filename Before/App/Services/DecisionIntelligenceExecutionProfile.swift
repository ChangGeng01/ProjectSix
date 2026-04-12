import Foundation
import BASHostKit

enum DecisionIntelligenceExecutionTier: String, Equatable, Sendable {
    case testingOverride
    case off
    case simulator
    case conservativeDeterministic
    case balancedGemma
    case fullGemma
    case systemManaged
}

struct DecisionIntelligenceExecutionProfile: Equatable, Sendable {
    let tier: DecisionIntelligenceExecutionTier
    let effectiveProviderPreference: DecisionModelProviderPreference
    let allowFallbacks: Bool
    let device: DeviceCapabilitySnapshot
    let preferredLanguages: [String]
    let detail: String

    var adaptationMatrix: DecisionAdaptiveRuntimeMatrix {
        DecisionAdaptiveRuntimeMatrixResolver.resolve(
            tier: tier,
            preference: effectiveProviderPreference,
            allowFallbacks: allowFallbacks,
            device: device,
            preferredLanguages: preferredLanguages
        )
    }

    func strategy(for kind: DecisionIntelligenceTraceKind) -> DecisionAdaptiveTaskStrategy {
        adaptationMatrix.strategy(for: kind)
    }

    var allowsQuickRefinement: Bool {
        strategy(for: .quick).allowsModelInvocation
    }

    var allowsBalanceRefinement: Bool {
        strategy(for: .balance).allowsModelInvocation
    }

    var allowsMirrorRefinement: Bool {
        strategy(for: .mirror).allowsModelInvocation
    }

    var allowsReminderSelection: Bool {
        strategy(for: .reminder).allowsModelInvocation
    }

    var usesAssistiveProvider: Bool {
        effectiveProviderPreference != .template
    }
}

enum DecisionIntelligenceExecutionProfileResolver {
    static func resolve(
        preferences: BeforePreferences,
        device: DeviceCapabilitySnapshot = .current,
        openModelStatus: DecisionModelProviderStatus = DecisionIntelligenceProviderRegistry.shared.statusesByKind()[.openModel] ?? DecisionModelProviderStatus(
            kind: .openModel,
            isAvailable: false,
            title: "Reserved",
            detail: "No open-model runtime is registered."
        ),
        foundationStatus: DecisionModelProviderStatus = FoundationModelsIntelligenceService.availabilityStatus,
        gemmaStatus: DecisionModelProviderStatus = GemmaE4BIntelligenceService.availabilityStatus,
        testingStubProfile: DecisionTestingStubProfile? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.stubProfile,
        preferredProviderOverride: DecisionModelProviderPreference? = DecisionTestingInterface.environmentOverride(environment: ProcessInfo.processInfo.environment)?.preferredProvider,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> DecisionIntelligenceExecutionProfile {
        let compilation = BASAppleExecutionProfileAdapter.compile(
            request: BASAppleExecutionProfileRequest(
                runtimeEnabled: preferences.onDeviceIntelligenceMode.isEnabled,
                preferredProviderID: preferences.preferredIntelligenceProvider.rawValue,
                allowFallbacks: preferences.allowModelFallbacks,
                isSimulator: device.isSimulator,
                physicalMemoryGB: device.physicalMemoryGB,
                isLowPowerModeEnabled: device.isLowPowerModeEnabled,
                openModelAvailable: openModelStatus.isAvailable,
                openModelDetail: openModelStatus.detail,
                foundationAvailable: foundationStatus.isAvailable,
                gemmaAvailable: gemmaStatus.isAvailable,
                testingOverrideTitle: testingStubProfile?.title,
                preferredProviderOverrideID: preferredProviderOverride?.rawValue,
                preferredLanguages: preferredLanguages
            ),
            behavior: BeforeProductCompatibility.executionProfileBehavior
        )

        return profile(
            tier: DecisionIntelligenceExecutionTier(rawValue: compilation.tierID) ?? .off,
            effectiveProviderPreference: DecisionModelProviderPreference(
                rawValue: compilation.effectiveProviderID
            ) ?? .template,
            allowFallbacks: compilation.allowFallbacks,
            device: device,
            preferredLanguages: compilation.preferredLanguages,
            detail: compilation.detail
        )
    }

    private static func profile(
        tier: DecisionIntelligenceExecutionTier,
        effectiveProviderPreference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        device: DeviceCapabilitySnapshot,
        preferredLanguages: [String],
        detail: String
    ) -> DecisionIntelligenceExecutionProfile {
        DecisionIntelligenceExecutionProfile(
            tier: tier,
            effectiveProviderPreference: effectiveProviderPreference,
            allowFallbacks: allowFallbacks,
            device: device,
            preferredLanguages: preferredLanguages,
            detail: detail
        )
    }
}
