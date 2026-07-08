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
    /// chapter 三百〇四 / M791 — Phase Gamma 2nd code cut: typed
    /// storage configuration. Defaults to `.legacyInMemory` to
    /// preserve pre-Phase-Gamma behavior for callers that don't
    /// explicitly opt in (ADR-014 backward-compat guardrail #1).
    /// Decode path uses `decodeIfPresent` so existing on-disk
    /// configs without this field still load.
    public var storageOptions: BASHostStorageOptions

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
        case storageOptions
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
        hostForgetRequest: BASForgetRequest? = nil,
        storageOptions: BASHostStorageOptions = .legacyInMemory
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
        self.storageOptions = storageOptions
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
            hostForgetRequest: try container.decodeIfPresent(BASForgetRequest.self, forKey: .hostForgetRequest),
            // chapter 三百〇四 / M791 — Phase Gamma 2nd code cut.
            // ADR-014 backward-compat: existing on-disk configs
            // without `storageOptions` field default to
            // `.legacyInMemory` (pre-Phase-Gamma behavior).
            storageOptions: try container.decodeIfPresent(
                BASHostStorageOptions.self,
                forKey: .storageOptions) ?? .legacyInMemory
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
        // chapter 三百〇四 / M791 — Phase Gamma 2nd code cut.
        // Encoded unconditionally (storageOptions has explicit
        // default in init; .legacyInMemory always round-trips).
        try container.encode(storageOptions, forKey: .storageOptions)
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
// audit M-o MED-2 — `BASHostConsoleView = BASConsoleView` was RELOCATED to
// the new BASAdminUI target (with the view itself). Keeping it here forced
// SwiftUI into BASHostKit and thus every headless host. The re-export had
// zero references; UI hosts now import BASAdminUI for BASConsoleView /
// BASHostConsoleView directly.

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


// chapter 二百八十七 / M774 — BASHostRuntime (1187 LOC,
// host-facing API entry surface) extracted to
// `HostRuntimeCore.swift`. Phase Alpha 13th cut, BASHostKit
// god file CLOSED. 0 behavior change.

