import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public protocol BASPowerClockServicing: Sendable {
    func planBudget(
        deviceState: BASDeviceState,
        taskPing: String,
        riskHint: BASBrainRiskLevel?
    ) -> BASBudgetFrame

    func routeDevice(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> BASDeviceRoute

    func scheduleMaintenance(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> Bool
}

public protocol BASVitalMonitorServicing: Sendable {
    func currentDeviceState(now: Date) -> BASDeviceState
}

public protocol BASHostProfileServicing: Sendable {
    func resolveHost(
        hostID: String,
        contextFrame: BASContextFrame?,
        riskCard: BASRiskCard?
    ) -> BASHostProfile

    func applyHostGate(
        profile: BASHostProfile,
        taskType: BASContextTaskType,
        riskCard: BASRiskCard?,
        confidence: Double
    ) -> Double

    func rollbackHostVersion(
        profile: BASHostProfile,
        to versionID: String
    ) -> BASHostVersion
}

public protocol BASHostConstitutionServicing: Sendable {
    func resolveConstitution(
        hostID: String,
        contextFrame: BASContextFrame?,
        riskCard: BASRiskCard?
    ) -> BASHostConstitution

    func projectProfile(
        from constitution: BASHostConstitution,
        riskThresholds: BASHostRiskThresholds
    ) -> BASHostProfile

    func projectRhythm(
        from constitution: BASHostConstitution
    ) -> BASHostRhythmProfile

    func stageChange(
        candidate: BASHostChangeCandidate,
        on constitution: BASHostConstitution
    ) -> BASHostConstitution

    func approve(
        candidate: BASHostChangeCandidate,
        on versionTree: BASHostVersionTree
    ) -> BASHostVersionTree

    func freeze(
        versionID: String,
        on versionTree: BASHostVersionTree
    ) -> BASHostVersionTree

    func thaw(
        versionID: String,
        on versionTree: BASHostVersionTree
    ) -> BASHostVersionTree

    func rollback(
        versionTree: BASHostVersionTree,
        to versionID: String
    ) -> BASHostVersionTree

    func executeForget(
        request: BASForgetRequest,
        on constitution: BASHostConstitution
    ) -> BASForgetRequest

    func applyForget(
        request: BASForgetRequest,
        on vault: BASHostConstitutionVault
    ) -> BASHostConstitutionVault

    func stageMigration(
        contract: BASHostDeviceMigrationContract,
        on vault: BASHostConstitutionVault
    ) -> BASHostConstitutionVault

    func approveMigration(
        on vault: BASHostConstitutionVault,
        targetDeviceID: String?
    ) -> BASHostConstitutionVault

    func synchronizeVault(
        on vault: BASHostConstitutionVault,
        deviceID: String,
        propagatedRequestIDs: [String],
        synchronizedAt: Date
    ) -> BASHostConstitutionVault
}

public protocol BASContextServicing: Sendable {
    func analyzeContext(
        userInput: String,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASContextFrame
}

public protocol BASDecomposeServicing: Sendable {
    func decompose(
        contextFrame: BASContextFrame,
        memoryHints: [String]
    ) -> BASDecomposeFrame

    func mirror(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> String

    func checkContradiction(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> [String]
}

public protocol BASMemoryServicing: Sendable {
    func retrieve(
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASMemoryBundle

    func promote(
        atom: BASMemoryAtom,
        hostContext: BASHostProfile
    ) -> BASPromotionState

    func freeze(memoryID: String) -> Bool
}

public protocol BASNeuralCoreServicing: Sendable {
    func synthesize(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        hostProfile: BASHostProfile,
        activeKillSwitches: [BASKillSwitchID]
    ) -> BASNeuralCoreFrame

    func materializeThoughtArtifacts(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        hostProfile: BASHostProfile,
        thoughtFrame: BASThoughtFrame
    ) -> BASNeuralThoughtMaterialization

    func materializePublicProjection(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        hostProfile: BASHostProfile,
        thoughtFrame: BASThoughtFrame
    ) -> BASNeuralPublicThoughtProjection

    func materializeRiskBindings(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit
    ) -> [BASRiskPermitBinding]

    func materializeToolIntent(
        budgetFrame: BASBudgetFrame,
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        actionPermit: BASActionPermit
    ) -> BASToolIntentEnvelope?
}

public extension BASNeuralCoreServicing {
    func materializeThoughtArtifacts(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        hostProfile: BASHostProfile,
        thoughtFrame: BASThoughtFrame
    ) -> BASNeuralThoughtMaterialization {
        BASNeuralMaterializationCompiler.materializeThoughtArtifacts(
            thoughtFrame: thoughtFrame
        )
    }

    func materializePublicProjection(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        hostProfile: BASHostProfile,
        thoughtFrame: BASThoughtFrame
    ) -> BASNeuralPublicThoughtProjection {
        BASNeuralMaterializationCompiler.materializePublicProjection(
            thoughtFrame: thoughtFrame
        )
    }

    func materializeRiskBindings(
        budgetFrame: BASBudgetFrame,
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit
    ) -> [BASRiskPermitBinding] {
        BASNeuralMaterializationCompiler.materializeRiskBindings(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            riskLevelResolver: { score in
                switch score {
                case ..<0.35:
                    return .low
                case ..<0.60:
                    return .medium
                case ..<0.82:
                    return .high
                default:
                    return .extreme
                }
            }
        )
    }

    func materializeToolIntent(
        budgetFrame: BASBudgetFrame,
        thoughtFrame: BASThoughtFrame,
        mergedChoice: BASMergedChoice,
        actionPermit: BASActionPermit
    ) -> BASToolIntentEnvelope? {
        BASNeuralMaterializationCompiler.materializeToolIntent(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            actionPermit: actionPermit
        )
    }
}

public protocol BASLoopServicing: Sendable {
    func proposePaths(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> [BASCandidatePath]

    func forecast(
        candidates: [BASCandidatePath],
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle
    ) -> [BASForecastItem]

    func critique(
        candidates: [BASCandidatePath],
        forecasts: [BASForecastItem],
        hostContext: BASHostProfile
    ) -> [BASCritiqueItem]

    func iterate(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> BASThoughtFrame
}

public protocol BASTriSelfServicing: Sendable {
    func mergeChoice(
        thoughtFrame: BASThoughtFrame,
        hostContext: BASHostProfile
    ) -> ([BASTriSelfScore], BASMergedChoice)
}

public protocol BASRiskServicing: Sendable {
    func calibrateRisk(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> BASRiskCard

    func computeGSI(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame
    ) -> Double

    func gateAction(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> (BASRiskCard, BASActionPermit)

    func buildRiskDecisionPackage(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> BASRiskDecisionPackage

    func riskLevel(for score: Double) -> BASBrainRiskLevel
}

public extension BASRiskServicing {
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
        let riskField = BASRiskField(
            fieldID: "risk-field.\(thoughtFrame.decomposeRef).\(thoughtFrame.stepIndex)",
            candidateRef: thoughtFrame.candidates.first?.candidateID ?? thoughtFrame.decomposeRef,
            hazardVector: BASHazardVector(
                harmSeverity: riskCard.totalRisk,
                harmScope: riskCard.totalRisk,
                irreversibility: riskCard.irreversibility,
                uncertainty: riskCard.uncertainty,
                evidenceDebt: riskCard.uncertainty,
                manipulationIntensity: riskCard.manipulationStrength,
                pressureAuthenticity: contextFrame.timePressure,
                vulnerabilityCoupling: contextFrame.emotionalLoad,
                sideEffectScope: riskCard.totalRisk
            ),
            harmRadius: BASHarmRadiusMap(
                radiusID: "harm-radius.\(thoughtFrame.decomposeRef).\(thoughtFrame.stepIndex)",
                privateImpact: contextFrame.emotionalLoad,
                relationImpact: contextFrame.consequenceLevel,
                workflowImpact: contextFrame.ambiguityScore,
                publicImpact: contextFrame.timePressure,
                longTermTrace: riskCard.irreversibility
            ),
            reversibilityProfile: BASReversibilityProfile(
                profileID: "reversibility.\(thoughtFrame.decomposeRef).\(thoughtFrame.stepIndex)",
                reversible: riskCard.irreversibility < 0.5,
                rollbackCost: riskCard.irreversibility,
                confirmNodes: riskCard.irreversibility >= 0.7 ? ["second_check"] : [],
                draftSafe: true,
                smallStepPossible: riskCard.riskLevel < .extreme
            ),
            evidenceSufficiency: BASEvidenceSufficiency(
                sufficiencyID: "evidence.\(thoughtFrame.decomposeRef).\(thoughtFrame.stepIndex)",
                supportLevel: max(0, 1 - riskCard.uncertainty),
                missingEvidence: riskCard.uncertainty >= 0.5 ? ["follow_up_evidence"] : [],
                allowedAssertionLevel: riskCard.assertionCeiling,
                allowedActionLevel: actionPermit.mode.rawValue
            ),
            gsiTrace: BASGSITrace(
                traceID: "gsi.\(thoughtFrame.decomposeRef).\(thoughtFrame.stepIndex)",
                gaslightSignals: contextFrame.manipulationHints,
                coerciveUrgency: contextFrame.timePressure,
                shamePressure: 0,
                authorityMask: 0,
                relationLeverage: riskCard.manipulationStrength,
                susceptibilityBand: riskCard.gsiScore >= 0.7 ? "elevated" : "stable"
            ),
            vulnerabilityCoupling: BASVulnerabilityCoupling(
                couplingID: "vulnerability.\(thoughtFrame.decomposeRef).\(thoughtFrame.stepIndex)",
                touchedBoundaries: [],
                lowEnergyResonance: contextFrame.emotionalLoad,
                sensitivityWindow: contextFrame.emotionalLoad,
                protectionBias: riskCard.riskLevel >= .high ? 0.8 : 0.3
            ),
            confidenceBand: riskCard.riskLevel >= .high ? "guarded" : "open"
        )
        let modeDecision = BASActionModeDecision(
            decisionID: "mode.\(thoughtFrame.decomposeRef).\(thoughtFrame.stepIndex)",
            primaryMode: actionPermit.mode,
            stackedModes: actionPermit.stackedModes,
            reasonCodes: actionPermit.reasonCodes,
            confidence: max(0, 1 - riskCard.uncertainty)
        )

        return BASRiskDecisionPackage(
            packageID: "risk-package.\(thoughtFrame.decomposeRef).\(thoughtFrame.stepIndex)",
            riskCard: riskCard,
            riskField: riskField,
            actionModeDecision: modeDecision,
            actionPermit: actionPermit
        )
    }

    func riskLevel(for score: Double) -> BASBrainRiskLevel {
        switch score {
        case ..<0.35:
            return .low
        case ..<0.60:
            return .medium
        case ..<0.82:
            return .high
        default:
            return .extreme
        }
    }
}

public protocol BASActionServicing: Sendable {
    func render(
        choice: BASMergedChoice,
        riskCard: BASRiskCard,
        permit: BASActionPermit,
        hostContext: BASHostProfile
    ) -> BASRenderedOutput
}

public protocol BASEvolutionServicing: Sendable {
    func buildTickets(
        thoughtFrame: BASThoughtFrame,
        output: BASRenderedOutput,
        feedbackEvent: BASFeedbackEvent?
    ) -> [BASUpdateTicket]
}
