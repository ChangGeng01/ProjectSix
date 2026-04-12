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

public struct BASHostConfiguration: Codable, Equatable, Sendable {
    public var runtimeProfileID: String
    public var policyProfileID: String
    public var prefersPureLocal: Bool
    public var console: BASHostConsoleConfiguration
    public var lifecycleBehavior: BASHostLifecycleBehaviorConfiguration
    public var workflowBehavior: BASHostWorkflowBehaviorConfiguration
    public var cognitionBehavior: BASHostCognitionBehaviorConfiguration
    public var presentation: BASHostPresentationConfiguration

    public init(
        runtimeProfileID: String,
        policyProfileID: String,
        prefersPureLocal: Bool,
        console: BASHostConsoleConfiguration,
        lifecycleBehavior: BASHostLifecycleBehaviorConfiguration,
        workflowBehavior: BASHostWorkflowBehaviorConfiguration,
        cognitionBehavior: BASHostCognitionBehaviorConfiguration,
        presentation: BASHostPresentationConfiguration
    ) {
        self.runtimeProfileID = runtimeProfileID
        self.policyProfileID = policyProfileID
        self.prefersPureLocal = prefersPureLocal
        self.console = console
        self.lifecycleBehavior = lifecycleBehavior
        self.workflowBehavior = workflowBehavior
        self.cognitionBehavior = cognitionBehavior
        self.presentation = presentation
    }

    public static let generic = BASHostConfiguration(
        runtimeProfileID: "host.default-runtime",
        policyProfileID: "host.default-policy",
        prefersPureLocal: true,
        console: .generic,
        lifecycleBehavior: .generic,
        workflowBehavior: .generic,
        cognitionBehavior: .generic,
        presentation: .generic
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

    public init(
        kind: BASHostSessionKind,
        workflowProfile: BASHostWorkflowProfile,
        surface: BASHostSurface = .application,
        prompt: String,
        title: String? = nil,
        detail: String? = nil,
        riskLevel: BASHostRiskLevel = .low,
        triggerReason: String? = nil
    ) {
        self.kind = kind
        self.workflowProfile = workflowProfile
        self.surface = surface
        self.prompt = prompt
        self.title = title
        self.detail = detail
        self.riskLevel = riskLevel
        self.triggerReason = triggerReason
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

    public init(
        workflowProfile: BASHostWorkflowProfile,
        title: String,
        detail: String? = nil,
        promptSeed: String,
        riskLevel: BASHostRiskLevel = .low,
        reopenHint: String? = nil,
        templateHint: String? = nil,
        interventionHistorySummary: String? = nil
    ) {
        self.workflowProfile = workflowProfile
        self.title = title
        self.detail = detail
        self.promptSeed = promptSeed
        self.riskLevel = riskLevel
        self.reopenHint = reopenHint
        self.templateHint = templateHint
        self.interventionHistorySummary = interventionHistorySummary
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
    public var relationshipBoundary: String
    public var boundaryHeadline: String
    public var dominantGoals: [String]
    public var activeConstraints: [String]
    public var retrievalTags: [String]
    public var verificationSummary: String
    public var activeTemplateCount: Int
    public var failureGuardCount: Int

    public init(
        workflowProfile: BASHostWorkflowProfile,
        workflowTitle: String,
        roleID: String,
        relationshipBoundary: String,
        boundaryHeadline: String,
        dominantGoals: [String],
        activeConstraints: [String],
        retrievalTags: [String],
        verificationSummary: String,
        activeTemplateCount: Int,
        failureGuardCount: Int
    ) {
        self.workflowProfile = workflowProfile
        self.workflowTitle = workflowTitle
        self.roleID = roleID
        self.relationshipBoundary = relationshipBoundary
        self.boundaryHeadline = boundaryHeadline
        self.dominantGoals = dominantGoals
        self.activeConstraints = activeConstraints
        self.retrievalTags = retrievalTags
        self.verificationSummary = verificationSummary
        self.activeTemplateCount = activeTemplateCount
        self.failureGuardCount = failureGuardCount
    }
}

public typealias BASHostConsoleSnapshot = BASConsoleSnapshot
public typealias BASHostConsoleView = BASConsoleView

public struct BASHostSessionResult: Codable, Equatable, Sendable {
    public var requestKind: BASHostSessionKind
    public var workflowProfile: BASHostWorkflowProfile
    public var currentBrain: BASHostCurrentBrain
    public var projection: BASHostProjectionSummary
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

    public init(
        configuration: BASHostConfiguration,
        dependencies: BASHostDependencySet = BASHostDependencySet()
    ) {
        self.configuration = configuration
        self.dependencies = dependencies
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
            followUpActions: result.followUpActions
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
            retrievalTags: bootstrapped.brainState.retrievalTags,
            verificationSnapshot: verificationSnapshot(
                profile: request.workflowProfile,
                prompt: request.prompt,
                riskLevel: request.riskLevel
            )
        )
        let currentBrain = makeHostCurrentBrain(
            from: substrateCurrentBrain,
            workflowProfile: request.workflowProfile,
            identityProfile: bootstrapped.brainState.identityProfile,
            boundaryHeadline: bootstrapped.brainState.boundaryPolicy.auditHeadline
        )
        let notices = baseNotices(for: request)
        let followUpActions = baseFollowUpActions(for: request)
        let interventionSuggestion = schedulePredictiveIntervention(for: request, now: now)
        return BASHostSessionResult(
            requestKind: request.kind,
            workflowProfile: request.workflowProfile,
            currentBrain: currentBrain,
            projection: makeHostProjection(from: projection),
            activeSessionTitle: request.title ?? configuration.presentation.sessionTitles.title(for: request.workflowProfile),
            notices: notices,
            followUpActions: followUpActions,
            interventionSuggestion: interventionSuggestion,
            consoleSnapshot: consoleSnapshot(
                requestKind: request.kind,
                currentBrain: currentBrain,
                notices: notices,
                followUpActions: followUpActions
            )
        )
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
                followUpActions: result.followUpActions
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
        followUpActions: [String]
    ) -> BASHostConsoleSnapshot {
        BASFlightDeckBuilder().build(
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
    }

    private func makeHostCurrentBrain(
        from currentBrain: BASCurrentBrainState,
        workflowProfile: BASHostWorkflowProfile,
        identityProfile: BASIdentityProfile,
        boundaryHeadline: String
    ) -> BASHostCurrentBrain {
        BASHostCurrentBrain(
            workflowProfile: workflowProfile,
            workflowTitle: workflowTitle(for: workflowProfile),
            roleID: identityProfile.role.identifier,
            relationshipBoundary: identityProfile.relationshipBoundary,
            boundaryHeadline: boundaryHeadline,
            dominantGoals: currentBrain.dominantGoals,
            activeConstraints: currentBrain.activeConstraints,
            retrievalTags: currentBrain.retrievalTags,
            verificationSummary: currentBrain.verificationSnapshot,
            activeTemplateCount: currentBrain.activeTemplateIDs.count,
            failureGuardCount: currentBrain.recentFailurePatternIDs.count
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
}
