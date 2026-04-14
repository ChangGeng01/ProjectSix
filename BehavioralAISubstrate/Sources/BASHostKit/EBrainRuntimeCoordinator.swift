import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public struct BASEBrainTurnRequest: Codable, Equatable, Sendable {
    public var userInput: String
    public var deviceState: BASDeviceState
    public var hostID: String
    public var recordedAt: Date
    public var riskHint: BASBrainRiskLevel?
    public var feedbackEvent: BASFeedbackEvent?
    public var activeKillSwitches: [BASKillSwitchID]

    public init(
        userInput: String,
        deviceState: BASDeviceState,
        hostID: String,
        recordedAt: Date = .now,
        riskHint: BASBrainRiskLevel? = nil,
        feedbackEvent: BASFeedbackEvent? = nil,
        activeKillSwitches: [BASKillSwitchID] = []
    ) {
        self.userInput = userInput
        self.deviceState = deviceState
        self.hostID = hostID
        self.recordedAt = recordedAt
        self.riskHint = riskHint
        self.feedbackEvent = feedbackEvent
        self.activeKillSwitches = activeKillSwitches
    }
}

public struct BASEBrainTurnResult: Codable, Equatable, Sendable {
    public var deviceState: BASDeviceState
    public var budgetFrame: BASBudgetFrame
    public var hostContext: BASHostProfile
    public var contextFrame: BASContextFrame
    public var decomposeFrame: BASDecomposeFrame
    public var memoryBundle: BASMemoryBundle
    public var thoughtFrame: BASThoughtFrame
    public var thoughtFold: BASThoughtFold
    public var triScores: [BASTriSelfScore]
    public var mergedChoice: BASMergedChoice
    public var riskCard: BASRiskCard
    public var actionPermit: BASActionPermit
    public var hostGateValue: Double
    public var renderedOutput: BASRenderedOutput
    public var updateTickets: [BASUpdateTicket]
    public var runtimeTrace: BASRuntimeTrace

    public init(
        deviceState: BASDeviceState,
        budgetFrame: BASBudgetFrame,
        hostContext: BASHostProfile,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        thoughtFrame: BASThoughtFrame,
        thoughtFold: BASThoughtFold,
        triScores: [BASTriSelfScore],
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        hostGateValue: Double,
        renderedOutput: BASRenderedOutput,
        updateTickets: [BASUpdateTicket],
        runtimeTrace: BASRuntimeTrace
    ) {
        self.deviceState = deviceState
        self.budgetFrame = budgetFrame
        self.hostContext = hostContext
        self.contextFrame = contextFrame
        self.decomposeFrame = decomposeFrame
        self.memoryBundle = memoryBundle
        self.thoughtFrame = thoughtFrame
        self.thoughtFold = thoughtFold
        self.triScores = triScores
        self.mergedChoice = mergedChoice
        self.riskCard = riskCard
        self.actionPermit = actionPermit
        self.hostGateValue = hostGateValue
        self.renderedOutput = renderedOutput
        self.updateTickets = updateTickets
        self.runtimeTrace = runtimeTrace
    }
}

public extension BASEBrainTurnResult {
    var evolutionLineageSummary: BASEvolutionLineageSummary {
        BASEvolutionLineageSummary(
            recordedAt: runtimeTrace.recordedAt,
            sessionID: runtimeTrace.sessionID,
            taskType: contextFrame.taskType.rawValue,
            riskLevel: riskCard.riskLevel.rawValue,
            permitMode: actionPermit.mode.rawValue,
            hostGatePercent: Int((hostGateValue * 100).rounded()),
            thoughtFoldChecksum: thoughtFold.checksum,
            updateTicketSummaries: Array(updateTickets.map(\.summary).prefix(3)),
            activeKillSwitches: Array(runtimeTrace.activeKillSwitches.map(\.rawValue).prefix(4)),
            guardrailFindings: Array(runtimeTrace.guardrailFindings.map(\.summary).prefix(3)),
            recommendedKillSwitches: Array(runtimeTrace.recommendedKillSwitches.map(\.rawValue).prefix(3))
        )
    }
}

public struct BASEBrainRuntimeCoordinator {
    public var powerClockService: any BASPowerClockServicing
    public var hostProfileService: any BASHostProfileServicing
    public var contextService: any BASContextServicing
    public var decomposeService: any BASDecomposeServicing
    public var memoryService: any BASMemoryServicing
    public var loopService: any BASLoopServicing
    public var triSelfService: any BASTriSelfServicing
    public var riskService: any BASRiskServicing
    public var actionService: any BASActionServicing
    public var evolutionService: any BASEvolutionServicing

    public init(
        powerClockService: any BASPowerClockServicing,
        hostProfileService: any BASHostProfileServicing,
        contextService: any BASContextServicing,
        decomposeService: any BASDecomposeServicing,
        memoryService: any BASMemoryServicing,
        loopService: any BASLoopServicing,
        triSelfService: any BASTriSelfServicing,
        riskService: any BASRiskServicing,
        actionService: any BASActionServicing,
        evolutionService: any BASEvolutionServicing
    ) {
        self.powerClockService = powerClockService
        self.hostProfileService = hostProfileService
        self.contextService = contextService
        self.decomposeService = decomposeService
        self.memoryService = memoryService
        self.loopService = loopService
        self.triSelfService = triSelfService
        self.riskService = riskService
        self.actionService = actionService
        self.evolutionService = evolutionService
    }

    public func runTurn(
        _ request: BASEBrainTurnRequest
    ) -> BASEBrainTurnResult {
        let requestedBudget = powerClockService.planBudget(
            deviceState: request.deviceState,
            taskPing: request.userInput,
            riskHint: request.riskHint
        )
        let (plannedBudget, budgetFindings) = normalizeBudget(
            requestedBudget,
            riskHint: request.riskHint,
            activeKillSwitches: request.activeKillSwitches
        )

        let routedBudget = BASBudgetFrame(
            schemaVersion: plannedBudget.schemaVersion,
            runMode: plannedBudget.runMode,
            maxLoops: plannedBudget.maxLoops,
            maxCandidates: plannedBudget.maxCandidates,
            maxDecodeTokens: plannedBudget.maxDecodeTokens,
            retrievalDepth: plannedBudget.retrievalDepth,
            precisionProfile: plannedBudget.precisionProfile,
            deviceRoute: powerClockService.routeDevice(
                deviceState: request.deviceState,
                budget: plannedBudget
            ),
            thermalGuardLevel: plannedBudget.thermalGuardLevel,
            maintenanceAllowed: powerClockService.scheduleMaintenance(
                deviceState: request.deviceState,
                budget: plannedBudget
            )
        )

        let hostContext = hostProfileService.resolveHost(
            hostID: request.hostID,
            contextFrame: nil,
            riskCard: nil
        )
        let contextFrame = contextService.analyzeContext(
            userInput: request.userInput,
            hostContext: hostContext,
            budget: routedBudget
        )

        var decomposeFrame = decomposeService.decompose(
            contextFrame: contextFrame,
            memoryHints: []
        )
        decomposeFrame.mirrorText = decomposeService.mirror(
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame
        )
        if decomposeFrame.contradictions.isEmpty {
            decomposeFrame.contradictions = decomposeService.checkContradiction(
                contextFrame: contextFrame,
                decomposeFrame: decomposeFrame
            )
        }

        let rawMemoryBundle = memoryService.retrieve(
            decomposeFrame: decomposeFrame,
            hostContext: hostContext,
            budget: routedBudget
        )
        let (memoryBundle, memoryFindings) = normalizeMemoryBundle(
            rawMemoryBundle,
            budget: routedBudget
        )

        var thoughtFrame = loopService.iterate(
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            budget: routedBudget
        )
        if thoughtFrame.candidates.isEmpty {
            thoughtFrame.candidates = loopService.proposePaths(
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle,
                budget: routedBudget
            )
        }
        if thoughtFrame.forecasts.isEmpty {
            thoughtFrame.forecasts = loopService.forecast(
                candidates: thoughtFrame.candidates,
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle
            )
        }
        if thoughtFrame.critiques.isEmpty {
            thoughtFrame.critiques = loopService.critique(
                candidates: thoughtFrame.candidates,
                forecasts: thoughtFrame.forecasts,
                hostContext: hostContext
            )
        }
        let (normalizedThoughtFrame, loopFindings) = normalizeThoughtFrame(
            thoughtFrame,
            budget: routedBudget
        )
        thoughtFrame = normalizedThoughtFrame

        let (triScores, mergedChoice) = triSelfService.mergeChoice(
            thoughtFrame: thoughtFrame,
            hostContext: hostContext
        )
        thoughtFrame.triScores = triScores

        let (rawRiskCard, rawActionPermit) = riskService.gateAction(
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            triScores: triScores,
            budget: routedBudget
        )
        let (riskCard, actionPermit, riskFindings) = normalizeRiskDecision(
            riskCard: rawRiskCard,
            actionPermit: rawActionPermit,
            budget: routedBudget,
            activeKillSwitches: request.activeKillSwitches
        )
        thoughtFrame.riskCard = riskCard
        thoughtFrame.actionPermit = actionPermit

        let hostGateValue = hostProfileService.applyHostGate(
            profile: hostContext,
            taskType: contextFrame.taskType,
            riskCard: riskCard,
            confidence: triScores.map(\.mergedScore).max() ?? 0
        )

        let renderedOutput = actionService.render(
            choice: mergedChoice,
            riskCard: riskCard,
            permit: actionPermit,
            hostContext: hostContext
        )
        let rawTickets = evolutionService.buildTickets(
            thoughtFrame: thoughtFrame,
            output: renderedOutput,
            feedbackEvent: request.feedbackEvent
        )
        let (updateTickets, evolutionFindings) = normalizeUpdateTickets(
            rawTickets,
            riskCard: riskCard,
            activeKillSwitches: request.activeKillSwitches
        )
        let auditFindings = budgetFindings + memoryFindings + loopFindings + riskFindings + evolutionFindings
        let killSwitches = recommendedKillSwitches(for: auditFindings)
        let thoughtFold = buildThoughtFold(
            request: request,
            hostContext: hostContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            riskCard: riskCard,
            hostGateValue: hostGateValue
        )
        let runtimeTrace = buildRuntimeTrace(
            request: request,
            budgetFrame: routedBudget,
            hostContext: hostContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            riskCard: riskCard,
            actionPermit: actionPermit,
            activeKillSwitches: request.activeKillSwitches,
            auditFindings: auditFindings,
            killSwitches: killSwitches
        )

        return BASEBrainTurnResult(
            deviceState: request.deviceState,
            budgetFrame: routedBudget,
            hostContext: hostContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            triScores: triScores,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            hostGateValue: hostGateValue,
            renderedOutput: renderedOutput,
            updateTickets: updateTickets,
            runtimeTrace: runtimeTrace
        )
    }

    private func normalizeBudget(
        _ budget: BASBudgetFrame,
        riskHint: BASBrainRiskLevel?,
        activeKillSwitches: [BASKillSwitchID]
    ) -> (BASBudgetFrame, [BASRuntimeAuditFinding]) {
        var normalized = budget
        var findings: [BASRuntimeAuditFinding] = []

        if activeKillSwitches.contains(.disableFastPath), normalized.runMode == .sentinel {
            normalized.runMode = .engage
            normalized.maxLoops = max(normalized.maxLoops, 1)
            normalized.maxCandidates = max(normalized.maxCandidates, 2)
            findings.append(
                BASRuntimeAuditFinding(
                    code: "kill_switch.disable_fast_path",
                    layerID: "L1",
                    summary: "Disable-fast-path kill switch lifted the run mode out of sentinel execution.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if activeKillSwitches.contains(.forceGuardMode) {
            normalized.runMode = .guarded
            normalized.maxLoops = max(normalized.maxLoops, 2)
            normalized.maxCandidates = max(normalized.maxCandidates, 2)
            normalized.retrievalDepth = max(normalized.retrievalDepth, 3)
            normalized.precisionProfile = .protected
            findings.append(
                BASRuntimeAuditFinding(
                    code: "kill_switch.force_guard_mode",
                    layerID: "L1",
                    summary: "Force-guard-mode kill switch escalated the turn into guarded execution.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if let riskHint, riskHint >= .high, normalized.runMode == .sentinel {
            normalized.runMode = .guarded
            normalized.maxLoops = max(normalized.maxLoops, riskHint == .extreme ? 2 : 3)
            normalized.maxCandidates = max(normalized.maxCandidates, 2)
            normalized.retrievalDepth = max(normalized.retrievalDepth, 3)
            normalized.precisionProfile = .protected
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.high_risk_fast_path",
                    layerID: "L1",
                    summary: "High-risk input attempted sentinel fast path and was escalated to guarded budget.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if let riskHint, riskHint == .extreme, normalized.runMode != .guarded {
            normalized.runMode = .guarded
            normalized.maxLoops = max(normalized.maxLoops, 2)
            normalized.maxCandidates = min(max(normalized.maxCandidates, 1), 2)
            normalized.retrievalDepth = max(normalized.retrievalDepth, 3)
            normalized.precisionProfile = .protected
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.extreme_guarded_mode",
                    layerID: "L1",
                    summary: "Extreme-risk input was forced onto guarded mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if normalized.maxLoops < 1 {
            normalized.maxLoops = 1
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.loop_floor",
                    layerID: "L1",
                    summary: "Loop budget was raised to the minimum executable floor.",
                    severity: .low,
                    enforced: true
                )
            )
        }

        if normalized.maxCandidates < 1 {
            normalized.maxCandidates = 1
            findings.append(
                BASRuntimeAuditFinding(
                    code: "budget.candidate_floor",
                    layerID: "L1",
                    summary: "Candidate budget was raised to preserve at least one executable path.",
                    severity: .low,
                    enforced: true
                )
            )
        }

        return (normalized, findings)
    }

    private func normalizeMemoryBundle(
        _ bundle: BASMemoryBundle,
        budget: BASBudgetFrame
    ) -> (BASMemoryBundle, [BASRuntimeAuditFinding]) {
        var normalized = bundle
        var findings: [BASRuntimeAuditFinding] = []

        if normalized.atoms.count > budget.retrievalDepth {
            normalized.atoms = Array(normalized.atoms.prefix(budget.retrievalDepth))
            findings.append(
                BASRuntimeAuditFinding(
                    code: "memory.retrieval_depth_clamped",
                    layerID: "L8",
                    summary: "Retrieved memory atoms exceeded retrieval depth and were clamped to budget.",
                    severity: .medium,
                    enforced: true
                )
            )
        }

        return (normalized, findings)
    }

    private func normalizeThoughtFrame(
        _ thoughtFrame: BASThoughtFrame,
        budget: BASBudgetFrame
    ) -> (BASThoughtFrame, [BASRuntimeAuditFinding]) {
        var normalized = thoughtFrame
        var findings: [BASRuntimeAuditFinding] = []

        if normalized.stepIndex > budget.maxLoops {
            normalized.stepIndex = budget.maxLoops
            normalized.stopReason = .maxLoopsReached
            findings.append(
                BASRuntimeAuditFinding(
                    code: "loop.max_loops_clamped",
                    layerID: "L9",
                    summary: "Dream loop exceeded the planned loop budget and was clamped to the maximum.",
                    severity: .high,
                    enforced: true
                )
            )
        } else if normalized.stepIndex < 1 {
            normalized.stepIndex = 1
        }

        if normalized.candidates.count > budget.maxCandidates {
            normalized.candidates = Array(normalized.candidates.prefix(budget.maxCandidates))
            let allowedCandidateIDs = Set(normalized.candidates.map(\.candidateID))
            normalized.forecasts = normalized.forecasts.filter { allowedCandidateIDs.contains($0.candidateID) }
            normalized.critiques = normalized.critiques.filter { allowedCandidateIDs.contains($0.candidateID) }
            normalized.triScores = normalized.triScores.filter { allowedCandidateIDs.contains($0.candidateID) }
            findings.append(
                BASRuntimeAuditFinding(
                    code: "loop.candidate_budget_clamped",
                    layerID: "L9",
                    summary: "Candidate generation exceeded budget and was clamped to the allowed path count.",
                    severity: .medium,
                    enforced: true
                )
            )
        }

        return (normalized, findings)
    }

    private func normalizeRiskDecision(
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        budget: BASBudgetFrame,
        activeKillSwitches: [BASKillSwitchID]
    ) -> (BASRiskCard, BASActionPermit, [BASRuntimeAuditFinding]) {
        var normalizedPermit = actionPermit
        var findings: [BASRuntimeAuditFinding] = []

        if activeKillSwitches.contains(.forceProtectedPermit),
           normalizedPermit.mode == .answer || normalizedPermit.mode == .compare {
            normalizedPermit = enforcedPermit(
                targetMode: .delay,
                from: normalizedPermit,
                reasonCode: "kill_switch.force_protected_permit"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "kill_switch.force_protected_permit",
                    layerID: "L11",
                    summary: "Force-protected-permit kill switch downgraded the turn into a protected output mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if riskCard.riskLevel == .extreme, normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: .block,
                from: normalizedPermit,
                reasonCode: "redline.extreme_answer_blocked"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.extreme_answer_blocked",
                    layerID: "L11",
                    summary: "Extreme-risk output was prevented from falling through to direct answer mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if riskCard.gsiScore >= 0.75, normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: .delay,
                from: normalizedPermit,
                reasonCode: "redline.gsi_delay"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.gsi_answer_downgraded",
                    layerID: "L11",
                    summary: "Elevated GSI forced the output into delay mode instead of direct answer mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if riskCard.riskLevel >= .high,
           riskCard.recommendedMode != .answer,
           normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: riskCard.recommendedMode,
                from: normalizedPermit,
                reasonCode: "redline.recommended_mode_enforced"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.recommended_mode_enforced",
                    layerID: "L11",
                    summary: "Direct answer mode was replaced with the calibrated risk-mode recommendation.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        if budget.runMode == .guarded, riskCard.riskLevel >= .high, normalizedPermit.mode == .answer {
            normalizedPermit = enforcedPermit(
                targetMode: .delay,
                from: normalizedPermit,
                reasonCode: "redline.guarded_mode_delay"
            )
            findings.append(
                BASRuntimeAuditFinding(
                    code: "risk.guarded_mode_answer_downgraded",
                    layerID: "L11",
                    summary: "Guarded mode rejected a direct answer and forced a safer output mode.",
                    severity: .high,
                    enforced: true
                )
            )
        }

        return (riskCard, normalizedPermit, findings)
    }

    private func normalizeUpdateTickets(
        _ tickets: [BASUpdateTicket],
        riskCard: BASRiskCard,
        activeKillSwitches: [BASKillSwitchID]
    ) -> ([BASUpdateTicket], [BASRuntimeAuditFinding]) {
        if activeKillSwitches.contains(.requireReviewedWrites) {
            var findings: [BASRuntimeAuditFinding] = []
            let normalized = tickets.map { ticket in
                guard !ticket.requiresReview,
                      ticket.memoryWriteSuggestion != nil || ticket.hostProfileChangeSuggestion != nil else {
                    return ticket
                }

                findings.append(
                    BASRuntimeAuditFinding(
                        code: "kill_switch.require_reviewed_writes",
                        layerID: "L13",
                        summary: "Require-reviewed-writes kill switch forced persistent write proposals back into review.",
                        severity: .high,
                        enforced: true
                    )
                )

                var adjusted = ticket
                adjusted.requiresReview = true
                adjusted.conflictFlag = true
                return adjusted
            }
            return (normalized, findings)
        }

        guard riskCard.riskLevel >= .high else {
            return (tickets, [])
        }

        var findings: [BASRuntimeAuditFinding] = []
        let normalized = tickets.map { ticket in
            guard !ticket.requiresReview,
                  ticket.memoryWriteSuggestion != nil || ticket.hostProfileChangeSuggestion != nil else {
                return ticket
            }

            findings.append(
                BASRuntimeAuditFinding(
                    code: "evolution.high_risk_review_required",
                    layerID: "L13",
                    summary: "High-risk turns cannot propose persistent writes without review; ticket was forced into review state.",
                    severity: .high,
                    enforced: true
                )
            )

            var adjusted = ticket
            adjusted.requiresReview = true
            adjusted.conflictFlag = true
            return adjusted
        }

        return (normalized, findings)
    }

    private func enforcedPermit(
        targetMode: BASActionPermitMode,
        from permit: BASActionPermit,
        reasonCode: String
    ) -> BASActionPermit {
        let reasonCodes = unique(permit.reasonCodes + [reasonCode])

        switch targetMode {
        case .answer:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .answer,
                reasonCodes: reasonCodes,
                requireSecondCheck: permit.requireSecondCheck,
                outputLengthCap: permit.outputLengthCap,
                tonePolicy: permit.tonePolicy,
                templatePolicy: permit.templatePolicy
            )
        case .compare:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .compare,
                reasonCodes: reasonCodes,
                requireSecondCheck: false,
                outputLengthCap: min(permit.outputLengthCap, 220),
                tonePolicy: "grounded_compare",
                templatePolicy: "bounded_compare"
            )
        case .delay:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .delay,
                reasonCodes: reasonCodes,
                requireSecondCheck: true,
                outputLengthCap: min(permit.outputLengthCap, 160),
                tonePolicy: "calm_guarded",
                templatePolicy: "delay_with_alternative"
            )
        case .block:
            return BASActionPermit.protectiveBlock(reasonCodes: reasonCodes)
        case .replace:
            return BASActionPermit(
                schemaVersion: permit.schemaVersion,
                mode: .replace,
                reasonCodes: reasonCodes,
                requireSecondCheck: false,
                outputLengthCap: min(permit.outputLengthCap, 180),
                tonePolicy: "clear_firm",
                templatePolicy: "protective_alternative"
            )
        }
    }

    private func recommendedKillSwitches(
        for findings: [BASRuntimeAuditFinding]
    ) -> [BASKillSwitchID] {
        var switches = Set<BASKillSwitchID>()

        for finding in findings where finding.enforced {
            switch finding.code {
            case let code where code.hasPrefix("budget."):
                switches.insert(.forceGuardMode)
                switches.insert(.disableFastPath)
            case let code where code.hasPrefix("risk."):
                switches.insert(.forceProtectedPermit)
            case let code where code.hasPrefix("evolution."):
                switches.insert(.requireReviewedWrites)
            default:
                break
            }
        }

        return switches.sorted { $0.rawValue < $1.rawValue }
    }

    private func buildRuntimeTrace(
        request: BASEBrainTurnRequest,
        budgetFrame: BASBudgetFrame,
        hostContext: BASHostProfile,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        thoughtFrame: BASThoughtFrame,
        thoughtFold: BASThoughtFold,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        activeKillSwitches: [BASKillSwitchID],
        auditFindings: [BASRuntimeAuditFinding],
        killSwitches: [BASKillSwitchID]
    ) -> BASRuntimeTrace {
        let retrievalDepth = max(1, budgetFrame.retrievalDepth)
        let loopCount = max(1, thoughtFrame.stepIndex)
        let powerEstimate = min(
            1,
            0.12
            + (Double(loopCount) * 0.10)
            + (Double(budgetFrame.maxCandidates) * 0.05)
            + (budgetFrame.precisionProfile == .protected ? 0.08 : 0)
            + (budgetFrame.runMode == .guarded ? 0.12 : 0)
        )
        let cacheHitRate = min(1, Double(memoryBundle.atoms.count) / Double(retrievalDepth))

        return BASRuntimeTrace(
            sessionID: [
                request.hostID,
                contextFrame.taskType.rawValue,
                budgetFrame.runMode.rawValue
            ].joined(separator: "|"),
            recordedAt: request.recordedAt,
            layerEvents: [
                BASRuntimeTraceEvent(
                    layerID: "L1",
                    event: "budget",
                    detail: "Run mode \(budgetFrame.runMode.rawValue), \(budgetFrame.maxLoops) loops, \(budgetFrame.maxCandidates) candidates."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L2",
                    event: "neural_core",
                    detail: "Route \(budgetFrame.deviceRoute.rawValue) with \(budgetFrame.precisionProfile.rawValue) precision and decode cap \(budgetFrame.maxDecodeTokens)."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L3",
                    event: "compression_runtime",
                    detail: "ThoughtFold \(thoughtFold.foldID) checksum \(thoughtFold.checksum.prefix(12)) prepared for replay."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L4",
                    event: "foundation",
                    detail: "Foundation priors aligned to \(contextFrame.taskType.rawValue) with ambiguity \(Int((contextFrame.ambiguityScore * 100).rounded()))."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L5",
                    event: "host_context",
                    detail: "Host version \(hostContext.activeVersion) resolved with \(hostContext.styleConstraints.count) style constraints."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L6",
                    event: "context",
                    detail: "Task \(contextFrame.taskType.rawValue) with \(contextFrame.manipulationHints.count) manipulation hints."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L7",
                    event: "decompose",
                    detail: "Decomposition captured \(decomposeFrame.facts.count) facts, \(decomposeFrame.unknowns.count) unknowns, and \(decomposeFrame.contradictions.count) contradictions."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L8",
                    event: "memory",
                    detail: "Retrieved \(memoryBundle.atoms.count) atoms with \(Int((cacheHitRate * 100).rounded()))% cache reuse."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L9",
                    event: "loop",
                    detail: "Loop converged after \(loopCount) rounds with stop reason \((thoughtFrame.stopReason ?? .candidateStable).rawValue)."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L10",
                    event: "triself",
                    detail: "Merged \(thoughtFrame.triScores.count) tri-self scores."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L11",
                    event: "risk_gate",
                    detail: "Risk \(riskCard.riskLevel.rawValue) with GSI \(Int((riskCard.gsiScore * 100).rounded())) produced permit \(actionPermit.mode.rawValue)."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L12",
                    event: "render",
                    detail: "Rendered \(actionPermit.mode.rawValue) output."
                ),
                BASRuntimeTraceEvent(
                    layerID: "L13",
                    event: "evolution",
                    detail: "Generated \(thoughtFrame.memoryRefs.count) memory refs and \(thoughtFrame.candidates.count) candidate signatures for review."
                )
            ],
            latencyBreakdownMs: [
                "power_clock": 6,
                "host_profile": 5,
                "context": 12,
                "decompose": 15,
                "memory": max(8, memoryBundle.atoms.count * 4),
                "loop": max(12, loopCount * 18),
                "triself": 7,
                "risk": 9,
                "action": 6,
                "evolution": 4
            ],
            powerEstimate: powerEstimate,
            thermalTrace: [
                request.deviceState.thermalLevel.rawValue,
                budgetFrame.thermalGuardLevel.rawValue
            ],
            modelRoute: budgetFrame.deviceRoute.rawValue,
            loopCount: loopCount,
            cacheHitRate: cacheHitRate,
            activeKillSwitches: activeKillSwitches.sorted { $0.rawValue < $1.rawValue },
            guardrailFindings: auditFindings,
            recommendedKillSwitches: killSwitches
        )
    }

    private func buildThoughtFold(
        request: BASEBrainTurnRequest,
        hostContext: BASHostProfile,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        thoughtFrame: BASThoughtFrame,
        riskCard: BASRiskCard,
        hostGateValue: Double
    ) -> BASThoughtFold {
        let compactSlots = [
            "task_type": contextFrame.taskType.rawValue,
            "host_version": hostContext.activeVersion,
            "facts": String(decomposeFrame.facts.count),
            "unknowns": String(decomposeFrame.unknowns.count),
            "risk_level": riskCard.riskLevel.rawValue,
            "permit_mode": thoughtFrame.actionPermit?.mode.rawValue ?? riskCard.recommendedMode.rawValue,
            "stability": String(format: "%.2f", thoughtFrame.stabilityScore),
            "stop_reason": (thoughtFrame.stopReason ?? .candidateStable).rawValue,
            "gate": String(format: "%.2f", hostGateValue),
            "mirror": condensed(decomposeFrame.mirrorText, limit: 96)
        ]

        let candidateSignatures = thoughtFrame.candidates.map { candidate in
            [
                candidate.candidateID,
                candidate.title,
                String(format: "%.2f", candidate.confidence),
                String(format: "%.2f", candidate.reversibility)
            ].joined(separator: "|")
        }

        let restorePointer = [
            request.hostID,
            hostContext.activeVersion,
            "step:\(thoughtFrame.stepIndex)",
            "risk:\(riskCard.riskLevel.rawValue)"
        ].joined(separator: "::")

        let checksumSeed = (
            compactSlots.keys.sorted().map { "\($0)=\(compactSlots[$0] ?? "")" }
            + candidateSignatures
            + [restorePointer]
        ).joined(separator: "||")

        return BASThoughtFold(
            foldID: "\(request.hostID).\(thoughtFrame.stepIndex)",
            compactSlots: compactSlots,
            candidateSignatures: candidateSignatures,
            riskSnapshot: riskCard,
            hostEffectSummary: condensed(hostContext.styleConstraints.joined(separator: " • "), limit: 120),
            restorePointer: restorePointer,
            checksum: fingerprint(for: checksumSeed)
        )
    }

    private func condensed(_ value: String, limit: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "..."
    }

    private func fingerprint(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
