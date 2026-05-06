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


// chapter 二百八十六 / M773 — Host presentation + titles +
// behavior configuration cluster (BASHostConsoleConfiguration /
// BASHostWorkflowTitles / BASHostSurfaceTitles /
// BASHostSessionTitles / BASHostFollowUpActions /
// BASHostLifecyclePresentation / BASHostNoticeTemplates /
// BASHostPredictiveInterventionPresentation /
// BASHostLifecycleBehaviorConfiguration /
// BASHostIntegrationError /
// BASHostWorkflowBehaviorConfiguration /
// BASHostCognitionBehaviorConfiguration /
// BASHostPresentationConfiguration) extracted to
// `HostPresentationConfigurationsCore.swift`. Phase Alpha
// 12th cut. 0 behavior change.



// chapter 二百八十五 / M772 — BASEBrainRuntimeSynthesisPolicy
// (single largest struct, 2090 LOC, 50+ nested types)
// extracted to `HostSynthesisPolicyCore.swift`. Phase Alpha
// 11th cut. 0 behavior change.


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
        defaultDeviceState: BASDeviceState,
        console: BASHostConsoleConfiguration,
        lifecycleBehavior: BASHostLifecycleBehaviorConfiguration,
        workflowBehavior: BASHostWorkflowBehaviorConfiguration,
        cognitionBehavior: BASHostCognitionBehaviorConfiguration,
        presentation: BASHostPresentationConfiguration,
        runtimeTuning: BASEBrainRuntimeSynthesisPolicy,
        runtimePolicyLineage: BASRuntimePolicyLineage? = nil,
        hostRhythmProfile: BASHostRhythmProfile,
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
        if runtimePolicyLineage == nil && defaultDeviceState == BASHostConfiguration.fixtureDefaultDeviceState {
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

    public static let fixtureDefaultDeviceState = BASDeviceState(
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

    public static let fixtureGeneric = BASHostConfiguration(
        runtimeProfileID: "host.default-runtime",
        policyProfileID: "host.default-policy",
        prefersPureLocal: true,
        defaultDeviceState: fixtureDefaultDeviceState,
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

    @available(*, unavailable, renamed: "fixtureDefaultDeviceState", message: "Use fixtureDefaultDeviceState only for fixtures or legacy compatibility; production code should supply an explicit host-owned default device state.")
    public static let genericDefaultDeviceState = fixtureDefaultDeviceState

    @available(*, unavailable, renamed: "fixtureGeneric", message: "Use fixtureGeneric only for fixtures or legacy compatibility; production code should supply an explicit host-owned configuration.")
    public static let generic = fixtureGeneric
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
        if let constitution {
            updated.dominantGoals = constitutionAwareDominantGoals(
                base: currentBrain.dominantGoals,
                constitution: constitution
            )
            updated.relationshipBoundary = constitutionAwareRelationshipBoundary(
                base: currentBrain.relationshipBoundary,
                constitution: constitution
            )
            updated.boundaryHeadline = constitutionAwareBoundaryHeadline(
                base: currentBrain.boundaryHeadline,
                constitution: constitution
            )
            updated.activeConstraints = constitutionAwareActiveConstraints(
                base: currentBrain.activeConstraints,
                constitution: constitution
            )
        }
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

    private func constitutionAwareDominantGoals(
        base: [String],
        constitution: BASHostConstitution
    ) -> [String] {
        constitutionAwareOrderedUnique(
            constitution.goalSpine.priorityOrder
                + constitution.goalSpine.goals
                + base
        )
    }

    private func constitutionAwareRelationshipBoundary(
        base: String,
        constitution: BASHostConstitution
    ) -> String {
        firstNonEmpty(
            constitution.relationGravity.highConsequenceLinks.first,
            constitution.relationGravity.nodes.first,
            base
        ) ?? base
    }

    private func constitutionAwareBoundaryHeadline(
        base: String,
        constitution: BASHostConstitution
    ) -> String {
        let segments = constitutionAwareOrderedUnique(
            [
                constitution.identityLattice.stableCenter.isEmpty
                    ? nil
                    : "stable center \(constitution.identityLattice.stableCenter)",
                constitution.boundaryVeil.confirmRequired.first.map { "confirm \($0)" },
                constitution.boundaryVeil.hardNoGo.first.map { "no-go \($0)" }
            ].compactMap { $0 }
        )
        guard segments.isEmpty == false else {
            return base
        }
        return segments.joined(separator: " • ")
    }

    private func constitutionAwareActiveConstraints(
        base: [String],
        constitution: BASHostConstitution
    ) -> [String] {
        constitutionAwareOrderedUnique(
            base
                + constitution.goalSpine.priorityOrder.map { "constitution_goal:\($0)" }
                + constitution.boundaryVeil.confirmRequired.map { "constitution_confirm_required:\($0)" }
                + constitution.boundaryVeil.hardNoGo.map { "constitution_no_go:\($0)" }
                + constitution.relationGravity.highConsequenceLinks.map { "constitution_relation:\($0)" }
                + [
                    constitution.narrativeLoom.currentPhase.isEmpty
                        ? nil
                        : "constitution_phase:\(constitution.narrativeLoom.currentPhase)",
                    constitution.consentLattice.memoryPromotionScope.isEmpty
                        ? nil
                        : "constitution_memory_promotion:\(constitution.consentLattice.memoryPromotionScope)",
                    constitution.consentLattice.toolWriteScope.isEmpty
                        ? nil
                        : "constitution_tool_write_scope:\(constitution.consentLattice.toolWriteScope)"
                ].compactMap { $0 }
        )
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return trimmed
            }
        }
        return nil
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
