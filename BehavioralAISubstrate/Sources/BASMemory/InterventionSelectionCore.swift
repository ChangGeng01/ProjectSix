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

public struct BASBrainBootstrapAdvisorBehavior: Codable, Equatable, Sendable {
    public static let generic = BASBrainBootstrapAdvisorBehavior()

    public var nightWindowStartHour: Int
    public var nightWindowEndHour: Int
    public var highRiskSignalGroups: [[String]]
    public var nightFallbackRiskLevelByModeID: [String: String]
    public var defaultRiskLevelByModeID: [String: String]
    public var defaultNightFallbackRiskLevelID: String
    public var defaultDayRiskLevelID: String

    public init(
        nightWindowStartHour: Int = 22,
        nightWindowEndHour: Int = 5,
        highRiskSignalGroups: [[String]] = [
            ["publish", "post", "submit", "share", "send"],
            ["buy", "purchase", "pay", "checkout", "upgrade", "subscribe"],
            ["delete", "remove", "erase", "cancel", "quit"]
        ],
        nightFallbackRiskLevelByModeID: [String: String] = [
            BASDecisionMode.primaryID: BASRiskLevel.medium.rawValue,
            BASDecisionMode.comparativeID: BASRiskLevel.high.rawValue,
            BASDecisionMode.reflectiveID: BASRiskLevel.high.rawValue
        ],
        defaultRiskLevelByModeID: [String: String] = [
            BASDecisionMode.reflectiveID: BASRiskLevel.medium.rawValue
        ],
        defaultNightFallbackRiskLevelID: String = BASRiskLevel.high.rawValue,
        defaultDayRiskLevelID: String = BASRiskLevel.low.rawValue
    ) {
        self.nightWindowStartHour = nightWindowStartHour
        self.nightWindowEndHour = nightWindowEndHour
        self.highRiskSignalGroups = highRiskSignalGroups
        self.nightFallbackRiskLevelByModeID = nightFallbackRiskLevelByModeID
        self.defaultRiskLevelByModeID = defaultRiskLevelByModeID
        self.defaultNightFallbackRiskLevelID = defaultNightFallbackRiskLevelID
        self.defaultDayRiskLevelID = defaultDayRiskLevelID
    }

    public func isNightWindow(hour: Int) -> Bool {
        if nightWindowStartHour == nightWindowEndHour {
            return true
        }
        if nightWindowStartHour < nightWindowEndHour {
            return (nightWindowStartHour..<nightWindowEndHour).contains(hour)
        }
        return hour >= nightWindowStartHour || hour < nightWindowEndHour
    }

    public func containsHighRiskSignal(in text: String) -> Bool {
        highRiskSignalGroups.contains { group in
            group.contains { text.contains($0) }
        }
    }

    public func nightFallbackRiskLevel(for mode: BASDecisionMode) -> BASRiskLevel {
        resolveRiskLevel(
            in: nightFallbackRiskLevelByModeID,
            mode: mode,
            fallback: defaultNightFallbackRiskLevelID
        )
    }

    public func defaultRiskLevel(for mode: BASDecisionMode) -> BASRiskLevel {
        resolveRiskLevel(
            in: defaultRiskLevelByModeID,
            mode: mode,
            fallback: defaultDayRiskLevelID
        )
    }

    private func resolveRiskLevel(
        in mapping: [String: String],
        mode: BASDecisionMode,
        fallback: String
    ) -> BASRiskLevel {
        let aliases = [mode.identifier, mode.rawValue]
        for alias in aliases {
            if let riskLevel = mapping[alias].flatMap(BASRiskLevel.init(rawValue:)) {
                return riskLevel
            }
        }
        return BASRiskLevel(rawValue: fallback) ?? .low
    }
}

public enum BASBrainBootstrapAdvisor {
    public static func inferRiskLevel(
        mode: BASDecisionMode,
        prompt: String,
        now: Date,
        behavior: BASBrainBootstrapAdvisorBehavior = .generic
    ) -> BASRiskLevel {
        let lowercased = prompt.lowercased()
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: now)
        if behavior.isNightWindow(hour: hour) {
            if behavior.containsHighRiskSignal(in: lowercased) {
                return .high
            }
            return behavior.nightFallbackRiskLevel(for: mode)
        }

        return behavior.defaultRiskLevel(for: mode)
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
