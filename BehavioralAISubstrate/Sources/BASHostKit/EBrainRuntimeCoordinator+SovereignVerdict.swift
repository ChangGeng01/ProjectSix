import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — sovereign verdict evaluator.
// buildSovereignVerdict — L14 BR-001..BR-012 hard-rule evaluation + lexicographic escalation.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func buildSovereignVerdict(
        request: BASEBrainTurnRequest,
        runtimeTrace: BASRuntimeTrace,
        budgetFrame: BASBudgetFrame,
        thoughtFold: BASThoughtFold,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        emergencyBrake: BASEmergencyBrake,
        updateTickets: [BASUpdateTicket]
    ) -> BASSovereignVerdict {
        let policyHash = sovereignPolicyHash(for: budgetFrame)
        var verdictLevel: BASSovereignVerdictLevel = .pass
        var reasonCodes: [String] = []
        var revokedPermissions = Set<BASSovereignPermission>()
        var quarantineRefs: [String] = []
        var rollbackRef: String?

        func raise(
            _ newLevel: BASSovereignVerdictLevel,
            reasons: [String],
            revoked: [BASSovereignPermission] = [],
            quarantineSources: [String] = [],
            rollbackSource: String? = nil
        ) {
            if newLevel > verdictLevel {
                verdictLevel = newLevel
            }
            reasonCodes.append(contentsOf: reasons)
            revoked.forEach { revokedPermissions.insert($0) }
            quarantineRefs.append(contentsOf: quarantineSources)
            if let rollbackSource {
                rollbackRef = rollbackSource
            }
        }

        if policyLineage == nil {
            raise(
                .shadowLock,
                reasons: ["runtime.policy_lineage_missing"],
                revoked: [.toolWrite, .externalActuation, .checkpointCommit]
            )
        }

        if budgetFrame.runMode == .recovery {
            raise(
                .shadowLock,
                reasons: ["runtime.recovery"],
                revoked: [.deepLoop, .checkpointCommit]
            )
        }

        if budgetFrame.runMode == .quarantine {
            raise(
                .quarantine,
                reasons: ["runtime.quarantine"],
                revoked: [
                    .toolRead,
                    .toolWrite,
                    .externalActuation,
                    .checkpointCommit,
                    .memoryWriteHot,
                    .memoryWriteWarm,
                    .memoryWriteCold,
                    .hostMutation,
                    .rulePromotion
                ],
                quarantineSources: [
                    runtimeTrace.sessionID,
                    thoughtFold.foldID,
                    thoughtFold.resumeFrameRef ?? ""
                ]
            )
        }

        if riskCard.riskLevel == .extreme && actionPermit.mode == .answer {
            raise(
                .deadStop,
                reasons: ["risk.extreme", "permit.answer", "risk_permit_conflict"],
                revoked: BASSovereignPermission.allCases,
                rollbackSource: thoughtFold.rollbackAnchorRef ?? thoughtFold.snapshotRef
            )
        } else if actionPermit.mode == .block {
            raise(
                emergencyBrake.brakeLevel == .lockdown ? .deadStop : .toolCut,
                reasons: ["permit.block"] + actionPermit.reasonCodes,
                revoked: [
                    .toolRead,
                    .toolWrite,
                    .externalActuation,
                    .renderHighRisk
                ],
                rollbackSource: emergencyBrake.brakeLevel == .lockdown
                    ? (thoughtFold.rollbackAnchorRef ?? thoughtFold.snapshotRef)
                    : nil
            )
        }

        let needsProtectedWriteLane =
            request.activeKillSwitches.contains(.requireReviewedWrites)
            || actionPermit.mode == .delay
            || actionPermit.mode == .replace
            || updateTickets.contains(where: { $0.requiresReview || $0.conflictFlag })

        if needsProtectedWriteLane {
            raise(
                .memoryFreeze,
                reasons: request.activeKillSwitches.map(\.rawValue) + actionPermit.reasonCodes + ["writes.review_required"],
                revoked: [
                    .memoryWriteHot,
                    .memoryWriteWarm,
                    .memoryWriteCold,
                    .hostMutation,
                    .rulePromotion
                ]
            )
        }

        if budgetFrame.runMode == .guard || riskCard.riskLevel >= .high {
            raise(
                .throttle,
                reasons: ["risk.\(riskCard.riskLevel.rawValue)"],
                revoked: [.deepLoop]
            )
        }

        if emergencyBrake.brakeLevel == .lockdown {
            raise(
                .deadStop,
                reasons: emergencyBrake.reasonCodes + ["runtime.lockdown"],
                revoked: BASSovereignPermission.allCases,
                rollbackSource: thoughtFold.rollbackAnchorRef ?? thoughtFold.snapshotRef
            )
        }

        let userStubMode: BASSovereignUserStubMode
        switch verdictLevel {
        case .deadStop:
            userStubMode = .refusalOnly
        case .toolCut, .memoryFreeze, .quarantine, .rollback:
            userStubMode = .minimalReceipt
        case .pass, .throttle, .shadowLock:
            userStubMode = .none
        }

        let verdictID = "verdict.\(runtimeTrace.sessionID)"
        let orderedQuarantineRefs = unique(quarantineRefs.filter { !$0.isEmpty })
        let expiresAt = runtimeTrace.recordedAt.addingTimeInterval(
            verdictLevel.isLatchedByDefault ? 300 : 90
        )

        return BASSovereignVerdict(
            verdictID: verdictID,
            verdictLevel: verdictLevel,
            latched: verdictLevel.isLatchedByDefault,
            forcedMode: emergencyBrake.forcedMode ?? verdictLevel.defaultForcedMode,
            reasonCodes: orderedReasonCodes(reasonCodes),
            revokedPermissions: Array(revokedPermissions).sorted { $0.rawValue < $1.rawValue },
            quarantineRefs: orderedQuarantineRefs,
            rollbackRef: rollbackRef?.trimmingCharacters(in: .whitespacesAndNewlines),
            userStubMode: userStubMode,
            policyHash: policyHash,
            expiresAt: expiresAt
        )
    }

}
