import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — evolution governance artifact builder.
// buildEvolutionGovernanceArtifacts — the L13 nursery+shadow+seal+retraction orchestration.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    struct BASEvolutionGovernanceArtifacts {
        let updateTickets: [BASUpdateTicket]
        let experienceCandidates: [BASExperienceCandidate]
        let workflowCandidates: [BASWorkflowCandidate]
        let guardTemplateCandidates: [BASGuardTemplateCandidate]
        let biasRecords: [BASBiasRecord]
        let riskPatternCandidates: [BASRiskPatternCandidate]
        let learningExportBundles: [BASLearningExportBundle]
        let shadowTrialRecords: [BASShadowTrialRecord]
        let versionDeltas: [BASVersionDelta]
        let retractionOrders: [BASRetractionOrder]
        let evolutionSeals: [BASEvolutionSeal]
    }

    /// audit M-k F4: a per-turn-unique, DETERMINISTIC token for evolution-artifact IDs. Two distinct
    /// turns in the same wall-clock SECOND must not collide (the old `Int(timeIntervalSince1970)`
    /// did), and a replay of the same turn must reproduce the same token. There is no per-turn ID
    /// field on the request/frames to reuse, so hash the turn's full distinguishing inputs
    /// (full-precision timestamp + input + host) — a 12-hex-char prefix is ample to separate turns.
    static func evolutionTurnToken(_ request: BASEBrainTurnRequest) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(String(request.recordedAt.timeIntervalSince1970).utf8))
        hasher.update(data: Data(request.userInput.utf8))
        hasher.update(data: Data(request.hostID.utf8))
        return hasher.finalize().prefix(6).map { String(format: "%02x", $0) }.joined()
    }

    func buildEvolutionGovernanceArtifacts(
        request: BASEBrainTurnRequest,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        thoughtFrame: BASThoughtFrame,
        output: BASRenderedOutput,
        riskCard: BASRiskCard,
        updateTickets: [BASUpdateTicket]
    ) -> BASEvolutionGovernanceArtifacts {
        let requiresGovernedTrial = riskCard.riskLevel >= .high
            || updateTickets.contains(where: {
                $0.conflictFlag
                    || $0.resolvedHostChangeCandidate != nil
                    || $0.ruleCandidateRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            })
        // audit M-k F4: was Int(request.recordedAt.timeIntervalSince1970) = WHOLE-SECOND
        // granularity, so two turns in the same wall-clock second reused exp./trial./retract.
        // <sec>.<index> keys → a retraction could target the WRONG turn's candidate. Derive a
        // per-turn-UNIQUE yet DETERMINISTIC token from the turn's full distinguishing inputs
        // (full-precision timestamp + input + host), so same-second turns get distinct IDs while a
        // replay of the same turn reproduces the same ID.
        let turnToken = Self.evolutionTurnToken(request)
        let trialScope = thoughtFrame.stopReason?.rawValue ?? output.mode.rawValue
        let lowOrMediumRisk = riskCard.riskLevel == .low || riskCard.riskLevel == .medium
        let isProtectiveMode = output.mode == .delay || output.mode == .block || output.mode == .replace
        let hasConflictPressure = updateTickets.contains(where: \.conflictFlag)
        let hasAmbientGuardSignals = contextFrame.manipulationHints.isEmpty == false
            || decomposeFrame.boundaryTouches.isEmpty == false
            || contextFrame.routeHint?.needGuard == true
        let hasGuardSignals = hasAmbientGuardSignals || isProtectiveMode
        let hasRiskPatternSignals = contextFrame.manipulationHints.isEmpty == false
            || (thoughtFrame.riskDecisionPackage?.sovereignEscalationHint != nil)
            || (thoughtFrame.riskDecisionPackage?.actionPermit.blockedDomains.isEmpty == false)
            || (thoughtFrame.actionPermit?.blockedDomains.isEmpty == false)

        var experienceCandidates: [BASExperienceCandidate] = []
        var workflowCandidates: [BASWorkflowCandidate] = []
        var guardTemplateCandidates: [BASGuardTemplateCandidate] = []
        var biasRecords: [BASBiasRecord] = []
        var riskPatternCandidates: [BASRiskPatternCandidate] = []
        var learningExportBundles: [BASLearningExportBundle] = []
        var shadowTrialRecords: [BASShadowTrialRecord] = []
        var versionDeltas: [BASVersionDelta] = []
        var retractionOrders: [BASRetractionOrder] = []
        var evolutionSeals: [BASEvolutionSeal] = []

        let governedTickets = updateTickets.enumerated().map { index, ticket in
            let resolvedHostChangeCandidate = ticket.resolvedHostChangeCandidate
            let candidateType: BASExperienceCandidateType = {
                if resolvedHostChangeCandidate != nil {
                    return .host
                }
                if ticket.ruleCandidateRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    return .rule
                }
                if ticket.conflictFlag {
                    return .failure
                }
                if ticket.memoryWriteSuggestion?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    return .guardPattern
                }
                return .success
            }()

            let candidateID = "exp.\(turnToken).\(index)"
            experienceCandidates.append(
                BASExperienceCandidate(
                    candidateID: candidateID,
                    sourceRefs: [ticket.ticketID, ticket.sessionRef],
                    candidateType: candidateType,
                    summary: ticket.summary,
                    stabilitySignal: requiresGovernedTrial ? 0.54 : 0.82,
                    contaminationRisk: requiresGovernedTrial ? 0.44 : 0.12,
                    hostScope: request.hostID,
                    sovereignScope: requiresGovernedTrial ? "l14_review_required" : "l14_clear"
                )
            )

            var governanceRefs: [String] = []
            let needsTrial = requiresGovernedTrial && candidateType != .success

            if needsTrial {
                let trialID = "trial.\(turnToken).\(index)"
                let trialScopeMode: String = {
                    if resolvedHostChangeCandidate != nil {
                        return "host_preview:\(output.mode.rawValue)"
                    }
                    if ticket.ruleCandidateRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        return "compare_only:\(output.mode.rawValue)"
                    }
                    if isProtectiveMode {
                        return "single_domain:\(output.mode.rawValue)"
                    }
                    return "draft_only:\(output.mode.rawValue)"
                }()
                let trialCompletionState: String
                let promotionRecommendation: String?
                let observedEffects: [String]
                let failConditions: [String]
                let trialEndAt: Date?

                if resolvedHostChangeCandidate != nil {
                    trialCompletionState = "pending"
                    promotionRecommendation = nil
                    observedEffects = []
                    failConditions = ["host_gate_regression", "scope_expansion", "preview_mismatch"]
                    trialEndAt = nil
                } else if (isProtectiveMode || riskCard.riskLevel >= .high) && hasGuardSignals {
                    trialCompletionState = "passed"
                    promotionRecommendation = "eligible_with_seal_review"
                    observedEffects = [
                        "protective mode \(output.mode.rawValue) held",
                        "bounded trial stayed inside \(request.hostID)"
                    ]
                    failConditions = ["host_gate_regression", "scope_expansion"]
                    trialEndAt = request.recordedAt
                } else if hasConflictPressure {
                    trialCompletionState = "failed"
                    promotionRecommendation = "reject"
                    observedEffects = ["conflict pressure persisted through bounded trial"]
                    failConditions = ["review_conflict", "boundary_regression"]
                    trialEndAt = request.recordedAt
                } else {
                    trialCompletionState = "pending"
                    promotionRecommendation = nil
                    observedEffects = []
                    failConditions = ["host_gate_regression", "sovereign_scope_expansion"]
                    trialEndAt = nil
                }

                shadowTrialRecords.append(
                    BASShadowTrialRecord(
                        trialID: trialID,
                        candidateRef: candidateID,
                        trialScope: trialScopeMode,
                        startAt: request.recordedAt,
                        endAt: trialEndAt,
                        observedEffects: observedEffects,
                        failConditions: failConditions,
                        promotionRecommendation: promotionRecommendation,
                        completionState: trialCompletionState
                    )
                )
                governanceRefs.append(trialID)
            }

            if resolvedHostChangeCandidate != nil
                || ticket.ruleCandidateRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                || needsTrial {
                let deltaID = "delta.\(turnToken).\(index)"
                let rollbackRef = resolvedHostChangeCandidate?.rollbackRef
                    ?? (ticket.ruleCandidateRef.map { "rollback.\($0)" })
                versionDeltas.append(
                    BASVersionDelta(
                        deltaID: deltaID,
                        targetType: resolvedHostChangeCandidate != nil ? "host" : "rule",
                        beforeRef: resolvedHostChangeCandidate?.hostVersionRef,
                        afterRef: resolvedHostChangeCandidate?.candidateID ?? ticket.ruleCandidateRef ?? candidateID,
                        reason: ticket.reviewDirectiveLine ?? ticket.summary,
                        impactScope: output.mode.rawValue,
                        rollbackRef: rollbackRef
                    )
                )
                governanceRefs.append(deltaID)
            }

            if needsTrial || ticket.conflictFlag {
                let trialState = shadowTrialRecords.last?.completionState
                let orderID = "retract.\(turnToken).\(index)"
                retractionOrders.append(
                    BASRetractionOrder(
                        orderID: orderID,
                        targetRefs: [ticket.ticketID, candidateID],
                        cascadeRefs: ticket.ruleCandidateRef.map { [$0] } ?? [],
                        reasonCodes: {
                            if trialState == "failed" {
                                return ["shadow_trial_failed", "cleanup_before_retain"]
                            }
                            if trialState == "passed" {
                                return ["seal_review"]
                            }
                            return ticket.conflictFlag
                                ? ["review_conflict", "await_shadow_trial"]
                                : ["await_shadow_trial"]
                        }(),
                        executionState: trialState == "passed" ? "cleared" : "pending_cleanup"
                    )
                )
                governanceRefs.append(orderID)
            }

            let sealID = "seal.\(turnToken).\(index)"
            let latestTrialState = shadowTrialRecords.last?.completionState
            evolutionSeals.append(
                BASEvolutionSeal(
                    sealID: sealID,
                    candidateRef: candidateID,
                    allowedScope: request.hostID,
                    trialRequired: needsTrial,
                    approvalRequirements: {
                        guard needsTrial else { return ["lineage_recorded"] }
                        switch latestTrialState {
                        case "passed":
                            return ["trial_passed", "l14_review"]
                        case "failed":
                            return ["shadow_trial_failed", "cleanup_before_retain"]
                        default:
                            return ["shadow_trial", "l14_review"]
                        }
                    }(),
                    signature: {
                        guard needsTrial else { return "l14.bridge.sealed" }
                        switch latestTrialState {
                        case "passed":
                            return "l14.bridge.awaiting_review"
                        case "failed":
                            return "l14.bridge.denied"
                        default:
                            return "l14.bridge.pending"
                        }
                    }(),
                    approvalState: {
                        guard needsTrial else { return "sealed" }
                        switch latestTrialState {
                        case "passed":
                            return "pending_review"
                        case "failed":
                            return "denied"
                        default:
                            return "pending_review"
                        }
                    }()
                )
            )
            governanceRefs.append(sealID)

            var adjusted = ticket
            adjusted.derivedCandidateRefs = Array(
                ([ticket.derivedCandidateRefs, [candidateID]])
                    .flatMap { $0 }
                    .runtimeOrderedUniqueStrings()
            )
            adjusted.governanceRefs = Array(
                ([ticket.governanceRefs, governanceRefs])
                    .flatMap { $0 }
                    .runtimeOrderedUniqueStrings()
            )
            if var hostChangeCandidate = adjusted.resolvedHostChangeCandidate {
                if hostChangeCandidate.hostVersionRef == nil {
                    hostChangeCandidate.hostVersionRef = "host.\(request.hostID).candidate"
                }
                if hostChangeCandidate.rollbackRef == nil {
                    hostChangeCandidate.rollbackRef = "rollback.\(hostChangeCandidate.candidateID)"
                }
                adjusted.hostChangeCandidate = hostChangeCandidate
            }
            return adjusted
        }

        let passedShadowTrialCount = shadowTrialRecords.filter(\.isPassed).count
        let failedShadowTrialCount = shadowTrialRecords.filter(\.isFailed).count
        let pendingShadowTrialCount = shadowTrialRecords.filter(\.isPending).count
        let deniedSealCount = evolutionSeals.filter(\.isDenied).count
        let pendingSealCount = evolutionSeals.filter(\.isPending).count
        let pendingRetractionCount = retractionOrders.filter {
            $0.executionState != "completed" && $0.executionState != "cleared"
        }.count
        let hasReusablePath = output.alternativeActions.isEmpty == false
            || output.mode == .compare
            || output.mode == .answer
        let candidateRefs = experienceCandidates.map(\.candidateID)
        let gateClean = pendingShadowTrialCount == 0
            && failedShadowTrialCount == 0
            && pendingSealCount == 0
            && deniedSealCount == 0
            && pendingRetractionCount == 0

        if lowOrMediumRisk && hasConflictPressure == false && hasReusablePath {
            workflowCandidates.append(
                BASWorkflowCandidate(
                    workflowID: "workflow.\(turnToken).0",
                    taskDomain: output.mode.rawValue,
                    steps: output.alternativeActions.isEmpty ? ["observe", output.mode.rawValue, "review"] : output.alternativeActions,
                    observedGain: 0.74,
                    safetyNotes: ["governed nursery candidate"],
                    hostSpecific: true,
                    shadowTrialState: pendingShadowTrialCount > 0 ? "pending" : (failedShadowTrialCount > 0 ? "failed" : (passedShadowTrialCount > 0 ? "passed" : "not_required"))
                )
            )
        }

        if (isProtectiveMode && hasAmbientGuardSignals) || (riskCard.riskLevel >= .high && hasGuardSignals) {
            guardTemplateCandidates.append(
                BASGuardTemplateCandidate(
                    templateID: "guard.\(turnToken).0",
                    sceneType: contextFrame.sceneType.rawValue,
                    boundaryScriptRef: decomposeFrame.boundaryTouches.isEmpty ? nil : "boundary.\(contextFrame.sceneType.rawValue)",
                    delayPacketRef: output.mode == .delay ? "delay.\(trialScope)" : nil,
                    substituteRef: isProtectiveMode ? "substitute.\(output.mode.rawValue)" : nil,
                    protectiveGain: isProtectiveMode ? 0.82 : 0.61,
                    overreachRisk: hasConflictPressure ? 0.42 : 0.18
                )
            )
        }

        if hasConflictPressure || pendingRetractionCount > 0 || pendingShadowTrialCount > 0 {
            biasRecords.append(
                BASBiasRecord(
                    biasID: "bias.\(turnToken).0",
                    biasType: hasConflictPressure ? "review_conflict" : "guard_drift_watch",
                    sourceRefs: governedTickets.map(\.ticketID),
                    severity: hasConflictPressure ? 0.72 : 0.54,
                    recurrenceScore: pendingRetractionCount > 0 ? 0.68 : 0.43,
                    affectedLayers: ["L11", "L12", "L13"]
                )
            )
        }

        if riskCard.riskLevel >= .high || ((isProtectiveMode && hasAmbientGuardSignals) && hasRiskPatternSignals) {
            riskPatternCandidates.append(
                BASRiskPatternCandidate(
                    patternID: "risk.\(turnToken).0",
                    sourceRefs: governedTickets.map(\.ticketID),
                    riskDomain: contextFrame.sceneType.rawValue,
                    triggerSignals: Array((contextFrame.manipulationHints + output.explanationCodes).prefix(4)),
                    severity: riskCard.totalRisk,
                    recurrenceScore: hasConflictPressure ? 0.63 : 0.41,
                    sovereignReviewRequired: riskCard.riskLevel >= .high,
                    shadowTrialState: pendingShadowTrialCount > 0 ? "pending" : (failedShadowTrialCount > 0 ? "failed" : (passedShadowTrialCount > 0 ? "passed" : "not_required"))
                )
            )
        }

        if gateClean && candidateRefs.isEmpty == false {
            learningExportBundles.append(
                BASLearningExportBundle(
                    bundleID: "export.\(turnToken).0",
                    candidateRefs: candidateRefs,
                    scrubbed: true,
                    privacySafe: true,
                    sovereignSafe: true,
                    evaluationTags: ["l13", "nursery", output.mode.rawValue]
                )
            )
        }

        return BASEvolutionGovernanceArtifacts(
            updateTickets: governedTickets,
            experienceCandidates: experienceCandidates,
            workflowCandidates: workflowCandidates,
            guardTemplateCandidates: guardTemplateCandidates,
            biasRecords: biasRecords,
            riskPatternCandidates: riskPatternCandidates,
            learningExportBundles: learningExportBundles,
            shadowTrialRecords: shadowTrialRecords,
            versionDeltas: versionDeltas,
            retractionOrders: retractionOrders,
            evolutionSeals: evolutionSeals
        )
    }

}
