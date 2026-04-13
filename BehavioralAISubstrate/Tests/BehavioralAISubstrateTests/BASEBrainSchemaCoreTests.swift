import Foundation
import Testing
@testable import BASHostKit

@Suite("BASEBrain schemas")
struct BASEBrainSchemaCoreTests {
    @Test("new control, knowledge, cognition, and observation schemas publish stable current versions")
    func schemasExposeStableCurrentVersion() {
        let device = BASDeviceState(
            batteryLevel: 0.62,
            thermalLevel: .warm,
            memoryFreeMB: 2048,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.41,
            gpuLoad: 0.12,
            npuAvailable: true,
            latencyBudgetMs: 1200
        )
        let budget = BASBudgetFrame.guardedLocal()
        let host = BASHostProfile(hostID: "host.primary")
        let atom = BASMemoryAtom(
            memoryID: "mem-1",
            summary: "Protect long-term boundaries.",
            contentType: .warm,
            source: "ticket",
            confidence: 0.81,
            conflictFingerprint: "fp-1"
        )
        let thought = BASThoughtFrame(stepIndex: 1, decomposeRef: "decomp-1")
        let risk = BASRiskCard(
            totalRisk: 0.83,
            riskLevel: .high,
            factors: ["irreversible", "manipulation"],
            uncertainty: 0.42,
            irreversibility: 0.88,
            manipulationStrength: 0.61,
            gsiScore: 0.57,
            recommendedMode: .delay
        )
        let ticket = BASUpdateTicket(
            ticketID: "ticket-1",
            sessionRef: "session-1",
            summary: "Delay and gather evidence before acting.",
            confidence: 0.76
        )

        #expect(device.schemaVersion == BASDeviceState.currentSchemaVersion)
        #expect(budget.schemaVersion == BASBudgetFrame.currentSchemaVersion)
        #expect(host.schemaVersion == BASHostProfile.currentSchemaVersion)
        #expect(atom.schemaVersion == BASMemoryAtom.currentSchemaVersion)
        #expect(thought.schemaVersion == BASThoughtFrame.currentSchemaVersion)
        #expect(risk.schemaVersion == BASRiskCard.currentSchemaVersion)
        #expect(ticket.schemaVersion == BASUpdateTicket.currentSchemaVersion)
    }

    @Test("protective block action permit encodes the red-line fallback mode")
    func protectiveBlockPermitUsesBlockMode() {
        let permit = BASActionPermit.protectiveBlock(reasonCodes: ["risk.high", "gsi.elevated"])

        #expect(permit.mode == .block)
        #expect(permit.requireSecondCheck)
        #expect(permit.outputLengthCap == 120)
        #expect(permit.templatePolicy == "protective_alternative")
    }

    @Test("service contracts can compose a thin end-to-end turn without leaking layer shortcuts")
    func serviceContractsComposeBrainTurn() {
        struct PowerClock: BASPowerClockServicing {
            func planBudget(deviceState: BASDeviceState, taskPing: String, riskHint: BASBrainRiskLevel?) -> BASBudgetFrame {
                .guardedLocal(maxLoops: riskHint == .high ? 3 : 1, maxCandidates: 2, maxDecodeTokens: 180, retrievalDepth: 3)
            }

            func routeDevice(deviceState: BASDeviceState, budget: BASBudgetFrame) -> BASDeviceRoute {
                budget.deviceRoute
            }

            func scheduleMaintenance(deviceState: BASDeviceState, budget: BASBudgetFrame) -> Bool {
                budget.maintenanceAllowed
            }
        }

        struct Host: BASHostProfileServicing {
            func resolveHost(hostID: String, contextFrame: BASContextFrame?, riskCard: BASRiskCard?) -> BASHostProfile {
                BASHostProfile(hostID: hostID, longTermGoals: ["Stay bounded"], noGoZones: ["dangerous_irreversible"])
            }

            func applyHostGate(profile: BASHostProfile, taskType: BASContextTaskType, riskCard: BASRiskCard?, confidence: Double) -> Double {
                riskCard?.riskLevel == .high ? 0.35 : confidence
            }

            func rollbackHostVersion(profile: BASHostProfile, to versionID: String) -> BASHostVersion {
                BASHostVersion(versionID: versionID, changedFields: ["tonePreference"], reason: "rollback", approvedByPolicy: true)
            }
        }

        struct Context: BASContextServicing {
            func analyzeContext(userInput: String, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASContextFrame {
                BASContextFrame(
                    utterance: userInput,
                    taskType: .conflict,
                    emotionalLoad: 0.8,
                    timePressure: 0.6,
                    relationPattern: "partner",
                    ambiguityScore: 0.4,
                    consequenceLevel: 0.7,
                    manipulationHints: ["time_pressure"],
                    hostRelevance: 0.9
                )
            }
        }

        struct Decompose: BASDecomposeServicing {
            func decompose(contextFrame: BASContextFrame, memoryHints: [String]) -> BASDecomposeFrame {
                BASDecomposeFrame(
                    facts: ["Conflict exists"],
                    goals: ["Respond safely"],
                    emotions: ["angry"],
                    unknowns: ["other side intent"],
                    contradictions: [],
                    pressureSignals: contextFrame.manipulationHints,
                    manipulationSignals: contextFrame.manipulationHints,
                    mirrorText: "You want to respond, but the situation is heated."
                )
            }

            func mirror(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> String {
                decomposeFrame.mirrorText
            }

            func checkContradiction(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> [String] {
                decomposeFrame.contradictions
            }
        }

        struct Memory: BASMemoryServicing {
            func retrieve(decomposeFrame: BASDecomposeFrame, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASMemoryBundle {
                BASMemoryBundle(
                    atoms: [
                        BASMemoryAtom(
                            memoryID: "m-1",
                            summary: "High-risk conflict should cool down first.",
                            contentType: .warm,
                            source: "ticket",
                            confidence: 0.85,
                            conflictFingerprint: "m-1"
                        )
                    ],
                    retrievalTags: ["conflict"],
                    activeHostVersion: hostContext.activeVersion
                )
            }

            func promote(atom: BASMemoryAtom, hostContext: BASHostProfile) -> BASPromotionState {
                atom.frozen ? .frozen : .admitted
            }

            func freeze(memoryID: String) -> Bool { memoryID == "m-1" }
        }

        struct Loop: BASLoopServicing {
            func proposePaths(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> [BASCandidatePath] {
                [
                    BASCandidatePath(
                        candidateID: "c-1",
                        title: "Delay the message",
                        actionSummary: "Wait, collect evidence, then respond.",
                        expectedBenefit: 0.8,
                        expectedCost: 0.2,
                        reversibility: 0.9,
                        confidence: 0.77
                    )
                ]
            }

            func forecast(candidates: [BASCandidatePath], decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle) -> [BASForecastItem] {
                [
                    BASForecastItem(
                        candidateID: "c-1",
                        shortTermOutcome: "Emotion cools",
                        midTermOutcome: "Better odds of a bounded reply",
                        worstCase: "Delay feels uncomfortable",
                        uncertainty: 0.32
                    )
                ]
            }

            func critique(candidates: [BASCandidatePath], forecasts: [BASForecastItem], hostContext: BASHostProfile) -> [BASCritiqueItem] {
                [
                    BASCritiqueItem(
                        candidateID: "c-1",
                        critiqueType: .evidenceGap,
                        critiqueText: "Evidence is still thin for irreversible action.",
                        severity: 0.51
                    )
                ]
            }

            func iterate(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> BASThoughtFrame {
                BASThoughtFrame(
                    stepIndex: 1,
                    decomposeRef: "decomp-1",
                    memoryRefs: memoryBundle.atoms.map(\.memoryID),
                    candidates: proposePaths(decomposeFrame: decomposeFrame, memoryBundle: memoryBundle, budget: budget),
                    forecasts: forecast(candidates: [], decomposeFrame: decomposeFrame, memoryBundle: memoryBundle),
                    critiques: critique(candidates: [], forecasts: [], hostContext: BASHostProfile(hostID: "unused")),
                    stabilityScore: 0.74,
                    stopReason: .riskConverged
                )
            }
        }

        struct TriSelf: BASTriSelfServicing {
            func mergeChoice(thoughtFrame: BASThoughtFrame, hostContext: BASHostProfile) -> ([BASTriSelfScore], BASMergedChoice) {
                let scores = [
                    BASTriSelfScore(candidateID: "c-1", idScore: 0.4, egoScore: 0.81, superegoScore: 0.88, mergedScore: 0.82, veto: false)
                ]
                let choice = BASMergedChoice(candidateID: "c-1", title: "Delay the message", actionSummary: "Pause before acting.")
                return (scores, choice)
            }
        }

        struct Risk: BASRiskServicing {
            func calibrateRisk(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> BASRiskCard {
                BASRiskCard(
                    totalRisk: 0.78,
                    riskLevel: .high,
                    factors: ["emotion_high", "relationship_pressure"],
                    uncertainty: 0.38,
                    irreversibility: 0.72,
                    manipulationStrength: 0.44,
                    gsiScore: 0.41,
                    recommendedMode: .delay
                )
            }

            func computeGSI(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame) -> Double {
                0.41
            }

            func gateAction(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> (BASRiskCard, BASActionPermit) {
                let card = calibrateRisk(contextFrame: contextFrame, thoughtFrame: thoughtFrame, triScores: triScores, budget: budget)
                let permit = BASActionPermit(mode: .delay, reasonCodes: ["risk.high"], requireSecondCheck: true, outputLengthCap: 200, tonePolicy: "calm", templatePolicy: "delay_with_alternative")
                return (card, permit)
            }
        }

        struct Action: BASActionServicing {
            func render(choice: BASMergedChoice, riskCard: BASRiskCard, permit: BASActionPermit, hostContext: BASHostProfile) -> BASRenderedOutput {
                BASRenderedOutput(mode: permit.mode, headline: choice.title, body: choice.actionSummary, alternativeActions: ["Collect evidence first"], explanationCodes: permit.reasonCodes)
            }
        }

        struct Evolution: BASEvolutionServicing {
            func buildTickets(thoughtFrame: BASThoughtFrame, output: BASRenderedOutput, feedbackEvent: BASFeedbackEvent?) -> [BASUpdateTicket] {
                [
                    BASUpdateTicket(
                        ticketID: "ticket-1",
                        sessionRef: "session-1",
                        summary: output.body,
                        memoryWriteSuggestion: "Conflict should cool down before action.",
                        confidence: 0.7
                    )
                ]
            }
        }

        let device = BASDeviceState(
            batteryLevel: 0.44,
            thermalLevel: .warm,
            memoryFreeMB: 1536,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.33,
            gpuLoad: 0.18,
            npuAvailable: true,
            latencyBudgetMs: 1500
        )

        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: PowerClock(),
            hostProfileService: Host(),
            contextService: Context(),
            decomposeService: Decompose(),
            memoryService: Memory(),
            loopService: Loop(),
            triSelfService: TriSelf(),
            riskService: Risk(),
            actionService: Action(),
            evolutionService: Evolution()
        )
        let recordedAt = Date(timeIntervalSince1970: 1_705_000_000)
        let result = coordinator.runTurn(
            BASEBrainTurnRequest(
                userInput: "I want to send a harsh message right now.",
                deviceState: device,
                hostID: "host.primary",
                recordedAt: recordedAt,
                riskHint: .high
            )
        )

        #expect(result.budgetFrame.runMode == .guarded)
        #expect(result.contextFrame.taskType == .conflict)
        #expect(result.memoryBundle.atoms.count == 1)
        #expect(result.thoughtFrame.candidates.count == 1)
        #expect(result.triScores.count == 1)
        #expect(result.riskCard.riskLevel == .high)
        #expect(result.actionPermit.mode == .delay)
        #expect(result.renderedOutput.mode == .delay)
        #expect(result.hostGateValue == 0.35)
        #expect(result.updateTickets.count == 1)
        #expect(!result.updateTickets[0].summary.isEmpty)
        #expect(result.thoughtFold.schemaVersion == BASThoughtFold.currentSchemaVersion)
        #expect(!result.thoughtFold.checksum.isEmpty)
        #expect(result.thoughtFold.compactSlots["task_type"] == BASContextTaskType.conflict.rawValue)
        #expect(result.runtimeTrace.loopCount == 1)
        #expect(result.runtimeTrace.modelRoute == BASDeviceRoute.hybridLocal.rawValue)
        #expect(result.runtimeTrace.recordedAt == recordedAt)
        #expect(result.runtimeTrace.layerEvents.count >= 12)
        #expect(result.runtimeTrace.layerEvents.contains { $0.layerID == "L3" && $0.event == "compression_runtime" })
        #expect(result.runtimeTrace.guardrailFindings.isEmpty)
    }

    @Test("runtime coordinator enforces hard red lines when downstream services misbehave")
    func coordinatorEnforcesHardRedLines() {
        struct PowerClock: BASPowerClockServicing {
            func planBudget(deviceState: BASDeviceState, taskPing: String, riskHint: BASBrainRiskLevel?) -> BASBudgetFrame {
                BASBudgetFrame(
                    runMode: .sentinel,
                    maxLoops: 1,
                    maxCandidates: 1,
                    maxDecodeTokens: 120,
                    retrievalDepth: 1,
                    precisionProfile: .minimal,
                    deviceRoute: .scoutCPU,
                    thermalGuardLevel: .nominal,
                    maintenanceAllowed: false
                )
            }

            func routeDevice(deviceState: BASDeviceState, budget: BASBudgetFrame) -> BASDeviceRoute {
                budget.deviceRoute
            }

            func scheduleMaintenance(deviceState: BASDeviceState, budget: BASBudgetFrame) -> Bool {
                false
            }
        }

        struct Host: BASHostProfileServicing {
            func resolveHost(hostID: String, contextFrame: BASContextFrame?, riskCard: BASRiskCard?) -> BASHostProfile {
                BASHostProfile(hostID: hostID, longTermGoals: ["Stay safe"], noGoZones: ["irreversible"])
            }

            func applyHostGate(profile: BASHostProfile, taskType: BASContextTaskType, riskCard: BASRiskCard?, confidence: Double) -> Double {
                confidence
            }

            func rollbackHostVersion(profile: BASHostProfile, to versionID: String) -> BASHostVersion {
                BASHostVersion(versionID: versionID, changedFields: ["tonePreference"], reason: "rollback", approvedByPolicy: true)
            }
        }

        struct Context: BASContextServicing {
            func analyzeContext(userInput: String, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASContextFrame {
                BASContextFrame(
                    utterance: userInput,
                    taskType: .highConsequence,
                    emotionalLoad: 0.9,
                    timePressure: 0.9,
                    relationPattern: "authority",
                    ambiguityScore: 0.5,
                    consequenceLevel: 0.9,
                    manipulationHints: ["time_pressure", "authority_pressure"],
                    hostRelevance: 0.8
                )
            }
        }

        struct Decompose: BASDecomposeServicing {
            func decompose(contextFrame: BASContextFrame, memoryHints: [String]) -> BASDecomposeFrame {
                BASDecomposeFrame(
                    facts: ["Irreversible action requested"],
                    goals: ["Act immediately"],
                    emotions: ["angry"],
                    unknowns: ["missing evidence"],
                    contradictions: [],
                    pressureSignals: contextFrame.manipulationHints,
                    manipulationSignals: contextFrame.manipulationHints,
                    mirrorText: "The request is heated and lacks evidence."
                )
            }

            func mirror(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> String {
                decomposeFrame.mirrorText
            }

            func checkContradiction(contextFrame: BASContextFrame, decomposeFrame: BASDecomposeFrame) -> [String] {
                []
            }
        }

        struct Memory: BASMemoryServicing {
            func retrieve(decomposeFrame: BASDecomposeFrame, hostContext: BASHostProfile, budget: BASBudgetFrame) -> BASMemoryBundle {
                BASMemoryBundle(
                    atoms: [
                        BASMemoryAtom(memoryID: "m1", summary: "Slow down.", contentType: .warm, source: "ticket", confidence: 0.8, conflictFingerprint: "m1"),
                        BASMemoryAtom(memoryID: "m2", summary: "Check evidence.", contentType: .warm, source: "ticket", confidence: 0.8, conflictFingerprint: "m2"),
                        BASMemoryAtom(memoryID: "m3", summary: "Do not escalate at night.", contentType: .warm, source: "ticket", confidence: 0.8, conflictFingerprint: "m3")
                    ],
                    retrievalTags: ["high_risk", "conflict"],
                    activeHostVersion: hostContext.activeVersion
                )
            }

            func promote(atom: BASMemoryAtom, hostContext: BASHostProfile) -> BASPromotionState { .candidate }
            func freeze(memoryID: String) -> Bool { true }
        }

        struct Loop: BASLoopServicing {
            func proposePaths(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> [BASCandidatePath] {
                [
                    BASCandidatePath(candidateID: "c1", title: "Send now", actionSummary: "Act immediately.", expectedBenefit: 0.7, expectedCost: 0.8, reversibility: 0.1, confidence: 0.8),
                    BASCandidatePath(candidateID: "c2", title: "Threaten escalation", actionSummary: "Escalate pressure.", expectedBenefit: 0.6, expectedCost: 0.9, reversibility: 0.1, confidence: 0.7),
                    BASCandidatePath(candidateID: "c3", title: "Pause", actionSummary: "Wait and review.", expectedBenefit: 0.5, expectedCost: 0.2, reversibility: 0.9, confidence: 0.65)
                ]
            }

            func forecast(candidates: [BASCandidatePath], decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle) -> [BASForecastItem] {
                [
                    BASForecastItem(candidateID: "c1", shortTermOutcome: "Immediate release", midTermOutcome: "Relationship damage", worstCase: "Irreversible escalation", uncertainty: 0.4),
                    BASForecastItem(candidateID: "c2", shortTermOutcome: "Pressure spike", midTermOutcome: "Trust collapse", worstCase: "Public fallout", uncertainty: 0.5),
                    BASForecastItem(candidateID: "c3", shortTermOutcome: "Cooling off", midTermOutcome: "Better evidence", worstCase: "Delay discomfort", uncertainty: 0.2)
                ]
            }

            func critique(candidates: [BASCandidatePath], forecasts: [BASForecastItem], hostContext: BASHostProfile) -> [BASCritiqueItem] {
                [
                    BASCritiqueItem(candidateID: "c1", critiqueType: .emotionalBias, critiqueText: "Emotion is driving urgency.", severity: 0.8),
                    BASCritiqueItem(candidateID: "c2", critiqueType: .boundaryConflict, critiqueText: "This path breaks safety boundaries.", severity: 0.9),
                    BASCritiqueItem(candidateID: "c3", critiqueType: .evidenceGap, critiqueText: "Evidence is still incomplete.", severity: 0.4)
                ]
            }

            func iterate(decomposeFrame: BASDecomposeFrame, memoryBundle: BASMemoryBundle, budget: BASBudgetFrame) -> BASThoughtFrame {
                BASThoughtFrame(
                    stepIndex: 5,
                    decomposeRef: "decomp-unsafe",
                    memoryRefs: memoryBundle.atoms.map(\.memoryID),
                    candidates: proposePaths(decomposeFrame: decomposeFrame, memoryBundle: memoryBundle, budget: budget),
                    forecasts: forecast(candidates: [], decomposeFrame: decomposeFrame, memoryBundle: memoryBundle),
                    critiques: critique(candidates: [], forecasts: [], hostContext: BASHostProfile(hostID: "unused")),
                    stabilityScore: 0.31,
                    stopReason: .candidateStable
                )
            }
        }

        struct TriSelf: BASTriSelfServicing {
            func mergeChoice(thoughtFrame: BASThoughtFrame, hostContext: BASHostProfile) -> ([BASTriSelfScore], BASMergedChoice) {
                (
                    [
                        BASTriSelfScore(candidateID: "c1", idScore: 0.9, egoScore: 0.3, superegoScore: 0.1, mergedScore: 0.6, veto: false),
                        BASTriSelfScore(candidateID: "c2", idScore: 0.8, egoScore: 0.2, superegoScore: 0.1, mergedScore: 0.5, veto: false),
                        BASTriSelfScore(candidateID: "c3", idScore: 0.2, egoScore: 0.7, superegoScore: 0.9, mergedScore: 0.75, veto: false)
                    ],
                    BASMergedChoice(candidateID: "c1", title: "Send now", actionSummary: "Send the message now.")
                )
            }
        }

        struct Risk: BASRiskServicing {
            func calibrateRisk(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> BASRiskCard {
                BASRiskCard(
                    totalRisk: 0.97,
                    riskLevel: .extreme,
                    factors: ["irreversible", "manipulation", "emotion_high"],
                    uncertainty: 0.5,
                    irreversibility: 0.95,
                    manipulationStrength: 0.8,
                    gsiScore: 0.82,
                    recommendedMode: .block
                )
            }

            func computeGSI(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame) -> Double { 0.82 }

            func gateAction(contextFrame: BASContextFrame, thoughtFrame: BASThoughtFrame, triScores: [BASTriSelfScore], budget: BASBudgetFrame) -> (BASRiskCard, BASActionPermit) {
                (
                    calibrateRisk(contextFrame: contextFrame, thoughtFrame: thoughtFrame, triScores: triScores, budget: budget),
                    BASActionPermit(mode: .answer, reasonCodes: ["unsafe.answer"], outputLengthCap: 300, tonePolicy: "direct", templatePolicy: "default")
                )
            }
        }

        struct Action: BASActionServicing {
            func render(choice: BASMergedChoice, riskCard: BASRiskCard, permit: BASActionPermit, hostContext: BASHostProfile) -> BASRenderedOutput {
                BASRenderedOutput(mode: permit.mode, headline: choice.title, body: choice.actionSummary, alternativeActions: ["Pause and gather evidence"], explanationCodes: permit.reasonCodes)
            }
        }

        struct Evolution: BASEvolutionServicing {
            func buildTickets(thoughtFrame: BASThoughtFrame, output: BASRenderedOutput, feedbackEvent: BASFeedbackEvent?) -> [BASUpdateTicket] {
                [
                    BASUpdateTicket(
                        ticketID: "ticket-unsafe",
                        sessionRef: "session-unsafe",
                        summary: output.body,
                        memoryWriteSuggestion: "Persist as cold memory immediately.",
                        hostProfileChangeSuggestion: "Always use the hardest tone.",
                        confidence: 0.9,
                        conflictFlag: false,
                        requiresReview: false
                    )
                ]
            }
        }

        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: PowerClock(),
            hostProfileService: Host(),
            contextService: Context(),
            decomposeService: Decompose(),
            memoryService: Memory(),
            loopService: Loop(),
            triSelfService: TriSelf(),
            riskService: Risk(),
            actionService: Action(),
            evolutionService: Evolution()
        )

        let result = coordinator.runTurn(
            BASEBrainTurnRequest(
                userInput: "Send the irreversible escalation now.",
                deviceState: BASDeviceState(
                    batteryLevel: 0.22,
                    thermalLevel: .warm,
                    memoryFreeMB: 1024,
                    networkState: .constrained,
                    foregroundState: .foreground,
                    cpuLoad: 0.4,
                    gpuLoad: 0.2,
                    npuAvailable: false,
                    latencyBudgetMs: 1200
                ),
                hostID: "host.unsafe",
                riskHint: .high
            )
        )

        #expect(result.budgetFrame.runMode == .guarded)
        #expect(result.budgetFrame.precisionProfile == .protected)
        #expect(result.memoryBundle.atoms.count == result.budgetFrame.retrievalDepth)
        #expect(result.thoughtFrame.stepIndex == result.budgetFrame.maxLoops)
        #expect(result.thoughtFrame.candidates.count == result.budgetFrame.maxCandidates)
        #expect(result.actionPermit.mode == .block)
        #expect(result.renderedOutput.mode == .block)
        #expect(result.updateTickets.allSatisfy { $0.requiresReview })
        #expect(result.updateTickets.contains(where: { $0.conflictFlag }))
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "budget.high_risk_fast_path" }))
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "loop.max_loops_clamped" }))
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "risk.extreme_answer_blocked" }))
        #expect(result.runtimeTrace.guardrailFindings.contains(where: { $0.code == "evolution.high_risk_review_required" }))
        #expect(result.runtimeTrace.recommendedKillSwitches.contains(.forceGuardMode))
        #expect(result.runtimeTrace.recommendedKillSwitches.contains(.forceProtectedPermit))
        #expect(result.runtimeTrace.recommendedKillSwitches.contains(.requireReviewedWrites))
    }
}
