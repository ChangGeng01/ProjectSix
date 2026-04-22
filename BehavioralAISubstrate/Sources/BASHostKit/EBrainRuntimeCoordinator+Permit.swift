import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — permit / kill-switch / wake / budget / lease builders.
// buildNeuralLeaseReceipt / enforcedPermit / recommendedKillSwitches / buildWakeIntent /
// buildFinalizedBudgetFrame / buildRunLease.  This is the L1 lease-&-life and L11 permit
// glue that runs between risk decision and sovereign verdict.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func buildNeuralLeaseReceipt(
        budgetFrame: BASBudgetFrame,
        thoughtFrame: BASThoughtFrame,
        degradedReasonCodes: [String]
    ) -> BASNeuralLeaseReceipt? {
        guard let organMap = thoughtFrame.organMap else {
            return nil
        }

        let decodeTokensUsed = min(
            budgetFrame.maxDecodeTokens,
            max(
                48,
                (thoughtFrame.candidates.count * 48)
                    + (thoughtFrame.forecasts.count * 24)
                    + (thoughtFrame.critiques.count * 16)
            )
        )
        let energyUsed = min(
            1,
            0.06
                + (Double(thoughtFrame.stepIndex) * 0.08)
                + (Double(organMap.activeOrgans.count) * 0.018)
                + (organMap.morph == .guard || organMap.morph == .stub ? 0.05 : 0)
        )

        return BASNeuralLeaseReceipt(
            leaseID: budgetFrame.leaseID,
            organsUsed: organMap.activeOrgans,
            loopsUsed: thoughtFrame.stepIndex,
            energyUsed: energyUsed,
            decodeTokensUsed: decodeTokensUsed,
            degraded: degradedReasonCodes.isEmpty == false
        )
    }

    func enforcedPermit(
        targetMode: BASActionPermitMode,
        from permit: BASActionPermit,
        reasonCode: String
    ) -> BASActionPermit {
        let reasonCodes = unique(permit.reasonCodes + [reasonCode])

        switch targetMode {
        case .answer:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .answer,
                stackedModes: permit.stackedModes,
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .answer),
                blockedDomains: forbiddenDomains(for: .answer),
                assertionCeiling: "standard",
                toolScope: "bounded",
                memoryScope: permit.memoryScope,
                requireMirror: permit.stackedModes.contains(.mirror),
                requireCompare: permit.stackedModes.contains(.compare),
                requireSecondCheck: permit.requireSecondCheck,
                outputLengthCap: permit.outputLengthCap,
                tonePolicy: permit.tonePolicy,
                templatePolicy: permit.templatePolicy
            )
        case .mirror:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .mirror,
                stackedModes: [.compare],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .mirror),
                blockedDomains: forbiddenDomains(for: .mirror),
                assertionCeiling: "guarded",
                toolScope: "none",
                memoryScope: "standard",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: false,
                outputLengthCap: min(permit.outputLengthCap, 220),
                tonePolicy: "mirrored_grounded",
                templatePolicy: "mirror_before_commit"
            )
        case .compare:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .compare,
                stackedModes: permit.stackedModes,
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .compare),
                blockedDomains: forbiddenDomains(for: .compare),
                assertionCeiling: "guarded",
                toolScope: "bounded",
                memoryScope: "standard",
                requireMirror: permit.stackedModes.contains(.mirror),
                requireCompare: true,
                requireSecondCheck: false,
                outputLengthCap: min(permit.outputLengthCap, 220),
                tonePolicy: "grounded_compare",
                templatePolicy: "bounded_compare"
            )
        case .delay:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .delay,
                stackedModes: [.draftOnly],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .delay),
                blockedDomains: forbiddenDomains(for: .delay),
                assertionCeiling: "guarded",
                toolScope: "none",
                memoryScope: "review_only",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: true,
                outputLengthCap: min(permit.outputLengthCap, 160),
                tonePolicy: "calm_guarded",
                templatePolicy: "delay_with_alternative",
                delayWindow: permit.delayWindow ?? "cool_down"
            )
        case .draftOnly:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .draftOnly,
                stackedModes: [.delay],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .draftOnly),
                blockedDomains: forbiddenDomains(for: .draftOnly),
                assertionCeiling: "guarded",
                toolScope: "none",
                memoryScope: "review_only",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: true,
                outputLengthCap: min(permit.outputLengthCap, 160),
                tonePolicy: "calm_guarded",
                templatePolicy: "draft_only_guarded",
                delayWindow: permit.delayWindow ?? "cool_down"
            )
        case .localOnly:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .localOnly,
                stackedModes: [.replace],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .localOnly),
                blockedDomains: forbiddenDomains(for: .localOnly),
                assertionCeiling: "guarded",
                toolScope: "local_only",
                memoryScope: "review_only",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: true,
                outputLengthCap: min(permit.outputLengthCap, 180),
                tonePolicy: "clear_firm",
                templatePolicy: "local_only_action",
                substituteRequired: true
            )
        case .block:
            return BASActionPermit.protectiveBlock(reasonCodes: reasonCodes)
        case .replace:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .replace,
                stackedModes: [.localOnly],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .replace),
                blockedDomains: forbiddenDomains(for: .replace),
                assertionCeiling: "guarded",
                toolScope: "bounded",
                memoryScope: "review_only",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: false,
                outputLengthCap: min(permit.outputLengthCap, 180),
                tonePolicy: "clear_firm",
                templatePolicy: "protective_alternative",
                substituteRequired: true
            )
        case .escalate:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .escalate,
                stackedModes: [.block],
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: .escalate),
                blockedDomains: forbiddenDomains(for: .escalate),
                assertionCeiling: "minimal",
                toolScope: "none",
                memoryScope: "frozen",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: true,
                outputLengthCap: min(permit.outputLengthCap, 140),
                tonePolicy: "calm_guarded",
                templatePolicy: "escalate_to_sovereign",
                substituteRequired: true,
                escalationHintRef: "sovereign.high"
            )
        }
    }

    func recommendedKillSwitches(
        for findings: [BASRuntimeAuditFinding]
    ) -> [BASKillSwitchID] {
        var switches = Set<BASKillSwitchID>()

        for finding in findings where finding.enforced {
            switch finding.code {
            case let code where code.hasPrefix("budget."):
                switches.insert(.forceGuardMode)
                switches.insert(.disableFastPath)
            case let code where code.hasPrefix("risk."):
                switches.insert(.forceProtectedPermit)
            case let code where code.hasPrefix("evolution."):
                switches.insert(.requireReviewedWrites)
            default:
                break
            }
        }

        return switches.sorted { $0.rawValue < $1.rawValue }
    }

    func buildWakeIntent(
        request: BASEBrainTurnRequest,
        budgetFrame: BASBudgetFrame
    ) -> BASWakeIntent {
        let riskValue: Double = switch request.riskHint ?? .low {
        case .low:
            0.18
        case .medium:
            0.42
        case .high:
            0.76
        case .extreme:
            0.96
        }
        let value = min(
            1,
            (request.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.2 : 0.48)
                + (request.deviceState.foregroundState == .foreground ? 0.18 : 0)
                + riskValue * 0.2
        )
        let cost = min(
            1,
            Double(budgetFrame.maxLoops + budgetFrame.maxCandidates + budgetFrame.retrievalDepth) / 12
        )
        let intentLevel: BASWakeIntentLevel
        switch budgetFrame.runMode {
        case .dormant:
            intentLevel = .dormant
        case .pulse:
            intentLevel = .pulse
        case .sentinel:
            intentLevel = .sentinel
        case .guard, .quarantine, .lockdown:
            intentLevel = .guard
        case .engage, .reflect, .deepLoop, .recovery:
            intentLevel = .engage
        }

        return BASWakeIntent(
            intentLevel: intentLevel,
            estimatedValue: value,
            estimatedRisk: riskValue,
            estimatedCost: cost,
            preferredMode: budgetFrame.runMode
        )
    }

    func buildFinalizedBudgetFrame(
        _ routedBudget: BASBudgetFrame,
        wakeIntent: BASWakeIntent,
        runLease: BASRunLease?,
        actionPermit: BASActionPermit
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            schemaVersion: routedBudget.schemaVersion,
            runMode: routedBudget.runMode,
            maxLoops: routedBudget.maxLoops,
            maxCandidates: routedBudget.maxCandidates,
            maxDecodeTokens: routedBudget.maxDecodeTokens,
            retrievalDepth: routedBudget.retrievalDepth,
            precisionProfile: routedBudget.precisionProfile,
            deviceRoute: routedBudget.deviceRoute,
            thermalGuardLevel: routedBudget.thermalGuardLevel,
            maintenanceAllowed: routedBudget.maintenanceAllowed,
            leaseID: runLease?.leaseID ?? routedBudget.leaseID,
            leaseExpiresAt: runLease?.expiresAt ?? routedBudget.leaseExpiresAt,
            maintenanceClass: routedBudget.maintenanceClass,
            wakeIntentID: wakeIntent.intentLevel.rawValue,
            allowedHeads: runLease?.validHeads ?? defaultAllowedHeads(for: actionPermit),
            policyBundleVersion: policyLineage?.bundleVersion ?? routedBudget.policyBundleVersion,
            policyDecisionIDs: policyLineage?.policyDecisionIDs ?? routedBudget.policyDecisionIDs
        )
    }

    func buildRunLease(
        request: BASEBrainTurnRequest,
        runtimeTrace: BASRuntimeTrace,
        budgetFrame: BASBudgetFrame,
        actionPermit: BASActionPermit
    ) -> BASRunLease? {
        guard budgetFrame.runMode.requiresRunLease else {
            return nil
        }
        let leaseID = budgetFrame.leaseID ?? "lease.\(runtimeTrace.sessionID)"
        let leaseExpiresAt = budgetFrame.leaseExpiresAt
            ?? runtimeTrace.recordedAt.addingTimeInterval(
                Double(max(900, budgetFrame.maxLoops * 300)) / 1_000
            )

        let maxMs = max(
            300,
            runtimeTrace.latencyBreakdownMs.values.reduce(0, +) + (budgetFrame.maxLoops * 120)
        )
        let validHeads = [
            "risk_gate",
            "permit",
            actionPermit.mode == .delay || actionPermit.mode == .block || actionPermit.mode == .replace
                ? "protective_render"
                : "render"
        ]

        return BASRunLease(
            leaseID: leaseID,
            sessionID: runtimeTrace.sessionID,
            turnID: "\(runtimeTrace.sessionID)#\(runtimeTrace.recordedAt.timeIntervalSinceReferenceDate)",
            allowedMode: budgetFrame.runMode,
            maxLoops: budgetFrame.maxLoops,
            maxMs: maxMs,
            maxEnergyQuota: min(1, runtimeTrace.powerEstimate + 0.1),
            validHeads: validHeads,
            expiresAt: leaseExpiresAt
        )
    }

}
