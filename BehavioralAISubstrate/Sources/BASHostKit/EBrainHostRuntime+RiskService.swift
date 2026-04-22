import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainRiskService extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

struct BASHostRuntimeEBrainRiskService: BASRiskServicing {
    let request: BASHostSessionRequest
    let currentBrain: BASHostCurrentBrain
    let tuning: BASEBrainRuntimeSynthesisPolicy
    let hostConstitution: BASHostConstitution?

    func calibrateRisk(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> BASRiskCard {
        let riskTuning = tuning.risk
        let critiqueSeverity = thoughtFrame.critiques.map(\.severity).max() ?? 0
        let directCandidatePenalty = thoughtFrame.candidates.contains {
            $0.candidateID == "path.direct"
                && $0.reversibility < riskTuning.directCandidateLowReversibilityThreshold
        } ? riskTuning.directCandidatePenalty : 0
        let vetoPressure = triScores.contains(where: \.veto) ? riskTuning.vetoPressureIncrement : 0
        let constitutionSignals = constitutionGuardSignals(
            thoughtFrame: thoughtFrame,
            triScores: triScores
        )
        let courtSignals = courtSignals(thoughtFrame: thoughtFrame)
        let presenceSignals = presenceRiskSignals(contextFrame: contextFrame)
        let totalRisk = min(
            1,
            (contextFrame.emotionalLoad * riskTuning.emotionalLoadWeight)
            + (contextFrame.timePressure * riskTuning.timePressureWeight)
            + (contextFrame.consequenceLevel * riskTuning.consequenceWeight)
            + (Double(contextFrame.manipulationHints.count) * riskTuning.manipulationHintWeight)
            + (critiqueSeverity * riskTuning.critiqueSeverityWeight)
            + directCandidatePenalty
            + currentBrain.hostGuardrailPressure(using: tuning)
            + vetoPressure
            + constitutionSignals.riskIncrement
            + courtSignals.riskIncrement
            + presenceSignals.riskIncrement
        )
        let level: BASBrainRiskLevel = switch totalRisk {
        case ..<riskTuning.mediumThreshold:
            .low
        case ..<riskTuning.highThreshold:
            .medium
        case ..<riskTuning.extremeThreshold:
            .high
        default:
            .extreme
        }

        let recommendedMode = recommendedMode(for: level, contextFrame: contextFrame)
        let stackedModes: [BASActionPermitMode] = switch recommendedMode {
        case .compare:
            [.mirror]
        case .delay:
            [.draftOnly]
        case .replace:
            [.localOnly]
        case .block:
            [.escalate]
        case .answer, .mirror, .draftOnly, .localOnly, .escalate:
            []
        }

        return BASRiskCard(
            totalRisk: totalRisk,
            riskLevel: level,
            factors: riskFactors(
                for: contextFrame,
                thoughtFrame: thoughtFrame,
                constitutionFactorCodes: constitutionSignals.factorCodes,
                courtFactorCodes: courtSignals.factorCodes,
                presenceFactorCodes: presenceSignals.factorCodes
            ),
            uncertainty: thoughtFrame.forecasts.map(\.uncertainty).max() ?? riskTuning.defaultForecastUncertainty,
            irreversibility: 1 - (thoughtFrame.candidates.map(\.reversibility).max() ?? riskTuning.defaultCandidateReversibility),
            manipulationStrength: max(
                min(1, Double(contextFrame.manipulationHints.count) * riskTuning.manipulationStrengthUnit),
                presenceSignals.manipulationStrength
            ),
            gsiScore: computeGSI(contextFrame: contextFrame, thoughtFrame: thoughtFrame),
            recommendedMode: recommendedMode,
            stackedModes: stackedModes,
            assertionCeiling: level >= .high ? "guarded" : "standard",
            delayType: recommendedMode == .delay ? (contextFrame.timePressure > 0.6 ? "cool_down" : "evidence_wait") : nil,
            substituteType: recommendedMode == .replace ? "local_only_action" : (recommendedMode == .block ? "cooling_step" : nil),
            sovereignHintLevel: recommendedMode == .block ? "high" : (level >= .high ? "medium" : nil)
        )
    }

    func computeGSI(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame
    ) -> Double {
        let riskTuning = tuning.risk
        let presenceSignals = presenceRiskSignals(contextFrame: contextFrame)
        return min(
            1,
            Double(contextFrame.manipulationHints.count) * riskTuning.gsiHintWeight
                + (contextFrame.timePressure > riskTuning.gsiTimePressureThreshold ? riskTuning.gsiTimePressureIncrement : 0)
                + (currentBrain.hasTrustDriftSignals ? riskTuning.gsiTrustDriftIncrement : 0)
                + (currentBrain.calibrationAlerts.contains(BASMemory.BASCalibrationAlert.lowTrustLoad) ? riskTuning.gsiLowTrustAlertIncrement : 0)
                + presenceSignals.gsiIncrement
        )
    }

    func riskLevel(for score: Double) -> BASBrainRiskLevel {
        let riskTuning = tuning.risk
        switch score {
        case ..<riskTuning.mediumThreshold:
            return .low
        case ..<riskTuning.highThreshold:
            return .medium
        case ..<riskTuning.extremeThreshold:
            return .high
        default:
            return .extreme
        }
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
        let constitutionSignals = constitutionGuardSignals(
            thoughtFrame: thoughtFrame,
            triScores: triScores
        )
        let courtSignals = courtSignals(thoughtFrame: thoughtFrame)
        let constitutionReasonCodes = constitutionSignals.reasonCodes
        let courtReasonCodes = courtSignals.reasonCodes
        let permit: BASActionPermit = switch card.riskLevel {
        case .low:
            BASActionPermit(
                mode: .answer,
                stackedModes: card.stackedModes,
                reasonCodes: ["risk.low"] + constitutionReasonCodes + courtReasonCodes + uncertaintyReasonCodes,
                allowedDomains: ["text.reply", "text.summary"],
                assertionCeiling: card.assertionCeiling,
                toolScope: "bounded",
                memoryScope: "standard",
                requireMirror: false,
                requireCompare: false,
                requireSecondCheck: false,
                outputLengthCap: 220,
                tonePolicy: "grounded_clear",
                templatePolicy: "direct_answer"
            )
        case .medium:
            BASActionPermit(
                mode: .compare,
                stackedModes: [.mirror],
                reasonCodes: ["risk.medium", "compare.paths"] + constitutionReasonCodes + courtReasonCodes + uncertaintyReasonCodes + (currentBrain.hasProtectiveBoundary ? ["boundary.protective"] : []),
                allowedDomains: ["text.compare", "text.mirror"],
                blockedDomains: ["tool.read", "tool.write", "memory.write", "host.write"],
                assertionCeiling: "guarded",
                toolScope: "none",
                memoryScope: "standard",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: false,
                outputLengthCap: 240,
                tonePolicy: "structured_compare",
                templatePolicy: "two_path_compare"
            )
        case .high:
            BASActionPermit(
                mode: currentBrain.hasProtectiveBoundary ? .replace : .delay,
                stackedModes: currentBrain.hasProtectiveBoundary ? [.localOnly] : [.draftOnly],
                reasonCodes: ["risk.high", "protective_delay"] + constitutionReasonCodes + courtReasonCodes + protectiveReasonCodes,
                allowedDomains: currentBrain.hasProtectiveBoundary ? ["text.replace", "local.action"] : ["text.delay", "draft.note"],
                blockedDomains: ["tool.write", "memory.write", "host.write", "public.release"],
                assertionCeiling: "guarded",
                toolScope: currentBrain.hasProtectiveBoundary ? "local_only" : "none",
                memoryScope: "review_only",
                requireMirror: true,
                requireCompare: true,
                requireSecondCheck: true,
                outputLengthCap: 220,
                tonePolicy: "calm_protective",
                templatePolicy: currentBrain.hasProtectiveBoundary ? "replace_with_guarded_alternative" : "delay_with_alternative",
                delayWindow: currentBrain.hasProtectiveBoundary ? nil : (card.delayType ?? "cool_down"),
                substituteRequired: true
            )
        case .extreme:
            BASActionPermit.protectiveBlock(reasonCodes: ["risk.extreme", "protective_block"] + constitutionReasonCodes + courtReasonCodes + protectiveReasonCodes)
        }
        return (card, permit)
    }

    func buildRiskDecisionPackage(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> BASRiskDecisionPackage {
        let (riskCard, actionPermit) = gateAction(
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            triScores: triScores,
            budget: budget
        )
        let fieldStem = "\(thoughtFrame.decomposeRef).\(thoughtFrame.stepIndex)"
        let selectedCandidateID = self.riskPreferredCandidateID(
            from: thoughtFrame,
            triScores: triScores
        )
        let selectedEvidenceDebt = self.riskEvidenceDebt(
            for: selectedCandidateID,
            in: thoughtFrame
        )
        let selectedBreakpointHints = self.riskSovereignBreakpointHints(
            for: selectedCandidateID,
            in: thoughtFrame
        )
        let weakPrediction = thoughtFrame.uncertaintyLedger?.weakPredictions.contains(selectedCandidateID) == true
        let confidenceFloor = thoughtFrame.uncertaintyLedger?.confidenceFloor ?? max(0, 1 - riskCard.uncertainty)
        let supportLevel = max(
            0,
            min(
                1,
                ((thoughtFrame.convergenceCertificate?.stabilityScore ?? confidenceFloor) + confidenceFloor) / 2
                    - (selectedEvidenceDebt?.debtWeight ?? 0) * 0.45
            )
        )
        let missingEvidence = orderedUnique(
            (selectedEvidenceDebt?.missingEvidence ?? [])
                + (weakPrediction ? (thoughtFrame.uncertaintyLedger?.unresolvedUnknowns ?? []) : [])
        )
        let harmRadius = BASHarmRadiusMap(
            radiusID: "harm-radius.\(fieldStem)",
            privateImpact: contextFrame.emotionalLoad,
            relationImpact: contextFrame.consequenceLevel,
            workflowImpact: contextFrame.ambiguityScore,
            publicImpact: contextFrame.timePressure,
            longTermTrace: max(riskCard.irreversibility, contextFrame.consequenceHorizon?.longTermTrace ?? 0)
        )
        let reversibilityProfile = BASReversibilityProfile(
            profileID: "reversibility.\(fieldStem)",
            reversible: riskCard.irreversibility < 0.5,
            rollbackCost: riskCard.irreversibility,
            confirmNodes: riskCard.irreversibility >= 0.65 ? ["second_check", "before_release"] : [],
            draftSafe: riskCard.riskLevel < .extreme,
            smallStepPossible: riskCard.riskLevel < .extreme
        )
        let evidenceSufficiency = BASEvidenceSufficiency(
            sufficiencyID: "evidence.\(fieldStem)",
            supportLevel: supportLevel,
            missingEvidence: missingEvidence.isEmpty
                ? (riskCard.uncertainty >= 0.45 ? ["follow_up_evidence"] : [])
                : missingEvidence,
            allowedAssertionLevel: riskCard.assertionCeiling,
            allowedActionLevel: actionPermit.mode.rawValue
        )
        let gsiTrace = BASGSITrace(
            traceID: "gsi.\(fieldStem)",
            gaslightSignals: contextFrame.manipulationHints,
            coerciveUrgency: contextFrame.manipulationTrace?.timeCoercion ?? contextFrame.timePressure,
            shamePressure: contextFrame.manipulationTrace?.shamePressure ?? 0,
            authorityMask: contextFrame.manipulationTrace?.authorityMask == true ? 1 : 0,
            relationLeverage: contextFrame.manipulationTrace?.relationalLeverage.isEmpty == false ? 0.8 : riskCard.manipulationStrength,
            susceptibilityBand: riskCard.gsiScore >= 0.75 ? "elevated" : (riskCard.gsiScore >= 0.5 ? "guarded" : "stable")
        )
        let vulnerabilityCoupling = BASVulnerabilityCoupling(
            couplingID: "vulnerability.\(fieldStem)",
            touchedBoundaries: contextFrame.hostResonance?.touchedBoundaries ?? [],
            lowEnergyResonance: contextFrame.hostResonance?.intensity ?? contextFrame.emotionalLoad,
            sensitivityWindow: currentBrain.hasProtectiveBoundary ? max(contextFrame.emotionalLoad, 0.7) : contextFrame.emotionalLoad,
            protectionBias: riskCard.riskLevel >= .high ? 0.82 : 0.34
        )
        let riskField = BASRiskField(
            fieldID: "risk-field.\(fieldStem)",
            candidateRef: selectedCandidateID,
            hazardVector: BASHazardVector(
                harmSeverity: riskCard.totalRisk,
                harmScope: max(harmRadius.relationImpact, harmRadius.publicImpact),
                irreversibility: riskCard.irreversibility,
                uncertainty: riskCard.uncertainty,
                evidenceDebt: selectedEvidenceDebt?.debtWeight ?? riskCard.uncertainty,
                manipulationIntensity: riskCard.manipulationStrength,
                pressureAuthenticity: contextFrame.urgencyTruth?.authenticityScore ?? (1 - contextFrame.timePressure),
                vulnerabilityCoupling: vulnerabilityCoupling.protectionBias,
                sideEffectScope: max(harmRadius.publicImpact, riskCard.irreversibility)
            ),
            harmRadius: harmRadius,
            reversibilityProfile: reversibilityProfile,
            evidenceSufficiency: evidenceSufficiency,
            gsiTrace: gsiTrace,
            vulnerabilityCoupling: vulnerabilityCoupling,
            confidenceBand: supportLevel >= 0.72 ? "stable" : (riskCard.riskLevel >= .high ? "guarded" : "open")
        )
        let actionModeDecision = BASActionModeDecision(
            decisionID: "mode.\(fieldStem)",
            primaryMode: actionPermit.mode,
            stackedModes: actionPermit.stackedModes,
            reasonCodes: actionPermit.reasonCodes,
            confidence: max(0, 1 - riskCard.uncertainty)
        )
        let delayReservation: BASDelayReservation? = if let delayType = riskCard.delayType ?? actionPermit.delayWindow {
            BASDelayReservation(
                reservationID: "delay.\(fieldStem)",
                delayType: delayType,
                minDelay: actionPermit.mode == .delay ? 15 : 5,
                maxDelay: actionPermit.mode == .delay ? 1_440 : 120,
                allowedIntermediateActions: actionPermit.mode == .delay ? ["compare", "draft_only"] : ["mirror"]
            )
        } else {
            nil
        }
        let protectiveSubstitute: BASProtectiveSubstitute? = if actionPermit.substituteRequired || riskCard.substituteType != nil {
            BASProtectiveSubstitute(
                substituteID: "substitute.\(fieldStem)",
                sourceCandidateRef: selectedCandidateID,
                substituteType: riskCard.substituteType ?? (actionPermit.mode == .replace ? "local_only_action" : "draft"),
                description: actionPermit.mode == .replace
                    ? "Use a smaller, more local step before any public move."
                    : "Keep the action at draft pressure until the boundary is re-checked.",
                safetyGain: riskCard.riskLevel >= .high ? 0.82 : 0.48
            )
        } else {
            nil
        }
        let sovereignEscalationHint: BASSovereignEscalationHint? = if actionPermit.allModes.contains(.escalate)
            || (riskCard.irreversibility >= 0.75 && riskCard.manipulationStrength >= 0.6)
            || selectedBreakpointHints.isEmpty == false {
            BASSovereignEscalationHint(
                hintID: "sovereign.\(fieldStem)",
                sourceRefs: orderedUnique(
                    ["risk-field.\(fieldStem)", "permit.\(fieldStem)"]
                        + selectedBreakpointHints.map(\.hintID)
                ),
                reasonCodes: orderedUnique(
                    actionPermit.reasonCodes
                        + ["risk.sovereign_boundary"]
                        + selectedBreakpointHints.flatMap(\.reasonCodes)
                ),
                urgency: riskCard.sovereignHintLevel
                    ?? selectedBreakpointHints.first.map { hint in
                        switch hint.suggestedAction {
                        case .stop:
                            return "high"
                        case .cut, .freeze:
                            return "medium"
                        case .shrink:
                            return "low"
                        }
                    }
                    ?? "high",
                suggestedScope: actionPermit.blockedDomains.contains("host.write")
                    || selectedBreakpointHints.contains(where: { $0.suggestedAction == .stop })
                    ? "host"
                    : "tool"
            )
        } else {
            nil
        }

        return BASRiskDecisionPackage(
            packageID: "risk-package.\(fieldStem)",
            riskCard: riskCard,
            riskField: riskField,
            actionModeDecision: actionModeDecision,
            actionPermit: actionPermit,
            delayReservation: delayReservation,
            protectiveSubstitute: protectiveSubstitute,
            sovereignEscalationHint: sovereignEscalationHint
        )
    }

    private func riskPreferredCandidateID(
        from thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore]
    ) -> String {
        if let preferred = triScores
            .filter({ !$0.veto })
            .max(by: { $0.mergedScore < $1.mergedScore })?.candidateID {
            return preferred
        }
        if let preferred = triScores.max(by: { $0.mergedScore < $1.mergedScore })?.candidateID {
            return preferred
        }
        return thoughtFrame.candidates.first?.candidateID ?? thoughtFrame.decomposeRef
    }

    private func riskEvidenceDebt(
        for candidateID: String,
        in thoughtFrame: BASThoughtFrame
    ) -> BASEvidenceDebt? {
        thoughtFrame.evidenceDebts?.first { $0.candidateID == candidateID }
    }

    private func riskSovereignBreakpointHints(
        for candidateID: String,
        in thoughtFrame: BASThoughtFrame
    ) -> [BASSovereignBreakpointHint] {
        thoughtFrame.sovereignBreakpointHints?.filter {
            $0.affectedCandidates.contains(candidateID)
                || $0.sourceRef.hasSuffix(candidateID)
        } ?? []
    }

    private func riskFactors(
        for contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        constitutionFactorCodes: [String],
        courtFactorCodes: [String],
        presenceFactorCodes: [String]
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
        if currentBrain.hasEvidenceCaveatLoad { factors.append("evidence_caveat_load") }
        factors += constitutionFactorCodes
        factors += courtFactorCodes
        factors += presenceFactorCodes
        return factors
    }

    private func presenceRiskSignals(
        contextFrame: BASContextFrame
    ) -> (
        riskIncrement: Double,
        factorCodes: [String],
        gsiIncrement: Double,
        manipulationStrength: Double
    ) {
        var riskIncrement = 0.0
        var gsiIncrement = 0.0
        var factorCodes: [String] = []
        var manipulationStrength = 0.0
        let manipulationConfidence = contextFrame.manipulationTrace?.confidence ?? 0
        let escalatoryPresence = manipulationConfidence > 0.55
            || (contextFrame.powerGradient?.strength ?? 0) > 0.65
            || contextFrame.routeHint?.needGuard == true

        if let powerGradient = contextFrame.powerGradient,
           powerGradient.strength > 0.6 {
            if escalatoryPresence {
                riskIncrement += min(0.06, 0.01 + (powerGradient.strength * 0.05))
                gsiIncrement += 0.05
            }
            factorCodes.append("presence_power_gradient")
        }
        if let urgencyTruth = contextFrame.urgencyTruth,
           urgencyTruth.canDelay == false,
           escalatoryPresence {
            riskIncrement += min(0.04, 0.01 + (urgencyTruth.inferredUrgency * 0.03))
            gsiIncrement += urgencyTruth.statedUrgency > 0.75 ? 0.05 : 0.02
            factorCodes.append("presence_urgency_locked")
        }
        if let manipulationTrace = contextFrame.manipulationTrace {
            if manipulationTrace.confidence > 0.55 {
                riskIncrement += min(0.06, manipulationTrace.confidence * 0.04 + manipulationTrace.timeCoercion * 0.02)
                gsiIncrement += min(0.14, manipulationTrace.confidence * 0.12)
            }
            manipulationStrength = max(manipulationStrength, manipulationTrace.confidence)
            factorCodes.append("presence_manipulation_trace")
        }
        if contextFrame.routeHint?.needGuard == true {
            riskIncrement += 0.03
            gsiIncrement += 0.05
            factorCodes.append("presence_route_guard")
        }

        return (
            min(0.16, riskIncrement),
            orderedUnique(factorCodes),
            min(0.24, gsiIncrement),
            min(1, manipulationStrength)
        )
    }

    private func constitutionGuardSignals(
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore]
    ) -> (riskIncrement: Double, factorCodes: [String], reasonCodes: [String]) {
        guard let hostConstitution,
              thoughtFrame.candidates.contains(where: { $0.candidateID == "path.direct" }) else {
            return (0, [], [])
        }

        let directScore = triScores.first(where: { $0.candidateID == "path.direct" })?.mergedScore ?? 0
        let stabilityWeight = constitutionAxisWeight(
            in: hostConstitution,
            matching: ["stability", "safety"]
        )
        let privacyWeight = constitutionAxisWeight(
            in: hostConstitution,
            matching: ["privacy", "locality"]
        )
        let confirmIncrement = hostConstitution.boundaryVeil.confirmRequired.isEmpty ? 0.0 : 0.08
        let valueAxisIncrement = max(stabilityWeight, privacyWeight) >= hostConstitution.valueAxes.updateThreshold ? 0.07 : 0.0
        let conflictIncrement = hostConstitution.valueAxes.conflictRules.contains {
            $0.lowercased().contains("over_speed")
        } ? 0.04 : 0.0
        let noGoIncrement = hostConstitution.boundaryVeil.hardNoGo.isEmpty ? 0.0 : 0.03
        let directPathBias = directScore > 0.6 ? 0.03 : 0.0

        var factorCodes: [String] = []
        var reasonCodes: [String] = []
        if confirmIncrement > 0 {
            factorCodes.append("constitution_confirm_required")
            reasonCodes.append("constitution.confirm_required")
        }
        if stabilityWeight >= hostConstitution.valueAxes.updateThreshold {
            factorCodes.append("constitution_value_axis_stability")
            reasonCodes.append("constitution.value_axis.stability")
        }
        if privacyWeight >= hostConstitution.valueAxes.updateThreshold {
            factorCodes.append("constitution_value_axis_privacy")
            reasonCodes.append("constitution.value_axis.privacy")
        }
        if conflictIncrement > 0 {
            factorCodes.append("constitution_conflict_rule")
            reasonCodes.append("constitution.conflict_rule")
        }
        if constitutionPrefersBoundedAction(in: hostConstitution) {
            factorCodes.append("constitution_goal_priority_bounded")
            reasonCodes.append("constitution.goal_priority.bounded")
        }
        if constitutionHasHighConsequenceRelations(in: hostConstitution) {
            factorCodes.append("constitution_relation_high_consequence")
            reasonCodes.append("constitution.relation_high_consequence")
        }

        return (
            min(
                0.33,
                confirmIncrement
                    + valueAxisIncrement
                    + conflictIncrement
                    + noGoIncrement
                    + directPathBias
                    + (constitutionPrefersBoundedAction(in: hostConstitution) ? 0.05 : 0.0)
                    + (constitutionHasHighConsequenceRelations(in: hostConstitution) ? 0.06 : 0.0)
            ),
            orderedUnique(factorCodes),
            orderedUnique(reasonCodes)
        )
    }

    private func courtSignals(
        thoughtFrame: BASThoughtFrame
    ) -> (riskIncrement: Double, factorCodes: [String], reasonCodes: [String]) {
        var riskIncrement = 0.0
        var factorCodes: [String] = []
        var reasonCodes: [String] = []

        if let agencyReservation = thoughtFrame.agencyReservation {
            switch agencyReservation.mode {
            case .retainChoice:
                factorCodes.append("court_agency_retain_choice")
                reasonCodes.append("agency.retain_choice")
            case .compareOnly:
                riskIncrement += 0.03
                factorCodes.append("court_agency_compare_only")
                reasonCodes.append("agency.compare_only")
            case .delayRight:
                riskIncrement += 0.05
                factorCodes.append("court_agency_delay_right")
                reasonCodes.append("agency.delay_right")
            case .noAutoMerge:
                riskIncrement += 0.04
                factorCodes.append("court_agency_no_auto_merge")
                reasonCodes.append("agency.no_auto_merge")
            }
        }

        if let remandOrders = thoughtFrame.remandOrders,
           remandOrders.isEmpty == false {
            riskIncrement += 0.05
            factorCodes.append("court_remand_pending")
            reasonCodes.append("court.remand.pending")
        }
        if let vetoMarks = thoughtFrame.vetoMarks,
           vetoMarks.isEmpty == false {
            factorCodes.append("court_veto_materialized")
        }
        if let ledger = thoughtFrame.uncertaintyLedger {
            if ledger.weakPredictions.isEmpty == false {
                riskIncrement += 0.03
                factorCodes.append("dream_loop_weak_prediction")
                reasonCodes.append("dream_loop.weak_prediction")
            }
            if ledger.confidenceFloor < 0.55 {
                riskIncrement += 0.03
                factorCodes.append("dream_loop_low_confidence_floor")
                reasonCodes.append("dream_loop.confidence_floor")
            }
        }
        if let evidenceDebts = thoughtFrame.evidenceDebts,
           let maxDebt = evidenceDebts.map(\.debtWeight).max(),
           maxDebt >= 0.5 {
            riskIncrement += min(0.04, maxDebt * 0.04)
            factorCodes.append("dream_loop_evidence_debt")
            reasonCodes.append("dream_loop.evidence_debt")
        }
        if let convergence = thoughtFrame.convergenceCertificate {
            switch convergence.stoppingMode {
            case .leaseEnd:
                riskIncrement += 0.04
                factorCodes.append("dream_loop_lease_end")
                reasonCodes.append("dream_loop.lease_end")
            case .sovereignCut:
                riskIncrement += 0.05
                factorCodes.append("dream_loop_sovereign_cut")
                reasonCodes.append("dream_loop.sovereign_cut")
            case .guardTakeover:
                riskIncrement += 0.03
                factorCodes.append("dream_loop_guard_takeover")
                reasonCodes.append("dream_loop.guard_takeover")
            case .converged:
                break
            }
        }
        if let breakpointHints = thoughtFrame.sovereignBreakpointHints,
           breakpointHints.isEmpty == false {
            riskIncrement += 0.04
            factorCodes.append("dream_loop_sovereign_breakpoint")
            reasonCodes.append("dream_loop.sovereign_breakpoint")
        }

        return (
            min(0.12, riskIncrement),
            orderedUnique(factorCodes),
            orderedUnique(reasonCodes)
        )
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

    private func orderedUnique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func recommendedMode(
        for level: BASBrainRiskLevel,
        contextFrame: BASContextFrame
    ) -> BASActionPermitMode {
        switch level {
        case .low:
            .answer
        case .medium:
            currentBrain.hasProtectiveBoundary || contextFrame.manipulationHints.isEmpty == false ? .compare : .answer
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
        reasons += uncertaintyReasonCodes
        return reasons
    }

    private var uncertaintyReasonCodes: [String] {
        currentBrain.hasEvidenceCaveatLoad ? ["evidence.caveat"] : []
    }
}
