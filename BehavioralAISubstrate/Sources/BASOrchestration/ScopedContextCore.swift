import Foundation
import BASMemory
import BASRuntimeCore

public struct BASScopedContextState: Codable, Sendable, Equatable {
    public var userProfile: [String]
    public var activeGoals: [String]
    public var localBiases: [String]
    public var autoMemory: [String]
    public var dominantReactionWeight: String
    public var boundaryMode: String?

    public init(
        userProfile: [String],
        activeGoals: [String],
        localBiases: [String],
        autoMemory: [String],
        dominantReactionWeight: String,
        boundaryMode: String? = nil
    ) {
        self.userProfile = userProfile
        self.activeGoals = activeGoals
        self.localBiases = localBiases
        self.autoMemory = autoMemory
        self.dominantReactionWeight = dominantReactionWeight
        self.boundaryMode = boundaryMode
    }
}

public enum BASScopedContextCompiler {
    public static func compile(
        kind: BASAdaptiveTraceKind,
        strategy: BASAdaptiveTaskStrategy?,
        brainState: BASDecisionBrainState?
    ) -> BASScopedContextState? {
        guard let brainState, !brainState.isEmpty else { return nil }

        let compactMobileSurface = strategy?.runtimeGear == .low && (kind == .quick || kind == .reminder)
        if compactMobileSurface {
            return BASScopedContextState(
                userProfile: Array(brainState.profileCore.prefix(1)),
                activeGoals: Array(brainState.activeGoals.prefix(1)),
                localBiases: Array(brainState.sessionBiases.prefix(1)),
                autoMemory: Array(brainState.relevantMemories.prefix(1)),
                dominantReactionWeight: brainState.reactionWeights.dominantKey.rawValue,
                boundaryMode: brainState.boundaryPolicy.mode.rawValue
            )
        }

        return BASScopedContextState(
            userProfile: brainState.profileCore,
            activeGoals: brainState.activeGoals,
            localBiases: brainState.sessionBiases,
            autoMemory: Array(brainState.relevantMemories.prefix(3)),
            dominantReactionWeight: brainState.reactionWeights.dominantKey.rawValue
        )
    }

    public static func jsonString(
        for state: BASScopedContextState
    ) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(state),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }
}
