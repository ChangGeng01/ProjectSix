import Foundation
import BASMemory
import BASRuntimeCore
import BASPolicy

public struct BASStructuredTruthRequest: Codable, Sendable, Equatable {
    public var kind: BASAdaptiveTraceKind
    public var brainState: BASDecisionBrainState?
    public var reminderSurfaceMode: BASDecisionMode?

    public init(
        kind: BASAdaptiveTraceKind,
        brainState: BASDecisionBrainState?,
        reminderSurfaceMode: BASDecisionMode? = nil
    ) {
        self.kind = kind
        self.brainState = brainState
        self.reminderSurfaceMode = reminderSurfaceMode
    }
}

public enum BASStructuredTruthCompiler {
    public static func truthState(
        for request: BASStructuredTruthRequest
    ) -> BASStructuredTruthState? {
        switch request.kind {
        case .quick, .balance, .mirror:
            guard let brainState = request.brainState else { return nil }
            return governedTruthState(kind: request.kind, brainState: brainState)
        case .reminder:
            return reminderTruthState(
                brainState: request.brainState,
                surfaceMode: request.reminderSurfaceMode
            )
        }
    }

    private static func governedTruthState(
        kind: BASAdaptiveTraceKind,
        brainState: BASDecisionBrainState
    ) -> BASStructuredTruthState {
        let personaRules = Array(
            orderedUnique(
                [kernelPersonaRule(for: kind), brainState.identityProfile.relationshipBoundary] +
                Array(brainState.sessionBiases.prefix(1))
            )
            .prefix(3)
        )

        return BASStructuredTruthState(
            mode: modeName(for: kind),
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
        surfaceMode: BASDecisionMode?
    ) -> BASStructuredTruthState {
        let boundaryPolicy = brainState?.boundaryPolicy ?? BASBoundaryPolicyState.default(riskLevel: .low)
        let relationshipRule = brainState.map { [$0.identityProfile.relationshipBoundary] } ?? []
        let sessionBiasRule = Array(brainState?.sessionBiases.prefix(1) ?? [])
        let personaRules = Array(
            orderedUnique(
                [kernelPersonaRule(for: .reminder)] +
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
            mode: modeName(for: .reminder),
            currentGoal: brainState?.activeGoals.first,
            allowedActions: Array(boundaryPolicy.allowedActionClasses.prefix(2)),
            forbiddenActions: Array(boundaryPolicy.blockedActionClasses.prefix(2)),
            personaRules: personaRules,
            sessionFacts: sessionFacts
        )
    }

    private static func modeName(
        for kind: BASAdaptiveTraceKind
    ) -> String {
        switch kind {
        case .quick:
            BASDecisionMode.quick.identifier
        case .balance:
            BASDecisionMode.balance.identifier
        case .mirror:
            BASDecisionMode.mirror.identifier
        case .reminder:
            "reminder"
        }
    }

    private static func kernelPersonaRule(
        for kind: BASAdaptiveTraceKind
    ) -> String {
        switch kind {
        case .quick:
            "Keep the interruption short, calm, and non-shaming."
        case .balance:
            "Clarify trade-offs without turning the board into a verdict."
        case .mirror:
            "Reflect the pattern without becoming dramatic or therapeutic."
        case .reminder:
            "Choose from retained reminders only and do not invent new reminders."
        }
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
