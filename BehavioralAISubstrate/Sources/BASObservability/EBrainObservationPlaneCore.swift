import Foundation
import BASMemory
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

    public init?(policyID: String) {
        switch policyID {
        case Self.forceGuardMode.rawValue:
            self = .forceGuardMode
        case Self.disableFastPath.rawValue:
            self = .disableFastPath
        case Self.requireReviewedWrites.rawValue:
            self = .requireReviewedWrites
        case Self.forceProtectedPermit.rawValue:
            self = .forceProtectedPermit
        case "disableHighRiskAutoAction", "tool-call", "external-tools":
            self = .forceProtectedPermit
        case "host-write", "lineage-review":
            self = .requireReviewedWrites
        default:
            return nil
        }
    }

    public static func resolvePolicyIDs(_ policyIDs: [String]) -> [BASKillSwitchID] {
        var seen = Set<BASKillSwitchID>()
        return policyIDs.compactMap(Self.init(policyID:)).filter { seen.insert($0).inserted }
    }
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
    public static let currentSchemaVersion = "1.2.0"

    public var schemaVersion: String
    public var ticketID: String
    public var sessionRef: String
    public var summary: String
    public var memoryWriteSuggestion: String?
    public var hostChangeCandidate: BASHostChangeCandidate?
    public var hostProfileChangeSuggestion: String?
    public var ruleCandidateRef: String?
    public var confidence: Double
    public var conflictFlag: Bool
    public var requiresReview: Bool
    public var derivedCandidateRefs: [String]
    public var governanceRefs: [String]

    public init(
        schemaVersion: String = BASUpdateTicket.currentSchemaVersion,
        ticketID: String,
        sessionRef: String,
        summary: String,
        memoryWriteSuggestion: String? = nil,
        hostChangeCandidate: BASHostChangeCandidate? = nil,
        hostProfileChangeSuggestion: String? = nil,
        ruleCandidateRef: String? = nil,
        derivedCandidateRefs: [String] = [],
        governanceRefs: [String] = [],
        confidence: Double,
        conflictFlag: Bool = false,
        requiresReview: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.ticketID = ticketID
        self.sessionRef = sessionRef
        self.summary = summary
        self.memoryWriteSuggestion = memoryWriteSuggestion
        self.hostChangeCandidate = hostChangeCandidate
        self.hostProfileChangeSuggestion = hostProfileChangeSuggestion
        self.ruleCandidateRef = ruleCandidateRef
        self.confidence = min(max(confidence, 0), 1)
        self.conflictFlag = conflictFlag
        self.requiresReview = requiresReview
        self.derivedCandidateRefs = derivedCandidateRefs
        self.governanceRefs = governanceRefs
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case ticketID
        case sessionRef
        case summary
        case memoryWriteSuggestion
        case hostChangeCandidate
        case hostProfileChangeSuggestion
        case ruleCandidateRef
        case confidence
        case conflictFlag
        case requiresReview
        case derivedCandidateRefs
        case governanceRefs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASUpdateTicket.currentSchemaVersion
        ticketID = try container.decode(String.self, forKey: .ticketID)
        sessionRef = try container.decode(String.self, forKey: .sessionRef)
        summary = try container.decode(String.self, forKey: .summary)
        memoryWriteSuggestion = try container.decodeIfPresent(String.self, forKey: .memoryWriteSuggestion)
        hostChangeCandidate = try container.decodeIfPresent(BASHostChangeCandidate.self, forKey: .hostChangeCandidate)
        hostProfileChangeSuggestion = try container.decodeIfPresent(
            String.self,
            forKey: .hostProfileChangeSuggestion
        )
        ruleCandidateRef = try container.decodeIfPresent(String.self, forKey: .ruleCandidateRef)
        confidence = min(
            max(try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0, 0),
            1
        )
        conflictFlag = try container.decodeIfPresent(Bool.self, forKey: .conflictFlag) ?? false
        requiresReview = try container.decodeIfPresent(Bool.self, forKey: .requiresReview) ?? true
        derivedCandidateRefs = try container.decodeIfPresent([String].self, forKey: .derivedCandidateRefs) ?? []
        governanceRefs = try container.decodeIfPresent([String].self, forKey: .governanceRefs) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(ticketID, forKey: .ticketID)
        try container.encode(sessionRef, forKey: .sessionRef)
        try container.encode(summary, forKey: .summary)
        try container.encodeIfPresent(memoryWriteSuggestion, forKey: .memoryWriteSuggestion)
        try container.encodeIfPresent(hostChangeCandidate, forKey: .hostChangeCandidate)
        try container.encodeIfPresent(hostProfileChangeSuggestion, forKey: .hostProfileChangeSuggestion)
        try container.encodeIfPresent(ruleCandidateRef, forKey: .ruleCandidateRef)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(conflictFlag, forKey: .conflictFlag)
        try container.encode(requiresReview, forKey: .requiresReview)
        try container.encode(derivedCandidateRefs, forKey: .derivedCandidateRefs)
        try container.encode(governanceRefs, forKey: .governanceRefs)
    }
}

public extension BASUpdateTicket {
    private var normalizedLegacyHostProfileChangeSuggestion: String? {
        let normalized = hostProfileChangeSuggestion?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, normalized.isEmpty == false else { return nil }
        return normalized
    }

    var resolvedHostChangeCandidate: BASHostChangeCandidate? {
        if let hostChangeCandidate {
            return hostChangeCandidate
        }

        guard let legacySuggestion = normalizedLegacyHostProfileChangeSuggestion else { return nil }
        return BASHostChangeCandidate(
            candidateID: "legacy.\(ticketID).host-mutation",
            changeType: "review_legacy_host_mutation",
            proposedDelta: ["legacy_host_profile_suggestion"],
            evidenceRefs: ["legacy:\(legacySuggestion)"],
            cooldownUntil: Date(timeIntervalSince1970: 0),
            confidence: confidence,
            conflictRefs: conflictFlag ? ["legacy_host_profile_conflict"] : [],
            previewState: "legacy_bridge",
            approvalState: requiresReview ? "pending_legacy_review" : "pending"
        )
    }

    var hasPersistentMutationSuggestion: Bool {
        let hasMemoryWriteSuggestion = memoryWriteSuggestion?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return hasMemoryWriteSuggestion || resolvedHostChangeCandidate != nil
    }

    var actionDigestParts: [String] {
        let resolvedHostChangeCandidate = resolvedHostChangeCandidate
        return [
            ticketID,
            memoryWriteSuggestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            resolvedHostChangeCandidate?.candidateID ?? "",
            resolvedHostChangeCandidate?.changeType ?? "",
            resolvedHostChangeCandidate?.proposedDelta.joined(separator: ",") ?? "",
            resolvedHostChangeCandidate?.approvalState ?? "",
            resolvedHostChangeCandidate?.previewState ?? "",
            normalizedLegacyHostProfileChangeSuggestion ?? "",
            ruleCandidateRef?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        ] + derivedCandidateRefs + governanceRefs
    }

    var reviewDirectiveLine: String? {
        let baseDirective: String?

        if let resolvedHostChangeCandidate {
            let changeFragments = [resolvedHostChangeCandidate.changeType]
                + (resolvedHostChangeCandidate.proposedDelta.isEmpty ? [] : [resolvedHostChangeCandidate.proposedDelta.joined(separator: ", ")])
            baseDirective = "Review constitution change: \(changeFragments.joined(separator: " • "))"
        } else if let memoryWriteSuggestion, memoryWriteSuggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            baseDirective = "Review memory write: \(memoryWriteSuggestion.trimmingCharacters(in: .whitespacesAndNewlines))"
        } else if let ruleCandidateRef, ruleCandidateRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            baseDirective = "Review rule candidate: \(ruleCandidateRef.trimmingCharacters(in: .whitespacesAndNewlines))"
        } else if requiresReview || conflictFlag {
            baseDirective = "Review ticket before promotion."
        } else {
            baseDirective = nil
        }

        guard let baseDirective else { return nil }
        return conflictFlag ? "\(baseDirective) • conflict flagged" : baseDirective
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
    public static let currentSchemaVersion = "1.3.0"

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
    public var activeKillSwitches: [BASKillSwitchID]
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
        activeKillSwitches: [BASKillSwitchID] = [],
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
        self.activeKillSwitches = activeKillSwitches
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
