import Foundation

public protocol BASSchemaVersioned: Codable, Equatable, Sendable {
    static var currentSchemaVersion: String { get }
    var schemaVersion: String { get }
}

public enum BASThermalLevel: String, Codable, CaseIterable, Sendable {
    case nominal
    case warm
    case hot
    case critical
}

public enum BASNetworkState: String, Codable, CaseIterable, Sendable {
    case offline
    case constrained
    case online
}

public enum BASForegroundState: String, Codable, CaseIterable, Sendable {
    case foreground
    case background
    case suspended
}

public enum BASEBrainRunMode: String, Codable, CaseIterable, Sendable {
    case dormant
    case pulse
    case sentinel
    case engage
    case reflect
    case deepLoop
    case `guard` = "guard"
    case recovery
    case quarantine
    case lockdown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "dormant":
            self = .dormant
        case "pulse":
            self = .pulse
        case "sentinel":
            self = .sentinel
        case "engage":
            self = .engage
        case "reflect":
            self = .reflect
        case "deepLoop":
            self = .deepLoop
        case "guard", "guarded":
            self = .guard
        case "recovery":
            self = .recovery
        case "quarantine":
            self = .quarantine
        case "lockdown":
            self = .lockdown
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported L1 run mode: \(rawValue)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var requiresRunLease: Bool {
        switch self {
        case .deepLoop, .guard, .recovery, .quarantine, .lockdown:
            true
        case .dormant, .pulse, .sentinel, .engage, .reflect:
            false
        }
    }

    public var displayTitle: String {
        switch self {
        case .dormant:
            "Dormant"
        case .pulse:
            "Pulse"
        case .sentinel:
            "Sentinel"
        case .engage:
            "Engage"
        case .reflect:
            "Reflect"
        case .deepLoop:
            "DeepLoop"
        case .guard:
            "Guard"
        case .recovery:
            "Recovery"
        case .quarantine:
            "Quarantine"
        case .lockdown:
            "Lockdown"
        }
    }
}

public enum BASRuntimePrecisionProfile: String, Codable, CaseIterable, Sendable {
    case minimal
    case balanced
    case protected
    case full
}

public enum BASDeviceRoute: String, Codable, CaseIterable, Sendable {
    case scoutCPU
    case scoutGPU
    case scoutNPU
    case coreGPU
    case coreNPU
    case hybridLocal
}

public enum BASThermalGuardLevel: String, Codable, CaseIterable, Sendable {
    case nominal
    case watch
    case throttle
    case emergency
}

public enum BASMaintenanceClass: String, Codable, CaseIterable, Sendable {
    case none
    case light
    case standard
    case deferred
}

public enum BASWakeIntentLevel: String, Codable, CaseIterable, Sendable {
    case dormant
    case pulse
    case sentinel
    case engage
    case `guard`
}

public enum BASEmergencyBrakeLevel: String, Codable, CaseIterable, Sendable {
    case none
    case caution
    case `guard`
    case quarantine
    case lockdown
}

public enum BASSovereignActuationKind: String, Codable, CaseIterable, Sendable {
    case throttle
    case shadowLock
    case toolCut
    case memoryFreeze
    case quarantine
    case rollback
    case deadStop
    case guardShift
}

public struct BASWakeIntent: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var intentLevel: BASWakeIntentLevel
    public var estimatedValue: Double
    public var estimatedRisk: Double
    public var estimatedCost: Double
    public var preferredMode: BASEBrainRunMode

    public init(
        schemaVersion: String = BASWakeIntent.currentSchemaVersion,
        intentLevel: BASWakeIntentLevel,
        estimatedValue: Double,
        estimatedRisk: Double,
        estimatedCost: Double,
        preferredMode: BASEBrainRunMode
    ) {
        self.schemaVersion = schemaVersion
        self.intentLevel = intentLevel
        self.estimatedValue = min(1, max(0, estimatedValue))
        self.estimatedRisk = min(1, max(0, estimatedRisk))
        self.estimatedCost = min(1, max(0, estimatedCost))
        self.preferredMode = preferredMode
    }
}

public struct BASVitalState: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var wakeState: BASEBrainRunMode
    public var survivalMargin: Double
    public var thermalMargin: Double
    public var powerMargin: Double
    public var continuityScore: Double
    public var stabilityScore: Double

    public init(
        schemaVersion: String = BASVitalState.currentSchemaVersion,
        wakeState: BASEBrainRunMode,
        survivalMargin: Double,
        thermalMargin: Double,
        powerMargin: Double,
        continuityScore: Double,
        stabilityScore: Double
    ) {
        self.schemaVersion = schemaVersion
        self.wakeState = wakeState
        self.survivalMargin = min(1, max(0, survivalMargin))
        self.thermalMargin = min(1, max(0, thermalMargin))
        self.powerMargin = min(1, max(0, powerMargin))
        self.continuityScore = min(1, max(0, continuityScore))
        self.stabilityScore = min(1, max(0, stabilityScore))
    }
}

public struct BASRunLease: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var leaseID: String
    public var sessionID: String
    public var turnID: String
    public var allowedMode: BASEBrainRunMode
    public var maxLoops: Int
    public var maxMs: Int
    public var maxEnergyQuota: Double
    public var validHeads: [String]
    public var expiresAt: Date

    public init(
        schemaVersion: String = BASRunLease.currentSchemaVersion,
        leaseID: String,
        sessionID: String,
        turnID: String,
        allowedMode: BASEBrainRunMode,
        maxLoops: Int,
        maxMs: Int,
        maxEnergyQuota: Double,
        validHeads: [String],
        expiresAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.leaseID = leaseID
        self.sessionID = sessionID
        self.turnID = turnID
        self.allowedMode = allowedMode
        self.maxLoops = max(0, maxLoops)
        self.maxMs = max(0, maxMs)
        self.maxEnergyQuota = min(1, max(0, maxEnergyQuota))
        self.validHeads = validHeads
        self.expiresAt = expiresAt
    }

    public func isActive(asOf date: Date = .now) -> Bool {
        expiresAt >= date
    }
}

public struct BASEmergencyBrake: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var brakeLevel: BASEmergencyBrakeLevel
    public var reasonCodes: [String]
    public var forcedMode: BASEBrainRunMode?
    public var expiresAt: Date?

    public init(
        schemaVersion: String = BASEmergencyBrake.currentSchemaVersion,
        brakeLevel: BASEmergencyBrakeLevel,
        reasonCodes: [String],
        forcedMode: BASEBrainRunMode? = nil,
        expiresAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.brakeLevel = brakeLevel
        self.reasonCodes = reasonCodes
        self.forcedMode = forcedMode
        self.expiresAt = expiresAt
    }
}

public struct BASSovereignActuationCommand: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var commandID: String
    public var kind: BASSovereignActuationKind
    public var reasonCodes: [String]
    public var issuedAt: Date
    public var forcedMode: BASEBrainRunMode?

    public init(
        schemaVersion: String = BASSovereignActuationCommand.currentSchemaVersion,
        commandID: String,
        kind: BASSovereignActuationKind,
        reasonCodes: [String],
        issuedAt: Date,
        forcedMode: BASEBrainRunMode? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.commandID = commandID
        self.kind = kind
        self.reasonCodes = reasonCodes
        self.issuedAt = issuedAt
        self.forcedMode = forcedMode
    }
}

public enum BASSovereignExecutionStatus: String, Codable, CaseIterable, Sendable {
    case executed
    case skipped
    case blocked
}

public struct BASSovereignExecutionReceipt: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var commandID: String
    public var kind: BASSovereignActuationKind
    public var status: BASSovereignExecutionStatus
    public var executedAt: Date
    public var latencyMs: Int
    public var enforcedMode: BASEBrainRunMode?
    public var reasonCodes: [String]

    public init(
        schemaVersion: String = BASSovereignExecutionReceipt.currentSchemaVersion,
        commandID: String,
        kind: BASSovereignActuationKind,
        status: BASSovereignExecutionStatus,
        executedAt: Date,
        latencyMs: Int,
        enforcedMode: BASEBrainRunMode? = nil,
        reasonCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.commandID = commandID
        self.kind = kind
        self.status = status
        self.executedAt = executedAt
        self.latencyMs = max(0, latencyMs)
        self.enforcedMode = enforcedMode
        self.reasonCodes = reasonCodes
    }
}

public enum BASRecoveryDispositionKind: String, Codable, CaseIterable, Sendable {
    case recovery
    case quarantine
    case lockdown
}

public struct BASRecoveryDisposition: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var kind: BASRecoveryDispositionKind
    public var summary: String
    public var reasonCodes: [String]
    public var remediationRequired: Bool
    public var restrictedLease: Bool
    public var toolWriteAllowed: Bool
    public var memoryWriteAllowed: Bool

    public init(
        schemaVersion: String = BASRecoveryDisposition.currentSchemaVersion,
        kind: BASRecoveryDispositionKind,
        summary: String,
        reasonCodes: [String] = [],
        remediationRequired: Bool,
        restrictedLease: Bool,
        toolWriteAllowed: Bool,
        memoryWriteAllowed: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.summary = summary
        self.reasonCodes = reasonCodes
        self.remediationRequired = remediationRequired
        self.restrictedLease = restrictedLease
        self.toolWriteAllowed = toolWriteAllowed
        self.memoryWriteAllowed = memoryWriteAllowed
    }
}

public struct BASRuntimePolicyLineage: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var bundleVersion: String
    public var providerRoutingRegistryVersion: String
    public var providerRoutingPolicyID: String
    public var runtimeTuningRegistryVersion: String
    public var runtimeTuningPolicyID: String
    public var resolutionSourceID: String

    public init(
        schemaVersion: String = BASRuntimePolicyLineage.currentSchemaVersion,
        bundleVersion: String,
        providerRoutingRegistryVersion: String,
        providerRoutingPolicyID: String,
        runtimeTuningRegistryVersion: String,
        runtimeTuningPolicyID: String,
        resolutionSourceID: String
    ) {
        self.schemaVersion = schemaVersion
        self.bundleVersion = bundleVersion
        self.providerRoutingRegistryVersion = providerRoutingRegistryVersion
        self.providerRoutingPolicyID = providerRoutingPolicyID
        self.runtimeTuningRegistryVersion = runtimeTuningRegistryVersion
        self.runtimeTuningPolicyID = runtimeTuningPolicyID
        self.resolutionSourceID = resolutionSourceID
    }

    public var policyDecisionIDs: [String] {
        [providerRoutingPolicyID, runtimeTuningPolicyID]
    }
}

public enum BASSovereignVerdictLevel: String, Codable, CaseIterable, Sendable, Comparable {
    case pass
    case throttle
    case shadowLock
    case toolCut
    case memoryFreeze
    case quarantine
    case rollback
    case deadStop

    public static func < (lhs: BASSovereignVerdictLevel, rhs: BASSovereignVerdictLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    public var rank: Int {
        switch self {
        case .pass:
            0
        case .throttle:
            1
        case .shadowLock:
            2
        case .toolCut:
            3
        case .memoryFreeze:
            4
        case .quarantine:
            5
        case .rollback:
            6
        case .deadStop:
            7
        }
    }

    public var defaultForcedMode: BASEBrainRunMode? {
        switch self {
        case .pass:
            nil
        case .throttle, .shadowLock, .toolCut, .memoryFreeze:
            .guard
        case .quarantine:
            .quarantine
        case .rollback:
            .recovery
        case .deadStop:
            .lockdown
        }
    }

    public var isLatchedByDefault: Bool {
        self >= .memoryFreeze
    }
}

public enum BASSovereignPermission: String, Codable, CaseIterable, Sendable {
    case toolRead
    case toolWrite
    case externalActuation
    case deepLoop
    case checkpointCommit
    case memoryWriteHot
    case memoryWriteWarm
    case memoryWriteCold
    case hostMutation
    case rulePromotion
    case renderHighRisk
}

public enum BASSovereignUserStubMode: String, Codable, CaseIterable, Sendable {
    case none
    case minimalReceipt
    case refusalOnly
}

public enum BASSovereignCommitScope: String, Codable, CaseIterable, Sendable {
    case toolRead
    case toolWrite
    case memoryWrite
    case hostMutate
    case renderHighRisk
    case checkpointCommit
}

public enum BASQuarantineZone: String, Codable, CaseIterable, Sendable {
    case session
    case memory
    case host
    case tool
    case cache
}

public enum BASQuarantineReviewState: String, Codable, CaseIterable, Sendable {
    case pending
    case held
    case released
    case rejected
}

public enum BASSovereignLockScope: String, Codable, CaseIterable, Sendable {
    case turn
    case session
    case featureDomain
}

public enum BASSovereignAuditActor: String, Codable, CaseIterable, Sendable {
    case system
    case `operator`
}

public struct BASSovereignVerdict: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var verdictID: String
    public var verdictLevel: BASSovereignVerdictLevel
    public var latched: Bool
    public var forcedMode: BASEBrainRunMode?
    public var reasonCodes: [String]
    public var revokedPermissions: [BASSovereignPermission]
    public var quarantineRefs: [String]
    public var rollbackRef: String?
    public var userStubMode: BASSovereignUserStubMode
    public var auditRef: String?
    public var policyHash: String
    public var expiresAt: Date?

    public init(
        schemaVersion: String = BASSovereignVerdict.currentSchemaVersion,
        verdictID: String,
        verdictLevel: BASSovereignVerdictLevel,
        latched: Bool,
        forcedMode: BASEBrainRunMode? = nil,
        reasonCodes: [String] = [],
        revokedPermissions: [BASSovereignPermission] = [],
        quarantineRefs: [String] = [],
        rollbackRef: String? = nil,
        userStubMode: BASSovereignUserStubMode = .none,
        auditRef: String? = nil,
        policyHash: String,
        expiresAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.verdictID = verdictID
        self.verdictLevel = verdictLevel
        self.latched = latched
        self.forcedMode = forcedMode
        self.reasonCodes = reasonCodes
        self.revokedPermissions = revokedPermissions
        self.quarantineRefs = quarantineRefs
        self.rollbackRef = rollbackRef
        self.userStubMode = userStubMode
        self.auditRef = auditRef
        self.policyHash = policyHash
        self.expiresAt = expiresAt
    }
}

public struct BASSovereignCommitToken: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var tokenID: String
    public var sessionID: String
    public var turnID: String
    public var scope: BASSovereignCommitScope
    public var allowedTargets: [String]
    public var actionDigest: String
    public var snapshotRef: String
    public var policyHash: String
    public var ttlMs: Int
    public var nonce: String
    public var singleUse: Bool
    public var signature: String

    public init(
        schemaVersion: String = BASSovereignCommitToken.currentSchemaVersion,
        tokenID: String,
        sessionID: String,
        turnID: String,
        scope: BASSovereignCommitScope,
        allowedTargets: [String] = [],
        actionDigest: String,
        snapshotRef: String,
        policyHash: String,
        ttlMs: Int,
        nonce: String,
        singleUse: Bool = true,
        signature: String
    ) {
        self.schemaVersion = schemaVersion
        self.tokenID = tokenID
        self.sessionID = sessionID
        self.turnID = turnID
        self.scope = scope
        self.allowedTargets = allowedTargets
        self.actionDigest = actionDigest
        self.snapshotRef = snapshotRef
        self.policyHash = policyHash
        self.ttlMs = max(0, ttlMs)
        self.nonce = nonce
        self.singleUse = singleUse
        self.signature = signature
    }
}

public struct BASSovereignWarrant: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var warrantID: String
    public var scope: BASSovereignCommitScope
    public var actionDigest: String
    public var jurisdictionRef: String
    public var snapshotRef: String
    public var timeLockRef: String
    public var singleUse: Bool
    public var signature: String

    public init(
        schemaVersion: String = BASSovereignWarrant.currentSchemaVersion,
        warrantID: String,
        scope: BASSovereignCommitScope,
        actionDigest: String,
        jurisdictionRef: String,
        snapshotRef: String,
        timeLockRef: String,
        singleUse: Bool = true,
        signature: String
    ) {
        self.schemaVersion = schemaVersion
        self.warrantID = warrantID
        self.scope = scope
        self.actionDigest = actionDigest
        self.jurisdictionRef = jurisdictionRef
        self.snapshotRef = snapshotRef
        self.timeLockRef = timeLockRef
        self.singleUse = singleUse
        self.signature = signature
    }
}

public struct BASQuarantineRecord: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var quarantineID: String
    public var zone: BASQuarantineZone
    public var sourceRef: String
    public var reasonCodes: [String]
    public var isolatedAt: Date
    public var releasePolicy: String
    public var reviewState: BASQuarantineReviewState

    public init(
        schemaVersion: String = BASQuarantineRecord.currentSchemaVersion,
        quarantineID: String,
        zone: BASQuarantineZone,
        sourceRef: String,
        reasonCodes: [String] = [],
        isolatedAt: Date,
        releasePolicy: String,
        reviewState: BASQuarantineReviewState = .pending
    ) {
        self.schemaVersion = schemaVersion
        self.quarantineID = quarantineID
        self.zone = zone
        self.sourceRef = sourceRef
        self.reasonCodes = reasonCodes
        self.isolatedAt = isolatedAt
        self.releasePolicy = releasePolicy
        self.reviewState = reviewState
    }
}

public struct BASSovereignLock: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var lockID: String
    public var scope: BASSovereignLockScope
    public var lockLevel: BASSovereignVerdictLevel
    public var createdAt: Date
    public var releaseCondition: String
    public var releasedAt: Date?

    public init(
        schemaVersion: String = BASSovereignLock.currentSchemaVersion,
        lockID: String,
        scope: BASSovereignLockScope,
        lockLevel: BASSovereignVerdictLevel,
        createdAt: Date,
        releaseCondition: String,
        releasedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.lockID = lockID
        self.scope = scope
        self.lockLevel = lockLevel
        self.createdAt = createdAt
        self.releaseCondition = releaseCondition
        self.releasedAt = releasedAt
    }
}

public struct BASSovereignAuditEntry: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var auditID: String
    public var sessionID: String
    public var turnID: String
    public var verdictRef: String
    public var ruleIDs: [String]
    public var signalRefs: [String]
    public var actionRefs: [String]
    public var snapshotRef: String
    public var actor: BASSovereignAuditActor
    public var signature: String
    public var appendedAt: Date

    public init(
        schemaVersion: String = BASSovereignAuditEntry.currentSchemaVersion,
        auditID: String,
        sessionID: String,
        turnID: String,
        verdictRef: String,
        ruleIDs: [String] = [],
        signalRefs: [String] = [],
        actionRefs: [String] = [],
        snapshotRef: String,
        actor: BASSovereignAuditActor = .system,
        signature: String,
        appendedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.auditID = auditID
        self.sessionID = sessionID
        self.turnID = turnID
        self.verdictRef = verdictRef
        self.ruleIDs = ruleIDs
        self.signalRefs = signalRefs
        self.actionRefs = actionRefs
        self.snapshotRef = snapshotRef
        self.actor = actor
        self.signature = signature
        self.appendedAt = appendedAt
    }
}

public struct BASHostRhythmProfile: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var activeWindows: [String]
    public var highFocusWindows: [String]
    public var lowEnergyWindows: [String]
    public var preferredInteractionStyle: String
    public var sensitivityPeriods: [String]

    public init(
        schemaVersion: String = BASHostRhythmProfile.currentSchemaVersion,
        activeWindows: [String],
        highFocusWindows: [String],
        lowEnergyWindows: [String],
        preferredInteractionStyle: String,
        sensitivityPeriods: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.activeWindows = activeWindows
        self.highFocusWindows = highFocusWindows
        self.lowEnergyWindows = lowEnergyWindows
        self.preferredInteractionStyle = preferredInteractionStyle
        self.sensitivityPeriods = sensitivityPeriods
    }

    public static let generic = BASHostRhythmProfile(
        activeWindows: [],
        highFocusWindows: [],
        lowEnergyWindows: [],
        preferredInteractionStyle: "bounded_reflective",
        sensitivityPeriods: []
    )
}

public struct BASDeviceState: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var batteryLevel: Double
    public var thermalLevel: BASThermalLevel
    public var memoryFreeMB: Int
    public var networkState: BASNetworkState
    public var foregroundState: BASForegroundState
    public var cpuLoad: Double
    public var gpuLoad: Double
    public var npuAvailable: Bool
    public var latencyBudgetMs: Int

    public init(
        schemaVersion: String = BASDeviceState.currentSchemaVersion,
        batteryLevel: Double,
        thermalLevel: BASThermalLevel,
        memoryFreeMB: Int,
        networkState: BASNetworkState,
        foregroundState: BASForegroundState,
        cpuLoad: Double,
        gpuLoad: Double,
        npuAvailable: Bool,
        latencyBudgetMs: Int
    ) {
        self.schemaVersion = schemaVersion
        self.batteryLevel = batteryLevel
        self.thermalLevel = thermalLevel
        self.memoryFreeMB = memoryFreeMB
        self.networkState = networkState
        self.foregroundState = foregroundState
        self.cpuLoad = cpuLoad
        self.gpuLoad = gpuLoad
        self.npuAvailable = npuAvailable
        self.latencyBudgetMs = latencyBudgetMs
    }
}

public extension BASDeviceState {
    init(
        profile: BASDeviceProfile,
        memoryFreeMB: Int,
        networkState: BASNetworkState = .constrained,
        foregroundState: BASForegroundState = .foreground,
        cpuLoad: Double = 0,
        gpuLoad: Double = 0,
        npuAvailable: Bool = true,
        latencyBudgetMs: Int = 1_500
    ) {
        let thermalLevel: BASThermalLevel
        switch profile.thermalState.lowercased() {
        case let value where value.contains("critical"):
            thermalLevel = .critical
        case let value where value.contains("serious") || value.contains("hot"):
            thermalLevel = .hot
        case let value where value.contains("fair") || value.contains("warm"):
            thermalLevel = .warm
        default:
            thermalLevel = .nominal
        }

        self.init(
            batteryLevel: profile.batteryLevel,
            thermalLevel: thermalLevel,
            memoryFreeMB: memoryFreeMB,
            networkState: networkState,
            foregroundState: foregroundState,
            cpuLoad: cpuLoad,
            gpuLoad: gpuLoad,
            npuAvailable: npuAvailable,
            latencyBudgetMs: latencyBudgetMs
        )
    }
}

public struct BASBudgetFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.2.0"

    public var schemaVersion: String
    public var runMode: BASEBrainRunMode
    public var maxLoops: Int
    public var maxCandidates: Int
    public var maxDecodeTokens: Int
    public var retrievalDepth: Int
    public var precisionProfile: BASRuntimePrecisionProfile
    public var deviceRoute: BASDeviceRoute
    public var thermalGuardLevel: BASThermalGuardLevel
    public var maintenanceAllowed: Bool
    public var leaseID: String?
    public var leaseExpiresAt: Date?
    public var maintenanceClass: BASMaintenanceClass
    public var wakeIntentID: String?
    public var allowedHeads: [String]
    public var policyBundleVersion: String?
    public var policyDecisionIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runMode
        case maxLoops
        case maxCandidates
        case maxDecodeTokens
        case retrievalDepth
        case precisionProfile
        case deviceRoute
        case thermalGuardLevel
        case maintenanceAllowed
        case leaseID
        case leaseExpiresAt
        case maintenanceClass
        case wakeIntentID
        case allowedHeads
        case policyBundleVersion
        case policyDecisionIDs
    }

    public init(
        schemaVersion: String = BASBudgetFrame.currentSchemaVersion,
        runMode: BASEBrainRunMode,
        maxLoops: Int,
        maxCandidates: Int,
        maxDecodeTokens: Int,
        retrievalDepth: Int,
        precisionProfile: BASRuntimePrecisionProfile,
        deviceRoute: BASDeviceRoute,
        thermalGuardLevel: BASThermalGuardLevel,
        maintenanceAllowed: Bool,
        leaseID: String? = nil,
        leaseExpiresAt: Date? = nil,
        maintenanceClass: BASMaintenanceClass = .none,
        wakeIntentID: String? = nil,
        allowedHeads: [String] = [],
        policyBundleVersion: String? = nil,
        policyDecisionIDs: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.runMode = runMode
        self.maxLoops = max(0, maxLoops)
        self.maxCandidates = max(1, maxCandidates)
        self.maxDecodeTokens = max(0, maxDecodeTokens)
        self.retrievalDepth = max(0, retrievalDepth)
        self.precisionProfile = precisionProfile
        self.deviceRoute = deviceRoute
        self.thermalGuardLevel = thermalGuardLevel
        self.maintenanceAllowed = maintenanceAllowed
        self.leaseID = leaseID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.leaseExpiresAt = leaseExpiresAt
        self.maintenanceClass = maintenanceClass
        self.wakeIntentID = wakeIntentID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.allowedHeads = allowedHeads
        self.policyBundleVersion = policyBundleVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.policyDecisionIDs = policyDecisionIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASBudgetFrame.currentSchemaVersion
        runMode = try container.decode(BASEBrainRunMode.self, forKey: .runMode)
        maxLoops = max(0, try container.decode(Int.self, forKey: .maxLoops))
        maxCandidates = max(1, try container.decode(Int.self, forKey: .maxCandidates))
        maxDecodeTokens = max(0, try container.decode(Int.self, forKey: .maxDecodeTokens))
        retrievalDepth = max(0, try container.decode(Int.self, forKey: .retrievalDepth))
        precisionProfile = try container.decode(BASRuntimePrecisionProfile.self, forKey: .precisionProfile)
        deviceRoute = try container.decode(BASDeviceRoute.self, forKey: .deviceRoute)
        thermalGuardLevel = try container.decode(BASThermalGuardLevel.self, forKey: .thermalGuardLevel)
        maintenanceAllowed = try container.decode(Bool.self, forKey: .maintenanceAllowed)
        leaseID = try container.decodeIfPresent(String.self, forKey: .leaseID)
        leaseExpiresAt = try container.decodeIfPresent(Date.self, forKey: .leaseExpiresAt)
        maintenanceClass = try container.decodeIfPresent(BASMaintenanceClass.self, forKey: .maintenanceClass)
            ?? (maintenanceAllowed ? .standard : .none)
        wakeIntentID = try container.decodeIfPresent(String.self, forKey: .wakeIntentID)
        allowedHeads = try container.decodeIfPresent([String].self, forKey: .allowedHeads) ?? []
        policyBundleVersion = try container.decodeIfPresent(String.self, forKey: .policyBundleVersion)
        policyDecisionIDs = try container.decodeIfPresent([String].self, forKey: .policyDecisionIDs) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(runMode, forKey: .runMode)
        try container.encode(maxLoops, forKey: .maxLoops)
        try container.encode(maxCandidates, forKey: .maxCandidates)
        try container.encode(maxDecodeTokens, forKey: .maxDecodeTokens)
        try container.encode(retrievalDepth, forKey: .retrievalDepth)
        try container.encode(precisionProfile, forKey: .precisionProfile)
        try container.encode(deviceRoute, forKey: .deviceRoute)
        try container.encode(thermalGuardLevel, forKey: .thermalGuardLevel)
        try container.encode(maintenanceAllowed, forKey: .maintenanceAllowed)
        try container.encodeIfPresent(leaseID, forKey: .leaseID)
        try container.encodeIfPresent(leaseExpiresAt, forKey: .leaseExpiresAt)
        try container.encode(maintenanceClass, forKey: .maintenanceClass)
        try container.encodeIfPresent(wakeIntentID, forKey: .wakeIntentID)
        try container.encode(allowedHeads, forKey: .allowedHeads)
        try container.encodeIfPresent(policyBundleVersion, forKey: .policyBundleVersion)
        try container.encode(policyDecisionIDs, forKey: .policyDecisionIDs)
    }

    public func hasActiveLease(asOf date: Date = .now) -> Bool {
        guard let leaseID, !leaseID.isEmpty, let leaseExpiresAt else {
            return false
        }
        return leaseExpiresAt >= date
    }
}

public extension BASBudgetFrame {
    static func guardedLocal(
        maxLoops: Int = 1,
        maxCandidates: Int = 2,
        maxDecodeTokens: Int = 192,
        retrievalDepth: Int = 2
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .guard,
            maxLoops: maxLoops,
            maxCandidates: maxCandidates,
            maxDecodeTokens: maxDecodeTokens,
            retrievalDepth: retrievalDepth,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch,
            maintenanceAllowed: false,
            maintenanceClass: .none
        )
    }
}
