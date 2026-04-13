import Foundation
import BASPolicy
import BASRuntimeCore

public enum BASRuntimeAuditSeverity: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
}

public enum BASKillSwitchID: String, Codable, CaseIterable, Sendable {
    case forceGuardMode = "force_guard_mode"
    case disableFastPath = "disable_fast_path"
    case requireReviewedWrites = "require_reviewed_writes"
    case forceProtectedPermit = "force_protected_permit"
}

public struct BASRuntimeAuditFinding: Codable, Equatable, Sendable, Identifiable {
    public var id: String { code }
    public var code: String
    public var layerID: String
    public var summary: String
    public var severity: BASRuntimeAuditSeverity
    public var enforced: Bool

    public init(
        code: String,
        layerID: String,
        summary: String,
        severity: BASRuntimeAuditSeverity,
        enforced: Bool
    ) {
        self.code = code
        self.layerID = layerID
        self.summary = summary
        self.severity = severity
        self.enforced = enforced
    }
}

public struct BASUpdateTicket: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var ticketID: String
    public var sessionRef: String
    public var summary: String
    public var memoryWriteSuggestion: String?
    public var hostProfileChangeSuggestion: String?
    public var ruleCandidateRef: String?
    public var confidence: Double
    public var conflictFlag: Bool
    public var requiresReview: Bool

    public init(
        schemaVersion: String = BASUpdateTicket.currentSchemaVersion,
        ticketID: String,
        sessionRef: String,
        summary: String,
        memoryWriteSuggestion: String? = nil,
        hostProfileChangeSuggestion: String? = nil,
        ruleCandidateRef: String? = nil,
        confidence: Double,
        conflictFlag: Bool = false,
        requiresReview: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.ticketID = ticketID
        self.sessionRef = sessionRef
        self.summary = summary
        self.memoryWriteSuggestion = memoryWriteSuggestion
        self.hostProfileChangeSuggestion = hostProfileChangeSuggestion
        self.ruleCandidateRef = ruleCandidateRef
        self.confidence = min(max(confidence, 0), 1)
        self.conflictFlag = conflictFlag
        self.requiresReview = requiresReview
    }
}

public struct BASRuntimeTraceEvent: Codable, Equatable, Sendable {
    public var layerID: String
    public var event: String
    public var detail: String

    public init(layerID: String, event: String, detail: String) {
        self.layerID = layerID
        self.event = event
        self.detail = detail
    }
}

public struct BASRuntimeTrace: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.2.0"

    public var schemaVersion: String
    public var sessionID: String
    public var recordedAt: Date
    public var layerEvents: [BASRuntimeTraceEvent]
    public var latencyBreakdownMs: [String: Int]
    public var powerEstimate: Double
    public var thermalTrace: [String]
    public var modelRoute: String
    public var loopCount: Int
    public var cacheHitRate: Double
    public var guardrailFindings: [BASRuntimeAuditFinding]
    public var recommendedKillSwitches: [BASKillSwitchID]

    public init(
        schemaVersion: String = BASRuntimeTrace.currentSchemaVersion,
        sessionID: String,
        recordedAt: Date = .now,
        layerEvents: [BASRuntimeTraceEvent] = [],
        latencyBreakdownMs: [String: Int] = [:],
        powerEstimate: Double = 0,
        thermalTrace: [String] = [],
        modelRoute: String,
        loopCount: Int = 0,
        cacheHitRate: Double = 0,
        guardrailFindings: [BASRuntimeAuditFinding] = [],
        recommendedKillSwitches: [BASKillSwitchID] = []
    ) {
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.recordedAt = recordedAt
        self.layerEvents = layerEvents
        self.latencyBreakdownMs = latencyBreakdownMs
        self.powerEstimate = powerEstimate
        self.thermalTrace = thermalTrace
        self.modelRoute = modelRoute
        self.loopCount = max(0, loopCount)
        self.cacheHitRate = min(max(cacheHitRate, 0), 1)
        self.guardrailFindings = guardrailFindings
        self.recommendedKillSwitches = recommendedKillSwitches
    }
}

public struct BASEvalSample: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var sampleID: String
    public var taskType: String
    public var goldLabels: [String: String]
    public var modelOutput: String
    public var riskCard: BASRiskCard?
    public var permit: BASActionPermit?
    public var humanScore: Double?
    public var benchmarkGroup: String

    public init(
        schemaVersion: String = BASEvalSample.currentSchemaVersion,
        sampleID: String,
        taskType: String,
        goldLabels: [String: String] = [:],
        modelOutput: String,
        riskCard: BASRiskCard? = nil,
        permit: BASActionPermit? = nil,
        humanScore: Double? = nil,
        benchmarkGroup: String
    ) {
        self.schemaVersion = schemaVersion
        self.sampleID = sampleID
        self.taskType = taskType
        self.goldLabels = goldLabels
        self.modelOutput = modelOutput
        self.riskCard = riskCard
        self.permit = permit
        self.humanScore = humanScore
        self.benchmarkGroup = benchmarkGroup
    }
}

public struct BASModelArtifact: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var modelID: String
    public var baseCheckpointRef: String
    public var headPackRef: String?
    public var quantProfile: String?
    public var distillTeacherRef: String?
    public var benchmarkSnapshot: String

    public init(
        schemaVersion: String = BASModelArtifact.currentSchemaVersion,
        modelID: String,
        baseCheckpointRef: String,
        headPackRef: String? = nil,
        quantProfile: String? = nil,
        distillTeacherRef: String? = nil,
        benchmarkSnapshot: String
    ) {
        self.schemaVersion = schemaVersion
        self.modelID = modelID
        self.baseCheckpointRef = baseCheckpointRef
        self.headPackRef = headPackRef
        self.quantProfile = quantProfile
        self.distillTeacherRef = distillTeacherRef
        self.benchmarkSnapshot = benchmarkSnapshot
    }
}

public struct BASFeedbackEvent: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var sessionID: String
    public var eventType: String
    public var detail: String
    public var recordedAt: Date

    public init(
        schemaVersion: String = BASFeedbackEvent.currentSchemaVersion,
        sessionID: String,
        eventType: String,
        detail: String,
        recordedAt: Date = .now
    ) {
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.eventType = eventType
        self.detail = detail
        self.recordedAt = recordedAt
    }
}
