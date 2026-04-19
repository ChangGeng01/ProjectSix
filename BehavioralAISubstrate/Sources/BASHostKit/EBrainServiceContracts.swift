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

    func riskLevel(for score: Double) -> BASBrainRiskLevel
}

public extension BASRiskServicing {
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
