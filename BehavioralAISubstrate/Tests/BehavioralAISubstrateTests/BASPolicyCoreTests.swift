import Foundation
import Testing
@testable import BASPolicy
@testable import BASMemory
@testable import BASRuntimeCore

@Suite("BASPolicy")
struct BASPolicyCoreTests {
    @Test("local only profile denies cloud route escalation")
    func localOnlyProfileDeniesCloudEscalation() {
        let profile = BASPolicyProfiles.make(.localOnly)

        let decision = profile.decide(
            at: .routeSelection,
            actionClass: .routeSelection,
            riskLevel: .medium,
            scope: .device,
            sensitivity: .low,
            cloudRequested: true
        )

        #expect(decision.decision == .deny)
        #expect(decision.reason.contains("cloud"))
    }

    @Test("child safe profile blocks high sensitivity recall")
    func childSafeProfileBlocksHighSensitivityRecall() {
        let profile = BASPolicyProfiles.make(.childSafe)

        let decision = profile.decide(
            at: .retrievalAdmit,
            actionClass: .memoryRecall,
            riskLevel: .low,
            scope: .session,
            sensitivity: .high
        )

        #expect(decision.decision == .deny)
        #expect(decision.reason == "scope or sensitivity blocked")
    }

    @Test("JSON DSL compiles into equivalent policy set")
    func jsonDSLCompilesIntoEquivalentPolicySet() throws {
        let document = BASPolicyDSLDocument(
            version: "1",
            rules: [
                BASPolicyRule(
                    id: "confirm-tools",
                    actionClass: .toolCall,
                    enforcementPoints: [.toolDispatch],
                    minimumRiskForConfirmation: BASRiskScore(0.4),
                    blockedScopes: [.task],
                    allowCloud: false
                )
            ]
        )

        let data = try JSONEncoder().encode(document)
        let compiled = try BASPolicyCompiler.decode(from: data)

        let decision = compiled.decide(
            at: .toolDispatch,
            actionClass: .toolCall,
            riskLevel: .medium,
            scope: .device,
            sensitivity: .low,
            cloudRequested: true
        )

        #expect(decision.decision == .deny)
    }

    @Test("rules only fire on matching enforcement points")
    func rulesOnlyFireOnMatchingEnforcementPoints() {
        let set = BASPolicySet(rules: [
            BASPolicyRule(
                id: "output-only",
                actionClass: .outputRelease,
                enforcementPoints: [.outputRelease],
                minimumRiskForConfirmation: BASRiskScore(0.3)
            )
        ])

        let retrievalDecision = set.decide(
            at: .retrievalAdmit,
            actionClass: .outputRelease,
            riskLevel: .high,
            scope: .session,
            sensitivity: .medium
        )
        let outputDecision = set.decide(
            at: .outputRelease,
            actionClass: .outputRelease,
            riskLevel: .high,
            scope: .session,
            sensitivity: .medium
        )

        #expect(retrievalDecision.decision == .allow)
        #expect(outputDecision.decision == .requireConfirmation)
    }

    @Test("strongest matching rule wins across conflicting policy rules")
    func strongestMatchingRuleWinsAcrossConflictingRules() {
        let set = BASPolicySet(rules: [
            BASPolicyRule(
                id: "confirm-medium-risk",
                actionClass: .toolCall,
                enforcementPoints: [.toolDispatch],
                minimumRiskForConfirmation: BASRiskScore(0.4),
                allowCloud: true
            ),
            BASPolicyRule(
                id: "deny-high-sensitivity",
                actionClass: .toolCall,
                enforcementPoints: [.toolDispatch],
                blockedSensitivities: [.high],
                allowCloud: true
            )
        ])

        let decision = set.decide(
            at: .toolDispatch,
            actionClass: .toolCall,
            riskLevel: .high,
            scope: .task,
            sensitivity: .high,
            cloudRequested: false
        )

        #expect(decision.decision == .deny)
        #expect(decision.ruleID == "deny-high-sensitivity")
        #expect(decision.matchedRuleIDs == ["confirm-medium-risk", "deny-high-sensitivity"])
    }

    @Test("matched rule ids stay visible when multiple rules contribute to decision space")
    func matchedRuleIDsStayVisibleAcrossMultipleMatches() throws {
        let document = BASPolicyDSLDocument(
            version: "1",
            rules: [
                BASPolicyRule(
                    id: "confirm-output",
                    actionClass: .outputRelease,
                    enforcementPoints: [.outputRelease],
                    minimumRiskForConfirmation: BASRiskScore(0.5),
                    allowCloud: true
                ),
                BASPolicyRule(
                    id: "deny-cloud-output",
                    actionClass: .outputRelease,
                    enforcementPoints: [.outputRelease],
                    allowCloud: false
                )
            ]
        )

        let set = try BASPolicyCompiler.decode(from: JSONEncoder().encode(document))
        let decision = set.decide(
            at: .outputRelease,
            actionClass: .outputRelease,
            riskLevel: .high,
            scope: .session,
            sensitivity: .medium,
            cloudRequested: true
        )

        #expect(decision.decision == .deny)
        #expect(decision.ruleID == "deny-cloud-output")
        #expect(decision.matchedRuleIDs == ["confirm-output", "deny-cloud-output"])
    }
    // MARK: - H19(大审计立即层,2026-07-08):默认分支 fail-closed

    @Test("H19: unmatched action with cloudRequested is denied (fail-closed), not allowed")
    func unmatchedCloudRequestIsDenied() {
        // localOnly 只有 route/output 两规则——toolCall 无匹配。
        // 旧行为:低风险云端 toolCall 走"no rule matched"→ allow(fail-open)。
        let profile = BASPolicyProfiles.make(.localOnly)
        let decision = profile.decide(
            at: .toolDispatch,
            actionClass: .toolCall,
            riskLevel: .low,
            scope: .device,
            sensitivity: .low,
            cloudRequested: true
        )
        #expect(decision.decision == .deny)
        #expect(decision.reason.contains("fail-closed"))
    }

    @Test("H19: unmatched memoryWrite with cloudRequested is denied under localOnly")
    func unmatchedCloudMemoryWriteIsDenied() {
        let profile = BASPolicyProfiles.make(.localOnly)
        let decision = profile.decide(
            at: .memoryWrite,
            actionClass: .memoryWrite,
            riskLevel: .low,
            scope: .user,
            sensitivity: .medium,
            cloudRequested: true
        )
        #expect(decision.decision == .deny)
    }

    @Test("H19: unmatched LOCAL action stays allowed (sovereign-local default unchanged)")
    func unmatchedLocalActionStaysAllowed() {
        let profile = BASPolicyProfiles.make(.localOnly)
        let decision = profile.decide(
            at: .toolDispatch,
            actionClass: .toolCall,
            riskLevel: .low,
            scope: .device,
            sensitivity: .low,
            cloudRequested: false
        )
        #expect(decision.decision == .allow)
    }

    @Test("H19: childSafe blocks high-sensitivity output release")
    func childSafeBlocksHighSensitivityOutput() {
        // 旧 childSafe 无 output 规则 → 任意敏感度输出放行。
        let profile = BASPolicyProfiles.make(.childSafe)
        let decision = profile.decide(
            at: .outputRelease,
            actionClass: .outputRelease,
            riskLevel: .low,
            scope: .session,
            sensitivity: .high
        )
        #expect(decision.decision == .deny)
    }

}
