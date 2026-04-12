import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

public enum BASPromptStateValue: Sendable, Equatable {
    case string(String)
    case integer(Int)
    case boolean(Bool)

    fileprivate var jsonValue: Any {
        switch self {
        case .string(let value):
            value
        case .integer(let value):
            value
        case .boolean(let value):
            value
        }
    }

    fileprivate var countsAsActiveSignal: Bool {
        switch self {
        case .string(let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !(trimmed.isEmpty || trimmed == "Not provided." || trimmed == "Not specified")
        case .integer(let value):
            return value > 0
        case .boolean(let value):
            return value
        }
    }
}

public struct BASPromptContextLifecycleSnapshot: Codable, Sendable, Equatable {
    public var rebuiltSession: Bool
    public var generation: Int
    public var anchorFields: [String]
    public var activeFields: [String]
    public var staleFields: [String]
    public var anchorTitles: [String]

    public init(
        rebuiltSession: Bool,
        generation: Int,
        anchorFields: [String],
        activeFields: [String],
        staleFields: [String],
        anchorTitles: [String] = []
    ) {
        self.rebuiltSession = rebuiltSession
        self.generation = generation
        self.anchorFields = anchorFields
        self.activeFields = activeFields
        self.staleFields = staleFields
        self.anchorTitles = anchorTitles
    }

    public var staleFieldCount: Int {
        staleFields.count
    }
}

public struct BASPromptNeuralActivationSnapshot: Codable, Sendable, Equatable {
    public var signal: String
    public var displayTitle: String?

    public init(
        signal: String,
        displayTitle: String? = nil
    ) {
        self.signal = signal
        self.displayTitle = displayTitle
    }
}

public struct BASPromptNeuralActionCandidateSnapshot: Codable, Sendable, Equatable {
    public var route: String

    public init(route: String) {
        self.route = route
    }
}

public struct BASPromptNeuralSnapshot: Codable, Sendable, Equatable {
    public var dominantActivations: [BASPromptNeuralActivationSnapshot]
    public var candidateActions: [BASPromptNeuralActionCandidateSnapshot]
    public var suppressedBehaviors: [String]

    public init(
        dominantActivations: [BASPromptNeuralActivationSnapshot],
        candidateActions: [BASPromptNeuralActionCandidateSnapshot],
        suppressedBehaviors: [String]
    ) {
        self.dominantActivations = dominantActivations
        self.candidateActions = candidateActions
        self.suppressedBehaviors = suppressedBehaviors
    }
}

public struct BASPromptPreparationRequest<Kind: Equatable & Sendable>: Sendable, Equatable {
    public var kind: Kind
    public var semanticKind: BASSemanticTaskKind
    public var adaptiveKind: BASAdaptiveTraceKind
    public var presentationBehavior: BASPromptPresentationBehavior
    public var frontstageBehavior: BASFrontstagePresentationBehavior
    public var taskState: [String: BASPromptStateValue?]
    public var evidenceSnippets: [String]
    public var outputGuard: [String]
    public var openTextSignalCount: Int
    public var defaultTargetCharacters: Int
    public var strategy: BASAdaptiveTaskStrategy?
    public var contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot?
    public var neuralSnapshot: BASPromptNeuralSnapshot?
    public var brainState: BASDecisionBrainState?
    public var structuredTruthOverride: BASStructuredTruthState?
    public var structuredTruthBehavior: BASStructuredTruthBehavior
    public var includeStructuredTruthBlock: Bool
    public var providerIdentifier: String?

    public init(
        kind: Kind,
        semanticKind: BASSemanticTaskKind,
        adaptiveKind: BASAdaptiveTraceKind,
        presentationBehavior: BASPromptPresentationBehavior = .generic,
        frontstageBehavior: BASFrontstagePresentationBehavior = .generic,
        taskState: [String: BASPromptStateValue?],
        evidenceSnippets: [String],
        outputGuard: [String],
        openTextSignalCount: Int = 0,
        defaultTargetCharacters: Int,
        strategy: BASAdaptiveTaskStrategy? = nil,
        contextLifecycleSnapshot: BASPromptContextLifecycleSnapshot? = nil,
        neuralSnapshot: BASPromptNeuralSnapshot? = nil,
        brainState: BASDecisionBrainState? = nil,
        structuredTruthOverride: BASStructuredTruthState? = nil,
        structuredTruthBehavior: BASStructuredTruthBehavior = .generic,
        includeStructuredTruthBlock: Bool = true,
        providerIdentifier: String? = nil
    ) {
        self.kind = kind
        self.semanticKind = semanticKind
        self.adaptiveKind = adaptiveKind
        self.presentationBehavior = presentationBehavior
        self.frontstageBehavior = frontstageBehavior
        self.taskState = taskState
        self.evidenceSnippets = evidenceSnippets
        self.outputGuard = outputGuard
        self.openTextSignalCount = openTextSignalCount
        self.defaultTargetCharacters = defaultTargetCharacters
        self.strategy = strategy
        self.contextLifecycleSnapshot = contextLifecycleSnapshot
        self.neuralSnapshot = neuralSnapshot
        self.brainState = brainState
        self.structuredTruthOverride = structuredTruthOverride
        self.structuredTruthBehavior = structuredTruthBehavior
        self.includeStructuredTruthBlock = includeStructuredTruthBlock
        self.providerIdentifier = providerIdentifier
    }
}

public enum BASPromptPreparationCompiler {
    public static func compile<Kind: Equatable & Sendable>(
        _ request: BASPromptPreparationRequest<Kind>
    ) -> BASPromptEnvelope<Kind, BASFrontstageState> {
        let structuredTruth = request.structuredTruthOverride ?? BASStructuredTruthCompiler.truthState(
            for: BASStructuredTruthRequest(
                kind: request.adaptiveKind,
                brainState: request.brainState,
                behavior: request.structuredTruthBehavior
            )
        )
        let includeStructuredTruthBlock = request.includeStructuredTruthBlock && structuredTruth != nil
        let scopedContextJSON = BASScopedContextCompiler.compile(
            kind: request.adaptiveKind,
            strategy: request.strategy,
            brainState: request.brainState
        )
        .map(BASScopedContextCompiler.jsonString(for:))

        let frontstageInput = BASPromptContractFrontstageInput(
            kind: request.adaptiveKind,
            activeStateSignalCount: activeStateSignalCount(in: request.taskState),
            openTextSignalCount: request.openTextSignalCount,
            contextWasRebuilt: request.contextLifecycleSnapshot?.rebuiltSession == true,
            staleFieldCount: request.contextLifecycleSnapshot?.staleFieldCount ?? 0,
            anchorTitles: request.contextLifecycleSnapshot?.anchorTitles ?? request.contextLifecycleSnapshot?.anchorFields ?? [],
            dominantSignalTitles: request.neuralSnapshot?.dominantActivations.map { $0.displayTitle ?? $0.signal } ?? [],
            suppressedBehaviors: request.neuralSnapshot?.suppressedBehaviors ?? [],
            memoryHeadlines: request.brainState?.relevantMemories ?? [],
            sessionBiases: request.brainState?.sessionBiases ?? [],
            presentationBehavior: request.frontstageBehavior
        )

        return BASPromptContractCompiler.compile(
            BASPromptContractRequest(
                kind: request.kind,
                semanticKind: request.semanticKind,
                adaptiveKind: request.adaptiveKind,
                immutablePrefix: BASPromptPrefixCatalog.immutablePrefix(
                    for: request.semanticKind,
                    behavior: request.presentationBehavior
                ),
                adaptivePrefix: BASPromptPrefixCatalog.adaptivePrefix(
                    for: request.semanticKind,
                    behavior: request.presentationBehavior
                ),
                taskStateJSON: taskStateJSONString(request.taskState),
                evidenceSnippets: request.evidenceSnippets,
                evidenceRetentionBudget: BASPromptRetentionAdvisor.evidenceRetentionBudget(
                    for: request.semanticKind,
                    strategy: request.strategy,
                    behavior: request.presentationBehavior
                ),
                outputGuard: request.outputGuard,
                frontstageInput: frontstageInput,
                targetCharacters: request.strategy?.contextBudget ?? request.defaultTargetCharacters,
                suffixFloorCharacters: suffixFloor(
                    for: request.semanticKind,
                    strategy: request.strategy
                ),
                strategy: request.strategy,
                structuredTruth: structuredTruth,
                includeStructuredTruthBlock: includeStructuredTruthBlock,
                scopedContextJSON: scopedContextJSON,
                providerIdentifier: request.providerIdentifier,
                contextLifecycleJSON: request.contextLifecycleSnapshot.map(contextLifecycleJSONString),
                neuralStateJSON: request.neuralSnapshot.map(neuralStateJSONString),
                brainStateJSON: request.brainState.flatMap { $0.isEmpty ? nil : brainStateJSONString($0) }
            )
        )
    }

    private static func suffixFloor(
        for kind: BASSemanticTaskKind,
        strategy: BASAdaptiveTaskStrategy?
    ) -> Int {
        if strategy?.runtimeGear == .low {
            switch kind {
            case .primary, .selection:
                120
            case .comparative, .reflective:
                150
            }
        } else {
            180
        }
    }

    private static func activeStateSignalCount(
        in state: [String: BASPromptStateValue?]
    ) -> Int {
        state.values.reduce(0) { partialResult, value in
            guard let value else { return partialResult }
            return value.countsAsActiveSignal ? partialResult + 1 : partialResult
        }
    }

    private static func taskStateJSONString(
        _ state: [String: BASPromptStateValue?]
    ) -> String {
        let compactState = state.reduce(into: [String: Any]()) { result, pair in
            guard let value = pair.value else { return }
            result[pair.key] = value.jsonValue
        }
        return jsonString(compactState)
    }

    private static func contextLifecycleJSONString(
        _ snapshot: BASPromptContextLifecycleSnapshot
    ) -> String {
        jsonString([
            "rebuilt_session": snapshot.rebuiltSession,
            "generation": snapshot.generation,
            "anchor_fields": snapshot.anchorFields,
            "active_fields": snapshot.activeFields,
            "stale_fields": snapshot.staleFields
        ])
    }

    private static func neuralStateJSONString(
        _ snapshot: BASPromptNeuralSnapshot
    ) -> String {
        jsonString([
            "dominant_signals": snapshot.dominantActivations.map { ["signal": $0.signal] },
            "candidate_actions": snapshot.candidateActions.map { ["route": $0.route] },
            "suppressed_behaviors": snapshot.suppressedBehaviors
        ])
    }

    private static func brainStateJSONString(
        _ brainState: BASDecisionBrainState
    ) -> String {
        jsonString([
            "profile_core": brainState.profileCore,
            "active_goals": brainState.activeGoals,
            "relevant_memories": brainState.relevantMemories,
            "session_biases": brainState.sessionBiases,
            "reaction_weights": reactionWeightsJSONObject(brainState.reactionWeights),
            "identity": [
                "role": brainState.identityProfile.role.rawValue,
                "posture": brainState.identityProfile.posture.rawValue,
                "initiative": brainState.identityProfile.initiative.rawValue,
                "confidence_ceiling": brainState.identityProfile.confidenceCeiling
            ],
            "boundary_policy": [
                "mode": brainState.boundaryPolicy.mode.rawValue,
                "constraints": brainState.boundaryPolicy.activeConstraints.map(\.rawValue),
                "required_confirmations": brainState.boundaryPolicy.requiredConfirmations
            ],
            "calibration": [
                "status": brainState.calibrationState.status.rawValue,
                "alerts": brainState.calibrationState.alerts.map(\.rawValue)
            ]
        ])
    }

    private static func reactionWeightsJSONObject(
        _ weights: BASReactionWeights
    ) -> [String: Double] {
        let allWeights: [(String, Double)] = [
            ("brief", weights.briefLanguage),
            ("warm_direct", weights.warmDirectTone),
            ("low_load", weights.lowCognitiveLoad),
            ("interruptive", weights.interruptiveActionBias),
            ("boundary", weights.boundaryNamingBias),
            ("tradeoff", weights.tradeoffClarityBias)
        ]

        let prioritized = allWeights
            .filter { $0.1 >= 0.6 }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0 < rhs.0
                }
                return lhs.1 > rhs.1
            }

        let retained = Array((prioritized.isEmpty ? allWeights.sorted { $0.1 > $1.1 } : prioritized).prefix(3))
        return Dictionary(uniqueKeysWithValues: retained)
    }

    private static func jsonString(
        _ payload: [String: Any]
    ) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }
}
