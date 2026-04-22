import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — per-layer runtime trace detail composers.
// goalSpineSummary / fingerprint / neuralCoreTraceDetail / compressionRuntimeTraceDetail /
// triSelfTraceDetail / riskGateTraceDetail / dreamLoopTraceDetail / renderTraceDetail /
// evolutionTraceDetail / appendingSovereignTraceEvent.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func goalSpineSummary(
        _ goalSpineLocal: BASGoalSpineLocal
    ) -> String {
        let surface = goalSpineLocal.surfaceGoals.first ?? "none"
        let mid = goalSpineLocal.midGoals.first ?? surface
        let deep = goalSpineLocal.deepGoals.first ?? mid
        return "\(surface) -> \(mid) -> \(deep)"
    }

    func fingerprint(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    func neuralCoreTraceDetail(
        budgetFrame: BASBudgetFrame,
        thoughtFrame: BASThoughtFrame
    ) -> String {
        let organMap = thoughtFrame.organMap
        let organSummary = summarizedTokens(
            Array((organMap?.activeOrgans ?? []).map(\.rawValue).prefix(4))
        )
        let headSummary = summarizedTokens(organMap?.headGuarantees ?? [])
        let frontierWidth = thoughtFrame.candidateFrontier?.frontierWidth ?? 0
        let critiqueCount = thoughtFrame.critiqueBundles?.count ?? 0
        let bindingCount = thoughtFrame.riskBindings?.count ?? 0
        let projectionLead = thoughtFrame.candidates.first?.candidateID ?? "none"
        let projectionSummary = "projection \(projectionLead)/\(thoughtFrame.forecasts.count)/\(thoughtFrame.critiques.count)"
        let toolIntentSummary = thoughtFrame.toolIntentEnvelope.map {
            "tool intent \($0.candidateID):\($0.permitMode.rawValue)"
        } ?? "tool intent offline"
        return "Morph \(organMap?.morph.rawValue ?? "none") on \(budgetFrame.deviceRoute.rawValue) keeps \(organSummary), heads \(headSummary), frontier \(frontierWidth), critiques \(critiqueCount), bindings \(bindingCount), \(projectionSummary), \(toolIntentSummary), decode cap \(budgetFrame.maxDecodeTokens), retrieval \(budgetFrame.retrievalDepth), thermal \(budgetFrame.thermalGuardLevel.rawValue)."
    }

    func compressionRuntimeTraceDetail(
        thoughtFold: BASThoughtFold,
        thoughtFrame: BASThoughtFrame
    ) -> String {
        "ThoughtFold \(thoughtFold.foldID) checksum \(String(thoughtFold.checksum.prefix(12))) keeps \(thoughtFrame.candidates.count) candidate paths and restore pointer \(thoughtFold.restorePointer)."
    }

    func triSelfTraceDetail(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice
    ) -> String {
        let scoreCount = thoughtFrame.triScores.count
        let courtFragments = [
            mergedChoice.agencyReservation.map { "agency \($0.mode.rawValue)" },
            mergedChoice.remandOrders?.isEmpty == false
                ? "remand \(summarizedTokens(mergedChoice.remandOrders?.map(\.targetLayer) ?? []))"
                : nil
        ].compactMap { $0 }
        let courtSuffix = courtFragments.isEmpty ? "" : " with \(courtFragments.joined(separator: ", "))."
        guard mergedChoice.vetoApplied else {
            return "Merged \(scoreCount) tri-self scores and selected \(mergedChoice.candidateID) without veto\(courtSuffix)"
        }

        return "Merged \(scoreCount) tri-self scores and selected \(mergedChoice.candidateID) after veto \(summarizedTokens(mergedChoice.vetoReasonCodes))\(courtSuffix)"
    }

    func riskGateTraceDetail(
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        renderedOutput: BASRenderedOutput
    ) -> String {
        "Risk \(riskCard.riskLevel.rawValue) with GSI \(Int((riskCard.gsiScore * 100).rounded())) produced permit \(actionPermit.mode.rawValue) via \(summarizedTokens(renderedOutput.explanationCodes))."
    }

    func dreamLoopTraceDetail(
        thoughtFrame: BASThoughtFrame,
        loopCount: Int
    ) -> String {
        let stopReason = (thoughtFrame.stopReason ?? .candidateStable).rawValue
        let convergence = thoughtFrame.convergenceCertificate?.stoppingMode.rawValue ?? "none"
        let frontierWidth = thoughtFrame.candidateFrontier?.frontierWidth ?? thoughtFrame.candidates.count
        let weakPredictionCount = thoughtFrame.uncertaintyLedger?.weakPredictions.count ?? 0
        let breakpointCount = thoughtFrame.sovereignBreakpointHints?.count ?? 0
        let maxEvidenceDebt = thoughtFrame.evidenceDebts?.map(\.debtWeight).max() ?? 0
        let debtPercent = Int((maxEvidenceDebt * 100).rounded())

        return "Loop converged after \(loopCount) rounds with stop reason \(stopReason), convergence \(convergence), frontier \(frontierWidth), weak predictions \(weakPredictionCount), max debt \(debtPercent)%, breakpoints \(breakpointCount)."
    }

    func renderTraceDetail(
        renderedOutput: BASRenderedOutput,
        mergedChoice: BASMergedChoice,
        thoughtFrame: BASThoughtFrame
    ) -> String {
        let dreamLoopState = thoughtFrame.convergenceCertificate?.stoppingMode.rawValue ?? "none"
        let agencyMode = mergedChoice.agencyReservation?.mode.rawValue ?? "none"
        let disclosureCount = mergedChoice.courtDecisionDraft?.requiredDisclosures.count ?? 0
        return "Rendered \(renderedOutput.mode.rawValue) output with dream loop \(dreamLoopState), agency \(agencyMode), disclosures \(disclosureCount)."
    }

    func evolutionTraceDetail(
        updateTickets: [BASUpdateTicket],
        thoughtFrame: BASThoughtFrame
    ) -> String {
        let reviewCount = updateTickets.filter(\.requiresReview).count
        let conflictCount = updateTickets.filter(\.conflictFlag).count
        let ruleRefs = updateTickets.compactMap(\.ruleCandidateRef)
        let hostChangeTypes = updateTickets.compactMap { $0.resolvedHostChangeCandidate?.changeType }
        let dreamLoopSignals = unique(
            updateTickets
                .flatMap(\.governanceRefs)
                .filter { $0.hasPrefix("dream_loop:") }
                .map { $0.replacingOccurrences(of: "dream_loop:", with: "") }
        )
        let ruleSummary = ruleRefs.isEmpty
            ? "no rule candidates"
            : "rule refs \(summarizedTokens(ruleRefs))"
        let hostChangeSummary = hostChangeTypes.isEmpty
            ? "constitution changes 0"
            : "constitution changes \(hostChangeTypes.count) via \(summarizedTokens(hostChangeTypes))"
        let dreamLoopSummary: String
        if dreamLoopSignals.isEmpty == false {
            dreamLoopSummary = "dream loop \(summarizedTokens(dreamLoopSignals))"
        } else if let stoppingMode = thoughtFrame.convergenceCertificate?.stoppingMode.rawValue {
            dreamLoopSummary = "dream loop \(stoppingMode)"
        } else {
            dreamLoopSummary = "dream loop none"
        }

        return "Generated \(updateTickets.count) update tickets, review \(reviewCount), conflicts \(conflictCount), \(ruleSummary), \(hostChangeSummary), \(dreamLoopSummary)."
    }

    func appendingSovereignTraceEvent(
        to runtimeTrace: BASRuntimeTrace,
        commands: [BASSovereignActuationCommand],
        receipts: [BASSovereignExecutionReceipt],
        thoughtFrame: BASThoughtFrame
    ) -> BASRuntimeTrace {
        guard commands.isEmpty == false else {
            return runtimeTrace
        }

        var enrichedTrace = runtimeTrace
        let commandSummary = commands.map(\.kind.rawValue).joined(separator: ", ")
        let receiptSummary = receipts.map { "\($0.kind.rawValue):\($0.status.rawValue)" }.joined(separator: ", ")
        let toolIntentState = thoughtFrame.toolIntentEnvelope == nil ? "tool intent cut" : "tool intent retained"
        enrichedTrace.layerEvents.append(
            BASRuntimeTraceEvent(
                layerID: "L14",
                event: "sovereign",
                detail: "Sovereign executed \(commandSummary) with receipts \(receiptSummary); \(toolIntentState)."
            )
        )
        return enrichedTrace
    }

}
