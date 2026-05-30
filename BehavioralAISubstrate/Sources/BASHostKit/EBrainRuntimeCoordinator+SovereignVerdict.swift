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
//
// ch1042 ADR-020 Phase A: the escalation-level decision (the `raise(...)` lattice)
// is extracted into `computeVerdictDecision`, a PURE function of pre-render-settled
// inputs. The only render-derived input (`updateTickets`) is reduced by the caller
// to a `needsProtectedWriteLane` bool, so the decision core itself is
// render-independent and can be reused by the pre-render provisional verdict
// (ADR-020 Phase B). This is a behavior-preserving extract — byte-equal
// unconditionally (verified by the full sweep), no flag involved.

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

        // The single render-derived input, reduced to a bool so the decision
        // core below is render-independent.
        let needsProtectedWriteLane =
            request.activeKillSwitches.contains(.requireReviewedWrites)
            || actionPermit.mode == .delay
            || actionPermit.mode == .replace
            || updateTickets.contains(where: { $0.requiresReview || $0.conflictFlag })

        // Quarantine/rollback ref strings (post-render IDs in this caller; the
        // decision core treats them as opaque, so Phase B can pass placeholders).
        let quarantineSources = [
            runtimeTrace.sessionID,
            thoughtFold.foldID,
            thoughtFold.resumeFrameRef ?? ""
        ]
        let rollbackSource = thoughtFold.rollbackAnchorRef ?? thoughtFold.snapshotRef

        let decision = Self.computeVerdictDecision(
            policyLineagePresent: policyLineage != nil,
            budgetFrame: budgetFrame,
            riskCard: riskCard,
            actionPermit: actionPermit,
            emergencyBrake: emergencyBrake,
            activeKillSwitches: request.activeKillSwitches,
            needsProtectedWriteLane: needsProtectedWriteLane,
            quarantineSources: quarantineSources,
            rollbackSource: rollbackSource
        )

        let userStubMode: BASSovereignUserStubMode
        switch decision.level {
        case .deadStop:
            userStubMode = .refusalOnly
        case .toolCut, .memoryFreeze, .quarantine, .rollback:
            userStubMode = .minimalReceipt
        case .pass, .throttle, .shadowLock:
            userStubMode = .none
        }

        let verdictID = "verdict.\(runtimeTrace.sessionID)"
        let orderedQuarantineRefs = unique(decision.quarantineRefs.filter { !$0.isEmpty })
        let expiresAt = runtimeTrace.recordedAt.addingTimeInterval(
            decision.level.isLatchedByDefault ? 300 : 90
        )

        return BASSovereignVerdict(
            verdictID: verdictID,
            verdictLevel: decision.level,
            latched: decision.level.isLatchedByDefault,
            forcedMode: emergencyBrake.forcedMode ?? decision.level.defaultForcedMode,
            reasonCodes: orderedReasonCodes(decision.reasonCodes),
            revokedPermissions: Array(decision.revokedPermissions).sorted { $0.rawValue < $1.rawValue },
            quarantineRefs: orderedQuarantineRefs,
            rollbackRef: decision.rollbackRef?.trimmingCharacters(in: .whitespacesAndNewlines),
            userStubMode: userStubMode,
            policyHash: policyHash,
            expiresAt: expiresAt
        )
    }

    // ch1042 ADR-020 Phase A — render-independent escalation-level decision core.
    // Pure function of pre-render-settled inputs (everything except
    // `needsProtectedWriteLane`, which the caller derives from `updateTickets`).
    // `quarantineSources`/`rollbackSource` are opaque ref strings supplied by the
    // caller. No instance state is read — `policyLineage` presence is passed in as
    // a `Bool`. ADR-020 Phase B makes this `static` (it reads no `self`) so the
    // pre-render provisional verdict can reuse it without a coordinator; static vs
    // instance dispatch does not change the computed value, so Phase A stays
    // byte-equal (verified by the full sweep).
    static func computeVerdictDecision(
        policyLineagePresent: Bool,
        budgetFrame: BASBudgetFrame,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        emergencyBrake: BASEmergencyBrake,
        activeKillSwitches: [BASKillSwitchID],
        needsProtectedWriteLane: Bool,
        quarantineSources: [String],
        rollbackSource: String?
    ) -> BASSovereignVerdictDecision {
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

        if !policyLineagePresent {
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
                quarantineSources: quarantineSources
            )
        }

        if riskCard.riskLevel == .extreme && actionPermit.mode == .answer {
            raise(
                .deadStop,
                reasons: ["risk.extreme", "permit.answer", "risk_permit_conflict"],
                revoked: BASSovereignPermission.allCases,
                rollbackSource: rollbackSource
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
                    ? rollbackSource
                    : nil
            )
        }

        if needsProtectedWriteLane {
            raise(
                .memoryFreeze,
                reasons: activeKillSwitches.map(\.rawValue) + actionPermit.reasonCodes + ["writes.review_required"],
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
                rollbackSource: rollbackSource
            )
        }

        return BASSovereignVerdictDecision(
            level: verdictLevel,
            reasonCodes: reasonCodes,
            revokedPermissions: revokedPermissions,
            quarantineRefs: quarantineRefs,
            rollbackRef: rollbackRef
        )
    }

}

// ch1042 ADR-020 Phase A — the render-independent output of the verdict-level
// decision lattice. Intermediate value (the final BASSovereignVerdict adds IDs,
// expiry, ordering, and userStubMode); kept internal so the provisional verdict
// (Phase B) can consume the same decision core.
struct BASSovereignVerdictDecision {
    let level: BASSovereignVerdictLevel
    let reasonCodes: [String]
    let revokedPermissions: Set<BASSovereignPermission>
    let quarantineRefs: [String]
    let rollbackRef: String?
}
