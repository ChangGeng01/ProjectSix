import Foundation
import BASMemory
import BASRuntimeCore

public enum BASRolePosture: String, Codable, Sendable {
    case observe
    case companion
    case coach
    case guardian
}

public enum BASRoleInitiative: String, Codable, Sendable {
    case passive
    case balanced
    case assertive
}

public struct BASRoleProfile: Codable, Sendable, Equatable {
    public var name: String
    public var posture: BASRolePosture
    public var initiative: BASRoleInitiative
    public var confidenceCeiling: Double
    public var roleBoundaryPreset: String

    public init(name: String, posture: BASRolePosture, initiative: BASRoleInitiative, confidenceCeiling: Double, roleBoundaryPreset: String) {
        self.name = name
        self.posture = posture
        self.initiative = initiative
        self.confidenceCeiling = confidenceCeiling
        self.roleBoundaryPreset = roleBoundaryPreset
    }
}

public struct BASRiskScore: Codable, Sendable, Equatable, Comparable {
    public var value: Double

    public init(_ value: Double) {
        self.value = min(max(value, 0), 1)
    }

    public static func < (lhs: BASRiskScore, rhs: BASRiskScore) -> Bool {
        lhs.value < rhs.value
    }
}

public enum BASPolicyActionClass: String, Codable, Sendable {
    case memoryWrite
    case memoryRecall
    case toolCall
    case outputRelease
    case interventionTrigger
    case routeSelection
}

public enum BASPolicyDecision: String, Codable, Sendable, Equatable {
    case allow
    case requireConfirmation
    case deny
}

public struct BASPolicyRule: Codable, Sendable, Equatable {
    public var id: String
    public var actionClass: BASPolicyActionClass
    public var minimumRiskForConfirmation: BASRiskScore?
    public var blockedScopes: [BASMemoryScope]
    public var blockedSensitivities: [BASMemorySensitivity]
    public var allowCloud: Bool

    public init(
        id: String,
        actionClass: BASPolicyActionClass,
        minimumRiskForConfirmation: BASRiskScore? = nil,
        blockedScopes: [BASMemoryScope] = [],
        blockedSensitivities: [BASMemorySensitivity] = [],
        allowCloud: Bool = true
    ) {
        self.id = id
        self.actionClass = actionClass
        self.minimumRiskForConfirmation = minimumRiskForConfirmation
        self.blockedScopes = blockedScopes
        self.blockedSensitivities = blockedSensitivities
        self.allowCloud = allowCloud
    }
}

public struct BASPolicyDecisionRecord: Codable, Sendable, Equatable {
    public var ruleID: String?
    public var decision: BASPolicyDecision
    public var reason: String

    public init(ruleID: String? = nil, decision: BASPolicyDecision, reason: String) {
        self.ruleID = ruleID
        self.decision = decision
        self.reason = reason
    }
}

public struct BASPolicySet: Codable, Sendable, Equatable {
    public var rules: [BASPolicyRule]

    public init(rules: [BASPolicyRule] = []) {
        self.rules = rules
    }

    public func decide(
        actionClass: BASPolicyActionClass,
        riskLevel: BASRiskLevel,
        scope: BASMemoryScope,
        sensitivity: BASMemorySensitivity,
        cloudRequested: Bool = false
    ) -> BASPolicyDecisionRecord {
        guard let rule = rules.first(where: { $0.actionClass == actionClass }) else {
            if cloudRequested && riskLevel >= .medium {
                return BASPolicyDecisionRecord(decision: .requireConfirmation, reason: "cloud request requires confirmation in medium-or-higher risk")
            }
            return BASPolicyDecisionRecord(decision: .allow, reason: "no rule matched")
        }

        if rule.blockedScopes.contains(scope) || rule.blockedSensitivities.contains(sensitivity) {
            return BASPolicyDecisionRecord(ruleID: rule.id, decision: .deny, reason: "scope or sensitivity blocked")
        }

        if let minimum = rule.minimumRiskForConfirmation, riskLevel.normalizedScore >= minimum.value {
            return BASPolicyDecisionRecord(ruleID: rule.id, decision: .requireConfirmation, reason: "risk threshold reached")
        }

        if cloudRequested && !rule.allowCloud {
            return BASPolicyDecisionRecord(ruleID: rule.id, decision: .deny, reason: "cloud not allowed by policy")
        }

        return BASPolicyDecisionRecord(ruleID: rule.id, decision: .allow, reason: "policy allowed")
    }
}

public struct BASPolicyDSLDocument: Codable, Sendable, Equatable {
    public var version: String
    public var rules: [BASPolicyRule]

    public init(version: String = "1", rules: [BASPolicyRule] = []) {
        self.version = version
        self.rules = rules
    }
}
