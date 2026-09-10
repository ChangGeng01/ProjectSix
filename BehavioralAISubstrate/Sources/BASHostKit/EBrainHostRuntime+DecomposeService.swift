import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainDecomposeService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainDecomposeService: BASDecomposeServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let projection: BASBrainProjection
    let hostConstitution: BASHostConstitution?

    func decompose(
        contextFrame: BASContextFrame,
        memoryHints: [String]
    ) -> BASDecomposeFrame {
        let baseGoals = currentBrain.dominantGoals.isEmpty ? ["Keep the next move bounded."] : currentBrain.dominantGoals
        let facts = orderedUnique([
            "Host request: \(request.prompt)",
            "Workflow: \(currentBrain.workflowTitle)"
        ] + (request.detail.map { ["Detail: \($0)"] } ?? []) + constitutionFacts())
        let goals = orderedUnique(baseGoals + constitutionGoalLines())
        let emotions = inferredEmotions(from: contextFrame)
        let unknowns = inferredUnknowns()
        let contradictions = checkContradiction(
            contextFrame: contextFrame,
            decomposeFrame: BASDecomposeFrame()
        )
        let factShards = buildFactShards(from: facts)
        let claimShards = buildClaimShards(contextFrame: contextFrame)
        let goalSpineLocal = buildGoalSpineLocal(
            from: goals,
            contradictions: contradictions
        )
        let unknownRecords = buildUnknownRecords(from: unknowns)
        let contradictionRecords = buildContradictionRecords(from: contradictions)
        let pressureVectors = buildPressureVectors(contextFrame: contextFrame)
        let manipulationPatterns = buildManipulationPatterns(contextFrame: contextFrame)
        let boundaryTouches = buildBoundaryTouches(
            contextFrame: contextFrame,
            contradictions: contradictionRecords,
            manipulationPatterns: manipulationPatterns
        )
        let mirrorDraft = buildMirrorDraft(
            contextFrame: contextFrame,
            facts: facts,
            goals: goals,
            unknowns: unknowns,
            pressureVectors: pressureVectors,
            boundaryTouches: boundaryTouches
        )
        let canonicalFrame = buildCanonicalFrame(
            facts: facts,
            goals: goals,
            unknowns: unknowns,
            contradictionRecords: contradictionRecords,
            pressureVectors: pressureVectors,
            manipulationPatterns: manipulationPatterns,
            boundaryTouches: boundaryTouches
        )

        return BASDecomposeFrame(
            facts: facts,
            goals: goals,
            emotions: emotions,
            unknowns: unknowns,
            contradictions: contradictions,
            pressureSignals: orderedUnique(
                pressureVectors.map(legacyPressureSignal(for:))
                    + (contextFrame.manipulationHints.contains("time_pressure") ? ["time_pressure"] : [])
            ),
            manipulationSignals: orderedUnique(
                contextFrame.manipulationHints
                    + manipulationPatterns.map(legacyManipulationSignal(for:))
            ),
            mirrorText: mirrorDraft.summary,
            factShards: factShards,
            claimShards: claimShards,
            goalSpineLocal: goalSpineLocal,
            unknownRecords: unknownRecords,
            contradictionRecords: contradictionRecords,
            pressureVectors: pressureVectors,
            manipulationPatterns: manipulationPatterns,
            boundaryTouches: boundaryTouches,
            mirrorDraft: mirrorDraft,
            canonicalFrame: canonicalFrame
        )
    }

    func mirror(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> String {
        if let summary = decomposeFrame.mirrorDraft?.summary, summary.isEmpty == false {
            return summary
        }
        if let hostConstitution,
           let leadRelation = hostConstitution.relationGravity.highConsequenceLinks.first {
            return "The host is asking for a \(currentBrain.workflowTitle.lowercased()) pass, and the system should keep \(leadRelation) context visible while staying bounded before acting."
        }
        return "The host is asking for a \(currentBrain.workflowTitle.lowercased()) pass, but the system should keep the next move bounded before acting."
    }

    func checkContradiction(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> [String] {
        let referenceTerms = currentBrain.activeConstraints
            + currentBrain.boundaryConstraints.map(\.rawValue)
            + currentBrain.calibrationAlerts.map { $0.rawValue }
        var contradictions = referenceTerms.filter { constraint in
            let normalizedConstraint = constraint.lowercased()
            return BASHostRuntimeEBrainPromptAnalyzer.tokenized(request.prompt).contains {
                normalizedConstraint.contains($0)
            }
        }
        if request.riskLevel >= .high && currentBrain.hasEvidenceCaveatLoad {
            contradictions.append("evidence strength conflicts with action urgency")
        }
        if contextFrame.timePressure > 0.75 && currentBrain.hasProtectiveBoundary {
            contradictions.append("timing pressure conflicts with bounded action")
        }
        return orderedUnique(contradictions)
    }

    private func inferredEmotions(from contextFrame: BASContextFrame) -> [String] {
        if request.riskLevel == .high {
            return currentBrain.calibrationStatus == .drifting ? ["elevated_pressure", "trust_drift"] : ["elevated_pressure"]
        }
        if contextFrame.taskType == .choice {
            return ["uncertainty"]
        }
        if request.workflowProfile == .reflective {
            return ["reflective"]
        }
        return ["focused"]
    }

    private func inferredUnknowns() -> [String] {
        var unknowns: [String] = []
        if projection.records.isEmpty {
            unknowns.append("No governed records were loaded for this turn.")
        }
        if request.riskLevel >= .medium {
            unknowns.append("Need more evidence before any irreversible move.")
        }
        if request.workflowProfile == .comparative {
            unknowns.append("The best tradeoff is not fully resolved yet.")
        }
        if currentBrain.calibrationStatus == .drifting {
            unknowns.append("Calibration drift suggests the turn should keep more uncertainty visible.")
        }
        if currentBrain.hasEvidenceCaveatLoad {
            unknowns.append("Evidence remains caveated, so the turn should keep uncertainty explicit.")
        }
        return unknowns
    }

    private func constitutionFacts() -> [String] {
        guard let hostConstitution else { return [] }

        var facts: [String] = []
        if hostConstitution.narrativeLoom.currentPhase.isEmpty == false {
            facts.append("Constitution phase: \(hostConstitution.narrativeLoom.currentPhase)")
        }
        if hostConstitution.relationGravity.highConsequenceLinks.isEmpty == false {
            facts.append(
                "High-consequence relations: \(hostConstitution.relationGravity.highConsequenceLinks.joined(separator: ", "))"
            )
        }
        if hostConstitution.goalSpine.stageState.isEmpty == false {
            facts.append("Goal spine stage: \(hostConstitution.goalSpine.stageState)")
        }
        return facts
    }

    private func constitutionGoalLines() -> [String] {
        guard let hostConstitution else { return [] }

        let goalLines = hostConstitution.goalSpine.priorityOrder + hostConstitution.goalSpine.goals
        return orderedUnique(goalLines).map { "Honor constitution goal: \($0)" }
    }

    private func buildFactShards(
        from facts: [String]
    ) -> [BASFactShard] {
        facts.enumerated().map { index, fact in
            BASFactShard(
                shardID: "fact-\(index + 1)",
                text: fact,
                status: .reported,
                sourceKind: sourceKind(for: fact),
                certainty: sourceKind(for: fact) == .systemInference ? 0.62 : 0.84,
                timeScope: "current_turn"
            )
        }
    }

    private func buildClaimShards(
        contextFrame: BASContextFrame
    ) -> [BASClaimShard] {
        var claims: [BASClaimShard] = [
            BASClaimShard(
                claimID: "claim-command-1",
                text: request.prompt,
                claimType: .command,
                supportLevel: 0.92,
                sourceKind: .currentInput,
                sourceRef: "prompt"
            )
        ]
        if let detail = request.detail, detail.isEmpty == false {
            claims.append(
                BASClaimShard(
                    claimID: "claim-detail-1",
                    text: detail,
                    claimType: .factClaim,
                    supportLevel: 0.66,
                    sourceKind: .sessionDetail,
                    sourceRef: "detail"
                )
            )
        }
        if contextFrame.taskType == .manipulationRisk {
            claims.append(
                BASClaimShard(
                    claimID: "claim-risk-1",
                    text: "Current turn contains coercive or authority-shaped steering pressure.",
                    claimType: .accusation,
                    supportLevel: 0.57,
                    sourceKind: .systemInference,
                    sourceRef: "context.analysis"
                )
            )
        }
        return claims
    }

    private func buildGoalSpineLocal(
        from goals: [String],
        contradictions: [String]
    ) -> BASGoalSpineLocal? {
        guard goals.isEmpty == false else { return nil }
        let surfaceGoals = Array(goals.prefix(2))
        let midGoals = goals.count > 2 ? [goals[2]] : surfaceGoals
        let deepFallback = hostConstitution?.goalSpine.priorityOrder.first
            ?? currentBrain.dominantGoals.first
            ?? "Keep the next move bounded."
        return BASGoalSpineLocal(
            surfaceGoals: orderedUnique(surfaceGoals),
            midGoals: orderedUnique(midGoals),
            deepGoals: [deepFallback],
            conflicts: contradictions,
            hostAlignmentScore: hostConstitution == nil ? 0.71 : 0.84
        )
    }

    private func buildUnknownRecords(
        from unknowns: [String]
    ) -> [BASUnknownRecord] {
        unknowns.enumerated().map { index, unknown in
            BASUnknownRecord(
                unknownID: "unknown-\(index + 1)",
                kind: unknownKind(for: unknown),
                summary: unknown,
                sourceKind: .systemInference,
                blocking: true
            )
        }
    }

    private func buildContradictionRecords(
        from contradictions: [String]
    ) -> [BASContradictionRecord] {
        contradictions.enumerated().map { index, contradiction in
            BASContradictionRecord(
                nodeID: "contradiction-\(index + 1)",
                kind: contradictionKind(for: contradiction),
                summary: contradiction,
                refs: ["prompt", "constraints"],
                severity: request.riskLevel == .high ? 0.78 : 0.63,
                unresolved: true
            )
        }
    }

    private func buildPressureVectors(
        contextFrame: BASContextFrame
    ) -> [BASPressureVector] {
        var vectors: [BASPressureVector] = []
        if contextFrame.timePressure > 0.45 {
            vectors.append(
                BASPressureVector(
                    vectorID: "pressure-time",
                    kind: .time,
                    direction: .compressing,
                    strength: contextFrame.timePressure,
                    authenticity: max(0.55, contextFrame.timePressure),
                    sourceRef: "context.timePressure"
                )
            )
        }
        if contextFrame.relationPattern.contains("high_consequence")
            || hostConstitution?.relationGravity.highConsequenceLinks.isEmpty == false {
            vectors.append(
                BASPressureVector(
                    vectorID: "pressure-relationship",
                    kind: .relationship,
                    direction: .leveraging,
                    strength: max(0.58, contextFrame.hostRelevance),
                    authenticity: 0.78,
                    sourceRef: "context.relationPattern"
                )
            )
        }
        if contextFrame.consequenceLevel > 0.45 || request.riskLevel >= .medium {
            vectors.append(
                BASPressureVector(
                    vectorID: "pressure-consequence",
                    kind: .consequence,
                    direction: .amplifying,
                    strength: max(contextFrame.consequenceLevel, request.riskLevel == .high ? 0.82 : 0.58),
                    authenticity: 0.73,
                    sourceRef: "request.riskLevel"
                )
            )
        }
        if currentBrain.hasProtectiveBoundary || currentBrain.failureGuardCount > 0 {
            vectors.append(
                BASPressureVector(
                    vectorID: "pressure-responsibility",
                    kind: .responsibility,
                    direction: .constraining,
                    strength: min(1, 0.46 + (Double(currentBrain.failureGuardCount) * 0.08)),
                    authenticity: 0.86,
                    sourceRef: "currentBrain.guardrails"
                )
            )
        }
        return vectors
    }

    private func buildManipulationPatterns(
        contextFrame: BASContextFrame
    ) -> [BASManipulationPattern] {
        orderedUnique(contextFrame.manipulationHints).enumerated().map { index, hint in
            BASManipulationPattern(
                patternID: "manipulation-\(index + 1)",
                kind: manipulationKind(for: hint),
                summary: hint,
                refs: ["context.manipulationHints"],
                confidence: hint == "authority_pressure" ? 0.76 : max(0.58, contextFrame.timePressure)
            )
        }
    }

    private func legacyPressureSignal(
        for vector: BASPressureVector
    ) -> String {
        switch vector.kind {
        case .time:
            "time_pressure"
        case .relationship:
            "relationship_pressure"
        case .shame:
            "shame_pressure"
        case .consequence:
            "consequence_pressure"
        case .resource:
            "resource_pressure"
        case .responsibility:
            "responsibility_pressure"
        }
    }

    private func legacyManipulationSignal(
        for pattern: BASManipulationPattern
    ) -> String {
        switch pattern.kind {
        case .gaslightPrecursor:
            "history_rewrite"
        case .shame:
            "shame_pressure"
        case .authorityMask:
            "authority_pressure"
        case .coerciveUrgency:
            "time_pressure"
        case .relationalLeverage:
            "relational_leverage"
        }
    }

    private func buildBoundaryTouches(
        contextFrame: BASContextFrame,
        contradictions: [BASContradictionRecord],
        manipulationPatterns: [BASManipulationPattern]
    ) -> [BASBoundaryTouch] {
        var touches: [BASBoundaryTouch] = []
        if currentBrain.boundaryConstraints.isEmpty == false {
            touches.append(
                BASBoundaryTouch(
                    touchID: "boundary-host",
                    domain: .host,
                    level: contextFrame.consequenceLevel > 0.7 ? .breachRisk : .approach,
                    summary: "Host boundary constraints are active for this turn.",
                    refs: currentBrain.boundaryConstraints.map(\.rawValue)
                )
            )
        }
        if currentBrain.hasProtectiveBoundary || contradictions.isEmpty == false {
            touches.append(
                BASBoundaryTouch(
                    touchID: "boundary-system",
                    domain: .system,
                    level: contradictions.isEmpty ? .brush : .approach,
                    summary: "System guardrails should stay visible before committing.",
                    refs: contradictions.map(\.summary)
                )
            )
        }
        if request.riskLevel >= .high && manipulationPatterns.isEmpty == false {
            touches.append(
                BASBoundaryTouch(
                    touchID: "boundary-sovereign",
                    domain: .sovereign,
                    level: .approach,
                    summary: "High-risk steering pressure is nearing sovereign review territory.",
                    refs: manipulationPatterns.map(\.summary)
                )
            )
        }
        return touches
    }

    private func buildMirrorDraft(
        contextFrame: BASContextFrame,
        facts: [String],
        goals: [String],
        unknowns: [String],
        pressureVectors: [BASPressureVector],
        boundaryTouches: [BASBoundaryTouch]
    ) -> BASMirrorDraft {
        let mode: BASMirrorMode = request.riskLevel >= .high || boundaryTouches.isEmpty == false ? .hard : .soft
        let leadPressure = pressureVectors.first?.kind.rawValue ?? "pressure"
        let leadGoal = goals.first ?? "keep the next move bounded"
        let leadRelation = hostConstitution?.relationGravity.highConsequenceLinks.first
            ?? contextFrame.relationPattern

        let summary: String
        if mode == .hard {
            summary = "This turn carries \(leadPressure) around \(leadRelation), and the system should mirror the pressure, keep \(leadGoal.lowercased()) visible, and check missing facts before committing."
        } else {
            summary = "This turn is asking for a \(currentBrain.workflowTitle.lowercased()) pass, so the system should keep \(leadGoal.lowercased()) visible before acting."
        }

        return BASMirrorDraft(
            draftID: "mirror-1",
            mode: mode,
            summary: summary,
            calibrationPoints: Array(facts.prefix(2)),
            omittedSpeculations: unknowns,
            toneGuard: mode == .hard ? "calibration_before_commit" : "gentle_calibration"
        )
    }

    private func buildCanonicalFrame(
        facts: [String],
        goals: [String],
        unknowns: [String],
        contradictionRecords: [BASContradictionRecord],
        pressureVectors: [BASPressureVector],
        manipulationPatterns: [BASManipulationPattern],
        boundaryTouches: [BASBoundaryTouch]
    ) -> BASCanonicalCognitiveFrame {
        let routeHint: String
        if request.riskLevel >= .high || boundaryTouches.contains(where: { $0.domain == .sovereign }) {
            routeHint = "mirror_before_commit"
        } else if unknowns.isEmpty == false {
            routeHint = "clarify_unknowns"
        } else {
            routeHint = "bounded_continue"
        }

        return BASCanonicalCognitiveFrame(
            ccfID: "ccf-1",
            stableFacts: facts,
            activeGoals: goals,
            activeUnknowns: unknowns,
            keyPressures: orderedUnique(pressureVectors.map { $0.kind.rawValue }),
            keyContradictions: contradictionRecords.map(\.summary),
            manipulationWatch: orderedUnique(manipulationPatterns.map { $0.kind.rawValue }),
            boundaryWatch: boundaryTouches.map { "\($0.domain.rawValue):\($0.level.rawValue)" },
            routeHint: routeHint
        )
    }

    private func sourceKind(
        for fact: String
    ) -> BASDecomposeSourceKind {
        if fact.hasPrefix("Host request:") {
            return .currentInput
        }
        if fact.hasPrefix("Detail:") {
            return .sessionDetail
        }
        if fact.hasPrefix("Workflow:") {
            return .workflowState
        }
        if fact.hasPrefix("Constitution ")
            || fact.hasPrefix("High-consequence relations:")
            || fact.hasPrefix("Goal spine stage:") {
            return .hostConstitution
        }
        return .systemInference
    }

    private func unknownKind(
        for unknown: String
    ) -> BASUnknownKind {
        let normalized = unknown.lowercased()
        if normalized.contains("permission") || normalized.contains("authorized") {
            return .unresolvedPermission
        }
        if normalized.contains("constraint") {
            return .missingConstraint
        }
        if normalized.contains("role") || normalized.contains("other side") {
            return .missingRole
        }
        if normalized.contains("ambig") || normalized.contains("uncertain") {
            return .ambiguity
        }
        return .missingFact
    }

    private func contradictionKind(
        for contradiction: String
    ) -> BASContradictionKind {
        let normalized = contradiction.lowercased()
        if normalized.contains("history") {
            return .historical
        }
        if normalized.contains("evidence") || normalized.contains("support") {
            return .evidential
        }
        if normalized.contains("role") || normalized.contains("boundary") {
            return .role
        }
        return .textual
    }

    private func manipulationKind(
        for hint: String
    ) -> BASManipulationKind {
        let normalized = hint.lowercased()
        if normalized.contains("gaslight") {
            return .gaslightPrecursor
        }
        if normalized.contains("shame") {
            return .shame
        }
        if normalized.contains("authority") {
            return .authorityMask
        }
        if normalized.contains("relation") {
            return .relationalLeverage
        }
        return .coerciveUrgency
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
