// MARK: - BASCoordinatorTestStubs — chapter 四百六十二 / M1225
// Reusable test stubs for BASEBrainRuntimeCoordinator
// service protocols。 Closes the LAST 30% of chapter
// 461 integration debt:before this file existed,no
// test in the BAS target could construct a real
// coordinator + call `engine.runWithPlan(...)` end-
// to-end — every existing engine-related test
// (BASTurnRuntimeEngineRunWithPlanTests etc.) tested
// the DELEGATE,not the engine。
//
// The stubs return minimal valid responses for each
// protocol method:no editorializing,no schema-
// specific behavior。 Each stub is a `Stub*` prefixed
// struct,distinct from the local-inside-test-method
// stubs in BASEBrainSchemaCoreTests (which return
// schema-specific test fixtures)。
//
// `BASCoordinatorTestStubs.makeStub()` returns a
// fully-wired `BASEBrainRuntimeCoordinator` ready
// for `engine.runWithPlan(...)` tests。

import Foundation
@testable import BASHostKit
@testable import BASRuntimeCore

public enum BASCoordinatorTestStubs {

    /// Factory returning a fully-wired stub coordinator
    /// suitable for testing BASTurnRuntimeEngine.runWith
    /// Plan(...) end-to-end without needing a real
    /// production host runtime。 chapter 462 / M1225。
    public static func makeStub() -> BASEBrainRuntimeCoordinator {
        // Default no-arg path. (StubEvolution is internal, so it can't be a public
        // default-arg value — reference it in the body via this overload instead.)
        makeStub(evolutionService: StubEvolution())
    }

    public static func makeStub(
        evolutionService: BASEvolutionServicing
    ) -> BASEBrainRuntimeCoordinator {
        return BASEBrainRuntimeCoordinator(
            powerClockService: StubPowerClock(),
            hostProfileService: StubHost(),
            contextService: StubContext(),
            decomposeService: StubDecompose(),
            memoryService: StubMemory(),
            loopService: StubLoop(),
            triSelfService: StubTriSelf(),
            riskService: StubRisk(),
            actionService: StubAction(),
            evolutionService: evolutionService)
    }

    /// Minimal device-state fixture for stub-coordinator
    /// turns。 Nominal everything — no edge cases。
    public static let nominalDeviceState =
        BASDeviceState(
            batteryLevel: 0.8,
            thermalLevel: .nominal,
            memoryFreeMB: 2048,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.2,
            gpuLoad: 0.1,
            npuAvailable: false,
            latencyBudgetMs: 1500)

    /// Minimal turn request fixture。 Hosts who need
    /// custom fields construct their own via
    /// `BASEBrainTurnRequest(...)`。
    public static func makeStubRequest(
        userInput: String = "stub test input",
        hostID: String = "stub.test.host",
        recordedAt: Date =
            Date(timeIntervalSince1970: 1_700_000_000)
    ) -> BASEBrainTurnRequest {
        return BASEBrainTurnRequest(
            userInput: userInput,
            deviceState: nominalDeviceState,
            hostID: hostID,
            recordedAt: recordedAt)
    }
}

// MARK: - Stub services

struct StubPowerClock: BASPowerClockServicing {
    func planBudget(
        deviceState: BASDeviceState,
        taskPing: String,
        riskHint: BASBrainRiskLevel?
    ) -> BASBudgetFrame {
        return BASBudgetFrame(
            runMode: .engage,
            maxLoops: 1,
            maxCandidates: 1,
            maxDecodeTokens: 100,
            retrievalDepth: 1,
            precisionProfile: .minimal,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false)
    }
    func routeDevice(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> BASDeviceRoute {
        return budget.deviceRoute
    }
    func scheduleMaintenance(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> Bool {
        return false
    }
}

struct StubHost: BASHostProfileServicing {
    func resolveHost(
        hostID: String,
        contextFrame: BASContextFrame?,
        riskCard: BASRiskCard?
    ) -> BASHostProfile {
        return BASHostProfile(
            hostID: hostID,
            longTermGoals: ["test"],
            noGoZones: [])
    }
    func applyHostGate(
        profile: BASHostProfile,
        taskType: BASContextTaskType,
        riskCard: BASRiskCard?,
        confidence: Double
    ) -> Double {
        return confidence
    }
    func rollbackHostVersion(
        profile: BASHostProfile,
        to versionID: String
    ) -> BASHostVersion {
        return BASHostVersion(
            versionID: versionID,
            changedFields: [],
            reason: "test",
            approvedByPolicy: true)
    }
}

struct StubContext: BASContextServicing {
    func analyzeContext(
        userInput: String,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASContextFrame {
        return BASContextFrame(
            utterance: userInput,
            taskType: .chat,
            emotionalLoad: 0.1,
            timePressure: 0.1,
            relationPattern: "neutral",
            ambiguityScore: 0.1,
            consequenceLevel: 0.1,
            manipulationHints: [],
            hostRelevance: 0.5)
    }
}

struct StubDecompose: BASDecomposeServicing {
    func decompose(
        contextFrame: BASContextFrame,
        memoryHints: [String]
    ) -> BASDecomposeFrame {
        return BASDecomposeFrame(
            facts: [],
            goals: [],
            emotions: [],
            unknowns: [],
            contradictions: [],
            pressureSignals: [],
            manipulationSignals: [],
            mirrorText: "stub mirror")
    }
    func mirror(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> String {
        return decomposeFrame.mirrorText
    }
    func checkContradiction(
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame
    ) -> [String] {
        return []
    }
}

struct StubMemory: BASMemoryServicing {
    func retrieve(
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile,
        budget: BASBudgetFrame
    ) -> BASMemoryBundle {
        return BASMemoryBundle(
            atoms: [],
            retrievalTags: [],
            activeHostVersion: hostContext.activeVersion)
    }
    func promote(
        atom: BASMemoryAtom,
        hostContext: BASHostProfile
    ) -> BASPromotionState {
        return .candidate
    }
    func freeze(memoryID: String) -> Bool {
        return true
    }
}

struct StubLoop: BASLoopServicing {
    func proposePaths(
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> [BASCandidatePath] {
        return [
            BASCandidatePath(
                candidateID: "stub-c1",
                title: "stub",
                actionSummary: "stub",
                expectedBenefit: 0.5,
                expectedCost: 0.5,
                reversibility: 0.5,
                confidence: 0.5)
        ]
    }
    func forecast(
        candidates: [BASCandidatePath],
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle
    ) -> [BASForecastItem] {
        return candidates.map {
            BASForecastItem(
                candidateID: $0.candidateID,
                shortTermOutcome: "stub",
                midTermOutcome: "stub",
                worstCase: "stub",
                uncertainty: 0.3)
        }
    }
    func critique(
        candidates: [BASCandidatePath],
        forecasts: [BASForecastItem],
        hostContext: BASHostProfile
    ) -> [BASCritiqueItem] {
        return candidates.map {
            BASCritiqueItem(
                candidateID: $0.candidateID,
                critiqueType: .evidenceGap,
                critiqueText: "stub",
                severity: 0.3)
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
            budget: budget)
        return BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "stub-decomp",
            memoryRefs: [],
            candidates: candidates,
            forecasts: forecast(
                candidates: candidates,
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle),
            critiques: critique(
                candidates: candidates,
                forecasts: [],
                hostContext: BASHostProfile(
                    hostID: "stub")),
            stabilityScore: 0.5,
            stopReason: .candidateStable)
    }
}

struct StubTriSelf: BASTriSelfServicing {
    func mergeChoice(
        thoughtFrame: BASThoughtFrame,
        hostContext: BASHostProfile
    ) -> ([BASTriSelfScore], BASMergedChoice) {
        let scores = thoughtFrame.candidates.map {
            BASTriSelfScore(
                candidateID: $0.candidateID,
                idScore: 0.5,
                egoScore: 0.5,
                superegoScore: 0.5,
                mergedScore: 0.5,
                veto: false)
        }
        let pick = thoughtFrame.candidates.first
            ?? BASCandidatePath(
                candidateID: "stub-c1",
                title: "stub",
                actionSummary: "stub",
                expectedBenefit: 0.5,
                expectedCost: 0.5,
                reversibility: 0.5,
                confidence: 0.5)
        return (
            scores,
            BASMergedChoice(
                candidateID: pick.candidateID,
                title: pick.title,
                actionSummary: pick.actionSummary))
    }
}

struct StubRisk: BASRiskServicing {
    func calibrateRisk(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> BASRiskCard {
        return BASRiskCard(
            totalRisk: 0.2,
            riskLevel: .low,
            factors: [],
            uncertainty: 0.2,
            irreversibility: 0.1,
            manipulationStrength: 0.0,
            gsiScore: 0.2,
            recommendedMode: .answer)
    }
    func computeGSI(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame
    ) -> Double {
        return 0.2
    }
    func gateAction(
        contextFrame: BASContextFrame,
        thoughtFrame: BASThoughtFrame,
        triScores: [BASTriSelfScore],
        budget: BASBudgetFrame
    ) -> (BASRiskCard, BASActionPermit) {
        return (
            calibrateRisk(
                contextFrame: contextFrame,
                thoughtFrame: thoughtFrame,
                triScores: triScores,
                budget: budget),
            BASActionPermit(
                mode: .answer,
                reasonCodes: ["stub"],
                outputLengthCap: 100,
                tonePolicy: "neutral",
                templatePolicy: "default"))
    }
}

struct StubAction: BASActionServicing {
    func render(
        choice: BASMergedChoice,
        riskCard: BASRiskCard,
        permit: BASActionPermit,
        hostContext: BASHostProfile
    ) -> BASRenderedOutput {
        return BASRenderedOutput(
            mode: permit.mode,
            headline: choice.title,
            body: choice.actionSummary,
            alternativeActions: [],
            explanationCodes: permit.reasonCodes)
    }
}

struct StubEvolution: BASEvolutionServicing {
    func buildTickets(
        thoughtFrame: BASThoughtFrame,
        output: BASRenderedOutput,
        feedbackEvent: BASFeedbackEvent?
    ) -> [BASUpdateTicket] {
        return []
    }
}

/// ch1044 D1 — a NON-EMPTY evolution stub with a DETERMINISTIC ticket id, so the
/// determinism guard actually exercises the `updateTickets → commit-token` path that
/// `StubEvolution` (returning []) hid — the very gap that let the production
/// evolution services' `UUID()`/clock ticket ids leak into signature bytes undetected.
struct DeterministicTicketStubEvolution: BASEvolutionServicing {
    func buildTickets(
        thoughtFrame: BASThoughtFrame,
        output: BASRenderedOutput,
        feedbackEvent: BASFeedbackEvent?
    ) -> [BASUpdateTicket] {
        [BASUpdateTicket(
            ticketID: "ticket.det.\(output.mode.rawValue)",
            sessionRef: "stub.det",
            summary: output.body,
            confidence: 0.7)]
    }
}
