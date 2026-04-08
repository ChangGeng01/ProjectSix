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
        evidenceCount: Int
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

    private static func encodeTags(_ tags: [String]) -> String {
        let payload = Array(Set(tags.map { $0.lowercased() })).sorted()
        guard let data = try? JSONEncoder().encode(payload),
              let blob = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return blob
    }

    private static func decodeTags(_ blob: String) -> [String] {
        guard let data = blob.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tags
    }
}
