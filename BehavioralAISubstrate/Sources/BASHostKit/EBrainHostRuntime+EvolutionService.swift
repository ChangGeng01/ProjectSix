import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainEvolutionService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainEvolutionService: BASEvolutionServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let hostConstitution: BASHostConstitution?

    func buildTickets(
        thoughtFrame: BASThoughtFrame,
        output: BASRenderedOutput,
        feedbackEvent: BASFeedbackEvent?
    ) -> [BASUpdateTicket] {
        let protectiveWriteSuggestion: String? = if output.mode == .answer && !currentBrain.isCalibrationUnstable {
            nil
        } else {
            "Keep this turn in review before any warm or cold promotion."
        }
        let hostChangeCandidate: BASHostChangeCandidate? = if currentBrain.calibrationStatus == .drifting {
            constitutionAlignedHostChangeCandidate(output: output)
        } else {
            nil
        }
        let courtDecisionDraft = thoughtFrame.courtDecisionDraft
        return [
            BASUpdateTicket(
                ticketID: "ticket.\(UUID().uuidString.lowercased())",
                sessionRef: "\(request.kind.rawValue).\(request.workflowProfile.rawValue)",
                summary: output.body,
                memoryWriteSuggestion: protectiveWriteSuggestion,
                hostChangeCandidate: hostChangeCandidate,
                ruleCandidateRef: output.mode == .block ? "rule.protective_block" : nil,
                derivedCandidateRefs: derivedCandidateRefs(from: courtDecisionDraft),
                governanceRefs: governanceRefs(
                    thoughtFrame: thoughtFrame,
                    courtDecisionDraft: courtDecisionDraft
                ),
                confidence: output.mode == .answer ? 0.62 : 0.80,
                conflictFlag: output.mode == .block || output.mode == .replace,
                requiresReview: true
            )
        ]
    }

    private func derivedCandidateRefs(
        from courtDecisionDraft: BASCourtDecisionDraft?
    ) -> [String] {
        guard let courtDecisionDraft else { return [] }
        return orderedUnique(
            [courtDecisionDraft.preferredCandidateID] + courtDecisionDraft.fallbackCandidateIDs
        )
    }

    private func governanceRefs(
        thoughtFrame: BASThoughtFrame,
        courtDecisionDraft: BASCourtDecisionDraft?
    ) -> [String] {
        var refs: [String] = []

        if let reservationMode = thoughtFrame.agencyReservation?.mode {
            refs.append("agency:\(reservationMode.rawValue)")
        }

        refs.append(contentsOf: (thoughtFrame.remandOrders ?? []).map { "remand:\($0.targetLayer)" })

        if let readinessLevel = courtDecisionDraft?.readinessLevel.trimmingCharacters(in: .whitespacesAndNewlines),
           !readinessLevel.isEmpty {
            refs.append("court:\(readinessLevel)")
        }

        refs.append(
            contentsOf: (thoughtFrame.vetoMarks ?? []).map {
                "veto:\($0.candidateID):\($0.vetoType.rawValue)"
            }
        )

        if let stoppingMode = thoughtFrame.convergenceCertificate?.stoppingMode {
            refs.append("dream_loop:\(stoppingMode.rawValue)")
        }
        if thoughtFrame.uncertaintyLedger?.weakPredictions.isEmpty == false {
            refs.append("dream_loop:weak_prediction")
        }
        if let maxEvidenceDebt = thoughtFrame.evidenceDebts?.map(\.debtWeight).max(),
           maxEvidenceDebt >= 0.5 {
            refs.append("dream_loop:evidence_debt")
        }
        if thoughtFrame.sovereignBreakpointHints?.isEmpty == false {
            refs.append("dream_loop:breakpoint")
        }
        if thoughtFrame.candidateFrontier?.delayedPaths.isEmpty == false {
            refs.append("dream_loop:delay_branch")
        }

        if let guardCandidateID = courtDecisionDraft?.guardCandidateID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !guardCandidateID.isEmpty {
            refs.append("guard:\(guardCandidateID)")
        }

        return orderedUnique(refs)
    }

    private func constitutionAlignedHostChangeCandidate(
        output: BASRenderedOutput
    ) -> BASHostChangeCandidate {
        guard let hostConstitution else {
            return BASHostChangeCandidate(
                candidateID: "candidate.\(UUID().uuidString.lowercased())",
                changeType: "review_host_gate_strength",
                proposedDelta: ["host_gate_strength"],
                evidenceRefs: ["calibration:drifting", "mode:\(output.mode.rawValue)"],
                cooldownUntil: .now.addingTimeInterval(1_800),
                confidence: output.mode == .answer ? 0.68 : 0.82,
                conflictRefs: output.explanationCodes,
                previewState: "review_only",
                approvalState: "pending"
            )
        }

        var proposedDelta: [String] = []
        var evidenceRefs = [
            "calibration:drifting",
            "mode:\(output.mode.rawValue)",
            "constitution:\(hostConstitution.activeVersion)"
        ]

        if let phase = firstNonEmptyOptional(
            hostConstitution.goalSpine.stageState,
            hostConstitution.narrativeLoom.currentPhase
        ) {
            evidenceRefs.append("phase:\(phase)")
        }

        if let goal = firstNonEmptyOptional(
            hostConstitution.goalSpine.priorityOrder.first,
            hostConstitution.goalSpine.goals.first
        ) {
            proposedDelta.append("goal_spine")
            evidenceRefs.append("goal:\(goal)")
        }

        if let confirmRequired = hostConstitution.boundaryVeil.confirmRequired.first,
           !confirmRequired.isEmpty {
            proposedDelta.append("boundary_veil")
            evidenceRefs.append("confirm_required:\(confirmRequired)")
        } else if hostConstitution.boundaryVeil.hardNoGo.isEmpty == false {
            proposedDelta.append("boundary_veil")
            evidenceRefs.append("hard_no_go:\(hostConstitution.boundaryVeil.hardNoGo[0])")
        }

        if let mutationScope = firstNonEmptyOptional(
            hostConstitution.consentLattice.hostMutationScope,
            hostConstitution.consentLattice.toolWriteScope
        ) {
            proposedDelta.append("consent_lattice")
            let scopeKey = hostConstitution.consentLattice.hostMutationScope
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty ? "tool_write_scope" : "host_mutation_scope"
            evidenceRefs.append("\(scopeKey):\(mutationScope)")
        }

        if proposedDelta.isEmpty {
            proposedDelta = ["host_gate_strength"]
        }

        return BASHostChangeCandidate(
            candidateID: "candidate.\(UUID().uuidString.lowercased())",
            changeType: "review_constitution_alignment",
            proposedDelta: orderedUnique(proposedDelta),
            evidenceRefs: orderedUnique(evidenceRefs),
            cooldownUntil: .now.addingTimeInterval(1_800),
            confidence: output.mode == .answer ? 0.72 : 0.84,
            conflictRefs: output.explanationCodes,
            previewState: "review_only",
            approvalState: "pending"
        )
    }

    private func firstNonEmptyOptional(_ values: String?...) -> String? {
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
