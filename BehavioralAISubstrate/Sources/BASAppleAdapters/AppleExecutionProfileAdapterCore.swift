import Foundation
import BASRuntimeCore

public struct BASAppleExecutionProfileBehavior: Codable, Equatable, Sendable {
    public static let generic = BASAppleExecutionProfileBehavior()

    public var conservativeMemoryThresholdGB: Int
    public var fullAssistiveMemoryThresholdGB: Int
    public var disabledRuntimeDetail: String
    public var testingOverrideDetailFormat: String
    public var testingPinnedDeterministicDetail: String
    public var testingPinnedSystemManagedDetail: String
    public var testingPinnedOpenModelDetailPrefix: String
    public var testingPinnedLocalProviderDetail: String
    public var deterministicPinnedDetail: String
    public var preferredOpenModelDetailPrefix: String
    public var systemManagedDetail: String
    public var simulatorDetail: String
    public var lowPowerDetail: String
    public var lowMemoryDetailFormat: String
    public var unavailableProviderDetail: String
    public var balancedAssistiveDetail: String
    public var fullAssistiveDetail: String
    public var openModelSimulatorDetail: String
    public var openModelLowPowerDetail: String
    public var openModelLowMemoryDetailFormat: String

    public init(
        conservativeMemoryThresholdGB: Int = 7,
        fullAssistiveMemoryThresholdGB: Int = 8,
        disabledRuntimeDetail: String = "Assistive runtime is disabled, so the host stays on the deterministic execution path.",
        testingOverrideDetailFormat: String = "Testing override '%@' is active, so the configured provider path remains open for verification.",
        testingPinnedDeterministicDetail: String = "Testing is pinning the deterministic execution path, so no assistive provider is used.",
        testingPinnedSystemManagedDetail: String = "Testing is pinning the system-managed on-device provider path.",
        testingPinnedOpenModelDetailPrefix: String = "Testing is pinning the configured open-model runtime.",
        testingPinnedLocalProviderDetail: String = "Testing is pinning the configured local provider path.",
        deterministicPinnedDetail: String = "Deterministic execution is pinned, so no assistive provider is used.",
        preferredOpenModelDetailPrefix: String = "The configured open-model runtime is preferred.",
        systemManagedDetail: String = "A system-managed on-device provider is available, so the host can keep the assistive path on-device.",
        simulatorDetail: String = "Simulator runs stay deterministic so tests do not pretend a local model runtime is representative.",
        lowPowerDetail: String = "Low Power Mode is enabled, so the host stays on the deterministic path to protect responsiveness.",
        lowMemoryDetailFormat: String = "This device is below the configured assistive headroom threshold (%d GB), so the host keeps the assistive runtime off the critical path.",
        unavailableProviderDetail: String = "No assistive provider is ready on this device right now, so the host stays on the deterministic path.",
        balancedAssistiveDetail: String = "This device has enough headroom for a moderated assistive path while keeping fast-turn work latency-aware.",
        fullAssistiveDetail: String = "This device has enough headroom for the full assistive path.",
        openModelSimulatorDetail: String = "Simulator runs keep the configured open-model runtime off the critical path and stay deterministic.",
        openModelLowPowerDetail: String = "Low Power Mode is enabled, so the host keeps the configured open-model runtime off the critical path.",
        openModelLowMemoryDetailFormat: String = "This device is below the configured open-model headroom threshold (%d GB), so the host keeps the open-model lane deterministic."
    ) {
        self.conservativeMemoryThresholdGB = conservativeMemoryThresholdGB
        self.fullAssistiveMemoryThresholdGB = fullAssistiveMemoryThresholdGB
        self.disabledRuntimeDetail = disabledRuntimeDetail
        self.testingOverrideDetailFormat = testingOverrideDetailFormat
        self.testingPinnedDeterministicDetail = testingPinnedDeterministicDetail
        self.testingPinnedSystemManagedDetail = testingPinnedSystemManagedDetail
        self.testingPinnedOpenModelDetailPrefix = testingPinnedOpenModelDetailPrefix
        self.testingPinnedLocalProviderDetail = testingPinnedLocalProviderDetail
        self.deterministicPinnedDetail = deterministicPinnedDetail
        self.preferredOpenModelDetailPrefix = preferredOpenModelDetailPrefix
        self.systemManagedDetail = systemManagedDetail
        self.simulatorDetail = simulatorDetail
        self.lowPowerDetail = lowPowerDetail
        self.lowMemoryDetailFormat = lowMemoryDetailFormat
        self.unavailableProviderDetail = unavailableProviderDetail
        self.balancedAssistiveDetail = balancedAssistiveDetail
        self.fullAssistiveDetail = fullAssistiveDetail
        self.openModelSimulatorDetail = openModelSimulatorDetail
        self.openModelLowPowerDetail = openModelLowPowerDetail
        self.openModelLowMemoryDetailFormat = openModelLowMemoryDetailFormat
    }

    public func lowMemoryDetail() -> String {
        String(format: lowMemoryDetailFormat, conservativeMemoryThresholdGB)
    }

    public func openModelLowMemoryDetail() -> String {
        String(format: openModelLowMemoryDetailFormat, conservativeMemoryThresholdGB)
    }

    public func testingOverrideDetail(title: String) -> String {
        String(format: testingOverrideDetailFormat, title)
    }
}

public struct BASAppleExecutionProfileRequest: Codable, Equatable, Sendable {
    public var runtimeEnabled: Bool
    public var preferredProviderID: String
    public var allowFallbacks: Bool
    public var isSimulator: Bool
    public var physicalMemoryGB: Int
    public var isLowPowerModeEnabled: Bool
    public var openModelAvailable: Bool
    public var openModelDetail: String
    public var foundationAvailable: Bool
    public var gemmaAvailable: Bool
    public var testingOverrideTitle: String?
    public var preferredProviderOverrideID: String?
    public var preferredLanguages: [String]

    public init(
        runtimeEnabled: Bool,
        preferredProviderID: String,
        allowFallbacks: Bool,
        isSimulator: Bool,
        physicalMemoryGB: Int,
        isLowPowerModeEnabled: Bool,
        openModelAvailable: Bool,
        openModelDetail: String,
        foundationAvailable: Bool,
        gemmaAvailable: Bool,
        testingOverrideTitle: String? = nil,
        preferredProviderOverrideID: String? = nil,
        preferredLanguages: [String]
    ) {
        self.runtimeEnabled = runtimeEnabled
        self.preferredProviderID = preferredProviderID
        self.allowFallbacks = allowFallbacks
        self.isSimulator = isSimulator
        self.physicalMemoryGB = physicalMemoryGB
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.openModelAvailable = openModelAvailable
        self.openModelDetail = openModelDetail
        self.foundationAvailable = foundationAvailable
        self.gemmaAvailable = gemmaAvailable
        self.testingOverrideTitle = testingOverrideTitle
        self.preferredProviderOverrideID = preferredProviderOverrideID
        self.preferredLanguages = preferredLanguages
    }
}

public struct BASAppleExecutionProfileCompilation: Codable, Equatable, Sendable {
    public var tierID: String
    public var effectiveProviderID: String
    public var allowFallbacks: Bool
    public var detail: String
    public var preferredLanguages: [String]

    public init(
        tierID: String,
        effectiveProviderID: String,
        allowFallbacks: Bool,
        detail: String,
        preferredLanguages: [String]
    ) {
        self.tierID = tierID
        self.effectiveProviderID = effectiveProviderID
        self.allowFallbacks = allowFallbacks
        self.detail = detail
        self.preferredLanguages = preferredLanguages
    }
}

public enum BASAppleExecutionProfileAdapter {
    public static func compile(
        request: BASAppleExecutionProfileRequest,
        behavior: BASAppleExecutionProfileBehavior = .generic
    ) -> BASAppleExecutionProfileCompilation {
        if !request.runtimeEnabled {
            return profile(
                tierID: "off",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: behavior.disabledRuntimeDetail,
                preferredLanguages: request.preferredLanguages
            )
        }

        if let testingOverrideTitle = request.testingOverrideTitle,
           request.preferredProviderID != BASReferenceProviderRuntime.templateProviderID {
            return profile(
                tierID: "testingOverride",
                effectiveProviderID: request.preferredProviderID,
                allowFallbacks: request.allowFallbacks,
                detail: behavior.testingOverrideDetail(title: testingOverrideTitle),
                preferredLanguages: request.preferredLanguages
            )
        }

        if let preferredProviderOverrideID = request.preferredProviderOverrideID {
            switch preferredProviderOverrideID {
            case BASReferenceProviderRuntime.templateProviderID:
                return profile(
                    tierID: "off",
                    effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                    allowFallbacks: false,
                    detail: behavior.testingPinnedDeterministicDetail,
                    preferredLanguages: request.preferredLanguages
                )
            case BASReferenceProviderRuntime.foundationModelsProviderID where request.foundationAvailable:
                return profile(
                    tierID: "systemManaged",
                    effectiveProviderID: BASReferenceProviderRuntime.foundationModelsProviderID,
                    allowFallbacks: request.allowFallbacks,
                    detail: behavior.testingPinnedSystemManagedDetail,
                    preferredLanguages: request.preferredLanguages
                )
            case BASReferenceProviderRuntime.openModelProviderID:
                return openModelProfile(
                    request: request,
                    detailPrefix: behavior.testingPinnedOpenModelDetailPrefix,
                    behavior: behavior
                )
            case BASReferenceProviderRuntime.gemmaE4BProviderID where request.gemmaAvailable:
                return profile(
                    tierID: request.physicalMemoryGB < behavior.fullAssistiveMemoryThresholdGB ? "balancedGemma" : "fullGemma",
                    effectiveProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                    allowFallbacks: request.allowFallbacks,
                    detail: behavior.testingPinnedLocalProviderDetail,
                    preferredLanguages: request.preferredLanguages
                )
            default:
                break
            }
        }

        if request.preferredProviderID == BASReferenceProviderRuntime.templateProviderID {
            return profile(
                tierID: "off",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: behavior.deterministicPinnedDetail,
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.preferredProviderID == BASReferenceProviderRuntime.openModelProviderID {
            return openModelProfile(
                request: request,
                detailPrefix: behavior.preferredOpenModelDetailPrefix,
                behavior: behavior
            )
        }

        if request.foundationAvailable {
            return profile(
                tierID: "systemManaged",
                effectiveProviderID: BASReferenceProviderRuntime.foundationModelsProviderID,
                allowFallbacks: request.allowFallbacks,
                detail: behavior.systemManagedDetail,
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.isSimulator {
            return profile(
                tierID: "simulator",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: behavior.simulatorDetail,
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.isLowPowerModeEnabled {
            return profile(
                tierID: "conservativeDeterministic",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: behavior.lowPowerDetail,
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.physicalMemoryGB < behavior.conservativeMemoryThresholdGB {
            return profile(
                tierID: "conservativeDeterministic",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: behavior.lowMemoryDetail(),
                preferredLanguages: request.preferredLanguages
            )
        }

        guard request.gemmaAvailable else {
            return profile(
                tierID: "conservativeDeterministic",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: behavior.unavailableProviderDetail,
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.physicalMemoryGB < behavior.fullAssistiveMemoryThresholdGB {
            return profile(
                tierID: "balancedGemma",
                effectiveProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                allowFallbacks: request.allowFallbacks,
                detail: behavior.balancedAssistiveDetail,
                preferredLanguages: request.preferredLanguages
            )
        }

        return profile(
            tierID: "fullGemma",
            effectiveProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
            allowFallbacks: request.allowFallbacks,
            detail: behavior.fullAssistiveDetail,
            preferredLanguages: request.preferredLanguages
        )
    }

    private static func openModelProfile(
        request: BASAppleExecutionProfileRequest,
        detailPrefix: String,
        behavior: BASAppleExecutionProfileBehavior
    ) -> BASAppleExecutionProfileCompilation {
        if request.isSimulator {
            return profile(
                tierID: "simulator",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: behavior.openModelSimulatorDetail,
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.isLowPowerModeEnabled {
            return profile(
                tierID: "conservativeDeterministic",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: behavior.openModelLowPowerDetail,
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.physicalMemoryGB < behavior.conservativeMemoryThresholdGB {
            return profile(
                tierID: "conservativeDeterministic",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: behavior.openModelLowMemoryDetail(),
                preferredLanguages: request.preferredLanguages
            )
        }

        return profile(
            tierID: request.physicalMemoryGB < behavior.fullAssistiveMemoryThresholdGB ? "balancedGemma" : "fullGemma",
            effectiveProviderID: BASReferenceProviderRuntime.openModelProviderID,
            allowFallbacks: request.allowFallbacks,
            detail: "\(detailPrefix) \(request.openModelDetail)",
            preferredLanguages: request.preferredLanguages
        )
    }

    private static func profile(
        tierID: String,
        effectiveProviderID: String,
        allowFallbacks: Bool,
        detail: String,
        preferredLanguages: [String]
    ) -> BASAppleExecutionProfileCompilation {
        BASAppleExecutionProfileCompilation(
            tierID: tierID,
            effectiveProviderID: effectiveProviderID,
            allowFallbacks: allowFallbacks,
            detail: detail,
            preferredLanguages: preferredLanguages
        )
    }
}
