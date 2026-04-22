import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — emergency brake / recovery disposition / vital state /
// sovereign actuation commands.
// buildEmergencyBrake / buildRecoveryDisposition / buildVitalState /
// buildSovereignActuationCommands.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func buildEmergencyBrake(
        budgetFrame: BASBudgetFrame,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        activeKillSwitches: [BASKillSwitchID]
    ) -> BASEmergencyBrake {
        if budgetFrame.runMode == .lockdown || actionPermit.mode == .block && riskCard.riskLevel == .extreme {
            return BASEmergencyBrake(
                brakeLevel: .lockdown,
                reasonCodes: orderedReasonCodes(
                    [
                        "risk.extreme",
                        "permit.block"
                    ] + activeKillSwitches.map(\.rawValue)
                ),
                forcedMode: .lockdown
            )
        }

        if budgetFrame.runMode == .quarantine {
            return BASEmergencyBrake(
                brakeLevel: .quarantine,
                reasonCodes: orderedReasonCodes(
                    ["runtime.quarantine"] + activeKillSwitches.map(\.rawValue)
                ),
                forcedMode: .quarantine
            )
        }

        if budgetFrame.runMode == .guard || riskCard.riskLevel >= .high {
            return BASEmergencyBrake(
                brakeLevel: .guard,
                reasonCodes: orderedReasonCodes(
                    ["risk.\(riskCard.riskLevel.rawValue)"] + activeKillSwitches.map(\.rawValue)
                ),
                forcedMode: .guard
            )
        }

        if budgetFrame.runMode == .recovery {
            return BASEmergencyBrake(
                brakeLevel: .caution,
                reasonCodes: ["runtime.recovery"],
                forcedMode: .recovery
            )
        }

        return BASEmergencyBrake(
            brakeLevel: .none,
            reasonCodes: []
        )
    }

    func buildRecoveryDisposition(
        budgetFrame: BASBudgetFrame,
        emergencyBrake: BASEmergencyBrake,
        sovereignVerdict: BASSovereignVerdict?
    ) -> BASRecoveryDisposition? {
        func contract(
            kind: BASRecoveryDispositionKind,
            summary: String,
            reasonCodes: [String],
            toolWriteAllowed: Bool,
            memoryWriteAllowed: Bool
        ) -> BASRecoveryDisposition {
            var blockedActionClasses: [String] = []
            if toolWriteAllowed == false {
                blockedActionClasses.append("tool_write")
            }
            if memoryWriteAllowed == false {
                blockedActionClasses.append("memory_write")
            }

            let remediationActions: [String]
            let requiredConfirmations: [String]
            switch kind {
            case .recovery:
                remediationActions = [
                    "review_runtime_diagnostics",
                    "rebuild_trusted_state",
                    "collect_confirmation:operator_recovery_review"
                ]
                requiredConfirmations = ["operator_recovery_review"]
            case .quarantine:
                remediationActions = [
                    "review_runtime_diagnostics",
                    "preserve_quarantine_evidence",
                    "rebuild_trusted_state",
                    "collect_confirmation:operator_quarantine_release"
                ]
                requiredConfirmations = ["operator_quarantine_release"]
            case .lockdown:
                remediationActions = [
                    "review_runtime_diagnostics",
                    "preserve_dead_stop_evidence",
                    "require_operator_release"
                ]
                requiredConfirmations = ["operator_lockdown_release"]
            }

            return BASRecoveryDisposition(
                kind: kind,
                summary: summary,
                reasonCodes: reasonCodes,
                remediationRequired: true,
                restrictedLease: true,
                toolWriteAllowed: toolWriteAllowed,
                memoryWriteAllowed: memoryWriteAllowed,
                operatorReviewRequired: true,
                requiredConfirmations: requiredConfirmations,
                allowedActionClasses: ["render_local_guidance", "load_governed_memory"],
                blockedActionClasses: blockedActionClasses,
                remediationActions: remediationActions
            )
        }

        if let sovereignVerdict {
            switch sovereignVerdict.verdictLevel {
            case .deadStop:
                return contract(
                    kind: .lockdown,
                    summary: "The turn entered lockdown after a sovereign dead-stop verdict revoked execution authority.",
                    reasonCodes: orderedReasonCodes(sovereignVerdict.reasonCodes + emergencyBrake.reasonCodes + ["runtime.lockdown"]),
                    toolWriteAllowed: false,
                    memoryWriteAllowed: false
                )
            case .quarantine:
                return contract(
                    kind: .quarantine,
                    summary: "The turn entered quarantine after the sovereign verdict flagged runtime or continuity trust loss.",
                    reasonCodes: orderedReasonCodes(sovereignVerdict.reasonCodes + emergencyBrake.reasonCodes + ["runtime.quarantine"]),
                    toolWriteAllowed: false,
                    memoryWriteAllowed: false
                )
            case .rollback, .shadowLock:
                return contract(
                    kind: .recovery,
                    summary: "The turn entered recovery because the sovereign verdict requires a verified policy or state reset before normal execution resumes.",
                    reasonCodes: orderedReasonCodes(sovereignVerdict.reasonCodes + emergencyBrake.reasonCodes + ["runtime.recovery"]),
                    toolWriteAllowed: sovereignVerdict.verdictLevel < .toolCut,
                    memoryWriteAllowed: sovereignVerdict.verdictLevel < .memoryFreeze
                )
            case .pass, .throttle, .toolCut, .memoryFreeze:
                break
            }
        }

        switch budgetFrame.runMode {
        case .recovery:
            return contract(
                kind: .recovery,
                summary: "The turn entered recovery so bootstrap or state repair can finish before deeper execution resumes.",
                reasonCodes: orderedReasonCodes(emergencyBrake.reasonCodes + ["runtime.recovery"]),
                toolWriteAllowed: false,
                memoryWriteAllowed: false
            )
        case .quarantine:
            return contract(
                kind: .quarantine,
                summary: "The turn entered quarantine after repeated recovery pressure or consistency failure.",
                reasonCodes: orderedReasonCodes(emergencyBrake.reasonCodes + ["runtime.quarantine"]),
                toolWriteAllowed: false,
                memoryWriteAllowed: false
            )
        case .lockdown:
            return contract(
                kind: .lockdown,
                summary: "The turn entered lockdown after a sovereign hard stop and cannot resume higher-order execution yet.",
                reasonCodes: orderedReasonCodes(emergencyBrake.reasonCodes + ["runtime.lockdown"]),
                toolWriteAllowed: false,
                memoryWriteAllowed: false
            )
        case .dormant, .pulse, .sentinel, .engage, .reflect, .deepLoop, .guard:
            return nil
        }
    }

    func buildVitalState(
        deviceState: BASDeviceState,
        budgetFrame: BASBudgetFrame,
        runtimeTrace: BASRuntimeTrace,
        emergencyBrake: BASEmergencyBrake
    ) -> BASVitalState {
        let thermalMargin: Double = switch deviceState.thermalLevel {
        case .nominal:
            0.92
        case .warm:
            0.66
        case .hot:
            0.34
        case .critical:
            0.08
        }
        let powerMargin = max(0.04, 1 - runtimeTrace.powerEstimate)
        let continuityPenalty = emergencyBrake.brakeLevel == .none ? 0.0 : 0.18

        return BASVitalState(
            wakeState: budgetFrame.runMode,
            survivalMargin: max(0.08, min(deviceState.batteryLevel, thermalMargin)),
            thermalMargin: thermalMargin,
            powerMargin: powerMargin,
            continuityScore: max(
                0,
                min(1, 0.82 - continuityPenalty + (budgetFrame.hasActiveLease() ? 0.08 : 0))
            ),
            stabilityScore: max(
                0,
                min(1, 0.88 - (1 - thermalMargin) * 0.5 - runtimeTrace.powerEstimate * 0.25)
            )
        )
    }

    func buildSovereignActuationCommands(
        sovereignVerdict: BASSovereignVerdict?,
        runtimeTrace: BASRuntimeTrace,
        budgetFrame: BASBudgetFrame,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit
    ) -> [BASSovereignActuationCommand] {
        guard let sovereignVerdict else {
            return []
        }

        var commands: [BASSovereignActuationCommand] = []

        if budgetFrame.runMode == .guard || sovereignVerdict.verdictLevel == .throttle {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.guard.\(runtimeTrace.sessionID)",
                    kind: .guardShift,
                    reasonCodes: orderedReasonCodes(
                        sovereignVerdict.reasonCodes + ["risk.\(riskCard.riskLevel.rawValue)"]
                    ),
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode ?? .guard
                )
            )
        }

        if sovereignVerdict.revokedPermissions.contains(.memoryWriteHot)
            || sovereignVerdict.revokedPermissions.contains(.memoryWriteWarm)
            || sovereignVerdict.revokedPermissions.contains(.memoryWriteCold)
            || actionPermit.mode == .delay
            || actionPermit.mode == .block
            || actionPermit.mode == .replace {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.memory-freeze.\(runtimeTrace.sessionID)",
                    kind: .memoryFreeze,
                    reasonCodes: orderedReasonCodes(sovereignVerdict.reasonCodes + actionPermit.reasonCodes),
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode
                )
            )
        }

        if sovereignVerdict.verdictLevel == .toolCut {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.tool-cut.\(runtimeTrace.sessionID)",
                    kind: .toolCut,
                    reasonCodes: orderedReasonCodes(sovereignVerdict.reasonCodes + ["permit.\(actionPermit.mode.rawValue)"]),
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode
                )
            )
        }

        if sovereignVerdict.verdictLevel == .quarantine {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.quarantine.\(runtimeTrace.sessionID)",
                    kind: .quarantine,
                    reasonCodes: sovereignVerdict.reasonCodes,
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode ?? .quarantine
                )
            )
        }

        if sovereignVerdict.verdictLevel == .rollback {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.rollback.\(runtimeTrace.sessionID)",
                    kind: .rollback,
                    reasonCodes: sovereignVerdict.reasonCodes,
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode ?? .recovery
                )
            )
        }

        if sovereignVerdict.verdictLevel == .deadStop {
            commands.append(
                BASSovereignActuationCommand(
                    commandID: "sovereign.dead-stop.\(runtimeTrace.sessionID)",
                    kind: .deadStop,
                    reasonCodes: sovereignVerdict.reasonCodes,
                    issuedAt: runtimeTrace.recordedAt,
                    forcedMode: sovereignVerdict.forcedMode ?? .lockdown
                )
            )
        }

        var emittedKinds = Set<BASSovereignActuationKind>()
        return commands.filter { command in
            emittedKinds.insert(command.kind).inserted
        }
    }

}
