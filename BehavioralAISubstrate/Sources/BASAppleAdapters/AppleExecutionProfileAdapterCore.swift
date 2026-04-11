import Foundation
import BASRuntimeCore

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
        request: BASAppleExecutionProfileRequest
    ) -> BASAppleExecutionProfileCompilation {
        if !request.runtimeEnabled {
            return profile(
                tierID: "off",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: "Assistive intelligence is off, so the host app is using the deterministic decision system only.",
                preferredLanguages: request.preferredLanguages
            )
        }

        if let testingOverrideTitle = request.testingOverrideTitle,
           request.preferredProviderID != BASReferenceProviderRuntime.templateProviderID {
            return profile(
                tierID: "testingOverride",
                effectiveProviderID: request.preferredProviderID,
                allowFallbacks: request.allowFallbacks,
                detail: "Testing stub '\(testingOverrideTitle)' is active, so the host app is keeping the full assistive path open for verification.",
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
                    detail: "Testing is pinning deterministic local copy, so the host app is not using a model provider for assistive refinement.",
                    preferredLanguages: request.preferredLanguages
                )
            case BASReferenceProviderRuntime.foundationModelsProviderID where request.foundationAvailable:
                return profile(
                    tierID: "systemManaged",
                    effectiveProviderID: BASReferenceProviderRuntime.foundationModelsProviderID,
                    allowFallbacks: request.allowFallbacks,
                    detail: "Testing is pinning Apple's system-managed model, so the host app is keeping the full assistive path open for that provider.",
                    preferredLanguages: request.preferredLanguages
                )
            case BASReferenceProviderRuntime.openModelProviderID:
                return openModelProfile(
                    request: request,
                    detailPrefix: "Testing is pinning the registered open-model runtime."
                )
            case BASReferenceProviderRuntime.gemmaE4BProviderID where request.gemmaAvailable:
                return profile(
                    tierID: request.physicalMemoryGB < 8 ? "balancedGemma" : "fullGemma",
                    effectiveProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                    allowFallbacks: request.allowFallbacks,
                    detail: "Testing is pinning Gemma directly, so the host app is leaving the full assistive path available for that provider.",
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
                detail: "Deterministic local copy is pinned, so the host app is not using a model provider for assistive refinement.",
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.preferredProviderID == BASReferenceProviderRuntime.openModelProviderID {
            return openModelProfile(
                request: request,
                detailPrefix: "The open-model runtime slot is preferred."
            )
        }

        if request.foundationAvailable {
            return profile(
                tierID: "systemManaged",
                effectiveProviderID: BASReferenceProviderRuntime.foundationModelsProviderID,
                allowFallbacks: request.allowFallbacks,
                detail: "Apple's system-managed on-device model is available, so the host app can keep assistive refinement on without pushing device-level model policy into the app.",
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.isSimulator {
            return profile(
                tierID: "simulator",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: "On Simulator, the host app stays on deterministic local copy so performance and correctness tests do not pretend a local model runtime is representative.",
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.isLowPowerModeEnabled {
            return profile(
                tierID: "conservativeDeterministic",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: "Low Power Mode is on, so the host app is staying on deterministic local copy to protect battery life and keep decision flows responsive.",
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.physicalMemoryGB < 7 {
            return profile(
                tierID: "conservativeDeterministic",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: "This device is running a conservative intelligence profile. The host app keeps the local model off the critical path on 6 GB-class iPhones like iPhone 14 so the experience stays stable, cool, and predictable.",
                preferredLanguages: request.preferredLanguages
            )
        }

        guard request.gemmaAvailable else {
            return profile(
                tierID: "conservativeDeterministic",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: "No assistive provider is ready on this device right now, so the host app is keeping the deterministic path only.",
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.physicalMemoryGB < 8 {
            return profile(
                tierID: "balancedGemma",
                effectiveProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                allowFallbacks: request.allowFallbacks,
                detail: "This device has enough headroom for deeper assisted analysis and reminder work, while the host app can still keep fast-turn refinement deterministic to protect latency.",
                preferredLanguages: request.preferredLanguages
            )
        }

        return profile(
            tierID: "fullGemma",
            effectiveProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
            allowFallbacks: request.allowFallbacks,
            detail: "This device has enough headroom for the full Gemma-assisted path, while the host app can still keep final verdicts deterministic.",
            preferredLanguages: request.preferredLanguages
        )
    }

    private static func openModelProfile(
        request: BASAppleExecutionProfileRequest,
        detailPrefix: String
    ) -> BASAppleExecutionProfileCompilation {
        if request.isSimulator {
            return profile(
                tierID: "simulator",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: "On Simulator, the host app keeps the reserved open-model slot off the critical path and stays deterministic.",
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.isLowPowerModeEnabled {
            return profile(
                tierID: "conservativeDeterministic",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: "Low Power Mode is on, so the host app keeps the open-model runtime off the critical path to protect battery life.",
                preferredLanguages: request.preferredLanguages
            )
        }

        if request.physicalMemoryGB < 7 {
            return profile(
                tierID: "conservativeDeterministic",
                effectiveProviderID: BASReferenceProviderRuntime.templateProviderID,
                allowFallbacks: false,
                detail: "This device is on a conservative intelligence profile, so the host app keeps the reserved open-model lane deterministic on 6 GB-class phones.",
                preferredLanguages: request.preferredLanguages
            )
        }

        return profile(
            tierID: request.physicalMemoryGB < 8 ? "balancedGemma" : "fullGemma",
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
