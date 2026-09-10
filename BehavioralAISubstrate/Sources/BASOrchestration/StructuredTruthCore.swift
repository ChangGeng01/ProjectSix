import Foundation
import BASMemory
import BASRuntimeCore
import BASPolicy

public struct BASStructuredTruthBehavior: Codable, Sendable, Equatable {
    public var modeNamesByKindID: [String: String]
    public var kernelPersonaRulesByKindID: [String: String]

    public init(
        modeNamesByKindID: [String: String] = [
            BASAdaptiveTraceKind.primaryID: BASDecisionMode.primary.identifier,
            BASAdaptiveTraceKind.comparativeID: BASDecisionMode.comparative.identifier,
            BASAdaptiveTraceKind.reflectiveID: BASDecisionMode.reflective.identifier,
            BASAdaptiveTraceKind.selectionID: BASAdaptiveTraceKind.selectionID
        ],
        kernelPersonaRulesByKindID: [String: String] = [
            BASAdaptiveTraceKind.primaryID: "Keep the active guidance short, calm, and bounded.",
            BASAdaptiveTraceKind.comparativeID: "Compare the active pressures without collapsing them into a verdict.",
            BASAdaptiveTraceKind.reflectiveID: "Reflect the underlying pattern without becoming dramatic or clinical.",
            BASAdaptiveTraceKind.selectionID: "Choose only from retained candidates and do not invent a new option."
        ]
    ) {
        self.modeNamesByKindID = modeNamesByKindID
        self.kernelPersonaRulesByKindID = kernelPersonaRulesByKindID
    }

    public static let generic = BASStructuredTruthBehavior()

    public func modeName(
        for kind: BASAdaptiveTraceKind
    ) -> String {
        value(in: modeNamesByKindID, for: kind)
            ?? fallbackModeName(for: kind)
    }

    public func kernelPersonaRule(
        for kind: BASAdaptiveTraceKind
    ) -> String {
        value(in: kernelPersonaRulesByKindID, for: kind)
            ?? fallbackKernelPersonaRule(for: kind)
    }

    private func fallbackModeName(
        for kind: BASAdaptiveTraceKind
    ) -> String {
        switch kind {
        case .primary:
            BASDecisionMode.primary.identifier
        case .comparative:
            BASDecisionMode.comparative.identifier
        case .reflective:
            BASDecisionMode.reflective.identifier
        case .selection:
            BASAdaptiveTraceKind.selectionID
        }
    }

    private func fallbackKernelPersonaRule(
        for kind: BASAdaptiveTraceKind
    ) -> String {
        switch kind {
        case .primary:
            "Keep the active guidance short, calm, and bounded."
        case .comparative:
            "Compare the active pressures without collapsing them into a verdict."
        case .reflective:
            "Reflect the underlying pattern without becoming dramatic or clinical."
        case .selection:
            "Choose only from retained candidates and do not invent a new option."
        }
    }

    private func value<T>(
        in mapping: [String: T],
        for kind: BASAdaptiveTraceKind
    ) -> T? {
        for candidate in [kind.identifier, kind.rawValue] {
            if let value = mapping[candidate] {
                return value
            }
        }
        return nil
    }
}

public struct BASStructuredTruthRequest: Codable, Sendable, Equatable {
    public var kind: BASAdaptiveTraceKind
    public var brainState: BASDecisionBrainState?
    public var selectionSurfaceMode: BASDecisionMode?
    public var behavior: BASStructuredTruthBehavior

    public init(
        kind: BASAdaptiveTraceKind,
        brainState: BASDecisionBrainState?,
        selectionSurfaceMode: BASDecisionMode? = nil,
        behavior: BASStructuredTruthBehavior = .generic
    ) {
        self.kind = kind
        self.brainState = brainState
        self.selectionSurfaceMode = selectionSurfaceMode
        self.behavior = behavior
    }
}

public enum BASStructuredTruthCompiler {
    public static func truthState(
        for request: BASStructuredTruthRequest
    ) -> BASStructuredTruthState? {
        switch request.kind {
        case .primary, .comparative, .reflective:
            guard let brainState = request.brainState else { return nil }
            return governedTruthState(kind: request.kind, brainState: brainState, behavior: request.behavior)
        case .selection:
            return selectionTruthState(
                brainState: request.brainState,
                surfaceMode: request.selectionSurfaceMode,
                behavior: request.behavior
            )
        }
    }

    private static func governedTruthState(
        kind: BASAdaptiveTraceKind,
        brainState: BASDecisionBrainState,
        behavior: BASStructuredTruthBehavior
    ) -> BASStructuredTruthState {
        let personaRules = Array(
            orderedUnique(
                [behavior.kernelPersonaRule(for: kind), brainState.identityProfile.relationshipBoundary] +
                Array(brainState.sessionBiases.prefix(1))
            )
            .prefix(3)
        )

        return BASStructuredTruthState(
            mode: behavior.modeName(for: kind),
            currentGoal: brainState.activeGoals.first,
            allowedActions: Array(brainState.boundaryPolicy.allowedActionClasses.prefix(3)),
            forbiddenActions: Array(brainState.boundaryPolicy.blockedActionClasses.prefix(2)),
            personaRules: personaRules,
            sessionFacts: [
                "boundary_mode": brainState.boundaryPolicy.mode.rawValue,
                "dominant_reaction_weight": brainState.reactionWeights.dominantKey.rawValue
            ]
        )
    }

    private static func selectionTruthState(
        brainState: BASDecisionBrainState?,
        surfaceMode: BASDecisionMode?,
        behavior: BASStructuredTruthBehavior
    ) -> BASStructuredTruthState {
        let boundaryPolicy = brainState?.boundaryPolicy ?? BASBoundaryPolicyState.default(riskLevel: .low)
        let relationshipRule = brainState.map { [$0.identityProfile.relationshipBoundary] } ?? []
        let sessionBiasRule = Array(brainState?.sessionBiases.prefix(1) ?? [])
        let personaRules = Array(
            orderedUnique(
                [behavior.kernelPersonaRule(for: .selection)] +
                relationshipRule +
                sessionBiasRule
            )
            .prefix(3)
        )

        var sessionFacts: [String: String] = [:]
        if let surfaceMode {
            sessionFacts["surface_mode"] = surfaceMode.identifier
        }
        if let brainState {
            sessionFacts["boundary_mode"] = brainState.boundaryPolicy.mode.rawValue
        }

        return BASStructuredTruthState(
            mode: behavior.modeName(for: .selection),
            currentGoal: brainState?.activeGoals.first,
            allowedActions: Array(boundaryPolicy.allowedActionClasses.prefix(2)),
            forbiddenActions: Array(boundaryPolicy.blockedActionClasses.prefix(2)),
            personaRules: personaRules,
            sessionFacts: sessionFacts
        )
    }

    private static func orderedUnique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values where seen.insert(value).inserted {
            ordered.append(value)
        }
        return ordered
    }
}
