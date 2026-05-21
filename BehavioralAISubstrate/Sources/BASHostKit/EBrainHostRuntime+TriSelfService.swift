import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainTriSelfService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainTriSelfService: BASTriSelfServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let hostConstitution: BASHostConstitution?

    func mergeChoice(
        thoughtFrame: BASThoughtFrame,
        hostContext: BASHostProfile
    ) -> ([BASTriSelfScore], BASMergedChoice) {
        let triSelfTuning = tuning.triSelf
        let evaluatedScores = thoughtFrame.candidates.map { candidate -> (score: BASTriSelfScore, vetoReasonCodes: [String]) in
            let initiativeLift = currentBrain.identityInitiative == .assertive ? triSelfTuning.assertiveInitiativeLift : 0
            let candidateEvidenceDebt = self.evidenceDebt(
                for: candidate.candidateID,
                in: thoughtFrame
            )?.debtWeight ?? 0
            let candidateConfidenceFloor = min(
                candidate.confidence,
                thoughtFrame.uncertaintyLedger?.confidenceFloor ?? candidate.confidence
            )
            let idScore = candidate.expectedBenefit
                - candidate.expectedCost * triSelfTuning.idCostWeight
                + initiativeLift
                + constitutionCandidateBoost(for: candidate)
                - candidateEvidenceDebt * 0.12
            let egoScore = candidate.reversibility * triSelfTuning.egoReversibilityWeight
                + min(candidateConfidenceFloor, currentBrain.confidenceCeiling) * triSelfTuning.egoConfidenceWeight
            let superegoPenalty = candidate.candidateID == "path.direct" && (request.riskLevel == .high || currentBrain.hasProtectiveBoundary)
                ? triSelfTuning.directPathSuperegoPenalty
                : 0
            let superegoScore = max(
                0,
                candidate.reversibility
                    - superegoPenalty
                    - constitutionSuperegoPenalty(for: candidate)
                    - candidateEvidenceDebt * 0.18
                    - self.sovereignBreakpointPenalty(for: candidate.candidateID, in: thoughtFrame)
            )
            let candidateVetoReasonCodes = vetoReasonCodes(
                for: candidate,
                thoughtFrame: thoughtFrame
            )
            let postureWeights: BASEBrainRuntimeSynthesisPolicy.TriSelfWeightProfile = switch currentBrain.identityPosture {
            case .reflective:
                triSelfTuning.reflectiveWeights
            case .coaching:
                triSelfTuning.coachingWeights
            case .protective:
                triSelfTuning.protectiveWeights
            }
            let mergedScore = max(
                0,
                (idScore * postureWeights.id)
                    + (egoScore * postureWeights.ego)
                    + (superegoScore * postureWeights.superego)
            )
            let score = BASTriSelfScore(
                candidateID: candidate.candidateID,
                idScore: idScore,
                egoScore: egoScore,
                superegoScore: superegoScore,
                mergedScore: mergedScore,
                veto: !candidateVetoReasonCodes.isEmpty
            )
            return (score, candidateVetoReasonCodes)
        }

        let scores = evaluatedScores.map { $0.score }
        let aggregatedVetoReasonCodes = unique(
            evaluatedScores
                .filter { $0.score.veto }
                .flatMap { $0.vetoReasonCodes }
        )
        let nonVetoScores = scores.filter { !$0.veto }
        let selectedScore: BASTriSelfScore?
        if let preferredScore = nonVetoScores.max(by: isLowerMergedScore(_:_:)) {
            selectedScore = preferredScore
        } else {
            selectedScore = scores.max(by: isLowerMergedScore(_:_:))
        }

        let selectedCandidate = thoughtFrame.candidates.first {
            $0.candidateID == selectedScore?.candidateID
        } ?? thoughtFrame.candidates.first ?? BASCandidatePath(
            candidateID: "path.empty",
            title: "No candidate available",
            actionSummary: "Keep the turn bounded until a valid candidate exists.",
            expectedBenefit: 0,
            expectedCost: 0,
            reversibility: 1,
            confidence: 0
        )
        let tradeoffLedgers = thoughtFrame.candidates.map {
            tradeoffLedger(for: $0, thoughtFrame: thoughtFrame)
        }
        let vetoMarks = evaluatedScores.compactMap { evaluated -> BASVetoMark? in
            guard evaluated.vetoReasonCodes.isEmpty == false else { return nil }
            return BASVetoMark(
                candidateID: evaluated.score.candidateID,
                vetoType: inferredVetoType(for: evaluated.vetoReasonCodes),
                reasonCodes: evaluated.vetoReasonCodes,
                compensable: false
            )
        }
        let agencyReservation = buildAgencyReservation(
            selectedCandidate: selectedCandidate,
            scores: scores,
            thoughtFrame: thoughtFrame
        )
        let remandOrders = self.buildRemandOrders(
            selectedCandidate: selectedCandidate,
            thoughtFrame: thoughtFrame,
            vetoMarks: vetoMarks
        )
        let courtDecisionDraft = self.buildCourtDecisionDraft(
            selectedCandidate: selectedCandidate,
            scores: scores,
            tradeoffLedgers: tradeoffLedgers,
            agencyReservation: agencyReservation,
            remandOrders: remandOrders,
            thoughtFrame: thoughtFrame
        )

        let mergedChoice = BASMergedChoice(
            candidateID: selectedCandidate.candidateID,
            title: selectedCandidate.title,
            actionSummary: selectedCandidate.actionSummary,
            vetoApplied: !aggregatedVetoReasonCodes.isEmpty,
            vetoReasonCodes: aggregatedVetoReasonCodes,
            vetoMarks: vetoMarks.isEmpty ? nil : vetoMarks,
            tradeoffLedgers: tradeoffLedgers,
            agencyReservation: agencyReservation,
            remandOrders: remandOrders.isEmpty ? nil : remandOrders,
            courtDecisionDraft: courtDecisionDraft
        )

        return (scores, mergedChoice)
    }

    private func tradeoffLedger(
        for candidate: BASCandidatePath,
        thoughtFrame: BASThoughtFrame
    ) -> BASTradeoffLedger {
        let forecast = thoughtFrame.forecasts.first { $0.candidateID == candidate.candidateID }
        let critiques = thoughtFrame.critiques.filter { $0.candidateID == candidate.candidateID }
        var gains = [candidate.actionSummary]
        if candidate.reversibility >= 0.8 {
            gains.append("Keeps the next step reversible.")
        }
        if candidate.expectedBenefit >= 0.75 {
            gains.append("Answers a live need with stronger immediate relief.")
        }

        var costs: [String] = []
        if candidate.expectedCost >= 0.5 {
            costs.append("Carries a visibly higher immediate cost.")
        } else if candidate.expectedCost >= 0.25 {
            costs.append("Adds friction before closure.")
        }
        if let forecast, forecast.uncertainty >= 0.5 {
            costs.append("The forecast is still unstable.")
        }

        let sacrifices = sacrifices(for: candidate)
        let evidenceDebtTensions = self.evidenceDebt(
            for: candidate.candidateID,
            in: thoughtFrame
        )?.missingEvidence ?? []
        let critiqueTensions = critiques.map(\.critiqueText) + critiqueUnresolvedTensions(from: critiques)
        let forecastTensions = forecastUnresolvedTensions(forecast)
        let uncertaintyIssues = self.uncertaintyTensions(
            for: candidate.candidateID,
            in: thoughtFrame
        )
        let unresolvedTensions = unique(
            candidate.requiredEvidence
                + evidenceDebtTensions
                + critiqueTensions
                + forecastTensions
                + uncertaintyIssues
        )

        return BASTradeoffLedger(
            candidateID: candidate.candidateID,
            gains: unique(gains),
            costs: unique(costs),
            sacrifices: sacrifices,
            unresolvedTensions: unresolvedTensions
        )
    }

    private func vetoReasonCodes(
        for candidate: BASCandidatePath,
        thoughtFrame: BASThoughtFrame
    ) -> [String] {
        var reasons: [String] = []
        if candidate.candidateID == "path.direct", request.riskLevel == .high {
            reasons.append("triself.high_risk_direct_path")
        }
        if candidate.candidateID == "path.direct", currentBrain.hasProtectiveBoundary {
            reasons.append("triself.protective_boundary")
        }
        if candidate.candidateID == "path.direct", currentBrain.calibrationStatus == .drifting {
            reasons.append("triself.calibration_drifting")
        }
        if let breakpointHint = self.sovereignBreakpointHint(for: candidate.candidateID, in: thoughtFrame) {
            switch breakpointHint.suggestedAction {
            case .cut:
                reasons.append("triself.sovereign_breakpoint_cut")
            case .stop:
                reasons.append("triself.sovereign_breakpoint_stop")
            case .freeze, .shrink:
                break
            }
        }

        guard !reasons.isEmpty else { return [] }
        return ["triself.superego_veto"] + reasons
    }

    private func inferredVetoType(
        for reasonCodes: [String]
    ) -> BASCourtVetoType {
        if reasonCodes.contains("triself.protective_boundary")
            || reasonCodes.contains("triself.superego_veto") {
            return .boundary
        }
        if reasonCodes.contains("triself.high_risk_direct_path") {
            return .irreversibility
        }
        if reasonCodes.contains("triself.calibration_drifting") {
            return .calibration
        }
        return .boundary
    }

    private func buildAgencyReservation(
        selectedCandidate: BASCandidatePath,
        scores: [BASTriSelfScore],
        thoughtFrame: BASThoughtFrame
    ) -> BASAgencyReservation? {
        if let convergence = thoughtFrame.convergenceCertificate {
            switch convergence.stoppingMode {
            case .leaseEnd:
                return BASAgencyReservation(
                    mode: .noAutoMerge,
                    reasons: ["The dream loop lease ended before the leading path stabilized enough for auto-merge."],
                    expiresWith: "fresh_lease"
                )
            case .sovereignCut:
                return BASAgencyReservation(
                    mode: .noAutoMerge,
                    reasons: ["A sovereign breakpoint invalidated the leading path before merge."],
                    expiresWith: "sovereign_clearance"
                )
            case .guardTakeover:
                return BASAgencyReservation(
                    mode: .delayRight,
                    reasons: ["The guard branch has taken over, so the final decision should stay reversible."],
                    expiresWith: "guard_release"
                )
            case .converged:
                break
            }
        }

        // chapter 八百四十 / M2852 — sort routed to Rust per
        // chapter 837 STRONG-FLIP framework。 Swift body kept as
        // FALLBACK per 「依旧 不删除 只 comment」。
        let filtered = scores.filter { !$0.veto }
        let viableScores: [BASTriSelfScore] = {
            let scoreValues: [Float] = filtered.map {
                Float($0.mergedScore)
            }
            if let indices = BASAutoRouteRanker
                .dreamLoopDominanceOrder(scores: scoreValues) {
                return indices.compactMap { idx -> BASTriSelfScore? in
                    let i = Int(idx)
                    guard i >= 0, i < filtered.count else {
                        return nil
                    }
                    return filtered[i]
                }
            }
            // Swift legacy fallback
            return filtered.sorted {
                $0.mergedScore > $1.mergedScore
            }
        }()
        guard viableScores.isEmpty == false else { return nil }

        let selectedForecast = thoughtFrame.forecasts.first {
            $0.candidateID == selectedCandidate.candidateID
        }
        let selectedEvidenceDebt = self.evidenceDebt(for: selectedCandidate.candidateID, in: thoughtFrame)
        let delayedByFrontier = thoughtFrame.candidateFrontier?.delayedPaths.contains(selectedCandidate.candidateID) == true
        let weakPrediction = thoughtFrame.uncertaintyLedger?.weakPredictions.contains(selectedCandidate.candidateID) == true
        let lowConfidenceFloor = (thoughtFrame.uncertaintyLedger?.confidenceFloor ?? 1) < 0.60

        if delayedByFrontier || weakPrediction || lowConfidenceFloor || (selectedEvidenceDebt?.debtWeight ?? 0) >= 0.5 {
            var reasons = ["The leading path still carries dream-loop uncertainty or evidence debt."]
            if delayedByFrontier {
                reasons.append("The candidate frontier still prefers a delayed branch for this path.")
            }
            if weakPrediction {
                reasons.append("The uncertainty ledger still marks this path as a weak prediction.")
            }
            if (selectedEvidenceDebt?.debtWeight ?? 0) >= 0.5 {
                reasons.append("The evidence debt for the lead path is still too high for auto-merge.")
            }
            if lowConfidenceFloor {
                reasons.append("The loop confidence floor is still low.")
            }
            return BASAgencyReservation(
                mode: .delayRight,
                reasons: unique(reasons),
                expiresWith: "evidence_refresh"
            )
        }
        if request.riskLevel == .high || selectedCandidate.requiredEvidence.isEmpty == false {
            var reasons = [
                "Multiple legal paths remain and one more fact is still missing."
            ]
            if selectedForecast?.uncertainty ?? 0 >= 0.5 {
                reasons.append("The current lead path still carries unstable forecast confidence.")
            }
            return BASAgencyReservation(
                mode: .delayRight,
                reasons: unique(reasons),
                expiresWith: "evidence_refresh"
            )
        }

        guard viableScores.count >= 2 else { return nil }
        let scoreGap = viableScores[0].mergedScore - viableScores[1].mergedScore
        guard scoreGap <= 0.14 else { return nil }

        return BASAgencyReservation(
            mode: .compareOnly,
            reasons: [
                "The top two legal paths are still close enough that the host should compare them directly."
            ],
            expiresWith: "host_choice"
        )
    }

    private func buildRemandOrders(
        selectedCandidate: BASCandidatePath,
        thoughtFrame: BASThoughtFrame,
        vetoMarks: [BASVetoMark]
    ) -> [BASRemandOrder] {
        let selectedForecast = thoughtFrame.forecasts.first {
            $0.candidateID == selectedCandidate.candidateID
        }
        let selectedCritiques = thoughtFrame.critiques.filter {
            $0.candidateID == selectedCandidate.candidateID
        }
        let selectedEvidenceDebt = self.evidenceDebt(for: selectedCandidate.candidateID, in: thoughtFrame)
        let selectedBreakpointHint = self.sovereignBreakpointHint(for: selectedCandidate.candidateID, in: thoughtFrame)
        let weakPrediction = thoughtFrame.uncertaintyLedger?.weakPredictions.contains(selectedCandidate.candidateID) == true
        let delayedByFrontier = thoughtFrame.candidateFrontier?.delayedPaths.contains(selectedCandidate.candidateID) == true
        let needsFrontierExpansion = vetoMarks.isEmpty == false
            || selectedCandidate.requiredEvidence.isEmpty == false
            || (selectedEvidenceDebt?.missingEvidence.isEmpty == false)
            || weakPrediction
            || delayedByFrontier
        let needsReframe = selectedCritiques.contains {
            $0.critiqueType == .boundaryConflict && $0.severity >= 0.65
        }

        var remands: [BASRemandOrder] = []
        if needsFrontierExpansion || (selectedForecast?.uncertainty ?? 0) >= 0.5 {
            let requiredWork = unique(
                ["Expand the guard branch before acting."]
                    + selectedCandidate.requiredEvidence
                    + (selectedEvidenceDebt?.missingEvidence ?? [])
                    + (selectedEvidenceDebt?.validationActions ?? [])
                    + (weakPrediction ? ["Re-test the weak prediction before acting."] : [])
            )
            let reasonCodes = unique(
                ["court.evidence_debt"]
                    + ((selectedForecast?.uncertainty ?? 0) >= 0.5 ? ["court.uncertainty_high"] : [])
                    + (weakPrediction ? ["court.weak_prediction"] : [])
                    + (delayedByFrontier ? ["court.delay_branch"] : [])
            )
            remands.append(
                BASRemandOrder(
                    targetLayer: "L9",
                    requiredWork: requiredWork,
                    reasonCodes: reasonCodes
                )
            )
        }
        if needsReframe {
            remands.append(
                BASRemandOrder(
                    targetLayer: "L7",
                    requiredWork: ["Re-clarify the boundary conflict before merging the choice."],
                    reasonCodes: ["court.boundary_conflict"]
                )
            )
        }
        if let convergence = thoughtFrame.convergenceCertificate,
           convergence.stoppingMode == .leaseEnd {
            remands.append(
                BASRemandOrder(
                    targetLayer: "L1",
                    requiredWork: ["Grant a fresh loop lease before attempting auto-merge again."],
                    reasonCodes: ["court.lease_end"]
                )
            )
        }
        if let selectedBreakpointHint {
            remands.append(
                BASRemandOrder(
                    targetLayer: "L14",
                    requiredWork: ["Honor the sovereign breakpoint before any further merge or action."],
                    reasonCodes: unique(["court.sovereign_breakpoint"] + selectedBreakpointHint.reasonCodes)
                )
            )
        }

        return remands
    }

    private func buildCourtDecisionDraft(
        selectedCandidate: BASCandidatePath,
        scores: [BASTriSelfScore],
        tradeoffLedgers: [BASTradeoffLedger],
        agencyReservation: BASAgencyReservation?,
        remandOrders: [BASRemandOrder],
        thoughtFrame: BASThoughtFrame
    ) -> BASCourtDecisionDraft {
        // chapter 八百四十 / M2853 — second TriSelf site flipped
        // (court decision fallback ranking)。 Same pattern as
        // M2852,Swift fallback preserved。
        let filteredFallbacks = scores.filter {
            !$0.veto
                && $0.candidateID != selectedCandidate.candidateID
        }
        let viableFallbacks: [String] = {
            let scoreValues: [Float] = filteredFallbacks.map {
                Float($0.mergedScore)
            }
            if let indices = BASAutoRouteRanker
                .dreamLoopDominanceOrder(scores: scoreValues) {
                return indices.compactMap { idx -> String? in
                    let i = Int(idx)
                    guard i >= 0, i < filteredFallbacks.count
                    else { return nil }
                    return filteredFallbacks[i].candidateID
                }
            }
            // Swift legacy fallback
            return filteredFallbacks
                .sorted { $0.mergedScore > $1.mergedScore }
                .map(\.candidateID)
        }()
        let selectedLedger = tradeoffLedgers.first {
            $0.candidateID == selectedCandidate.candidateID
        }
        let selectedEvidenceDebt = self.evidenceDebt(for: selectedCandidate.candidateID, in: thoughtFrame)
        let requiredDisclosures = unique(
            selectedCandidate.requiredEvidence
                + (selectedEvidenceDebt?.missingEvidence ?? [])
                + uncertaintyDisclosures(for: selectedCandidate.candidateID, in: thoughtFrame)
                + (selectedLedger?.unresolvedTensions ?? [])
        )
        let unresolvedCosts = unique(
            (selectedLedger?.sacrifices ?? [])
                + (selectedLedger?.costs ?? [])
                + convergenceDisclosures(in: thoughtFrame)
        )
        let readinessLevel = if remandOrders.isEmpty == false {
            "remand_pending"
        } else if requiredDisclosures.isEmpty == false {
            "disclosure_required"
        } else {
            "ready"
        }

        return BASCourtDecisionDraft(
            preferredCandidateID: selectedCandidate.candidateID,
            fallbackCandidateIDs: viableFallbacks,
            guardCandidateID: selectedCandidate.candidateID == "path.direct" ? viableFallbacks.first : selectedCandidate.candidateID,
            requiredDisclosures: requiredDisclosures,
            unresolvedCosts: unresolvedCosts,
            agencyMode: agencyReservation?.mode,
            readinessLevel: readinessLevel
        )
    }

    private func evidenceDebt(
        for candidateID: String,
        in thoughtFrame: BASThoughtFrame
    ) -> BASEvidenceDebt? {
        thoughtFrame.evidenceDebts?.first { $0.candidateID == candidateID }
    }

    private func sovereignBreakpointHint(
        for candidateID: String,
        in thoughtFrame: BASThoughtFrame
    ) -> BASSovereignBreakpointHint? {
        thoughtFrame.sovereignBreakpointHints?.first {
            $0.affectedCandidates.contains(candidateID)
                || $0.sourceRef.hasSuffix(candidateID)
        }
    }

    private func sovereignBreakpointPenalty(
        for candidateID: String,
        in thoughtFrame: BASThoughtFrame
    ) -> Double {
        guard let hint = sovereignBreakpointHint(for: candidateID, in: thoughtFrame) else {
            return 0
        }

        switch hint.suggestedAction {
        case .shrink:
            return 0.03
        case .freeze:
            return 0.06
        case .cut:
            return 0.12
        case .stop:
            return 0.18
        }
    }

    private func uncertaintyTensions(
        for candidateID: String,
        in thoughtFrame: BASThoughtFrame
    ) -> [String] {
        guard let ledger = thoughtFrame.uncertaintyLedger else {
            return []
        }

        var tensions: [String] = []
        if ledger.weakPredictions.contains(candidateID) {
            tensions.append("The uncertainty ledger still marks this path as a weak prediction.")
        }
        if ledger.highSensitivityPoints.contains(candidateID) {
            tensions.append("Small changes in evidence could still flip this path.")
        }
        return tensions
    }

    private func uncertaintyDisclosures(
        for candidateID: String,
        in thoughtFrame: BASThoughtFrame
    ) -> [String] {
        guard let ledger = thoughtFrame.uncertaintyLedger else {
            return []
        }

        var disclosures: [String] = []
        if ledger.weakPredictions.contains(candidateID) {
            disclosures.append("This path is still carried as a weak prediction.")
        }
        if thoughtFrame.candidateFrontier?.delayedPaths.contains(candidateID) == true {
            disclosures.append("The current frontier still classifies this path as delay-preferring.")
        }
        return disclosures
    }

    private func convergenceDisclosures(
        in thoughtFrame: BASThoughtFrame
    ) -> [String] {
        guard let convergence = thoughtFrame.convergenceCertificate else {
            return []
        }

        switch convergence.stoppingMode {
        case .leaseEnd:
            return ["The loop lease ended before full convergence."]
        case .sovereignCut:
            return ["A sovereign breakpoint interrupted the convergence path."]
        case .guardTakeover:
            return ["A guard branch took over the convergence path."]
        case .converged:
            return []
        }
    }

    private func sacrifices(
        for candidate: BASCandidatePath
    ) -> [String] {
        switch candidate.candidateID {
        case "path.direct":
            unique([
                "Boundary visibility can collapse under speed.",
                candidate.reversibility < 0.5 ? "You give up reversibility margin." : ""
            ])
        case "path.bounded":
            ["You lose some immediate speed."]
        case "path.reflective":
            ["You sacrifice momentum while naming the pressure clearly."]
        default:
            candidate.expectedCost > 0.4 ? ["This path still costs notable energy."] : []
        }
    }

    private func critiqueUnresolvedTensions(
        from critiques: [BASCritiqueItem]
    ) -> [String] {
        critiques.compactMap { critique in
            guard critique.severity >= 0.55 else { return nil }
            return critique.critiqueText
        }
    }

    private func forecastUnresolvedTensions(
        _ forecast: BASForecastItem?
    ) -> [String] {
        guard let forecast else { return [] }
        guard forecast.uncertainty >= 0.5 else { return [] }
        return ["Worst case still open: \(forecast.worstCase)"]
    }

    private func constitutionSuperegoPenalty(
        for candidate: BASCandidatePath
    ) -> Double {
        guard candidate.candidateID == "path.direct", let hostConstitution else {
            return 0
        }

        let confirmPenalty = hostConstitution.boundaryVeil.confirmRequired.isEmpty ? 0.0 : 0.08
        let hardNoGoPenalty = hostConstitution.boundaryVeil.hardNoGo.isEmpty ? 0.0 : 0.05
        let stabilityWeight = constitutionAxisWeight(
            in: hostConstitution,
            matching: ["stability", "safety", "care", "relationship", "privacy"]
        )
        let valueAxisPenalty = stabilityWeight >= hostConstitution.valueAxes.updateThreshold ? 0.09 : 0.0
        let conflictPenalty = hostConstitution.valueAxes.conflictRules.contains {
            let normalized = $0.lowercased()
            return normalized.contains("over_speed") || normalized.contains("over_haste")
        } ? 0.05 : 0.0
        let boundedGoalPenalty = constitutionPrefersBoundedAction(in: hostConstitution) ? 0.05 : 0.0
        let relationPenalty = constitutionHasHighConsequenceRelations(in: hostConstitution) ? 0.06 : 0.0

        return min(
            0.34,
            confirmPenalty + hardNoGoPenalty + valueAxisPenalty + conflictPenalty + boundedGoalPenalty + relationPenalty
        )
    }

    private func constitutionCandidateBoost(
        for candidate: BASCandidatePath
    ) -> Double {
        guard let hostConstitution else {
            return 0
        }

        var boost = 0.0
        if constitutionPrefersBoundedAction(in: hostConstitution) {
            switch candidate.candidateID {
            case "path.bounded":
                boost += 0.10
            case "path.reflective":
                boost += 0.05
            default:
                break
            }
        }
        if constitutionHasHighConsequenceRelations(in: hostConstitution) {
            switch candidate.candidateID {
            case "path.bounded":
                boost += 0.08
            case "path.reflective":
                boost += 0.04
            default:
                break
            }
        }

        return boost
    }

    private func constitutionAxisWeight(
        in hostConstitution: BASHostConstitution,
        matching protectedAxes: Set<String>
    ) -> Double {
        zip(hostConstitution.valueAxes.axes, hostConstitution.valueAxes.relativeWeights)
            .reduce(0) { partialResult, pair in
                let axis = pair.0.lowercased()
                let weight = pair.1
                return protectedAxes.contains(axis) ? max(partialResult, weight) : partialResult
            }
    }

    private func constitutionPrefersBoundedAction(
        in hostConstitution: BASHostConstitution
    ) -> Bool {
        let descriptors = hostConstitution.goalSpine.priorityOrder
            + hostConstitution.goalSpine.goals
            + hostConstitution.goalSpine.conflictPairs
        return descriptors.contains { descriptor in
            let normalized = descriptor.lowercased()
            return normalized.contains("bounded")
                || normalized.contains("compare")
                || normalized.contains("reflect")
                || normalized.contains("review")
                || normalized.contains("protect")
                || normalized.contains("slow")
        }
    }

    private func constitutionHasHighConsequenceRelations(
        in hostConstitution: BASHostConstitution
    ) -> Bool {
        !hostConstitution.relationGravity.highConsequenceLinks.isEmpty
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private func isLowerMergedScore(
        _ lhs: BASTriSelfScore,
        _ rhs: BASTriSelfScore
    ) -> Bool {
        lhs.mergedScore < rhs.mergedScore
    }
}
