import Foundation
import BASHostKit

enum DeveloperDecisionReplayRecord: Identifiable {
    case quick(CheckEvent)
    case balance(BalanceDecisionRecord)
    case mirror(MirrorDecisionRecord)
    case checkpoint(DecisionEvolutionLineageSnapshot)

    var id: String {
        switch self {
        case .quick(let event):
            "quick-\(event.id.uuidString)"
        case .balance(let record):
            "balance-\(record.id.uuidString)"
        case .mirror(let record):
            "mirror-\(record.id.uuidString)"
        case .checkpoint(let lineage):
            "checkpoint-\(lineage.checkpointID)"
        }
    }

    var mode: DecisionMode {
        switch self {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        case .checkpoint(let lineage):
            lineage.mode
        }
    }

    var timestamp: Date {
        switch self {
        case .quick(let event):
            event.createdAt
        case .balance(let record):
            record.updatedAt
        case .mirror(let record):
            record.updatedAt
        case .checkpoint(let lineage):
            lineage.eBrain.recordedAt
        }
    }

    var entrySource: EntrySource {
        switch self {
        case .quick(let event):
            event.entrySource
        case .balance(let record):
            record.entrySource
        case .mirror(let record):
            record.entrySource
        case .checkpoint:
            .app
        }
    }

    var title: String {
        switch self {
        case .quick(let event):
            event.currentPerspective
        case .balance(let record):
            record.prompt
        case .mirror(let record):
            record.prompt
        case .checkpoint(let lineage):
            DecisionEvolutionEBrainPresentationSupport.recoveredCheckpointLineageTitle(
                modeTitle: lineage.mode.shortTitle
            )
        }
    }

    var subtitle: String {
        switch self {
        case .quick(let event):
            event.afterPerspective
        case .balance(let record):
            record.focusSummary
        case .mirror(let record):
            record.coreTension
        case .checkpoint(let lineage):
            DecisionEvolutionEBrainPresentationSupport.recoveredPersistedCheckpointSubtitle(
                taskType: lineage.eBrain.taskType
            )
        }
    }

    var statusTitle: String {
        switch self {
        case .quick(let event):
            event.verdict.title
        case .balance(let record):
            record.focusTitle
        case .mirror(let record):
            record.nextActionTitle
        case .checkpoint(let lineage):
            readableApprovalStateTitle(lineage.approvalState)
        }
    }

    var summaryLine: String {
        switch self {
        case .quick(let event):
            return "\(event.scenario.title) • \(event.finalAction.title(using: BeforePolicy.QuickCheck.defaultBufferDuration))"
        case .balance(let record):
            return record.nextAction
        case .mirror(let record):
            return record.nextAction
        case .checkpoint(let lineage):
            if let firstDiff = lineage.diffSummary.first, !firstDiff.isEmpty {
                return firstDiff
            }
            if let firstTicket = lineage.eBrain.updateTicketSummaries.first, !firstTicket.isEmpty {
                return firstTicket
            }
            return DecisionEvolutionEBrainPresentationSupport.recoveredLineageNarrative(
                riskLevel: lineage.eBrain.riskLevel,
                permitMode: lineage.eBrain.permitMode
            )
        }
    }

    var checkpointID: String? {
        if case .checkpoint(let lineage) = self {
            return lineage.checkpointID
        }

        return nil
    }
}

private func readableApprovalStateTitle(
    _ approvalState: BASEvolutionApprovalState
) -> String {
    switch approvalState {
    case .automatic:
        return "Automatic"
    case .reviewSuggested:
        return "Review Suggested"
    }
}

struct DeveloperDecisionReplayEntry: Identifiable {
    let record: DeveloperDecisionReplayRecord
    let trace: DeveloperDecisionReplayTraceSummary?
    let eBrain: DeveloperDecisionReplayEBrainSummary?
    let matchedPersistedCheckpointID: String?

    init(
        record: DeveloperDecisionReplayRecord,
        trace: DeveloperDecisionReplayTraceSummary?,
        eBrain: DeveloperDecisionReplayEBrainSummary?,
        matchedPersistedCheckpointID: String? = nil
    ) {
        self.record = record
        self.trace = trace
        self.eBrain = eBrain
        self.matchedPersistedCheckpointID = matchedPersistedCheckpointID
    }

    var id: String { record.id }
    var mode: DecisionMode { record.mode }
    var timestamp: Date { record.timestamp }
    var entrySource: EntrySource { record.entrySource }
    var title: String { record.title }
    var subtitle: String { record.subtitle }
    var statusTitle: String { record.statusTitle }
    var summaryLine: String { record.summaryLine }
    var preferredCheckpointID: String? { matchedPersistedCheckpointID ?? record.checkpointID }
}

struct DeveloperDecisionReplayTraceSummary: Equatable, Sendable {
    let createdAt: Date
    let kind: DecisionIntelligenceTraceKind
    let preferredProvider: DecisionModelProviderKind
    let activeProvider: DecisionModelProviderKind?
    let attemptedProviders: [DecisionModelProviderKind]
    let allowFallbacks: Bool
    let usedFallback: Bool
    let prompt: String
    let outputPreview: String
    let detail: String

    init(trace: DecisionIntelligenceTrace) {
        self.createdAt = trace.createdAt
        self.kind = trace.kind
        self.preferredProvider = trace.preferredProvider
        self.activeProvider = trace.activeProvider
        self.attemptedProviders = trace.attemptedProviders
        self.allowFallbacks = trace.allowFallbacks
        self.usedFallback = trace.usedFallback
        self.prompt = trace.prompt
        self.outputPreview = trace.outputPreview
        self.detail = trace.detail
    }
}

typealias DeveloperDecisionReplayEBrainSource = DecisionTestingEBrainSource

struct DeveloperDecisionReplayEBrainSummary: Equatable, Sendable {
    let source: DeveloperDecisionReplayEBrainSource
    let recordedAt: Date
    let sessionID: String
    let taskType: String
    let riskLevel: String
    let permitMode: String
    let hostGatePercent: Int
    let thoughtFoldChecksum: String
    let updateTicketSummaries: [String]
    let reviewDirectiveLine: String?
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let activeKillSwitches: [String]
    let guardrailFindings: [String]
    let killSwitches: [String]
    let sovereignVerdictLine: String?
    let sovereignAuthorityLine: String?
    let sovereignAuditLine: String?
    let layerStackLines: [String]
    let checkpointBudgetLine: String?
    let checkpointPressureLine: String?
    let checkpointTaskLine: String?
    let executionCapability: DecisionSessionCheckpointExecutionCapability?
    let morphGraph: BASMorphGraph?
    let hotColdMap: BASHotColdMap?
    let precisionProfile: BASPrecisionProfile?
    let lungState: BASLungState?
    let breathScheduler: BASBreathSchedulerFrame?
    let resumeFrame: BASResumeFrame?
    let rollbackAnchor: BASRollbackAnchor?
    let sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult?

    init(
        source: DeveloperDecisionReplayEBrainSource,
        recordedAt: Date,
        sessionID: String,
        taskType: String,
        riskLevel: String,
        permitMode: String,
        hostGatePercent: Int,
        thoughtFoldChecksum: String,
        updateTicketSummaries: [String],
        reviewDirectiveLine: String?,
        riskFactorsLine: String? = nil,
        reasonCodesLine: String? = nil,
        activeKillSwitches: [String],
        guardrailFindings: [String],
        killSwitches: [String],
        sovereignVerdictLine: String? = nil,
        sovereignAuthorityLine: String? = nil,
        sovereignAuditLine: String? = nil,
        layerStackLines: [String],
        checkpointBudgetLine: String?,
        checkpointPressureLine: String?,
        checkpointTaskLine: String?,
        executionCapability: DecisionSessionCheckpointExecutionCapability? = nil,
        morphGraph: BASMorphGraph? = nil,
        hotColdMap: BASHotColdMap? = nil,
        precisionProfile: BASPrecisionProfile? = nil,
        lungState: BASLungState? = nil,
        breathScheduler: BASBreathSchedulerFrame? = nil,
        resumeFrame: BASResumeFrame? = nil,
        rollbackAnchor: BASRollbackAnchor? = nil,
        sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult? = nil
    ) {
        self.source = source
        self.recordedAt = recordedAt
        self.sessionID = sessionID
        self.taskType = taskType
        self.riskLevel = riskLevel
        self.permitMode = permitMode
        self.hostGatePercent = hostGatePercent
        self.thoughtFoldChecksum = thoughtFoldChecksum
        self.updateTicketSummaries = updateTicketSummaries
        self.reviewDirectiveLine = reviewDirectiveLine
        self.riskFactorsLine = riskFactorsLine
        self.reasonCodesLine = reasonCodesLine
        self.activeKillSwitches = activeKillSwitches
        self.guardrailFindings = guardrailFindings
        self.killSwitches = killSwitches
        self.sovereignVerdictLine = sovereignVerdictLine
        self.sovereignAuthorityLine = sovereignAuthorityLine
        self.sovereignAuditLine = sovereignAuditLine
        self.layerStackLines = layerStackLines
        self.checkpointBudgetLine = checkpointBudgetLine
        self.checkpointPressureLine = checkpointPressureLine
        self.checkpointTaskLine = checkpointTaskLine
        self.executionCapability = executionCapability
        self.morphGraph = morphGraph
        self.hotColdMap = hotColdMap
        self.precisionProfile = precisionProfile
        self.lungState = lungState
        self.breathScheduler = breathScheduler
        self.resumeFrame = resumeFrame
        self.rollbackAnchor = rollbackAnchor
        self.sovereignBridgeResult = sovereignBridgeResult
    }

    init(turn: BASEBrainTurnResult) {
        let foldedLung = DecisionFoldedLungCoordinator.snapshot(for: turn)
        let activeKillSwitches = turn.runtimeTrace.activeKillSwitches.map(\.rawValue)
        let recommendedKillSwitches = turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue)
        self.source = .liveRuntime
        self.recordedAt = turn.runtimeTrace.recordedAt
        self.sessionID = turn.runtimeTrace.sessionID
        self.taskType = turn.contextFrame.taskType.rawValue
        self.riskLevel = turn.riskCard.riskLevel.rawValue
        self.permitMode = turn.actionPermit.mode.rawValue
        self.hostGatePercent = Int((turn.hostGateValue * 100).rounded())
        self.thoughtFoldChecksum = String(turn.thoughtFold.checksum.prefix(12))
        self.updateTicketSummaries = turn.updateTickets.map(\.summary)
        self.reviewDirectiveLine = turn.updateTickets.lazy.compactMap(\.reviewDirectiveLine).compactMap(\.evolutionTrimmedNonEmpty).first
        self.riskFactorsLine = turn.turnDiagnosticsSupport.riskFactorsLine
        self.reasonCodesLine = turn.turnDiagnosticsSupport.reasonCodesLine
        self.activeKillSwitches = activeKillSwitches
        self.guardrailFindings = turn.runtimeTrace.guardrailFindings.map(\.summary)
        self.killSwitches = Self.orderedUnique(activeKillSwitches + recommendedKillSwitches)
        self.sovereignVerdictLine = Self.sovereignVerdictLine(from: turn.sovereignVerdict)
        self.sovereignAuthorityLine = Self.sovereignAuthorityLine(
            tokens: turn.sovereignCommitTokens,
            lock: turn.sovereignLock,
            quarantineRecords: turn.quarantineRecords
        )
        self.sovereignAuditLine = Self.sovereignAuditLine(from: turn.sovereignAuditEntry)
        self.layerStackLines = turn.layerStackLines
        self.checkpointBudgetLine = turn.replayCheckpointBudgetLine
        self.checkpointPressureLine = turn.replayCheckpointPressureLine
        self.checkpointTaskLine = turn.replayCheckpointTaskLine
        self.executionCapability = nil
        self.morphGraph = foldedLung.morphGraph
        self.hotColdMap = foldedLung.hotColdMap
        self.precisionProfile = foldedLung.precisionProfile
        self.lungState = foldedLung.lungState
        self.breathScheduler = foldedLung.breathScheduler
        self.resumeFrame = foldedLung.resumeFrame
        self.rollbackAnchor = foldedLung.rollbackAnchor
        self.sovereignBridgeResult = foldedLung.sovereignBridgeResult
    }

    init(lineageSummary: BASEvolutionLineageSummary) {
        let foldedLung = Self.foldedLungProjection(from: lineageSummary.foldedLungSummary)
        self.source = .persistedCheckpoint
        self.recordedAt = lineageSummary.recordedAt
        self.sessionID = lineageSummary.sessionID
        self.taskType = lineageSummary.taskType
        self.riskLevel = lineageSummary.riskLevel
        self.permitMode = lineageSummary.permitMode
        self.hostGatePercent = lineageSummary.hostGatePercent
        self.thoughtFoldChecksum = lineageSummary.thoughtFoldChecksum
        self.updateTicketSummaries = lineageSummary.updateTicketSummaries
        self.reviewDirectiveLine = lineageSummary.reviewDirectiveLine?.evolutionTrimmedNonEmpty
        self.riskFactorsLine = nil
        self.reasonCodesLine = nil
        self.activeKillSwitches = lineageSummary.activeKillSwitches
        self.guardrailFindings = lineageSummary.guardrailFindings
        self.killSwitches = Self.orderedUnique(
            lineageSummary.activeKillSwitches + lineageSummary.recommendedKillSwitches
        )
        self.sovereignVerdictLine = Self.sovereignVerdictLine(from: lineageSummary.sovereignVerdict)
        self.sovereignAuthorityLine = Self.sovereignAuthorityLine(
            tokens: lineageSummary.sovereignCommitTokens,
            lock: lineageSummary.sovereignLock,
            quarantineRecords: lineageSummary.quarantineRecords
        )
        self.sovereignAuditLine = Self.sovereignAuditLine(from: lineageSummary.sovereignAuditEntry)
        self.layerStackLines = Self.checkpointLayerStackLines(from: lineageSummary)
        self.checkpointBudgetLine = nil
        self.checkpointPressureLine = nil
        self.checkpointTaskLine = self.reviewDirectiveLine
            ?? lineageSummary.updateTicketSummaries.first?.evolutionTrimmedNonEmpty.map { "Review: \($0)" }
        self.executionCapability = nil
        self.morphGraph = foldedLung.morphGraph
        self.hotColdMap = foldedLung.hotColdMap
        self.precisionProfile = foldedLung.precisionProfile
        self.lungState = foldedLung.lungState
        self.breathScheduler = foldedLung.breathScheduler
        self.resumeFrame = foldedLung.resumeFrame
        self.rollbackAnchor = foldedLung.rollbackAnchor
        self.sovereignBridgeResult = foldedLung.sovereignBridgeResult
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }

    private static func sovereignVerdictLine(
        from verdict: BASSovereignVerdict?
    ) -> String? {
        guard let verdict else {
            return nil
        }

        let reasonSummary = verdict.reasonCodes
            .prefix(2)
            .joined(separator: ", ")

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                "Sovereign verdict \(verdict.verdictLevel.rawValue)",
                verdict.latched ? "latched" : nil,
                verdict.forcedMode.map { "mode \($0.rawValue)" },
                reasonSummary.isEmpty ? nil : "reasons \(reasonSummary)"
            ].compactMap { $0 }
        )
    }

    private static func sovereignAuthorityLine(
        tokens: [BASSovereignCommitToken],
        lock: BASSovereignLock?,
        quarantineRecords: [BASQuarantineRecord]
    ) -> String? {
        let tokenScopeSummary = tokens.map(\.scope.rawValue)
        let quarantineZones = quarantineRecords.map(\.zone.rawValue)

        guard
            tokenScopeSummary.isEmpty == false
                || lock != nil
                || quarantineZones.isEmpty == false
        else {
            return nil
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                tokenScopeSummary.isEmpty ? nil : "tokens \(tokenScopeSummary.joined(separator: ", "))",
                lock.map { "lock \($0.scope.rawValue)" },
                quarantineZones.isEmpty ? nil : "quarantine \(quarantineZones.joined(separator: ", "))"
            ].compactMap { $0 }
        )
    }

    private static func sovereignAuditLine(
        from auditEntry: BASSovereignAuditEntry?
    ) -> String? {
        guard let auditEntry else {
            return nil
        }

        let ruleSummary = auditEntry.ruleIDs
            .prefix(3)
            .joined(separator: ", ")

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                "Sovereign audit",
                ruleSummary.isEmpty ? nil : ruleSummary,
                "ref \(auditEntry.auditID)"
            ].compactMap { $0 }
        )
    }

    private static func checkpointLayerStackLines(
        from lineageSummary: BASEvolutionLineageSummary
    ) -> [String] {
        let reviewDirective = lineageSummary.reviewDirectiveLine?.evolutionTrimmedNonEmpty
            ?? lineageSummary.updateTicketSummaries.first?.evolutionTrimmedNonEmpty
        let runModeTitle = lineageSummary.runMode?.displayTitle.uppercased() ?? "RECOVERY"
        let wakeIntentLine = lineageSummary.wakeIntent.map {
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "wake \($0.intentLevel.rawValue)",
                "value \(Int(($0.estimatedValue * 100).rounded()))%",
                "risk \(Int(($0.estimatedRisk * 100).rounded()))%"
            ])
        }
        let leaseLine = lineageSummary.runLease.map {
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "lease \($0.allowedMode.displayTitle.lowercased())",
                "loops \($0.maxLoops)",
                "heads \($0.validHeads.count)"
            ])
        }
        let brakeLine: String? = {
            guard let emergencyBrake = lineageSummary.emergencyBrake,
                  emergencyBrake.brakeLevel != .none else {
                return nil
            }
            return DecisionEvolutionNarrativeFormattingSupport.joined([
                "brake \(emergencyBrake.brakeLevel.rawValue)",
                emergencyBrake.forcedMode.map { "force \($0.displayTitle.lowercased())" }
            ].compactMap { $0 })
        }()
        let sovereignLine = lineageSummary.sovereignActuationCommands.isEmpty
            ? nil
            : DecisionEvolutionNarrativeFormattingSupport.joined([
                "sovereign",
                lineageSummary.sovereignActuationCommands.map(\.kind.rawValue).joined(separator: ", ")
            ])
        let sovereignVerdictLine = lineageSummary.sovereignVerdict.map {
            "verdict \($0.verdictLevel.rawValue)"
        }
        let sovereignTokenLine: String? = {
            let scopes = lineageSummary.sovereignCommitTokens.map(\.scope.rawValue)
            guard scopes.isEmpty == false else { return nil }
            return "tokens \(Array(scopes.prefix(3)).joined(separator: ", "))"
        }()
        let sovereignLockLine = lineageSummary.sovereignLock.map {
            "lock \($0.scope.rawValue)"
        }
        let quarantineLine: String? = {
            let zones = lineageSummary.quarantineRecords.map(\.zone.rawValue)
            guard zones.isEmpty == false else { return nil }
            return "quarantine \(Array(zones.prefix(2)).joined(separator: ", "))"
        }()
        let sovereignAuditLine = lineageSummary.sovereignAuditEntry.map {
            "audit \($0.ruleIDs.first ?? $0.auditID)"
        }
        let sovereignReceiptLine = lineageSummary.sovereignExecutionReceipts.isEmpty
            ? nil
            : DecisionEvolutionNarrativeFormattingSupport.joined([
                "executed",
                lineageSummary.sovereignExecutionReceipts.map {
                    "\($0.kind.rawValue) \($0.latencyMs)ms"
                }.joined(separator: ", ")
            ])
        let policyLine = lineageSummary.policyLineage.map {
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "policy \($0.bundleVersion)",
                "routing \($0.providerRoutingPolicyID)",
                "tuning \($0.runtimeTuningPolicyID)"
            ])
        }
        let recoveryLine = lineageSummary.recoveryDisposition.map {
            DecisionEvolutionNarrativeFormattingSupport.joined([
                $0.kind.rawValue,
                $0.summary
            ])
        }
        let activeOrganSummary = lineageSummary.activeOrganIDs.isEmpty
            ? "none"
            : Array(lineageSummary.activeOrganIDs.prefix(4)).joined(separator: ", ")
        let headGuaranteeSummary = lineageSummary.headGuarantees.isEmpty
            ? "none"
            : Array(lineageSummary.headGuarantees.prefix(3)).joined(separator: ", ")
        let projectionSummary = DecisionEvolutionEBrainPresentationSupport.neuralProjectionSummary(
            leadCandidateID: lineageSummary.projectionLeadCandidateID,
            forecastCount: lineageSummary.projectionForecastCount,
            critiqueCount: lineageSummary.projectionCritiqueCount
        )
        let degradedLine = lineageSummary.degradedReasonCodes.isEmpty
            ? nil
            : "degraded \(lineageSummary.degradedReasonCodes.joined(separator: ", "))"
        let sovereignConstraintSummary = lineageSummary.foldedLungSummary?.morphSovereignConstraints ?? []
        let activeKillSwitchSummary = lineageSummary.activeKillSwitches
        let recommendedKillSwitchSummary = lineageSummary.recommendedKillSwitches
        let sovereignLayerLine: String? = {
            let details = [
                sovereignConstraintSummary.isEmpty ? nil : "constraints \(Array(sovereignConstraintSummary.prefix(3)).joined(separator: ", "))",
                sovereignVerdictLine,
                sovereignTokenLine,
                sovereignLockLine,
                quarantineLine,
                sovereignAuditLine,
                sovereignLine.map { $0.replacingOccurrences(of: "sovereign • ", with: "commands ") },
                sovereignReceiptLine.map { $0.replacingOccurrences(of: "executed • ", with: "executed ") },
                activeKillSwitchSummary.isEmpty ? nil : "active \(Array(activeKillSwitchSummary.prefix(3)).joined(separator: ", "))",
                recommendedKillSwitchSummary.isEmpty ? nil : "recommended \(Array(recommendedKillSwitchSummary.prefix(3)).joined(separator: ", "))"
            ]
            .compactMap { $0 }
            .compactMap(\.evolutionTrimmedNonEmpty)

            guard details.isEmpty == false else {
                return nil
            }

            return DecisionEvolutionNarrativeFormattingSupport.joined(
                ["L14 sovereign"] + details
            )
        }()
        let l3Line = lineageSummary.foldedLungSummary.map { foldedLung in
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "L3 compression runtime",
                "breath \(foldedLung.breathMode)",
                "phase \(foldedLung.breathPhase)",
                "anchor \(foldedLung.rollbackAnchorID)"
            ])
        } ?? DecisionEvolutionNarrativeFormattingSupport.joined([
            "L3 compression runtime",
            "fold \(lineageSummary.thoughtFoldChecksum)"
        ])
        let contextLine = checkpointContextLayerLine(from: lineageSummary)
        let cognitionLine = checkpointCognitionLayerLine(from: lineageSummary)
        let adjudicationLine = checkpointAdjudicationLayerLine(
            from: lineageSummary,
            brakeLine: brakeLine
        )

        return [
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "L1 power clock",
                "mode \(runModeTitle)",
                "recovered checkpoint budget envelope",
                wakeIntentLine,
                leaseLine,
                policyLine,
                recoveryLine
            ].compactMap { $0 }),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "L2 neural core",
                "morph \(lineageSummary.neuralMorphID ?? "none")",
                "organs \(activeOrganSummary)",
                "heads \(headGuaranteeSummary)",
                lineageSummary.frontierWidth.map { "frontier \($0)" },
                lineageSummary.bindingCount > 0 ? "bindings \(lineageSummary.bindingCount)" : nil,
                projectionSummary,
                degradedLine,
                "recovered checkpoint fabric summary"
            ].compactMap { $0 }),
            l3Line,
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "L4 foundation",
                "task \(DecisionEvolutionEBrainPresentationSupport.taskTitle(lineageSummary.taskType))",
                "recovered priors"
            ]),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "L5 host profile",
                "session \(lineageSummary.sessionID)",
                "gate \(lineageSummary.hostGatePercent)%"
            ]),
            contextLine,
            cognitionLine,
            adjudicationLine,
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "L13 evolution",
                "\(lineageSummary.updateTicketSummaries.count) tickets",
                reviewDirective
            ].compactMap { $0 }),
            sovereignLayerLine
        ]
        .compactMap { $0?.evolutionTrimmedNonEmpty }
    }

    private static func checkpointContextLayerLine(
        from lineageSummary: BASEvolutionLineageSummary
    ) -> String {
        guard let contextSummary = lineageSummary.contextSummary else {
            return DecisionEvolutionEBrainPresentationSupport.fallbackContextLayerStackLine(
                taskType: lineageSummary.taskType,
                sessionID: lineageSummary.sessionID
            )
        }

        return DecisionEvolutionEBrainPresentationSupport.contextLayerStackLine(
            taskType: lineageSummary.taskType,
            emotionalLoadPercent: contextSummary.emotionalLoadPercent,
            timePressurePercent: contextSummary.timePressurePercent,
            relationPattern: contextSummary.relationPattern,
            ambiguityPercent: contextSummary.ambiguityPercent,
            consequencePercent: contextSummary.consequencePercent,
            manipulationHintCount: contextSummary.manipulationHintCount
        )
    }

    private static func checkpointCognitionLayerLine(
        from lineageSummary: BASEvolutionLineageSummary
    ) -> String {
        guard let cognitionSummary = lineageSummary.cognitionSummary else {
            return DecisionEvolutionEBrainPresentationSupport.fallbackCognitionLayerStackLine()
        }

        return DecisionEvolutionEBrainPresentationSupport.cognitionLayerStackLine(
            factCount: cognitionSummary.factCount,
            goalCount: cognitionSummary.goalCount,
            unknownCount: cognitionSummary.unknownCount,
            contradictionCount: cognitionSummary.contradictionCount,
            memoryAtomCount: cognitionSummary.memoryAtomCount,
            candidateCount: cognitionSummary.candidateCount,
            forecastCount: cognitionSummary.forecastCount,
            critiqueCount: cognitionSummary.critiqueCount,
            stopReasonID: cognitionSummary.stopReasonID
        )
    }

    private static func checkpointAdjudicationLayerLine(
        from lineageSummary: BASEvolutionLineageSummary,
        brakeLine: String?
    ) -> String {
        if let adjudicationSummary = lineageSummary.adjudicationSummary {
            return DecisionEvolutionEBrainPresentationSupport.adjudicationLayerStackLine(
                triScoreCount: adjudicationSummary.triScoreCount,
                vetoCount: adjudicationSummary.vetoCount,
                riskLevel: lineageSummary.riskLevel,
                permitMode: lineageSummary.permitMode,
                gsiPercent: adjudicationSummary.gsiPercent,
                alternativeActionCount: adjudicationSummary.alternativeActionCount,
                emergencyBrakeLine: adjudicationSummary.emergencyBrakeLevelID.map { "brake \($0)" } ?? brakeLine
            )
        }

        return DecisionEvolutionEBrainPresentationSupport.fallbackAdjudicationLayerStackLine(
            riskLevel: lineageSummary.riskLevel,
            permitMode: lineageSummary.permitMode,
            hostGatePercent: lineageSummary.hostGatePercent,
            emergencyBrakeLine: brakeLine
        )
    }

    private static func foldedLungProjection(
        from summary: BASEvolutionFoldedLungSummary?
    ) -> PersistedFoldedLungProjection {
        guard let summary else {
            return PersistedFoldedLungProjection(
                morphGraph: nil,
                hotColdMap: nil,
                precisionProfile: nil,
                lungState: nil,
                breathScheduler: nil,
                resumeFrame: nil,
                rollbackAnchor: nil,
                sovereignBridgeResult: nil
            )
        }

        let morphGraph = persistedMorphGraph(from: summary)
        let hotColdMap = persistedHotColdMap(from: summary)
        let precisionProfile = persistedPrecisionProfile(from: summary)
        let breathScheduler = persistedBreathScheduler(from: summary)
        let lungState = breathMode(rawValue: summary.breathMode).flatMap { breathMode in
            breathPhase(rawValue: summary.breathPhase).map { breathPhase in
                BASLungState(
                    breathMode: breathMode,
                    breathPhase: breathPhase,
                    thermalPressure: summary.thermalPressure,
                    cachePressure: summary.cachePressure,
                    restoreReadiness: Double(summary.restoreReadinessPercent) / 100.0,
                    rollbackAnchorRef: summary.rollbackAnchorID
                )
            }
        }
        let resumeFrame = BASResumeFrame(
            resumeID: summary.resumeID,
            sourceFoldID: summary.sourceFoldID,
            resumeDepth: summary.resumeDepth,
            requiredOrgans: summary.requiredOrganIDs.compactMap(BASNeuralOrgan.init(rawValue:)),
            consistencyChecks: summary.consistencyChecks,
            fallbackMode: resumeFallbackMode(rawValue: summary.fallbackMode) ?? .rollbackAnchor
        )
        let rollbackAnchor = BASRollbackAnchor(
            anchorID: summary.rollbackAnchorID,
            safeSnapshotRef: summary.safeSnapshotRef,
            foldRefs: summary.foldRefs,
            hostVersionRef: summary.hostVersionRef,
            cacheStateRef: summary.cacheStateRef,
            integrityHash: summary.integrityHash
        )
        let sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult? = summary.sovereignActuationKinds.isEmpty
            ? nil
            : DecisionFoldedLungSovereignBridgeResult(
                actuationKinds: summary.sovereignActuationKinds,
                invalidatedResumeFrameIDs: summary.invalidatedResumeFrameIDs,
                invalidatedCacheRefs: summary.invalidatedCacheRefs,
                invalidatedFoldRefs: summary.invalidatedFoldRefs,
                quarantinedFoldRefs: summary.quarantinedFoldRefs,
                resultingBreathMode: breathMode(rawValue: summary.resultingBreathMode ?? summary.breathMode) ?? .structured,
                preservedReadOnlyRecovery: summary.preservedReadOnlyRecovery ?? false,
                summary: summary.sovereignBridgeSummary ?? "Sovereign bridge • mode \(summary.resultingBreathMode ?? summary.breathMode)"
            )

        return PersistedFoldedLungProjection(
            morphGraph: morphGraph,
            hotColdMap: hotColdMap,
            precisionProfile: precisionProfile,
            lungState: lungState,
            breathScheduler: breathScheduler,
            resumeFrame: resumeFrame,
            rollbackAnchor: rollbackAnchor,
            sovereignBridgeResult: sovereignBridgeResult
        )
    }

    private static func breathMode(rawValue: String?) -> BASBreathMode? {
        guard let rawValue = rawValue?.evolutionTrimmedNonEmpty else {
            return nil
        }
        return BASBreathMode(rawValue: rawValue)
    }

    private static func breathPhase(rawValue: String?) -> BASBreathPhase? {
        guard let rawValue = rawValue?.evolutionTrimmedNonEmpty else {
            return nil
        }
        return BASBreathPhase(rawValue: rawValue)
    }

    private static func resumeFallbackMode(rawValue: String?) -> BASResumeFallbackMode? {
        guard let rawValue = rawValue?.evolutionTrimmedNonEmpty else {
            return nil
        }
        return BASResumeFallbackMode(rawValue: rawValue)
    }

    private static func persistedMorphGraph(
        from summary: BASEvolutionFoldedLungSummary
    ) -> BASMorphGraph? {
        let activeOrgans = summary.morphActiveOrganIDs.compactMap(BASNeuralOrgan.init(rawValue:))
        guard activeOrgans.isEmpty == false || summary.morphGraphID?.evolutionTrimmedNonEmpty != nil else {
            return nil
        }

        let precisionMap = summary.morphPrecisionRecords.compactMap(persistedPrecisionRecord)
        return BASMorphGraph(
            graphID: summary.morphGraphID?.evolutionTrimmedNonEmpty
                ?? "morph.persisted.\(summary.sourceFoldID)",
            activeOrgans: activeOrgans.isEmpty ? [.stubCore] : activeOrgans,
            executionOrder: summary.morphExecutionOrder.isEmpty
                ? (activeOrgans.isEmpty ? ["stubCore"] : activeOrgans.map(\.rawValue))
                : summary.morphExecutionOrder,
            precisionMap: precisionMap,
            deviceRouteMap: summary.morphDeviceRouteMap,
            thermalProfile: summary.morphThermalProfile,
            sovereignConstraints: summary.morphSovereignConstraints
        )
    }

    private static func persistedHotColdMap(
        from summary: BASEvolutionFoldedLungSummary
    ) -> BASHotColdMap? {
        let hotOrgans = summary.hotOrganIDs.compactMap(BASNeuralOrgan.init(rawValue:))
        let warmOrgans = summary.warmOrganIDs.compactMap(BASNeuralOrgan.init(rawValue:))
        let coldOrgans = summary.coldOrganIDs.compactMap(BASNeuralOrgan.init(rawValue:))
        guard
            hotOrgans.isEmpty == false
                || warmOrgans.isEmpty == false
                || coldOrgans.isEmpty == false
                || summary.hotColdMapID?.evolutionTrimmedNonEmpty != nil
        else {
            return nil
        }

        return BASHotColdMap(
            hotOrgans: hotOrgans,
            warmOrgans: warmOrgans,
            coldOrgans: coldOrgans,
            preloadPolicy: summary.hotColdPreloadPolicy ?? "structured_preload",
            evictionPolicy: summary.hotColdEvictionPolicy ?? "balanced_trim"
        )
    }

    private static func persistedPrecisionProfile(
        from summary: BASEvolutionFoldedLungSummary
    ) -> BASPrecisionProfile? {
        let organPrecisions = summary.precisionOrganPrecisionRecords.compactMap(persistedPrecisionRecord)
        guard
            organPrecisions.isEmpty == false
                || summary.precisionProfileID?.evolutionTrimmedNonEmpty != nil
                || summary.precisionGuardSafeFloorID?.evolutionTrimmedNonEmpty != nil
        else {
            return nil
        }

        return BASPrecisionProfile(
            organPrecisions: organPrecisions,
            lockedPrecisions: summary.precisionLockedOrganIDs.compactMap(BASNeuralOrgan.init(rawValue:)),
            degradationOrder: summary.precisionDegradationOrder.compactMap(BASNeuralPrecisionTier.init(rawValue:)),
            guardSafeFloor: BASNeuralPrecisionTier(rawValue: summary.precisionGuardSafeFloorID ?? "") ?? .balanced
        )
    }

    private static func persistedBreathScheduler(
        from summary: BASEvolutionFoldedLungSummary
    ) -> BASBreathSchedulerFrame? {
        guard
            summary.breathSchedulerID?.evolutionTrimmedNonEmpty != nil
                || summary.schedulerCadenceTag?.evolutionTrimmedNonEmpty != nil
                || summary.schedulerCheckpointCadence?.evolutionTrimmedNonEmpty != nil
                || summary.schedulerResumeBudgetClass?.evolutionTrimmedNonEmpty != nil
        else {
            return nil
        }

        return BASBreathSchedulerFrame(
            schedulerID: summary.breathSchedulerID?.evolutionTrimmedNonEmpty
                ?? "scheduler.persisted.\(summary.sourceFoldID)",
            cadenceTag: summary.schedulerCadenceTag ?? "structured_cycle",
            checkpointCadence: summary.schedulerCheckpointCadence ?? "anchor_on_yield",
            microSleepWindowMs: summary.schedulerMicroSleepWindowMs ?? 0,
            backgroundMaintenanceWindowMs: summary.schedulerBackgroundMaintenanceWindowMs ?? 0,
            allowsBackgroundMaintenance: summary.schedulerAllowsBackgroundMaintenance ?? false,
            allowsMicroSleep: summary.schedulerAllowsMicroSleep ?? true,
            resumeBudgetClass: summary.schedulerResumeBudgetClass ?? "guarded_hot",
            schedulerReasonCodes: summary.schedulerReasonCodes
        )
    }

    private static func persistedPrecisionRecord(
        from record: BASEvolutionFoldedLungSummary.PrecisionRecord
    ) -> BASNeuralOrganPrecision? {
        guard
            let organ = BASNeuralOrgan(rawValue: record.organID),
            let tier = BASNeuralPrecisionTier(rawValue: record.tierID)
        else {
            return nil
        }

        return BASNeuralOrganPrecision(organ: organ, tier: tier)
    }
}

private struct PersistedFoldedLungProjection {
    let morphGraph: BASMorphGraph?
    let hotColdMap: BASHotColdMap?
    let precisionProfile: BASPrecisionProfile?
    let lungState: BASLungState?
    let breathScheduler: BASBreathSchedulerFrame?
    let resumeFrame: BASResumeFrame?
    let rollbackAnchor: BASRollbackAnchor?
    let sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult?
}

extension DeveloperDecisionReplayEBrainSummary {
    var morphLine: String? {
        morphGraph?.decisionMorphLine
    }

    var hotColdLine: String? {
        hotColdMap?.decisionHotColdLine
    }

    var precisionLine: String? {
        precisionProfile?.decisionPrecisionLine
    }

    var lungLine: String? {
        lungState?.decisionLungLine
    }

    var schedulerLine: String? {
        breathScheduler?.decisionSchedulerLine
    }

    var resumeLine: String? {
        resumeFrame?.decisionResumeLine
    }

    var rollbackLine: String? {
        rollbackAnchor?.decisionRollbackLine
    }

    var sovereignBridgeLine: String? {
        sovereignBridgeResult?.primaryLine
    }

    var sovereignBridgeDetailLines: [String] {
        sovereignBridgeResult?.detailLines ?? []
    }

    var sovereignBridgeSupplementalLines: [String] {
        sovereignBridgeResult?.supplementalLines ?? []
    }

    func applying(anchor: DecisionSessionCheckpointEBrainAnchor?) -> DeveloperDecisionReplayEBrainSummary {
        guard let anchor else {
            return self
        }

        let anchoredSnapshot = anchor.foldedLungSnapshot
        let augmentedLayerStackLines = Self.orderedUnique(
            (anchoredSnapshot.map { [$0.layerStackLine] } ?? [])
            + layerStackLines
        )

        return DeveloperDecisionReplayEBrainSummary(
            source: source,
            recordedAt: recordedAt,
            sessionID: sessionID,
            taskType: taskType,
            riskLevel: riskLevel,
            permitMode: permitMode,
            hostGatePercent: hostGatePercent,
            thoughtFoldChecksum: thoughtFoldChecksum,
            updateTicketSummaries: updateTicketSummaries,
            reviewDirectiveLine: reviewDirectiveLine,
            riskFactorsLine: riskFactorsLine,
            reasonCodesLine: reasonCodesLine,
            activeKillSwitches: activeKillSwitches,
            guardrailFindings: guardrailFindings,
            killSwitches: killSwitches,
            sovereignVerdictLine: sovereignVerdictLine,
            sovereignAuthorityLine: sovereignAuthorityLine,
            sovereignAuditLine: sovereignAuditLine,
            layerStackLines: augmentedLayerStackLines,
            checkpointBudgetLine: checkpointBudgetLine,
            checkpointPressureLine: checkpointPressureLine,
            checkpointTaskLine: checkpointTaskLine,
            executionCapability: anchor.executionCapability ?? executionCapability,
            morphGraph: anchor.morphGraph ?? morphGraph,
            hotColdMap: anchor.hotColdMap ?? hotColdMap,
            precisionProfile: anchor.precisionProfile ?? precisionProfile,
            lungState: anchor.lungState ?? lungState,
            breathScheduler: anchor.breathScheduler ?? breathScheduler,
            resumeFrame: anchor.resumeFrame ?? resumeFrame,
            rollbackAnchor: anchor.rollbackAnchor ?? rollbackAnchor,
            sovereignBridgeResult: anchor.sovereignBridgeResult ?? sovereignBridgeResult
        )
    }
}

extension DecisionEvolutionLineageSnapshot {
    func applying(anchor: DecisionSessionCheckpointEBrainAnchor?) -> DecisionEvolutionLineageSnapshot {
        guard let anchor else {
            return self
        }

        return DecisionEvolutionLineageSnapshot(
            checkpointID: checkpointID,
            previousCheckpointID: previousCheckpointID,
            createdAt: createdAt,
            mode: mode,
            approvalState: approvalState,
            rollbackReady: rollbackReady,
            hasBrainStateSnapshot: hasBrainStateSnapshot,
            diffSummary: diffSummary,
            eBrain: eBrain.applying(anchor: anchor)
        )
    }
}

enum DecisionEvolutionSourceDescriptorKind: Equatable, Sendable {
    case liveRuntime
    case checkpointRecovery
}

struct DecisionEvolutionSourceDescriptor: Equatable, Sendable {
    let kind: DecisionEvolutionSourceDescriptorKind
    let title: String
    let detail: String
}

extension DecisionEvolutionSourceDescriptor {
    static let liveRuntimeDefault = DecisionEvolutionSourceDescriptor(
        kind: .liveRuntime,
        title: "Live runtime",
        detail: "Showing the active 13-layer turn synthesized from the current local runtime."
    )

    static let checkpointRecoveryDefault = DecisionEvolutionSourceDescriptor(
        kind: .checkpointRecovery,
        title: "Checkpoint recovery",
        detail: DecisionEvolutionCheckpointRecoverySupport.recoveredDescriptorDetail
    )

    static let checkpointRecoveryWorkspace = DecisionEvolutionSourceDescriptor(
        kind: .checkpointRecovery,
        title: "Checkpoint recovery",
        detail: DecisionEvolutionCheckpointRecoverySupport.recoveredWorkspaceDescriptorDetail
    )
}

struct DecisionEvolutionTurnDiagnosticsPresentation: Equatable, Sendable {
    let sourceDescriptor: DecisionEvolutionSourceDescriptor
    let runModeTitle: String
    let taskTitle: String
    let riskTitle: String
    let permitTitle: String
    let mirrorText: String
    let routeText: String
    let hostText: String
    let replayText: String
    let auditLines: [String]
    let activeKillSwitchesLine: String?
    let recommendedKillSwitchesLine: String?
    let layerStackLines: [String]
    let candidateTitles: [String]
    let memorySummaries: [String]
    let triScoreLines: [String]
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let alternativeActions: [String]
    let thoughtFoldLines: [String]
    let replayTraceLines: [String]
    let ticketSummary: String?
}

struct DecisionEvolutionReplayOverviewPresentation: Equatable, Sendable {
    let labelLine: String
    let titleLine: String
    let detailLines: [String]
}

struct DecisionEvolutionReplayOverviewCardCopy: Equatable, Sendable {
    let labelLine: String
    let titleLine: String
    let detailLines: [String]

    var summaryCardCopy: DecisionEvolutionReplayCardCopy {
        DecisionEvolutionReplayCardCopy(
            titleLine: titleLine,
            secondaryLine: primaryDetailLine,
            supplementaryLine: secondaryDetailLine
        )
    }

    var primaryDetailLine: String? {
        detailLines.first
    }

    var secondaryDetailLine: String? {
        Array(detailLines.dropFirst()).first
    }

    var remainingDetailLines: [String] {
        Array(detailLines.dropFirst(2))
    }
}

struct DecisionEvolutionReplayCardCopy: Equatable, Sendable {
    let titleLine: String
    let secondaryLine: String?
    let supplementaryLine: String?
}

struct DecisionEvolutionReplayDiagnosticsHeaderCopy: Equatable, Sendable {
    let eyebrowLine: String
    let statusLine: String?
    let titleLine: String
    let detailLines: [String]
}

struct DecisionEvolutionReplayDiagnosticLine: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case operations
        case budget
        case pressure
        case eBrain
        case riskFactors
        case reasonCodes
        case foldedLung
        case scheduler
        case hotCold
        case resume
        case rollback
        case sovereignBridge
        case task
        case action
        case audit
        case activeKillSwitches
        case killSwitches
        case trace
    }

    let kind: Kind
    let text: String
}

struct DecisionEvolutionReplayEntryPresentation: Equatable, Sendable {
    let sourceTitle: String
    let modeTitle: String
    let statusTitle: String
    let timestamp: Date
    let title: String
    let summaryLine: String
    let digest: DecisionEvolutionEBrainDigestPresentation?
    let overviewPresentation: DecisionEvolutionReplayOverviewPresentation
    let layerStackLines: [String]
    let budgetLine: String?
    let pressureLine: String?
    let eBrainLine: String?
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let taskLine: String?
    let actionLine: String?
    let auditLine: String?
    let activeKillSwitchesLine: String?
    let killSwitchesLine: String?
    let lungLine: String?
    let schedulerLine: String?
    let hotColdLine: String?
    let resumeLine: String?
    let rollbackLine: String?
    let sovereignBridgeLine: String?
    let traceLine: String?

    init(
        sourceTitle: String,
        modeTitle: String,
        statusTitle: String,
        timestamp: Date,
        title: String,
        summaryLine: String,
        digest: DecisionEvolutionEBrainDigestPresentation?,
        overviewPresentation: DecisionEvolutionReplayOverviewPresentation,
        layerStackLines: [String],
        budgetLine: String?,
        pressureLine: String?,
        eBrainLine: String?,
        riskFactorsLine: String? = nil,
        reasonCodesLine: String? = nil,
        taskLine: String?,
        actionLine: String?,
        auditLine: String?,
        activeKillSwitchesLine: String?,
        killSwitchesLine: String?,
        lungLine: String? = nil,
        schedulerLine: String? = nil,
        hotColdLine: String? = nil,
        resumeLine: String? = nil,
        rollbackLine: String? = nil,
        sovereignBridgeLine: String? = nil,
        traceLine: String?
    ) {
        self.sourceTitle = sourceTitle
        self.modeTitle = modeTitle
        self.statusTitle = statusTitle
        self.timestamp = timestamp
        self.title = title
        self.summaryLine = summaryLine
        self.digest = digest
        self.overviewPresentation = overviewPresentation
        self.layerStackLines = layerStackLines
        self.budgetLine = budgetLine
        self.pressureLine = pressureLine
        self.eBrainLine = eBrainLine
        self.riskFactorsLine = riskFactorsLine
        self.reasonCodesLine = reasonCodesLine
        self.taskLine = taskLine
        self.actionLine = actionLine
        self.auditLine = auditLine
        self.activeKillSwitchesLine = activeKillSwitchesLine
        self.killSwitchesLine = killSwitchesLine
        self.lungLine = lungLine
        self.schedulerLine = schedulerLine
        self.hotColdLine = hotColdLine
        self.resumeLine = resumeLine
        self.rollbackLine = rollbackLine
        self.sovereignBridgeLine = sovereignBridgeLine
        self.traceLine = traceLine
    }
}

extension DecisionEvolutionReplayEntryPresentation {
    var digestHeadlineLine: String? {
        guard let digest else { return nil }
        return "\(digest.sourceDescriptor.title) • \(digest.compactStatusLine)"
    }

    var replayCardCopy: DecisionEvolutionReplayCardCopy {
        let titleLine = overviewPresentation.titleLine.evolutionTrimmedNonEmpty ?? title
        let supportingLines = Self.uniqueOverviewLines(
            [summaryLine == titleLine ? nil : summaryLine]
                + overviewPresentation.detailLines.map(Optional.some)
        )

        return DecisionEvolutionReplayCardCopy(
            titleLine: titleLine,
            secondaryLine: supportingLines.first,
            supplementaryLine: Array(supportingLines.dropFirst()).first
        )
    }

    var overviewCardCopy: DecisionEvolutionReplayOverviewCardCopy {
        DecisionEvolutionReplayOverviewCardCopy(
            labelLine: overviewPresentation.labelLine.evolutionTrimmedNonEmpty
                ?? digestHeadlineLine
                ?? sourceTitle,
            titleLine: replayCardCopy.titleLine,
            detailLines: Self.uniqueOverviewLines(
                [replayCardCopy.secondaryLine, replayCardCopy.supplementaryLine]
                    + overviewPresentation.detailLines.map(Optional.some)
            )
        )
    }

    var diagnosticsHeaderCopy: DecisionEvolutionReplayDiagnosticsHeaderCopy {
        if let digest {
            return DecisionEvolutionReplayDiagnosticsHeaderCopy(
                eyebrowLine: digest.sourceDescriptor.title,
                statusLine: digest.compactStatusLine,
                titleLine: digest.taskTitle,
                detailLines: Self.uniqueOverviewLines([
                    digest.operationsLine,
                    summaryLine == digest.taskTitle ? nil : summaryLine
                ])
            )
        }

        return DecisionEvolutionReplayDiagnosticsHeaderCopy(
            eyebrowLine: sourceTitle,
            statusLine: nil,
            titleLine: summaryLine,
            detailLines: []
        )
    }

    var compactDiagnosticsLines: [DecisionEvolutionReplayDiagnosticLine] {
        let excludedLines = Set(
            [
                replayCardCopy.secondaryLine,
                replayCardCopy.supplementaryLine
            ]
            .compactMap { $0?.evolutionTrimmedNonEmpty }
        )

        return diagnosticsLines.filter { line in
            let trimmedText = line.text.evolutionTrimmedNonEmpty ?? line.text
            guard !excludedLines.contains(trimmedText) else {
                return false
            }

            if digest != nil, line.kind == .eBrain {
                return false
            }

            return true
        }
    }

    func fullDiagnosticsLines(
        excludingHeaderSummary: Bool,
        excludingOverviewSummary: Bool = false
    ) -> [DecisionEvolutionReplayDiagnosticLine] {
        let excludedLines = Set(
            (
                (excludingHeaderSummary ? diagnosticsHeaderCopy.detailLines : [])
                + (excludingOverviewSummary ? overviewCardCopy.detailLines : [])
            )
            .compactMap(\.evolutionTrimmedNonEmpty)
        )

        guard !excludedLines.isEmpty else { return diagnosticsLines }

        return diagnosticsLines.filter { line in
            let trimmedText = line.text.evolutionTrimmedNonEmpty ?? line.text
            return !excludedLines.contains(trimmedText)
        }
    }

    var diagnosticsLines: [DecisionEvolutionReplayDiagnosticLine] {
        [
            diagnosticLine(.operations, digest?.operationsLine),
            diagnosticLine(.budget, budgetLine),
            diagnosticLine(.pressure, pressureLine),
            diagnosticLine(.eBrain, eBrainLine),
            diagnosticLine(.riskFactors, riskFactorsLine),
            diagnosticLine(.reasonCodes, reasonCodesLine),
            diagnosticLine(.foldedLung, lungLine),
            diagnosticLine(.scheduler, schedulerLine),
            diagnosticLine(.hotCold, hotColdLine),
            diagnosticLine(.resume, resumeLine),
            diagnosticLine(.rollback, rollbackLine),
            diagnosticLine(.sovereignBridge, sovereignBridgeLine),
            diagnosticLine(.task, taskLine),
            diagnosticLine(.action, actionLine),
            diagnosticLine(.audit, auditLine),
            diagnosticLine(.activeKillSwitches, activeKillSwitchesLine),
            diagnosticLine(.killSwitches, killSwitchesLine),
            diagnosticLine(.trace, traceLine)
        ]
        .compactMap { $0 }
    }

    static func uniqueOverviewLines(_ values: [String?]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard let trimmedValue = value?.evolutionTrimmedNonEmpty,
                  !uniqueValues.contains(trimmedValue) else {
                return
            }
            uniqueValues.append(trimmedValue)
        }
    }

    private func diagnosticLine(
        _ kind: DecisionEvolutionReplayDiagnosticLine.Kind,
        _ text: String?
    ) -> DecisionEvolutionReplayDiagnosticLine? {
        guard let trimmedText = text?.evolutionTrimmedNonEmpty else { return nil }
        return DecisionEvolutionReplayDiagnosticLine(
            kind: kind,
            text: trimmedText
        )
    }
}

extension DecisionSystemEBrainSummary {
    var sourceDescriptor: DecisionEvolutionSourceDescriptor {
        if source == .persistedCheckpoint {
            return .checkpointRecoveryWorkspace
        }

        return .liveRuntimeDefault
    }
}

extension DeveloperDecisionReplayEBrainSummary {
    var worldPriorContract: DecisionEBrainWorldPriorContract? {
        executionCapability?.executionCapabilityFrame?.worldPriorContract
    }

    var temporalKnowledgeContract: DecisionEBrainTemporalKnowledgeContract? {
        executionCapability?.executionCapabilityFrame?.temporalKnowledgeContract
    }

    var evidenceContract: DecisionEBrainEvidenceContract? {
        executionCapability?.executionCapabilityFrame?.evidenceContract
    }

    var persistenceContract: DecisionEBrainPersistenceContract? {
        executionCapability?.executionCapabilityFrame?.persistenceContract
    }

    var executionCapabilityLine: String? {
        executionCapability?.executionCapabilityFrame?.detailLine
    }

    var horizonLine: String? {
        executionCapability?.executionCapabilityFrame?.horizonLine
    }

    var temporalLine: String? {
        executionCapability?.executionCapabilityFrame?.temporalLine
    }

    var evidenceLine: String? {
        executionCapability?.executionCapabilityFrame?.evidenceLine
    }

    var persistenceLine: String? {
        executionCapability?.executionCapabilityFrame?.persistenceLine
    }

    func digestPresentation(modeTitle: String) -> DecisionEvolutionEBrainDigestPresentation {
        let recommendedKillSwitchCount = killSwitches.filter { !activeKillSwitches.contains($0) }.count

        return DecisionEvolutionEBrainDigestPresentation(
            sourceDescriptor: sourceDescriptor,
            compactStatusLine: "\(modeTitle.uppercased()) • \(DecisionEvolutionEBrainPresentationSupport.riskPermitLine(riskLevel: riskLevel, permitMode: permitMode))",
            taskTitle: DecisionEvolutionEBrainPresentationSupport.taskTitle(taskType),
            operationsLine: "Audit \(guardrailFindings.count) • Active kill switches \(activeKillSwitches.count) • Recommended \(recommendedKillSwitchCount) • Host gate \(hostGatePercent)%"
        )
    }

    var sourceDescriptor: DecisionEvolutionSourceDescriptor {
        switch source {
        case .liveRuntime:
            .liveRuntimeDefault
        case .persistedCheckpoint:
            .checkpointRecoveryDefault
        }
    }
}

extension BASEBrainTurnResult {
    var diagnosticsPresentation: DecisionEvolutionTurnDiagnosticsPresentation {
        let support = turnDiagnosticsSupport

        return DecisionEvolutionTurnDiagnosticsPresentation(
            sourceDescriptor: .liveRuntimeDefault,
            runModeTitle: budgetFrame.runMode.displayTitle.uppercased(),
            taskTitle: DecisionEvolutionEBrainPresentationSupport.taskTitle(contextFrame.taskType.rawValue),
            riskTitle: riskCard.riskLevel.rawValue.uppercased(),
            permitTitle: actionPermit.mode.rawValue.uppercased(),
            mirrorText: decomposeFrame.mirrorText,
            routeText: support.routeText,
            hostText: support.hostText,
            replayText: support.replayText,
            auditLines: support.auditLines,
            activeKillSwitchesLine: support.activeKillSwitchesLine,
            recommendedKillSwitchesLine: support.recommendedKillSwitchesLine,
            layerStackLines: support.layerStackLines,
            candidateTitles: Array(thoughtFrame.candidates.prefix(3)).map(\.title),
            memorySummaries: Array(memoryBundle.atoms.prefix(3)).map(\.summary),
            triScoreLines: Array(triScores.prefix(3)).map(triScoreLine),
            riskFactorsLine: support.riskFactorsLine,
            reasonCodesLine: support.reasonCodesLine,
            alternativeActions: renderedOutput.alternativeActions,
            thoughtFoldLines: thoughtFold.compactSlots.keys.sorted().compactMap { key in
                guard let value = thoughtFold.compactSlots[key], !value.isEmpty else { return nil }
                return "• \(key): \(value)"
            },
            replayTraceLines: prioritizedReplayTraceLines(),
            ticketSummary: support.ticketSummary
        )
    }

    private func triScoreLine(for score: BASTriSelfScore) -> String {
        let base = "• \(score.candidateID): id \(Int((score.idScore * 100).rounded())) / ego \(Int((score.egoScore * 100).rounded())) / superego \(Int((score.superegoScore * 100).rounded()))"
        guard score.veto else { return base }

        let vetoSummary = formattedTriSelfVetoSummary(reasonCodes: mergedChoice.vetoReasonCodes)
        guard !vetoSummary.isEmpty else {
            return "\(base) • vetoed"
        }

        return "\(base) • vetoed (\(vetoSummary))"
    }

    private func formattedTriSelfVetoSummary(reasonCodes: [String]) -> String {
        let details = reasonCodes.compactMap { code -> String? in
            switch code {
            case "triself.superego_veto":
                nil
            case "triself.high_risk_direct_path":
                "high-risk direct path"
            case "triself.protective_boundary":
                "protective boundary"
            case "triself.calibration_drifting":
                "calibration drifting"
            default:
                code.replacingOccurrences(of: "triself.", with: "")
                    .replacingOccurrences(of: "_", with: " ")
            }
        }

        return details.joined(separator: ", ")
    }

    private func prioritizedReplayTraceLines() -> [String] {
        let preferredLayers = ["L2", "L3", "L10", "L11", "L13"]
        let prioritized = preferredLayers.compactMap { preferredLayer in
            runtimeTrace.layerEvents.first(where: { $0.layerID == preferredLayer })
        }

        let selectedEvents = prioritized.isEmpty
            ? Array(runtimeTrace.layerEvents.prefix(6))
            : prioritized

        return selectedEvents.map { event in
            "• \(event.layerID) \(event.event): \(event.detail)"
        }
    }
}

extension DeveloperDecisionReplayEntry {
    var diagnosticsPresentation: DecisionEvolutionReplayEntryPresentation {
        let replayRecoverySummary = eBrain?.replayRecoverySummary
        let digest = eBrain?.digestPresentation(modeTitle: mode.shortTitle)
        let overviewPresentation: DecisionEvolutionReplayOverviewPresentation
        let sovereignBridgeLines = eBrain?.sovereignBridgeDetailLines.map(Optional.some) ?? []

        if let digest {
            overviewPresentation = DecisionEvolutionReplayOverviewPresentation(
                labelLine: "\(digest.sourceDescriptor.title) • \(digest.compactStatusLine)",
                titleLine: digest.taskTitle,
                detailLines: DecisionEvolutionReplayEntryPresentation.uniqueOverviewLines(
                    [
                        replayRecoverySummary?.detailLine,
                        eBrain?.riskFactorsLine,
                        eBrain?.reasonCodesLine,
                        digest.operationsLine,
                        eBrain?.executionCapabilityLine,
                        eBrain?.horizonLine,
                        eBrain?.temporalLine,
                        eBrain?.evidenceLine,
                        eBrain?.lungLine,
                        eBrain?.schedulerLine,
                        eBrain?.hotColdLine,
                        eBrain?.resumeLine,
                        eBrain?.rollbackLine
                    ] + sovereignBridgeLines
                )
            )
        } else {
            let traceLine = trace.map {
                "Trace: \($0.kind.title) • \($0.activeProvider?.title ?? $0.preferredProvider.title)"
            }
            overviewPresentation = DecisionEvolutionReplayOverviewPresentation(
                labelLine: replayRecoverySummary?.sourceDescriptor.title ?? "Trace fallback",
                titleLine: summaryLine,
                detailLines: DecisionEvolutionReplayEntryPresentation.uniqueOverviewLines(
                    [
                        traceLine,
                        eBrain?.riskFactorsLine,
                        eBrain?.reasonCodesLine,
                        eBrain?.executionCapabilityLine,
                        eBrain?.horizonLine,
                        eBrain?.temporalLine,
                        eBrain?.evidenceLine,
                        eBrain?.lungLine,
                        eBrain?.schedulerLine,
                        eBrain?.hotColdLine,
                        eBrain?.resumeLine,
                        eBrain?.rollbackLine
                    ] + sovereignBridgeLines
                )
            )
        }

        return DecisionEvolutionReplayEntryPresentation(
            sourceTitle: replayRecoverySummary?.sourceDescriptor.title ?? "Trace fallback",
            modeTitle: mode.shortTitle,
            statusTitle: statusTitle,
            timestamp: timestamp,
            title: title,
            summaryLine: summaryLine,
            digest: digest,
            overviewPresentation: overviewPresentation,
            layerStackLines: eBrain?.layerStackLines ?? [],
            budgetLine: replayRecoverySummary?.budgetLine,
            pressureLine: replayRecoverySummary?.pressureLine,
            eBrainLine: replayRecoverySummary?.headlineLine,
            riskFactorsLine: eBrain?.riskFactorsLine,
            reasonCodesLine: eBrain?.reasonCodesLine,
            taskLine: replayRecoverySummary?.taskLine,
            actionLine: replayRecoverySummary?.actionLine,
            auditLine: replayRecoverySummary?.auditLine,
            activeKillSwitchesLine: replayRecoverySummary?.activeKillSwitchesLine,
            killSwitchesLine: replayRecoverySummary?.killSwitchesLine,
            lungLine: eBrain?.lungLine,
            schedulerLine: eBrain?.schedulerLine,
            hotColdLine: eBrain?.hotColdLine,
            resumeLine: eBrain?.resumeLine,
            rollbackLine: eBrain?.rollbackLine,
            sovereignBridgeLine: eBrain?.sovereignBridgeLine,
            traceLine: eBrain == nil ? overviewPresentation.detailLines.first : nil
        )
    }
}

enum DeveloperDecisionReplayBuilder {
    static func build(
        quick: [CheckEvent],
        balance: [BalanceDecisionRecord],
        mirror: [MirrorDecisionRecord],
        traces: [DecisionIntelligenceTrace],
        eBrainTurns: [BASEBrainTurnResult] = [],
        persistedLineages: [DecisionEvolutionLineageSnapshot] = [],
        limit: Int = BeforePolicy.Settings.developerReplayLimit
    ) -> [DeveloperDecisionReplayEntry] {
        let records = (
            quick.map(DeveloperDecisionReplayRecord.quick)
            + balance.map(DeveloperDecisionReplayRecord.balance)
            + mirror.map(DeveloperDecisionReplayRecord.mirror)
        )
        .sorted { $0.timestamp > $1.timestamp }

        var unmatchedTraces = Dictionary(
            grouping: traces.sorted { $0.createdAt > $1.createdAt },
            by: \.kind
        )
        var unmatchedTurns = Dictionary(
            grouping: eBrainTurns.sorted { $0.runtimeTrace.recordedAt > $1.runtimeTrace.recordedAt },
            by: { $0.replayMode ?? .quick }
        )
        var unmatchedPersistedLineages = Dictionary(
            grouping: persistedLineages.sorted { lhs, rhs in
                if lhs.eBrain.recordedAt == rhs.eBrain.recordedAt {
                    return lhs.checkpointID > rhs.checkpointID
                }
                return lhs.eBrain.recordedAt > rhs.eBrain.recordedAt
            },
            by: \.mode
        )

        let replayEntries = records.map { record in
            let trace = matchingTrace(
                for: record,
                unmatchedTraces: &unmatchedTraces
            )
            let turn = matchingTurn(
                for: record,
                unmatchedTurns: &unmatchedTurns
            )
            let consumedPersistedLineage = turn.flatMap { matchedTurn in
                matchingPersistedLineage(
                    for: matchedTurn,
                    unmatchedLineages: &unmatchedPersistedLineages
                )
            }
            let persistedLineage = turn == nil
                ? matchingPersistedLineage(
                    for: record,
                    unmatchedLineages: &unmatchedPersistedLineages
                )
                : nil
            return DeveloperDecisionReplayEntry(
                record: record,
                trace: trace.map(DeveloperDecisionReplayTraceSummary.init),
                eBrain: turn.map(DeveloperDecisionReplayEBrainSummary.init)
                    ?? persistedLineage.map(\.eBrain),
                matchedPersistedCheckpointID: consumedPersistedLineage?.checkpointID
                    ?? persistedLineage?.checkpointID
            )
        }

        let checkpointOnlyEntries = unmatchedPersistedLineages.values
            .flatMap { $0 }
            .map { lineage in
                DeveloperDecisionReplayEntry(
                    record: .checkpoint(lineage),
                    trace: nil,
                    eBrain: lineage.eBrain,
                    matchedPersistedCheckpointID: lineage.checkpointID
                )
            }

        return (replayEntries + checkpointOnlyEntries)
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }

    private static func matchingTrace(
        for record: DeveloperDecisionReplayRecord,
        unmatchedTraces: inout [DecisionIntelligenceTraceKind: [DecisionIntelligenceTrace]]
    ) -> DecisionIntelligenceTrace? {
        let kind = traceKind(for: record.mode)
        guard var candidates = unmatchedTraces[kind] else { return nil }
        guard let matchIndex = candidates.firstIndex(where: { isReasonableMatch(trace: $0, for: record.timestamp) }) else {
            return nil
        }

        let match = candidates.remove(at: matchIndex)
        unmatchedTraces[kind] = candidates
        return match
    }

    private static func matchingTurn(
        for record: DeveloperDecisionReplayRecord,
        unmatchedTurns: inout [DecisionMode: [BASEBrainTurnResult]]
    ) -> BASEBrainTurnResult? {
        guard var candidates = unmatchedTurns[record.mode] else { return nil }
        guard let matchIndex = candidates.firstIndex(where: { isReasonableMatch(turn: $0, for: record.timestamp) }) else {
            return nil
        }

        let match = candidates.remove(at: matchIndex)
        unmatchedTurns[record.mode] = candidates
        return match
    }

    private static func matchingPersistedLineage(
        for record: DeveloperDecisionReplayRecord,
        unmatchedLineages: inout [DecisionMode: [DecisionEvolutionLineageSnapshot]]
    ) -> DecisionEvolutionLineageSnapshot? {
        guard var candidates = unmatchedLineages[record.mode] else { return nil }
        guard let matchIndex = candidates.firstIndex(where: { isReasonableMatch(lineage: $0, for: record.timestamp) }) else {
            return nil
        }

        let match = candidates.remove(at: matchIndex)
        unmatchedLineages[record.mode] = candidates
        return match
    }

    private static func matchingPersistedLineage(
        for turn: BASEBrainTurnResult,
        unmatchedLineages: inout [DecisionMode: [DecisionEvolutionLineageSnapshot]]
    ) -> DecisionEvolutionLineageSnapshot? {
        let candidateModes = turn.replayMode.map { [$0] } ?? Array(unmatchedLineages.keys)
        let candidates = candidateModes.flatMap { unmatchedLineages[$0] ?? [] }
        guard !candidates.isEmpty else { return nil }

        let context = DecisionEvolutionRuntimeAnchorResolver.selectionContext(for: turn)
        guard let match = DecisionEvolutionRuntimeAnchorResolver.preferredLineage(
            in: candidates,
            matching: context
        ) else {
            return nil
        }

        removePersistedLineage(match, from: &unmatchedLineages)
        return match
    }

    private static func isReasonableMatch(trace: DecisionIntelligenceTrace, for timestamp: Date) -> Bool {
        let delta = timestamp.timeIntervalSince(trace.createdAt)
        return delta >= -BeforePolicy.Settings.developerReplayFutureTraceGraceInterval
            && delta <= BeforePolicy.Settings.developerReplayTraceLookbackInterval
    }

    private static func isReasonableMatch(turn: BASEBrainTurnResult, for timestamp: Date) -> Bool {
        let delta = timestamp.timeIntervalSince(turn.runtimeTrace.recordedAt)
        return delta >= -BeforePolicy.Settings.developerReplayFutureTraceGraceInterval
            && delta <= BeforePolicy.Settings.developerReplayTraceLookbackInterval
    }

    private static func isReasonableMatch(lineage: DecisionEvolutionLineageSnapshot, for timestamp: Date) -> Bool {
        let delta = timestamp.timeIntervalSince(lineage.eBrain.recordedAt)
        return delta >= -BeforePolicy.Settings.developerReplayFutureTraceGraceInterval
            && delta <= BeforePolicy.Settings.developerReplayTraceLookbackInterval
    }

    private static func removePersistedLineage(
        _ lineage: DecisionEvolutionLineageSnapshot,
        from unmatchedLineages: inout [DecisionMode: [DecisionEvolutionLineageSnapshot]]
    ) {
        for mode in Array(unmatchedLineages.keys) {
            guard var candidates = unmatchedLineages[mode] else { continue }
            if let index = candidates.firstIndex(where: { $0.checkpointID == lineage.checkpointID }) {
                candidates.remove(at: index)
                unmatchedLineages[mode] = candidates
                return
            }
        }
    }

    private static func traceKind(for mode: DecisionMode) -> DecisionIntelligenceTraceKind {
        switch mode {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        }
    }
}
