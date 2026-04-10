import Foundation
import BASMemory
import BASPolicy

enum DecisionBoundaryPolicyEngine {
    static func evaluate(
        mode: DecisionMode,
        source: BrainStateUpdateSource,
        sourceSurface: DecisionIntentSourceSurface,
        riskLevel: InterventionRiskLevel,
        identityProfile: DecisionIdentityProfile,
        brainState: DecisionBrainState,
        taskGraph: DecisionTaskGraphSnapshot?
    ) -> DecisionBoundaryPolicyState {
        let taskGraphHint = taskGraph.map { snapshot in
            BASTaskGraphHint(
                headline: snapshot.nextActionHint,
                activeNodeCount: snapshot.tasks.filter { $0.status != .completed }.count,
                hasResumeCandidate: !snapshot.tasks.isEmpty,
                resumeHint: snapshot.nextActionHint
            )
        }

        return BASBoundaryPolicyEvaluator.evaluate(
            mode: substrateMode(from: mode),
            sourceSurface: resolvedSurface(source: source, sourceSurface: sourceSurface),
            riskLevel: substrateRiskLevel(from: riskLevel),
            identityProfile: identityProfile,
            brainState: brainState,
            taskGraphHint: taskGraphHint
        )
    }

    private static func resolvedSurface(
        source: BrainStateUpdateSource,
        sourceSurface: DecisionIntentSourceSurface
    ) -> BASInteractionSurface {
        if source == .notification { return .notification }
        switch sourceSurface {
        case .app:
            return .app
        case .watch:
            return .watch
        case .widget:
            return .widget
        case .shortcut:
            return .shortcut
        case .siri:
            return .siri
        case .notification:
            return .notification
        }
    }
}
