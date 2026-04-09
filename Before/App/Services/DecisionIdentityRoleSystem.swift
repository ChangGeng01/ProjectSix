import Foundation

enum DecisionIdentityRoleSystem {
    static func resolve(
        mode: DecisionMode,
        source: BrainStateUpdateSource,
        sourceSurface: DecisionIntentSourceSurface,
        riskLevel: InterventionRiskLevel
    ) -> DecisionIdentityProfile {
        var profile = DecisionIdentityProfile.default(for: mode)

        if source == .notification || sourceSurface == .notification {
            profile = DecisionIdentityProfile(
                role: .predictiveSentinel,
                posture: riskLevel == .high ? .protective : .coaching,
                initiative: riskLevel == .high ? .assertive : .guided,
                confidenceCeiling: riskLevel == .high ? 0.62 : 0.58,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Interrupt momentum, but do not overtake the user's agency."
            )
        }

        if sourceSurface == .watch {
            return DecisionIdentityProfile(
                role: profile.role == .mirrorWitness ? .pauseCompanion : profile.role,
                posture: riskLevel == .high ? .protective : profile.posture,
                initiative: profile.initiative == .assertive ? .guided : profile.initiative,
                confidenceCeiling: min(profile.confidenceCeiling, 0.64),
                canAdvise: profile.canAdvise,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Keep the watch surface lightweight, interruptive, and local."
            )
        }

        if riskLevel == .high {
            return DecisionIdentityProfile(
                role: profile.role,
                posture: .protective,
                initiative: profile.role == .mirrorWitness ? .guided : .assertive,
                confidenceCeiling: min(profile.confidenceCeiling, 0.66),
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Slow the decision down before offering any stronger interpretation."
            )
        }

        return profile
    }
}
