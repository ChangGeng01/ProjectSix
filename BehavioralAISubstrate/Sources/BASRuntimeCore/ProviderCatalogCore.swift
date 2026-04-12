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
            bestFor: [.comparative, .reflective, .selection]
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
            bestFor: [.primary, .selection]
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
                    bestFor: [.primary, .selection]
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
                .primary: 70,
                .comparative: 94,
                .reflective: 100,
                .selection: 84
            ]
        case BASReferenceProviderRuntime.openModelProviderID:
            [
                .primary: 88,
                .comparative: 90,
                .reflective: 92,
                .selection: 86
            ]
        case BASReferenceProviderRuntime.foundationModelsProviderID:
            [
                .primary: 100,
                .comparative: 78,
                .reflective: 72,
                .selection: 92
            ]
        case BASReferenceProviderRuntime.testingStubProviderID:
            [
                .primary: 100,
                .comparative: 100,
                .reflective: 100,
                .selection: 100
            ]
        case BASReferenceProviderRuntime.templateProviderID:
            [
                .primary: 0,
                .comparative: 0,
                .reflective: 0,
                .selection: 0
            ]
        default:
            [:]
        }
    }
}
