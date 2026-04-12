import BASHostKit
import Foundation

enum BeforeProductCompatibility {
    static let workflowBehavior = BeforeProductLanguage.workflowBehavior
    static let hostCognition = BeforeProductLanguage.hostCognition
    static let hostPresentation = BeforeProductLanguage.hostPresentation
    static let hostLifecycleBehavior = BeforeProductLanguage.hostLifecycleBehavior
    static let predictiveInterventionBehavior = BeforeProductLanguage.predictiveInterventionBehavior
    static let referencePromptBehavior = BeforeProductLanguage.referencePromptBehavior
    static let memoryDerivationBehavior = BeforeProductLanguage.memoryDerivationBehavior
    static let executionProfileBehavior = BeforeProductLanguage.executionProfileBehavior

    static let hostConfiguration = BASHostConfiguration(
        runtimeProfileID: "before.local-cognition",
        policyProfileID: "before.product-policy",
        prefersPureLocal: true,
        console: .generic,
        lifecycleBehavior: hostLifecycleBehavior,
        workflowBehavior: workflowBehavior,
        cognitionBehavior: hostCognition,
        presentation: hostPresentation
    )

    static let currentBrainBootstrapBehavior = hostLifecycleBehavior.currentBrainBootstrapBehavior
    static let lifecycleBootstrapBehavior = hostLifecycleBehavior.bootstrapBehavior
    static let projectionRefreshLimits = hostLifecycleBehavior.projectionRefreshLimits
    static let substrateCognitionBehavior = hostCognition.substrateBehavior
    static let memoryTrustBehavior = substrateCognitionBehavior.memoryTrust
    static let predictiveInterventionPresentation = hostPresentation.predictiveIntervention

    static func substrateEntryIntentKindID(_ kind: DecisionIntentKind) -> String {
        substrateEntryIntentKindID(rawValue: kind.rawValue)
    }

    static func substrateEntryIntentKindID(rawValue: String) -> String {
        BeforeLegacyMigration.normalizedEntryIntentKindIdentifier(rawValue)
    }

    static func substrateModeID(rawValue: String) -> String {
        BeforeLegacyMigration.normalizedModeIdentifier(rawValue)
    }

    static func hostModeID(rawValue: String) -> String {
        BeforeLegacyMigration.normalizedHostModeIdentifier(rawValue)
    }

    static func reactionWeights(for mode: DecisionMode) -> BASReactionWeights {
        BeforeProductLanguage.reactionWeights(for: mode)
    }

    static func identityProfile(for mode: DecisionMode) -> BASIdentityProfile {
        BeforeProductLanguage.identityProfile(for: mode)
    }

    static func providerObservationNarrative(
        forKindID kindID: String
    ) -> BASAppleProviderObservationNarrative? {
        workflowBehavior.providerObservationNarrative(forKindID: kindID)
    }

    static func makeHostRuntime() -> BASHostRuntime {
        BASHostRuntime(configuration: hostConfiguration)
    }
}
