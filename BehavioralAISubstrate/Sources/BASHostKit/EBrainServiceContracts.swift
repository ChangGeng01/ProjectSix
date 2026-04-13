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
