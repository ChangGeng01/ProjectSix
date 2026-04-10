import Foundation
import BASMemory
import BASPolicy

enum DecisionIdentityRoleSystem {
    static func resolve(
        mode: DecisionMode,
        source: BrainStateUpdateSource,
        sourceSurface: DecisionIntentSourceSurface,
        riskLevel: InterventionRiskLevel
    ) -> DecisionIdentityProfile {
        return BASIdentityRoleResolver.resolve(
            mode: substrateMode(from: mode),
            sourceSurface: resolvedSurface(source: source, sourceSurface: sourceSurface),
            riskLevel: substrateRiskLevel(from: riskLevel)
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
