import Foundation
import BASMemory
import BASRuntimeCore

public enum BASEnforcementPoint: String, Codable, Sendable, CaseIterable {
    case inputAccepted
    case memoryWrite
    case retrievalAdmit
    case routeSelection
    case toolDispatch
    case outputRelease
    case interventionTrigger
}

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
    public var enforcementPoints: [BASEnforcementPoint]
    public var minimumRiskForConfirmation: BASRiskScore?
    public var blockedScopes: [BASMemoryScope]
    public var blockedSensitivities: [BASMemorySensitivity]
    public var allowCloud: Bool

    public init(
        id: String,
        actionClass: BASPolicyActionClass,
        enforcementPoints: [BASEnforcementPoint] = BASEnforcementPoint.allCases,
        minimumRiskForConfirmation: BASRiskScore? = nil,
        blockedScopes: [BASMemoryScope] = [],
        blockedSensitivities: [BASMemorySensitivity] = [],
        allowCloud: Bool = true
    ) {
        self.id = id
        self.actionClass = actionClass
        self.enforcementPoints = enforcementPoints
        self.minimumRiskForConfirmation = minimumRiskForConfirmation
        self.blockedScopes = blockedScopes
        self.blockedSensitivities = blockedSensitivities
        self.allowCloud = allowCloud
    }
}

public struct BASPolicyDecisionRecord: Codable, Sendable, Equatable {
    public var ruleID: String?
    public var matchedRuleIDs: [String]
    public var decision: BASPolicyDecision
    public var reason: String

    public init(
        ruleID: String? = nil,
        matchedRuleIDs: [String] = [],
        decision: BASPolicyDecision,
        reason: String
    ) {
        self.ruleID = ruleID
        self.matchedRuleIDs = matchedRuleIDs
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
        at enforcementPoint: BASEnforcementPoint = .outputRelease,
        actionClass: BASPolicyActionClass,
        riskLevel: BASRiskLevel,
        scope: BASMemoryScope,
        sensitivity: BASMemorySensitivity,
        cloudRequested: Bool = false
    ) -> BASPolicyDecisionRecord {
        let matchingRules = rules.filter {
            $0.actionClass == actionClass && $0.enforcementPoints.contains(enforcementPoint)
        }

        guard !matchingRules.isEmpty else {
            // H19(大审计立即层,2026-07-08):默认分支 fail-closed。云出口没有任何
            // 显式规则授权时一律 deny——旧行为(仅 medium+ 风险才 confirm,其余 allow)
            // 让 localOnly/childSafe 档的未覆盖动作类静默放行云端。本地动作维持
            // sovereign-local 缺省 allow(设备内动作不经此闸约束)。
            if cloudRequested {
                return BASPolicyDecisionRecord(
                    decision: .deny,
                    reason: "no rule matched; cloud egress is fail-closed by default"
                )
            }
            return BASPolicyDecisionRecord(decision: .allow, reason: "no rule matched")
        }

        let matchedRuleIDs = matchingRules.map(\.id)

        if let blockedRule = matchingRules.first(where: {
            $0.blockedScopes.contains(scope) || $0.blockedSensitivities.contains(sensitivity)
        }) {
            return BASPolicyDecisionRecord(
                ruleID: blockedRule.id,
                matchedRuleIDs: matchedRuleIDs,
                decision: .deny,
                reason: "scope or sensitivity blocked"
            )
        }

        if let cloudDeniedRule = matchingRules.first(where: { cloudRequested && !$0.allowCloud }) {
            return BASPolicyDecisionRecord(
                ruleID: cloudDeniedRule.id,
                matchedRuleIDs: matchedRuleIDs,
                decision: .deny,
                reason: "cloud not allowed by policy"
            )
        }

        if let confirmRule = matchingRules.first(where: {
            guard let minimum = $0.minimumRiskForConfirmation else { return false }
            return riskLevel.normalizedScore >= minimum.value
        }) {
            return BASPolicyDecisionRecord(
                ruleID: confirmRule.id,
                matchedRuleIDs: matchedRuleIDs,
                decision: .requireConfirmation,
                reason: "risk threshold reached"
            )
        }

        return BASPolicyDecisionRecord(
            ruleID: matchingRules.first?.id,
            matchedRuleIDs: matchedRuleIDs,
            decision: .allow,
            reason: "policy allowed"
        )
    }
}

public enum BASPolicyProfilePreset: String, Codable, Sendable, CaseIterable {
    case localOnly
    case localFirst
    case cloudAllowed
    case childSafe
    case enterpriseAudit
}

public enum BASPolicyCompiler {
    public static func compile(_ document: BASPolicyDSLDocument) -> BASPolicySet {
        BASPolicySet(rules: document.rules)
    }

    public static func decode(from data: Data) throws -> BASPolicySet {
        try compile(JSONDecoder().decode(BASPolicyDSLDocument.self, from: data))
    }
}

public enum BASPolicyProfiles {
    public static func make(_ preset: BASPolicyProfilePreset) -> BASPolicySet {
        switch preset {
        case .localOnly:
            return BASPolicySet(rules: [
                BASPolicyRule(
                    id: "local-only-route",
                    actionClass: .routeSelection,
                    enforcementPoints: [.routeSelection],
                    minimumRiskForConfirmation: BASRiskScore(0.8),
                    allowCloud: false
                ),
                BASPolicyRule(
                    id: "local-only-output",
                    actionClass: .outputRelease,
                    enforcementPoints: [.outputRelease],
                    minimumRiskForConfirmation: BASRiskScore(0.95),
                    allowCloud: false
                )
            ])
        case .localFirst:
            return BASPolicySet(rules: [
                BASPolicyRule(
                    id: "local-first-route",
                    actionClass: .routeSelection,
                    enforcementPoints: [.routeSelection],
                    minimumRiskForConfirmation: BASRiskScore(1.0),
                    allowCloud: true
                ),
                BASPolicyRule(
                    id: "local-first-tool",
                    actionClass: .toolCall,
                    enforcementPoints: [.toolDispatch],
                    minimumRiskForConfirmation: BASRiskScore(0.6),
                    blockedSensitivities: [.high],
                    allowCloud: false
                )
            ])
        case .cloudAllowed:
            return BASPolicySet(rules: [
                BASPolicyRule(
                    id: "cloud-allowed-route",
                    actionClass: .routeSelection,
                    enforcementPoints: [.routeSelection],
                    minimumRiskForConfirmation: BASRiskScore(0.7),
                    allowCloud: true
                )
            ])
        case .childSafe:
            return BASPolicySet(rules: [
                BASPolicyRule(
                    id: "child-safe-recall",
                    actionClass: .memoryRecall,
                    enforcementPoints: [.retrievalAdmit],
                    minimumRiskForConfirmation: BASRiskScore(0.4),
                    blockedSensitivities: [.high],
                    allowCloud: false
                ),
                BASPolicyRule(
                    id: "child-safe-tools",
                    actionClass: .toolCall,
                    enforcementPoints: [.toolDispatch],
                    minimumRiskForConfirmation: BASRiskScore(0.2),
                    blockedScopes: [.user],
                    allowCloud: false
                ),
                // H19:childSafe 原无 output 规则 → 任意敏感度输出放行(经默认分支)。
                // 补上与 recall 同向的输出闸:高敏感输出 deny,中等以上风险须确认。
                BASPolicyRule(
                    id: "child-safe-output",
                    actionClass: .outputRelease,
                    enforcementPoints: [.outputRelease],
                    minimumRiskForConfirmation: BASRiskScore(0.4),
                    blockedSensitivities: [.high],
                    allowCloud: false
                )
            ])
        case .enterpriseAudit:
            return BASPolicySet(rules: [
                BASPolicyRule(
                    id: "enterprise-route",
                    actionClass: .routeSelection,
                    enforcementPoints: [.routeSelection],
                    minimumRiskForConfirmation: BASRiskScore(0.5),
                    allowCloud: true
                ),
                BASPolicyRule(
                    id: "enterprise-output",
                    actionClass: .outputRelease,
                    enforcementPoints: [.outputRelease],
                    minimumRiskForConfirmation: BASRiskScore(0.5),
                    allowCloud: true
                ),
                BASPolicyRule(
                    id: "enterprise-memory-write",
                    actionClass: .memoryWrite,
                    enforcementPoints: [.memoryWrite],
                    minimumRiskForConfirmation: BASRiskScore(0.7),
                    blockedSensitivities: [],
                    allowCloud: true
                )
            ])
        }
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
