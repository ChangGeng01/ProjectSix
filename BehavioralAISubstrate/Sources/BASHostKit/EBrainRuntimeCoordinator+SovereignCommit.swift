import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — sovereign commit tokens / warrants / lock / quarantine /
// audit / execution receipt builders.
// buildSovereignCommitTokens / buildSovereignWarrants / makeCommitToken / makeSovereignWarrant /
// sovereignWarrantWitnessRefs / buildSovereignLock / buildQuarantineRecords /
// buildSovereignAuditEntry / sovereignRuleIDs / sovereignPolicyHash / sovereignSnapshotRef /
// sovereignDigestHex / buildSovereignExecutionReceipts.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func buildSovereignCommitTokens(
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace,
        thoughtFold: BASThoughtFold,
        actionPermit: BASActionPermit,
        updateTickets: [BASUpdateTicket],
        renderedOutput: BASRenderedOutput
    ) -> [BASSovereignCommitToken] {
        guard sovereignVerdict.verdictLevel < .quarantine else {
            return []
        }

        let snapshotRef = sovereignSnapshotRef(for: thoughtFold, sessionID: runtimeTrace.sessionID)
        let turnID = "\(runtimeTrace.sessionID)#\(runtimeTrace.recordedAt.timeIntervalSinceReferenceDate)"
        var tokens: [BASSovereignCommitToken] = []

        if sovereignVerdict.revokedPermissions.contains(.checkpointCommit) == false {
            tokens.append(
                makeCommitToken(
                    sessionID: runtimeTrace.sessionID,
                    turnID: turnID,
                    scope: .checkpointCommit,
                    allowedTargets: [thoughtFold.foldID],
                    actionDigestParts: [
                        "checkpoint",
                        thoughtFold.foldID,
                        renderedOutput.mode.rawValue,
                        String(updateTickets.count)
                    ],
                    snapshotRef: snapshotRef,
                    policyHash: sovereignVerdict.policyHash,
                    issuedAt: runtimeTrace.recordedAt,
                    ttlMs: 60_000
                )
            )
        }

        if sovereignVerdict.revokedPermissions.contains(.memoryWriteHot) == false,
           updateTickets.isEmpty == false {
            tokens.append(
                makeCommitToken(
                    sessionID: runtimeTrace.sessionID,
                    turnID: turnID,
                    scope: .memoryWrite,
                    allowedTargets: updateTickets.map(\.ticketID),
                    actionDigestParts: updateTickets.flatMap(\.actionDigestParts),
                    snapshotRef: snapshotRef,
                    policyHash: sovereignVerdict.policyHash,
                    issuedAt: runtimeTrace.recordedAt,
                    ttlMs: 30_000
                )
            )
        }

        if actionPermit.requireSecondCheck,
           sovereignVerdict.revokedPermissions.contains(.renderHighRisk) == false {
            tokens.append(
                makeCommitToken(
                    sessionID: runtimeTrace.sessionID,
                    turnID: turnID,
                    scope: .renderHighRisk,
                    allowedTargets: [renderedOutput.mode.rawValue],
                    actionDigestParts: [
                        renderedOutput.mode.rawValue,
                        renderedOutput.headline,
                        renderedOutput.body
                    ],
                    snapshotRef: snapshotRef,
                    policyHash: sovereignVerdict.policyHash,
                    issuedAt: runtimeTrace.recordedAt,
                    ttlMs: 15_000
                )
            )
        }

        return tokens
    }

    func buildSovereignWarrants(
        sovereignCommitTokens: [BASSovereignCommitToken],
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace
    ) -> [BASSovereignWarrant] {
        sovereignCommitTokens.map { token in
            makeSovereignWarrant(
                from: token,
                sovereignVerdict: sovereignVerdict,
                runtimeTrace: runtimeTrace
            )
        }
    }

    func makeCommitToken(
        sessionID: String,
        turnID: String,
        scope: BASSovereignCommitScope,
        allowedTargets: [String],
        actionDigestParts: [String],
        snapshotRef: String,
        policyHash: String,
        issuedAt: Date,
        ttlMs: Int
    ) -> BASSovereignCommitToken {
        let nonce = "nonce.\(UUID().uuidString.lowercased())"
        let actionDigest = sovereignDigestHex(
            actionDigestParts + [sessionID, turnID, scope.rawValue, snapshotRef, policyHash]
        )
        let tokenID = "token.\(scope.rawValue).\(sessionID).\(abs(actionDigest.hashValue))"
        let signature = sovereignDigestHex(
            [
                tokenID,
                sessionID,
                turnID,
                scope.rawValue,
                actionDigest,
                snapshotRef,
                policyHash,
                String(ttlMs),
                nonce,
                String(issuedAt.timeIntervalSinceReferenceDate)
            ] + allowedTargets
        )

        return BASSovereignCommitToken(
            tokenID: tokenID,
            sessionID: sessionID,
            turnID: turnID,
            scope: scope,
            allowedTargets: allowedTargets,
            actionDigest: actionDigest,
            snapshotRef: snapshotRef,
            policyHash: policyHash,
            ttlMs: ttlMs,
            nonce: nonce,
            singleUse: true,
            signature: signature
        )
    }

    func makeSovereignWarrant(
        from token: BASSovereignCommitToken,
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace
    ) -> BASSovereignWarrant {
        let jurisdictionRef = "jurisdiction.\(token.scope.rawValue)"
        let timeLockRef = "timelock.\(token.turnID).\(token.scope.rawValue).ttl_\(token.ttlMs)"
        let warrantID = "warrant.\(token.scope.rawValue).\(runtimeTrace.sessionID).\(abs(token.actionDigest.hashValue))"
        let issuedAt = runtimeTrace.recordedAt
        let expiresAt = issuedAt.addingTimeInterval(Double(token.ttlMs) / 1_000)
        let witnessRefs = sovereignWarrantWitnessRefs(
            token: token,
            sovereignVerdict: sovereignVerdict
        )
        let signature = sovereignDigestHex(
            [
                warrantID,
                token.scope.rawValue,
                token.actionDigest,
                token.tokenID,
                jurisdictionRef,
                token.snapshotRef,
                timeLockRef,
                token.policyHash,
                String(issuedAt.timeIntervalSinceReferenceDate),
                String(expiresAt.timeIntervalSinceReferenceDate),
                String(token.singleUse),
                token.signature
            ] + witnessRefs
        )

        return BASSovereignWarrant(
            warrantID: warrantID,
            scope: token.scope,
            actionDigest: token.actionDigest,
            commitTokenRef: token.tokenID,
            jurisdictionRef: jurisdictionRef,
            snapshotRef: token.snapshotRef,
            timeLockRef: timeLockRef,
            policyHash: token.policyHash,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            witnessRefs: witnessRefs,
            singleUse: token.singleUse,
            signature: signature
        )
    }

    func sovereignWarrantWitnessRefs(
        token: BASSovereignCommitToken,
        sovereignVerdict: BASSovereignVerdict
    ) -> [String] {
        let baseWitnesses = [
            "permit.\(token.turnID).\(token.scope.rawValue)",
            "integrity.\(token.snapshotRef)",
            "continuity.\(token.turnID)",
            "policy.\(token.policyHash)"
        ]

        let scopeWitnesses: [String] = switch token.scope {
        case .checkpointCommit:
            [
                "checkpoint.\(token.snapshotRef)",
                "render_mode.\(token.allowedTargets.first ?? "unknown")"
            ]
        case .memoryWrite:
            ["mutation.memory.\(token.turnID)"] + token.allowedTargets.prefix(2).map { "memory_target.\($0)" }
        case .renderHighRisk:
            [
                "render.second_check.\(token.turnID)",
                "render_target.\(token.allowedTargets.first ?? "unknown")"
            ]
        case .toolRead:
            ["tool.read.\(token.allowedTargets.first ?? "local")"]
        case .toolWrite:
            ["tool.write.\(token.allowedTargets.first ?? "local")"]
        case .hostMutate:
            ["mutation.host.\(token.turnID)"]
        }

        let verdictWitnesses = sovereignVerdict.reasonCodes.prefix(2).map { "verdict.\($0)" }
        return orderedReasonCodes(baseWitnesses + scopeWitnesses + verdictWitnesses)
    }

    func buildSovereignLock(
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace
    ) -> BASSovereignLock? {
        guard sovereignVerdict.verdictLevel != .pass else {
            return nil
        }

        let scope: BASSovereignLockScope = sovereignVerdict.latched ? .session : .turn
        let releaseCondition = sovereignVerdict.latched
            ? "governance_review_required"
            : "turn_end_or_retry"

        return BASSovereignLock(
            lockID: "lock.\(runtimeTrace.sessionID).\(sovereignVerdict.verdictLevel.rawValue)",
            scope: scope,
            lockLevel: sovereignVerdict.verdictLevel,
            createdAt: runtimeTrace.recordedAt,
            releaseCondition: releaseCondition
        )
    }

    func buildQuarantineRecords(
        sovereignVerdict: BASSovereignVerdict,
        runtimeTrace: BASRuntimeTrace,
        thoughtFold: BASThoughtFold
    ) -> [BASQuarantineRecord] {
        guard sovereignVerdict.verdictLevel >= .quarantine else {
            return []
        }

        let sessionRecord = BASQuarantineRecord(
            quarantineID: "quarantine.session.\(runtimeTrace.sessionID)",
            zone: .session,
            sourceRef: runtimeTrace.sessionID,
            reasonCodes: sovereignVerdict.reasonCodes,
            isolatedAt: runtimeTrace.recordedAt,
            releasePolicy: "manual_review_or_clean_recovery",
            reviewState: .held
        )
        let cacheRecord = BASQuarantineRecord(
            quarantineID: "quarantine.cache.\(thoughtFold.foldID)",
            zone: .cache,
            sourceRef: thoughtFold.foldID,
            reasonCodes: sovereignVerdict.reasonCodes,
            isolatedAt: runtimeTrace.recordedAt,
            releasePolicy: "invalidate_after_verified_resume",
            reviewState: .held
        )
        return [sessionRecord, cacheRecord]
    }

    func buildSovereignAuditEntry(
        sovereignVerdict: BASSovereignVerdict,
        sovereignCommitTokens: [BASSovereignCommitToken],
        sovereignWarrants: [BASSovereignWarrant],
        quarantineRecords: [BASQuarantineRecord],
        runtimeTrace: BASRuntimeTrace,
        thoughtFold: BASThoughtFold,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit
    ) -> BASSovereignAuditEntry {
        let turnID = "\(runtimeTrace.sessionID)#\(runtimeTrace.recordedAt.timeIntervalSinceReferenceDate)"
        let snapshotRef = sovereignSnapshotRef(for: thoughtFold, sessionID: runtimeTrace.sessionID)
        let auditID = "audit.\(runtimeTrace.sessionID).\(sovereignVerdict.verdictLevel.rawValue)"
        let actionRefs =
            sovereignCommitTokens.map(\.tokenID)
            + sovereignWarrants.map(\.warrantID)
            + quarantineRecords.map(\.quarantineID)
        let signalRefs = orderedReasonCodes(
            [
                "risk:\(riskCard.riskLevel.rawValue)",
                "permit:\(actionPermit.mode.rawValue)",
                "fold:\(thoughtFold.foldID)",
                thoughtFold.checksum.isEmpty ? nil : "fold_checksum:\(thoughtFold.checksum)",
                sovereignVerdict.forcedMode.map { "forced_mode:\($0.rawValue)" }
            ].compactMap { $0 }
                + sovereignVerdict.reasonCodes
                + sovereignWarrants.flatMap(\.witnessRefs)
        )
        let ruleIDs = sovereignRuleIDs(for: sovereignVerdict)
        let signature = sovereignDigestHex(
            [
                auditID,
                runtimeTrace.sessionID,
                turnID,
                sovereignVerdict.verdictID,
                snapshotRef,
                sovereignVerdict.policyHash
            ] + ruleIDs + signalRefs + actionRefs
        )

        return BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: runtimeTrace.sessionID,
            turnID: turnID,
            verdictRef: sovereignVerdict.verdictID,
            ruleIDs: ruleIDs,
            signalRefs: signalRefs,
            actionRefs: actionRefs,
            snapshotRef: snapshotRef,
            actor: .system,
            signature: signature,
            appendedAt: runtimeTrace.recordedAt
        )
    }

    func sovereignRuleIDs(
        for verdict: BASSovereignVerdict
    ) -> [String] {
        var rules: [String] = []
        if verdict.reasonCodes.contains("runtime.policy_lineage_missing") {
            rules.append("BR-SOV-001")
        }
        if verdict.reasonCodes.contains("risk_permit_conflict") {
            rules.append("BR-SOV-002")
        }
        if verdict.reasonCodes.contains("writes.review_required") {
            rules.append("BR-SOV-003")
        }
        if verdict.reasonCodes.contains("runtime.quarantine") {
            rules.append("BR-SOV-004")
        }
        if verdict.reasonCodes.contains("runtime.lockdown") {
            rules.append("BR-SOV-005")
        }
        if verdict.reasonCodes.contains(where: { $0 == "risk.high" || $0 == "risk.extreme" }) {
            rules.append("BR-SOV-006")
        }
        return unique(rules)
    }

    func sovereignPolicyHash(
        for budgetFrame: BASBudgetFrame
    ) -> String {
        let components = [
            policyLineage?.bundleVersion ?? budgetFrame.policyBundleVersion ?? "policy.none",
            policyLineage?.providerRoutingPolicyID ?? budgetFrame.policyDecisionIDs.first ?? "routing.none",
            policyLineage?.runtimeTuningPolicyID ?? budgetFrame.policyDecisionIDs.dropFirst().first ?? "tuning.none",
            policyLineage?.resolutionSourceID ?? "resolution.none"
        ]
        return sovereignDigestHex(components)
    }

    func sovereignSnapshotRef(
        for thoughtFold: BASThoughtFold,
        sessionID: String
    ) -> String {
        thoughtFold.snapshotRef?.trimmedNonEmpty
            ?? thoughtFold.rollbackAnchorRef?.trimmedNonEmpty
            ?? "snapshot.\(sessionID).\(thoughtFold.foldID)"
    }

    func sovereignDigestHex(
        _ components: [String]
    ) -> String {
        let payload = components.joined(separator: "|")
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func buildSovereignExecutionReceipts(
        sovereignActuationCommands: [BASSovereignActuationCommand],
        runtimeTrace: BASRuntimeTrace
    ) -> [BASSovereignExecutionReceipt] {
        sovereignActuationCommands.enumerated().map { index, command in
            BASSovereignExecutionReceipt(
                commandID: command.commandID,
                kind: command.kind,
                status: .executed,
                executedAt: runtimeTrace.recordedAt.addingTimeInterval(Double(index + 1) * 0.012),
                latencyMs: (index + 1) * 12,
                enforcedMode: command.forcedMode,
                reasonCodes: command.reasonCodes
            )
        }
    }

}
