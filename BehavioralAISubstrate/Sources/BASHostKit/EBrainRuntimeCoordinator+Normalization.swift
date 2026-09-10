import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — input normalization / projection.
// normalize*, reconcile*, derived*, projected*, optionalNonEmptyStrings, normalizeUpdateTickets.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func normalizeBudget(
        _ budget: BASBudgetFrame,
        riskHint: BASBrainRiskLevel?,
        activeKillSwitches: [BASKillSwitchID]
    ) -> (BASBudgetFrame, [BASRuntimeAuditFinding]) {
        var normalized = budget
        var findings: [BASRuntimeAuditFinding] = []

        if activeKillSwitches.contains(.disableFastPath), normalized.runMode == .sentinel {
            normalized.runMode = .engage
            normalized.maxLoops = max(normalized.maxLoops, 1)
            normalized.maxCandidates = max(normalized.maxCandidates, 2)
            findings.append(
                BASRuntimeAuditFinding(
                    code: "kill_switch.disable_fast_path",
                    layerID: "L1",
                    summary: "Disable-fast-path kill switch lifted the run mode out of sentinel execution.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if activeKillSwitches.contains(.forceGuardMode) {
            normalized.runMode = .guard
            normalized.maxLoops = max(normalized.maxLoops, 2)
            normalized.maxCandidates = max(normalized.maxCandidates, 2)
            normalized.retrievalDepth = max(normalized.retrievalDepth, 3)
            normalized.precisionProfile = .protected
            findings.append(
                BASRuntimeAuditFinding(
                    code: "kill_switch.force_guard_mode",
                    layerID: "L1",
                    summary: "Force-guard-mode kill switch escalated the turn into guarded execution.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if let riskHint, riskHint >= .high, normalized.runMode == .sentinel {
            normalized.runMode = .guard
            normalized.maxLoops = max(normalized.maxLoops, riskHint == .extreme ? 2 : 3)
            normalized.maxCandidates = max(normalized.maxCandidates, 2)
            normalized.retrievalDepth = max(normalized.retrievalDepth, 3)
            normalized.precisionProfile = .protected
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.high_risk_fast_path",
                    layerID: "L1",
                    summary: "High-risk input attempted sentinel fast path and was escalated to guarded budget.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if let riskHint, riskHint == .extreme, normalized.runMode != .guard {
            normalized.runMode = .guard
            normalized.maxLoops = max(normalized.maxLoops, 2)
            normalized.maxCandidates = min(max(normalized.maxCandidates, 1), 2)
            normalized.retrievalDepth = max(normalized.retrievalDepth, 3)
            normalized.precisionProfile = .protected
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.extreme_guarded_mode",
                    layerID: "L1",
                    summary: "Extreme-risk input was forced onto guarded mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if normalized.maxLoops < 1 {
            normalized.maxLoops = 1
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.loop_floor",
                    layerID: "L1",
                    summary: "Loop budget was raised to the minimum executable floor.",
                    severity: .low,
                    enforced: true
                )
            )
        }

        if normalized.maxCandidates < 1 {
            normalized.maxCandidates = 1
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.candidate_floor",
                    layerID: "L1",
                    summary: "Candidate budget was raised to preserve at least one executable path.",
                    severity: .low,
                    enforced: true
                )
            )
        }

        return (normalized, findings)
    }

    func normalizeMemoryBundle(
        _ bundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> (BASMemoryBundle, [BASRuntimeAuditFinding]) {
        var normalized = bundle
        var findings: [BASRuntimeAuditFinding] = []

        if normalized.atoms.count > budget.retrievalDepth {
            normalized.atoms = Array(normalized.atoms.prefix(budget.retrievalDepth))
            findings.append(
                BASRuntimeAuditFinding(
                    code: "memory.retrieval_depth_clamped",
                    layerID: "L8",
                    summary: "Retrieved memory atoms exceeded retrieval depth and were clamped to budget.",
                    severity: .medium,
                    enforced: true
                )
            )
        }

        return (normalized, findings)
    }

    func normalizeThoughtFrame(
        _ thoughtFrame: BASThoughtFrame,
        budget: BASBudgetFrame
    ) -> (BASThoughtFrame, [BASRuntimeAuditFinding]) {
        var normalized = thoughtFrame
        var findings: [BASRuntimeAuditFinding] = []

        if normalized.stepIndex > budget.maxLoops {
            normalized.stepIndex = budget.maxLoops
            normalized.stopReason = .maxLoopsReached
            findings.append(
                BASRuntimeAuditFinding(
                    code: "loop.max_loops_clamped",
                    layerID: "L9",
                    summary: "Dream loop exceeded the planned loop budget and was clamped to the maximum.",
                    severity: .high,
                    enforced: true
                )
            )
        } else if normalized.stepIndex < 1 {
            normalized.stepIndex = 1
        }

        if normalized.candidates.count > budget.maxCandidates {
            normalized.candidates = Array(normalized.candidates.prefix(budget.maxCandidates))
            let allowedCandidateIDs = Set(normalized.candidates.map(\.candidateID))
            normalized.forecasts = normalized.forecasts.filter { allowedCandidateIDs.contains($0.candidateID) }
            normalized.critiques = normalized.critiques.filter { allowedCandidateIDs.contains($0.candidateID) }
            normalized.triScores = normalized.triScores.filter { allowedCandidateIDs.contains($0.candidateID) }
            findings.append(
                BASRuntimeAuditFinding(
                    code: "loop.candidate_budget_clamped",
                    layerID: "L9",
                    summary: "Candidate generation exceeded budget and was clamped to the allowed path count.",
                    severity: .medium,
                    enforced: true
                )
            )
        }

        return (normalized, findings)
    }

    func reconcileDreamLoopConvergence(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice
    ) -> BASThoughtFrame {
        guard let resolvedStopReason = derivedDreamLoopStopReason(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice
        ), resolvedStopReason != thoughtFrame.stopReason else {
            return thoughtFrame
        }

        var reconciled = thoughtFrame
        reconciled.stopReason = resolvedStopReason
        if let updatedConvergence = BASNeuralMaterializationCompiler.buildConvergenceCertificate(
            from: reconciled,
            frontier: reconciled.candidateFrontier,
            critiqueBundles: reconciled.critiqueBundles
        ) {
            reconciled.convergenceCertificate = updatedConvergence
        }
        return reconciled
    }

    func derivedDreamLoopStopReason(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice
    ) -> BASThoughtStopReason? {
        switch thoughtFrame.stopReason {
        case .maxLoopsReached, .blocked, .replaced, .guardTakeover:
            return thoughtFrame.stopReason
        case .candidateStable, .riskConverged, .uncertaintyBelowThreshold, .none:
            break
        }

        let selectedCandidateID = mergedChoice.candidateID
        if let breakpointHint = thoughtFrame.sovereignBreakpointHints?.first(where: {
            $0.affectedCandidates.contains(selectedCandidateID)
                || $0.sourceRef.hasSuffix(selectedCandidateID)
        }) {
            switch breakpointHint.suggestedAction {
            case .cut, .stop:
                return .blocked
            case .freeze, .shrink:
                break
            }
        }

        let guardPathSelected = thoughtFrame.candidateFrontier?.guardPaths.contains(selectedCandidateID) == true
        let delayedPathSelected = thoughtFrame.candidateFrontier?.delayedPaths.contains(selectedCandidateID) == true
        let weakPrediction = thoughtFrame.uncertaintyLedger?.weakPredictions.contains(selectedCandidateID) == true
        let highSensitivity = thoughtFrame.uncertaintyLedger?.highSensitivityPoints.contains(selectedCandidateID) == true
        let evidenceDebt = thoughtFrame.evidenceDebts?.first(where: { $0.candidateID == selectedCandidateID })?.debtWeight ?? 0
        let delayReserved = mergedChoice.agencyReservation?.mode == .delayRight

        if guardPathSelected && (delayedPathSelected || weakPrediction || highSensitivity || evidenceDebt >= 0.5 || delayReserved) {
            return .guardTakeover
        }

        return thoughtFrame.stopReason
    }

    func normalizeRiskDecision(
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        budget: BASBudgetFrame,
        activeKillSwitches: [BASKillSwitchID]
    ) -> (BASRiskCard, BASActionPermit, [BASRuntimeAuditFinding]) {
        var normalizedPermit = actionPermit
        var findings: [BASRuntimeAuditFinding] = []

        if activeKillSwitches.contains(.forceProtectedPermit),
           normalizedPermit.mode == .answer || normalizedPermit.mode == .compare {
            normalizedPermit = enforcedPermit(
                targetMode: .delay,
                from: normalizedPermit,
                reasonCode: "kill_switch.force_protected_permit"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "kill_switch.force_protected_permit",
                    layerID: "L11",
                    summary: "Force-protected-permit kill switch downgraded the turn into a protected output mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if riskCard.riskLevel == .extreme, normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: .block,
                from: normalizedPermit,
                reasonCode: "redline.extreme_answer_blocked"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.extreme_answer_blocked",
                    layerID: "L11",
                    summary: "Extreme-risk output was prevented from falling through to direct answer mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if riskCard.gsiScore >= 0.75, normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: .delay,
                from: normalizedPermit,
                reasonCode: "redline.gsi_delay"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.gsi_answer_downgraded",
                    layerID: "L11",
                    summary: "Elevated GSI forced the output into delay mode instead of direct answer mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if riskCard.riskLevel >= .high,
           riskCard.recommendedMode != .answer,
           normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: riskCard.recommendedMode,
                from: normalizedPermit,
                reasonCode: "redline.recommended_mode_enforced"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.recommended_mode_enforced",
                    layerID: "L11",
                    summary: "Direct answer mode was replaced with the calibrated risk-mode recommendation.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if budget.runMode == .guard, riskCard.riskLevel >= .high, normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: .delay,
                from: normalizedPermit,
                reasonCode: "redline.guarded_mode_delay"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.guarded_mode_answer_downgraded",
                    layerID: "L11",
                    summary: "Guarded mode rejected a direct answer and forced a safer output mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        return (riskCard, normalizedPermit, findings)
    }

    func projectedRiskDecisionPackage(
        from package: BASRiskDecisionPackage,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        binding: BASRiskPermitBinding? = nil
    ) -> BASRiskDecisionPackage {
        let actionModeDecision = BASActionModeDecision(
            schemaVersion: package.actionModeDecision.schemaVersion,
            decisionID: package.actionModeDecision.decisionID,
            primaryMode: actionPermit.mode,
            stackedModes: actionPermit.stackedModes,
            reasonCodes: actionPermit.reasonCodes,
            confidence: package.actionModeDecision.confidence
        )
        let delayReservation: BASDelayReservation? = if let existing = package.delayReservation {
            existing
        } else if let delayType = binding?.delayType ?? riskCard.delayType ?? actionPermit.delayWindow {
            BASDelayReservation(
                reservationID: "delay.\(package.packageID)",
                delayType: delayType,
                minDelay: actionPermit.mode == .delay ? 15 : 5,
                maxDelay: actionPermit.mode == .delay ? 1_440 : 120,
                allowedIntermediateActions: ["compare", "draft_only"]
            )
        } else {
            nil
        }
        let protectiveSubstitute = package.protectiveSubstitute ?? {
            guard actionPermit.substituteRequired || binding?.substituteType != nil || riskCard.substituteType != nil else {
                return nil
            }
            return BASProtectiveSubstitute(
                substituteID: "substitute.\(package.packageID)",
                sourceCandidateRef: package.riskField.candidateRef,
                substituteType: binding?.substituteType ?? riskCard.substituteType ?? "draft",
                description: "Use the safer, more bounded substitute path before any direct release.",
                safetyGain: riskCard.riskLevel >= .high ? 0.82 : 0.48
            )
        }()
        let sovereignEscalationHint = package.sovereignEscalationHint ?? {
            guard actionPermit.allModes.contains(.escalate)
                || binding?.sovereignHintLevel != nil
                || riskCard.sovereignHintLevel == "high" else {
                return nil
            }
            return BASSovereignEscalationHint(
                hintID: "sovereign.\(package.packageID)",
                sourceRefs: [package.riskField.fieldID],
                reasonCodes: actionPermit.reasonCodes,
                urgency: binding?.sovereignHintLevel ?? riskCard.sovereignHintLevel ?? "high",
                suggestedScope: actionPermit.blockedDomains.contains("host.write") ? "host" : "tool"
            )
        }()

        return BASRiskDecisionPackage(
            schemaVersion: package.schemaVersion,
            packageID: package.packageID,
            riskCard: riskCard,
            riskField: package.riskField,
            actionModeDecision: actionModeDecision,
            actionPermit: actionPermit,
            delayReservation: delayReservation,
            protectiveSubstitute: protectiveSubstitute,
            sovereignEscalationHint: sovereignEscalationHint
        )
    }

    func projectedRenderedOutput(
        from output: BASRenderedOutput,
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        riskDecisionPackage: BASRiskDecisionPackage?
    ) -> BASRenderedOutput {
        let prefersDraftOnly = actionPermit.mode == .draftOnly
            || actionPermit.stackedModes.contains(.draftOnly)
        let localOnlyPreferred = actionPermit.mode == .localOnly
            || actionPermit.stackedModes.contains(.localOnly)
        let delayAvailable = actionPermit.mode == .delay
            || actionPermit.stackedModes.contains(.delay)
            || actionPermit.delayWindow != nil
            || riskDecisionPackage?.delayReservation != nil
        let chooseLaterAllowed = actionPermit.requireCompare
            || delayAvailable
            || actionPermit.requireSecondCheck
            || prefersDraftOnly
            || localOnlyPreferred
            || actionPermit.mode == .replace
            || actionPermit.mode == .block
            || actionPermit.mode == .escalate
        let uncertaintyVisible = riskCard.uncertainty >= 0.35
            || output.explanationCodes.contains(where: { $0.hasPrefix("evidence.") || $0.hasPrefix("uncertainty.") })
        let agencyReservation = mergedChoice.agencyReservation
        let courtDecisionDraft = mergedChoice.courtDecisionDraft
        let remandTargets = optionalNonEmptyStrings(
            mergedChoice.remandOrders?.map(\.targetLayer) ?? []
        )

        var projected = output
        projected.surfaceGuide = BASRenderedSurfaceGuide(
            stackedModes: actionPermit.stackedModes,
            tonePolicy: actionPermit.tonePolicy,
            templatePolicy: actionPermit.templatePolicy,
            outputLengthCap: actionPermit.outputLengthCap,
            boundary: BASRenderedBoundaryGuide(
                allowedDomains: actionPermit.allowedDomains,
                blockedDomains: actionPermit.blockedDomains,
                toolScope: actionPermit.toolScope,
                memoryScope: actionPermit.memoryScope,
                escalationHintRef: actionPermit.escalationHintRef
            ),
            agency: BASRenderedAgencyGuide(
                requiresCompare: actionPermit.requireCompare,
                requiresSecondCheck: actionPermit.requireSecondCheck,
                delayAvailable: delayAvailable,
                chooseLaterAllowed: chooseLaterAllowed,
                prefersDraftOnly: prefersDraftOnly,
                localOnlyPreferred: localOnlyPreferred,
                reservationMode: agencyReservation?.mode,
                reservationReasons: optionalNonEmptyStrings(agencyReservation?.reasons ?? [])
            ),
            disclosure: BASRenderedDisclosureGuide(
                assertionCeiling: actionPermit.assertionCeiling,
                explanationCodes: output.explanationCodes,
                uncertaintyVisible: uncertaintyVisible,
                requiredDisclosures: optionalNonEmptyStrings(courtDecisionDraft?.requiredDisclosures ?? []),
                unresolvedCosts: optionalNonEmptyStrings(courtDecisionDraft?.unresolvedCosts ?? []),
                remandTargets: remandTargets
            ),
            delayWindow: actionPermit.delayWindow,
            delayReservation: riskDecisionPackage?.delayReservation,
            protectiveSubstitute: riskDecisionPackage?.protectiveSubstitute,
            sovereignEscalationHint: riskDecisionPackage?.sovereignEscalationHint
        )
        return projected
    }

    func optionalNonEmptyStrings(_ values: [String]) -> [String]? {
        let filtered = values.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        return filtered.isEmpty ? nil : filtered
    }

    func normalizeUpdateTickets(
        _ tickets: [BASUpdateTicket],
        riskCard: BASRiskCard,
        activeKillSwitches: [BASKillSwitchID]
    ) -> ([BASUpdateTicket], [BASRuntimeAuditFinding]) {
        if activeKillSwitches.contains(.requireReviewedWrites) {
            var findings: [BASRuntimeAuditFinding] = []
            let normalized = tickets.map { ticket in
                guard !ticket.requiresReview,
                      ticket.hasPersistentMutationSuggestion else {
                    return ticket
                }

                findings.append(
                    BASRuntimeAuditFinding(
                        code: "kill_switch.require_reviewed_writes",
                        layerID: "L13",
                        summary: "Require-reviewed-writes kill switch forced persistent write proposals back into review.",
                        severity: .high,
                        enforced: true
                    )
                )

                var adjusted = ticket
                adjusted.requiresReview = true
                adjusted.conflictFlag = true
                return adjusted
            }
            return (normalized, findings)
        }

        guard riskCard.riskLevel >= .high else {
            return (tickets, [])
        }

        var findings: [BASRuntimeAuditFinding] = []
        let normalized = tickets.map { ticket in
            guard !ticket.requiresReview,
                  ticket.hasPersistentMutationSuggestion else {
                return ticket
            }

            findings.append(
                BASRuntimeAuditFinding(
                    code: "evolution.high_risk_review_required",
                    layerID: "L13",
                    summary: "High-risk turns cannot propose persistent writes without review; ticket was forced into review state.",
                    severity: .high,
                    enforced: true
                )
            )

            var adjusted = ticket
            adjusted.requiresReview = true
            adjusted.conflictFlag = true
            return adjusted
        }

        return (normalized, findings)
    }
}
