import Foundation
import SwiftData

enum DecisionMemoryType: String, Codable, Sendable {
    case identity
    case preference
    case goal
    case situational
    case semantic
    case support
}

enum DecisionMemorySource: String, Codable, Sendable {
    case history
    case reflection
    case reminder
    case pattern
}

enum DecisionMemoryDecayPolicy: String, Codable, Sendable {
    case stable
    case slow
    case medium
    case fast
}

enum DecisionMemoryWriteOperation: String, Codable, Sendable {
    case add
    case update
    case delete
    case noop
}

enum DecisionMemoryCandidateStatus: String, Codable, Sendable {
    case pending
    case promoted
}

enum DecisionMemoryGovernanceDecision: String, Codable, Sendable {
    case admit
    case deferred
    case reject
}

enum DecisionMemoryLifecycleState: String, Codable, Sendable {
    case active
    case aging
    case retired
}

@Model
final class DecisionMemoryRecord {
    @Attribute(.unique) var id: String
    var typeRaw: String
    var topic: String
    var headline: String
    var value: String
    var confidence: Double
    var priority: Double
    var sourceRaw: String
    var lastConfirmedAt: Date
    var decayPolicyRaw: String
    var retrievalTagsBlob: String
    var evidenceCount: Int
    var observationCount: Int
    var provenanceSummary: String
    var lifecycleStateRaw: String?
    var lastReviewedAt: Date?

    init(
        id: String,
        type: DecisionMemoryType,
        topic: String,
        headline: String,
        value: String,
        confidence: Double,
        priority: Double,
        source: DecisionMemorySource,
        lastConfirmedAt: Date,
        decayPolicy: DecisionMemoryDecayPolicy,
        retrievalTags: [String],
        evidenceCount: Int,
        observationCount: Int,
        provenanceSummary: String,
        lifecycleState: DecisionMemoryLifecycleState = .active,
        lastReviewedAt: Date? = nil
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.topic = topic
        self.headline = headline
        self.value = value
        self.confidence = confidence
        self.priority = priority
        self.sourceRaw = source.rawValue
        self.lastConfirmedAt = lastConfirmedAt
        self.decayPolicyRaw = decayPolicy.rawValue
        self.retrievalTagsBlob = Self.encodeTags(retrievalTags)
        self.evidenceCount = evidenceCount
        self.observationCount = observationCount
        self.provenanceSummary = provenanceSummary
        self.lifecycleStateRaw = lifecycleState.rawValue
        self.lastReviewedAt = lastReviewedAt ?? lastConfirmedAt
    }
}

@Model
final class DecisionMemoryCandidateRecord {
    @Attribute(.unique) var id: String
    var typeRaw: String
    var topic: String
    var headline: String
    var value: String
    var confidence: Double
    var priority: Double
    var sourceRaw: String
    var firstObservedAt: Date
    var lastObservedAt: Date
    var decayPolicyRaw: String
    var retrievalTagsBlob: String
    var evidenceCount: Int
    var confirmationCount: Int
    var lastObservationFingerprint: String
    var statusRaw: String
    var provenanceSummary: String
    var lastWriteOperationRaw: String
    var lastGovernanceDecisionRaw: String
    var governanceReason: String

    init(
        id: String,
        type: DecisionMemoryType,
        topic: String,
        headline: String,
        value: String,
        confidence: Double,
        priority: Double,
        source: DecisionMemorySource,
        firstObservedAt: Date,
        lastObservedAt: Date,
        decayPolicy: DecisionMemoryDecayPolicy,
        retrievalTags: [String],
        evidenceCount: Int,
        confirmationCount: Int,
        lastObservationFingerprint: String,
        status: DecisionMemoryCandidateStatus,
        provenanceSummary: String,
        lastWriteOperation: DecisionMemoryWriteOperation,
        lastGovernanceDecision: DecisionMemoryGovernanceDecision,
        governanceReason: String
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.topic = topic
        self.headline = headline
        self.value = value
        self.confidence = confidence
        self.priority = priority
        self.sourceRaw = source.rawValue
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
        self.decayPolicyRaw = decayPolicy.rawValue
        self.retrievalTagsBlob = DecisionMemoryRecord.encodeTags(retrievalTags)
        self.evidenceCount = evidenceCount
        self.confirmationCount = confirmationCount
        self.lastObservationFingerprint = lastObservationFingerprint
        self.statusRaw = status.rawValue
        self.provenanceSummary = provenanceSummary
        self.lastWriteOperationRaw = lastWriteOperation.rawValue
        self.lastGovernanceDecisionRaw = lastGovernanceDecision.rawValue
        self.governanceReason = governanceReason
    }
}

extension DecisionMemoryRecord {
    var type: DecisionMemoryType {
        DecisionMemoryType(rawValue: typeRaw) ?? .semantic
    }

    var source: DecisionMemorySource {
        DecisionMemorySource(rawValue: sourceRaw) ?? .history
    }

    var decayPolicy: DecisionMemoryDecayPolicy {
        DecisionMemoryDecayPolicy(rawValue: decayPolicyRaw) ?? .medium
    }

    var retrievalTags: [String] {
        Self.decodeTags(retrievalTagsBlob)
    }

    var lifecycleState: DecisionMemoryLifecycleState {
        DecisionMemoryLifecycleState(rawValue: lifecycleStateRaw ?? "") ?? .active
    }

    var reviewedAt: Date {
        lastReviewedAt ?? lastConfirmedAt
    }

    static func encodeTags(_ tags: [String]) -> String {
        let payload = Array(Set(tags.map { $0.lowercased() })).sorted()
        guard let data = try? JSONEncoder().encode(payload),
              let blob = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return blob
    }

    static func decodeTags(_ blob: String) -> [String] {
        guard let data = blob.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tags
    }
}

extension DecisionMemoryCandidateRecord {
    var type: DecisionMemoryType {
        DecisionMemoryType(rawValue: typeRaw) ?? .semantic
    }

    var source: DecisionMemorySource {
        DecisionMemorySource(rawValue: sourceRaw) ?? .history
    }

    var decayPolicy: DecisionMemoryDecayPolicy {
        DecisionMemoryDecayPolicy(rawValue: decayPolicyRaw) ?? .medium
    }

    var status: DecisionMemoryCandidateStatus {
        DecisionMemoryCandidateStatus(rawValue: statusRaw) ?? .pending
    }

    var lastWriteOperation: DecisionMemoryWriteOperation {
        DecisionMemoryWriteOperation(rawValue: lastWriteOperationRaw) ?? .noop
    }

    var lastGovernanceDecision: DecisionMemoryGovernanceDecision {
        DecisionMemoryGovernanceDecision(rawValue: lastGovernanceDecisionRaw) ?? .deferred
    }

    var retrievalTags: [String] {
        DecisionMemoryRecord.decodeTags(retrievalTagsBlob)
    }
}
