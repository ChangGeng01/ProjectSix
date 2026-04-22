import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainLoopService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainLoopService: BASLoopServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let hostConstitution: BASHostConstitution?

    func proposePaths(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> [BASCandidatePath] {
        let directConfidence = min(
            currentBrain.confidenceCeiling,
            request.riskLevel == .high ? 0.42 : 0.72
        )
        let guardrailPressure = currentBrain.hostGuardrailPressure(using: tuning)
        let directCostBoost = guardrailPressure + min(
            tuning.guardrailPressure.failureGuardCap,
            Double(currentBrain.failureGuardCount) * tuning.guardrailPressure.failureGuardUnit
        )
        let direct = BASCandidatePath(
            candidateID: "path.direct",
            title: directTitle,
            actionSummary: "Move directly with the host's current workflow and minimal friction.",
            requiredEvidence: request.riskLevel >= .medium ? ["Confirm the missing facts first."] : [],
            expectedBenefit: request.workflowProfile == .primary ? 0.82 : 0.64,
            expectedCost: min(1, (request.riskLevel == .high ? 0.70 : 0.28) + directCostBoost),
            reversibility: max(0.12, (request.riskLevel == .high ? 0.34 : 0.74) - guardrailPressure * 0.35),
            confidence: directConfidence
        )
        let bounded = BASCandidatePath(
            candidateID: "path.bounded",
            title: boundedTitle,
            actionSummary: "Slow the decision down, keep the boundary visible, and ask for the next safest move.",
            requiredEvidence: ["Clarify one missing fact before committing."],
            expectedBenefit: min(1, (request.riskLevel == .high ? 0.86 : 0.74) + guardrailPressure * 0.25),
            expectedCost: 0.32,
            reversibility: min(1, 0.86 + guardrailPressure * 0.10),
            confidence: min(currentBrain.confidenceCeiling + 0.18, 0.84)
        )
        let reflective = BASCandidatePath(
            candidateID: "path.reflective",
            title: "Mirror the pressure before committing",
            actionSummary: "Name the tradeoff and the pressure signal before acting.",
            requiredEvidence: ["Keep the unknowns visible."],
            expectedBenefit: 0.70,
            expectedCost: 0.26,
            reversibility: 0.91,
            confidence: min(currentBrain.confidenceCeiling + 0.12, 0.78)
        )

        return Array([direct, bounded, reflective].prefix(budget.maxCandidates))
    }

    func forecast(
        candidates: [BASCandidatePath],
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle
    ) -> [BASForecastItem] {
        return candidates.map { candidate in
            let highConsequenceRelations = constitutionHighConsequenceRelations()
            return BASForecastItem(
                candidateID: candidate.candidateID,
                shortTermOutcome: candidate.candidateID == "path.direct"
                    ? "Fast movement with thinner safety margin."
                    : "More friction, but a clearer next step.",
                midTermOutcome: candidate.candidateID == "path.direct"
                    ? "Higher chance of avoidable rework."
                    : "Better odds of a bounded decision that matches host intent.",
                worstCase: candidate.candidateID == "path.direct"
                    ? directWorstCase(highConsequenceRelations: highConsequenceRelations)
                    : "The host feels slowed down more than expected.",
                uncertainty: candidate.candidateID == "path.direct" ? 0.58 : 0.34,
                affectedRelations: orderedUnique(
                    [memoryBundle.activeHostVersion ?? "host.current"] + highConsequenceRelations
                )
            )
        }
    }

    func critique(
        candidates: [BASCandidatePath],
        forecasts: [BASForecastItem],
        hostContext: BASHostProfile
    ) -> [BASCritiqueItem] {
        return candidates.map { candidate in
            let baseSeverity = candidate.candidateID == "path.direct" && hostContext.noGoZones.count > 1 ? 0.72 : 0.40
            return BASCritiqueItem(
                candidateID: candidate.candidateID,
                critiqueType: critiqueType(for: candidate),
                critiqueText: critiqueText(for: candidate),
                severity: min(1, baseSeverity + constitutionCritiqueSeverityIncrement(for: candidate))
            )
        }
    }

    func iterate(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> BASThoughtFrame {
        let desiredLoopCount = desiredLoopCount()
        let appliedLoopCount = min(budget.maxLoops, desiredLoopCount)
        let candidates = proposePaths(
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            budget: budget
        )
        let forecasts = forecast(
            candidates: candidates,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle
        )
        let critiques = critique(
            candidates: candidates,
            forecasts: forecasts,
            hostContext: projectedLoopHostContext(memoryBundle: memoryBundle)
        )
        return BASThoughtFrame(
            stepIndex: appliedLoopCount,
            decomposeRef: "hostkit.decompose",
            memoryRefs: memoryBundle.atoms.map(\.memoryID),
            candidates: candidates,
            forecasts: forecasts,
            critiques: critiques,
            stabilityScore: max(0.36, (request.riskLevel == .high ? 0.68 : 0.84) - currentBrain.hostGuardrailPressure(using: tuning) * 0.20),
            stopReason: desiredLoopCount > budget.maxLoops
                ? .maxLoopsReached
                : (request.riskLevel == .high || currentBrain.calibrationStatus == .drifting
                    ? .riskConverged
                    : .candidateStable)
        )
    }

    private func projectedLoopHostContext(
        memoryBundle: BASMemoryBundle
    ) -> BASHostProfile {
        guard let hostConstitution else {
            return BASHostProfile(hostID: memoryBundle.activeHostVersion ?? "host.runtime")
        }

        var projected = hostConstitution.projectedHostProfile()
        if let activeHostVersion = memoryBundle.activeHostVersion,
           activeHostVersion.isEmpty == false {
            projected.activeVersion = activeHostVersion
        }
        return projected
    }

    private func desiredLoopCount() -> Int {
        max(
            1,
            request.riskLevel == .high || currentBrain.isCalibrationUnstable ? 3 : 1
        )
    }

    private var directTitle: String {
        switch request.workflowProfile {
        case .primary:
            "Direct host answer"
        case .comparative:
            "Choose the strongest path now"
        case .reflective:
            "Reflect without adding extra structure"
        }
    }

    private var boundedTitle: String {
        switch request.riskLevel {
        case .high:
            "Delay and hold the boundary"
        case .medium:
            "Compare before committing"
        case .low:
            "Answer with one bounded next step"
        }
    }

    private func critiqueType(for candidate: BASCandidatePath) -> BASCritiqueType {
        if candidate.candidateID == "path.direct" && request.riskLevel == .high {
            return .boundaryConflict
        }
        if candidate.candidateID == "path.direct" {
            return .evidenceGap
        }
        return .emotionalBias
    }

    private func critiqueText(for candidate: BASCandidatePath) -> String {
        if candidate.candidateID == "path.direct" && request.riskLevel == .high {
            return "Direct movement is too likely to outrun the active boundary."
        }
        if candidate.candidateID == "path.direct",
           let relationSummary = constitutionHighConsequenceRelationSummary() {
            return "The direct path risks outrunning the high-consequence relation around \(relationSummary)."
        }
        if candidate.candidateID == "path.direct" && currentBrain.hasProtectiveBoundary {
            return "The direct path conflicts with the host's protective boundary mode."
        }
        if candidate.candidateID == "path.direct" {
            return "The direct path still has thin evidence."
        }
        return "This path is safer, but it adds friction."
    }

    private func constitutionCritiqueSeverityIncrement(
        for candidate: BASCandidatePath
    ) -> Double {
        guard candidate.candidateID == "path.direct",
              let hostConstitution else {
            return 0
        }

        var increment = 0.0
        if hostConstitution.relationGravity.highConsequenceLinks.isEmpty == false {
            increment += 0.16
        }
        if constitutionPrefersBoundedAction(in: hostConstitution) {
            increment += 0.08
        }
        return min(0.28, increment)
    }

    private func constitutionHighConsequenceRelationSummary() -> String? {
        let links = constitutionHighConsequenceRelations()
        guard links.isEmpty == false else { return nil }
        return links.joined(separator: ", ")
    }

    private func constitutionHighConsequenceRelations() -> [String] {
        hostConstitution?.relationGravity.highConsequenceLinks ?? []
    }

    private func directWorstCase(highConsequenceRelations: [String]) -> String {
        guard highConsequenceRelations.isEmpty == false else {
            return "The turn overshoots the boundary."
        }

        return "The turn overshoots the boundary and distorts context around \(highConsequenceRelations.joined(separator: ", "))."
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

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
