import Foundation

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
        if !preferences.onDeviceIntelligenceMode.isEnabled {
            return profile(
                tier: .off,
                effectiveProviderPreference: .template,
                allowFallbacks: false,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "Assistive intelligence is off, so Before is using the deterministic decision system only."
            )
        }

        if let testingStubProfile, preferences.preferredIntelligenceProvider != .template {
            return profile(
                tier: .testingOverride,
                effectiveProviderPreference: preferences.preferredIntelligenceProvider,
                allowFallbacks: preferences.allowModelFallbacks,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "Testing stub '\(testingStubProfile.title)' is active, so Before is keeping the full assistive path open for verification."
            )
        }

        if let preferredProviderOverride {
            switch preferredProviderOverride {
            case .template:
                return profile(
                    tier: .off,
                    effectiveProviderPreference: .template,
                    allowFallbacks: false,
                    device: device,
                    preferredLanguages: preferredLanguages,
                    detail: "Testing is pinning deterministic local copy, so Before is not using a model provider for assistive refinement."
                )
            case .foundationModels:
                if foundationStatus.isAvailable {
                    return profile(
                        tier: .systemManaged,
                        effectiveProviderPreference: .foundationModels,
                        allowFallbacks: preferences.allowModelFallbacks,
                        device: device,
                        preferredLanguages: preferredLanguages,
                        detail: "Testing is pinning Apple's system-managed model, so Before is keeping the full assistive path open for that provider."
                    )
                }
            case .openModel:
                return openModelProfile(
                    preferences: preferences,
                    device: device,
                    status: openModelStatus,
                    detailPrefix: "Testing is pinning the registered open-model runtime.",
                    preferredLanguages: preferredLanguages
                )
            case .gemmaE4B:
                if gemmaStatus.isAvailable {
                    return profile(
                        tier: device.physicalMemoryGB < 8 ? .balancedGemma : .fullGemma,
                        effectiveProviderPreference: .gemmaE4B,
                        allowFallbacks: preferences.allowModelFallbacks,
                        device: device,
                        preferredLanguages: preferredLanguages,
                        detail: "Testing is pinning Gemma directly, so Before is leaving the full assistive path available for that provider."
                    )
                }
            }
        }

        if preferences.preferredIntelligenceProvider == .template {
            return profile(
                tier: .off,
                effectiveProviderPreference: .template,
                allowFallbacks: false,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "Deterministic local copy is pinned, so Before is not using a model provider for assistive refinement."
            )
        }

        if preferences.preferredIntelligenceProvider == .openModel {
            return openModelProfile(
                preferences: preferences,
                device: device,
                status: openModelStatus,
                detailPrefix: "The open-model runtime slot is preferred.",
                preferredLanguages: preferredLanguages
            )
        }

        if foundationStatus.isAvailable {
            return profile(
                tier: .systemManaged,
                effectiveProviderPreference: .foundationModels,
                allowFallbacks: preferences.allowModelFallbacks,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "Apple's system-managed on-device model is available, so Before can keep assistive refinement on without pushing device-level model policy into the app."
            )
        }

        if device.isSimulator {
            return profile(
                tier: .simulator,
                effectiveProviderPreference: .template,
                allowFallbacks: false,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "On Simulator, Before stays on deterministic local copy so performance and correctness tests do not pretend a local model runtime is representative."
            )
        }

        if device.isLowPowerModeEnabled {
            return profile(
                tier: .conservativeDeterministic,
                effectiveProviderPreference: .template,
                allowFallbacks: false,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "Low Power Mode is on, so Before is staying on deterministic local copy to protect battery life and keep decision flows responsive."
            )
        }

        if device.physicalMemoryGB < 7 {
            return profile(
                tier: .conservativeDeterministic,
                effectiveProviderPreference: .template,
                allowFallbacks: false,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "This device is running a conservative intelligence profile. Before keeps the local model off the critical path on 6 GB-class iPhones like iPhone 14 so the app stays stable, cool, and predictable."
            )
        }

        guard gemmaStatus.isAvailable else {
            return profile(
                tier: .conservativeDeterministic,
                effectiveProviderPreference: .template,
                allowFallbacks: false,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "No assistive provider is ready on this device right now, so Before is keeping the deterministic path only."
            )
        }

        if device.physicalMemoryGB < 8 {
            return profile(
                tier: .balancedGemma,
                effectiveProviderPreference: .gemmaE4B,
                allowFallbacks: preferences.allowModelFallbacks,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "This device has enough headroom for Gemma-assisted balance, mirror, and reminder work, but Before keeps quick-check refinement deterministic to protect latency."
            )
        }

        return profile(
            tier: .fullGemma,
            effectiveProviderPreference: .gemmaE4B,
            allowFallbacks: preferences.allowModelFallbacks,
            device: device,
            preferredLanguages: preferredLanguages,
            detail: "This device has enough headroom for the full Gemma-assisted path, while Before still keeps verdicts deterministic."
        )
    }

    private static func openModelProfile(
        preferences: BeforePreferences,
        device: DeviceCapabilitySnapshot,
        status: DecisionModelProviderStatus,
        detailPrefix: String,
        preferredLanguages: [String]
    ) -> DecisionIntelligenceExecutionProfile {
        if device.isSimulator {
            return profile(
                tier: .simulator,
                effectiveProviderPreference: .template,
                allowFallbacks: false,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "On Simulator, Before keeps the reserved open-model slot off the critical path and stays deterministic."
            )
        }

        if device.isLowPowerModeEnabled {
            return profile(
                tier: .conservativeDeterministic,
                effectiveProviderPreference: .template,
                allowFallbacks: false,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "Low Power Mode is on, so Before keeps the open-model runtime off the critical path to protect battery life."
            )
        }

        if device.physicalMemoryGB < 7 {
            return profile(
                tier: .conservativeDeterministic,
                effectiveProviderPreference: .template,
                allowFallbacks: false,
                device: device,
                preferredLanguages: preferredLanguages,
                detail: "This device is on a conservative intelligence profile, so Before keeps the reserved open-model lane deterministic on 6 GB-class phones."
            )
        }

        let detail = "\(detailPrefix) \(status.detail)"
        return profile(
            tier: device.physicalMemoryGB < 8 ? .balancedGemma : .fullGemma,
            effectiveProviderPreference: .openModel,
            allowFallbacks: preferences.allowModelFallbacks,
            device: device,
            preferredLanguages: preferredLanguages,
            detail: detail
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
