import Foundation
import BASRuntimeCore

public struct BASInterventionTemplateDescriptor: Codable, Equatable, Sendable {
    public var id: String
    public var mode: BASDecisionMode
    public var riskLevel: BASRiskLevel
    public var isPinned: Bool
    public var successCount: Int
    public var updatedAt: Date

    public init(
        id: String,
        mode: BASDecisionMode,
        riskLevel: BASRiskLevel,
        isPinned: Bool,
        successCount: Int,
        updatedAt: Date
    ) {
        self.id = id
        self.mode = mode
        self.riskLevel = riskLevel
        self.isPinned = isPinned
        self.successCount = successCount
        self.updatedAt = updatedAt
    }
}

public struct BASFailurePatternDescriptor: Codable, Equatable, Sendable {
    public var id: String
    public var mode: BASDecisionMode
    public var suppressionWeight: Double
    public var evidenceCount: Int
    public var updatedAt: Date

    public init(
        id: String,
        mode: BASDecisionMode,
        suppressionWeight: Double,
        evidenceCount: Int,
        updatedAt: Date
    ) {
        self.id = id
        self.mode = mode
        self.suppressionWeight = suppressionWeight
        self.evidenceCount = evidenceCount
        self.updatedAt = updatedAt
    }
}

public enum BASBrainBootstrapAdvisor {
    public static func inferRiskLevel(
        mode: BASDecisionMode,
        prompt: String,
        now: Date
    ) -> BASRiskLevel {
        let lowercased = prompt.lowercased()
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: now)
        let isNightWindow = hour >= 22 || hour < 5
        let containsMessagingImpulse = containsAny(
            in: lowercased,
            tokens: ["message", "reply", "text", "send", "dm"]
        )
        let containsSpendingImpulse = containsAny(
            in: lowercased,
            tokens: ["buy", "purchase", "spend", "checkout", "cart"]
        )

        if isNightWindow {
            if containsMessagingImpulse || containsSpendingImpulse {
                return .high
            }
            return mode == .quick ? .medium : .high
        }

        if mode == .mirror {
            return .medium
        }

        return .low
    }

    public static func orderedTemplateIDs(
        mode: BASDecisionMode,
        riskLevel: BASRiskLevel,
        recommendedTemplateIDs: [String],
        templates: [BASInterventionTemplateDescriptor]
    ) -> [String] {
        let recommendationIndex = Dictionary(
            uniqueKeysWithValues: recommendedTemplateIDs.enumerated().map { ($0.element, $0.offset) }
        )

        return templates
            .filter { $0.mode == mode && $0.riskLevel == riskLevel }
            .sorted { lhs, rhs in
                let lhsPriority = recommendationIndex[lhs.id] ?? Int.max
                let rhsPriority = recommendationIndex[rhs.id] ?? Int.max
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                if lhs.successCount != rhs.successCount {
                    return lhs.successCount > rhs.successCount
                }
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.id < rhs.id
            }
            .map(\.id)
    }

    public static func orderedFailurePatternIDs(
        mode: BASDecisionMode,
        failurePatterns: [BASFailurePatternDescriptor]
    ) -> [String] {
        failurePatterns
            .filter { $0.mode == mode }
            .sorted { lhs, rhs in
                if lhs.suppressionWeight != rhs.suppressionWeight {
                    return lhs.suppressionWeight > rhs.suppressionWeight
                }
                if lhs.evidenceCount != rhs.evidenceCount {
                    return lhs.evidenceCount > rhs.evidenceCount
                }
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.id < rhs.id
            }
            .map(\.id)
    }

    private static func containsAny(
        in text: String,
        tokens: [String]
    ) -> Bool {
        tokens.contains { text.contains($0) }
    }
}
