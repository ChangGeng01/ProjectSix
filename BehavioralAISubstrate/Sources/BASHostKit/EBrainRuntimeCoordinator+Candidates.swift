import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M71 split — BASEBrainRuntimeCoordinator — candidate / counterfactual / critique / risk-binding /
// tool-intent / sovereign-neural-contract builders.
// buildCandidateFrontier / buildCounterfactualBundles / buildCritiqueBundles /
// buildRiskBindings / selectedRiskBinding / buildToolIntentEnvelope /
// applySovereignNeuralContract.
// Extracted from the 6099-line monolith during the M71 cohesion split.

extension BASEBrainRuntimeCoordinator {
    func buildCandidateFrontier(
        from thoughtFrame: BASThoughtFrame
    ) -> BASCandidateFrontier? {
        guard thoughtFrame.candidates.isEmpty == false else {
            return nil
        }

        let candidateIDs = thoughtFrame.candidates.map(\.candidateID)
        // chapter 八百三十八 / M2842 — L9 dominance order routed to
        // Rust per chapter 837 5-axis verdict (Rust ~100× faster
        // at 1K-10K scale,no axis worse-by->1.5×)。 The Swift
        // legacy sort remains as the FALLBACK path (executed when
        // Rust FFI unavailable on non-iOS/macOS or returns fault),
        // honoring 「依旧 不删除 只 comment」 — body kept active for
        // determinism contract,not just commented out。
        // chapter 八百四十七 / M2887 — upgraded to f64 path per
        // post-八百四十六 strict review HIGH #1。 The f32 path
        // narrowed Double scores to Float,potentially tying
        // candidates whose Doubles differed by < 2^-23 (real
        // determinism risk vs V1 Swift `.sorted` over Doubles)。
        // Switched to `dreamLoopDominanceOrderDouble` which
        // preserves full Double precision through the Rust kernel。
        // audit orchestration MED-2: the OOB guard now lives in the FFI wrapper
        // (dreamLoopDominanceOrderDouble → validatedPermutation): a corrupt / short /
        // duplicate kernel return yields nil, routing HERE to the Swift `.sorted`
        // fallback (fail-SAFE) rather than aborting the whole process with a call-site
        // precondition (the old fail-loud). A validated permutation indexes safely below.
        let dominanceOrder: [String] = {
            let scores: [Double] = thoughtFrame.candidates.map {
                candidateDominanceScore($0)
            }
            if let indices = BASAutoRouteRanker
                .dreamLoopDominanceOrderDouble(scores: scores) {
                return indices.map { idx -> String in
                    // audit orchestration MED-2: wrapper-validated permutation ⇒ index in range;
                    // a corrupt FFI return fell back to the Swift `.sorted` path (nil wrapper).
                    return thoughtFrame.candidates[Int(idx)].candidateID
                }
            }
            // Swift legacy fallback (V1 implementation,kept active
            // per 「依旧 不删除 只 comment」 + cross-platform safety)
            return thoughtFrame.candidates
                .sorted { lhs, rhs in
                    candidateDominanceScore(lhs)
                        > candidateDominanceScore(rhs)
                }
                .map(\.candidateID)
        }()
        let reversiblePaths = thoughtFrame.candidates
            .filter { $0.reversibility >= 0.6 }
            .map(\.candidateID)
        let guardPaths = thoughtFrame.candidates
            .filter { candidate in
                candidate.reversibility >= 0.7
                    || containsGuardLexicon(candidate.title)
                    || containsGuardLexicon(candidate.actionSummary)
            }
            .map(\.candidateID)

        return BASCandidateFrontier(
            candidateIDs: candidateIDs,
            dominanceOrder: dominanceOrder,
            reversiblePaths: reversiblePaths,
            guardPaths: guardPaths,
            frontierWidth: candidateIDs.count
        )
    }

    func buildCounterfactualBundles(
        from forecasts: [BASForecastItem]
    ) -> [BASCounterfactualBundle]? {
        guard forecasts.isEmpty == false else {
            return nil
        }

        return forecasts.map { forecast in
            BASCounterfactualBundle(
                candidateID: forecast.candidateID,
                shortTerm: forecast.shortTermOutcome,
                midTerm: forecast.midTermOutcome,
                worstCase: forecast.worstCase,
                uncertainty: forecast.uncertainty,
                affectedDomains: forecast.affectedRelations
            )
        }
    }

    func buildCritiqueBundles(
        from critiques: [BASCritiqueItem],
        candidates: [BASCandidatePath]
    ) -> [BASCritiqueBundle]? {
        guard candidates.isEmpty == false else {
            return nil
        }

        let critiqueLookup = Dictionary(grouping: critiques, by: \.candidateID)
        return candidates.map { candidate in
            let candidateCritiques = critiqueLookup[candidate.candidateID] ?? []
            let evidenceGap = critiqueSeverity(.evidenceGap, in: candidateCritiques)
            let manipulationRisk = critiqueSeverity(.manipulationRisk, in: candidateCritiques)
            let emotionalBias = critiqueSeverity(.emotionalBias, in: candidateCritiques)
            let boundaryConflict = critiqueSeverity(.boundaryConflict, in: candidateCritiques)
            let critiqueStrength = max(
                evidenceGap,
                manipulationRisk,
                emotionalBias,
                boundaryConflict
            )

            return BASCritiqueBundle(
                candidateID: candidate.candidateID,
                evidenceGap: evidenceGap,
                manipulationRisk: manipulationRisk,
                emotionalBias: emotionalBias,
                boundaryConflict: boundaryConflict,
                critiqueStrength: critiqueStrength
            )
        }
    }

    func buildRiskBindings(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit
    ) -> [BASRiskPermitBinding] {
        let critiqueLookup = Dictionary(grouping: thoughtFrame.critiques, by: \.candidateID)
        // audit H17: uniquing-guard — was Dictionary(uniqueKeysWithValues:), traps on duplicate key
        let forecastLookup = Dictionary(thoughtFrame.forecasts.map { ($0.candidateID, $0) }, uniquingKeysWith: { first, _ in first })

        return thoughtFrame.candidates.map { candidate in
            let critiques = critiqueLookup[candidate.candidateID] ?? []
            let forecast = forecastLookup[candidate.candidateID]
            let evidenceGap = critiques
                .filter { $0.critiqueType == .evidenceGap }
                .map(\.severity)
                .max() ?? 0
            let manipulationPressure = critiques
                .filter { $0.critiqueType == .manipulationRisk }
                .map(\.severity)
                .max() ?? riskCard.manipulationStrength
            let emotionalBias = critiques
                .filter { $0.critiqueType == .emotionalBias }
                .map(\.severity)
                .max() ?? 0
            let boundaryConflict = critiques
                .filter { $0.critiqueType == .boundaryConflict }
                .map(\.severity)
                .max() ?? 0
            let irreversibility = min(max(max(riskCard.irreversibility, 1 - candidate.reversibility), 0), 1)
            let uncertainty = min(
                1,
                max(riskCard.uncertainty, forecast?.uncertainty ?? 0) + (evidenceGap * 0.15)
            )
            let manipulationStrength = min(
                1,
                max(riskCard.manipulationStrength, manipulationPressure + emotionalBias * 0.25)
            )
            let totalRisk = min(
                1,
                (riskCard.totalRisk * 0.5)
                    + (irreversibility * 0.25)
                    + (uncertainty * 0.10)
                    + (manipulationStrength * 0.10)
                    + (boundaryConflict * 0.05)
            )
            let gsiScore = min(
                1,
                max(
                    riskCard.gsiScore,
                    irreversibility * 0.45 + manipulationStrength * 0.30 + boundaryConflict * 0.25
                )
            )
            let candidateRiskLevel = riskService.riskLevel(
                for: max(totalRisk, gsiScore)
            )
            let recommendedMode = recommendedPermitMode(
                riskLevel: candidateRiskLevel,
                gsiScore: gsiScore,
                irreversibility: irreversibility,
                boundaryConflict: boundaryConflict
            )
            let permitMode = saferPermitMode(
                recommendedMode,
                actionPermit.mode
            )
            let boundPermit = enforcedPermit(
                targetMode: permitMode,
                from: actionPermit,
                reasonCode: "binding.\(candidate.candidateID)"
            )
            let reasonCodes = unique(
                riskCard.factors
                    + boundPermit.reasonCodes
                    + (candidate.candidateID == mergedChoice.candidateID ? ["binding.primary_candidate"] : [])
                    + (evidenceGap > 0.4 ? ["candidate.evidence_gap"] : [])
                    + (irreversibility > 0.75 ? ["candidate.irreversible"] : [])
                    + (manipulationStrength > 0.6 ? ["candidate.manipulation"] : [])
                    + (boundaryConflict > 0.6 ? ["candidate.boundary_conflict"] : [])
            )

            return BASRiskPermitBinding(
                candidateID: candidate.candidateID,
                riskLevel: candidateRiskLevel,
                totalRisk: totalRisk,
                uncertainty: uncertainty,
                irreversibility: irreversibility,
                manipulationStrength: manipulationStrength,
                gsiScore: gsiScore,
                recommendedMode: recommendedMode,
                permitMode: permitMode,
                requireSecondCheck: boundPermit.requireSecondCheck,
                outputLengthCap: boundPermit.outputLengthCap,
                tonePolicy: boundPermit.tonePolicy,
                templatePolicy: boundPermit.templatePolicy,
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: permitMode),
                forbiddenDomains: forbiddenDomains(for: permitMode)
            )
        }
    }

    func selectedRiskBinding(
        from bindings: [BASRiskPermitBinding],
        mergedChoice: BASMergedChoice,
        thoughtFrame: BASThoughtFrame
    ) -> BASRiskPermitBinding? {
        if let matched = bindings.first(where: { $0.candidateID == mergedChoice.candidateID }) {
            return matched
        }
        if let dominantID = thoughtFrame.candidateFrontier?.dominanceOrder.first,
           let dominant = bindings.first(where: { $0.candidateID == dominantID }) {
            return dominant
        }
        return bindings.first
    }

    func buildToolIntentEnvelope(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        primaryBinding: BASRiskPermitBinding?,
        actionPermit: BASActionPermit
    ) -> BASToolIntentEnvelope? {
        guard thoughtFrame.organMap?.activeOrgans.contains(.toolIntentMesh) == true else {
            return nil
        }

        let boundPermit = primaryBinding?.actionPermit ?? actionPermit
        guard boundPermit.mode != .block else {
            return nil
        }

        let candidateID = primaryBinding?.candidateID ?? mergedChoice.candidateID
        let requestedDomains = primaryBinding?.allowedDomains ?? allowedDomains(for: boundPermit.mode)
        let blockedDomains = primaryBinding?.forbiddenDomains ?? forbiddenDomains(for: boundPermit.mode)
        let reasonCodes = unique((primaryBinding?.reasonCodes ?? []) + boundPermit.reasonCodes)

        return BASToolIntentEnvelope(
            intentID: "tool-intent.\(candidateID).\(boundPermit.mode.rawValue)",
            candidateID: candidateID,
            permitMode: boundPermit.mode,
            summary: mergedChoice.actionSummary,
            requestedDomains: requestedDomains,
            blockedDomains: blockedDomains,
            requireSecondCheck: boundPermit.requireSecondCheck,
            tonePolicy: boundPermit.tonePolicy,
            templatePolicy: boundPermit.templatePolicy,
            reasonCodes: reasonCodes,
            sovereignBound: !(thoughtFrame.organMap?.sovereignConstraints.isEmpty ?? true)
        )
    }

    func applySovereignNeuralContract(
        to organMap: BASNeuralOrganMap,
        budgetFrame: BASBudgetFrame,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        activeKillSwitches: [BASKillSwitchID],
        inheritedReasonCodes: [String]
    ) -> (BASNeuralOrganMap, [String]) {
        let targetMorph: BASNeuralMorph
        if budgetFrame.runMode == .lockdown || actionPermit.mode == .block {
            targetMorph = .stub
        } else if budgetFrame.runMode == .quarantine {
            targetMorph = .quarantine
        } else if budgetFrame.runMode == .recovery {
            targetMorph = .rollbackRebuild
        } else if budgetFrame.runMode == .guard
            || riskCard.riskLevel >= .high
            || actionPermit.mode == .delay
            || actionPermit.mode == .replace {
            targetMorph = .guard
        } else {
            targetMorph = organMap.morph
        }

        var degradedReasonCodes = inheritedReasonCodes
        if targetMorph != organMap.morph {
            degradedReasonCodes.append("sovereign.morph_shrink")
        }
        if targetMorph == .stub {
            degradedReasonCodes.append("runtime.stub_only")
        }
        if targetMorph == .quarantine {
            degradedReasonCodes.append("runtime.quarantine")
        }

        let sovereignConstraints = unique(
            organMap.sovereignConstraints
                + activeKillSwitches.map(\.rawValue)
                + sovereignConstraintCodes(
                    for: targetMorph,
                    actionPermit: actionPermit
                )
        )

        let rebuilt = BASNeuralOrganMap(
            morph: targetMorph,
            activeOrgans: defaultActiveOrgans(for: targetMorph),
            precisionMap: defaultPrecisionMap(for: targetMorph, budgetFrame: budgetFrame),
            routingPolicy: defaultRoutingPolicy(for: targetMorph),
            leaseRef: organMap.leaseRef,
            sovereignConstraints: sovereignConstraints,
            headGuarantees: defaultHeadGuarantees(for: targetMorph)
        )

        return (rebuilt, unique(degradedReasonCodes))
    }

}
