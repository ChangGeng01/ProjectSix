// MARK: - HostPresentationConfigurationsCore — chapter 二百八十六 / M773
//
// Phase Alpha 第十二刀(BASHostKit god file 2nd cut):从
// HostKitCore.swift 抽出 host presentation / titles / behavior
// configuration cluster — Phase Alpha 第三个 god file 第二次拆分。
//
// 抽出 types:
//   - `BASHostConsoleConfiguration` — console config
//   - `BASHostWorkflowTitles` — workflow title strings
//   - `BASHostSurfaceTitles` — surface title strings
//   - `BASHostSessionTitles` — session title strings
//   - `BASHostFollowUpActions` — follow-up action templates
//   - `BASHostLifecyclePresentation` — lifecycle presentation
//   - `BASHostNoticeTemplates` — notice templates
//   - `BASHostPredictiveInterventionPresentation` — predictive
//     intervention presentation
//   - `BASHostLifecycleBehaviorConfiguration` — lifecycle behavior
//   - `BASHostIntegrationError` — host integration error enum
//   - `BASHostWorkflowBehaviorConfiguration` — workflow behavior
//   - `BASHostCognitionBehaviorConfiguration` — cognition behavior
//   - `BASHostPresentationConfiguration` — top-level presentation
//     aggregator
//
// **0 behavior change**:types literal-identical to pre-extraction
// versions。Module DAG 不变(BASHostKit internal split)。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth
//   - chapter 二百一(架构 guardrail)+ chapter 一百八十五 anti-magic-number 全保
//   - canonical default factories 不变,所有调用者保持 API 兼容

import Foundation
@_exported import BASAdmin
@_exported import BASAppleLifecycleKit
@_exported import BASEvaluation
@_exported import BASMemory
@_exported import BASObservability
@_exported import BASOrchestration
@_exported import BASPolicy
@_exported import BASRuntimeCore

public struct BASHostConsoleConfiguration: Codable, Equatable, Sendable {
    public static let generic = BASHostConsoleConfiguration()

    public var isEnabled: Bool
    public var productionEnabled: Bool
    public var debugEntryPointTitle: String

    public init(
        isEnabled: Bool = true,
        productionEnabled: Bool = false,
        debugEntryPointTitle: String = "Host Console"
    ) {
        self.isEnabled = isEnabled
        self.productionEnabled = productionEnabled
        self.debugEntryPointTitle = debugEntryPointTitle
    }
}

public struct BASHostWorkflowTitles: Codable, Equatable, Sendable {
    public var primary: String
    public var comparative: String
    public var reflective: String

    private enum CodingKeys: String, CodingKey {
        case primary
        case comparative
        case reflective
    }

    public init(
        primary: String = "Primary",
        comparative: String = "Comparative",
        reflective: String = "Reflective"
    ) {
        self.primary = primary
        self.comparative = comparative
        self.reflective = reflective
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primary = try container.decodeIfPresent(String.self, forKey: .primary)
            ?? "Primary"
        comparative = try container.decodeIfPresent(String.self, forKey: .comparative)
            ?? "Comparative"
        reflective = try container.decodeIfPresent(String.self, forKey: .reflective)
            ?? "Reflective"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(primary, forKey: .primary)
        try container.encode(comparative, forKey: .comparative)
        try container.encode(reflective, forKey: .reflective)
    }

    public func title(for profile: BASHostWorkflowProfile) -> String {
        switch profile {
        case .primary:
            primary
        case .comparative:
            comparative
        case .reflective:
            reflective
        }
    }
}

public struct BASHostSurfaceTitles: Codable, Equatable, Sendable {
    public var application: String
    public var wearable: String
    public var widget: String
    public var shortcut: String
    public var voiceAssistant: String
    public var notification: String
    public var system: String

    public init(
        application: String = "Application",
        wearable: String = "Wearable",
        widget: String = "Widget",
        shortcut: String = "Shortcut",
        voiceAssistant: String = "Voice Assistant",
        notification: String = "Notification",
        system: String = "System"
    ) {
        self.application = application
        self.wearable = wearable
        self.widget = widget
        self.shortcut = shortcut
        self.voiceAssistant = voiceAssistant
        self.notification = notification
        self.system = system
    }

    public func title(for surface: BASHostSurface) -> String {
        switch surface {
        case .application:
            application
        case .wearable:
            wearable
        case .widget:
            widget
        case .shortcut:
            shortcut
        case .voiceAssistant:
            voiceAssistant
        case .notification:
            notification
        case .system:
            system
        }
    }
}

public struct BASHostSessionTitles: Codable, Equatable, Sendable {
    public var primary: String
    public var comparative: String
    public var reflective: String
    public var initialAppearance: String
    public var sceneActive: String

    private enum CodingKeys: String, CodingKey {
        case primary
        case comparative
        case reflective
        case initialAppearance
        case sceneActive
    }

    public init(
        primary: String = "Primary",
        comparative: String = "Comparative",
        reflective: String = "Reflective",
        initialAppearance: String = "Initial Appearance",
        sceneActive: String = "Scene Active"
    ) {
        self.primary = primary
        self.comparative = comparative
        self.reflective = reflective
        self.initialAppearance = initialAppearance
        self.sceneActive = sceneActive
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primary = try container.decodeIfPresent(String.self, forKey: .primary)
            ?? "Primary"
        comparative = try container.decodeIfPresent(String.self, forKey: .comparative)
            ?? "Comparative"
        reflective = try container.decodeIfPresent(String.self, forKey: .reflective)
            ?? "Reflective"
        initialAppearance = try container.decodeIfPresent(String.self, forKey: .initialAppearance)
            ?? "Initial Appearance"
        sceneActive = try container.decodeIfPresent(String.self, forKey: .sceneActive)
            ?? "Scene Active"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(primary, forKey: .primary)
        try container.encode(comparative, forKey: .comparative)
        try container.encode(reflective, forKey: .reflective)
        try container.encode(initialAppearance, forKey: .initialAppearance)
        try container.encode(sceneActive, forKey: .sceneActive)
    }

    public func title(for profile: BASHostWorkflowProfile) -> String {
        switch profile {
        case .primary:
            primary
        case .comparative:
            comparative
        case .reflective:
            reflective
        }
    }

    public func title(for phase: BASHostLifecyclePhase) -> String {
        switch phase {
        case .initialAppearance:
            initialAppearance
        case .sceneActive:
            sceneActive
        }
    }
}

public struct BASHostFollowUpActions: Codable, Equatable, Sendable {
    public var primary: [String]
    public var comparative: [String]
    public var reflective: [String]
    public var highRiskEscalation: [String]

    private enum CodingKeys: String, CodingKey {
        case primary
        case comparative
        case reflective
        case highRiskEscalation
    }

    public init(
        primary: [String] = ["Capture the active context", "Choose one next move"],
        comparative: [String] = ["Compare the active pressures", "Name one constraint"],
        reflective: [String] = ["Describe the active pattern", "Keep one anchor visible"],
        highRiskEscalation: [String] = ["Require confirmation"]
    ) {
        self.primary = primary
        self.comparative = comparative
        self.reflective = reflective
        self.highRiskEscalation = highRiskEscalation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primary = try container.decodeIfPresent([String].self, forKey: .primary)
            ?? ["Capture the active context", "Choose one next move"]
        comparative = try container.decodeIfPresent([String].self, forKey: .comparative)
            ?? ["Compare the active pressures", "Name one constraint"]
        reflective = try container.decodeIfPresent([String].self, forKey: .reflective)
            ?? ["Describe the active pattern", "Keep one anchor visible"]
        highRiskEscalation = try container.decodeIfPresent([String].self, forKey: .highRiskEscalation)
            ?? ["Require confirmation"]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(primary, forKey: .primary)
        try container.encode(comparative, forKey: .comparative)
        try container.encode(reflective, forKey: .reflective)
        try container.encode(highRiskEscalation, forKey: .highRiskEscalation)
    }

    public func actions(for profile: BASHostWorkflowProfile) -> [String] {
        switch profile {
        case .primary:
            primary
        case .comparative:
            comparative
        case .reflective:
            reflective
        }
    }
}

public struct BASHostLifecyclePresentation: Codable, Equatable, Sendable {
    public var initialAppearancePromptFallback: String
    public var sceneActivePromptFallback: String
    public var refreshMemoryProjectionNotice: String
    public var refreshCurrentBrainNotice: String
    public var presentPendingReflectionNotice: String
    public var consumePendingLaunchRequestNotice: String
    public var restoreActiveWorkspaceNotice: String
    public var refreshPredictedInterventionNotice: String
    public var syncWidgetSnapshotNotice: String
    public var loadCurrentBrainFollowUp: String
    public var resumeStructuredWorkspaceFollowUp: String
    public var recomputeGuardedInterventionFollowUp: String

    public init(
        initialAppearancePromptFallback: String = "Prepare state for the first surface presentation.",
        sceneActivePromptFallback: String = "Refresh state and resume the active session.",
        refreshMemoryProjectionNotice: String = "Refresh substrate projection",
        refreshCurrentBrainNotice: String = "Refresh substrate state",
        presentPendingReflectionNotice: String = "Present deferred follow-up",
        consumePendingLaunchRequestNotice: String = "Consume deferred entry request",
        restoreActiveWorkspaceNotice: String = "Restore active workspace",
        refreshPredictedInterventionNotice: String = "Refresh predictive intervention",
        syncWidgetSnapshotNotice: String = "Sync shared snapshot",
        loadCurrentBrainFollowUp: String = "Load current state for presentation",
        resumeStructuredWorkspaceFollowUp: String = "Resume the active session",
        recomputeGuardedInterventionFollowUp: String = "Recompute the guarded intervention state"
    ) {
        self.initialAppearancePromptFallback = initialAppearancePromptFallback
        self.sceneActivePromptFallback = sceneActivePromptFallback
        self.refreshMemoryProjectionNotice = refreshMemoryProjectionNotice
        self.refreshCurrentBrainNotice = refreshCurrentBrainNotice
        self.presentPendingReflectionNotice = presentPendingReflectionNotice
        self.consumePendingLaunchRequestNotice = consumePendingLaunchRequestNotice
        self.restoreActiveWorkspaceNotice = restoreActiveWorkspaceNotice
        self.refreshPredictedInterventionNotice = refreshPredictedInterventionNotice
        self.syncWidgetSnapshotNotice = syncWidgetSnapshotNotice
        self.loadCurrentBrainFollowUp = loadCurrentBrainFollowUp
        self.resumeStructuredWorkspaceFollowUp = resumeStructuredWorkspaceFollowUp
        self.recomputeGuardedInterventionFollowUp = recomputeGuardedInterventionFollowUp
    }
}

public struct BASHostNoticeTemplates: Codable, Equatable, Sendable {
    public var enteredWorkflow: String
    public var runtimeProfile: String
    public var reopenFollowUpAction: String
    public var emptyPromptGoalFallback: String

    public init(
        enteredWorkflow: String = "{surface} entered {workflow}.",
        runtimeProfile: String = "Runtime profile {runtimeProfile} is active for the current integration.",
        reopenFollowUpAction: String = "Reopen in {workflow}",
        emptyPromptGoalFallback: String = "Keep the active state clear and bounded."
    ) {
        self.enteredWorkflow = enteredWorkflow
        self.runtimeProfile = runtimeProfile
        self.reopenFollowUpAction = reopenFollowUpAction
        self.emptyPromptGoalFallback = emptyPromptGoalFallback
    }
}

public struct BASHostPredictiveInterventionPresentation: Codable, Equatable, Sendable {
    public var mediumRiskTitle: String
    public var mediumRiskDetail: String
    public var highRiskTitle: String
    public var highRiskDetail: String
    public var reopenRiskDetail: String
    public var fallbackReopenSuggestionDetail: String
    public var defaultReason: String

    public init(
        mediumRiskTitle: String = "A lower-pressure next step may help here.",
        mediumRiskDetail: String = "Current signals suggest lowering pressure on the next step.",
        highRiskTitle: String = "This state may need stronger confirmation.",
        highRiskDetail: String = "Current signals suggest increasing confirmation and narrowing the execution path.",
        reopenRiskDetail: String = "This reopen path is carrying extra risk, so the integration is tightening the next step.",
        fallbackReopenSuggestionDetail: String = "A prior hold suggests reopening with a narrower path.",
        defaultReason: String = "Risk-aware policy prefers a lower-pressure path here."
    ) {
        self.mediumRiskTitle = mediumRiskTitle
        self.mediumRiskDetail = mediumRiskDetail
        self.highRiskTitle = highRiskTitle
        self.highRiskDetail = highRiskDetail
        self.reopenRiskDetail = reopenRiskDetail
        self.fallbackReopenSuggestionDetail = fallbackReopenSuggestionDetail
        self.defaultReason = defaultReason
    }
}

public struct BASHostLifecycleBehaviorConfiguration: Codable, Equatable, Sendable {
    public static let generic = BASHostLifecycleBehaviorConfiguration(
        bootstrapBehavior: .generic,
        currentBrainBootstrapBehavior: .generic,
        predictiveInterventionBehavior: .generic,
        projectionRefreshLimits: BASAppleMemoryProjectionRefreshLimits()
    )

    public var bootstrapBehavior: BASAppleLifecycleBootstrapBehavior
    public var currentBrainBootstrapBehavior: BASCurrentBrainBootstrapBehavior
    public var predictiveInterventionBehavior: BASApplePredictiveInterventionBehavior
    public var projectionRefreshLimits: BASAppleMemoryProjectionRefreshLimits

    @available(*, unavailable, message: "Use .generic or provide explicit lifecycle behavior.")
    public init() {
        fatalError("Unavailable")
    }

    public init(
        bootstrapBehavior: BASAppleLifecycleBootstrapBehavior = BASAppleLifecycleBootstrapBehavior(),
        currentBrainBootstrapBehavior: BASCurrentBrainBootstrapBehavior = BASCurrentBrainBootstrapBehavior(),
        predictiveInterventionBehavior: BASApplePredictiveInterventionBehavior = BASApplePredictiveInterventionBehavior(),
        projectionRefreshLimits: BASAppleMemoryProjectionRefreshLimits = BASAppleMemoryProjectionRefreshLimits()
    ) {
        self.bootstrapBehavior = bootstrapBehavior
        self.currentBrainBootstrapBehavior = currentBrainBootstrapBehavior
        self.predictiveInterventionBehavior = predictiveInterventionBehavior
        self.projectionRefreshLimits = projectionRefreshLimits
    }
}

public enum BASHostIntegrationError:
    Error, Equatable, Sendable, Codable
{
    case missingWorkflowModeMapping(profileID: String)
    case unsupportedWorkflowModeID(profileID: String, modeID: String)
    case missingWorkflowMemorySource(profileID: String)
    case unsupportedWorkflowMemorySourceID(profileID: String, sourceID: String)
    case missingInteractiveRetrievalMode(profileID: String)
    case missingSessionKindMemorySource(kindID: String)
    case unsupportedSessionKindMemorySourceID(kindID: String, sourceID: String)
    case missingSessionKindRetrievalMode(kindID: String)
}

public struct BASHostWorkflowBehaviorConfiguration: Codable, Equatable, Sendable {
    public static let generic = BASHostWorkflowBehaviorConfiguration(
        modeIDsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASDecisionMode.primaryID,
            BASHostWorkflowProfile.comparative.rawValue: BASDecisionMode.comparativeID,
            BASHostWorkflowProfile.reflective.rawValue: BASDecisionMode.reflectiveID
        ],
        templateIDsByProfileID: [:],
        memorySourceIDsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASMemorySource.pattern.rawValue,
            BASHostWorkflowProfile.comparative.rawValue: BASMemorySource.pattern.rawValue,
            BASHostWorkflowProfile.reflective.rawValue: BASMemorySource.pattern.rawValue
        ],
        interactiveRetrievalModeByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASRetrievalMode.adaptive.rawValue,
            BASHostWorkflowProfile.comparative.rawValue: BASRetrievalMode.adaptive.rawValue,
            BASHostWorkflowProfile.reflective.rawValue: BASRetrievalMode.adaptive.rawValue
        ],
        providerObservationNarrativesByKindID: [:],
        memorySourceIDsBySessionKindID: [:],
        retrievalModeIDsBySessionKindID: [:],
        defaultMemorySourceIDsBySessionKindID: [
            BASHostSessionKind.ambient.rawValue: BASMemorySource.pattern.rawValue,
            BASHostSessionKind.reopen.rawValue: BASMemorySource.archive.rawValue,
            BASHostSessionKind.handoff.rawValue: BASMemorySource.cue.rawValue,
            BASHostSessionKind.widget.rawValue: BASMemorySource.cue.rawValue,
            BASHostSessionKind.notification.rawValue: BASMemorySource.cue.rawValue
        ],
        defaultRetrievalModeIDsBySessionKindID: [
            BASHostSessionKind.ambient.rawValue: BASRetrievalMode.adaptive.rawValue,
            BASHostSessionKind.reopen.rawValue: BASRetrievalMode.adaptive.rawValue,
            BASHostSessionKind.handoff.rawValue: BASRetrievalMode.adaptive.rawValue,
            BASHostSessionKind.widget.rawValue: BASRetrievalMode.adaptive.rawValue,
            BASHostSessionKind.notification.rawValue: BASRetrievalMode.adaptive.rawValue
        ],
        failureGuardIDsByRiskLevelID: [:],
        hostNamespace: "host"
    )

    public var modeIDsByProfileID: [String: String]
    public var templateIDsByProfileID: [String: [String]]
    public var memorySourceIDsByProfileID: [String: String]
    public var interactiveRetrievalModeByProfileID: [String: String]
    public var providerObservationNarrativesByKindID: [String: BASAppleProviderObservationNarrative]
    public var memorySourceIDsBySessionKindID: [String: String]
    public var retrievalModeIDsBySessionKindID: [String: String]
    public var defaultMemorySourceIDsBySessionKindID: [String: String]
    public var defaultRetrievalModeIDsBySessionKindID: [String: String]
    public var failureGuardIDsByRiskLevelID: [String: [String]]
    public var hostNamespace: String

    @available(*, unavailable, message: "Use .generic or provide explicit workflow behavior.")
    public init() {
        fatalError("Unavailable")
    }

    public init(
        modeIDsByProfileID: [String: String] = [
            BASHostWorkflowProfile.primary.rawValue: BASDecisionMode.primaryID,
            BASHostWorkflowProfile.comparative.rawValue: BASDecisionMode.comparativeID,
            BASHostWorkflowProfile.reflective.rawValue: BASDecisionMode.reflectiveID
        ],
        templateIDsByProfileID: [String: [String]] = [:],
        memorySourceIDsByProfileID: [String: String] = [
            BASHostWorkflowProfile.primary.rawValue: BASMemorySource.pattern.rawValue,
            BASHostWorkflowProfile.comparative.rawValue: BASMemorySource.pattern.rawValue,
            BASHostWorkflowProfile.reflective.rawValue: BASMemorySource.pattern.rawValue
        ],
        interactiveRetrievalModeByProfileID: [String: String] = [
            BASHostWorkflowProfile.primary.rawValue: BASRetrievalMode.adaptive.rawValue,
            BASHostWorkflowProfile.comparative.rawValue: BASRetrievalMode.adaptive.rawValue,
            BASHostWorkflowProfile.reflective.rawValue: BASRetrievalMode.adaptive.rawValue
        ],
        providerObservationNarrativesByKindID: [String: BASAppleProviderObservationNarrative] = [:],
        memorySourceIDsBySessionKindID: [String: String] = [:],
        retrievalModeIDsBySessionKindID: [String: String] = [:],
        defaultMemorySourceIDsBySessionKindID: [String: String] = [:],
        defaultRetrievalModeIDsBySessionKindID: [String: String] = [:],
        failureGuardIDsByRiskLevelID: [String: [String]] = [:],
        hostNamespace: String = "host"
    ) {
        self.modeIDsByProfileID = modeIDsByProfileID
        self.templateIDsByProfileID = templateIDsByProfileID
        self.memorySourceIDsByProfileID = memorySourceIDsByProfileID
        self.interactiveRetrievalModeByProfileID = interactiveRetrievalModeByProfileID
        self.providerObservationNarrativesByKindID = providerObservationNarrativesByKindID
        self.memorySourceIDsBySessionKindID = memorySourceIDsBySessionKindID
        self.retrievalModeIDsBySessionKindID = retrievalModeIDsBySessionKindID
        self.defaultMemorySourceIDsBySessionKindID = defaultMemorySourceIDsBySessionKindID
        self.defaultRetrievalModeIDsBySessionKindID = defaultRetrievalModeIDsBySessionKindID
        self.failureGuardIDsByRiskLevelID = failureGuardIDsByRiskLevelID
        self.hostNamespace = hostNamespace
    }

    public func modeID(for profile: BASHostWorkflowProfile) throws -> String {
        guard let modeID = mappedValue(for: profile, in: modeIDsByProfileID) else {
            throw BASHostIntegrationError.missingWorkflowModeMapping(profileID: profile.rawValue)
        }
        return modeID
    }

    public func mode(for profile: BASHostWorkflowProfile) throws -> BASDecisionMode {
        let resolvedModeID = try modeID(for: profile)
        guard let resolved = BASDecisionMode(identifier: resolvedModeID) else {
            throw BASHostIntegrationError.unsupportedWorkflowModeID(
                profileID: profile.rawValue,
                modeID: resolvedModeID
            )
        }
        return resolved
    }

    public func workflowProfile(forModeID requestedModeID: String) -> BASHostWorkflowProfile? {
        let requestedAliases = Self.modeAliases(for: requestedModeID)

        for profile in BASHostWorkflowProfile.allCases {
            guard let configuredModeID = try? modeID(for: profile) else {
                continue
            }
            let configuredAliases = Self.modeAliases(for: configuredModeID)
            if !requestedAliases.isDisjoint(with: configuredAliases) {
                return profile
            }
        }

        return nil
    }

    public func templateIDs(for profile: BASHostWorkflowProfile) -> [String] {
        mappedValue(for: profile, in: templateIDsByProfileID) ?? []
    }

    public func memorySource(for profile: BASHostWorkflowProfile) throws -> BASMemorySource {
        guard let sourceID = mappedValue(for: profile, in: memorySourceIDsByProfileID) else {
            throw BASHostIntegrationError.missingWorkflowMemorySource(profileID: profile.rawValue)
        }
        guard let source = BASMemorySource(rawValue: sourceID) else {
            throw BASHostIntegrationError.unsupportedWorkflowMemorySourceID(
                profileID: profile.rawValue,
                sourceID: sourceID
            )
        }
        return source
    }

    public func interactiveRetrievalMode(for profile: BASHostWorkflowProfile) throws -> String {
        guard let retrievalMode = mappedValue(for: profile, in: interactiveRetrievalModeByProfileID) else {
            throw BASHostIntegrationError.missingInteractiveRetrievalMode(profileID: profile.rawValue)
        }
        return retrievalMode
    }

    public func providerObservationNarrative(forKindID kindID: String) -> BASAppleProviderObservationNarrative? {
        providerObservationNarrativesByKindID[kindID]
    }

    public func memorySource(for kind: BASHostSessionKind) -> BASMemorySource? {
        memorySourceIDsBySessionKindID[kind.rawValue]
            .flatMap(BASMemorySource.init(rawValue:))
    }

    public func retrievalMode(for kind: BASHostSessionKind) -> String? {
        retrievalModeIDsBySessionKindID[kind.rawValue]
    }

    public func defaultMemorySource(for kind: BASHostSessionKind) -> BASMemorySource? {
        defaultMemorySourceIDsBySessionKindID[kind.rawValue]
            .flatMap(BASMemorySource.init(rawValue:))
    }

    public func defaultRetrievalMode(for kind: BASHostSessionKind) -> String? {
        defaultRetrievalModeIDsBySessionKindID[kind.rawValue]
    }

    public func failureGuardIDs(for riskLevel: BASHostRiskLevel) -> [String] {
        failureGuardIDsByRiskLevelID[riskLevel.rawValue] ?? []
    }

    public var sessionProvenanceSummary: String {
        "Session request from the \(hostNamespace) runtime."
    }

    private static func modeAliases(for modeID: String) -> Set<String> {
        var aliases = Set([modeID])
        if let mode = BASDecisionMode(identifier: modeID) {
            aliases.insert(mode.identifier)
            aliases.insert(mode.rawValue)
        }
        return aliases
    }

    private func mappedValue<Value>(
        for profile: BASHostWorkflowProfile,
        in mapping: [String: Value]
    ) -> Value? {
        for key in compatibilityLookupKeys(for: profile) where mapping[key] != nil {
            return mapping[key]
        }
        return nil
    }

    private func compatibilityLookupKeys(for profile: BASHostWorkflowProfile) -> [String] {
        [profile.rawValue]
    }

}

public struct BASHostCognitionBehaviorConfiguration: Codable, Equatable, Sendable {
    public static let generic = BASHostCognitionBehaviorConfiguration(
        reactionWeightsByProfileID: BASHostCognitionBehaviorConfiguration.genericReactionWeightsByProfileID(),
        identityProfilesByProfileID: BASHostCognitionBehaviorConfiguration.genericIdentityProfilesByProfileID(
            modeNamesByProfileID: BASHostCognitionBehaviorConfiguration.genericModeNamesByProfileID()
        ),
        modeNamesByProfileID: BASHostCognitionBehaviorConfiguration.genericModeNamesByProfileID(),
        substrateBehavior: .generic
    )

    public var reactionWeightsByProfileID: [String: BASReactionWeights]
    public var identityProfilesByProfileID: [String: BASIdentityProfile]
    public var modeNamesByProfileID: [String: String]
    public var substrateBehavior: BASCognitionBehavior

    @available(*, unavailable, message: "Use .generic or provide explicit cognition behavior.")
    public init() {
        fatalError("Unavailable")
    }

    public init(
        reactionWeightsByProfileID: [String: BASReactionWeights]? = nil,
        identityProfilesByProfileID: [String: BASIdentityProfile]? = nil,
        modeNamesByProfileID: [String: String]? = nil,
        substrateBehavior: BASCognitionBehavior = .generic
    ) {
        self.reactionWeightsByProfileID = reactionWeightsByProfileID
            ?? BASHostCognitionBehaviorConfiguration.genericReactionWeightsByProfileID()
        self.modeNamesByProfileID = modeNamesByProfileID
            ?? BASHostCognitionBehaviorConfiguration.genericModeNamesByProfileID()
        self.identityProfilesByProfileID = identityProfilesByProfileID
            ?? BASHostCognitionBehaviorConfiguration.genericIdentityProfilesByProfileID(
                modeNamesByProfileID: self.modeNamesByProfileID
            )
        self.substrateBehavior = substrateBehavior
    }

    public func reactionWeights(for profile: BASHostWorkflowProfile) -> BASReactionWeights {
        lookup(profile, in: reactionWeightsByProfileID)
            ?? BASHostCognitionBehaviorConfiguration.neutralReactionWeights(for: profile)
    }

    public func identityProfile(for profile: BASHostWorkflowProfile) -> BASIdentityProfile {
        lookup(profile, in: identityProfilesByProfileID)
            ?? BASHostCognitionBehaviorConfiguration.neutralIdentityProfile(
                for: profile,
                modeName: lookup(profile, in: modeNamesByProfileID)
            )
    }

    private static func genericReactionWeightsByProfileID() -> [String: BASReactionWeights] {
        var mapping: [String: BASReactionWeights] = [:]
        for profile in BASHostWorkflowProfile.allCases {
            mapping[profile.rawValue] = neutralReactionWeights(for: profile)
        }
        return mapping
    }

    private static func genericModeNamesByProfileID() -> [String: String] {
        [
            BASHostWorkflowProfile.primary.rawValue: "primary",
            BASHostWorkflowProfile.comparative.rawValue: "comparative",
            BASHostWorkflowProfile.reflective.rawValue: "reflective"
        ]
    }

    private static func genericIdentityProfilesByProfileID(
        modeNamesByProfileID: [String: String]
    ) -> [String: BASIdentityProfile] {
        var mapping: [String: BASIdentityProfile] = [:]
        for profile in BASHostWorkflowProfile.allCases {
            mapping[profile.rawValue] = neutralIdentityProfile(
                for: profile,
                modeName: modeNamesByProfileID[profile.rawValue]
            )
        }
        return mapping
    }

    private static func neutralReactionWeights(for profile: BASHostWorkflowProfile) -> BASReactionWeights {
        let modeName = genericModeNamesByProfileID()[profile.rawValue] ?? "host"
        return BASReactionWeights.defaults(for: modeName)
    }

    private static func neutralIdentityProfile(
        for profile: BASHostWorkflowProfile,
        modeName: String? = nil
    ) -> BASIdentityProfile {
        _ = profile
        return BASIdentityProfile.default(modeName: modeName ?? "host")
    }

    private func lookup<Value>(
        _ profile: BASHostWorkflowProfile,
        in mapping: [String: Value]
    ) -> Value? {
        for key in compatibilityLookupKeys(for: profile) where mapping[key] != nil {
            return mapping[key]
        }
        return nil
    }

    private func compatibilityLookupKeys(for profile: BASHostWorkflowProfile) -> [String] {
        [profile.rawValue]
    }
}

public struct BASHostPresentationConfiguration: Codable, Equatable, Sendable {
    public static let generic = BASHostPresentationConfiguration(
        workflowTitles: BASHostWorkflowTitles(),
        surfaceTitles: BASHostSurfaceTitles(),
        sessionTitles: BASHostSessionTitles(),
        followUpActions: BASHostFollowUpActions(),
        lifecycle: BASHostLifecyclePresentation(),
        notices: BASHostNoticeTemplates(),
        predictiveIntervention: BASHostPredictiveInterventionPresentation()
    )

    public var workflowTitles: BASHostWorkflowTitles
    public var surfaceTitles: BASHostSurfaceTitles
    public var sessionTitles: BASHostSessionTitles
    public var followUpActions: BASHostFollowUpActions
    public var lifecycle: BASHostLifecyclePresentation
    public var notices: BASHostNoticeTemplates
    public var predictiveIntervention: BASHostPredictiveInterventionPresentation

    @available(*, unavailable, message: "Use .generic or provide explicit presentation behavior.")
    public init() {
        fatalError("Unavailable")
    }

    public init(
        workflowTitles: BASHostWorkflowTitles = BASHostWorkflowTitles(),
        surfaceTitles: BASHostSurfaceTitles = BASHostSurfaceTitles(),
        sessionTitles: BASHostSessionTitles = BASHostSessionTitles(),
        followUpActions: BASHostFollowUpActions = BASHostFollowUpActions(),
        lifecycle: BASHostLifecyclePresentation = BASHostLifecyclePresentation(),
        notices: BASHostNoticeTemplates = BASHostNoticeTemplates(),
        predictiveIntervention: BASHostPredictiveInterventionPresentation = BASHostPredictiveInterventionPresentation()
    ) {
        self.workflowTitles = workflowTitles
        self.surfaceTitles = surfaceTitles
        self.sessionTitles = sessionTitles
        self.followUpActions = followUpActions
        self.lifecycle = lifecycle
        self.notices = notices
        self.predictiveIntervention = predictiveIntervention
    }
}
