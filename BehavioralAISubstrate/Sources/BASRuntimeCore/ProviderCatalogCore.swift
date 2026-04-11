import Foundation

public enum BASReferenceProviderCatalog {
    public static let gemmaOpenModelDescriptor = BASOpenModelDescriptor(
        stableID: "google/gemma-4-e4b-it",
        family: "Gemma 4",
        version: "E4B",
        title: "Gemma 4 E4B",
        detail: "Built-in open-model adapter. Future bundled open-source runtimes can plug into the same provider contract without changing the intelligence pipeline.",
        taskAffinities: defaultTaskAffinities(providerID: BASReferenceProviderRuntime.gemmaE4BProviderID),
        capabilityProfile: BASProviderCapabilityProfile(
            modelID: "google/gemma-4-e4b-it",
            strengths: [
                .structuredOutput,
                .deepReflection,
                .retrievalGrounding,
                .multilingualChinese
            ],
            weaknesses: [],
            latencyClass: .medium,
            memoryClass: .medium,
            supportedResponseLanguages: [.english, .chinese, .mixed],
            supportsThinking: true,
            supportsStructuredOutput: true,
            supportsToolUse: true,
            bestFor: [.balance, .mirror, .reminder]
        )
    )

    public static let reservedOpenModelDescriptor = BASOpenModelDescriptor(
        stableID: "substrate/open-model-slot",
        family: "Open model runtime",
        version: "reserved",
        title: "Open model runtime",
        detail: "Reserved integration slot for future bundled or open-source local models. Replace this adapter to add a new model without rewriting the intelligence pipeline.",
        taskAffinities: defaultTaskAffinities(providerID: BASReferenceProviderRuntime.openModelProviderID),
        capabilityProfile: BASProviderCapabilityProfile(
            modelID: "substrate/open-model-slot",
            strengths: [
                .shortDialogue,
                .structuredOutput,
                .lightToolUse
            ],
            weaknesses: [
                .deepReflection
            ],
            latencyClass: .low,
            memoryClass: .low,
            supportedResponseLanguages: [.english],
            supportsThinking: false,
            supportsStructuredOutput: true,
            supportsToolUse: true,
            bestFor: [.quick, .reminder]
        )
    )

    public static func defaultDescriptorsByID() -> [String: BASProviderDescriptor] {
        [
            BASReferenceProviderRuntime.gemmaE4BProviderID: BASProviderDescriptor(
                providerID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                title: gemmaOpenModelDescriptor.title,
                detail: gemmaOpenModelDescriptor.detail,
                track: .builtInOpenModel,
                openModel: gemmaOpenModelDescriptor,
                taskAffinities: gemmaOpenModelDescriptor.taskAffinities,
                capabilityProfile: gemmaOpenModelDescriptor.capabilityProfile
            ),
            BASReferenceProviderRuntime.foundationModelsProviderID: BASProviderDescriptor(
                providerID: BASReferenceProviderRuntime.foundationModelsProviderID,
                title: "Apple Foundation Model",
                detail: "Built-in system-managed language provider.",
                track: .builtInSystem,
                openModel: nil,
                taskAffinities: defaultTaskAffinities(providerID: BASReferenceProviderRuntime.foundationModelsProviderID),
                capabilityProfile: BASProviderCapabilityProfile(
                    modelID: "apple/foundation-model-default",
                    strengths: [
                        .shortDialogue,
                        .structuredOutput,
                        .lightToolUse,
                        .lowLatency,
                        .lowMemory,
                        .multilingualChinese
                    ],
                    weaknesses: [],
                    latencyClass: .low,
                    memoryClass: .low,
                    supportedResponseLanguages: [.english, .chinese, .mixed],
                    supportsThinking: false,
                    supportsStructuredOutput: true,
                    supportsToolUse: true,
                    bestFor: [.quick, .reminder]
                )
            ),
            BASReferenceProviderRuntime.openModelProviderID: BASProviderDescriptor(
                providerID: BASReferenceProviderRuntime.openModelProviderID,
                title: reservedOpenModelDescriptor.title,
                detail: reservedOpenModelDescriptor.detail,
                track: .builtInOpenModel,
                openModel: reservedOpenModelDescriptor,
                taskAffinities: reservedOpenModelDescriptor.taskAffinities,
                capabilityProfile: reservedOpenModelDescriptor.capabilityProfile
            )
        ]
    }

    public static func defaultTaskAffinities(providerID: String) -> [BASAdaptiveTraceKind: Int] {
        switch providerID {
        case BASReferenceProviderRuntime.gemmaE4BProviderID:
            [
                .quick: 70,
                .balance: 94,
                .mirror: 100,
                .reminder: 84
            ]
        case BASReferenceProviderRuntime.openModelProviderID:
            [
                .quick: 88,
                .balance: 90,
                .mirror: 92,
                .reminder: 86
            ]
        case BASReferenceProviderRuntime.foundationModelsProviderID:
            [
                .quick: 100,
                .balance: 78,
                .mirror: 72,
                .reminder: 92
            ]
        case BASReferenceProviderRuntime.testingStubProviderID:
            [
                .quick: 100,
                .balance: 100,
                .mirror: 100,
                .reminder: 100
            ]
        case BASReferenceProviderRuntime.templateProviderID:
            [
                .quick: 0,
                .balance: 0,
                .mirror: 0,
                .reminder: 0
            ]
        default:
            [:]
        }
    }
}
