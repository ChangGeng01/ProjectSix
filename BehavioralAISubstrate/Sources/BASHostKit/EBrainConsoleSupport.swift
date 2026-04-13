import Foundation
import BASAdmin
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public enum BASEBrainConsoleSupport {
    public static func inspectionBundle(
        for turn: BASEBrainTurnResult,
        generatedAt: Date = .now
    ) -> BASInspectionBundle {
        BASInspectionBundleBuilder.build(
            generatedAt: generatedAt,
            trace: executionTrace(for: turn),
            brainState: currentBrainState(for: turn),
            runtimeContext: runtimeContext(for: turn),
            policyDecision: policyDecision(for: turn)
        )
    }

    public static func mergedSnapshot(
        _ snapshot: BASConsoleSnapshot,
        with turn: BASEBrainTurnResult
    ) -> BASConsoleSnapshot {
        var merged = snapshot
        let inspectionBundle = inspectionBundle(for: turn, generatedAt: snapshot.generatedAt)

        merged.runtimeSummary = runtimeSummary(for: turn, fallback: snapshot.runtimeSummary)
        merged.brainSummary = brainSummary(for: turn, fallback: snapshot.brainSummary)
        merged.reports = merged.reports.map { mergedReport($0, turn: turn) }
        merged.blockerSummary = mergedBlockers(
            existing: merged.blockerSummary,
            reportBlockers: merged.reports.flatMap(\.blockers),
            inspection: inspectionBundle
        )
        merged.inspectionBundle = inspectionBundle

        return merged
    }

    public static func runtimeSummary(
        for turn: BASEBrainTurnResult,
        fallback: String? = nil
    ) -> String {
        let eBrainSummary = [
            "Run \(turn.budgetFrame.runMode.rawValue)",
            "route \(turn.budgetFrame.deviceRoute.rawValue)",
            "permit \(turn.actionPermit.mode.rawValue)",
            "loops \(turn.runtimeTrace.loopCount)",
            "fold \(turn.thoughtFold.checksum.prefix(8))",
            "audit \(turn.runtimeTrace.guardrailFindings.count)",
            "power \(Int((turn.runtimeTrace.powerEstimate * 100).rounded()))%"
        ].joined(separator: " • ")

        guard let fallback, !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return eBrainSummary
        }
        return "\(fallback) • \(eBrainSummary)"
    }

    public static func brainSummary(
        for turn: BASEBrainTurnResult,
        fallback: String? = nil
    ) -> String {
        let mirror = turn.decomposeFrame.mirrorText.trimmingCharacters(in: .whitespacesAndNewlines)
        let mirrorSummary = mirror.isEmpty ? "mirror unavailable" : mirror
        let goalSummary = turn.hostContext.longTermGoals.prefix(2).joined(separator: " • ").nilIfEmpty ?? "no dominant goals"

        let eBrainSummary = [
            "Host \(turn.hostContext.hostID)",
            "version \(turn.hostContext.activeVersion)",
            goalSummary,
            mirrorSummary
        ].joined(separator: " • ")

        guard let fallback, !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return eBrainSummary
        }
        return "\(fallback) • \(eBrainSummary)"
    }

    private static func mergedReport(
        _ report: BASLayerReport,
        turn: BASEBrainTurnResult
    ) -> BASLayerReport {
        var merged = report

        switch report.kind {
        case .runtime:
            let blockers = runtimeBlockers(for: turn)
            merged.summary = "L1 budget \(turn.budgetFrame.runMode.rawValue) • route \(turn.budgetFrame.deviceRoute.rawValue) • precision \(turn.budgetFrame.precisionProfile.rawValue) • thermal \(turn.budgetFrame.thermalGuardLevel.rawValue)"
            merged.blockers = blockers
            merged.score = adjustedScore(base: report.score, fallback: blockers.isEmpty ? 0.92 : 0.58)
        case .data:
            let gateValue = String(format: "%.2f", turn.hostGateValue)
            let identitySummary = turn.hostContext.identityTags.prefix(2).joined(separator: " • ")
            merged.summary = "L5 host \(turn.hostContext.activeVersion) • gate \(gateValue) • identity \(identitySummary)"
            merged.blockers = []
            merged.score = adjustedScore(base: report.score, fallback: 0.93)
        case .memory:
            let blockers = memoryBlockers(for: turn)
            merged.summary = "L8 recalled \(turn.memoryBundle.atoms.count) atoms • conflicts \(turn.memoryBundle.conflictRefs.count) • tags \(turn.memoryBundle.retrievalTags.count)"
            merged.blockers = blockers
            merged.score = adjustedScore(base: report.score, fallback: blockers.isEmpty ? 0.90 : 0.52)
        case .security:
            let blockers = securityBlockers(for: turn)
            merged.summary = "L11 risk \(turn.riskCard.riskLevel.rawValue) • permit \(turn.actionPermit.mode.rawValue) • GSI \(Int((turn.riskCard.gsiScore * 100).rounded()))"
            merged.blockers = blockers
            merged.score = adjustedScore(base: report.score, fallback: blockers.isEmpty ? 0.94 : 0.50)
        case .orchestration:
            let blockers = orchestrationBlockers(for: turn)
            merged.summary = "L9 loop \(turn.runtimeTrace.loopCount) • candidates \(turn.thoughtFrame.candidates.count) • stop \((turn.thoughtFrame.stopReason ?? .candidateStable).rawValue)"
            merged.blockers = blockers
            merged.score = adjustedScore(base: report.score, fallback: blockers.isEmpty ? 0.91 : 0.60)
        case .observability:
            let thermalSummary = turn.runtimeTrace.thermalTrace.joined(separator: " -> ")
            let killSwitchSummary = turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue).joined(separator: ", ")
            merged.summary = "Trace \(turn.runtimeTrace.layerEvents.count) events • fold \(turn.thoughtFold.checksum.prefix(12)) • audit \(turn.runtimeTrace.guardrailFindings.count) • cache \(Int((turn.runtimeTrace.cacheHitRate * 100).rounded()))% • thermal \(thermalSummary)\(killSwitchSummary.isEmpty ? "" : " • kill \(killSwitchSummary)")"
            merged.blockers = []
            merged.score = adjustedScore(base: report.score, fallback: 0.92)
        case .evaluation:
            let reviewCount = turn.updateTickets.filter(\.requiresReview).count
            merged.summary = "L13 tickets \(turn.updateTickets.count) • review \(reviewCount) • schema guard \(turn.updateTickets.first?.schemaVersion ?? BASUpdateTicket.currentSchemaVersion)"
            merged.blockers = turn.updateTickets.contains(where: \.conflictFlag) ? ["Update tickets contain unresolved conflicts."] : []
            merged.score = adjustedScore(base: report.score, fallback: merged.blockers.isEmpty ? 0.89 : 0.62)
        case .delivery:
            merged.summary = "L12 \(turn.renderedOutput.mode.rawValue) output • alternatives \(turn.renderedOutput.alternativeActions.count) • codes \(turn.renderedOutput.explanationCodes.count)"
            merged.blockers = turn.actionPermit.mode == .block && turn.renderedOutput.alternativeActions.isEmpty
                ? ["Blocked outputs should offer a safer alternative path."]
                : []
            merged.score = adjustedScore(base: report.score, fallback: merged.blockers.isEmpty ? 0.90 : 0.66)
        }

        merged.health = BASLayerReport.health(forScore: merged.score, blockers: merged.blockers)
        return merged
    }

    private static func executionTrace(
        for turn: BASEBrainTurnResult
    ) -> BASExecutionTrace {
        BASExecutionTrace(
            inputSummary: turn.contextFrame.utterance,
            selectedRoute: BASModelRoute(
                routeKind: routeKind(for: turn.budgetFrame.deviceRoute),
                preferredModelID: turn.budgetFrame.deviceRoute.rawValue
            ),
            memoriesRecalled: Array(turn.memoryBundle.atoms.map(\.summary).prefix(4)),
            toolsCalled: [],
            latency: BASTraceLatencyBreakdown(
                routeSelectionMs: turn.runtimeTrace.latencyBreakdownMs["power_clock", default: 0] + turn.runtimeTrace.latencyBreakdownMs["risk", default: 0],
                retrievalMs: turn.runtimeTrace.latencyBreakdownMs["memory", default: 0],
                generationMs: turn.runtimeTrace.latencyBreakdownMs["loop", default: 0] + turn.runtimeTrace.latencyBreakdownMs["action", default: 0],
                toolMs: turn.runtimeTrace.latencyBreakdownMs["evolution", default: 0]
            ),
            auditEvents: turn.runtimeTrace.layerEvents.prefix(10).map { event in
                BASAuditEvent(
                    category: event.layerID,
                    message: "\(event.event): \(event.detail)"
                )
            },
            outputSummary: [turn.renderedOutput.headline, turn.renderedOutput.body]
                .filter { !$0.isEmpty }
                .joined(separator: " • ")
        )
    }

    private static func currentBrainState(
        for turn: BASEBrainTurnResult
    ) -> BASCurrentBrainState {
        BASCurrentBrainState(
            mode: turn.budgetFrame.runMode.rawValue,
            dominantGoals: turn.hostContext.longTermGoals,
            activeConstraints: turn.hostContext.noGoZones,
            reactionWeights: reactionWeights(for: turn.hostContext.tonePreference),
            activeTemplateIDs: [],
            recentFailurePatternIDs: [],
            retrievalTags: turn.memoryBundle.retrievalTags,
            verificationSnapshot: turn.hostContext.activeVersion
        )
    }

    private static func runtimeContext(
        for turn: BASEBrainTurnResult
    ) -> BASRuntimeContext {
        BASRuntimeContext(
            taskKind: taskKind(for: turn.contextFrame.taskType),
            gear: runtimeGear(for: turn.budgetFrame.runMode),
            deviceProfile: BASDeviceProfile(
                modelName: "ebrain-\(turn.budgetFrame.deviceRoute.rawValue)",
                memoryMB: max(2048, turn.budgetFrame.retrievalDepth * 1024),
                batteryLevel: 0.5,
                lowPowerMode: turn.budgetFrame.runMode == .sentinel,
                thermalState: turn.budgetFrame.thermalGuardLevel.rawValue
            ),
            privacyMode: turn.budgetFrame.deviceRoute == .hybridLocal ? .localFirst : .localOnly,
            riskLevel: riskLevel(for: turn.riskCard.riskLevel),
            networkAvailable: false,
            budget: BASExecutionBudget(
                contextTokens: turn.budgetFrame.maxDecodeTokens,
                outputTokens: turn.budgetFrame.maxDecodeTokens,
                retrievalItems: turn.budgetFrame.retrievalDepth,
                toolCalls: 0,
                timeBudgetMs: max(300, turn.runtimeTrace.latencyBreakdownMs.values.reduce(0, +))
            )
        )
    }

    private static func policyDecision(
        for turn: BASEBrainTurnResult
    ) -> BASPolicyDecisionRecord {
        let decision: BASPolicyDecision
        let reason: String

        switch turn.actionPermit.mode {
        case .answer, .compare, .replace, .block:
            decision = .allow
            reason = "Protective output released via \(turn.actionPermit.mode.rawValue)."
        case .delay:
            decision = .requireConfirmation
            reason = "Delay requires a second check before irreversible action."
        }

        return BASPolicyDecisionRecord(
            matchedRuleIDs: turn.actionPermit.reasonCodes,
            decision: decision,
            reason: reason
        )
    }

    private static func adjustedScore(base: Double, fallback: Double) -> Double {
        min(max((base + fallback) / 2, 0), 1)
    }

    private static func mergedBlockers(
        existing: [String],
        reportBlockers: [String],
        inspection: BASInspectionBundle
    ) -> [String] {
        Array((existing + reportBlockers + inspection.blockerSummary).uniqued().prefix(8))
    }

    private static func runtimeBlockers(for turn: BASEBrainTurnResult) -> [String] {
        var blockers: [String] = []
        if turn.riskCard.riskLevel >= .high, turn.budgetFrame.runMode == .sentinel {
            blockers.append("High-risk turn cannot stay on sentinel mode.")
        }
        if turn.budgetFrame.thermalGuardLevel == .emergency {
            blockers.append("Thermal guard is in emergency mode.")
        }
        blockers.append(
            contentsOf: turn.runtimeTrace.guardrailFindings
                .filter { $0.severity == .high }
                .map(\.summary)
        )
        return blockers
    }

    private static func memoryBlockers(for turn: BASEBrainTurnResult) -> [String] {
        var blockers: [String] = []
        if turn.riskCard.riskLevel >= .high, turn.memoryBundle.atoms.isEmpty {
            blockers.append("High-risk turn has no aligned memory atoms.")
        }
        if !turn.memoryBundle.conflictRefs.isEmpty {
            blockers.append("Memory conflicts require governed review before promotion.")
        }
        return blockers
    }

    private static func securityBlockers(for turn: BASEBrainTurnResult) -> [String] {
        var blockers: [String] = []
        if turn.riskCard.gsiScore >= 0.75, turn.actionPermit.mode == .answer {
            blockers.append("Elevated GSI should not fall through to direct answer mode.")
        }
        if turn.riskCard.riskLevel == .extreme, turn.actionPermit.mode == .answer {
            blockers.append("Extreme risk requires delay, block, or replace.")
        }
        blockers.append(
            contentsOf: turn.runtimeTrace.guardrailFindings
                .filter { $0.layerID == "L11" }
                .map(\.summary)
        )
        return blockers
    }

    private static func orchestrationBlockers(for turn: BASEBrainTurnResult) -> [String] {
        var blockers: [String] = []
        if turn.thoughtFrame.stopReason == .maxLoopsReached {
            blockers.append("Dream loop exhausted its maximum loop budget.")
        }
        if turn.runtimeTrace.loopCount > turn.budgetFrame.maxLoops {
            blockers.append("Loop count exceeded the planned budget.")
        }
        blockers.append(
            contentsOf: turn.runtimeTrace.guardrailFindings
                .filter { $0.layerID == "L9" }
                .map(\.summary)
        )
        return blockers
    }

    private static func routeKind(for deviceRoute: BASDeviceRoute) -> BASRouteKind {
        switch deviceRoute {
        case .hybridLocal:
            .hybrid
        default:
            .local
        }
    }

    private static func riskLevel(for riskLevel: BASBrainRiskLevel) -> BASRiskLevel {
        switch riskLevel {
        case .low:
            .low
        case .medium:
            .medium
        case .high, .extreme:
            .high
        }
    }

    private static func taskKind(for taskType: BASContextTaskType) -> BASTaskKind {
        switch taskType {
        case .chat:
            .chat
        case .task:
            .tool
        case .choice, .conflict, .highPressure, .highConsequence:
            .plan
        case .manipulationRisk:
            .retrieve
        }
    }

    private static func runtimeGear(for runMode: BASEBrainRunMode) -> BASRuntimeGear {
        switch runMode {
        case .dormant, .sentinel:
            .low
        case .engage:
            .balanced
        case .deepLoop, .guarded:
            .high
        }
    }

    private static func reactionWeights(for tonePreference: String) -> BASReactionWeights {
        switch tonePreference {
        case let tone where tone.contains("comparative"):
            BASReactionWeights(warmth: 0.52, directness: 0.66, brevity: 0.48, actionBias: 0.44)
        case let tone where tone.contains("reflective"):
            BASReactionWeights(warmth: 0.68, directness: 0.42, brevity: 0.54, actionBias: 0.30)
        default:
            BASReactionWeights(warmth: 0.58, directness: 0.58, brevity: 0.56, actionBias: 0.46)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Sequence where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
