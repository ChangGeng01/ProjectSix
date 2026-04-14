import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

extension BASHostRiskLevel {
    var eBrainRiskLevel: BASBrainRiskLevel {
        switch self {
        case .low:
            .low
        case .medium:
            .medium
        case .high:
            .high
        }
    }
}

private extension BASHostCurrentBrain {
    var hasProtectiveBoundary: Bool {
        boundaryMode == .localOnlyProtective
    }

    var isCalibrationUnstable: Bool {
        calibrationStatus == .watch || calibrationStatus == .drifting
    }

    var hasTrustDriftSignals: Bool {
        riskFlags.contains(.lowTrustLoad) || riskFlags.contains(.retrievalInstability)
    }

    var hostGuardrailPressure: Double {
        var pressure = 0.0
        if hasProtectiveBoundary { pressure += 0.18 }
        if calibrationStatus == .watch { pressure += 0.10 }
        if calibrationStatus == .drifting { pressure += 0.18 }
        pressure += min(0.18, Double(boundaryConstraints.count) * 0.03)
        pressure += min(0.15, Double(calibrationAlerts.count) * 0.03)
        pressure += min(0.12, Double(failureGuardCount) * 0.02)
        pressure += min(0.14, Double(riskFlags.count) * 0.035)
        return min(0.65, pressure)
    }
}

private struct BASHostRuntimeEBrainPowerClockService: BASPowerClockServicing {
    let prefersPureLocal: Bool
    let currentBrain: BASHostCurrentBrain

    func planBudget(
        deviceState: BASDeviceState,
        taskPing: String,
        riskHint: BASBrainRiskLevel?
    ) -> BASBudgetFrame {
        let hint = riskHint ?? .low
        let urgencyDetected = BASHostRuntimeEBrainPromptAnalyzer.containsUrgency(taskPing)
        let guardedBudgetRequired = currentBrain.hasProtectiveBoundary || currentBrain.hasTrustDriftSignals
        let runMode: BASEBrainRunMode = switch hint {
        case .low:
            guardedBudgetRequired ? .engage : (urgencyDetected ? .engage : .sentinel)
        case .medium:
            guardedBudgetRequired ? .deepLoop : .engage
        case .high:
            .guarded
        case .extreme:
            .guarded
        }

        let loops: Int = switch hint {
        case .low: 1
        case .medium: 2
        case .high: 4
        case .extreme: 2
        }
        let loopFloor = currentBrain.hasProtectiveBoundary ? 2 : 1

        let candidates: Int = switch hint {
        case .low: 2
        case .medium: 3
        case .high: 3
        case .extreme: 2
        }

        let precision: BASPrecisionProfile = switch hint {
        case .low: .balanced
        case .medium: .balanced
        case .high, .extreme: .protected
        }
        let resolvedPrecision: BASPrecisionProfile = currentBrain.isCalibrationUnstable ? .protected : precision

        let thermalGuard: BASThermalGuardLevel = switch deviceState.thermalLevel {
        case .nominal:
            .nominal
        case .warm:
            .watch
        case .hot:
            .throttle
        case .critical:
            .emergency
        }

        let guardedLoops = thermalGuard == .throttle ? max(1, loops - 1) : loops
        let resolvedLoops = max(loopFloor, guardedLoops + (currentBrain.isCalibrationUnstable && hint < .high ? 1 : 0))
        let guardedCandidates = thermalGuard == .throttle ? max(1, candidates - 1) : candidates
        let resolvedCandidates = min(4, max(currentBrain.hasProtectiveBoundary ? 2 : 1, guardedCandidates))
        let preliminaryBudget = BASBudgetFrame(
            runMode: runMode,
            maxLoops: resolvedLoops,
            maxCandidates: resolvedCandidates,
            maxDecodeTokens: hint >= .high ? 220 : (currentBrain.isCalibrationUnstable ? 192 : 160),
            retrievalDepth: hint >= .high ? 4 : (hint == .medium || currentBrain.hasTrustDriftSignals ? 3 : 2),
            precisionProfile: resolvedPrecision,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: thermalGuard,
            maintenanceAllowed: false
        )
        return BASBudgetFrame(
            runMode: preliminaryBudget.runMode,
            maxLoops: preliminaryBudget.maxLoops,
            maxCandidates: preliminaryBudget.maxCandidates,
            maxDecodeTokens: preliminaryBudget.maxDecodeTokens,
            retrievalDepth: preliminaryBudget.retrievalDepth,
            precisionProfile: preliminaryBudget.precisionProfile,
            deviceRoute: routeDevice(deviceState: deviceState, budget: preliminaryBudget),
            thermalGuardLevel: preliminaryBudget.thermalGuardLevel,
            maintenanceAllowed: scheduleMaintenance(deviceState: deviceState, budget: preliminaryBudget)
        )
    }

    func routeDevice(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> BASDeviceRoute {
        if budget.runMode == .guarded {
            return prefersPureLocal ? .hybridLocal : .coreNPU
        }
        if deviceState.npuAvailable {
            return budget.runMode == .sentinel ? .scoutNPU : .coreNPU
        }
        return budget.runMode == .sentinel ? .scoutCPU : .coreGPU
    }

    func scheduleMaintenance(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> Bool {
        guard budget.runMode != .guarded else { return false }
        guard deviceState.foregroundState != .foreground else { return false }
        return deviceState.thermalLevel == .nominal && deviceState.batteryLevel > 0.35
    }
}

private struct BASHostRuntimeEBrainHostProfileService: BASHostProfileServicing {
    let configuration: BASHostConfiguration
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain

    func resolveHost(
        hostID: String,
        contextFrame: BASContextFrame?,
        riskCard: BASRiskCard?
    ) -> BASHostProfile {
        BASHostProfile(
            hostID: hostID,
            identityTags: [
                configuration.workflowBehavior.hostNamespace,
                currentBrain.roleID,
                request.workflowProfile.rawValue
            ],
            tonePreference: tonePreference,
            longTermGoals: currentBrain.dominantGoals,
            noGoZones: orderedUnique(
                currentBrain.activeConstraints
                    + currentBrain.boundaryConstraints.map(\.rawValue)
                    + currentBrain.calibrationAlerts.map { $0.rawValue }
                    + [currentBrain.boundaryHeadline]
            ),
            riskThresholds: BASHostRiskThresholds(
                caution: 0.45,
                protective: 0.72,
                block: 0.92
            ),
            memoryPermissions: BASMemoryPermissions(
                allowHotWrites: true,
                allowWarmWrites: true,
                allowColdWrites: false,
                requireReviewForColdWrites: true
            ),
            workRoutines: request.title.map { [$0] } ?? [],
            relationshipRefs: [currentBrain.relationshipBoundary],
            styleConstraints: orderedUnique([
                currentBrain.workflowTitle,
                "risk-first",
                "local-first",
                currentBrain.identityPosture.rawValue,
                currentBrain.identityInitiative.rawValue,
                currentBrain.boundaryMode.rawValue
            ]),
            updatePolicy: BASHostUpdatePolicy(
                requiresReview: true,
                allowsRollback: true,
                allowsDelete: true,
                allowsFreeze: true
            ),
            activeVersion: "\(configuration.workflowBehavior.hostNamespace).v1"
        )
    }

    func applyHostGate(
        profile: BASHostProfile,
        taskType: BASContextTaskType,
        riskCard: BASRiskCard?,
        confidence: Double
    ) -> Double {
        let baseCap = min(confidence, currentBrain.confidenceCeiling)
        guard let riskCard else { return baseCap }

        let modeCap: Double = switch riskCard.riskLevel {
        case .low: 1.0
        case .medium: 0.72
        case .high: 0.42
        case .extreme: 0.20
        }
        let calibrationCap: Double = switch currentBrain.calibrationStatus {
        case .stable: 1.0
        case .watch: 0.85
        case .drifting: 0.70
        }
        let taskCap: Double = switch taskType {
        case .highConsequence, .highPressure, .manipulationRisk:
            0.78
        default:
            1.0
        }

        return min(
            baseCap,
            modeCap,
            calibrationCap,
            taskCap,
            max(0.20, 1 - currentBrain.hostGuardrailPressure)
        )
    }

    func rollbackHostVersion(
        profile: BASHostProfile,
        to versionID: String
    ) -> BASHostVersion {
        BASHostVersion(
            versionID: versionID,
            changedFields: ["tonePreference", "longTermGoals"],
            reason: "host runtime rollback",
            rollbackRef: profile.activeVersion,
            approvedByPolicy: true
        )
    }

    private var tonePreference: String {
        switch request.workflowProfile {
        case .primary:
            "brief_grounded"
        case .comparative:
            "structured_comparative"
        case .reflective:
            "calm_reflective"
        }
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

private struct BASHostRuntimeEBrainContextService: BASContextServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain

    func analyzeContext(
        userInput: String,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASContextFrame {
        let manipulationHints = BASHostRuntimeEBrainPromptAnalyzer.manipulationHints(in: userInput)
        let trustInstability = currentBrain.hasTrustDriftSignals ? 0.12 : 0
        let guardedPressure = currentBrain.hasProtectiveBoundary ? 0.10 : 0
        return BASContextFrame(
            utterance: userInput,
            taskType: taskType(for: userInput, manipulationHints: manipulationHints),
            emotionalLoad: min(
                1,
                (request.riskLevel == .high ? 0.72 : (request.workflowProfile == .reflective ? 0.46 : 0.30))
                    + (currentBrain.calibrationStatus == .drifting ? 0.08 : 0)
            ),
            timePressure: min(
                1,
                (request.kind == .reopen ? 0.66 : (BASHostRuntimeEBrainPromptAnalyzer.containsUrgency(userInput) ? 0.74 : 0.24))
                    + guardedPressure
            ),
            relationPattern: currentBrain.relationshipBoundary,
            ambiguityScore: min(1, (request.workflowProfile == .comparative ? 0.42 : 0.28) + trustInstability),
            consequenceLevel: min(
                1,
                (request.riskLevel == .high ? 0.84 : (request.riskLevel == .medium ? 0.56 : 0.26))
                    + guardedPressure
            ),
            manipulationHints: orderedUnique(manipulationHints + currentBrain.riskFlags.map(\.rawValue)),
            hostRelevance: min(1.0, max(0.4, Double(hostContext.longTermGoals.count) * 0.2))
        )
    }

    private func taskType(for userInput: String, manipulationHints: [String]) -> BASContextTaskType {
        if !manipulationHints.isEmpty || currentBrain.hasTrustDriftSignals {
            return .manipulationRisk
        }
        if request.riskLevel == .high {
            return request.kind == .reopen ? .highPressure : .highConsequence
        }
        switch request.workflowProfile {
        case .primary:
            return .task
        case .comparative:
            return .choice
        case .reflective:
            return .chat
        }
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

private struct BASHostRuntimeEBrainDecomposeService: BASDecomposeServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let projection: BASBrainProjection

    func decompose(
        contextFrame: BASContextFrame,
        memoryHints: [String]
    ) -> BASDecomposeFrame {
        BASDecomposeFrame(
            facts: [
                "Host request: \(request.prompt)",
                "Workflow: \(currentBrain.workflowTitle)"
            ] + (request.detail.map { ["Detail: \($0)"] } ?? []),
            goals: currentBrain.dominantGoals.isEmpty ? ["Keep the next move bounded."] : currentBrain.dominantGoals,
            emotions: inferredEmotions(from: contextFrame),
            unknowns: inferredUnknowns(),
            contradictions: checkContradiction(
                contextFrame: contextFrame,
                decomposeFrame: BASDecomposeFrame()
            ),
            pressureSignals: contextFrame.timePressure > 0.6 ? ["time_pressure"] : [],
            manipulationSignals: contextFrame.manipulationHints,
            mirrorText: mirror(contextFrame: contextFrame, decomposeFrame: BASDecomposeFrame())
        )
    }

    func mirror(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> String {
        "The host is asking for a \(currentBrain.workflowTitle.lowercased()) pass, but the system should keep the next move bounded before acting."
    }

    func checkContradiction(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> [String] {
        let referenceTerms = currentBrain.activeConstraints
            + currentBrain.boundaryConstraints.map(\.rawValue)
            + currentBrain.calibrationAlerts.map { $0.rawValue }
        return referenceTerms.filter { constraint in
            let normalizedConstraint = constraint.lowercased()
            return BASHostRuntimeEBrainPromptAnalyzer.tokenized(request.prompt).contains {
                normalizedConstraint.contains($0)
            }
        }
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
        return unknowns
    }
}

private struct BASHostRuntimeEBrainMemoryService: BASMemoryServicing {
    let projection: BASBrainProjection
    let currentBrain: BASHostCurrentBrain

    func retrieve(
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASMemoryBundle {
        let recordAtoms = projection.records.prefix(budget.retrievalDepth).map(memoryAtom(from:))
        let eventAtoms = projection.recentEvents.prefix(max(0, budget.retrievalDepth - recordAtoms.count)).map(memoryAtom(from:))
        let atoms = Array(recordAtoms) + Array(eventAtoms)

        return BASMemoryBundle(
            atoms: atoms,
            retrievalTags: orderedUnique(
                projection.records.prefix(budget.retrievalDepth).flatMap { [$0.kind.rawValue, $0.sourceType] }
                    + projection.recentEvents.flatMap(\.tags)
                    + currentBrain.retrievalTags
                    + [currentBrain.boundaryMode.rawValue]
                    + currentBrain.riskFlags.map(\.rawValue)
            ),
            conflictRefs: atoms.filter(\.frozen).map(\.memoryID),
            activeHostVersion: hostContext.activeVersion
        )
    }

    func promote(
        atom: BASMemoryAtom,
        hostContext: BASHostProfile
    ) -> BASPromotionState {
        atom.frozen ? .frozen : atom.promotionState
    }

    func freeze(memoryID: String) -> Bool {
        projection.records.contains { $0.id.uuidString == memoryID && $0.sensitivity == .high }
    }

    private func memoryAtom(from record: BASGovernedMemory) -> BASMemoryAtom {
        BASMemoryAtom(
            memoryID: record.id.uuidString,
            summary: record.content,
            contentType: contentType(for: record.tier),
            source: record.sourceType,
            timestamp: record.lastConfirmedAt ?? .now,
            confidence: record.confidence,
            emotionalWeight: record.kind == .semantic ? 0.55 : 0.22,
            riskRelevance: record.sensitivity == .high ? 0.82 : 0.38,
            hostRelevance: record.kind == .profile ? 0.88 : 0.54,
            conflictFingerprint: record.id.uuidString,
            promotionState: promotionState(for: record.governanceStatus),
            frozen: record.governanceStatus == .archived
        )
    }

    private func memoryAtom(from event: BASEventRecord) -> BASMemoryAtom {
        BASMemoryAtom(
            memoryID: event.id.uuidString,
            summary: event.content,
            contentType: .hot,
            source: event.entrySourceID ?? "event",
            timestamp: event.timestamp,
            confidence: 0.72,
            emotionalWeight: event.kind == .semantic ? 0.55 : 0.20,
            riskRelevance: event.kind == .situational ? 0.48 : 0.28,
            hostRelevance: 0.52,
            conflictFingerprint: event.id.uuidString,
            promotionState: .candidate,
            frozen: false
        )
    }

    private func contentType(for tier: BASMemoryTier) -> BASMemoryAtomContentType {
        switch tier {
        case .hot:
            .hot
        case .warm:
            .warm
        case .cold:
            .cold
        }
    }

    private func promotionState(for status: BASMemoryGovernanceStatus) -> BASPromotionState {
        switch status {
        case .candidate:
            .candidate
        case .governed:
            .admitted
        case .archived:
            .frozen
        case .quarantined, .rejected:
            .retired
        }
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

private struct BASHostRuntimeEBrainLoopService: BASLoopServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain

    func proposePaths(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> [BASCandidatePath] {
        let directConfidence = min(
            currentBrain.confidenceCeiling,
            request.riskLevel == .high ? 0.42 : 0.72
        )
        let directCostBoost = currentBrain.hostGuardrailPressure + min(0.12, Double(currentBrain.failureGuardCount) * 0.03)
        let direct = BASCandidatePath(
            candidateID: "path.direct",
            title: directTitle,
            actionSummary: "Move directly with the host's current workflow and minimal friction.",
            requiredEvidence: request.riskLevel >= .medium ? ["Confirm the missing facts first."] : [],
            expectedBenefit: request.workflowProfile == .primary ? 0.82 : 0.64,
            expectedCost: min(1, (request.riskLevel == .high ? 0.70 : 0.28) + directCostBoost),
            reversibility: max(0.12, (request.riskLevel == .high ? 0.34 : 0.74) - currentBrain.hostGuardrailPressure * 0.35),
            confidence: directConfidence
        )
        let bounded = BASCandidatePath(
            candidateID: "path.bounded",
            title: boundedTitle,
            actionSummary: "Slow the decision down, keep the boundary visible, and ask for the next safest move.",
            requiredEvidence: ["Clarify one missing fact before committing."],
            expectedBenefit: min(1, (request.riskLevel == .high ? 0.86 : 0.74) + currentBrain.hostGuardrailPressure * 0.25),
            expectedCost: 0.32,
            reversibility: min(1, 0.86 + currentBrain.hostGuardrailPressure * 0.10),
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
        candidates.map { candidate in
            BASForecastItem(
                candidateID: candidate.candidateID,
                shortTermOutcome: candidate.candidateID == "path.direct"
                    ? "Fast movement with thinner safety margin."
                    : "More friction, but a clearer next step.",
                midTermOutcome: candidate.candidateID == "path.direct"
                    ? "Higher chance of avoidable rework."
                    : "Better odds of a bounded decision that matches host intent.",
                worstCase: candidate.candidateID == "path.direct"
                    ? "The turn overshoots the boundary."
                    : "The host feels slowed down more than expected.",
                uncertainty: candidate.candidateID == "path.direct" ? 0.58 : 0.34,
                affectedRelations: [memoryBundle.activeHostVersion ?? "host.current"]
            )
        }
    }

    func critique(
        candidates: [BASCandidatePath],
        forecasts: [BASForecastItem],
        hostContext: BASHostProfile
    ) -> [BASCritiqueItem] {
        candidates.map { candidate in
            BASCritiqueItem(
                candidateID: candidate.candidateID,
                critiqueType: critiqueType(for: candidate),
                critiqueText: critiqueText(for: candidate),
                severity: candidate.candidateID == "path.direct" && hostContext.noGoZones.count > 1 ? 0.72 : 0.40
            )
        }
    }

    func iterate(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> BASThoughtFrame {
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
            hostContext: BASHostProfile(hostID: memoryBundle.activeHostVersion ?? "host.runtime")
        )
        return BASThoughtFrame(
            stepIndex: min(
                budget.maxLoops,
                max(
                    1,
                    request.riskLevel == .high || currentBrain.isCalibrationUnstable
                        ? min(3, budget.maxLoops)
                        : 1
                )
            ),
            decomposeRef: "hostkit.decompose",
            memoryRefs: memoryBundle.atoms.map(\.memoryID),
            candidates: candidates,
            forecasts: forecasts,
            critiques: critiques,
            stabilityScore: max(0.36, (request.riskLevel == .high ? 0.68 : 0.84) - currentBrain.hostGuardrailPressure * 0.20),
            stopReason: request.riskLevel == .high || currentBrain.calibrationStatus == .drifting
                ? .riskConverged
                : .candidateStable
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
        if candidate.candidateID == "path.direct" && currentBrain.hasProtectiveBoundary {
            return "The direct path conflicts with the host's protective boundary mode."
        }
        if candidate.candidateID == "path.direct" {
            return "The direct path still has thin evidence."
        }
        return "This path is safer, but it adds friction."
    }
}

private struct BASHostRuntimeEBrainTriSelfService: BASTriSelfServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain

    func mergeChoice(
        thoughtFrame: BASThoughtFrame,
        hostContext: BASHostProfile
    ) -> ([BASTriSelfScore], BASMergedChoice) {
        let scores = thoughtFrame.candidates.map { candidate in
            let initiativeLift = currentBrain.identityInitiative == .assertive ? 0.06 : 0
            let idScore = candidate.expectedBenefit - candidate.expectedCost * 0.4 + initiativeLift
            let egoScore = candidate.reversibility * 0.5 + min(candidate.confidence, currentBrain.confidenceCeiling) * 0.5
            let superegoPenalty = candidate.candidateID == "path.direct" && (request.riskLevel == .high || currentBrain.hasProtectiveBoundary) ? 0.45 : 0
            let superegoScore = max(0, candidate.reversibility - superegoPenalty)
            let postureWeights: (Double, Double, Double) = switch currentBrain.identityPosture {
            case .reflective:
                (0.24, 0.34, 0.42)
            case .coaching:
                (0.28, 0.38, 0.34)
            case .protective:
                (0.18, 0.30, 0.52)
            }
            let mergedScore = max(
                0,
                (idScore * postureWeights.0) + (egoScore * postureWeights.1) + (superegoScore * postureWeights.2)
            )
            let veto = candidate.candidateID == "path.direct"
                && (request.riskLevel == .high || currentBrain.hasProtectiveBoundary || currentBrain.calibrationStatus == .drifting)
            return BASTriSelfScore(
                candidateID: candidate.candidateID,
                idScore: idScore,
                egoScore: egoScore,
                superegoScore: superegoScore,
                mergedScore: mergedScore,
                veto: veto
            )
        }

        let selectedScore = scores
            .filter { !$0.veto }
            .max(by: { $0.mergedScore < $1.mergedScore })
            ?? scores.max(by: { $0.mergedScore < $1.mergedScore })

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

        let mergedChoice = BASMergedChoice(
            candidateID: selectedCandidate.candidateID,
            title: selectedCandidate.title,
            actionSummary: selectedCandidate.actionSummary,
            vetoApplied: selectedScore?.veto ?? false,
            vetoReasonCodes: selectedScore?.veto == true ? ["triself.superego_veto"] : []
        )

        return (scores, mergedChoice)
    }
}

private struct BASHostRuntimeEBrainRiskService: BASRiskServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain

    func calibrateRisk(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> BASRiskCard {
        let critiqueSeverity = thoughtFrame.critiques.map(\.severity).max() ?? 0
        let directCandidatePenalty = thoughtFrame.candidates.contains { $0.candidateID == "path.direct" && $0.reversibility < 0.5 } ? 0.12 : 0
        let vetoPressure = triScores.contains(where: \.veto) ? 0.08 : 0
        let totalRisk = min(
            1,
            (contextFrame.emotionalLoad * 0.20)
            + (contextFrame.timePressure * 0.15)
            + (contextFrame.consequenceLevel * 0.25)
            + (Double(contextFrame.manipulationHints.count) * 0.10)
            + (critiqueSeverity * 0.20)
            + directCandidatePenalty
            + currentBrain.hostGuardrailPressure
            + vetoPressure
        )
        let level: BASBrainRiskLevel = switch totalRisk {
        case ..<0.35:
            .low
        case ..<0.65:
            .medium
        case ..<0.85:
            .high
        default:
            .extreme
        }

        return BASRiskCard(
            totalRisk: totalRisk,
            riskLevel: level,
            factors: riskFactors(for: contextFrame, thoughtFrame: thoughtFrame),
            uncertainty: thoughtFrame.forecasts.map(\.uncertainty).max() ?? 0.22,
            irreversibility: 1 - (thoughtFrame.candidates.map(\.reversibility).max() ?? 0.5),
            manipulationStrength: min(1, Double(contextFrame.manipulationHints.count) * 0.35),
            gsiScore: computeGSI(contextFrame: contextFrame, thoughtFrame: thoughtFrame),
            recommendedMode: recommendedMode(for: level, contextFrame: contextFrame)
        )
    }

    func computeGSI(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame
    ) -> Double {
        min(
            1,
            Double(contextFrame.manipulationHints.count) * 0.26
                + (contextFrame.timePressure > 0.6 ? 0.12 : 0)
                + (currentBrain.hasTrustDriftSignals ? 0.18 : 0)
                + (currentBrain.calibrationAlerts.contains(BASMemory.BASCalibrationAlert.lowTrustLoad) ? 0.10 : 0)
        )
    }

    func gateAction(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> (BASRiskCard, BASActionPermit) {
        let card = calibrateRisk(
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            triScores: triScores,
            budget: budget
        )
        let permit: BASActionPermit = switch card.riskLevel {
        case .low:
            BASActionPermit(
                mode: .answer,
                reasonCodes: ["risk.low"],
                requireSecondCheck: false,
                outputLengthCap: 220,
                tonePolicy: "grounded_clear",
                templatePolicy: "direct_answer"
            )
        case .medium:
            BASActionPermit(
                mode: .compare,
                reasonCodes: ["risk.medium", "compare.paths"] + (currentBrain.hasProtectiveBoundary ? ["boundary.protective"] : []),
                requireSecondCheck: false,
                outputLengthCap: 240,
                tonePolicy: "structured_compare",
                templatePolicy: "two_path_compare"
            )
        case .high:
            BASActionPermit(
                mode: currentBrain.hasProtectiveBoundary ? .replace : .delay,
                reasonCodes: ["risk.high", "protective_delay"] + protectiveReasonCodes,
                requireSecondCheck: true,
                outputLengthCap: 220,
                tonePolicy: "calm_protective",
                templatePolicy: currentBrain.hasProtectiveBoundary ? "replace_with_guarded_alternative" : "delay_with_alternative"
            )
        case .extreme:
            BASActionPermit.protectiveBlock(reasonCodes: ["risk.extreme", "protective_block"] + protectiveReasonCodes)
        }
        return (card, permit)
    }

    private func riskFactors(
        for contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame
    ) -> [String] {
        var factors: [String] = []
        if contextFrame.emotionalLoad > 0.6 { factors.append("emotion_high") }
        if contextFrame.timePressure > 0.6 { factors.append("time_pressure") }
        if contextFrame.consequenceLevel > 0.6 { factors.append("consequence_high") }
        if !contextFrame.manipulationHints.isEmpty { factors.append("manipulation_signals") }
        if thoughtFrame.critiques.contains(where: { $0.critiqueType == .boundaryConflict }) { factors.append("boundary_conflict") }
        if currentBrain.hasProtectiveBoundary { factors.append("host_protective_boundary") }
        if currentBrain.calibrationStatus == .drifting { factors.append("calibration_drifting") }
        if currentBrain.hasTrustDriftSignals { factors.append("trust_drift") }
        return factors
    }

    private func recommendedMode(
        for level: BASBrainRiskLevel,
        contextFrame: BASContextFrame
    ) -> BASActionPermitMode {
        switch level {
        case .low:
            .answer
        case .medium:
            currentBrain.hasProtectiveBoundary ? .delay : .compare
        case .high:
            currentBrain.hasProtectiveBoundary ? .replace : .delay
        case .extreme:
            contextFrame.manipulationHints.isEmpty ? .replace : .block
        }
    }

    private var protectiveReasonCodes: [String] {
        var reasons: [String] = []
        if currentBrain.hasProtectiveBoundary {
            reasons.append("boundary.protective")
        }
        if currentBrain.calibrationStatus == .drifting {
            reasons.append("calibration.drifting")
        }
        if currentBrain.hasTrustDriftSignals {
            reasons.append("trust.low")
        }
        return reasons
    }
}

private struct BASHostRuntimeEBrainActionService: BASActionServicing {
    func render(
        choice: BASMergedChoice,
        riskCard: BASRiskCard,
        permit: BASActionPermit,
        hostContext: BASHostProfile
    ) -> BASRenderedOutput {
        switch permit.mode {
        case .answer:
            return BASRenderedOutput(
                mode: .answer,
                headline: choice.title,
                body: choice.actionSummary,
                alternativeActions: [],
                explanationCodes: permit.reasonCodes
            )
        case .compare:
            return BASRenderedOutput(
                mode: .compare,
                headline: "Compare the two safest paths first",
                body: choice.actionSummary,
                alternativeActions: ["Name one tradeoff before acting."],
                explanationCodes: permit.reasonCodes
            )
        case .delay:
            return BASRenderedOutput(
                mode: .delay,
                headline: "Delay the move and re-check the boundary",
                body: choice.actionSummary,
                alternativeActions: ["Gather one more fact.", "Return after the pressure cools."],
                explanationCodes: permit.reasonCodes
            )
        case .block:
            return BASRenderedOutput(
                mode: .block,
                headline: "Do not take the direct high-risk path",
                body: "The current path is too likely to outrun the boundary, so the system is blocking direct release.",
                alternativeActions: ["Pause the action.", "Choose the safer bounded alternative."],
                explanationCodes: permit.reasonCodes
            )
        case .replace:
            return BASRenderedOutput(
                mode: .replace,
                headline: "Replace the risky move with a safer next step",
                body: "The direct action is not permitted, so the system is switching to a safer bounded move.",
                alternativeActions: ["Use a lower-pressure template.", "Ask for one missing fact first."],
                explanationCodes: permit.reasonCodes
            )
        }
    }
}

private struct BASHostRuntimeEBrainEvolutionService: BASEvolutionServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain

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
        return [
            BASUpdateTicket(
                ticketID: "ticket.\(UUID().uuidString.lowercased())",
                sessionRef: "\(request.kind.rawValue).\(request.workflowProfile.rawValue)",
                summary: output.body,
                memoryWriteSuggestion: protectiveWriteSuggestion,
                hostProfileChangeSuggestion: currentBrain.calibrationStatus == .drifting
                    ? "Review host gate strength before promoting any new long-term preference."
                    : nil,
                ruleCandidateRef: output.mode == .block ? "rule.protective_block" : nil,
                confidence: output.mode == .answer ? 0.62 : 0.80,
                conflictFlag: output.mode == .block || output.mode == .replace,
                requiresReview: true
            )
        ]
    }
}

private enum BASHostRuntimeEBrainPromptAnalyzer {
    static func containsUrgency(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return ["now", "immediately", "urgent", "asap", "tonight", "must"].contains {
            normalized.contains($0)
        }
    }

    static func manipulationHints(in text: String) -> [String] {
        let normalized = text.lowercased()
        let rules: [(String, String)] = [
            ("now", "time_pressure"),
            ("immediately", "time_pressure"),
            ("must", "authority_pressure"),
            ("for your own good", "benevolent_control"),
            ("everyone says", "social_pressure"),
            ("you always", "history_rewrite")
        ]
        return rules.compactMap { normalized.contains($0.0) ? $0.1 : nil }
    }

    static func tokenized(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }
}

extension BASHostRuntime {
    public func buildEBrainTurn(
        request: BASHostSessionRequest,
        currentBrain: BASHostCurrentBrain,
        projection: BASBrainProjection,
        deviceStateOverride: BASDeviceState? = nil,
        now: Date = .now
    ) -> BASEBrainTurnResult {
        makeEBrainTurn(
            for: request,
            currentBrain: currentBrain,
            projection: projection,
            deviceStateOverride: deviceStateOverride,
            now: now
        )
    }

    func makeEBrainTurn(
        for request: BASHostSessionRequest,
        currentBrain: BASHostCurrentBrain,
        projection: BASBrainProjection,
        deviceStateOverride: BASDeviceState?,
        now: Date
    ) -> BASEBrainTurnResult {
        let deviceState = deviceStateOverride ?? BASDeviceState(
            batteryLevel: configuration.prefersPureLocal ? 0.78 : 0.64,
            thermalLevel: request.riskLevel == .high ? .warm : .nominal,
            memoryFreeMB: request.workflowProfile == .reflective ? 2048 : 3072,
            networkState: configuration.prefersPureLocal ? .constrained : .online,
            foregroundState: .foreground,
            cpuLoad: request.riskLevel == .high ? 0.34 : 0.18,
            gpuLoad: request.workflowProfile == .comparative ? 0.22 : 0.10,
            npuAvailable: true,
            latencyBudgetMs: request.riskLevel == .high ? 1800 : 1200
        )

        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: BASHostRuntimeEBrainPowerClockService(
                prefersPureLocal: configuration.prefersPureLocal,
                currentBrain: currentBrain
            ),
            hostProfileService: BASHostRuntimeEBrainHostProfileService(
                configuration: configuration,
                request: request,
                currentBrain: currentBrain
            ),
            contextService: BASHostRuntimeEBrainContextService(
                request: request,
                currentBrain: currentBrain
            ),
            decomposeService: BASHostRuntimeEBrainDecomposeService(
                request: request,
                currentBrain: currentBrain,
                projection: projection
            ),
            memoryService: BASHostRuntimeEBrainMemoryService(
                projection: projection,
                currentBrain: currentBrain
            ),
            loopService: BASHostRuntimeEBrainLoopService(
                request: request,
                currentBrain: currentBrain
            ),
            triSelfService: BASHostRuntimeEBrainTriSelfService(
                request: request,
                currentBrain: currentBrain
            ),
            riskService: BASHostRuntimeEBrainRiskService(
                request: request,
                currentBrain: currentBrain
            ),
            actionService: BASHostRuntimeEBrainActionService(),
            evolutionService: BASHostRuntimeEBrainEvolutionService(
                request: request,
                currentBrain: currentBrain
            )
        )

        return coordinator.runTurn(
            BASEBrainTurnRequest(
                userInput: request.prompt,
                deviceState: deviceState,
                hostID: "\(configuration.workflowBehavior.hostNamespace).\(request.workflowProfile.rawValue)",
                recordedAt: now,
                riskHint: request.riskLevel.eBrainRiskLevel,
                feedbackEvent: nil,
                activeKillSwitches: request.activeKillSwitches
            )
        )
    }
}
