import CryptoKit
import Foundation

@_exported import BASAdmin
@_exported import BASAppleAdapters
@_exported import BASEvaluation
@_exported import BASMemory
@_exported import BASObservability
@_exported import BASOrchestration
@_exported import BASPolicy
@_exported import BASRuntimeCore

public typealias BASHostBootstrapBehaviorConfiguration = BASCurrentBrainBootstrapBehavior
public typealias BASHostPromptBehaviorConfiguration = BASReferencePromptBehavior
public typealias BASHostMemoryDerivationConfiguration = BASMemoryDerivationBehavior
public typealias BASHostPredictiveInterventionBehaviorConfiguration = BASApplePredictiveInterventionBehavior

public enum BASHostSessionKind: String, Codable, Sendable, CaseIterable {
    case interactive
    case ambient
    case reopen
    case handoff
    case widget
    case notification

    public var title: String {
        switch self {
        case .interactive:
            "Interactive"
        case .ambient:
            "Ambient"
        case .reopen:
            "Reopen"
        case .handoff:
            "Handoff"
        case .widget:
            "Widget"
        case .notification:
            "Notification"
        }
    }
}

public enum BASHostSurface: String, Codable, Sendable, CaseIterable {
    case application
    case wearable
    case widget
    case shortcut
    case voiceAssistant
    case notification
    case system

    public var title: String {
        switch self {
        case .application:
            "Application"
        case .wearable:
            "Wearable"
        case .widget:
            "Widget"
        case .shortcut:
            "Shortcut"
        case .voiceAssistant:
            "Voice Assistant"
        case .notification:
            "Notification"
        case .system:
            "System"
        }
    }

    var substrateSurface: BASInteractionSurface {
        switch self {
        case .application:
            .app
        case .wearable:
            .watch
        case .widget:
            .widget
        case .shortcut:
            .shortcut
        case .voiceAssistant:
            .siri
        case .notification:
            .notification
        case .system:
            .system
        }
    }
}

public enum BASHostRiskLevel: String, Codable, Sendable, Comparable, CaseIterable {
    case low
    case medium
    case high

    public static func < (lhs: BASHostRiskLevel, rhs: BASHostRiskLevel) -> Bool {
        lhs.order < rhs.order
    }

    var substrateRiskLevel: BASRiskLevel {
        switch self {
        case .low:
            .low
        case .medium:
            .medium
        case .high:
            .high
        }
    }

    private var order: Int {
        switch self {
        case .low:
            0
        case .medium:
            1
        case .high:
            2
        }
    }
}

public enum BASHostWorkflowProfile: String, Codable, Sendable, CaseIterable {
    case primary
    case comparative
    case reflective

    public var lookupKeys: [String] {
        [rawValue]
    }

    public init?(identifier: String) {
        switch identifier {
        case Self.primary.rawValue:
            self = .primary
        case Self.comparative.rawValue:
            self = .comparative
        case Self.reflective.rawValue:
            self = .reflective
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let profile = BASHostWorkflowProfile(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported host workflow profile: \(identifier)"
            )
        }
        self = profile
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var title: String {
        switch self {
        case .primary:
            "Primary"
        case .comparative:
            "Comparative"
        case .reflective:
            "Reflective"
        }
    }
}

public enum BASHostLifecyclePhase: String, Codable, Sendable, CaseIterable {
    case initialAppearance
    case sceneActive

    var bootstrapPhase: BASAppleLifecycleBootstrapPhase {
        switch self {
        case .initialAppearance:
            .initialAppearance
        case .sceneActive:
            .sceneActive
        }
    }
}

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

public enum BASHostIntegrationError: Error, Equatable, Sendable {
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

public struct BASEBrainRuntimeSynthesisPolicy: Codable, Equatable, Sendable {
    public struct GuardrailPressureTuning: Codable, Equatable, Sendable {
        public var protectiveBoundaryIncrement: Double
        public var calibrationWatchIncrement: Double
        public var calibrationDriftingIncrement: Double
        public var boundaryConstraintUnit: Double
        public var boundaryConstraintCap: Double
        public var calibrationAlertUnit: Double
        public var calibrationAlertCap: Double
        public var failureGuardUnit: Double
        public var failureGuardCap: Double
        public var riskFlagUnit: Double
        public var riskFlagCap: Double
        public var maximumPressure: Double

        public init(
            protectiveBoundaryIncrement: Double,
            calibrationWatchIncrement: Double,
            calibrationDriftingIncrement: Double,
            boundaryConstraintUnit: Double,
            boundaryConstraintCap: Double,
            calibrationAlertUnit: Double,
            calibrationAlertCap: Double,
            failureGuardUnit: Double,
            failureGuardCap: Double,
            riskFlagUnit: Double,
            riskFlagCap: Double,
            maximumPressure: Double
        ) {
            self.protectiveBoundaryIncrement = protectiveBoundaryIncrement
            self.calibrationWatchIncrement = calibrationWatchIncrement
            self.calibrationDriftingIncrement = calibrationDriftingIncrement
            self.boundaryConstraintUnit = boundaryConstraintUnit
            self.boundaryConstraintCap = boundaryConstraintCap
            self.calibrationAlertUnit = calibrationAlertUnit
            self.calibrationAlertCap = calibrationAlertCap
            self.failureGuardUnit = failureGuardUnit
            self.failureGuardCap = failureGuardCap
            self.riskFlagUnit = riskFlagUnit
            self.riskFlagCap = riskFlagCap
            self.maximumPressure = maximumPressure
        }
    }

    public struct BudgetTuning: Codable, Equatable, Sendable {
        public struct RunModeBudgetProfile: Codable, Equatable, Sendable {
            public var maxLoops: Int
            public var maxCandidates: Int
            public var retrievalDepth: Int
            public var defaultDecodeTokens: Int?
            public var unstableDecodeTokens: Int?
            public var precisionProfile: BASRuntimePrecisionProfile
            public var defaultDeviceRoute: BASDeviceRoute
            public var npuUnavailableDeviceRoute: BASDeviceRoute
            public var pureLocalPreferredDeviceRoute: BASDeviceRoute?
            public var candidateCountCap: Int?
            public var standardLoopFloor: Int?
            public var protectedLoopFloor: Int?
            public var standardCandidateFloor: Int?
            public var protectedCandidateFloor: Int?
            public var unstableLoopIncrement: Int?
            public var unstableLoopIncrementRiskLevels: [BASBrainRiskLevel]?
            public var throttleLoopPenalty: Int?
            public var throttleCandidatePenalty: Int?
            public var throttlePenaltyThermalLevels: [BASThermalLevel]?
            public var maintenanceSupported: Bool?
            public var maintenanceBatteryFloor: Double?
            public var scheduledMaintenanceClass: BASMaintenanceClass?
            public var deferredMaintenanceClass: BASMaintenanceClass?

            public init(
                maxLoops: Int,
                maxCandidates: Int,
                retrievalDepth: Int,
                defaultDecodeTokens: Int? = nil,
                unstableDecodeTokens: Int? = nil,
                precisionProfile: BASRuntimePrecisionProfile,
                defaultDeviceRoute: BASDeviceRoute,
                npuUnavailableDeviceRoute: BASDeviceRoute,
                pureLocalPreferredDeviceRoute: BASDeviceRoute? = nil,
                candidateCountCap: Int? = nil,
                standardLoopFloor: Int? = nil,
                protectedLoopFloor: Int? = nil,
                standardCandidateFloor: Int? = nil,
                protectedCandidateFloor: Int? = nil,
                unstableLoopIncrement: Int? = nil,
                unstableLoopIncrementRiskLevels: [BASBrainRiskLevel]? = nil,
                throttleLoopPenalty: Int? = nil,
                throttleCandidatePenalty: Int? = nil,
                throttlePenaltyThermalLevels: [BASThermalLevel]? = nil,
                maintenanceSupported: Bool? = nil,
                maintenanceBatteryFloor: Double? = nil,
                scheduledMaintenanceClass: BASMaintenanceClass? = nil,
                deferredMaintenanceClass: BASMaintenanceClass? = nil
            ) {
                self.maxLoops = maxLoops
                self.maxCandidates = maxCandidates
                self.retrievalDepth = retrievalDepth
                self.defaultDecodeTokens = defaultDecodeTokens
                self.unstableDecodeTokens = unstableDecodeTokens
                self.precisionProfile = precisionProfile
                self.defaultDeviceRoute = defaultDeviceRoute
                self.npuUnavailableDeviceRoute = npuUnavailableDeviceRoute
                self.pureLocalPreferredDeviceRoute = pureLocalPreferredDeviceRoute
                self.candidateCountCap = candidateCountCap
                self.standardLoopFloor = standardLoopFloor
                self.protectedLoopFloor = protectedLoopFloor
                self.standardCandidateFloor = standardCandidateFloor
                self.protectedCandidateFloor = protectedCandidateFloor
                self.unstableLoopIncrement = unstableLoopIncrement
                self.unstableLoopIncrementRiskLevels = unstableLoopIncrementRiskLevels
                self.throttleLoopPenalty = throttleLoopPenalty
                self.throttleCandidatePenalty = throttleCandidatePenalty
                self.throttlePenaltyThermalLevels = throttlePenaltyThermalLevels
                self.maintenanceSupported = maintenanceSupported
                self.maintenanceBatteryFloor = maintenanceBatteryFloor
                self.scheduledMaintenanceClass = scheduledMaintenanceClass
                self.deferredMaintenanceClass = deferredMaintenanceClass
            }

            public func resolvedDeviceRoute(
                npuAvailable: Bool,
                prefersPureLocal: Bool
            ) -> BASDeviceRoute {
                if prefersPureLocal, let pureLocalPreferredDeviceRoute {
                    return pureLocalPreferredDeviceRoute
                }
                return npuAvailable ? defaultDeviceRoute : npuUnavailableDeviceRoute
            }

            public func merged(with fallback: RunModeBudgetProfile) -> RunModeBudgetProfile {
                RunModeBudgetProfile(
                    maxLoops: maxLoops,
                    maxCandidates: maxCandidates,
                    retrievalDepth: retrievalDepth,
                    defaultDecodeTokens: defaultDecodeTokens ?? fallback.defaultDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens ?? fallback.unstableDecodeTokens,
                    precisionProfile: precisionProfile,
                    defaultDeviceRoute: defaultDeviceRoute,
                    npuUnavailableDeviceRoute: npuUnavailableDeviceRoute,
                    pureLocalPreferredDeviceRoute: pureLocalPreferredDeviceRoute ?? fallback.pureLocalPreferredDeviceRoute,
                    candidateCountCap: candidateCountCap ?? fallback.candidateCountCap,
                    standardLoopFloor: standardLoopFloor ?? fallback.standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor ?? fallback.protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor ?? fallback.standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor ?? fallback.protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement ?? fallback.unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels ?? fallback.unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty ?? fallback.throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty ?? fallback.throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels ?? fallback.throttlePenaltyThermalLevels,
                    maintenanceSupported: maintenanceSupported ?? fallback.maintenanceSupported,
                    maintenanceBatteryFloor: maintenanceBatteryFloor ?? fallback.maintenanceBatteryFloor,
                    scheduledMaintenanceClass: scheduledMaintenanceClass ?? fallback.scheduledMaintenanceClass,
                    deferredMaintenanceClass: deferredMaintenanceClass ?? fallback.deferredMaintenanceClass
                )
            }
        }

        public var standardDecodeTokens: Int
        public var unstableDecodeTokens: Int
        public var guardedDecodeTokens: Int
        public var maintenanceBatteryFloor: Double
        public var lowRiskLoops: Int
        public var mediumRiskLoops: Int
        public var highRiskLoops: Int
        public var extremeRiskLoops: Int
        public var lowRiskCandidates: Int
        public var mediumRiskCandidates: Int
        public var highRiskCandidates: Int
        public var extremeRiskCandidates: Int
        public var lowRiskRetrievalDepth: Int
        public var mediumRiskRetrievalDepth: Int
        public var guardedRetrievalDepth: Int
        public var standardLoopFloor: Int
        public var protectedLoopFloor: Int
        public var standardCandidateFloor: Int
        public var protectedCandidateFloor: Int
        public var maxCandidateCount: Int
        public var protectedFloorBoundaryModes: [BASBoundaryPolicyMode]
        public var protectedFloorCalibrationStatuses: [BASCalibrationStatus]
        public var unstableLoopIncrement: Int
        public var unstableLoopIncrementRiskLevels: [BASBrainRiskLevel]
        public var unstableBudgetCalibrationStatuses: [BASCalibrationStatus]
        public var nominalThermalGuardLevel: BASThermalGuardLevel
        public var warmThermalGuardLevel: BASThermalGuardLevel
        public var hotThermalGuardLevel: BASThermalGuardLevel
        public var criticalThermalGuardLevel: BASThermalGuardLevel
        public var throttleLoopPenalty: Int
        public var throttleCandidatePenalty: Int
        public var throttlePenaltyThermalLevels: [BASThermalLevel]
        public var defaultPrecisionProfile: BASRuntimePrecisionProfile
        public var unstablePrecisionProfile: BASRuntimePrecisionProfile
        public var guardedPrecisionProfile: BASRuntimePrecisionProfile
        public var lowRiskPrecisionProfile: BASRuntimePrecisionProfile
        public var mediumRiskPrecisionProfile: BASRuntimePrecisionProfile
        public var highRiskPrecisionProfile: BASRuntimePrecisionProfile
        public var extremeRiskPrecisionProfile: BASRuntimePrecisionProfile
        public var pulseRetrievalDepth: Int
        public var sentinelRetrievalDepth: Int
        public var engageRetrievalDepth: Int
        public var reflectRetrievalDepth: Int
        public var deepLoopRetrievalDepth: Int
        public var guardRetrievalDepth: Int
        public var recoveryRetrievalDepth: Int
        public var quarantineRetrievalDepth: Int
        public var lockdownRetrievalDepth: Int
        public var dormantRetrievalDepth: Int
        public var runModeProfilesByID: [String: RunModeBudgetProfile]?

        private enum CodingKeys: String, CodingKey {
            case standardDecodeTokens
            case unstableDecodeTokens
            case guardedDecodeTokens
            case maintenanceBatteryFloor
            case lowRiskLoops
            case mediumRiskLoops
            case highRiskLoops
            case extremeRiskLoops
            case lowRiskCandidates
            case mediumRiskCandidates
            case highRiskCandidates
            case extremeRiskCandidates
            case lowRiskRetrievalDepth
            case mediumRiskRetrievalDepth
            case guardedRetrievalDepth
            case standardLoopFloor
            case protectedLoopFloor
            case standardCandidateFloor
            case protectedCandidateFloor
            case maxCandidateCount
            case protectedFloorBoundaryModes
            case protectedFloorCalibrationStatuses
            case unstableLoopIncrement
            case unstableLoopIncrementRiskLevels
            case unstableBudgetCalibrationStatuses
            case nominalThermalGuardLevel
            case warmThermalGuardLevel
            case hotThermalGuardLevel
            case criticalThermalGuardLevel
            case throttleLoopPenalty
            case throttleCandidatePenalty
            case throttlePenaltyThermalLevels
            case defaultPrecisionProfile
            case unstablePrecisionProfile
            case guardedPrecisionProfile
            case lowRiskPrecisionProfile
            case mediumRiskPrecisionProfile
            case highRiskPrecisionProfile
            case extremeRiskPrecisionProfile
            case pulseRetrievalDepth
            case sentinelRetrievalDepth
            case engageRetrievalDepth
            case reflectRetrievalDepth
            case deepLoopRetrievalDepth
            case guardRetrievalDepth
            case recoveryRetrievalDepth
            case quarantineRetrievalDepth
            case lockdownRetrievalDepth
            case dormantRetrievalDepth
            case runModeProfilesByID
        }

        public init(
            standardDecodeTokens: Int,
            unstableDecodeTokens: Int,
            guardedDecodeTokens: Int,
            maintenanceBatteryFloor: Double,
            lowRiskLoops: Int = 1,
            mediumRiskLoops: Int = 2,
            highRiskLoops: Int = 4,
            extremeRiskLoops: Int = 2,
            lowRiskCandidates: Int = 2,
            mediumRiskCandidates: Int = 3,
            highRiskCandidates: Int = 3,
            extremeRiskCandidates: Int = 2,
            lowRiskRetrievalDepth: Int = 2,
            mediumRiskRetrievalDepth: Int = 3,
            guardedRetrievalDepth: Int = 4,
            standardLoopFloor: Int = 1,
            protectedLoopFloor: Int = 2,
            standardCandidateFloor: Int = 1,
            protectedCandidateFloor: Int = 2,
            maxCandidateCount: Int = 4,
            protectedFloorBoundaryModes: [BASBoundaryPolicyMode] = [.localOnlyProtective],
            protectedFloorCalibrationStatuses: [BASCalibrationStatus] = [],
            unstableLoopIncrement: Int = 1,
            unstableLoopIncrementRiskLevels: [BASBrainRiskLevel] = [.low, .medium],
            unstableBudgetCalibrationStatuses: [BASCalibrationStatus] = [.watch, .drifting],
            nominalThermalGuardLevel: BASThermalGuardLevel = .nominal,
            warmThermalGuardLevel: BASThermalGuardLevel = .watch,
            hotThermalGuardLevel: BASThermalGuardLevel = .throttle,
            criticalThermalGuardLevel: BASThermalGuardLevel = .emergency,
            throttleLoopPenalty: Int = 1,
            throttleCandidatePenalty: Int = 1,
            throttlePenaltyThermalLevels: [BASThermalLevel] = [.hot],
            defaultPrecisionProfile: BASRuntimePrecisionProfile = .balanced,
            unstablePrecisionProfile: BASRuntimePrecisionProfile = .protected,
            guardedPrecisionProfile: BASRuntimePrecisionProfile = .protected,
            lowRiskPrecisionProfile: BASRuntimePrecisionProfile? = nil,
            mediumRiskPrecisionProfile: BASRuntimePrecisionProfile? = nil,
            highRiskPrecisionProfile: BASRuntimePrecisionProfile? = nil,
            extremeRiskPrecisionProfile: BASRuntimePrecisionProfile? = nil,
            pulseRetrievalDepth: Int? = nil,
            sentinelRetrievalDepth: Int? = nil,
            engageRetrievalDepth: Int? = nil,
            reflectRetrievalDepth: Int? = nil,
            deepLoopRetrievalDepth: Int? = nil,
            guardRetrievalDepth: Int? = nil,
            recoveryRetrievalDepth: Int? = nil,
            quarantineRetrievalDepth: Int? = nil,
            lockdownRetrievalDepth: Int? = nil,
            dormantRetrievalDepth: Int? = nil,
            runModeProfilesByID: [String: RunModeBudgetProfile]? = nil
        ) {
            self.standardDecodeTokens = standardDecodeTokens
            self.unstableDecodeTokens = unstableDecodeTokens
            self.guardedDecodeTokens = guardedDecodeTokens
            self.maintenanceBatteryFloor = maintenanceBatteryFloor
            self.lowRiskLoops = lowRiskLoops
            self.mediumRiskLoops = mediumRiskLoops
            self.highRiskLoops = highRiskLoops
            self.extremeRiskLoops = extremeRiskLoops
            self.lowRiskCandidates = lowRiskCandidates
            self.mediumRiskCandidates = mediumRiskCandidates
            self.highRiskCandidates = highRiskCandidates
            self.extremeRiskCandidates = extremeRiskCandidates
            self.lowRiskRetrievalDepth = lowRiskRetrievalDepth
            self.mediumRiskRetrievalDepth = mediumRiskRetrievalDepth
            self.guardedRetrievalDepth = guardedRetrievalDepth
            self.standardLoopFloor = standardLoopFloor
            self.protectedLoopFloor = protectedLoopFloor
            self.standardCandidateFloor = standardCandidateFloor
            self.protectedCandidateFloor = protectedCandidateFloor
            self.maxCandidateCount = maxCandidateCount
            self.protectedFloorBoundaryModes = protectedFloorBoundaryModes
            self.protectedFloorCalibrationStatuses = protectedFloorCalibrationStatuses
            self.unstableLoopIncrement = unstableLoopIncrement
            self.unstableLoopIncrementRiskLevels = unstableLoopIncrementRiskLevels
            self.unstableBudgetCalibrationStatuses = unstableBudgetCalibrationStatuses
            self.nominalThermalGuardLevel = nominalThermalGuardLevel
            self.warmThermalGuardLevel = warmThermalGuardLevel
            self.hotThermalGuardLevel = hotThermalGuardLevel
            self.criticalThermalGuardLevel = criticalThermalGuardLevel
            self.throttleLoopPenalty = throttleLoopPenalty
            self.throttleCandidatePenalty = throttleCandidatePenalty
            self.throttlePenaltyThermalLevels = throttlePenaltyThermalLevels
            self.defaultPrecisionProfile = defaultPrecisionProfile
            self.unstablePrecisionProfile = unstablePrecisionProfile
            self.guardedPrecisionProfile = guardedPrecisionProfile
            self.lowRiskPrecisionProfile = lowRiskPrecisionProfile ?? defaultPrecisionProfile
            self.mediumRiskPrecisionProfile = mediumRiskPrecisionProfile ?? defaultPrecisionProfile
            self.highRiskPrecisionProfile = highRiskPrecisionProfile ?? guardedPrecisionProfile
            self.extremeRiskPrecisionProfile = extremeRiskPrecisionProfile ?? guardedPrecisionProfile
            self.pulseRetrievalDepth = pulseRetrievalDepth ?? lowRiskRetrievalDepth
            self.sentinelRetrievalDepth = sentinelRetrievalDepth ?? lowRiskRetrievalDepth
            self.engageRetrievalDepth = engageRetrievalDepth ?? lowRiskRetrievalDepth
            self.reflectRetrievalDepth = reflectRetrievalDepth ?? mediumRiskRetrievalDepth
            self.deepLoopRetrievalDepth = deepLoopRetrievalDepth ?? max(mediumRiskRetrievalDepth, lowRiskRetrievalDepth)
            self.guardRetrievalDepth = guardRetrievalDepth ?? guardedRetrievalDepth
            self.recoveryRetrievalDepth = recoveryRetrievalDepth ?? guardedRetrievalDepth
            self.quarantineRetrievalDepth = quarantineRetrievalDepth ?? guardedRetrievalDepth
            self.lockdownRetrievalDepth = lockdownRetrievalDepth ?? guardedRetrievalDepth
            self.dormantRetrievalDepth = dormantRetrievalDepth ?? lowRiskRetrievalDepth
            self.runModeProfilesByID = runModeProfilesByID
        }

        public func thermalGuardLevel(
            for thermalLevel: BASThermalLevel
        ) -> BASThermalGuardLevel {
            switch thermalLevel {
            case .nominal:
                nominalThermalGuardLevel
            case .warm:
                warmThermalGuardLevel
            case .hot:
                hotThermalGuardLevel
            case .critical:
                criticalThermalGuardLevel
            }
        }

        public func usesProtectedFloors(
            boundaryMode: BASBoundaryPolicyMode,
            calibrationStatus: BASCalibrationStatus
        ) -> Bool {
            protectedFloorBoundaryModes.contains(boundaryMode) ||
                protectedFloorCalibrationStatuses.contains(calibrationStatus)
        }

        private static func synthesizedRunModeProfiles(
            lowRiskLoops: Int,
            mediumRiskLoops: Int,
            highRiskLoops: Int,
            extremeRiskLoops: Int,
            lowRiskCandidates: Int,
            mediumRiskCandidates: Int,
            highRiskCandidates: Int,
            extremeRiskCandidates: Int,
            standardDecodeTokens: Int,
            unstableDecodeTokens: Int,
            guardedDecodeTokens: Int,
            lowRiskPrecisionProfile: BASRuntimePrecisionProfile,
            mediumRiskPrecisionProfile: BASRuntimePrecisionProfile,
            highRiskPrecisionProfile: BASRuntimePrecisionProfile,
            extremeRiskPrecisionProfile: BASRuntimePrecisionProfile,
            pulseRetrievalDepth: Int,
            sentinelRetrievalDepth: Int,
            engageRetrievalDepth: Int,
            reflectRetrievalDepth: Int,
            deepLoopRetrievalDepth: Int,
            guardRetrievalDepth: Int,
            recoveryRetrievalDepth: Int,
            quarantineRetrievalDepth: Int,
            lockdownRetrievalDepth: Int,
            dormantRetrievalDepth: Int,
            standardLoopFloor: Int,
            protectedLoopFloor: Int,
            standardCandidateFloor: Int,
            protectedCandidateFloor: Int,
            candidateCountCap: Int,
            unstableLoopIncrement: Int,
            unstableLoopIncrementRiskLevels: [BASBrainRiskLevel],
            throttleLoopPenalty: Int,
            throttleCandidatePenalty: Int,
            throttlePenaltyThermalLevels: [BASThermalLevel],
            lightweightMaintenanceBatteryFloor: Double,
            standardMaintenanceBatteryFloor: Double,
            restrictedMaintenanceBatteryFloor: Double,
            lightweightAllowedClass: BASMaintenanceClass,
            lightweightDeferredClass: BASMaintenanceClass,
            activeRunModeClass: BASMaintenanceClass,
            restrictedRunModeClass: BASMaintenanceClass
        ) -> [String: RunModeBudgetProfile] {
            [
                BASEBrainRunMode.dormant.rawValue: .init(
                    maxLoops: lowRiskLoops,
                    maxCandidates: lowRiskCandidates,
                    retrievalDepth: dormantRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: lowRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: standardMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: activeRunModeClass,
                    deferredMaintenanceClass: activeRunModeClass
                ),
                BASEBrainRunMode.pulse.rawValue: .init(
                    maxLoops: lowRiskLoops,
                    maxCandidates: lowRiskCandidates,
                    retrievalDepth: pulseRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: lowRiskPrecisionProfile,
                    defaultDeviceRoute: .scoutNPU,
                    npuUnavailableDeviceRoute: .scoutCPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: lightweightMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: lightweightAllowedClass,
                    deferredMaintenanceClass: lightweightDeferredClass
                ),
                BASEBrainRunMode.sentinel.rawValue: .init(
                    maxLoops: lowRiskLoops,
                    maxCandidates: lowRiskCandidates,
                    retrievalDepth: sentinelRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: lowRiskPrecisionProfile,
                    defaultDeviceRoute: .scoutNPU,
                    npuUnavailableDeviceRoute: .scoutCPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: lightweightMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: lightweightAllowedClass,
                    deferredMaintenanceClass: lightweightDeferredClass
                ),
                BASEBrainRunMode.engage.rawValue: .init(
                    maxLoops: lowRiskLoops,
                    maxCandidates: lowRiskCandidates,
                    retrievalDepth: engageRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: lowRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: standardMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: activeRunModeClass,
                    deferredMaintenanceClass: activeRunModeClass
                ),
                BASEBrainRunMode.reflect.rawValue: .init(
                    maxLoops: mediumRiskLoops,
                    maxCandidates: mediumRiskCandidates,
                    retrievalDepth: reflectRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: mediumRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: standardMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: activeRunModeClass,
                    deferredMaintenanceClass: activeRunModeClass
                ),
                BASEBrainRunMode.deepLoop.rawValue: .init(
                    maxLoops: mediumRiskLoops,
                    maxCandidates: mediumRiskCandidates,
                    retrievalDepth: deepLoopRetrievalDepth,
                    defaultDecodeTokens: standardDecodeTokens,
                    unstableDecodeTokens: unstableDecodeTokens,
                    precisionProfile: mediumRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: true,
                    maintenanceBatteryFloor: standardMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: activeRunModeClass,
                    deferredMaintenanceClass: activeRunModeClass
                ),
                BASEBrainRunMode.guard.rawValue: .init(
                    maxLoops: highRiskLoops,
                    maxCandidates: highRiskCandidates,
                    retrievalDepth: guardRetrievalDepth,
                    defaultDecodeTokens: guardedDecodeTokens,
                    unstableDecodeTokens: guardedDecodeTokens,
                    precisionProfile: highRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    pureLocalPreferredDeviceRoute: .hybridLocal,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: restrictedMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: restrictedRunModeClass,
                    deferredMaintenanceClass: restrictedRunModeClass
                ),
                BASEBrainRunMode.recovery.rawValue: .init(
                    maxLoops: highRiskLoops,
                    maxCandidates: highRiskCandidates,
                    retrievalDepth: recoveryRetrievalDepth,
                    defaultDecodeTokens: guardedDecodeTokens,
                    unstableDecodeTokens: guardedDecodeTokens,
                    precisionProfile: highRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    pureLocalPreferredDeviceRoute: .hybridLocal,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: restrictedMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: restrictedRunModeClass,
                    deferredMaintenanceClass: restrictedRunModeClass
                ),
                BASEBrainRunMode.quarantine.rawValue: .init(
                    maxLoops: highRiskLoops,
                    maxCandidates: highRiskCandidates,
                    retrievalDepth: quarantineRetrievalDepth,
                    defaultDecodeTokens: guardedDecodeTokens,
                    unstableDecodeTokens: guardedDecodeTokens,
                    precisionProfile: highRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    pureLocalPreferredDeviceRoute: .hybridLocal,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: restrictedMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: restrictedRunModeClass,
                    deferredMaintenanceClass: restrictedRunModeClass
                ),
                BASEBrainRunMode.lockdown.rawValue: .init(
                    maxLoops: extremeRiskLoops,
                    maxCandidates: extremeRiskCandidates,
                    retrievalDepth: lockdownRetrievalDepth,
                    defaultDecodeTokens: guardedDecodeTokens,
                    unstableDecodeTokens: guardedDecodeTokens,
                    precisionProfile: extremeRiskPrecisionProfile,
                    defaultDeviceRoute: .coreNPU,
                    npuUnavailableDeviceRoute: .coreGPU,
                    pureLocalPreferredDeviceRoute: .hybridLocal,
                    candidateCountCap: candidateCountCap,
                    standardLoopFloor: standardLoopFloor,
                    protectedLoopFloor: protectedLoopFloor,
                    standardCandidateFloor: standardCandidateFloor,
                    protectedCandidateFloor: protectedCandidateFloor,
                    unstableLoopIncrement: unstableLoopIncrement,
                    unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                    throttleLoopPenalty: throttleLoopPenalty,
                    throttleCandidatePenalty: throttleCandidatePenalty,
                    throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                    maintenanceSupported: false,
                    maintenanceBatteryFloor: restrictedMaintenanceBatteryFloor,
                    scheduledMaintenanceClass: restrictedRunModeClass,
                    deferredMaintenanceClass: restrictedRunModeClass
                )
            ]
        }

        public func resolvedRunModeProfilesByID(
            maintenance: BASEBrainRuntimeSynthesisPolicy.MaintenanceTuning = .generic
        ) -> [String: RunModeBudgetProfile] {
            let synthesizedProfiles = Self.synthesizedRunModeProfiles(
                lowRiskLoops: lowRiskLoops,
                mediumRiskLoops: mediumRiskLoops,
                highRiskLoops: highRiskLoops,
                extremeRiskLoops: extremeRiskLoops,
                lowRiskCandidates: lowRiskCandidates,
                mediumRiskCandidates: mediumRiskCandidates,
                highRiskCandidates: highRiskCandidates,
                extremeRiskCandidates: extremeRiskCandidates,
                standardDecodeTokens: standardDecodeTokens,
                unstableDecodeTokens: unstableDecodeTokens,
                guardedDecodeTokens: guardedDecodeTokens,
                lowRiskPrecisionProfile: lowRiskPrecisionProfile,
                mediumRiskPrecisionProfile: mediumRiskPrecisionProfile,
                highRiskPrecisionProfile: highRiskPrecisionProfile,
                extremeRiskPrecisionProfile: extremeRiskPrecisionProfile,
                pulseRetrievalDepth: pulseRetrievalDepth,
                sentinelRetrievalDepth: sentinelRetrievalDepth,
                engageRetrievalDepth: engageRetrievalDepth,
                reflectRetrievalDepth: reflectRetrievalDepth,
                deepLoopRetrievalDepth: deepLoopRetrievalDepth,
                guardRetrievalDepth: guardRetrievalDepth,
                recoveryRetrievalDepth: recoveryRetrievalDepth,
                quarantineRetrievalDepth: quarantineRetrievalDepth,
                lockdownRetrievalDepth: lockdownRetrievalDepth,
                dormantRetrievalDepth: dormantRetrievalDepth,
                standardLoopFloor: standardLoopFloor,
                protectedLoopFloor: protectedLoopFloor,
                standardCandidateFloor: standardCandidateFloor,
                protectedCandidateFloor: protectedCandidateFloor,
                candidateCountCap: maxCandidateCount,
                unstableLoopIncrement: unstableLoopIncrement,
                unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                throttleLoopPenalty: throttleLoopPenalty,
                throttleCandidatePenalty: throttleCandidatePenalty,
                throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                lightweightMaintenanceBatteryFloor: maintenance.lightBatteryFloor,
                standardMaintenanceBatteryFloor: maintenance.standardBatteryFloor,
                restrictedMaintenanceBatteryFloor: maintenanceBatteryFloor,
                lightweightAllowedClass: maintenance.lightweightAllowedClass,
                lightweightDeferredClass: maintenance.lightweightDeferredClass,
                activeRunModeClass: maintenance.activeRunModeClass,
                restrictedRunModeClass: maintenance.restrictedRunModeClass
            )
            guard let runModeProfilesByID else {
                return synthesizedProfiles
            }

            return synthesizedProfiles.merging(runModeProfilesByID) { fallback, explicit in
                explicit.merged(with: fallback)
            }
        }

        public func runModeProfile(
            for runMode: BASEBrainRunMode,
            maintenance: BASEBrainRuntimeSynthesisPolicy.MaintenanceTuning = .generic
        ) -> RunModeBudgetProfile {
            let resolvedProfiles = resolvedRunModeProfilesByID(maintenance: maintenance)
            if let explicitProfile = resolvedProfiles[runMode.rawValue] {
                return explicitProfile
            }

            return Self.synthesizedRunModeProfiles(
                lowRiskLoops: lowRiskLoops,
                mediumRiskLoops: mediumRiskLoops,
                highRiskLoops: highRiskLoops,
                extremeRiskLoops: extremeRiskLoops,
                lowRiskCandidates: lowRiskCandidates,
                mediumRiskCandidates: mediumRiskCandidates,
                highRiskCandidates: highRiskCandidates,
                extremeRiskCandidates: extremeRiskCandidates,
                standardDecodeTokens: standardDecodeTokens,
                unstableDecodeTokens: unstableDecodeTokens,
                guardedDecodeTokens: guardedDecodeTokens,
                lowRiskPrecisionProfile: lowRiskPrecisionProfile,
                mediumRiskPrecisionProfile: mediumRiskPrecisionProfile,
                highRiskPrecisionProfile: highRiskPrecisionProfile,
                extremeRiskPrecisionProfile: extremeRiskPrecisionProfile,
                pulseRetrievalDepth: pulseRetrievalDepth,
                sentinelRetrievalDepth: sentinelRetrievalDepth,
                engageRetrievalDepth: engageRetrievalDepth,
                reflectRetrievalDepth: reflectRetrievalDepth,
                deepLoopRetrievalDepth: deepLoopRetrievalDepth,
                guardRetrievalDepth: guardRetrievalDepth,
                recoveryRetrievalDepth: recoveryRetrievalDepth,
                quarantineRetrievalDepth: quarantineRetrievalDepth,
                lockdownRetrievalDepth: lockdownRetrievalDepth,
                dormantRetrievalDepth: dormantRetrievalDepth,
                standardLoopFloor: standardLoopFloor,
                protectedLoopFloor: protectedLoopFloor,
                standardCandidateFloor: standardCandidateFloor,
                protectedCandidateFloor: protectedCandidateFloor,
                candidateCountCap: maxCandidateCount,
                unstableLoopIncrement: unstableLoopIncrement,
                unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                throttleLoopPenalty: throttleLoopPenalty,
                throttleCandidatePenalty: throttleCandidatePenalty,
                throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                lightweightMaintenanceBatteryFloor: maintenance.lightBatteryFloor,
                standardMaintenanceBatteryFloor: maintenance.standardBatteryFloor,
                restrictedMaintenanceBatteryFloor: maintenanceBatteryFloor,
                lightweightAllowedClass: maintenance.lightweightAllowedClass,
                lightweightDeferredClass: maintenance.lightweightDeferredClass,
                activeRunModeClass: maintenance.activeRunModeClass,
                restrictedRunModeClass: maintenance.restrictedRunModeClass
            )[runMode.rawValue] ?? .init(
                maxLoops: lowRiskLoops,
                maxCandidates: lowRiskCandidates,
                retrievalDepth: lowRiskRetrievalDepth,
                defaultDecodeTokens: standardDecodeTokens,
                unstableDecodeTokens: unstableDecodeTokens,
                precisionProfile: lowRiskPrecisionProfile,
                defaultDeviceRoute: .coreNPU,
                npuUnavailableDeviceRoute: .coreGPU,
                candidateCountCap: maxCandidateCount,
                standardLoopFloor: standardLoopFloor,
                protectedLoopFloor: protectedLoopFloor,
                standardCandidateFloor: standardCandidateFloor,
                protectedCandidateFloor: protectedCandidateFloor,
                unstableLoopIncrement: unstableLoopIncrement,
                unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                throttleLoopPenalty: throttleLoopPenalty,
                throttleCandidatePenalty: throttleCandidatePenalty,
                throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                maintenanceSupported: true,
                maintenanceBatteryFloor: maintenance.standardBatteryFloor,
                scheduledMaintenanceClass: maintenance.activeRunModeClass,
                deferredMaintenanceClass: maintenance.activeRunModeClass
            )
        }

        public var missingRequiredRunModeProfileIDs: [String] {
            let requiredRunModes = Set(BASEBrainRunMode.allCases.map(\.rawValue))
            let declaredRunModes = Set((runModeProfilesByID ?? [:]).keys)
            return requiredRunModes.subtracting(declaredRunModes).sorted()
        }

        public var incompleteRunModeProfileIDs: [String] {
            guard let runModeProfilesByID else {
                return []
            }

            return runModeProfilesByID
                .filter { _, profile in
                    profile.defaultDecodeTokens == nil ||
                    profile.unstableDecodeTokens == nil ||
                    profile.candidateCountCap == nil ||
                    profile.standardLoopFloor == nil ||
                    profile.protectedLoopFloor == nil ||
                    profile.standardCandidateFloor == nil ||
                    profile.protectedCandidateFloor == nil ||
                    profile.unstableLoopIncrement == nil ||
                    profile.unstableLoopIncrementRiskLevels == nil ||
                    profile.throttleLoopPenalty == nil ||
                    profile.throttleCandidatePenalty == nil ||
                    profile.throttlePenaltyThermalLevels == nil ||
                    profile.maintenanceSupported == nil ||
                    profile.maintenanceBatteryFloor == nil ||
                    profile.scheduledMaintenanceClass == nil ||
                    profile.deferredMaintenanceClass == nil
                }
                .map(\.key)
                .sorted()
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let standardDecodeTokens = try container.decode(Int.self, forKey: .standardDecodeTokens)
            let unstableDecodeTokens = try container.decode(Int.self, forKey: .unstableDecodeTokens)
            let guardedDecodeTokens = try container.decode(Int.self, forKey: .guardedDecodeTokens)
            let maintenanceBatteryFloor = try container.decode(Double.self, forKey: .maintenanceBatteryFloor)
            let lowRiskLoops = try container.decode(Int.self, forKey: .lowRiskLoops)
            let mediumRiskLoops = try container.decode(Int.self, forKey: .mediumRiskLoops)
            let highRiskLoops = try container.decode(Int.self, forKey: .highRiskLoops)
            let extremeRiskLoops = try container.decode(Int.self, forKey: .extremeRiskLoops)
            let lowRiskCandidates = try container.decode(Int.self, forKey: .lowRiskCandidates)
            let mediumRiskCandidates = try container.decode(Int.self, forKey: .mediumRiskCandidates)
            let highRiskCandidates = try container.decode(Int.self, forKey: .highRiskCandidates)
            let extremeRiskCandidates = try container.decode(Int.self, forKey: .extremeRiskCandidates)
            let lowRiskRetrievalDepth = try container.decode(Int.self, forKey: .lowRiskRetrievalDepth)
            let mediumRiskRetrievalDepth = try container.decode(Int.self, forKey: .mediumRiskRetrievalDepth)
            let guardedRetrievalDepth = try container.decode(Int.self, forKey: .guardedRetrievalDepth)
            let standardLoopFloor = try container.decode(Int.self, forKey: .standardLoopFloor)
            let protectedLoopFloor = try container.decode(Int.self, forKey: .protectedLoopFloor)
            let standardCandidateFloor = try container.decode(Int.self, forKey: .standardCandidateFloor)
            let protectedCandidateFloor = try container.decode(Int.self, forKey: .protectedCandidateFloor)
            let maxCandidateCount = try container.decode(Int.self, forKey: .maxCandidateCount)
            let protectedFloorBoundaryModes = try container.decodeIfPresent(
                [BASBoundaryPolicyMode].self,
                forKey: .protectedFloorBoundaryModes
            ) ?? [.localOnlyProtective]
            let protectedFloorCalibrationStatuses = try container.decodeIfPresent(
                [BASCalibrationStatus].self,
                forKey: .protectedFloorCalibrationStatuses
            ) ?? []
            let unstableLoopIncrement = try container.decode(Int.self, forKey: .unstableLoopIncrement)
            let unstableLoopIncrementRiskLevels = try container.decode([BASBrainRiskLevel].self, forKey: .unstableLoopIncrementRiskLevels)
            let unstableBudgetCalibrationStatuses = try container.decode([BASCalibrationStatus].self, forKey: .unstableBudgetCalibrationStatuses)
            let nominalThermalGuardLevel = try container.decode(BASThermalGuardLevel.self, forKey: .nominalThermalGuardLevel)
            let warmThermalGuardLevel = try container.decode(BASThermalGuardLevel.self, forKey: .warmThermalGuardLevel)
            let hotThermalGuardLevel = try container.decode(BASThermalGuardLevel.self, forKey: .hotThermalGuardLevel)
            let criticalThermalGuardLevel = try container.decode(BASThermalGuardLevel.self, forKey: .criticalThermalGuardLevel)
            let throttleLoopPenalty = try container.decode(Int.self, forKey: .throttleLoopPenalty)
            let throttleCandidatePenalty = try container.decode(Int.self, forKey: .throttleCandidatePenalty)
            let throttlePenaltyThermalLevels = try container.decode([BASThermalLevel].self, forKey: .throttlePenaltyThermalLevels)
            let defaultPrecisionProfile = try container.decode(BASRuntimePrecisionProfile.self, forKey: .defaultPrecisionProfile)
            let unstablePrecisionProfile = try container.decode(BASRuntimePrecisionProfile.self, forKey: .unstablePrecisionProfile)
            let guardedPrecisionProfile = try container.decode(BASRuntimePrecisionProfile.self, forKey: .guardedPrecisionProfile)

            self.init(
                standardDecodeTokens: standardDecodeTokens,
                unstableDecodeTokens: unstableDecodeTokens,
                guardedDecodeTokens: guardedDecodeTokens,
                maintenanceBatteryFloor: maintenanceBatteryFloor,
                lowRiskLoops: lowRiskLoops,
                mediumRiskLoops: mediumRiskLoops,
                highRiskLoops: highRiskLoops,
                extremeRiskLoops: extremeRiskLoops,
                lowRiskCandidates: lowRiskCandidates,
                mediumRiskCandidates: mediumRiskCandidates,
                highRiskCandidates: highRiskCandidates,
                extremeRiskCandidates: extremeRiskCandidates,
                lowRiskRetrievalDepth: lowRiskRetrievalDepth,
                mediumRiskRetrievalDepth: mediumRiskRetrievalDepth,
                guardedRetrievalDepth: guardedRetrievalDepth,
                standardLoopFloor: standardLoopFloor,
                protectedLoopFloor: protectedLoopFloor,
                standardCandidateFloor: standardCandidateFloor,
                protectedCandidateFloor: protectedCandidateFloor,
                maxCandidateCount: maxCandidateCount,
                protectedFloorBoundaryModes: protectedFloorBoundaryModes,
                protectedFloorCalibrationStatuses: protectedFloorCalibrationStatuses,
                unstableLoopIncrement: unstableLoopIncrement,
                unstableLoopIncrementRiskLevels: unstableLoopIncrementRiskLevels,
                unstableBudgetCalibrationStatuses: unstableBudgetCalibrationStatuses,
                nominalThermalGuardLevel: nominalThermalGuardLevel,
                warmThermalGuardLevel: warmThermalGuardLevel,
                hotThermalGuardLevel: hotThermalGuardLevel,
                criticalThermalGuardLevel: criticalThermalGuardLevel,
                throttleLoopPenalty: throttleLoopPenalty,
                throttleCandidatePenalty: throttleCandidatePenalty,
                throttlePenaltyThermalLevels: throttlePenaltyThermalLevels,
                defaultPrecisionProfile: defaultPrecisionProfile,
                unstablePrecisionProfile: unstablePrecisionProfile,
                guardedPrecisionProfile: guardedPrecisionProfile,
                lowRiskPrecisionProfile: try container.decodeIfPresent(BASRuntimePrecisionProfile.self, forKey: .lowRiskPrecisionProfile),
                mediumRiskPrecisionProfile: try container.decodeIfPresent(BASRuntimePrecisionProfile.self, forKey: .mediumRiskPrecisionProfile),
                highRiskPrecisionProfile: try container.decodeIfPresent(BASRuntimePrecisionProfile.self, forKey: .highRiskPrecisionProfile),
                extremeRiskPrecisionProfile: try container.decodeIfPresent(BASRuntimePrecisionProfile.self, forKey: .extremeRiskPrecisionProfile),
                pulseRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .pulseRetrievalDepth),
                sentinelRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .sentinelRetrievalDepth),
                engageRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .engageRetrievalDepth),
                reflectRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .reflectRetrievalDepth),
                deepLoopRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .deepLoopRetrievalDepth),
                guardRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .guardRetrievalDepth),
                recoveryRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .recoveryRetrievalDepth),
                quarantineRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .quarantineRetrievalDepth),
                lockdownRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .lockdownRetrievalDepth),
                dormantRetrievalDepth: try container.decodeIfPresent(Int.self, forKey: .dormantRetrievalDepth),
                runModeProfilesByID: try container.decodeIfPresent([String: RunModeBudgetProfile].self, forKey: .runModeProfilesByID)
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(standardDecodeTokens, forKey: .standardDecodeTokens)
            try container.encode(unstableDecodeTokens, forKey: .unstableDecodeTokens)
            try container.encode(guardedDecodeTokens, forKey: .guardedDecodeTokens)
            try container.encode(maintenanceBatteryFloor, forKey: .maintenanceBatteryFloor)
            try container.encode(lowRiskLoops, forKey: .lowRiskLoops)
            try container.encode(mediumRiskLoops, forKey: .mediumRiskLoops)
            try container.encode(highRiskLoops, forKey: .highRiskLoops)
            try container.encode(extremeRiskLoops, forKey: .extremeRiskLoops)
            try container.encode(lowRiskCandidates, forKey: .lowRiskCandidates)
            try container.encode(mediumRiskCandidates, forKey: .mediumRiskCandidates)
            try container.encode(highRiskCandidates, forKey: .highRiskCandidates)
            try container.encode(extremeRiskCandidates, forKey: .extremeRiskCandidates)
            try container.encode(lowRiskRetrievalDepth, forKey: .lowRiskRetrievalDepth)
            try container.encode(mediumRiskRetrievalDepth, forKey: .mediumRiskRetrievalDepth)
            try container.encode(guardedRetrievalDepth, forKey: .guardedRetrievalDepth)
            try container.encode(standardLoopFloor, forKey: .standardLoopFloor)
            try container.encode(protectedLoopFloor, forKey: .protectedLoopFloor)
            try container.encode(standardCandidateFloor, forKey: .standardCandidateFloor)
            try container.encode(protectedCandidateFloor, forKey: .protectedCandidateFloor)
            try container.encode(maxCandidateCount, forKey: .maxCandidateCount)
            try container.encode(protectedFloorBoundaryModes, forKey: .protectedFloorBoundaryModes)
            try container.encode(protectedFloorCalibrationStatuses, forKey: .protectedFloorCalibrationStatuses)
            try container.encode(unstableLoopIncrement, forKey: .unstableLoopIncrement)
            try container.encode(unstableLoopIncrementRiskLevels, forKey: .unstableLoopIncrementRiskLevels)
            try container.encode(unstableBudgetCalibrationStatuses, forKey: .unstableBudgetCalibrationStatuses)
            try container.encode(nominalThermalGuardLevel, forKey: .nominalThermalGuardLevel)
            try container.encode(warmThermalGuardLevel, forKey: .warmThermalGuardLevel)
            try container.encode(hotThermalGuardLevel, forKey: .hotThermalGuardLevel)
            try container.encode(criticalThermalGuardLevel, forKey: .criticalThermalGuardLevel)
            try container.encode(throttleLoopPenalty, forKey: .throttleLoopPenalty)
            try container.encode(throttleCandidatePenalty, forKey: .throttleCandidatePenalty)
            try container.encode(throttlePenaltyThermalLevels, forKey: .throttlePenaltyThermalLevels)
            try container.encode(defaultPrecisionProfile, forKey: .defaultPrecisionProfile)
            try container.encode(unstablePrecisionProfile, forKey: .unstablePrecisionProfile)
            try container.encode(guardedPrecisionProfile, forKey: .guardedPrecisionProfile)
            try container.encode(lowRiskPrecisionProfile, forKey: .lowRiskPrecisionProfile)
            try container.encode(mediumRiskPrecisionProfile, forKey: .mediumRiskPrecisionProfile)
            try container.encode(highRiskPrecisionProfile, forKey: .highRiskPrecisionProfile)
            try container.encode(extremeRiskPrecisionProfile, forKey: .extremeRiskPrecisionProfile)
            try container.encode(pulseRetrievalDepth, forKey: .pulseRetrievalDepth)
            try container.encode(sentinelRetrievalDepth, forKey: .sentinelRetrievalDepth)
            try container.encode(engageRetrievalDepth, forKey: .engageRetrievalDepth)
            try container.encode(reflectRetrievalDepth, forKey: .reflectRetrievalDepth)
            try container.encode(deepLoopRetrievalDepth, forKey: .deepLoopRetrievalDepth)
            try container.encode(guardRetrievalDepth, forKey: .guardRetrievalDepth)
            try container.encode(recoveryRetrievalDepth, forKey: .recoveryRetrievalDepth)
            try container.encode(quarantineRetrievalDepth, forKey: .quarantineRetrievalDepth)
            try container.encode(lockdownRetrievalDepth, forKey: .lockdownRetrievalDepth)
            try container.encode(dormantRetrievalDepth, forKey: .dormantRetrievalDepth)
            try container.encodeIfPresent(runModeProfilesByID, forKey: .runModeProfilesByID)
        }
    }

    public struct WakeIntentTuning: Codable, Equatable, Sendable {
        public var pulseBatteryFloor: Double
        public var sentinelBatteryFloor: Double
        public var engageUrgencyIncrement: Double
        public var reflectCueIncrement: Double
        public var deepLoopCueIncrement: Double
        public var highRiskGuardThreshold: Double
        public var urgencyCuePhrases: [String]
        public var reflectiveCuePhrases: [String]
        public var deepLoopCuePhrases: [String]

        public init(
            pulseBatteryFloor: Double,
            sentinelBatteryFloor: Double,
            engageUrgencyIncrement: Double,
            reflectCueIncrement: Double,
            deepLoopCueIncrement: Double,
            highRiskGuardThreshold: Double,
            urgencyCuePhrases: [String] = ["now", "immediately", "urgent", "asap", "tonight", "must"],
            reflectiveCuePhrases: [String] = ["think", "reflect", "consider", "unclear", "confused", "compare"],
            deepLoopCuePhrases: [String] = ["plan", "strategy", "multi-step", "tradeoff", "pros and cons", "simulate"]
        ) {
            self.pulseBatteryFloor = pulseBatteryFloor
            self.sentinelBatteryFloor = sentinelBatteryFloor
            self.engageUrgencyIncrement = engageUrgencyIncrement
            self.reflectCueIncrement = reflectCueIncrement
            self.deepLoopCueIncrement = deepLoopCueIncrement
            self.highRiskGuardThreshold = highRiskGuardThreshold
            self.urgencyCuePhrases = urgencyCuePhrases
            self.reflectiveCuePhrases = reflectiveCuePhrases
            self.deepLoopCuePhrases = deepLoopCuePhrases
        }

        public func containsUrgency(_ text: String) -> Bool {
            containsCue(text, phrases: urgencyCuePhrases)
        }

        public func containsReflectiveCue(_ text: String) -> Bool {
            containsCue(text, phrases: reflectiveCuePhrases)
        }

        public func containsDeepLoopCue(_ text: String) -> Bool {
            containsCue(text, phrases: deepLoopCuePhrases)
        }

        private func containsCue(_ text: String, phrases: [String]) -> Bool {
            let normalized = text.lowercased()
            return phrases.contains { phrase in
                let normalizedPhrase = phrase
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return normalizedPhrase.isEmpty == false && normalized.contains(normalizedPhrase)
            }
        }

        public static let generic = WakeIntentTuning(
            pulseBatteryFloor: 0.18,
            sentinelBatteryFloor: 0.12,
            engageUrgencyIncrement: 0.18,
            reflectCueIncrement: 0.16,
            deepLoopCueIncrement: 0.26,
            highRiskGuardThreshold: 0.70,
            urgencyCuePhrases: ["now", "immediately", "urgent", "asap", "tonight", "must"],
            reflectiveCuePhrases: ["think", "reflect", "consider", "unclear", "confused", "compare"],
            deepLoopCuePhrases: ["plan", "strategy", "multi-step", "tradeoff", "pros and cons", "simulate"]
        )
    }

    struct BASRunModeTransitionContext: Equatable, Sendable {
        var riskLevel: BASBrainRiskLevel
        var thermalLevel: BASThermalLevel
        var foregroundState: BASForegroundState
        var batteryLevel: Double
        var guardedBudgetRequired: Bool
        var requiresRecovery: Bool
        var requiresQuarantine: Bool
        var urgencyDetected: Bool
        var reflectiveCueDetected: Bool
        var deepLoopCueDetected: Bool
    }

    public struct StateTransitionTuning: Codable, Equatable, Sendable {
        public struct RunModeTransitionRule: Codable, Equatable, Sendable {
            public var ruleID: String
            public var resultMode: BASEBrainRunMode
            public var riskLevels: [BASBrainRiskLevel]?
            public var thermalLevels: [BASThermalLevel]?
            public var foregroundStates: [BASForegroundState]?
            public var requiresGuardedBudget: Bool?
            public var requiresRecovery: Bool?
            public var requiresQuarantine: Bool?
            public var urgencyDetected: Bool?
            public var reflectiveCueDetected: Bool?
            public var deepLoopCueDetected: Bool?
            public var minimumBatteryLevel: Double?

            public init(
                ruleID: String,
                resultMode: BASEBrainRunMode,
                riskLevels: [BASBrainRiskLevel]? = nil,
                thermalLevels: [BASThermalLevel]? = nil,
                foregroundStates: [BASForegroundState]? = nil,
                requiresGuardedBudget: Bool? = nil,
                requiresRecovery: Bool? = nil,
                requiresQuarantine: Bool? = nil,
                urgencyDetected: Bool? = nil,
                reflectiveCueDetected: Bool? = nil,
                deepLoopCueDetected: Bool? = nil,
                minimumBatteryLevel: Double? = nil
            ) {
                self.ruleID = ruleID
                self.resultMode = resultMode
                self.riskLevels = riskLevels
                self.thermalLevels = thermalLevels
                self.foregroundStates = foregroundStates
                self.requiresGuardedBudget = requiresGuardedBudget
                self.requiresRecovery = requiresRecovery
                self.requiresQuarantine = requiresQuarantine
                self.urgencyDetected = urgencyDetected
                self.reflectiveCueDetected = reflectiveCueDetected
                self.deepLoopCueDetected = deepLoopCueDetected
                self.minimumBatteryLevel = minimumBatteryLevel.map { min(max($0, 0), 1) }
            }

            func matches(_ context: BASRunModeTransitionContext) -> Bool {
                if let riskLevels, riskLevels.contains(context.riskLevel) == false {
                    return false
                }
                if let thermalLevels, thermalLevels.contains(context.thermalLevel) == false {
                    return false
                }
                if let foregroundStates, foregroundStates.contains(context.foregroundState) == false {
                    return false
                }
                if let requiresGuardedBudget, requiresGuardedBudget != context.guardedBudgetRequired {
                    return false
                }
                if let requiresRecovery, requiresRecovery != context.requiresRecovery {
                    return false
                }
                if let requiresQuarantine, requiresQuarantine != context.requiresQuarantine {
                    return false
                }
                if let urgencyDetected, urgencyDetected != context.urgencyDetected {
                    return false
                }
                if let reflectiveCueDetected, reflectiveCueDetected != context.reflectiveCueDetected {
                    return false
                }
                if let deepLoopCueDetected, deepLoopCueDetected != context.deepLoopCueDetected {
                    return false
                }
                if let minimumBatteryLevel, context.batteryLevel < minimumBatteryLevel {
                    return false
                }
                return true
            }
        }

        public var backgroundPulseEnabled: Bool
        public var recoveryOnCriticalThermal: Bool
        public var reflectOnTrustDrift: Bool
        public var deepLoopOnProtectedBoundary: Bool
        public var guardedBudgetBoundaryModes: [BASBoundaryPolicyMode]
        public var guardedBudgetCalibrationStatuses: [BASCalibrationStatus]
        public var guardedBudgetRiskFlags: [BASBrainStateRiskFlag]
        public var guardedBudgetRetrievalTags: [String]
        public var lockdownOnExtremeBlockedPermit: Bool
        public var quarantineFailureGuardThreshold: Int
        public var criticalThermalMode: BASEBrainRunMode
        public var lowRiskBackgroundMode: BASEBrainRunMode
        public var lowRiskProtectedMode: BASEBrainRunMode
        public var lowRiskUrgentMode: BASEBrainRunMode
        public var lowRiskDefaultMode: BASEBrainRunMode
        public var mediumRiskProtectedDeepLoopMode: BASEBrainRunMode
        public var mediumRiskReflectiveMode: BASEBrainRunMode
        public var mediumRiskDefaultMode: BASEBrainRunMode
        public var highRiskMode: BASEBrainRunMode
        public var extremeRiskMode: BASEBrainRunMode
        public var recoveryMode: BASEBrainRunMode
        public var quarantineMode: BASEBrainRunMode
        public var runModeRules: [RunModeTransitionRule]?

        private enum CodingKeys: String, CodingKey {
            case backgroundPulseEnabled
            case recoveryOnCriticalThermal
            case reflectOnTrustDrift
            case deepLoopOnProtectedBoundary
            case guardedBudgetBoundaryModes
            case guardedBudgetCalibrationStatuses
            case guardedBudgetRiskFlags
            case guardedBudgetRetrievalTags
            case lockdownOnExtremeBlockedPermit
            case quarantineFailureGuardThreshold
            case criticalThermalMode
            case lowRiskBackgroundMode
            case lowRiskProtectedMode
            case lowRiskUrgentMode
            case lowRiskDefaultMode
            case mediumRiskProtectedDeepLoopMode
            case mediumRiskReflectiveMode
            case mediumRiskDefaultMode
            case highRiskMode
            case extremeRiskMode
            case recoveryMode
            case quarantineMode
            case runModeRules
        }

        public init(
            backgroundPulseEnabled: Bool,
            recoveryOnCriticalThermal: Bool,
            reflectOnTrustDrift: Bool,
            deepLoopOnProtectedBoundary: Bool,
            guardedBudgetBoundaryModes: [BASBoundaryPolicyMode] = [.localOnlyProtective],
            guardedBudgetCalibrationStatuses: [BASCalibrationStatus] = [],
            guardedBudgetRiskFlags: [BASBrainStateRiskFlag] = [
                .lowTrustLoad,
                .retrievalInstability,
                .externalRefreshGuardTriggered,
                .observationOnlyQuarantine,
                .evidenceCaveatLoad
            ],
            guardedBudgetRetrievalTags: [String] = ["evidence_caveat"],
            lockdownOnExtremeBlockedPermit: Bool,
            quarantineFailureGuardThreshold: Int,
            criticalThermalMode: BASEBrainRunMode? = nil,
            lowRiskBackgroundMode: BASEBrainRunMode = .pulse,
            lowRiskProtectedMode: BASEBrainRunMode = .engage,
            lowRiskUrgentMode: BASEBrainRunMode = .engage,
            lowRiskDefaultMode: BASEBrainRunMode = .sentinel,
            mediumRiskProtectedDeepLoopMode: BASEBrainRunMode = .deepLoop,
            mediumRiskReflectiveMode: BASEBrainRunMode = .reflect,
            mediumRiskDefaultMode: BASEBrainRunMode = .engage,
            highRiskMode: BASEBrainRunMode = .guard,
            extremeRiskMode: BASEBrainRunMode? = nil,
            recoveryMode: BASEBrainRunMode = .recovery,
            quarantineMode: BASEBrainRunMode = .quarantine,
            runModeRules: [RunModeTransitionRule]? = nil
        ) {
            self.backgroundPulseEnabled = backgroundPulseEnabled
            self.recoveryOnCriticalThermal = recoveryOnCriticalThermal
            self.reflectOnTrustDrift = reflectOnTrustDrift
            self.deepLoopOnProtectedBoundary = deepLoopOnProtectedBoundary
            self.guardedBudgetBoundaryModes = guardedBudgetBoundaryModes
            self.guardedBudgetCalibrationStatuses = guardedBudgetCalibrationStatuses
            self.guardedBudgetRiskFlags = guardedBudgetRiskFlags
            self.guardedBudgetRetrievalTags = guardedBudgetRetrievalTags
            self.lockdownOnExtremeBlockedPermit = lockdownOnExtremeBlockedPermit
            self.quarantineFailureGuardThreshold = quarantineFailureGuardThreshold
            self.criticalThermalMode = criticalThermalMode ?? (recoveryOnCriticalThermal ? .recovery : .guard)
            self.lowRiskBackgroundMode = lowRiskBackgroundMode
            self.lowRiskProtectedMode = lowRiskProtectedMode
            self.lowRiskUrgentMode = lowRiskUrgentMode
            self.lowRiskDefaultMode = lowRiskDefaultMode
            self.mediumRiskProtectedDeepLoopMode = mediumRiskProtectedDeepLoopMode
            self.mediumRiskReflectiveMode = mediumRiskReflectiveMode
            self.mediumRiskDefaultMode = mediumRiskDefaultMode
            self.highRiskMode = highRiskMode
            self.extremeRiskMode = extremeRiskMode ?? (lockdownOnExtremeBlockedPermit ? .lockdown : .guard)
            self.recoveryMode = recoveryMode
            self.quarantineMode = quarantineMode
            self.runModeRules = runModeRules
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let backgroundPulseEnabled = try container.decode(Bool.self, forKey: .backgroundPulseEnabled)
            let recoveryOnCriticalThermal = try container.decode(Bool.self, forKey: .recoveryOnCriticalThermal)
            let reflectOnTrustDrift = try container.decode(Bool.self, forKey: .reflectOnTrustDrift)
            let deepLoopOnProtectedBoundary = try container.decode(Bool.self, forKey: .deepLoopOnProtectedBoundary)
            let guardedBudgetBoundaryModes = try container.decodeIfPresent(
                [BASBoundaryPolicyMode].self,
                forKey: .guardedBudgetBoundaryModes
            ) ?? [.localOnlyProtective]
            let guardedBudgetCalibrationStatuses = try container.decodeIfPresent(
                [BASCalibrationStatus].self,
                forKey: .guardedBudgetCalibrationStatuses
            ) ?? []
            let guardedBudgetRiskFlags = try container.decodeIfPresent(
                [BASBrainStateRiskFlag].self,
                forKey: .guardedBudgetRiskFlags
            ) ?? [
                .lowTrustLoad,
                .retrievalInstability,
                .externalRefreshGuardTriggered,
                .observationOnlyQuarantine,
                .evidenceCaveatLoad
            ]
            let guardedBudgetRetrievalTags = try container.decodeIfPresent(
                [String].self,
                forKey: .guardedBudgetRetrievalTags
            ) ?? ["evidence_caveat"]
            let lockdownOnExtremeBlockedPermit = try container.decode(Bool.self, forKey: .lockdownOnExtremeBlockedPermit)
            let quarantineFailureGuardThreshold = try container.decode(Int.self, forKey: .quarantineFailureGuardThreshold)

            self.init(
                backgroundPulseEnabled: backgroundPulseEnabled,
                recoveryOnCriticalThermal: recoveryOnCriticalThermal,
                reflectOnTrustDrift: reflectOnTrustDrift,
                deepLoopOnProtectedBoundary: deepLoopOnProtectedBoundary,
                guardedBudgetBoundaryModes: guardedBudgetBoundaryModes,
                guardedBudgetCalibrationStatuses: guardedBudgetCalibrationStatuses,
                guardedBudgetRiskFlags: guardedBudgetRiskFlags,
                guardedBudgetRetrievalTags: guardedBudgetRetrievalTags,
                lockdownOnExtremeBlockedPermit: lockdownOnExtremeBlockedPermit,
                quarantineFailureGuardThreshold: quarantineFailureGuardThreshold,
                criticalThermalMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .criticalThermalMode),
                lowRiskBackgroundMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .lowRiskBackgroundMode) ?? .pulse,
                lowRiskProtectedMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .lowRiskProtectedMode) ?? .engage,
                lowRiskUrgentMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .lowRiskUrgentMode) ?? .engage,
                lowRiskDefaultMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .lowRiskDefaultMode) ?? .sentinel,
                mediumRiskProtectedDeepLoopMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .mediumRiskProtectedDeepLoopMode) ?? .deepLoop,
                mediumRiskReflectiveMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .mediumRiskReflectiveMode) ?? .reflect,
                mediumRiskDefaultMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .mediumRiskDefaultMode) ?? .engage,
                highRiskMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .highRiskMode) ?? .guard,
                extremeRiskMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .extremeRiskMode),
                recoveryMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .recoveryMode) ?? .recovery,
                quarantineMode: try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .quarantineMode) ?? .quarantine,
                runModeRules: try container.decodeIfPresent([RunModeTransitionRule].self, forKey: .runModeRules)
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(backgroundPulseEnabled, forKey: .backgroundPulseEnabled)
            try container.encode(recoveryOnCriticalThermal, forKey: .recoveryOnCriticalThermal)
            try container.encode(reflectOnTrustDrift, forKey: .reflectOnTrustDrift)
            try container.encode(deepLoopOnProtectedBoundary, forKey: .deepLoopOnProtectedBoundary)
            try container.encode(guardedBudgetBoundaryModes, forKey: .guardedBudgetBoundaryModes)
            try container.encode(guardedBudgetCalibrationStatuses, forKey: .guardedBudgetCalibrationStatuses)
            try container.encode(guardedBudgetRiskFlags, forKey: .guardedBudgetRiskFlags)
            try container.encode(guardedBudgetRetrievalTags, forKey: .guardedBudgetRetrievalTags)
            try container.encode(lockdownOnExtremeBlockedPermit, forKey: .lockdownOnExtremeBlockedPermit)
            try container.encode(quarantineFailureGuardThreshold, forKey: .quarantineFailureGuardThreshold)
            try container.encode(criticalThermalMode, forKey: .criticalThermalMode)
            try container.encode(lowRiskBackgroundMode, forKey: .lowRiskBackgroundMode)
            try container.encode(lowRiskProtectedMode, forKey: .lowRiskProtectedMode)
            try container.encode(lowRiskUrgentMode, forKey: .lowRiskUrgentMode)
            try container.encode(lowRiskDefaultMode, forKey: .lowRiskDefaultMode)
            try container.encode(mediumRiskProtectedDeepLoopMode, forKey: .mediumRiskProtectedDeepLoopMode)
            try container.encode(mediumRiskReflectiveMode, forKey: .mediumRiskReflectiveMode)
            try container.encode(mediumRiskDefaultMode, forKey: .mediumRiskDefaultMode)
            try container.encode(highRiskMode, forKey: .highRiskMode)
            try container.encode(extremeRiskMode, forKey: .extremeRiskMode)
            try container.encode(recoveryMode, forKey: .recoveryMode)
            try container.encode(quarantineMode, forKey: .quarantineMode)
            try container.encodeIfPresent(runModeRules, forKey: .runModeRules)
        }

        public var requiredRunModeRuleIDs: Set<String> {
            [
                "thermal.critical",
                "state.quarantine",
                "state.recovery",
                "risk.low.default",
                "risk.medium.default",
                "risk.high.default",
                "risk.extreme.default"
            ]
        }

        public func missingRequiredRunModeRuleIDs() -> [String] {
            let declaredRuleIDs = Set((runModeRules ?? []).map(\.ruleID))
            return requiredRunModeRuleIDs.subtracting(declaredRuleIDs).sorted()
        }

        public func resolvedRunModeRules(
            wakeIntent: WakeIntentTuning
        ) -> [RunModeTransitionRule] {
            runModeRules ?? synthesizedRunModeRules(wakeIntent: wakeIntent)
        }

        public func requiresGuardedBudget(
            boundaryMode: BASBoundaryPolicyMode,
            calibrationStatus: BASCalibrationStatus,
            riskFlags: [BASBrainStateRiskFlag],
            retrievalTags: [String]
        ) -> Bool {
            if guardedBudgetBoundaryModes.contains(boundaryMode) {
                return true
            }
            if guardedBudgetCalibrationStatuses.contains(calibrationStatus) {
                return true
            }
            if riskFlags.contains(where: { guardedBudgetRiskFlags.contains($0) }) {
                return true
            }

            let normalizedTags = Set(retrievalTags.map { $0.lowercased() })
            return guardedBudgetRetrievalTags.contains { normalizedTags.contains($0.lowercased()) }
        }

        func resolvedRunMode(
            for context: BASRunModeTransitionContext,
            wakeIntent: WakeIntentTuning
        ) -> BASEBrainRunMode {
            if let matchedRule = resolvedRunModeRules(wakeIntent: wakeIntent).first(where: { $0.matches(context) }) {
                return matchedRule.resultMode
            }

            return quarantineMode
        }

        private func synthesizedRunModeRules(
            wakeIntent: WakeIntentTuning
        ) -> [RunModeTransitionRule] {
            var rules: [RunModeTransitionRule] = [
                .init(
                    ruleID: "thermal.critical",
                    resultMode: criticalThermalMode,
                    thermalLevels: [.critical]
                ),
                .init(
                    ruleID: "state.quarantine",
                    resultMode: quarantineMode,
                    requiresQuarantine: true
                ),
                .init(
                    ruleID: "state.recovery",
                    resultMode: recoveryMode,
                    requiresRecovery: true
                )
            ]

            if backgroundPulseEnabled {
                rules.append(
                    .init(
                        ruleID: "risk.low.background_pulse",
                        resultMode: lowRiskBackgroundMode,
                        riskLevels: [.low],
                        foregroundStates: [.background, .suspended],
                        urgencyDetected: false,
                        minimumBatteryLevel: wakeIntent.pulseBatteryFloor
                    )
                )
            }

            rules.append(
                .init(
                    ruleID: "risk.low.protected",
                    resultMode: lowRiskProtectedMode,
                    riskLevels: [.low],
                    requiresGuardedBudget: true
                )
            )
            rules.append(
                .init(
                    ruleID: "risk.low.urgent",
                    resultMode: lowRiskUrgentMode,
                    riskLevels: [.low],
                    requiresGuardedBudget: false,
                    urgencyDetected: true
                )
            )
            rules.append(
                .init(
                    ruleID: "risk.low.default",
                    resultMode: lowRiskDefaultMode,
                    riskLevels: [.low],
                    requiresGuardedBudget: false,
                    urgencyDetected: false
                )
            )

            if deepLoopOnProtectedBoundary {
                rules.append(
                    .init(
                        ruleID: "risk.medium.protected_deep_loop",
                        resultMode: mediumRiskProtectedDeepLoopMode,
                        riskLevels: [.medium],
                        requiresGuardedBudget: true,
                        deepLoopCueDetected: true
                    )
                )
            }

            rules.append(
                .init(
                    ruleID: "risk.medium.reflective_cue",
                    resultMode: mediumRiskReflectiveMode,
                    riskLevels: [.medium],
                    reflectiveCueDetected: true
                )
            )

            if reflectOnTrustDrift {
                rules.append(
                    .init(
                        ruleID: "risk.medium.guarded_reflect",
                        resultMode: mediumRiskReflectiveMode,
                        riskLevels: [.medium],
                        requiresGuardedBudget: true
                    )
                )
            }

            rules.append(
                .init(
                    ruleID: "risk.medium.default",
                    resultMode: mediumRiskDefaultMode,
                    riskLevels: [.medium]
                )
            )
            rules.append(
                .init(
                    ruleID: "risk.high.default",
                    resultMode: highRiskMode,
                    riskLevels: [.high]
                )
            )
            rules.append(
                .init(
                    ruleID: "risk.extreme.default",
                    resultMode: extremeRiskMode,
                    riskLevels: [.extreme]
                )
            )
            return rules
        }

        public static let generic = StateTransitionTuning(
            backgroundPulseEnabled: true,
            recoveryOnCriticalThermal: true,
            reflectOnTrustDrift: true,
            deepLoopOnProtectedBoundary: true,
            lockdownOnExtremeBlockedPermit: true,
            quarantineFailureGuardThreshold: 2
        )
    }

    public struct LeaseTuning: Codable, Equatable, Sendable {
        public var deepLoopDurationMs: Int
        public var protectedDurationMs: Int
        public var restrictedDurationMs: Int
        public var standardEnergyQuota: Double
        public var restrictedEnergyQuota: Double

        public init(
            deepLoopDurationMs: Int,
            protectedDurationMs: Int,
            restrictedDurationMs: Int,
            standardEnergyQuota: Double,
            restrictedEnergyQuota: Double
        ) {
            self.deepLoopDurationMs = deepLoopDurationMs
            self.protectedDurationMs = protectedDurationMs
            self.restrictedDurationMs = restrictedDurationMs
            self.standardEnergyQuota = standardEnergyQuota
            self.restrictedEnergyQuota = restrictedEnergyQuota
        }

        public static let generic = LeaseTuning(
            deepLoopDurationMs: 1_800,
            protectedDurationMs: 1_200,
            restrictedDurationMs: 900,
            standardEnergyQuota: 0.74,
            restrictedEnergyQuota: 0.48
        )
    }

    public struct MaintenanceTuning: Codable, Equatable, Sendable {
        public var lightBatteryFloor: Double
        public var standardBatteryFloor: Double
        public var allowedThermalLevels: [BASThermalLevel]
        public var blockedForegroundStates: [BASForegroundState]
        public var lightweightAllowedClass: BASMaintenanceClass
        public var lightweightDeferredClass: BASMaintenanceClass
        public var activeRunModeClass: BASMaintenanceClass
        public var restrictedRunModeClass: BASMaintenanceClass

        private enum CodingKeys: String, CodingKey {
            case lightBatteryFloor
            case standardBatteryFloor
            case allowedThermalLevels
            case blockedForegroundStates
            case lightweightAllowedClass
            case lightweightDeferredClass
            case activeRunModeClass
            case restrictedRunModeClass
        }

        public init(
            lightBatteryFloor: Double,
            standardBatteryFloor: Double,
            allowedThermalLevels: [BASThermalLevel] = [.nominal],
            blockedForegroundStates: [BASForegroundState] = [.foreground],
            lightweightAllowedClass: BASMaintenanceClass = .light,
            lightweightDeferredClass: BASMaintenanceClass = .deferred,
            activeRunModeClass: BASMaintenanceClass = .none,
            restrictedRunModeClass: BASMaintenanceClass = .none
        ) {
            self.lightBatteryFloor = lightBatteryFloor
            self.standardBatteryFloor = standardBatteryFloor
            self.allowedThermalLevels = allowedThermalLevels
            self.blockedForegroundStates = blockedForegroundStates
            self.lightweightAllowedClass = lightweightAllowedClass
            self.lightweightDeferredClass = lightweightDeferredClass
            self.activeRunModeClass = activeRunModeClass
            self.restrictedRunModeClass = restrictedRunModeClass
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                lightBatteryFloor: try container.decode(Double.self, forKey: .lightBatteryFloor),
                standardBatteryFloor: try container.decode(Double.self, forKey: .standardBatteryFloor),
                allowedThermalLevels: try container.decode([BASThermalLevel].self, forKey: .allowedThermalLevels),
                blockedForegroundStates: try container.decode([BASForegroundState].self, forKey: .blockedForegroundStates),
                lightweightAllowedClass: try container.decodeIfPresent(BASMaintenanceClass.self, forKey: .lightweightAllowedClass) ?? .light,
                lightweightDeferredClass: try container.decodeIfPresent(BASMaintenanceClass.self, forKey: .lightweightDeferredClass) ?? .deferred,
                activeRunModeClass: try container.decodeIfPresent(BASMaintenanceClass.self, forKey: .activeRunModeClass) ?? .none,
                restrictedRunModeClass: try container.decodeIfPresent(BASMaintenanceClass.self, forKey: .restrictedRunModeClass) ?? .none
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(lightBatteryFloor, forKey: .lightBatteryFloor)
            try container.encode(standardBatteryFloor, forKey: .standardBatteryFloor)
            try container.encode(allowedThermalLevels, forKey: .allowedThermalLevels)
            try container.encode(blockedForegroundStates, forKey: .blockedForegroundStates)
            try container.encode(lightweightAllowedClass, forKey: .lightweightAllowedClass)
            try container.encode(lightweightDeferredClass, forKey: .lightweightDeferredClass)
            try container.encode(activeRunModeClass, forKey: .activeRunModeClass)
            try container.encode(restrictedRunModeClass, forKey: .restrictedRunModeClass)
        }

        public static let generic = MaintenanceTuning(
            lightBatteryFloor: 0.22,
            standardBatteryFloor: 0.35,
            allowedThermalLevels: [.nominal],
            blockedForegroundStates: [.foreground]
        )
    }

    public struct SovereignExecutionTuning: Codable, Equatable, Sendable {
        public var toolCutOnBlockedPermit: Bool
        public var memoryFreezeOnReviewedWrites: Bool
        public var guardShiftOnHighRisk: Bool
        public var deadStopOnExtremeBlockedPermit: Bool

        public init(
            toolCutOnBlockedPermit: Bool,
            memoryFreezeOnReviewedWrites: Bool,
            guardShiftOnHighRisk: Bool,
            deadStopOnExtremeBlockedPermit: Bool
        ) {
            self.toolCutOnBlockedPermit = toolCutOnBlockedPermit
            self.memoryFreezeOnReviewedWrites = memoryFreezeOnReviewedWrites
            self.guardShiftOnHighRisk = guardShiftOnHighRisk
            self.deadStopOnExtremeBlockedPermit = deadStopOnExtremeBlockedPermit
        }

        public static let generic = SovereignExecutionTuning(
            toolCutOnBlockedPermit: true,
            memoryFreezeOnReviewedWrites: true,
            guardShiftOnHighRisk: true,
            deadStopOnExtremeBlockedPermit: true
        )
    }

    public struct HostThresholdTuning: Codable, Equatable, Sendable {
        public var caution: Double
        public var protective: Double
        public var block: Double

        public init(
            caution: Double,
            protective: Double,
            block: Double
        ) {
            self.caution = caution
            self.protective = protective
            self.block = block
        }
    }

    public struct ContextTuning: Codable, Equatable, Sendable {
        public var trustInstabilityIncrement: Double
        public var guardedPressureIncrement: Double
        public var emotionalLoadHighRisk: Double
        public var emotionalLoadReflective: Double
        public var emotionalLoadDefault: Double
        public var emotionalLoadDriftingIncrement: Double
        public var timePressureReopen: Double
        public var timePressureUrgent: Double
        public var timePressureDefault: Double
        public var ambiguityComparative: Double
        public var ambiguityDefault: Double
        public var consequenceHigh: Double
        public var consequenceMedium: Double
        public var consequenceLow: Double

        public init(
            trustInstabilityIncrement: Double,
            guardedPressureIncrement: Double,
            emotionalLoadHighRisk: Double,
            emotionalLoadReflective: Double,
            emotionalLoadDefault: Double,
            emotionalLoadDriftingIncrement: Double,
            timePressureReopen: Double,
            timePressureUrgent: Double,
            timePressureDefault: Double,
            ambiguityComparative: Double,
            ambiguityDefault: Double,
            consequenceHigh: Double,
            consequenceMedium: Double,
            consequenceLow: Double
        ) {
            self.trustInstabilityIncrement = trustInstabilityIncrement
            self.guardedPressureIncrement = guardedPressureIncrement
            self.emotionalLoadHighRisk = emotionalLoadHighRisk
            self.emotionalLoadReflective = emotionalLoadReflective
            self.emotionalLoadDefault = emotionalLoadDefault
            self.emotionalLoadDriftingIncrement = emotionalLoadDriftingIncrement
            self.timePressureReopen = timePressureReopen
            self.timePressureUrgent = timePressureUrgent
            self.timePressureDefault = timePressureDefault
            self.ambiguityComparative = ambiguityComparative
            self.ambiguityDefault = ambiguityDefault
            self.consequenceHigh = consequenceHigh
            self.consequenceMedium = consequenceMedium
            self.consequenceLow = consequenceLow
        }

        public static let generic = ContextTuning(
            trustInstabilityIncrement: 0.12,
            guardedPressureIncrement: 0.10,
            emotionalLoadHighRisk: 0.72,
            emotionalLoadReflective: 0.46,
            emotionalLoadDefault: 0.30,
            emotionalLoadDriftingIncrement: 0.08,
            timePressureReopen: 0.66,
            timePressureUrgent: 0.74,
            timePressureDefault: 0.24,
            ambiguityComparative: 0.42,
            ambiguityDefault: 0.28,
            consequenceHigh: 0.84,
            consequenceMedium: 0.56,
            consequenceLow: 0.26
        )
    }

    public struct TriSelfWeightProfile: Codable, Equatable, Sendable {
        public var id: Double
        public var ego: Double
        public var superego: Double

        public init(
            id: Double,
            ego: Double,
            superego: Double
        ) {
            self.id = id
            self.ego = ego
            self.superego = superego
        }
    }

    public struct TriSelfTuning: Codable, Equatable, Sendable {
        public var assertiveInitiativeLift: Double
        public var idCostWeight: Double
        public var egoReversibilityWeight: Double
        public var egoConfidenceWeight: Double
        public var directPathSuperegoPenalty: Double
        public var reflectiveWeights: TriSelfWeightProfile
        public var coachingWeights: TriSelfWeightProfile
        public var protectiveWeights: TriSelfWeightProfile

        public init(
            assertiveInitiativeLift: Double,
            idCostWeight: Double,
            egoReversibilityWeight: Double,
            egoConfidenceWeight: Double,
            directPathSuperegoPenalty: Double,
            reflectiveWeights: TriSelfWeightProfile,
            coachingWeights: TriSelfWeightProfile,
            protectiveWeights: TriSelfWeightProfile
        ) {
            self.assertiveInitiativeLift = assertiveInitiativeLift
            self.idCostWeight = idCostWeight
            self.egoReversibilityWeight = egoReversibilityWeight
            self.egoConfidenceWeight = egoConfidenceWeight
            self.directPathSuperegoPenalty = directPathSuperegoPenalty
            self.reflectiveWeights = reflectiveWeights
            self.coachingWeights = coachingWeights
            self.protectiveWeights = protectiveWeights
        }

        public static let generic = TriSelfTuning(
            assertiveInitiativeLift: 0.06,
            idCostWeight: 0.4,
            egoReversibilityWeight: 0.5,
            egoConfidenceWeight: 0.5,
            directPathSuperegoPenalty: 0.45,
            reflectiveWeights: TriSelfWeightProfile(id: 0.24, ego: 0.34, superego: 0.42),
            coachingWeights: TriSelfWeightProfile(id: 0.28, ego: 0.38, superego: 0.34),
            protectiveWeights: TriSelfWeightProfile(id: 0.18, ego: 0.30, superego: 0.52)
        )
    }

    public struct RiskTuning: Codable, Equatable, Sendable {
        public var directCandidateLowReversibilityThreshold: Double
        public var directCandidatePenalty: Double
        public var vetoPressureIncrement: Double
        public var emotionalLoadWeight: Double
        public var timePressureWeight: Double
        public var consequenceWeight: Double
        public var manipulationHintWeight: Double
        public var critiqueSeverityWeight: Double
        public var mediumThreshold: Double
        public var highThreshold: Double
        public var extremeThreshold: Double
        public var defaultForecastUncertainty: Double
        public var defaultCandidateReversibility: Double
        public var manipulationStrengthUnit: Double
        public var gsiHintWeight: Double
        public var gsiTimePressureThreshold: Double
        public var gsiTimePressureIncrement: Double
        public var gsiTrustDriftIncrement: Double
        public var gsiLowTrustAlertIncrement: Double

        public init(
            directCandidateLowReversibilityThreshold: Double,
            directCandidatePenalty: Double,
            vetoPressureIncrement: Double,
            emotionalLoadWeight: Double,
            timePressureWeight: Double,
            consequenceWeight: Double,
            manipulationHintWeight: Double,
            critiqueSeverityWeight: Double,
            mediumThreshold: Double,
            highThreshold: Double,
            extremeThreshold: Double,
            defaultForecastUncertainty: Double,
            defaultCandidateReversibility: Double,
            manipulationStrengthUnit: Double,
            gsiHintWeight: Double,
            gsiTimePressureThreshold: Double,
            gsiTimePressureIncrement: Double,
            gsiTrustDriftIncrement: Double,
            gsiLowTrustAlertIncrement: Double
        ) {
            self.directCandidateLowReversibilityThreshold = directCandidateLowReversibilityThreshold
            self.directCandidatePenalty = directCandidatePenalty
            self.vetoPressureIncrement = vetoPressureIncrement
            self.emotionalLoadWeight = emotionalLoadWeight
            self.timePressureWeight = timePressureWeight
            self.consequenceWeight = consequenceWeight
            self.manipulationHintWeight = manipulationHintWeight
            self.critiqueSeverityWeight = critiqueSeverityWeight
            self.mediumThreshold = mediumThreshold
            self.highThreshold = highThreshold
            self.extremeThreshold = extremeThreshold
            self.defaultForecastUncertainty = defaultForecastUncertainty
            self.defaultCandidateReversibility = defaultCandidateReversibility
            self.manipulationStrengthUnit = manipulationStrengthUnit
            self.gsiHintWeight = gsiHintWeight
            self.gsiTimePressureThreshold = gsiTimePressureThreshold
            self.gsiTimePressureIncrement = gsiTimePressureIncrement
            self.gsiTrustDriftIncrement = gsiTrustDriftIncrement
            self.gsiLowTrustAlertIncrement = gsiLowTrustAlertIncrement
        }

        public static let generic = RiskTuning(
            directCandidateLowReversibilityThreshold: 0.5,
            directCandidatePenalty: 0.12,
            vetoPressureIncrement: 0.08,
            emotionalLoadWeight: 0.20,
            timePressureWeight: 0.15,
            consequenceWeight: 0.25,
            manipulationHintWeight: 0.10,
            critiqueSeverityWeight: 0.20,
            mediumThreshold: 0.35,
            highThreshold: 0.65,
            extremeThreshold: 0.85,
            defaultForecastUncertainty: 0.22,
            defaultCandidateReversibility: 0.5,
            manipulationStrengthUnit: 0.35,
            gsiHintWeight: 0.26,
            gsiTimePressureThreshold: 0.6,
            gsiTimePressureIncrement: 0.12,
            gsiTrustDriftIncrement: 0.18,
            gsiLowTrustAlertIncrement: 0.10
        )
    }

    public var schemaVersion: String
    public var guardrailPressure: GuardrailPressureTuning
    public var budget: BudgetTuning
    public var wakeIntent: WakeIntentTuning
    public var stateTransitions: StateTransitionTuning
    public var lease: LeaseTuning
    public var maintenance: MaintenanceTuning
    public var sovereignExecution: SovereignExecutionTuning
    public var hostThresholds: HostThresholdTuning
    public var context: ContextTuning
    public var triSelf: TriSelfTuning
    public var risk: RiskTuning

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case guardrailPressure
        case budget
        case wakeIntent
        case stateTransitions
        case lease
        case maintenance
        case sovereignExecution
        case hostThresholds
        case context
        case triSelf
        case risk
    }

    public init(
        schemaVersion: String,
        guardrailPressure: GuardrailPressureTuning,
        budget: BudgetTuning,
        wakeIntent: WakeIntentTuning = .generic,
        stateTransitions: StateTransitionTuning = .generic,
        lease: LeaseTuning = .generic,
        maintenance: MaintenanceTuning = .generic,
        sovereignExecution: SovereignExecutionTuning = .generic,
        hostThresholds: HostThresholdTuning,
        context: ContextTuning = .generic,
        triSelf: TriSelfTuning = .generic,
        risk: RiskTuning = .generic
    ) {
        self.schemaVersion = schemaVersion
        self.guardrailPressure = guardrailPressure
        self.budget = budget
        self.wakeIntent = wakeIntent
        self.stateTransitions = stateTransitions
        self.lease = lease
        self.maintenance = maintenance
        self.sovereignExecution = sovereignExecution
        self.hostThresholds = hostThresholds
        self.context = context
        self.triSelf = triSelf
        self.risk = risk
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(String.self, forKey: .schemaVersion),
            guardrailPressure: try container.decode(GuardrailPressureTuning.self, forKey: .guardrailPressure),
            budget: try container.decode(BudgetTuning.self, forKey: .budget),
            wakeIntent: try container.decode(WakeIntentTuning.self, forKey: .wakeIntent),
            stateTransitions: try container.decode(StateTransitionTuning.self, forKey: .stateTransitions),
            lease: try container.decode(LeaseTuning.self, forKey: .lease),
            maintenance: try container.decode(MaintenanceTuning.self, forKey: .maintenance),
            sovereignExecution: try container.decode(SovereignExecutionTuning.self, forKey: .sovereignExecution),
            hostThresholds: try container.decode(HostThresholdTuning.self, forKey: .hostThresholds),
            context: try container.decode(ContextTuning.self, forKey: .context),
            triSelf: try container.decode(TriSelfTuning.self, forKey: .triSelf),
            risk: try container.decode(RiskTuning.self, forKey: .risk)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(guardrailPressure, forKey: .guardrailPressure)
        try container.encode(budget, forKey: .budget)
        try container.encode(wakeIntent, forKey: .wakeIntent)
        try container.encode(stateTransitions, forKey: .stateTransitions)
        try container.encode(lease, forKey: .lease)
        try container.encode(maintenance, forKey: .maintenance)
        try container.encode(sovereignExecution, forKey: .sovereignExecution)
        try container.encode(hostThresholds, forKey: .hostThresholds)
        try container.encode(context, forKey: .context)
        try container.encode(triSelf, forKey: .triSelf)
        try container.encode(risk, forKey: .risk)
    }

    public func withSchemaVersion(_ schemaVersion: String) -> BASEBrainRuntimeSynthesisPolicy {
        var copy = self
        copy.schemaVersion = schemaVersion
        return copy
    }

    public var compiledGenericFamilyIDs: [String] {
        var families: [String] = []
        if wakeIntent == .generic {
            families.append("wakeIntent")
        }
        if stateTransitions == .generic {
            families.append("stateTransitions")
        }
        if lease == .generic {
            families.append("lease")
        }
        if maintenance == .generic {
            families.append("maintenance")
        }
        if sovereignExecution == .generic {
            families.append("sovereignExecution")
        }
        if context == .generic {
            families.append("context")
        }
        if triSelf == .generic {
            families.append("triSelf")
        }
        if risk == .generic {
            families.append("risk")
        }
        return families
    }

    public var compiledPlannerFallbackComponentIDs: [String] {
        var components: [String] = []

        if budget.runModeProfilesByID == nil {
            components.append("budget.runModeProfilesByID")
        } else {
            components.append(
                contentsOf: budget.missingRequiredRunModeProfileIDs.map { "budget.runModeProfilesByID.\($0)" }
            )
            components.append(
                contentsOf: budget.incompleteRunModeProfileIDs.map { "budget.runModeProfilesByID.\($0)" }
            )
        }

        if let runModeRules = stateTransitions.runModeRules {
            if runModeRules.isEmpty {
                components.append("stateTransitions.runModeRules")
            } else {
                components.append(
                    contentsOf: stateTransitions
                        .missingRequiredRunModeRuleIDs()
                        .map { "stateTransitions.runModeRules.\($0)" }
                )
            }
        } else {
            components.append("stateTransitions.runModeRules")
        }

        return components
    }

    public var compiledFallbackComponentIDs: [String] {
        var components = compiledGenericFamilyIDs
        components.append(contentsOf: compiledPlannerFallbackComponentIDs)
        return components
    }

    public var usesCompiledFallbackEnvelope: Bool {
        self == .generic || self == .missing || compiledFallbackComponentIDs.isEmpty == false
    }

    public static let generic = BASEBrainRuntimeSynthesisPolicy(
        schemaVersion: "host.runtime-synthesis.v1",
        guardrailPressure: GuardrailPressureTuning(
            protectiveBoundaryIncrement: 0.18,
            calibrationWatchIncrement: 0.10,
            calibrationDriftingIncrement: 0.18,
            boundaryConstraintUnit: 0.03,
            boundaryConstraintCap: 0.18,
            calibrationAlertUnit: 0.03,
            calibrationAlertCap: 0.15,
            failureGuardUnit: 0.02,
            failureGuardCap: 0.12,
            riskFlagUnit: 0.035,
            riskFlagCap: 0.14,
            maximumPressure: 0.65
        ),
        budget: BudgetTuning(
            standardDecodeTokens: 160,
            unstableDecodeTokens: 192,
            guardedDecodeTokens: 220,
            maintenanceBatteryFloor: 0.35,
            runModeProfilesByID: BudgetTuning(
                standardDecodeTokens: 160,
                unstableDecodeTokens: 192,
                guardedDecodeTokens: 220,
                maintenanceBatteryFloor: 0.35
            ).resolvedRunModeProfilesByID()
        ),
        wakeIntent: .generic,
        stateTransitions: .generic,
        lease: .generic,
        maintenance: .generic,
        sovereignExecution: .generic,
        hostThresholds: HostThresholdTuning(
            caution: 0.45,
            protective: 0.72,
            block: 0.92
        ),
        context: .generic,
        triSelf: .generic,
        risk: .generic
    )

    public static let missing: BASEBrainRuntimeSynthesisPolicy = {
        var policy = BASEBrainRuntimeSynthesisPolicy.generic
        policy.schemaVersion = "host.runtime-synthesis.missing.v1"
        return policy
    }()
}

public struct BASEBrainRuntimeSynthesisPolicyRegistry: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var defaultPolicyID: String
    public var policiesByID: [String: BASEBrainRuntimeSynthesisPolicy]

    public init(
        schemaVersion: String,
        defaultPolicyID: String,
        policiesByID: [String: BASEBrainRuntimeSynthesisPolicy]
    ) {
        self.schemaVersion = schemaVersion
        self.defaultPolicyID = defaultPolicyID
        self.policiesByID = policiesByID
    }

    public func policyIfAvailable(
        for policyID: String? = nil
    ) -> BASEBrainRuntimeSynthesisPolicy? {
        if let policyID {
            return policiesByID[policyID]
        }

        return policiesByID[defaultPolicyID]
    }

    public func policy(for policyID: String? = nil) -> BASEBrainRuntimeSynthesisPolicy {
        policyIfAvailable(for: policyID) ?? .missing
    }
}

public struct BASEBrainRuntimeSynthesisPolicySource: Codable, Equatable, Sendable {
    public var registry: BASEBrainRuntimeSynthesisPolicyRegistry
    public var policyID: String?

    public init(
        registry: BASEBrainRuntimeSynthesisPolicyRegistry,
        policyID: String? = nil
    ) {
        self.registry = registry
        self.policyID = policyID
    }

    public var registryVersion: String {
        registry.schemaVersion
    }

    public var resolvedPolicy: BASEBrainRuntimeSynthesisPolicy {
        registry.policy(for: policyID)
    }

    public var resolvedPolicyIfAvailable: BASEBrainRuntimeSynthesisPolicy? {
        registry.policyIfAvailable(for: policyID)
    }
}

public struct BASHostConfiguration: Codable, Equatable, Sendable {
    public enum ControlPlaneIssue: String, Codable, Equatable, Sendable {
        case missingRuntimePolicyLineage = "missing_runtime_policy_lineage"
        case compiledDefaultDeviceState = "compiled_default_device_state"
        case compiledRuntimeTuning = "compiled_runtime_tuning"
        case compiledHostRhythmProfile = "compiled_host_rhythm_profile"
    }

    public enum ControlPlaneExecutionDisposition: String, Codable, Equatable, Sendable {
        case normal
        case recovery
        case quarantine
    }

    public var runtimeProfileID: String
    public var policyProfileID: String
    public var prefersPureLocal: Bool
    public var defaultDeviceState: BASDeviceState
    public var console: BASHostConsoleConfiguration
    public var lifecycleBehavior: BASHostLifecycleBehaviorConfiguration
    public var workflowBehavior: BASHostWorkflowBehaviorConfiguration
    public var cognitionBehavior: BASHostCognitionBehaviorConfiguration
    public var presentation: BASHostPresentationConfiguration
    public var runtimeTuning: BASEBrainRuntimeSynthesisPolicy
    public var runtimePolicyLineage: BASRuntimePolicyLineage?
    public var hostRhythmProfile: BASHostRhythmProfile
    public var hostConstitution: BASHostConstitution?
    public var hostConstitutionVault: BASHostConstitutionVault?
    public var hostVersionTree: BASHostVersionTree?
    public var hostForgetRequest: BASForgetRequest?

    private enum CodingKeys: String, CodingKey {
        case runtimeProfileID
        case policyProfileID
        case prefersPureLocal
        case defaultDeviceState
        case console
        case lifecycleBehavior
        case workflowBehavior
        case cognitionBehavior
        case presentation
        case runtimeTuning
        case runtimePolicyLineage
        case hostRhythmProfile
        case hostConstitution
        case hostConstitutionVault
        case hostVersionTree
        case hostForgetRequest
    }

    public init(
        runtimeProfileID: String,
        policyProfileID: String,
        prefersPureLocal: Bool,
        defaultDeviceState: BASDeviceState = BASHostConfiguration.genericDefaultDeviceState,
        console: BASHostConsoleConfiguration,
        lifecycleBehavior: BASHostLifecycleBehaviorConfiguration,
        workflowBehavior: BASHostWorkflowBehaviorConfiguration,
        cognitionBehavior: BASHostCognitionBehaviorConfiguration,
        presentation: BASHostPresentationConfiguration,
        runtimeTuning: BASEBrainRuntimeSynthesisPolicy = .generic,
        runtimePolicyLineage: BASRuntimePolicyLineage? = nil,
        hostRhythmProfile: BASHostRhythmProfile = .generic,
        hostConstitution: BASHostConstitution? = nil,
        hostConstitutionVault: BASHostConstitutionVault? = nil,
        hostVersionTree: BASHostVersionTree? = nil,
        hostForgetRequest: BASForgetRequest? = nil
    ) {
        self.runtimeProfileID = runtimeProfileID
        self.policyProfileID = policyProfileID
        self.prefersPureLocal = prefersPureLocal
        self.defaultDeviceState = defaultDeviceState
        self.console = console
        self.lifecycleBehavior = lifecycleBehavior
        self.workflowBehavior = workflowBehavior
        self.cognitionBehavior = cognitionBehavior
        self.presentation = presentation
        self.runtimeTuning = runtimeTuning
        self.runtimePolicyLineage = runtimePolicyLineage
        self.hostRhythmProfile = hostRhythmProfile
        self.hostConstitution = hostConstitution
        self.hostConstitutionVault = hostConstitutionVault
        self.hostVersionTree = hostVersionTree
        self.hostForgetRequest = hostForgetRequest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let runtimeProfileID = try container.decode(String.self, forKey: .runtimeProfileID)
        let policyProfileID = try container.decode(String.self, forKey: .policyProfileID)
        let prefersPureLocal = try container.decode(Bool.self, forKey: .prefersPureLocal)
        let runtimePolicyLineage = try container.decodeIfPresent(
            BASRuntimePolicyLineage.self,
            forKey: .runtimePolicyLineage
        )

        self.init(
            runtimeProfileID: runtimeProfileID,
            policyProfileID: policyProfileID,
            prefersPureLocal: prefersPureLocal,
            defaultDeviceState: try container.decode(BASDeviceState.self, forKey: .defaultDeviceState),
            console: try container.decode(BASHostConsoleConfiguration.self, forKey: .console),
            lifecycleBehavior: try container.decode(BASHostLifecycleBehaviorConfiguration.self, forKey: .lifecycleBehavior),
            workflowBehavior: try container.decode(BASHostWorkflowBehaviorConfiguration.self, forKey: .workflowBehavior),
            cognitionBehavior: try container.decode(BASHostCognitionBehaviorConfiguration.self, forKey: .cognitionBehavior),
            presentation: try container.decode(BASHostPresentationConfiguration.self, forKey: .presentation),
            runtimeTuning: try container.decode(BASEBrainRuntimeSynthesisPolicy.self, forKey: .runtimeTuning),
            runtimePolicyLineage: runtimePolicyLineage,
            hostRhythmProfile: try container.decode(BASHostRhythmProfile.self, forKey: .hostRhythmProfile),
            hostConstitution: try container.decodeIfPresent(BASHostConstitution.self, forKey: .hostConstitution),
            hostConstitutionVault: try container.decodeIfPresent(BASHostConstitutionVault.self, forKey: .hostConstitutionVault),
            hostVersionTree: try container.decodeIfPresent(BASHostVersionTree.self, forKey: .hostVersionTree),
            hostForgetRequest: try container.decodeIfPresent(BASForgetRequest.self, forKey: .hostForgetRequest)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(runtimeProfileID, forKey: .runtimeProfileID)
        try container.encode(policyProfileID, forKey: .policyProfileID)
        try container.encode(prefersPureLocal, forKey: .prefersPureLocal)
        try container.encode(defaultDeviceState, forKey: .defaultDeviceState)
        try container.encode(console, forKey: .console)
        try container.encode(lifecycleBehavior, forKey: .lifecycleBehavior)
        try container.encode(workflowBehavior, forKey: .workflowBehavior)
        try container.encode(cognitionBehavior, forKey: .cognitionBehavior)
        try container.encode(presentation, forKey: .presentation)
        try container.encode(runtimeTuning, forKey: .runtimeTuning)
        try container.encodeIfPresent(runtimePolicyLineage, forKey: .runtimePolicyLineage)
        try container.encode(hostRhythmProfile, forKey: .hostRhythmProfile)
        try container.encodeIfPresent(hostConstitution, forKey: .hostConstitution)
        try container.encodeIfPresent(hostConstitutionVault, forKey: .hostConstitutionVault)
        try container.encodeIfPresent(hostVersionTree, forKey: .hostVersionTree)
        try container.encodeIfPresent(hostForgetRequest, forKey: .hostForgetRequest)
    }

    public var controlPlaneIssues: [ControlPlaneIssue] {
        var issues: [ControlPlaneIssue] = []

        if runtimePolicyLineage == nil {
            issues.append(.missingRuntimePolicyLineage)
        }
        if runtimePolicyLineage == nil && defaultDeviceState == BASHostConfiguration.genericDefaultDeviceState {
            issues.append(.compiledDefaultDeviceState)
        }
        if runtimeTuning.usesCompiledFallbackEnvelope {
            issues.append(.compiledRuntimeTuning)
        }
        if runtimePolicyLineage == nil && hostRhythmProfile == .generic {
            issues.append(.compiledHostRhythmProfile)
        }

        return issues
    }

    public var controlPlaneExecutionDisposition: ControlPlaneExecutionDisposition {
        let issues = controlPlaneIssues
        guard issues.isEmpty == false else {
            return .normal
        }

        if issues.contains(.compiledDefaultDeviceState) ||
            issues.contains(.compiledRuntimeTuning) ||
            issues.contains(.compiledHostRhythmProfile) {
            return .quarantine
        }

        return .recovery
    }

    public var controlPlaneReasonCodes: [String] {
        controlPlaneIssues.map { "control_plane.\($0.rawValue)" }
    }

    public static let genericDefaultDeviceState = BASDeviceState(
        batteryLevel: 0.78,
        thermalLevel: .nominal,
        memoryFreeMB: 3_072,
        networkState: .constrained,
        foregroundState: .foreground,
        cpuLoad: 0.18,
        gpuLoad: 0.10,
        npuAvailable: true,
        latencyBudgetMs: 1_200
    )

    public static let generic = BASHostConfiguration(
        runtimeProfileID: "host.default-runtime",
        policyProfileID: "host.default-policy",
        prefersPureLocal: true,
        defaultDeviceState: genericDefaultDeviceState,
        console: .generic,
        lifecycleBehavior: .generic,
        workflowBehavior: .generic,
        cognitionBehavior: .generic,
        presentation: .generic,
        runtimeTuning: .generic,
        runtimePolicyLineage: nil,
        hostRhythmProfile: .generic,
        hostConstitution: nil,
        hostConstitutionVault: nil,
        hostVersionTree: nil,
        hostForgetRequest: nil
    )
}

public struct BASHostDependencySet: Codable, Equatable, Sendable {
    public var protectedStorageProviderID: String
    public var handoffProviderID: String
    public var notificationProviderID: String
    public var modelRegistryID: String
    public var persistenceProviderID: String

    public init(
        protectedStorageProviderID: String = "host.protected-storage",
        handoffProviderID: String = "host.handoff",
        notificationProviderID: String = "host.notifications",
        modelRegistryID: String = "host.model-registry",
        persistenceProviderID: String = "host.persistence"
    ) {
        self.protectedStorageProviderID = protectedStorageProviderID
        self.handoffProviderID = handoffProviderID
        self.notificationProviderID = notificationProviderID
        self.modelRegistryID = modelRegistryID
        self.persistenceProviderID = persistenceProviderID
    }
}

public struct BASHostLifecycleRequest: Codable, Equatable, Sendable {
    public var phase: BASHostLifecyclePhase
    public var sessionKind: BASHostSessionKind
    public var preferredProfile: BASHostWorkflowProfile
    public var sourceSurface: BASHostSurface
    public var promptSeed: String
    public var riskLevel: BASHostRiskLevel

    public init(
        phase: BASHostLifecyclePhase,
        sessionKind: BASHostSessionKind,
        preferredProfile: BASHostWorkflowProfile,
        sourceSurface: BASHostSurface,
        promptSeed: String = "",
        riskLevel: BASHostRiskLevel
    ) {
        self.phase = phase
        self.sessionKind = sessionKind
        self.preferredProfile = preferredProfile
        self.sourceSurface = sourceSurface
        self.promptSeed = promptSeed
        self.riskLevel = riskLevel
    }
}

public struct BASHostSessionRequest: Codable, Equatable, Sendable {
    public var kind: BASHostSessionKind
    public var workflowProfile: BASHostWorkflowProfile
    public var surface: BASHostSurface
    public var prompt: String
    public var title: String?
    public var detail: String?
    public var riskLevel: BASHostRiskLevel
    public var triggerReason: String?
    public var activeKillSwitches: [BASKillSwitchID]

    public init(
        kind: BASHostSessionKind,
        workflowProfile: BASHostWorkflowProfile,
        surface: BASHostSurface = .application,
        prompt: String,
        title: String? = nil,
        detail: String? = nil,
        riskLevel: BASHostRiskLevel = .low,
        triggerReason: String? = nil,
        activeKillSwitches: [BASKillSwitchID] = []
    ) {
        self.kind = kind
        self.workflowProfile = workflowProfile
        self.surface = surface
        self.prompt = prompt
        self.title = title
        self.detail = detail
        self.riskLevel = riskLevel
        self.triggerReason = triggerReason
        self.activeKillSwitches = activeKillSwitches
    }
}

public struct BASHostReopenRequest: Codable, Equatable, Sendable {
    public var workflowProfile: BASHostWorkflowProfile
    public var title: String
    public var detail: String?
    public var promptSeed: String
    public var riskLevel: BASHostRiskLevel
    public var reopenHint: String?
    public var templateHint: String?
    public var interventionHistorySummary: String?
    public var activeKillSwitches: [BASKillSwitchID]

    public init(
        workflowProfile: BASHostWorkflowProfile,
        title: String,
        detail: String? = nil,
        promptSeed: String,
        riskLevel: BASHostRiskLevel = .low,
        reopenHint: String? = nil,
        templateHint: String? = nil,
        interventionHistorySummary: String? = nil,
        activeKillSwitches: [BASKillSwitchID] = []
    ) {
        self.workflowProfile = workflowProfile
        self.title = title
        self.detail = detail
        self.promptSeed = promptSeed
        self.riskLevel = riskLevel
        self.reopenHint = reopenHint
        self.templateHint = templateHint
        self.interventionHistorySummary = interventionHistorySummary
        self.activeKillSwitches = activeKillSwitches
    }
}

public struct BASHostGovernanceSummary: Codable, Equatable, Sendable {
    public var totalRecordCount: Int
    public var totalCandidateCount: Int
    public var pendingCandidateCount: Int
    public var promotedCandidateCount: Int
    public var loadedPromotedMemoryCount: Int
    public var loadedPendingMemoryCount: Int

    public init(
        totalRecordCount: Int,
        totalCandidateCount: Int,
        pendingCandidateCount: Int,
        promotedCandidateCount: Int,
        loadedPromotedMemoryCount: Int,
        loadedPendingMemoryCount: Int
    ) {
        self.totalRecordCount = totalRecordCount
        self.totalCandidateCount = totalCandidateCount
        self.pendingCandidateCount = pendingCandidateCount
        self.promotedCandidateCount = promotedCandidateCount
        self.loadedPromotedMemoryCount = loadedPromotedMemoryCount
        self.loadedPendingMemoryCount = loadedPendingMemoryCount
    }
}

public struct BASHostProjectionSummary: Codable, Equatable, Sendable {
    public var recordCount: Int
    public var candidateCount: Int
    public var recentEventCount: Int
    public var activeTemplateIDs: [String]
    public var failureGuardIDs: [String]
    public var governance: BASHostGovernanceSummary?

    public init(
        recordCount: Int,
        candidateCount: Int,
        recentEventCount: Int,
        activeTemplateIDs: [String],
        failureGuardIDs: [String],
        governance: BASHostGovernanceSummary? = nil
    ) {
        self.recordCount = recordCount
        self.candidateCount = candidateCount
        self.recentEventCount = recentEventCount
        self.activeTemplateIDs = activeTemplateIDs
        self.failureGuardIDs = failureGuardIDs
        self.governance = governance
    }
}

public struct BASHostCurrentBrain: Codable, Equatable, Sendable {
    public var workflowProfile: BASHostWorkflowProfile
    public var workflowTitle: String
    public var roleID: String
    public var identityPosture: BASIdentityPosture
    public var identityInitiative: BASIdentityInitiative
    public var confidenceCeiling: Double
    public var relationshipBoundary: String
    public var boundaryHeadline: String
    public var boundaryMode: BASBoundaryPolicyMode
    public var boundaryConstraints: [BASBoundaryConstraint]
    public var calibrationStatus: BASCalibrationStatus
    public var calibrationAlerts: [BASMemory.BASCalibrationAlert]
    public var riskFlags: [BASBrainStateRiskFlag]
    public var dominantGoals: [String]
    public var activeConstraints: [String]
    public var retrievalTags: [String]
    public var verificationSummary: String
    public var activeTemplateCount: Int
    public var failureGuardCount: Int
    public var evolutionPendingReviewCount: Int
    public var evolutionRollbackReady: Bool

    public init(
        workflowProfile: BASHostWorkflowProfile,
        workflowTitle: String,
        roleID: String,
        identityPosture: BASIdentityPosture,
        identityInitiative: BASIdentityInitiative,
        confidenceCeiling: Double,
        relationshipBoundary: String,
        boundaryHeadline: String,
        boundaryMode: BASBoundaryPolicyMode,
        boundaryConstraints: [BASBoundaryConstraint],
        calibrationStatus: BASCalibrationStatus,
        calibrationAlerts: [BASMemory.BASCalibrationAlert],
        riskFlags: [BASBrainStateRiskFlag],
        dominantGoals: [String],
        activeConstraints: [String],
        retrievalTags: [String],
        verificationSummary: String,
        activeTemplateCount: Int,
        failureGuardCount: Int,
        evolutionPendingReviewCount: Int,
        evolutionRollbackReady: Bool
    ) {
        self.workflowProfile = workflowProfile
        self.workflowTitle = workflowTitle
        self.roleID = roleID
        self.identityPosture = identityPosture
        self.identityInitiative = identityInitiative
        self.confidenceCeiling = confidenceCeiling
        self.relationshipBoundary = relationshipBoundary
        self.boundaryHeadline = boundaryHeadline
        self.boundaryMode = boundaryMode
        self.boundaryConstraints = boundaryConstraints
        self.calibrationStatus = calibrationStatus
        self.calibrationAlerts = calibrationAlerts
        self.riskFlags = riskFlags
        self.dominantGoals = dominantGoals
        self.activeConstraints = activeConstraints
        self.retrievalTags = retrievalTags
        self.verificationSummary = verificationSummary
        self.activeTemplateCount = activeTemplateCount
        self.failureGuardCount = failureGuardCount
        self.evolutionPendingReviewCount = evolutionPendingReviewCount
        self.evolutionRollbackReady = evolutionRollbackReady
    }
}

public typealias BASHostConsoleSnapshot = BASConsoleSnapshot
public typealias BASHostConsoleView = BASConsoleView

public struct BASHostSessionResult: Codable, Equatable, Sendable {
    public var requestKind: BASHostSessionKind
    public var workflowProfile: BASHostWorkflowProfile
    public var currentBrain: BASHostCurrentBrain
    public var projection: BASHostProjectionSummary
    public var eBrainTurn: BASEBrainTurnResult?
    public var activeSessionTitle: String
    public var notices: [String]
    public var followUpActions: [String]
    public var interventionSuggestion: BASHostInterventionSuggestion?
    public var consoleSnapshot: BASHostConsoleSnapshot

    public init(
        requestKind: BASHostSessionKind,
        workflowProfile: BASHostWorkflowProfile,
        currentBrain: BASHostCurrentBrain,
        projection: BASHostProjectionSummary,
        eBrainTurn: BASEBrainTurnResult? = nil,
        activeSessionTitle: String,
        notices: [String],
        followUpActions: [String],
        interventionSuggestion: BASHostInterventionSuggestion? = nil,
        consoleSnapshot: BASHostConsoleSnapshot
    ) {
        self.requestKind = requestKind
        self.workflowProfile = workflowProfile
        self.currentBrain = currentBrain
        self.projection = projection
        self.eBrainTurn = eBrainTurn
        self.activeSessionTitle = activeSessionTitle
        self.notices = notices
        self.followUpActions = followUpActions
        self.interventionSuggestion = interventionSuggestion
        self.consoleSnapshot = consoleSnapshot
    }
}

public struct BASHostInterventionSuggestion: Codable, Equatable, Sendable {
    public var riskLevel: BASHostRiskLevel
    public var title: String
    public var detail: String
    public var evidenceSignalCount: Int
    public var preferredWorkflowProfile: BASHostWorkflowProfile?
    public var reason: String
    public var expiresAt: Date

    public init(
        riskLevel: BASHostRiskLevel,
        title: String,
        detail: String,
        evidenceSignalCount: Int,
        preferredWorkflowProfile: BASHostWorkflowProfile?,
        reason: String,
        expiresAt: Date
    ) {
        self.riskLevel = riskLevel
        self.title = title
        self.detail = detail
        self.evidenceSignalCount = evidenceSignalCount
        self.preferredWorkflowProfile = preferredWorkflowProfile
        self.reason = reason
        self.expiresAt = expiresAt
    }
}

public struct BASHostRuntime: Sendable {
    public let configuration: BASHostConfiguration
    public let dependencies: BASHostDependencySet
    public let vitalMonitor: (any BASVitalMonitorServicing)?

    public init(
        configuration: BASHostConfiguration,
        dependencies: BASHostDependencySet = BASHostDependencySet(),
        vitalMonitor: (any BASVitalMonitorServicing)? = nil
    ) {
        self.configuration = configuration
        self.dependencies = dependencies
        self.vitalMonitor = vitalMonitor
    }

    public func stageHostConstitutionChange(
        _ candidate: BASHostChangeCandidate,
        on constitution: BASHostConstitution
    ) -> BASHostConstitution {
        constitution.staged(with: candidate)
    }

    public func approveHostConstitutionChange(
        _ candidate: BASHostChangeCandidate,
        on versionTree: BASHostVersionTree
    ) -> BASHostVersionTree {
        versionTree.approving(candidate)
    }

    public func freezeHostConstitutionVersionTree(
        _ versionTree: BASHostVersionTree,
        versionID: String
    ) -> BASHostVersionTree {
        versionTree.freezing(versionID: versionID)
    }

    public func thawHostConstitutionVersionTree(
        _ versionTree: BASHostVersionTree,
        versionID: String
    ) -> BASHostVersionTree {
        versionTree.thawing(versionID: versionID)
    }

    public func rollbackHostConstitutionVersionTree(
        _ versionTree: BASHostVersionTree,
        to versionID: String
    ) -> BASHostVersionTree {
        versionTree.rollingBack(to: versionID)
    }

    public func executeHostForget(
        _ request: BASForgetRequest,
        on constitution: BASHostConstitution
    ) -> BASForgetRequest {
        request.executingCanonicalCascade()
    }

    public func applyHostForgetToConstitutionVault(
        _ request: BASForgetRequest,
        on vault: BASHostConstitutionVault
    ) -> BASHostConstitutionVault {
        vault.applyingForget(request)
    }

    public func stageHostConstitutionMigration(
        _ contract: BASHostDeviceMigrationContract,
        on vault: BASHostConstitutionVault
    ) -> BASHostConstitutionVault {
        vault.stagingMigration(contract)
    }

    public func approveHostConstitutionMigration(
        _ vault: BASHostConstitutionVault,
        targetDeviceID: String? = nil
    ) -> BASHostConstitutionVault {
        vault.approvingMigration(targetDeviceID: targetDeviceID)
    }

    public func synchronizeHostConstitutionVault(
        _ vault: BASHostConstitutionVault,
        deviceID: String,
        propagatedRequestIDs: [String] = [],
        synchronizedAt: Date = .now
    ) -> BASHostConstitutionVault {
        vault.synchronizingDevice(
            deviceID,
            propagatedRequestIDs: propagatedRequestIDs,
            synchronizedAt: synchronizedAt
        )
    }

    public func executeLifecyclePhase<Envelope, PendingRequest>(
        _ phase: BASHostLifecyclePhase,
        refreshMemoryProjection: () -> Void,
        refreshCurrentBrain: (String) -> Void,
        presentPendingReflection: () -> Void,
        consumeHandoff: () -> Envelope?,
        handleHandoff: (Envelope) -> Void,
        consumePendingRequest: () -> PendingRequest?,
        handlePendingRequest: (PendingRequest) -> Void,
        restoreActiveWorkspace: () -> Void,
        refreshPredictedIntervention: () -> Void,
        syncWidgetSnapshot: () -> Void = {}
    ) {
        BASAppleAppLifecycleOrchestrationExecutor.execute(
            phase: phase.bootstrapPhase,
            behavior: configuration.lifecycleBehavior.bootstrapBehavior,
            refreshMemoryProjection: refreshMemoryProjection,
            refreshCurrentBrain: refreshCurrentBrain,
            presentPendingReflection: presentPendingReflection,
            consumeHandoff: consumeHandoff,
            handleHandoff: handleHandoff,
            consumePendingRequest: consumePendingRequest,
            handlePendingRequest: handlePendingRequest,
            restoreActiveWorkspace: restoreActiveWorkspace,
            refreshPredictedIntervention: refreshPredictedIntervention,
            syncWidgetSnapshot: syncWidgetSnapshot
        )
    }

    public func consumeLifecycleEntriesIfNeeded<Envelope, PendingRequest>(
        consumeHandoff: () -> Envelope?,
        handleHandoff: (Envelope) -> Void,
        consumePendingRequest: () -> PendingRequest?,
        handlePendingRequest: (PendingRequest) -> Void
    ) {
        BASAppleAppLifecycleOrchestrationExecutor.consumeEntriesIfNeeded(
            consumeHandoff: consumeHandoff,
            handleHandoff: handleHandoff,
            consumePendingRequest: consumePendingRequest,
            handlePendingRequest: handlePendingRequest
        )
    }

    public func commitProjectionRefresh<Projection>(
        outcome: BASAppleProjectionRefreshResult<Projection>,
        commitProjection: (Projection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void
    ) {
        BASAppleCurrentBrainHostStateExecutor.commitProjectionRefresh(
            outcome: outcome,
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice
        )
    }

    public func resolveProjectionRefresh<Projection>(
        using resolver: () -> BASAppleProjectionRefreshResult<Projection>,
        commitProjection: (Projection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void
    ) {
        commitProjectionRefresh(
            outcome: resolver(),
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice
        )
    }

    public func commitCurrentBrainProjection<CurrentBrain, Projection>(
        outcome: BASAppleCurrentBrainProjectionRuntimeResult<CurrentBrain, Projection>,
        commitProjection: (Projection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void,
        commitCurrentBrain: (CurrentBrain) -> Void
    ) {
        BASAppleCurrentBrainHostStateExecutor.commitCurrentBrainProjection(
            outcome: outcome,
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice,
            commitCurrentBrain: commitCurrentBrain
        )
    }

    public func resolveCurrentBrainProjection<CurrentBrain, Projection>(
        using resolver: () -> BASAppleCurrentBrainProjectionRuntimeResult<CurrentBrain, Projection>,
        commitProjection: (Projection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void,
        commitCurrentBrain: (CurrentBrain) -> Void
    ) {
        commitCurrentBrainProjection(
            outcome: resolver(),
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice,
            commitCurrentBrain: commitCurrentBrain
        )
    }

    public func activateSession<Session, CurrentBrain, Projection>(
        session: Session,
        outcome: BASAppleCurrentBrainProjectionRuntimeResult<CurrentBrain, Projection>,
        loadBrainState: (Session, CurrentBrain) -> Void,
        commitProjection: (Projection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void,
        commitCurrentBrain: (CurrentBrain) -> Void,
        commitSession: (Session) -> Void
    ) {
        BASAppleCurrentBrainHostStateExecutor.activateSession(
            session: session,
            outcome: outcome,
            loadBrainState: loadBrainState,
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice,
            commitCurrentBrain: commitCurrentBrain,
            commitSession: commitSession
        )
    }

    public func resolveAndActivateSession<Session, CurrentBrain, Projection>(
        session: Session,
        using resolver: () -> BASAppleCurrentBrainProjectionRuntimeResult<CurrentBrain, Projection>,
        loadBrainState: (Session, CurrentBrain) -> Void,
        commitProjection: (Projection) -> Void,
        setProjectionDirty: (Bool) -> Void,
        publishNotice: (String) -> Void,
        commitCurrentBrain: (CurrentBrain) -> Void,
        commitSession: (Session) -> Void
    ) {
        activateSession(
            session: session,
            outcome: resolver(),
            loadBrainState: loadBrainState,
            commitProjection: commitProjection,
            setProjectionDirty: setProjectionDirty,
            publishNotice: publishNotice,
            commitCurrentBrain: commitCurrentBrain,
            commitSession: commitSession
        )
    }

    public func reopenHeldItem(
        modeID: String?,
        promptSeed: String,
        hasDraft: Bool,
        title: String,
        detail: String?,
        riskLevelID: String?,
        reopenHint: String?,
        templateHint: String?,
        interventionHistorySummary: String?,
        clearActiveDecisionFlows: () -> Void,
        activatePrimaryFromDraft: () -> Void,
        activateComparativeFromDraft: () -> Void,
        activateReflectiveFromDraft: () -> Void,
        startPrimary: (String) -> Void,
        startComparative: (String) -> Void,
        startReflective: (String) -> Void,
        removeItem: () -> Void,
        applyInterventionSuggestion: (BASAppleReopenInterventionSuggestion?) -> Void,
        refreshPredictedIntervention: () -> Void,
        selectHomeTab: () -> Void,
        persistActiveWorkspaceState: () -> Void,
        now: Date = .now
    ) {
        let followUp = BASAppleDeferredReopenFollowUpBuilder.build(
            riskLevelID: riskLevelID,
            title: title,
            detail: detail,
            modeID: modeID,
            reopenHint: reopenHint,
            templateHint: templateHint,
            interventionHistorySummary: interventionHistorySummary,
            now: now
        )

        BASAppleDeferredReopenExecutor.execute(
            modeID: modeID,
            promptSeed: promptSeed,
            hasDraft: hasDraft,
            clearActiveDecisionFlows: clearActiveDecisionFlows,
            activatePrimaryFromDraft: activatePrimaryFromDraft,
            activateComparativeFromDraft: activateComparativeFromDraft,
            activateReflectiveFromDraft: activateReflectiveFromDraft,
            startPrimary: startPrimary,
            startComparative: startComparative,
            startReflective: startReflective,
            removeDeferredItem: removeItem,
            followUp: followUp,
            setInterventionSuggestion: applyInterventionSuggestion,
            refreshPredictedIntervention: refreshPredictedIntervention,
            selectHomeTab: selectHomeTab,
            persistActiveWorkspaceState: persistActiveWorkspaceState
        )
    }

    public func reopenSimpleItem(
        clearActiveDecisionFlows: () -> Void,
        reopen: () -> Void,
        selectHomeTab: () -> Void,
        persistActiveWorkspaceState: () -> Void
    ) {
        BASAppleSimpleReopenExecutor.execute(
            clearActiveDecisionFlows: clearActiveDecisionFlows,
            reopen: reopen,
            afterSuccessfulReopen: {
                selectHomeTab()
                persistActiveWorkspaceState()
            }
        )
    }

    @discardableResult
    public func reopenDraftedItem(
        modeID: String?,
        clearActiveDecisionFlows: () -> Void,
        activatePrimary: () -> Void,
        activateComparative: () -> Void,
        activateReflective: () -> Void,
        afterSuccessfulReopen: () -> Void
    ) -> Bool {
        BASAppleDraftedWorkflowReopenExecutor.execute(
            modeID: modeID,
            clearActiveDecisionFlows: clearActiveDecisionFlows,
            activatePrimary: activatePrimary,
            activateComparative: activateComparative,
            activateReflective: activateReflective,
            afterSuccessfulReopen: afterSuccessfulReopen
        )
    }

    public func restoreActiveWorkspaceIfNeeded<State>(
        restoreEnabled: Bool,
        hasActivePrimaryWorkflow: Bool,
        hasActiveComparativeWorkflow: Bool,
        hasActiveReflectiveWorkflow: Bool,
        hasReflectionContext: Bool,
        loadState: () -> State?,
        modeID: (State) -> String?,
        restorePrimary: (State) -> Void,
        restoreComparative: (State) -> Void,
        restoreReflective: (State) -> Void,
        selectHomeTab: () -> Void,
        afterRestore: () -> Void
    ) {
        BASAppleWorkspaceRestoreExecutor.execute(
            eligibility: BASAppleWorkspaceRestoreEligibilityInput(
                restoreEnabled: restoreEnabled,
                hasActivePrimaryWorkflow: hasActivePrimaryWorkflow,
                hasActiveComparativeWorkflow: hasActiveComparativeWorkflow,
                hasActiveReflectiveWorkflow: hasActiveReflectiveWorkflow,
                hasReflectionContext: hasReflectionContext
            ),
            loadState: loadState,
            modeID: modeID,
            restorePrimary: restorePrimary,
            restoreComparative: restoreComparative,
            restoreReflective: restoreReflective,
            selectHomeTab: selectHomeTab,
            afterRestore: afterRestore
        )
    }

    public func refreshActiveTaskGraph<Snapshot>(
        snapshotsInPriorityOrder: [() -> Snapshot?],
        saveSnapshot: (Snapshot) -> Void,
        clearSnapshot: () -> Void
    ) -> Snapshot? {
        BASAppleTaskGraphLifecycleExecutor.refresh(
            snapshotsInPriorityOrder: snapshotsInPriorityOrder,
            saveSnapshot: saveSnapshot,
            clearSnapshot: clearSnapshot
        )
    }

    public func reconcilePredictiveIntervention(
        existing: BASApplePredictiveInterventionCandidateSummary?,
        next: BASApplePredictiveInterventionCandidateSummary?
    ) -> BASApplePredictiveInterventionCandidateSummary? {
        BASApplePredictiveInterventionReconciler.reconcile(
            existing: existing,
            next: next
        )
    }

    public func executePredictiveInterventionDelivery(
        candidate: BASApplePredictiveInterventionCandidateSummary?,
        predictiveInterventionsEnabled: Bool,
        policyAllowed: Bool,
        upsertTrigger: (BASApplePredictiveInterventionCandidateSummary, Bool) -> Void,
        cancelNotification: (UUID) -> Void,
        scheduleNotification: (BASApplePredictiveInterventionCandidateSummary) -> Void
    ) {
        let plan = BASApplePredictiveInterventionDeliveryPlanner.plan(
            candidate: candidate,
            predictiveInterventionsEnabled: predictiveInterventionsEnabled,
            policyAllowed: policyAllowed
        )
        BASApplePredictiveInterventionDeliveryExecutor.execute(
            plan: plan,
            upsertTrigger: upsertTrigger,
            cancelNotification: cancelNotification,
            scheduleNotification: scheduleNotification
        )
    }

    public func bootstrap(
        _ request: BASHostLifecycleRequest,
        now: Date = .now
    ) throws -> BASHostSessionResult {
        let bootstrapActions = BASAppleLifecycleBootstrapPlanner.actions(
            for: request.phase.bootstrapPhase,
            behavior: configuration.lifecycleBehavior.bootstrapBehavior
        )
        let lifecyclePresentation = configuration.presentation.lifecycle
        let baseRequest = BASHostSessionRequest(
            kind: request.sessionKind,
            workflowProfile: request.preferredProfile,
            surface: request.sourceSurface,
            prompt: request.promptSeed.isEmpty
                ? (request.phase == .initialAppearance
                    ? lifecyclePresentation.initialAppearancePromptFallback
                    : lifecyclePresentation.sceneActivePromptFallback)
                : request.promptSeed,
            title: configuration.presentation.sessionTitles.title(for: request.phase),
            riskLevel: request.riskLevel
        )
        var result = try startSession(baseRequest, now: now)
        result.requestKind = request.sessionKind
        result.workflowProfile = request.preferredProfile
        result.activeSessionTitle = configuration.presentation.sessionTitles.title(for: request.phase)
        result.notices = bootstrapActions.map(lifecycleNotice(for:))
        result.followUpActions = bootstrapActions.compactMap(lifecycleFollowUp(for:))
        result.consoleSnapshot = consoleSnapshot(
            requestKind: request.sessionKind,
            currentBrain: result.currentBrain,
            notices: result.notices,
            followUpActions: result.followUpActions,
            eBrainTurn: result.eBrainTurn
        )
        return result
    }

    public func handleEntryIntent(
        _ request: BASHostSessionRequest,
        now: Date = .now
    ) throws -> BASHostSessionResult {
        try startSession(request, now: now)
    }

    public func startSession(
        _ request: BASHostSessionRequest,
        now: Date = .now
    ) throws -> BASHostSessionResult {
        let projection = try makeProjection(
            prompt: request.prompt,
            profile: request.workflowProfile,
            riskLevel: request.riskLevel,
            now: now
        )
        let mode = try configuration.workflowBehavior.mode(for: request.workflowProfile)
        let bootstrapped = BASCognitionBootstrapper.bootstrap(
            request: BASBrainBootstrapRequest(
                mode: mode,
                prompt: request.prompt,
                source: try source(for: request),
                sourceSurface: request.surface.substrateSurface,
                riskLevel: request.riskLevel.substrateRiskLevel,
                retrievalMode: try retrievalMode(for: request),
                reactionWeightSeed: configuration.cognitionBehavior.reactionWeights(for: request.workflowProfile),
                identityProfileOverride: configuration.cognitionBehavior.identityProfile(for: request.workflowProfile),
                cognitionBehavior: configuration.cognitionBehavior.substrateBehavior,
                goalHints: goalHints(for: request),
                constraintHints: constraintHints(for: request),
                now: now
            ),
            projection: projection
        )
        let substrateCurrentBrain = BASCurrentBrainState(
            mode: mode.identifier,
            dominantGoals: compactGoals(primary: bootstrapped.dominantGoal, prompt: request.prompt),
            activeConstraints: bootstrapped.activeConstraints,
            reactionWeights: bootstrapped.brainState.reactionWeights,
            activeTemplateIDs: bootstrapped.activeTemplateIDs.map(deterministicUUID(for:)),
            recentFailurePatternIDs: bootstrapped.failureGuardIDs.map(deterministicUUID(for:)),
            retrievalTags: constitutionAwareRetrievalTags(
                base: bootstrapped.brainState.retrievalTags,
                constitution: configuration.hostConstitution,
                vault: resolvedHostConstitutionVault(constitution: configuration.hostConstitution),
                versionTree: configuration.hostVersionTree,
                forgetRequest: configuration.hostForgetRequest
            ),
            verificationSnapshot: constitutionAwareVerificationSnapshot(
                base: verificationSnapshot(
                    profile: request.workflowProfile,
                    prompt: request.prompt,
                    riskLevel: request.riskLevel
                ),
                constitution: configuration.hostConstitution,
                vault: resolvedHostConstitutionVault(constitution: configuration.hostConstitution),
                versionTree: configuration.hostVersionTree,
                forgetRequest: configuration.hostForgetRequest
            )
        )
        let currentBrain = makeHostCurrentBrain(
            from: substrateCurrentBrain,
            workflowProfile: request.workflowProfile,
            brainState: bootstrapped.brainState
        )
        let notices = baseNotices(for: request)
        let followUpActions = baseFollowUpActions(for: request)
        let interventionSuggestion = schedulePredictiveIntervention(for: request, now: now)
        let eBrainTurn = makeEBrainTurn(
            for: request,
            currentBrain: currentBrain,
            projection: projection,
            deviceStateOverride: nil,
            now: now
        )
        let constitutionAwareCurrentBrain = applyConstitutionAwareness(
            to: currentBrain,
            constitution: eBrainTurn.hostConstitution,
            vault: eBrainTurn.hostConstitutionVault,
            versionTree: eBrainTurn.hostVersionTree,
            forgetRequest: eBrainTurn.hostForgetRequest
        )
        return BASHostSessionResult(
            requestKind: request.kind,
            workflowProfile: request.workflowProfile,
            currentBrain: constitutionAwareCurrentBrain,
            projection: makeHostProjection(from: projection),
            eBrainTurn: eBrainTurn,
            activeSessionTitle: request.title ?? configuration.presentation.sessionTitles.title(for: request.workflowProfile),
            notices: notices,
            followUpActions: followUpActions,
            interventionSuggestion: interventionSuggestion,
            consoleSnapshot: consoleSnapshot(
                requestKind: request.kind,
                currentBrain: constitutionAwareCurrentBrain,
                notices: notices,
                followUpActions: followUpActions,
                eBrainTurn: eBrainTurn
            )
        )
    }

    private func constitutionAwareRetrievalTags(
        base: [String],
        constitution: BASHostConstitution?,
        vault: BASHostConstitutionVault?,
        versionTree: BASHostVersionTree?,
        forgetRequest: BASForgetRequest?
    ) -> [String] {
        var tags = base
        if let constitution {
            tags += [
                "constitution:\(constitution.activeVersion)",
                "constitution_phase:\(constitution.narrativeLoom.currentPhase)",
                "constitution_value_axes:\(constitution.valueAxes.axes.count)"
            ]
        }
        if let vault {
            tags += vault.verificationMarkers
        }
        if let versionTree {
            tags += [
                "constitution_pending:\(versionTree.pendingCandidateIDs.count)",
                "constitution_frozen:\(versionTree.frozenVersionIDs.count)"
            ]
        }
        if let forgetRequest {
            tags += [
                "forget_request:\(forgetRequest.requestID)",
                "forget_verified:\(forgetRequest.verified)"
            ]
            if forgetRequest.executedSteps.contains("checkpoint_exports_revoked") {
                tags.append("forget_checkpoints_revoked:true")
            }
            if forgetRequest.executedSteps.contains("sync_exports_revoked") {
                tags.append("forget_sync_exports_revoked:true")
            }
        }
        return constitutionAwareOrderedUnique(tags)
    }

    private func constitutionAwareVerificationSnapshot(
        base: String,
        constitution: BASHostConstitution?,
        vault: BASHostConstitutionVault?,
        versionTree: BASHostVersionTree?,
        forgetRequest: BASForgetRequest?
    ) -> String {
        var segments = [base]
        if let constitution {
            segments += [
                "constitution:\(constitution.activeVersion)",
                "phase:\(constitution.narrativeLoom.currentPhase)"
            ]
        }
        if let vault {
            segments += vault.verificationMarkers
        }
        if let versionTree {
            segments += [
                "pending:\(versionTree.pendingCandidateIDs.count)",
                "frozen:\(versionTree.frozenVersionIDs.count)"
            ]
        }
        if let forgetRequest {
            segments += [
                "forget:\(forgetRequest.requestID)",
                "forget_verified:\(forgetRequest.verified)"
            ]
            if forgetRequest.executedSteps.contains("checkpoint_exports_revoked") {
                segments.append("forget_checkpoints_revoked:true")
            }
            if forgetRequest.executedSteps.contains("sync_exports_revoked") {
                segments.append("forget_sync_exports_revoked:true")
            }
        }
        return constitutionAwareOrderedUnique(segments).joined(separator: "|")
    }

    private func constitutionAwareOrderedUnique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func applyConstitutionAwareness(
        to currentBrain: BASHostCurrentBrain,
        constitution: BASHostConstitution?,
        vault: BASHostConstitutionVault?,
        versionTree: BASHostVersionTree?,
        forgetRequest: BASForgetRequest?
    ) -> BASHostCurrentBrain {
        var updated = currentBrain
        updated.retrievalTags = constitutionAwareRetrievalTags(
            base: currentBrain.retrievalTags,
            constitution: constitution,
            vault: vault,
            versionTree: versionTree,
            forgetRequest: forgetRequest
        )
        updated.verificationSummary = constitutionAwareVerificationSnapshot(
            base: currentBrain.verificationSummary,
            constitution: constitution,
            vault: vault,
            versionTree: versionTree,
            forgetRequest: forgetRequest
        )
        return updated
    }

    private func resolvedHostConstitutionVault(
        constitution: BASHostConstitution?
    ) -> BASHostConstitutionVault? {
        if let hostConstitutionVault = configuration.hostConstitutionVault {
            guard let constitution else {
                return hostConstitutionVault
            }
            return hostConstitutionVault.reconciling(
                constitutionSnapshot: constitution,
                versionTree: configuration.hostVersionTree,
                forgetRequest: configuration.hostForgetRequest
            )
        }
        guard let constitution else {
            return nil
        }
        return constitution.vaultSnapshot(
            versionTree: configuration.hostVersionTree,
            forgetRequest: configuration.hostForgetRequest
        )
    }

    private func verificationSnapshot(
        profile: BASHostWorkflowProfile,
        prompt: String,
        riskLevel: BASHostRiskLevel
    ) -> String {
        "\(configuration.workflowBehavior.hostNamespace)/\(profile.rawValue)/\(riskLevel.rawValue)/\(fingerprint(for: prompt))"
    }

    private func hostTags(
        for profile: BASHostWorkflowProfile,
        riskLevel: BASHostRiskLevel
    ) -> [String] {
        [
            "profile:\(profile.rawValue)",
            "risk:\(riskLevel.rawValue)",
            "source:\(configuration.workflowBehavior.hostNamespace)"
        ]
    }

    private func deterministicUUID(for value: String) -> UUID {
        let digest = SHA256.hash(data: Data(value.utf8))
        let bytes = Array(digest.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func fingerprint(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    public func reopen(
        _ request: BASHostReopenRequest,
        now: Date = .now
    ) throws -> BASHostSessionResult {
        let followUp = BASAppleDeferredReopenFollowUpBuilder.build(
            riskLevelID: request.riskLevel.rawValue,
            title: request.title,
            detail: request.detail,
            modeID: try configuration.workflowBehavior.modeID(for: request.workflowProfile),
            reopenHint: request.reopenHint,
            templateHint: request.templateHint,
            interventionHistorySummary: request.interventionHistorySummary,
            now: now
        )
        var result = try startSession(
            BASHostSessionRequest(
                kind: .reopen,
                workflowProfile: request.workflowProfile,
                surface: .application,
                prompt: request.promptSeed,
                title: request.title,
                detail: request.detail,
                riskLevel: request.riskLevel,
                triggerReason: request.templateHint
            ),
            now: now
        )
        if let suggestion = followUp.interventionSuggestion {
            result.interventionSuggestion = BASHostInterventionSuggestion(
                riskLevel: BASHostRiskLevel(rawValue: suggestion.riskLevelID) ?? .medium,
                title: suggestion.title,
                detail: suggestion.detail ?? configuration.presentation.predictiveIntervention.fallbackReopenSuggestionDetail,
                evidenceSignalCount: suggestion.evidenceSignalCount,
                preferredWorkflowProfile: suggestion.suggestedModeID
                    .flatMap { configuration.workflowBehavior.workflowProfile(forModeID: $0) },
                reason: suggestion.reason,
                expiresAt: suggestion.expiresAt
            )
            result.notices.append(suggestion.reason)
            result.followUpActions.append(
                renderTemplate(
                    configuration.presentation.notices.reopenFollowUpAction,
                    replacements: [
                        "workflow": workflowTitle(for: request.workflowProfile).lowercased()
                    ]
                )
            )
            result.consoleSnapshot = consoleSnapshot(
                requestKind: .reopen,
                currentBrain: result.currentBrain,
                notices: result.notices,
                followUpActions: result.followUpActions,
                eBrainTurn: result.eBrainTurn
            )
        }
        return result
    }

    public func refreshCurrentBrain(
        for request: BASHostSessionRequest,
        now: Date = .now
    ) throws -> BASHostCurrentBrain {
        try startSession(request, now: now).currentBrain
    }

    public func schedulePredictiveIntervention(
        for request: BASHostSessionRequest,
        now: Date = .now
    ) -> BASHostInterventionSuggestion? {
        guard request.riskLevel >= .medium else { return nil }
        let predictiveBehavior = configuration.lifecycleBehavior.predictiveInterventionBehavior
        let riskBehavior: BASApplePredictiveInterventionRiskBehavior = {
            switch request.riskLevel {
            case .low:
                predictiveBehavior.lowRisk
            case .medium:
                predictiveBehavior.mediumRisk
            case .high:
                predictiveBehavior.highRisk
            }
        }()

        let predictivePresentation = configuration.presentation.predictiveIntervention
        let detail = request.kind == .reopen
            ? predictivePresentation.reopenRiskDetail
            : riskBehavior.detail

        return BASHostInterventionSuggestion(
            riskLevel: request.riskLevel,
            title: riskBehavior.title,
            detail: detail,
            evidenceSignalCount: request.triggerReason == nil ? 1 : 2,
            preferredWorkflowProfile: riskBehavior.preferredModeID
                .flatMap { configuration.workflowBehavior.workflowProfile(forModeID: $0) }
                ?? request.workflowProfile,
            reason: request.triggerReason ?? predictiveBehavior.defaultReason,
            expiresAt: now.addingTimeInterval(30 * 60)
        )
    }

    private func makeProjection(
        prompt: String,
        profile: BASHostWorkflowProfile,
        riskLevel: BASHostRiskLevel,
        now: Date
    ) throws -> BASBrainProjection {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            return BASBrainProjection(
                records: [],
                candidates: [],
                recentEvents: [],
                governanceSnapshot: .empty,
                activeTemplateIDs: templateIDs(for: profile),
                failureGuardIDs: failureGuardIDs(for: riskLevel)
            )
        }

        let event = BASEventRecord(
            kind: .situational,
            content: trimmedPrompt,
            timestamp: now,
            tags: hostTags(for: profile, riskLevel: riskLevel),
            entrySourceID: configuration.workflowBehavior.hostNamespace
        )
        let memory = BASGovernedMemory(
            kind: .situational,
            content: trimmedPrompt,
            scope: .session,
            sensitivity: riskLevel == .high ? .high : .medium,
            tier: .hot,
            confidence: riskLevel == .high ? 0.92 : 0.80,
            sourceType: try source(for: profile).rawValue,
            lastConfirmedAt: now,
            governanceStatus: .governed,
            provenanceSummary: configuration.workflowBehavior.sessionProvenanceSummary
        )
        return BASBrainProjection(
            records: [memory],
            candidates: [],
            recentEvents: [event],
            embeddingScoresByID: [memory.id.uuidString: 0.9],
            governanceSnapshot: BASMemoryGovernanceState(
                totalRecordCount: 1,
                totalCandidateCount: 0,
                pendingCandidateCount: 0,
                promotedCandidateCount: 1,
                loadedPromotedMemoryCount: 1,
                loadedPendingMemoryCount: 0
            ),
            activeTemplateIDs: templateIDs(for: profile),
            failureGuardIDs: failureGuardIDs(for: riskLevel)
        )
    }

    private func consoleSnapshot(
        requestKind: BASHostSessionKind,
        currentBrain: BASHostCurrentBrain,
        notices: [String],
        followUpActions: [String],
        eBrainTurn: BASEBrainTurnResult? = nil
    ) -> BASHostConsoleSnapshot {
        let baseSnapshot = BASFlightDeckBuilder().build(
            from: BASFlightDeckInput(
                overallSummary: "BASHostKit is serving the \(requestKind.title.lowercased()) path through the private SDK façade.",
                runtimeSummary: configuration.prefersPureLocal
                    ? "Local-first façade using \(dependencies.modelRegistryID)."
                    : "Hybrid-ready façade using \(dependencies.modelRegistryID).",
                brainSummary: "\(currentBrain.workflowTitle) • \(currentBrain.dominantGoals.prefix(2).joined(separator: " • "))",
                layerMetrics: [
                    BASFlightDeckLayerMetric(kind: .runtime, score: 0.97, summary: "Routing and execution are owned by the substrate façade."),
                    BASFlightDeckLayerMetric(kind: .data, score: 0.95, summary: "Host dependencies resolve through \(dependencies.persistenceProviderID)."),
                    BASFlightDeckLayerMetric(kind: .memory, score: currentBrain.dominantGoals.isEmpty ? 0.82 : 0.94, summary: "Current brain loaded with governed retrieval tags."),
                    BASFlightDeckLayerMetric(kind: .security, score: configuration.prefersPureLocal ? 0.96 : 0.84, summary: "Policy profile \(configuration.policyProfileID) is active."),
                    BASFlightDeckLayerMetric(kind: .orchestration, score: 0.92, summary: followUpActions.isEmpty ? "Session orchestration is ready." : followUpActions.joined(separator: " • ")),
                    BASFlightDeckLayerMetric(kind: .observability, score: 0.90, summary: notices.prefix(2).joined(separator: " • ")),
                    BASFlightDeckLayerMetric(kind: .evaluation, score: 0.88, summary: "Fast-evolving private SDK contract is covered by façade tests."),
                    BASFlightDeckLayerMetric(kind: .delivery, score: configuration.console.isEnabled ? 0.94 : 0.82, summary: "Host kit is ready for private integration.")
                ],
                isPureLocal: configuration.prefersPureLocal
            )
        )

        guard let eBrainTurn else {
            return baseSnapshot
        }

        return BASEBrainConsoleSupport.mergedSnapshot(baseSnapshot, with: eBrainTurn)
    }

    private func makeHostCurrentBrain(
        from currentBrain: BASCurrentBrainState,
        workflowProfile: BASHostWorkflowProfile,
        brainState: BASDecisionBrainState
    ) -> BASHostCurrentBrain {
        let identityProfile = brainState.identityProfile
        return BASHostCurrentBrain(
            workflowProfile: workflowProfile,
            workflowTitle: workflowTitle(for: workflowProfile),
            roleID: identityProfile.role.identifier,
            identityPosture: identityProfile.posture,
            identityInitiative: identityProfile.initiative,
            confidenceCeiling: identityProfile.confidenceCeiling,
            relationshipBoundary: identityProfile.relationshipBoundary,
            boundaryHeadline: brainState.boundaryPolicy.auditHeadline,
            boundaryMode: brainState.boundaryPolicy.mode,
            boundaryConstraints: brainState.boundaryPolicy.activeConstraints,
            calibrationStatus: brainState.calibrationState.status,
            calibrationAlerts: brainState.calibrationState.alerts,
            riskFlags: brainState.verificationSnapshot.riskFlags,
            dominantGoals: currentBrain.dominantGoals,
            activeConstraints: currentBrain.activeConstraints,
            retrievalTags: currentBrain.retrievalTags,
            verificationSummary: currentBrain.verificationSnapshot,
            activeTemplateCount: currentBrain.activeTemplateIDs.count,
            failureGuardCount: currentBrain.recentFailurePatternIDs.count,
            evolutionPendingReviewCount: brainState.evolutionState.pendingReviewCount,
            evolutionRollbackReady: brainState.evolutionState.rollbackReady
        )
    }

    private func makeHostProjection(from projection: BASBrainProjection) -> BASHostProjectionSummary {
        BASHostProjectionSummary(
            recordCount: projection.records.count,
            candidateCount: projection.candidates.count,
            recentEventCount: projection.recentEvents.count,
            activeTemplateIDs: projection.activeTemplateIDs,
            failureGuardIDs: projection.failureGuardIDs,
            governance: projection.governanceSnapshot.map {
                BASHostGovernanceSummary(
                    totalRecordCount: $0.totalRecordCount,
                    totalCandidateCount: $0.totalCandidateCount,
                    pendingCandidateCount: $0.pendingCandidateCount,
                    promotedCandidateCount: $0.promotedCandidateCount,
                    loadedPromotedMemoryCount: $0.loadedPromotedMemoryCount,
                    loadedPendingMemoryCount: $0.loadedPendingMemoryCount
                )
            }
        )
    }

    private func baseNotices(for request: BASHostSessionRequest) -> [String] {
        var notices = [
            renderTemplate(
                configuration.presentation.notices.enteredWorkflow,
                replacements: [
                    "surface": configuration.presentation.surfaceTitles.title(for: request.surface),
                    "workflow": workflowTitle(for: request.workflowProfile).lowercased()
                ]
            ),
            renderTemplate(
                configuration.presentation.notices.runtimeProfile,
                replacements: [
                    "runtimeProfile": configuration.runtimeProfileID
                ]
            )
        ]
        if let triggerReason = request.triggerReason, !triggerReason.isEmpty {
            notices.append(triggerReason)
        }
        return notices
    }

    private func baseFollowUpActions(for request: BASHostSessionRequest) -> [String] {
        let baseActions = configuration.presentation.followUpActions.actions(for: request.workflowProfile)

        if request.riskLevel == .high {
            return baseActions + configuration.presentation.followUpActions.highRiskEscalation
        }
        return baseActions
    }

    private func workflowTitle(for profile: BASHostWorkflowProfile) -> String {
        configuration.presentation.workflowTitles.title(for: profile)
    }

    private func goalHints(for request: BASHostSessionRequest) -> [String] {
        [request.title, request.prompt]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func constraintHints(for request: BASHostSessionRequest) -> [String] {
        var constraints = ["private-sdk", configuration.policyProfileID]
        if request.riskLevel == .high {
            constraints.append("high-risk-confirmation")
        }
        if request.kind == .notification || request.kind == .handoff || request.kind == .widget {
            constraints.append("low-friction-surface")
        }
        return constraints
    }

    private func templateIDs(for profile: BASHostWorkflowProfile) -> [String] {
        configuration.workflowBehavior.templateIDs(for: profile)
    }

    private func failureGuardIDs(for riskLevel: BASHostRiskLevel) -> [String] {
        configuration.workflowBehavior.failureGuardIDs(for: riskLevel)
    }

    private func retrievalMode(for request: BASHostSessionRequest) throws -> String {
        if let configured = configuration.workflowBehavior.retrievalMode(for: request.kind) {
            return configured
        }
        if request.kind == .interactive {
            return try configuration.workflowBehavior.interactiveRetrievalMode(for: request.workflowProfile)
        }
        if let configuredDefault = configuration.workflowBehavior.defaultRetrievalMode(for: request.kind) {
            return configuredDefault
        }
        throw BASHostIntegrationError.missingSessionKindRetrievalMode(kindID: request.kind.rawValue)
    }

    private func source(for request: BASHostSessionRequest) throws -> BASMemorySource {
        if let configured = configuration.workflowBehavior.memorySource(for: request.kind) {
            return configured
        }
        if request.kind == .interactive {
            return try source(for: request.workflowProfile)
        }
        if let configuredDefault = configuration.workflowBehavior.defaultMemorySource(for: request.kind) {
            return configuredDefault
        }
        throw BASHostIntegrationError.missingSessionKindMemorySource(kindID: request.kind.rawValue)
    }

    private func source(for profile: BASHostWorkflowProfile) throws -> BASMemorySource {
        try configuration.workflowBehavior.memorySource(for: profile)
    }

    private func compactGoals(primary: String?, prompt: String) -> [String] {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            primary,
            trimmedPrompt.isEmpty ? configuration.presentation.notices.emptyPromptGoalFallback : trimmedPrompt
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
    }

    private func lifecycleNotice(for action: BASAppleLifecycleBootstrapAction) -> String {
        switch action.kind {
        case .refreshMemoryProjection:
            configuration.presentation.lifecycle.refreshMemoryProjectionNotice
        case .refreshCurrentBrain:
            configuration.presentation.lifecycle.refreshCurrentBrainNotice
        case .presentPendingReflection:
            configuration.presentation.lifecycle.presentPendingReflectionNotice
        case .consumePendingLaunchRequest:
            configuration.presentation.lifecycle.consumePendingLaunchRequestNotice
        case .restoreActiveWorkspace:
            configuration.presentation.lifecycle.restoreActiveWorkspaceNotice
        case .refreshPredictedIntervention:
            configuration.presentation.lifecycle.refreshPredictedInterventionNotice
        case .syncWidgetSnapshot:
            configuration.presentation.lifecycle.syncWidgetSnapshotNotice
        }
    }

    private func lifecycleFollowUp(for action: BASAppleLifecycleBootstrapAction) -> String? {
        switch action.kind {
        case .refreshCurrentBrain:
            configuration.presentation.lifecycle.loadCurrentBrainFollowUp
        case .restoreActiveWorkspace:
            configuration.presentation.lifecycle.resumeStructuredWorkspaceFollowUp
        case .refreshPredictedIntervention:
            configuration.presentation.lifecycle.recomputeGuardedInterventionFollowUp
        default:
            nil
        }
    }

    private func renderTemplate(
        _ template: String,
        replacements: [String: String]
    ) -> String {
        replacements.reduce(template) { partial, entry in
            partial.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
        }
    }

}
