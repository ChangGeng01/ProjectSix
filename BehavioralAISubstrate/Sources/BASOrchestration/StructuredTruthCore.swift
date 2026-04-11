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
            BASAdaptiveTraceKind.reminderID: "reminder"
        ],
        kernelPersonaRulesByKindID: [String: String] = [
            BASAdaptiveTraceKind.primaryID: "Keep the active guidance short, calm, and bounded.",
            BASAdaptiveTraceKind.comparativeID: "Compare the active pressures without collapsing them into a verdict.",
            BASAdaptiveTraceKind.reflectiveID: "Reflect the underlying pattern without becoming dramatic or clinical.",
            BASAdaptiveTraceKind.reminderID: "Choose only from retained candidates and do not invent a new option."
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
        case .quick:
            BASDecisionMode.primary.identifier
        case .balance:
            BASDecisionMode.comparative.identifier
        case .mirror:
            BASDecisionMode.reflective.identifier
        case .reminder:
            "reminder"
        }
    }

    private func fallbackKernelPersonaRule(
        for kind: BASAdaptiveTraceKind
    ) -> String {
        switch kind {
        case .quick:
            "Keep the active guidance short, calm, and bounded."
        case .balance:
            "Compare the active pressures without collapsing them into a verdict."
        case .mirror:
            "Reflect the underlying pattern without becoming dramatic or clinical."
        case .reminder:
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
    public var reminderSurfaceMode: BASDecisionMode?
    public var behavior: BASStructuredTruthBehavior

    public init(
        kind: BASAdaptiveTraceKind,
        brainState: BASDecisionBrainState?,
        reminderSurfaceMode: BASDecisionMode? = nil,
        behavior: BASStructuredTruthBehavior = .generic
    ) {
        self.kind = kind
        self.brainState = brainState
        self.reminderSurfaceMode = reminderSurfaceMode
        self.behavior = behavior
    }
}

public enum BASStructuredTruthCompiler {
    public static func truthState(
        for request: BASStructuredTruthRequest
    ) -> BASStructuredTruthState? {
        switch request.kind {
        case .quick, .balance, .mirror:
            guard let brainState = request.brainState else { return nil }
            return governedTruthState(kind: request.kind, brainState: brainState, behavior: request.behavior)
        case .reminder:
            return reminderTruthState(
                brainState: request.brainState,
                surfaceMode: request.reminderSurfaceMode,
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

    private static func reminderTruthState(
        brainState: BASDecisionBrainState?,
        surfaceMode: BASDecisionMode?,
        behavior: BASStructuredTruthBehavior
    ) -> BASStructuredTruthState {
        let boundaryPolicy = brainState?.boundaryPolicy ?? BASBoundaryPolicyState.default(riskLevel: .low)
        let relationshipRule = brainState.map { [$0.identityProfile.relationshipBoundary] } ?? []
        let sessionBiasRule = Array(brainState?.sessionBiases.prefix(1) ?? [])
        let personaRules = Array(
            orderedUnique(
                [behavior.kernelPersonaRule(for: .reminder)] +
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
            mode: behavior.modeName(for: .reminder),
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
