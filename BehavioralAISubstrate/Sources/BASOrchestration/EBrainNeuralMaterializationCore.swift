import Foundation
import BASPolicy

public struct BASNeuralThoughtMaterialization: Equatable, Sendable {
    public var candidateFrontier: BASCandidateFrontier?
    public var counterfactualBundles: [BASCounterfactualBundle]?
    public var critiqueBundles: [BASCritiqueBundle]?
    public var uncertaintyLedger: BASUncertaintyLedger?
    public var evidenceDebts: [BASEvidenceDebt]?
    public var convergenceCertificate: BASConvergenceCertificate?
    public var loopLeaseReceipt: BASLoopLeaseReceipt?
    public var sovereignBreakpointHints: [BASSovereignBreakpointHint]?
    /// M52 — L9 dream-loop per-candidate observation bundle. Emitted
    /// as a first-class output of `materializeThoughtArtifacts`, derived
    /// deterministically from the same `BASThoughtFrame` inputs that
    /// drive the frontier. The bundle mirrors the frontier's decisions
    /// (one `.candidate` + optional `.dominanceSignal` per candidate;
    /// `.reversibilitySignal` for reversible paths; `.guardianBranch`
    /// for guard paths; `.delayRecommendation` for delayed paths; a
    /// single aggregate `.diversitySignal`), so the M24 primitives
    /// stop being a test-only sidecar and start being load-bearing
    /// observations that the M32 coverage projection and the L14
    /// audit surface can rely on per turn.
    ///
    /// Nil iff `candidateFrontier` is also nil (no candidates →
    /// no observations to emit); this keeps the pair coherent
    /// by construction.
    public var candidateObservationBundle: BASCandidateObservationBundle?

    public init(
        candidateFrontier: BASCandidateFrontier? = nil,
        counterfactualBundles: [BASCounterfactualBundle]? = nil,
        critiqueBundles: [BASCritiqueBundle]? = nil,
        uncertaintyLedger: BASUncertaintyLedger? = nil,
        evidenceDebts: [BASEvidenceDebt]? = nil,
        convergenceCertificate: BASConvergenceCertificate? = nil,
        loopLeaseReceipt: BASLoopLeaseReceipt? = nil,
        sovereignBreakpointHints: [BASSovereignBreakpointHint]? = nil,
        candidateObservationBundle: BASCandidateObservationBundle? = nil
    ) {
        self.candidateFrontier = candidateFrontier
        self.counterfactualBundles = counterfactualBundles
        self.critiqueBundles = critiqueBundles
        self.uncertaintyLedger = uncertaintyLedger
        self.evidenceDebts = evidenceDebts
        self.convergenceCertificate = convergenceCertificate
        self.loopLeaseReceipt = loopLeaseReceipt
        self.sovereignBreakpointHints = sovereignBreakpointHints
        self.candidateObservationBundle = candidateObservationBundle
    }
}

public struct BASNeuralPublicThoughtProjection: Codable, Equatable, Sendable {
    public var candidates: [BASCandidatePath]?
    public var forecasts: [BASForecastItem]?
    public var critiques: [BASCritiqueItem]?

    public init(
        candidates: [BASCandidatePath]? = nil,
        forecasts: [BASForecastItem]? = nil,
        critiques: [BASCritiqueItem]? = nil
    ) {
        self.candidates = candidates
        self.forecasts = forecasts
        self.critiques = critiques
    }
}

public enum BASNeuralMaterializationCompiler {
    public static func materializeThoughtArtifacts(
        thoughtFrame: BASThoughtFrame
    ) -> BASNeuralThoughtMaterialization {
        let candidateFrontier = buildCandidateFrontier(from: thoughtFrame)
        let counterfactualBundles = buildCounterfactualBundles(from: thoughtFrame.forecasts)
        let critiqueBundles = buildCritiqueBundles(
            from: thoughtFrame.critiques,
            candidates: thoughtFrame.candidates
        )
        let uncertaintyLedger = buildUncertaintyLedger(
            from: thoughtFrame,
            critiqueBundles: critiqueBundles
        )
        let evidenceDebts = buildEvidenceDebts(
            from: thoughtFrame,
            critiqueBundles: critiqueBundles
        )
        let sovereignBreakpointHints = buildSovereignBreakpointHints(
            from: thoughtFrame,
            critiqueBundles: critiqueBundles
        )
        let candidateObservationBundle = buildCandidateObservationBundle(
            from: thoughtFrame,
            frontier: candidateFrontier
        )

        return BASNeuralThoughtMaterialization(
            candidateFrontier: candidateFrontier,
            counterfactualBundles: counterfactualBundles,
            critiqueBundles: critiqueBundles,
            uncertaintyLedger: uncertaintyLedger,
            evidenceDebts: evidenceDebts,
            convergenceCertificate: buildConvergenceCertificate(
                from: thoughtFrame,
                frontier: candidateFrontier,
                critiqueBundles: critiqueBundles
            ),
            loopLeaseReceipt: buildLoopLeaseReceipt(
                from: thoughtFrame,
                frontier: candidateFrontier,
                counterfactualBundles: counterfactualBundles
            ),
            sovereignBreakpointHints: sovereignBreakpointHints,
            candidateObservationBundle: candidateObservationBundle
        )
    }

    public static func materializePublicProjection(
        thoughtFrame: BASThoughtFrame
    ) -> BASNeuralPublicThoughtProjection {
        return BASNeuralPublicThoughtProjection(
            candidates: nil,
            forecasts: thoughtFrame.forecasts.isEmpty
                ? Self.buildForecastSurface(from: thoughtFrame.counterfactualBundles)
                : nil,
            critiques: thoughtFrame.critiques.isEmpty
                ? Self.buildCritiqueSurface(from: thoughtFrame.critiqueBundles)
                : nil
        )
    }

    public static func materializeRiskBindings(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        riskLevelResolver: @Sendable (Double) -> BASBrainRiskLevel
    ) -> [BASRiskPermitBinding] {
        let critiqueLookup = Dictionary(grouping: thoughtFrame.critiques, by: \.candidateID)
        let forecastLookup = Dictionary(uniqueKeysWithValues: thoughtFrame.forecasts.map { ($0.candidateID, $0) })

        return thoughtFrame.candidates.map { candidate in
            let critiques = critiqueLookup[candidate.candidateID] ?? []
            let forecast = forecastLookup[candidate.candidateID]
            let evidenceGap = critiqueSeverity(.evidenceGap, in: critiques)
            let manipulationPressure = critiqueSeverity(.manipulationRisk, in: critiques)
            let emotionalBias = critiqueSeverity(.emotionalBias, in: critiques)
            let boundaryConflict = critiqueSeverity(.boundaryConflict, in: critiques)
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
            let candidateRiskLevel = riskLevelResolver(max(totalRisk, gsiScore))
            let recommendedMode = recommendedPermitMode(
                riskLevel: candidateRiskLevel,
                gsiScore: gsiScore,
                irreversibility: irreversibility,
                boundaryConflict: boundaryConflict
            )
            let permitMode = saferPermitMode(recommendedMode, actionPermit.mode)
            let reasonCodes = unique(
                riskCard.factors
                    + actionPermit.reasonCodes
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
                stackedModes: actionPermit.stackedModes,
                assertionCeiling: actionPermit.assertionCeiling,
                toolScope: actionPermit.toolScope,
                memoryScope: actionPermit.memoryScope,
                requireSecondCheck: actionPermit.requireSecondCheck,
                outputLengthCap: actionPermit.outputLengthCap,
                tonePolicy: actionPermit.tonePolicy,
                templatePolicy: actionPermit.templatePolicy,
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: permitMode),
                forbiddenDomains: forbiddenDomains(for: permitMode),
                delayType: actionPermit.delayWindow,
                substituteType: actionPermit.substituteRequired ? actionPermit.templatePolicy : nil,
                sovereignHintLevel: actionPermit.escalationHintRef
            )
        }
    }

    public static func selectedRiskBinding(
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

    public static func materializeToolIntent(
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        actionPermit: BASActionPermit
    ) -> BASToolIntentEnvelope? {
        guard thoughtFrame.organMap?.activeOrgans.contains(.toolIntentMesh) == true else {
            return nil
        }
        guard actionPermit.mode != .block else {
            return nil
        }

        let primaryBinding = selectedRiskBinding(
            from: thoughtFrame.riskBindings ?? [],
            mergedChoice: mergedChoice,
            thoughtFrame: thoughtFrame
        )
        let candidateID = primaryBinding?.candidateID ?? mergedChoice.candidateID
        let requestedDomains = primaryBinding?.allowedDomains ?? allowedDomains(for: actionPermit.mode)
        let blockedDomains = primaryBinding?.forbiddenDomains ?? forbiddenDomains(for: actionPermit.mode)
        let reasonCodes = unique((primaryBinding?.reasonCodes ?? []) + actionPermit.reasonCodes)

        return BASToolIntentEnvelope(
            intentID: "tool-intent.\(candidateID).\(actionPermit.mode.rawValue)",
            candidateID: candidateID,
            permitMode: actionPermit.mode,
            summary: mergedChoice.actionSummary,
            requestedDomains: requestedDomains,
            blockedDomains: blockedDomains,
            stackedModes: actionPermit.stackedModes,
            assertionCeiling: actionPermit.assertionCeiling,
            toolScope: actionPermit.toolScope,
            memoryScope: actionPermit.memoryScope,
            requireSecondCheck: actionPermit.requireSecondCheck,
            tonePolicy: actionPermit.tonePolicy,
            templatePolicy: actionPermit.templatePolicy,
            reasonCodes: reasonCodes,
            delayType: actionPermit.delayWindow,
            substituteType: actionPermit.substituteRequired ? actionPermit.templatePolicy : nil,
            sovereignHintLevel: actionPermit.escalationHintRef,
            sovereignBound: !(thoughtFrame.organMap?.sovereignConstraints.isEmpty ?? true)
        )
    }

    public static func buildCandidateFrontier(
        from thoughtFrame: BASThoughtFrame
    ) -> BASCandidateFrontier? {
        guard thoughtFrame.candidates.isEmpty == false else {
            return nil
        }

        let forecastLookup = Dictionary(uniqueKeysWithValues: thoughtFrame.forecasts.map { ($0.candidateID, $0) })
        let critiqueLookup = Dictionary(grouping: thoughtFrame.critiques, by: \.candidateID)
        let candidateIDs = thoughtFrame.candidates.map(\.candidateID)
        let dominanceOrder = thoughtFrame.candidates
            .sorted { lhs, rhs in
                candidateDominanceScore(lhs) > candidateDominanceScore(rhs)
            }
            .map(\.candidateID)
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
        let delayedPaths = thoughtFrame.candidates
            .filter { candidate in
                Self.isDelayedCandidate(
                    candidate,
                    forecast: forecastLookup[candidate.candidateID],
                    critiques: critiqueLookup[candidate.candidateID] ?? []
                )
            }
            .map(\.candidateID)

        return BASCandidateFrontier(
            candidateIDs: candidateIDs,
            dominanceOrder: dominanceOrder,
            reversiblePaths: reversiblePaths,
            guardPaths: guardPaths,
            frontierWidth: candidateIDs.count,
            diversityScore: Self.frontierDiversityScore(in: thoughtFrame.candidates),
            delayedPaths: delayedPaths
        )
    }

    /// M52 — derive an L9 per-candidate observation bundle from the
    /// same `BASThoughtFrame` data that drives the frontier. This
    /// closes the L4↔L9 adjacent gap for L9 itself: M24 primitives
    /// stop being a test-only sidecar and start being a real output
    /// of the main chain, so the M32 coverage projection and the L14
    /// audit surface get a bundle per turn without any additional
    /// wiring from the coordinator.
    ///
    /// The bundle mirrors the frontier's decisions (it is derived
    /// from the same inputs; they are coherent by construction):
    ///   - `.candidate` for every candidate (carries the raw draft
    ///     signal; salience = dominance score, confidence = candidate
    ///     confidence)
    ///   - `.dominanceSignal` for every candidate (position-ordered
    ///     salience so the dominance ordering is directly recoverable
    ///     from the observations)
    ///   - `.reversibilitySignal` for every reversible path
    ///   - `.guardianBranch` for every guard path
    ///   - `.delayRecommendation` for every delayed path
    ///   - one aggregate `.diversitySignal` keyed by the first
    ///     candidate (diversity is a frontier-level property, not a
    ///     per-candidate property; we surface it once so the
    ///     observation grammar keeps one record per signal kind the
    ///     frontier actually used)
    ///
    /// Returns nil iff the frontier is also nil (no candidates → no
    /// observations); this keeps the (`candidateFrontier`,
    /// `candidateObservationBundle`) pair coherent.
    public static func buildCandidateObservationBundle(
        from thoughtFrame: BASThoughtFrame,
        frontier: BASCandidateFrontier?
    ) -> BASCandidateObservationBundle? {
        guard
            let frontier,
            thoughtFrame.candidates.isEmpty == false
        else {
            return nil
        }

        let turnID = "l9.turn.step-\(thoughtFrame.stepIndex)"
        let sessionID = thoughtFrame.decomposeRef
        let emittedAt = Date()

        let candidateByID = Dictionary(
            uniqueKeysWithValues:
                thoughtFrame.candidates.map { ($0.candidateID, $0) })
        let dominanceOrder = frontier.dominanceOrder
        let dominanceRank = Dictionary(
            uniqueKeysWithValues:
                dominanceOrder.enumerated()
                .map { ($0.element, $0.offset) })
        let reversibleSet = Set(frontier.reversiblePaths)
        let guardSet = Set(frontier.guardPaths)
        let delayedSet = Set(frontier.delayedPaths)
        let orderCount = max(1, dominanceOrder.count)

        var observations: [BASCandidateObservation] = []

        for candidate in thoughtFrame.candidates {
            let score = candidateDominanceScore(candidate)
            let normalizedScore = min(max(score, 0), 1)
            observations.append(
                BASCandidateObservation(
                    kind: .candidate,
                    candidateID: candidate.candidateID,
                    salience: normalizedScore,
                    confidence: candidate.confidence,
                    content: candidate.actionSummary,
                    observedAt: emittedAt))

            if let rank = dominanceRank[candidate.candidateID] {
                let positionSalience =
                    Double(orderCount - rank) / Double(orderCount)
                observations.append(
                    BASCandidateObservation(
                        kind: .dominanceSignal,
                        candidateID: candidate.candidateID,
                        salience: positionSalience,
                        confidence: normalizedScore,
                        content:
                            "dominance-rank:\(rank + 1)/\(orderCount)",
                        observedAt: emittedAt))
            }

            if reversibleSet.contains(candidate.candidateID) {
                observations.append(
                    BASCandidateObservation(
                        kind: .reversibilitySignal,
                        candidateID: candidate.candidateID,
                        salience: candidate.reversibility,
                        confidence: candidate.confidence,
                        content:
                            "reversibility:\(candidate.reversibility)",
                        observedAt: emittedAt))
            }

            if guardSet.contains(candidate.candidateID) {
                // Guard paths include reversibility-only entries *and*
                // lexicon matches; salience picks whichever is more
                // informative so the observation isn't falsely weak.
                let guardSalience = max(candidate.reversibility, 0.7)
                observations.append(
                    BASCandidateObservation(
                        kind: .guardianBranch,
                        candidateID: candidate.candidateID,
                        salience: guardSalience,
                        confidence: candidate.confidence,
                        content:
                            "guard-path:\(candidate.candidateID)",
                        observedAt: emittedAt))
            }

            if delayedSet.contains(candidate.candidateID) {
                observations.append(
                    BASCandidateObservation(
                        kind: .delayRecommendation,
                        candidateID: candidate.candidateID,
                        salience: 1.0 - candidate.confidence,
                        confidence: candidate.confidence,
                        content:
                            "delayed-path:\(candidate.candidateID)",
                        observedAt: emittedAt))
            }
        }

        // One aggregate diversity observation. We key it to the first
        // dominance-ordered candidate if present (the frontier's
        // "bearer" of the ranking), otherwise to the first candidate
        // as a fallback — either way the observation carries the
        // global diversity score at bundle level.
        let diversityBearer =
            dominanceOrder.first
            ?? thoughtFrame.candidates.first?.candidateID
        if let diversityBearer,
           let bearerCandidate = candidateByID[diversityBearer] {
            observations.append(
                BASCandidateObservation(
                    kind: .diversitySignal,
                    candidateID: diversityBearer,
                    salience: frontier.diversityScore,
                    confidence: bearerCandidate.confidence,
                    content:
                        "frontier-diversity:"
                        + "\(frontier.diversityScore)",
                    observedAt: emittedAt))
        }

        return BASCandidateObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            observations: observations,
            emittedAt: emittedAt)
    }

    public static func buildCounterfactualBundles(
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

    public static func buildCritiqueBundles(
        from critiques: [BASCritiqueItem],
        candidates: [BASCandidatePath]
    ) -> [BASCritiqueBundle]? {
        guard candidates.isEmpty == false else {
            return nil
        }

        let critiqueLookup = Dictionary(grouping: critiques, by: \.candidateID)
        return candidates.map { candidate in
            let candidateCritiques = critiqueLookup[candidate.candidateID] ?? []
            let evidenceGap = Self.critiqueSeverity(.evidenceGap, in: candidateCritiques)
            let manipulationRisk = Self.critiqueSeverity(.manipulationRisk, in: candidateCritiques)
            let emotionalBias = Self.critiqueSeverity(.emotionalBias, in: candidateCritiques)
            let boundaryConflict = Self.critiqueSeverity(.boundaryConflict, in: candidateCritiques)

            return BASCritiqueBundle(
                candidateID: candidate.candidateID,
                evidenceGap: evidenceGap,
                manipulationRisk: manipulationRisk,
                emotionalBias: emotionalBias,
                boundaryConflict: boundaryConflict,
                critiqueStrength: max(evidenceGap, manipulationRisk, emotionalBias, boundaryConflict)
            )
        }
    }

    public static func buildUncertaintyLedger(
        from thoughtFrame: BASThoughtFrame,
        critiqueBundles: [BASCritiqueBundle]?
    ) -> BASUncertaintyLedger? {
        let critiqueLookup = Dictionary(uniqueKeysWithValues: (critiqueBundles ?? []).map { ($0.candidateID, $0) })
        let forecastLookup = Dictionary(uniqueKeysWithValues: thoughtFrame.forecasts.map { ($0.candidateID, $0) })
        let unresolvedUnknowns = unique(
            thoughtFrame.candidates.flatMap(\.requiredEvidence).filter { !$0.isEmpty }
        )
        let weakPredictions = unique(
            thoughtFrame.forecasts
                .filter { $0.uncertainty >= 0.45 }
                .map(\.candidateID)
        )
        let highSensitivityPoints = unique(
            thoughtFrame.candidates.compactMap { candidate in
                let critiqueStrength = critiqueLookup[candidate.candidateID]?.critiqueStrength ?? 0
                let forecastUncertainty = forecastLookup[candidate.candidateID]?.uncertainty ?? 0
                guard critiqueStrength >= 0.75 || forecastUncertainty >= 0.65 else {
                    return nil
                }
                return candidate.candidateID
            }
        )
        let confidenceFloor = thoughtFrame.candidates
            .map { candidate -> Double in
                let forecastPenalty = (forecastLookup[candidate.candidateID]?.uncertainty ?? 0) * 0.30
                let critiquePenalty = (critiqueLookup[candidate.candidateID]?.critiqueStrength ?? 0) * 0.20
                return min(max(candidate.confidence - forecastPenalty - critiquePenalty, 0), 1)
            }
            .min() ?? 0

        guard
            unresolvedUnknowns.isEmpty == false
                || weakPredictions.isEmpty == false
                || highSensitivityPoints.isEmpty == false
                || thoughtFrame.candidates.isEmpty == false
        else {
            return nil
        }

        return BASUncertaintyLedger(
            ledgerID: "uncertainty.step-\(thoughtFrame.stepIndex)",
            unresolvedUnknowns: unresolvedUnknowns,
            weakPredictions: weakPredictions,
            highSensitivityPoints: highSensitivityPoints,
            confidenceFloor: confidenceFloor
        )
    }

    public static func buildEvidenceDebts(
        from thoughtFrame: BASThoughtFrame,
        critiqueBundles: [BASCritiqueBundle]?
    ) -> [BASEvidenceDebt]? {
        guard thoughtFrame.candidates.isEmpty == false else {
            return nil
        }

        let critiqueLookup = Dictionary(uniqueKeysWithValues: (critiqueBundles ?? []).map { ($0.candidateID, $0) })

        return thoughtFrame.candidates.map { candidate in
            let critiqueBundle = critiqueLookup[candidate.candidateID]
            let evidenceGap = critiqueBundle?.evidenceGap ?? 0
            let missingEvidence = candidate.requiredEvidence
            let validationActions = missingEvidence.isEmpty
                ? ["Validate candidate \(candidate.candidateID) before escalation."]
                : missingEvidence.map { "Validate: \($0)" }
            let baseEvidenceWeight = missingEvidence.isEmpty ? 0.12 : min(Double(missingEvidence.count) / 2, 1)

            return BASEvidenceDebt(
                debtID: "debt.\(candidate.candidateID)",
                candidateID: candidate.candidateID,
                missingEvidence: missingEvidence,
                validationActions: validationActions,
                debtWeight: min(1, max(baseEvidenceWeight, evidenceGap))
            )
        }
    }

    public static func buildConvergenceCertificate(
        from thoughtFrame: BASThoughtFrame,
        frontier: BASCandidateFrontier?,
        critiqueBundles: [BASCritiqueBundle]?
    ) -> BASConvergenceCertificate? {
        guard let frontier else {
            return nil
        }

        let averageCritique = Self.average((critiqueBundles ?? []).map(\.critiqueStrength))
        let averageUncertainty = Self.average(thoughtFrame.forecasts.map(\.uncertainty))
        let stabilityScore = min(
            1,
            max(
                thoughtFrame.stabilityScore,
                Self.average(thoughtFrame.candidates.map(\.confidence)) - averageCritique * 0.15 - averageUncertainty * 0.10
            )
        )

        return BASConvergenceCertificate(
            certID: "convergence.step-\(thoughtFrame.stepIndex)",
            frontierID: "frontier.step-\(thoughtFrame.stepIndex)",
            stabilityScore: stabilityScore,
            stoppingMode: Self.stoppingMode(for: thoughtFrame.stopReason),
            recommendedNextStep: Self.recommendedNextStep(
                from: thoughtFrame,
                dominanceOrder: frontier.dominanceOrder
            )
        )
    }

    public static func buildLoopLeaseReceipt(
        from thoughtFrame: BASThoughtFrame,
        frontier: BASCandidateFrontier?,
        counterfactualBundles: [BASCounterfactualBundle]?
    ) -> BASLoopLeaseReceipt? {
        guard thoughtFrame.candidates.isEmpty == false || thoughtFrame.organMap?.leaseRef != nil else {
            return nil
        }

        return BASLoopLeaseReceipt(
            receiptID: "loop-receipt.step-\(thoughtFrame.stepIndex)",
            leaseID: thoughtFrame.organMap?.leaseRef ?? "unleased",
            loopsUsed: max(thoughtFrame.stepIndex, 1),
            candidatesUsed: frontier?.frontierWidth ?? thoughtFrame.candidates.count,
            projectionsUsed: counterfactualBundles?.count ?? thoughtFrame.forecasts.count,
            degraded: thoughtFrame.stopReason == .maxLoopsReached
        )
    }

    public static func buildSovereignBreakpointHints(
        from thoughtFrame: BASThoughtFrame,
        critiqueBundles: [BASCritiqueBundle]?
    ) -> [BASSovereignBreakpointHint]? {
        let sovereignConstraints = thoughtFrame.organMap?.sovereignConstraints ?? []
        let hints = (critiqueBundles ?? []).compactMap { bundle -> BASSovereignBreakpointHint? in
            let hasBoundaryConflict = bundle.boundaryConflict >= 0.75
            let hasManipulationRisk = bundle.manipulationRisk >= 0.75
            guard hasBoundaryConflict || hasManipulationRisk else {
                return nil
            }

            let suggestedAction: BASSovereignBreakpointSuggestedAction
            if hasBoundaryConflict || sovereignConstraints.contains("tool_cut") {
                suggestedAction = .cut
            } else if hasManipulationRisk {
                suggestedAction = .freeze
            } else {
                suggestedAction = .shrink
            }

            return BASSovereignBreakpointHint(
                hintID: "sovereign-breakpoint.\(bundle.candidateID)",
                sourceRef: "candidate.\(bundle.candidateID)",
                reasonCodes: unique(
                    (hasBoundaryConflict ? ["boundary_conflict"] : [])
                        + (hasManipulationRisk ? ["manipulation_risk"] : [])
                        + sovereignConstraints
                ),
                affectedCandidates: [bundle.candidateID],
                suggestedAction: suggestedAction
            )
        }

        return hints.isEmpty ? nil : hints
    }

    public static func buildForecastSurface(
        from bundles: [BASCounterfactualBundle]?
    ) -> [BASForecastItem]? {
        guard let bundles, bundles.isEmpty == false else {
            return nil
        }

        return bundles.map { bundle in
            BASForecastItem(
                candidateID: bundle.candidateID,
                shortTermOutcome: bundle.shortTerm,
                midTermOutcome: bundle.midTerm,
                worstCase: bundle.worstCase,
                uncertainty: bundle.uncertainty,
                affectedRelations: bundle.affectedDomains
            )
        }
    }

    public static func buildCritiqueSurface(
        from bundles: [BASCritiqueBundle]?
    ) -> [BASCritiqueItem]? {
        guard let bundles, bundles.isEmpty == false else {
            return nil
        }

        let critiques = bundles.compactMap { bundle -> BASCritiqueItem? in
            guard let strongest = strongestCritique(in: bundle) else {
                return nil
            }

            return BASCritiqueItem(
                candidateID: bundle.candidateID,
                critiqueType: strongest.type,
                critiqueText: critiqueText(
                    for: strongest.type,
                    severity: strongest.severity
                ),
                severity: strongest.severity
            )
        }

        return critiques.isEmpty ? nil : critiques
    }

    public static func projectedCandidates(
        from candidates: [BASCandidatePath],
        frontier: BASCandidateFrontier?
    ) -> [BASCandidatePath]? {
        guard
            let frontier,
            frontier.dominanceOrder.isEmpty == false,
            candidates.isEmpty == false
        else {
            return nil
        }

        let candidateLookup = Dictionary(uniqueKeysWithValues: candidates.map { ($0.candidateID, $0) })
        let ordered = frontier.dominanceOrder.compactMap { candidateLookup[$0] }
        let seenIDs = Set(ordered.map(\.candidateID))
        let remaining = candidates.filter { !seenIDs.contains($0.candidateID) }
        let projection = ordered + remaining

        return projection == candidates ? nil : projection
    }

    private static func critiqueSeverity(
        _ type: BASCritiqueType,
        in critiques: [BASCritiqueItem]
    ) -> Double {
        critiques
            .filter { $0.critiqueType == type }
            .map(\.severity)
            .max() ?? 0
    }

    private static func strongestCritique(
        in bundle: BASCritiqueBundle
    ) -> (type: BASCritiqueType, severity: Double)? {
        let scores: [(BASCritiqueType, Double)] = [
            (.evidenceGap, bundle.evidenceGap),
            (.manipulationRisk, bundle.manipulationRisk),
            (.emotionalBias, bundle.emotionalBias),
            (.boundaryConflict, bundle.boundaryConflict)
        ]
        guard let strongest = scores.max(by: { $0.1 < $1.1 }), strongest.1 > 0 else {
            return nil
        }
        return (type: strongest.0, severity: strongest.1)
    }

    private static func critiqueText(
        for type: BASCritiqueType,
        severity: Double
    ) -> String {
        let strength = Int((severity * 100).rounded())
        switch type {
        case .evidenceGap:
            return "Neural critique flags an evidence gap (\(strength))."
        case .manipulationRisk:
            return "Neural critique flags manipulation pressure (\(strength))."
        case .emotionalBias:
            return "Neural critique flags emotional bias (\(strength))."
        case .boundaryConflict:
            return "Neural critique flags boundary conflict (\(strength))."
        }
    }

    private static func candidateDominanceScore(
        _ candidate: BASCandidatePath
    ) -> Double {
        (candidate.expectedBenefit * 0.45)
            + (candidate.reversibility * 0.30)
            + (candidate.confidence * 0.20)
            - (candidate.expectedCost * 0.25)
    }

    private static func containsGuardLexicon(
        _ value: String
    ) -> Bool {
        let normalized = value.lowercased()
        return normalized.contains("delay")
            || normalized.contains("pause")
            || normalized.contains("wait")
            || normalized.contains("review")
            || normalized.contains("bounded")
            || normalized.contains("protect")
    }

    private static func isDelayedCandidate(
        _ candidate: BASCandidatePath,
        forecast: BASForecastItem?,
        critiques: [BASCritiqueItem]
    ) -> Bool {
        let evidenceGap = critiqueSeverity(.evidenceGap, in: critiques)
        let normalizedText = "\(candidate.title) \(candidate.actionSummary) \(candidate.requiredEvidence.joined(separator: " "))"
            .lowercased()

        return normalizedText.contains("pause")
            || normalizedText.contains("wait")
            || normalizedText.contains("delay")
            || normalizedText.contains("verify")
            || normalizedText.contains("gather")
            || (candidate.requiredEvidence.isEmpty == false && (forecast?.uncertainty ?? 0) >= 0.40)
            || (candidate.reversibility >= 0.80 && evidenceGap >= 0.50)
    }

    private static func frontierDiversityScore(
        in candidates: [BASCandidatePath]
    ) -> Double {
        guard candidates.count > 1 else {
            return candidates.isEmpty ? 0 : 1
        }

        var pairwiseScores: [Double] = []
        for lhsIndex in candidates.indices {
            for rhsIndex in candidates.indices where rhsIndex > lhsIndex {
                let lhs = candidates[lhsIndex]
                let rhs = candidates[rhsIndex]
                let textDistance = lhs.actionSummary == rhs.actionSummary ? 0.0 : 0.35
                let titleDistance = lhs.title == rhs.title ? 0.0 : 0.15
                let evidenceDistance = 1 - Self.overlapScore(lhs.requiredEvidence, rhs.requiredEvidence)
                let numericDistance = (
                    abs(lhs.reversibility - rhs.reversibility)
                        + abs(lhs.expectedBenefit - rhs.expectedBenefit)
                        + abs(lhs.expectedCost - rhs.expectedCost)
                ) / 3

                pairwiseScores.append(
                    min(1, textDistance + titleDistance + evidenceDistance * 0.20 + numericDistance * 0.30)
                )
            }
        }

        return min(max(Self.average(pairwiseScores), 0), 1)
    }

    private static func overlapScore(
        _ lhs: [String],
        _ rhs: [String]
    ) -> Double {
        let lhsSet = Set(lhs.map { $0.lowercased() })
        let rhsSet = Set(rhs.map { $0.lowercased() })
        let union = lhsSet.union(rhsSet)
        guard union.isEmpty == false else {
            return 1
        }
        return Double(lhsSet.intersection(rhsSet).count) / Double(union.count)
    }

    private static func average(
        _ values: [Double]
    ) -> Double {
        guard values.isEmpty == false else {
            return 0
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func stoppingMode(
        for stopReason: BASThoughtStopReason?
    ) -> BASConvergenceStoppingMode {
        switch stopReason {
        case .maxLoopsReached:
            return .leaseEnd
        case .blocked, .replaced:
            return .sovereignCut
        case .guardTakeover:
            return .guardTakeover
        case .none, .candidateStable, .riskConverged, .uncertaintyBelowThreshold:
            return .converged
        }
    }

    private static func recommendedNextStep(
        from thoughtFrame: BASThoughtFrame,
        dominanceOrder: [String]
    ) -> String {
        guard let preferredCandidateID = dominanceOrder.first,
              let preferredCandidate = thoughtFrame.candidates.first(where: { $0.candidateID == preferredCandidateID }) else {
            return "Hold the current guard path."
        }

        return preferredCandidate.actionSummary
    }

    private static func recommendedPermitMode(
        riskLevel: BASBrainRiskLevel,
        gsiScore: Double,
        irreversibility: Double,
        boundaryConflict: Double
    ) -> BASActionPermitMode {
        if riskLevel == .extreme || gsiScore >= 0.80 || irreversibility >= 0.88 || boundaryConflict >= 0.85 {
            return .block
        }
        if riskLevel == .high || gsiScore >= 0.68 || irreversibility >= 0.72 {
            return .delay
        }
        if riskLevel == .medium {
            return .compare
        }
        return .answer
    }

    private static func saferPermitMode(
        _ lhs: BASActionPermitMode,
        _ rhs: BASActionPermitMode
    ) -> BASActionPermitMode {
        permitStrictness(lhs) >= permitStrictness(rhs) ? lhs : rhs
    }

    private static func permitStrictness(
        _ mode: BASActionPermitMode
    ) -> Int {
        switch mode {
        case .answer:
            return 0
        case .mirror:
            return 1
        case .compare:
            return 2
        case .delay:
            return 3
        case .draftOnly:
            return 4
        case .localOnly:
            return 5
        case .replace:
            return 6
        case .block:
            return 7
        case .escalate:
            return 8
        }
    }

    private static func allowedDomains(
        for mode: BASActionPermitMode
    ) -> [String] {
        switch mode {
        case .answer:
            return ["bounded_reply", "plain_language"]
        case .mirror:
            return ["bounded_reply", "mirror"]
        case .compare:
            return ["bounded_reply", "comparison"]
        case .delay:
            return ["bounded_reply"]
        case .draftOnly:
            return ["bounded_reply", "draft"]
        case .localOnly:
            return ["bounded_reply", "local_action"]
        case .replace:
            return ["bounded_reply", "protective_alternative"]
        case .block:
            return ["protective_receipt"]
        case .escalate:
            return ["protective_receipt", "sovereign_alert"]
        }
    }

    private static func forbiddenDomains(
        for mode: BASActionPermitMode
    ) -> [String] {
        switch mode {
        case .answer:
            return []
        case .mirror:
            return ["tool_commit", "memory_commit", "host_commit"]
        case .compare:
            return ["tool_commit"]
        case .delay:
            return ["tool_commit", "memory_commit"]
        case .draftOnly:
            return ["tool_commit", "memory_commit", "host_commit"]
        case .localOnly:
            return ["memory_commit", "host_commit", "public_release"]
        case .replace:
            return ["tool_commit", "memory_commit", "host_commit"]
        case .block:
            return ["tool_commit", "memory_commit", "host_commit", "high_consequence_decode"]
        case .escalate:
            return ["tool_commit", "memory_commit", "host_commit", "public_release", "high_consequence_decode"]
        }
    }

    private static func unique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard isEmpty == false else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
