import Foundation
import BASPolicy

public struct BASNeuralThoughtMaterialization: Equatable, Sendable {
    public var candidateFrontier: BASCandidateFrontier?
    public var counterfactualBundles: [BASCounterfactualBundle]?
    public var critiqueBundles: [BASCritiqueBundle]?

    public init(
        candidateFrontier: BASCandidateFrontier? = nil,
        counterfactualBundles: [BASCounterfactualBundle]? = nil,
        critiqueBundles: [BASCritiqueBundle]? = nil
    ) {
        self.candidateFrontier = candidateFrontier
        self.counterfactualBundles = counterfactualBundles
        self.critiqueBundles = critiqueBundles
    }
}

public struct BASNeuralPublicThoughtProjection: Equatable, Sendable {
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
        BASNeuralThoughtMaterialization(
            candidateFrontier: buildCandidateFrontier(from: thoughtFrame),
            counterfactualBundles: buildCounterfactualBundles(from: thoughtFrame.forecasts),
            critiqueBundles: buildCritiqueBundles(
                from: thoughtFrame.critiques,
                candidates: thoughtFrame.candidates
            )
        )
    }

    public static func materializePublicProjection(
        thoughtFrame: BASThoughtFrame
    ) -> BASNeuralPublicThoughtProjection {
        BASNeuralPublicThoughtProjection(
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
                requireSecondCheck: actionPermit.requireSecondCheck,
                outputLengthCap: actionPermit.outputLengthCap,
                tonePolicy: actionPermit.tonePolicy,
                templatePolicy: actionPermit.templatePolicy,
                reasonCodes: reasonCodes,
                allowedDomains: allowedDomains(for: permitMode),
                forbiddenDomains: forbiddenDomains(for: permitMode)
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
            requireSecondCheck: actionPermit.requireSecondCheck,
            tonePolicy: actionPermit.tonePolicy,
            templatePolicy: actionPermit.templatePolicy,
            reasonCodes: reasonCodes,
            sovereignBound: !(thoughtFrame.organMap?.sovereignConstraints.isEmpty ?? true)
        )
    }

    public static func buildCandidateFrontier(
        from thoughtFrame: BASThoughtFrame
    ) -> BASCandidateFrontier? {
        guard thoughtFrame.candidates.isEmpty == false else {
            return nil
        }

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

        return BASCandidateFrontier(
            candidateIDs: candidateIDs,
            dominanceOrder: dominanceOrder,
            reversiblePaths: reversiblePaths,
            guardPaths: guardPaths,
            frontierWidth: candidateIDs.count
        )
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
            let evidenceGap = critiqueSeverity(.evidenceGap, in: candidateCritiques)
            let manipulationRisk = critiqueSeverity(.manipulationRisk, in: candidateCritiques)
            let emotionalBias = critiqueSeverity(.emotionalBias, in: candidateCritiques)
            let boundaryConflict = critiqueSeverity(.boundaryConflict, in: candidateCritiques)

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
        case .compare:
            return 1
        case .delay:
            return 2
        case .replace:
            return 3
        case .block:
            return 4
        }
    }

    private static func allowedDomains(
        for mode: BASActionPermitMode
    ) -> [String] {
        switch mode {
        case .answer:
            return ["bounded_reply", "plain_language"]
        case .compare:
            return ["bounded_reply", "comparison"]
        case .delay:
            return ["bounded_reply"]
        case .replace:
            return ["bounded_reply", "protective_alternative"]
        case .block:
            return ["protective_receipt"]
        }
    }

    private static func forbiddenDomains(
        for mode: BASActionPermitMode
    ) -> [String] {
        switch mode {
        case .answer:
            return []
        case .compare:
            return ["tool_commit"]
        case .delay:
            return ["tool_commit", "memory_commit"]
        case .replace:
            return ["tool_commit", "memory_commit", "host_commit"]
        case .block:
            return ["tool_commit", "memory_commit", "host_commit", "high_consequence_decode"]
        }
    }

    private static func unique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
