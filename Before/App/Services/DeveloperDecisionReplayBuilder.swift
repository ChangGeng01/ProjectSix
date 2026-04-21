import Foundation
import BASHostKit
import BASMemory

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
    let courtLine: String?
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let cognitionLine: String?
    let mirrorCalibrationLine: String?
    let activeKillSwitches: [String]
    let guardrailFindings: [String]
    let killSwitches: [String]
    let sovereignVerdictLine: String?
    let sovereignAuthorityLine: String?
    let sovereignAuditLine: String?
    let governanceLine: String?
    let versionTreeLine: String?
    let retractionLine: String?
    let layerStackLines: [String]
    let checkpointBudgetLine: String?
    let checkpointPressureLine: String?
    let checkpointTaskLine: String?
    let deliveryFallbackActionLine: String?
    let executionCapability: DecisionSessionCheckpointExecutionCapability?
    let morphGraph: BASMorphGraph?
    let hotColdMap: BASHotColdMap?
    let precisionProfile: BASPrecisionProfile?
    let lungState: BASLungState?
    let thermalExchange: BASThermalExchangeFrame?
    let breathScheduler: BASBreathSchedulerFrame?
    let integrityWeave: BASIntegrityWeaveFrame?
    let organPackages: [BASOrganPackage]
    let organDeltaPlan: BASOrganDeltaPlan?
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
        courtLine: String? = nil,
        riskFactorsLine: String? = nil,
        reasonCodesLine: String? = nil,
        cognitionLine: String? = nil,
        mirrorCalibrationLine: String? = nil,
        activeKillSwitches: [String],
        guardrailFindings: [String],
        killSwitches: [String],
        sovereignVerdictLine: String? = nil,
        sovereignAuthorityLine: String? = nil,
        sovereignAuditLine: String? = nil,
        governanceLine: String? = nil,
        versionTreeLine: String? = nil,
        retractionLine: String? = nil,
        layerStackLines: [String],
        checkpointBudgetLine: String?,
        checkpointPressureLine: String?,
        checkpointTaskLine: String?,
        deliveryFallbackActionLine: String? = nil,
        executionCapability: DecisionSessionCheckpointExecutionCapability? = nil,
        morphGraph: BASMorphGraph? = nil,
        hotColdMap: BASHotColdMap? = nil,
        precisionProfile: BASPrecisionProfile? = nil,
        lungState: BASLungState? = nil,
        thermalExchange: BASThermalExchangeFrame? = nil,
        breathScheduler: BASBreathSchedulerFrame? = nil,
        integrityWeave: BASIntegrityWeaveFrame? = nil,
        organPackages: [BASOrganPackage] = [],
        organDeltaPlan: BASOrganDeltaPlan? = nil,
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
        self.courtLine = courtLine
        self.riskFactorsLine = riskFactorsLine
        self.reasonCodesLine = reasonCodesLine
        self.cognitionLine = cognitionLine
        self.mirrorCalibrationLine = mirrorCalibrationLine
        self.activeKillSwitches = activeKillSwitches
        self.guardrailFindings = guardrailFindings
        self.killSwitches = killSwitches
        self.sovereignVerdictLine = sovereignVerdictLine
        self.sovereignAuthorityLine = sovereignAuthorityLine
        self.sovereignAuditLine = sovereignAuditLine
        self.governanceLine = governanceLine
        self.versionTreeLine = versionTreeLine
        self.retractionLine = retractionLine
        self.layerStackLines = layerStackLines
        self.checkpointBudgetLine = checkpointBudgetLine
        self.checkpointPressureLine = checkpointPressureLine
        self.checkpointTaskLine = checkpointTaskLine
        self.deliveryFallbackActionLine = deliveryFallbackActionLine
        self.executionCapability = executionCapability
        self.morphGraph = morphGraph
        self.hotColdMap = hotColdMap
        self.precisionProfile = precisionProfile
        self.lungState = lungState
        self.thermalExchange = thermalExchange
        self.breathScheduler = breathScheduler
        self.integrityWeave = integrityWeave
        self.organPackages = organPackages
        self.organDeltaPlan = organDeltaPlan
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
        self.courtLine = Self.courtLine(from: turn.mergedChoice)
        self.riskFactorsLine = turn.turnDiagnosticsSupport.riskFactorsLine
        self.reasonCodesLine = turn.turnDiagnosticsSupport.reasonCodesLine
        self.cognitionLine = turn.turnDiagnosticsSupport.cognitionLine
        self.mirrorCalibrationLine = turn.turnDiagnosticsSupport.mirrorCalibrationLine
        self.activeKillSwitches = activeKillSwitches
        self.guardrailFindings = turn.runtimeTrace.guardrailFindings.map(\.summary)
        self.killSwitches = Self.orderedUnique(activeKillSwitches + recommendedKillSwitches)
        self.sovereignVerdictLine = Self.sovereignVerdictLine(
            levelID: turn.sovereignVerdictLevelID,
            latched: turn.sovereignVerdictLatched,
            forcedModeID: turn.sovereignForcedModeID,
            reasonCodes: turn.sovereignVerdictReasonCodes
        )
        self.sovereignAuthorityLine = Self.sovereignAuthorityLine(
            tokenScopes: turn.sovereignTokenScopeIDs,
            warrantScopes: turn.sovereignWarrantScopeIDs,
            warrantPolicyIDs: Self.sovereignWarrantPolicyIDs(from: turn.sovereignWarrants),
            warrantTTLIDs: Self.sovereignWarrantTTLIDs(from: turn.sovereignWarrants),
            warrantWitnessCount: Self.sovereignWarrantWitnessCount(from: turn.sovereignWarrants),
            lockScopeID: turn.sovereignLockScopeID,
            quarantineZoneIDs: turn.sovereignQuarantineZoneIDs
        )
        self.sovereignAuditLine = Self.sovereignAuditLine(
            ruleIDs: turn.sovereignAuditRuleIDs,
            auditID: turn.sovereignAuditEntryID
        )
        self.governanceLine = Self.governanceLine(
            experienceCandidateCount: turn.experienceCandidates.count,
            workflowCandidateCount: turn.workflowCandidates.count,
            guardTemplateCandidateCount: turn.guardTemplateCandidates.count,
            biasRecordCount: turn.biasRecords.count,
            riskPatternCandidateCount: turn.riskPatternCandidates.count,
            learningExportBundleCount: turn.learningExportBundles.count,
            shadowTrialCount: turn.shadowTrialRecords.count,
            passedShadowTrialCount: turn.shadowTrialRecords.filter(\.isPassed).count,
            failedShadowTrialCount: turn.shadowTrialRecords.filter(\.isFailed).count,
            pendingShadowTrialCount: turn.shadowTrialRecords.filter(\.isPending).count,
            sealCount: turn.evolutionSeals.count,
            deniedSealCount: turn.evolutionSeals.filter(\.isDenied).count,
            pendingSealCount: turn.evolutionSeals.filter(\.isPending).count,
            versionDeltaCount: turn.versionDeltas.count,
            retractionOrderCount: turn.retractionOrders.count,
            pendingRetractionCount: turn.retractionOrders.filter {
                $0.executionState != "completed" && $0.executionState != "cleared"
            }.count,
            gateBlocked: turn.shadowTrialRecords.contains(where: \.isPending)
                || turn.shadowTrialRecords.contains(where: \.isFailed)
                || turn.evolutionSeals.contains(where: \.isPending)
                || turn.evolutionSeals.contains(where: \.isDenied)
                || turn.retractionOrders.contains {
                $0.executionState != "completed" && $0.executionState != "cleared"
            }
        )
        self.versionTreeLine = Self.versionTreeLine(
            highlights: Self.versionDeltaHighlights(from: turn.versionDeltas)
        )
        self.retractionLine = Self.retractionLine(
            highlights: Self.retractionOrderHighlights(from: turn.retractionOrders)
        )
        self.layerStackLines = Self.augmentedLayerStackLines(
            turn.layerStackLines,
            temporalField: turn.memoryBundle.temporalField,
            dreamLoopLine: Self.dreamLoopLine(from: turn)
        )
        self.checkpointBudgetLine = turn.replayCheckpointBudgetLine
        self.checkpointPressureLine = turn.replayCheckpointPressureLine
        self.checkpointTaskLine = turn.replayCheckpointTaskLine
        self.deliveryFallbackActionLine = turn.renderedOutput.deliveryFallbackActionLine
        self.executionCapability = nil
        self.morphGraph = foldedLung.morphGraph
        self.hotColdMap = foldedLung.hotColdMap
        self.precisionProfile = foldedLung.precisionProfile
        self.lungState = foldedLung.lungState
        self.thermalExchange = foldedLung.thermalExchange
        self.breathScheduler = foldedLung.breathScheduler
        self.integrityWeave = foldedLung.integrityWeave
        self.organPackages = foldedLung.organPackages
        self.organDeltaPlan = foldedLung.organDeltaPlan
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
        self.courtLine = DecisionEvolutionEBrainPresentationSupport.courtLine(
            from: lineageSummary
        )
        self.riskFactorsLine = nil
        self.reasonCodesLine = nil
        self.cognitionLine = nil
        self.mirrorCalibrationLine = Self.checkpointMirrorCalibrationLine(from: lineageSummary)
        self.activeKillSwitches = lineageSummary.activeKillSwitches
        self.guardrailFindings = lineageSummary.guardrailFindings
        self.killSwitches = Self.orderedUnique(
            lineageSummary.activeKillSwitches + lineageSummary.recommendedKillSwitches
        )
        self.sovereignVerdictLine = Self.sovereignVerdictLine(
            levelID: lineageSummary.sovereignVerdictLevelID,
            latched: lineageSummary.sovereignVerdictLatched,
            forcedModeID: lineageSummary.sovereignForcedModeID,
            reasonCodes: lineageSummary.sovereignVerdictReasonCodes
        )
        self.sovereignAuthorityLine = Self.sovereignAuthorityLine(
            tokenScopes: lineageSummary.sovereignTokenScopeIDs,
            warrantScopes: lineageSummary.sovereignWarrantScopeIDs,
            warrantPolicyIDs: Self.sovereignWarrantPolicyIDs(from: lineageSummary.sovereignWarrants),
            warrantTTLIDs: Self.sovereignWarrantTTLIDs(from: lineageSummary.sovereignWarrants),
            warrantWitnessCount: Self.sovereignWarrantWitnessCount(from: lineageSummary.sovereignWarrants),
            lockScopeID: lineageSummary.sovereignLockScopeID,
            quarantineZoneIDs: lineageSummary.sovereignQuarantineZoneIDs
        )
        self.sovereignAuditLine = Self.sovereignAuditLine(
            ruleIDs: lineageSummary.sovereignAuditRuleIDs,
            auditID: lineageSummary.sovereignAuditEntryID
        )
        self.governanceLine = Self.governanceLine(from: lineageSummary.governanceSummary)
        self.versionTreeLine = Self.versionTreeLine(
            highlights: lineageSummary.governanceSummary?.versionDeltaHighlights ?? []
        )
        self.retractionLine = Self.retractionLine(
            highlights: lineageSummary.governanceSummary?.retractionOrderHighlights ?? []
        )
        self.layerStackLines = Self.checkpointLayerStackLines(from: lineageSummary)
        self.checkpointBudgetLine = nil
        self.checkpointPressureLine = nil
        self.checkpointTaskLine = self.reviewDirectiveLine
            ?? lineageSummary.updateTicketSummaries.first?.evolutionTrimmedNonEmpty.map { "Review: \($0)" }
        self.deliveryFallbackActionLine = nil
        self.executionCapability = nil
        self.morphGraph = foldedLung.morphGraph
        self.hotColdMap = foldedLung.hotColdMap
        self.precisionProfile = foldedLung.precisionProfile
        self.lungState = foldedLung.lungState
        self.thermalExchange = foldedLung.thermalExchange
        self.breathScheduler = foldedLung.breathScheduler
        self.integrityWeave = foldedLung.integrityWeave
        self.organPackages = foldedLung.organPackages
        self.organDeltaPlan = foldedLung.organDeltaPlan
        self.resumeFrame = foldedLung.resumeFrame
        self.rollbackAnchor = foldedLung.rollbackAnchor
        self.sovereignBridgeResult = foldedLung.sovereignBridgeResult
    }

    var checkpointWindGateLine: String? {
        layerStackLines.first(where: { $0.hasPrefix("L11 wind gate") })
    }

    private static func courtLine(from mergedChoice: BASMergedChoice) -> String? {
        let summary = courtSummary(
            vetoApplied: mergedChoice.vetoApplied,
            vetoReasonCodes: mergedChoice.vetoReasonCodes,
            agencyReservation: mergedChoice.agencyReservation,
            remandOrders: mergedChoice.remandOrders,
            courtDecisionDraft: mergedChoice.courtDecisionDraft
        )
        guard let summary else { return nil }
        return "Court: \(summary)"
    }

    private static func courtSummary(
        vetoApplied: Bool,
        vetoReasonCodes: [String],
        agencyReservation: BASAgencyReservation?,
        remandOrders: [BASRemandOrder]?,
        courtDecisionDraft: BASCourtDecisionDraft?
    ) -> String? {
        var segments: [String] = []
        if vetoApplied {
            let vetoSummary = vetoReasonSummary(reasonCodes: vetoReasonCodes)
            segments.append(vetoSummary.isEmpty ? "veto" : "veto \(vetoSummary)")
        }
        if let agencyReservation {
            segments.append(
                "agency \(agencyReservation.mode.rawValue.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).lowercased())"
            )
        }
        if let remandOrders,
           remandOrders.isEmpty == false {
            segments.append("remand \(remandOrders.map(\.targetLayer).joined(separator: ", "))")
        }
        if let disclosure = courtSummarySnippet(courtDecisionDraft?.requiredDisclosures.first) {
            segments.append("disclose \(disclosure)")
        }
        if let unresolvedCost = courtSummarySnippet(courtDecisionDraft?.unresolvedCosts.first) {
            segments.append("cost \(unresolvedCost)")
        }
        guard segments.isEmpty == false else { return nil }
        return segments.joined(separator: " • ")
    }

    private static func vetoReasonSummary(reasonCodes: [String]) -> String {
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

    private static func courtSummarySnippet(_ text: String?) -> String? {
        guard let text else { return nil }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return nil }
        guard normalized.count > 72 else { return normalized }
        return String(normalized.prefix(69)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }

    private static func sovereignWarrantPolicyIDs(
        from warrants: [BASSovereignWarrant]
    ) -> [String] {
        orderedUnique(
            warrants.compactMap { warrant in
                compactPolicyID(for: warrant.policyHash)
            }
        )
    }

    private static func sovereignWarrantTTLIDs(
        from warrants: [BASSovereignWarrant]
    ) -> [String] {
        orderedUnique(
            warrants.compactMap { warrant in
                compactTTLID(
                    issuedAt: warrant.issuedAt,
                    expiresAt: warrant.expiresAt
                )
            }
        )
    }

    private static func sovereignWarrantWitnessCount(
        from warrants: [BASSovereignWarrant]
    ) -> Int {
        Set(warrants.flatMap(\.witnessRefs)).count
    }

    private static func compactPolicyID(for policyHash: String) -> String? {
        let trimmed = policyHash.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        guard trimmed.count > 16 else { return trimmed }
        return String(trimmed.prefix(16))
    }

    private static func compactTTLID(
        issuedAt: Date?,
        expiresAt: Date?
    ) -> String? {
        guard let issuedAt, let expiresAt else { return nil }
        let ttlSeconds = max(0, Int(expiresAt.timeIntervalSince(issuedAt).rounded()))
        guard ttlSeconds > 0 else { return "0s" }
        if ttlSeconds % 60 == 0 {
            return "\(ttlSeconds / 60)m"
        }
        return "\(ttlSeconds)s"
    }

    private static func augmentedLayerStackLines(
        _ baseLines: [String],
        temporalField: BASTemporalMemoryField?,
        dreamLoopLine: String? = nil
    ) -> [String] {
        var lines = baseLines

        if let dreamLoopLine = dreamLoopLine?.evolutionTrimmedNonEmpty {
            lines = insertingDreamLoopLine(
                dreamLoopLine,
                into: lines
            )
        }

        guard let temporalField else {
            return lines
        }

        let temporalLine = "L8 temporal field • records \(temporalField.records.count) • arcs \(temporalField.episodeArcs.count) • conflicts \(temporalField.conflictClusters.count) • sealed \(temporalField.sanctumEntries.count) • cascades \(temporalField.forgetCascades.count)"
        guard !lines.contains(temporalLine) else {
            return lines
        }
        return lines + [temporalLine]
    }

    private static func insertingDreamLoopLine(
        _ dreamLoopLine: String,
        into baseLines: [String]
    ) -> [String] {
        var lines = baseLines.filter { !$0.hasPrefix("L9 dream loop") }
        if let cognitionIndex = lines.firstIndex(where: { $0.hasPrefix("L7-L9 cognition") }) {
            lines.insert(dreamLoopLine, at: cognitionIndex + 1)
            return lines
        }
        if let adjudicationIndex = lines.firstIndex(where: { $0.hasPrefix("L10-L12 adjudication") }) {
            lines.insert(dreamLoopLine, at: adjudicationIndex)
            return lines
        }
        lines.append(dreamLoopLine)
        return lines
    }

    private static func sovereignVerdictLine(
        levelID: String?,
        latched: Bool,
        forcedModeID: String?,
        reasonCodes: [String]
    ) -> String? {
        guard let levelID else {
            return nil
        }

        let reasonSummary = reasonCodes
            .prefix(2)
            .joined(separator: ", ")

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                "Sovereign verdict \(levelID)",
                latched ? "latched" : nil,
                forcedModeID.map { "mode \($0)" },
                reasonSummary.isEmpty ? nil : "reasons \(reasonSummary)"
            ].compactMap { $0 }
        )
    }

    private static func sovereignAuthorityLine(
        tokenScopes: [String],
        warrantScopes: [String],
        warrantPolicyIDs: [String],
        warrantTTLIDs: [String],
        warrantWitnessCount: Int,
        lockScopeID: String?,
        quarantineZoneIDs: [String]
    ) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.sovereignAuthorityLine(
            tokenScopes: tokenScopes,
            warrantScopes: warrantScopes,
            warrantPolicyIDs: warrantPolicyIDs,
            warrantTTLIDs: warrantTTLIDs,
            warrantWitnessCount: warrantWitnessCount,
            lockScopeID: lockScopeID,
            quarantineZoneIDs: quarantineZoneIDs
        )
    }

    private static func sovereignAuditLine(
        ruleIDs: [String],
        auditID: String?
    ) -> String? {
        guard ruleIDs.isEmpty == false || auditID != nil else {
            return nil
        }

        let ruleSummary = ruleIDs
            .prefix(3)
            .joined(separator: ", ")

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                "Sovereign audit",
                ruleSummary.isEmpty ? nil : ruleSummary,
                auditID.map { "ref \($0)" }
            ].compactMap { $0 }
        )
    }

    private static func governanceLine(
        from governanceSummary: BASEvolutionLineageSummary.GovernanceSummary?
    ) -> String? {
        guard let governanceSummary else {
            return nil
        }

        return governanceLine(
            experienceCandidateCount: governanceSummary.experienceCandidateCount,
            workflowCandidateCount: governanceSummary.workflowCandidateCount,
            guardTemplateCandidateCount: governanceSummary.guardTemplateCandidateCount,
            biasRecordCount: governanceSummary.biasRecordCount,
            riskPatternCandidateCount: governanceSummary.riskPatternCandidateCount,
            learningExportBundleCount: governanceSummary.learningExportBundleCount,
            shadowTrialCount: governanceSummary.shadowTrialCount,
            passedShadowTrialCount: governanceSummary.passedShadowTrialCount,
            failedShadowTrialCount: governanceSummary.failedShadowTrialCount,
            pendingShadowTrialCount: governanceSummary.pendingShadowTrialCount,
            sealCount: governanceSummary.sealCount,
            deniedSealCount: governanceSummary.deniedSealCount,
            pendingSealCount: governanceSummary.pendingSealCount,
            versionDeltaCount: governanceSummary.versionDeltaCount,
            retractionOrderCount: governanceSummary.retractionOrderCount,
            pendingRetractionCount: governanceSummary.pendingRetractionCount,
            gateBlocked: governanceSummary.blockedPromotionReasonCodes.isEmpty == false
        )
    }

    private static func dreamLoopLine(
        from turn: BASEBrainTurnResult
    ) -> String? {
        dreamLoopLine(
            stoppingMode: turn.thoughtFrame.convergenceCertificate?.stoppingMode.rawValue,
            reservationMode: turn.thoughtFrame.agencyReservation?.mode.rawValue,
            remandTargets: turn.thoughtFrame.remandOrders?.map(\.targetLayer) ?? [],
            signalRefs: turn.updateTickets
                .flatMap(\.governanceRefs)
                .filter { $0.hasPrefix("dream_loop:") || $0.hasPrefix("dream_loop_") },
            maxEvidenceDebtPercent: maxEvidenceDebtPercent(
                from: turn.thoughtFrame.evidenceDebts
            )
        )
    }

    private static func dreamLoopLine(
        from governanceSummary: BASEvolutionLineageSummary.GovernanceSummary?
    ) -> String? {
        guard let governanceSummary else {
            return nil
        }

        return dreamLoopLine(
            stoppingMode: governanceSummary.dreamLoopStoppingMode,
            reservationMode: governanceSummary.dreamLoopReservationMode,
            remandTargets: governanceSummary.dreamLoopRemandTargets,
            signalRefs: governanceSummary.dreamLoopSignalRefs,
            maxEvidenceDebtPercent: governanceSummary.dreamLoopMaxEvidenceDebtPercent
        )
    }

    private static func dreamLoopLine(
        stoppingMode: String?,
        reservationMode: String?,
        remandTargets: [String],
        signalRefs: [String],
        maxEvidenceDebtPercent: Int?
    ) -> String? {
        let stopLine = stoppingMode?.evolutionTrimmedNonEmpty.map {
            "stop \(humanizedDreamLoopToken($0))"
        }
        let reservationLine = reservationMode?.evolutionTrimmedNonEmpty.map {
            "reserve \(humanizedDreamLoopToken($0))"
        }
        let remandLine = remandTargets.isEmpty
            ? nil
            : "remand \(orderedUnique(remandTargets).prefix(3).joined(separator: ", "))"
        let evidenceDebtLine = maxEvidenceDebtPercent.map { "debt \($0)%" }
        let signalLine = dreamLoopSignalLine(
            signalRefs: signalRefs,
            stopMode: stoppingMode,
            reservationMode: reservationMode
        )

        let details = [
            stopLine,
            reservationLine,
            remandLine,
            evidenceDebtLine,
            signalLine
        ]
        .compactMap { $0?.evolutionTrimmedNonEmpty }

        guard details.isEmpty == false else {
            return nil
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            ["L9 dream loop"] + details
        ).evolutionTrimmedNonEmpty
    }

    private static func dreamLoopSignalLine(
        signalRefs: [String],
        stopMode: String?,
        reservationMode: String?
    ) -> String? {
        let normalizedSignals = orderedUnique(
            signalRefs.compactMap { signalRef in
                let token = normalizedDreamLoopSignalToken(from: signalRef)
                guard let token else { return nil }

                let humanizedToken = humanizedDreamLoopToken(token)
                if humanizedToken == humanizedDreamLoopToken(stopMode) {
                    return nil
                }
                if humanizedToken == humanizedDreamLoopToken(reservationMode) {
                    return nil
                }
                return humanizedToken
            }
        )

        guard normalizedSignals.isEmpty == false else {
            return nil
        }

        return "signals \(normalizedSignals.prefix(2).joined(separator: ", "))"
    }

    private static func normalizedDreamLoopSignalToken(
        from signalRef: String
    ) -> String? {
        signalRef
            .replacingOccurrences(of: "dream_loop_stop:", with: "")
            .replacingOccurrences(of: "dream_loop_reservation:", with: "")
            .replacingOccurrences(of: "dream_loop:", with: "")
            .evolutionTrimmedNonEmpty
    }

    private static func humanizedDreamLoopToken(
        _ token: String?
    ) -> String {
        guard let token = token?.evolutionTrimmedNonEmpty else {
            return ""
        }

        return token
            .replacingOccurrences(
                of: "([a-z0-9])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()
    }

    private static func maxEvidenceDebtPercent(
        from evidenceDebts: [BASEvidenceDebt]?
    ) -> Int? {
        guard let maxDebtWeight = evidenceDebts?.map(\.debtWeight).max() else {
            return nil
        }
        return Int((maxDebtWeight * 100).rounded())
    }

    private static func governanceLine(
        experienceCandidateCount: Int,
        workflowCandidateCount: Int = 0,
        guardTemplateCandidateCount: Int = 0,
        biasRecordCount: Int = 0,
        riskPatternCandidateCount: Int = 0,
        learningExportBundleCount: Int = 0,
        shadowTrialCount: Int,
        passedShadowTrialCount: Int = 0,
        failedShadowTrialCount: Int = 0,
        pendingShadowTrialCount: Int,
        sealCount: Int,
        deniedSealCount: Int = 0,
        pendingSealCount: Int,
        versionDeltaCount: Int,
        retractionOrderCount: Int,
        pendingRetractionCount: Int,
        gateBlocked: Bool
    ) -> String? {
        let hasGovernanceSignals =
            experienceCandidateCount > 0
            || workflowCandidateCount > 0
            || guardTemplateCandidateCount > 0
            || biasRecordCount > 0
            || riskPatternCandidateCount > 0
            || learningExportBundleCount > 0
            || shadowTrialCount > 0
            || sealCount > 0
            || versionDeltaCount > 0
            || retractionOrderCount > 0
            || gateBlocked

        guard hasGovernanceSignals else {
            return nil
        }

        var details = ["candidates \(experienceCandidateCount)"]

        if shadowTrialCount > 0 || pendingShadowTrialCount > 0 || passedShadowTrialCount > 0 || failedShadowTrialCount > 0 {
            details.append(
                pendingShadowTrialCount > 0
                    ? "shadow \(pendingShadowTrialCount) pending/\(shadowTrialCount)"
                    : (failedShadowTrialCount > 0
                        ? "shadow failed \(failedShadowTrialCount)/\(shadowTrialCount)"
                        : (passedShadowTrialCount > 0
                            ? "shadow ready \(passedShadowTrialCount)/\(shadowTrialCount)"
                            : "shadow cleared \(shadowTrialCount)"))
            )
        }

        if sealCount > 0 || pendingSealCount > 0 || deniedSealCount > 0 {
            details.append(
                pendingSealCount > 0
                    ? "seal \(pendingSealCount) pending/\(sealCount)"
                    : (deniedSealCount > 0
                        ? "seal denied \(deniedSealCount)/\(sealCount)"
                        : "seal ready \(sealCount)")
            )
        }

        if versionDeltaCount > 0 {
            details.append("version \(versionDeltaCount)")
        }

        if retractionOrderCount > 0 || pendingRetractionCount > 0 {
            details.append(
                pendingRetractionCount > 0
                    ? "retract \(pendingRetractionCount) pending/\(retractionOrderCount)"
                    : "retract cleared \(retractionOrderCount)"
            )
        }

        if workflowCandidateCount > 0
            || guardTemplateCandidateCount > 0
            || biasRecordCount > 0
            || riskPatternCandidateCount > 0
            || learningExportBundleCount > 0 {
            details.append("nursery workflow \(workflowCandidateCount)")
            details.append("guard \(guardTemplateCandidateCount)")
            details.append("bias \(biasRecordCount)")
            details.append("risk \(riskPatternCandidateCount)")
            details.append("export \(learningExportBundleCount)")
        }

        if gateBlocked {
            details.append("gate hold")
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            ["L13 governance"] + details
        ).evolutionTrimmedNonEmpty
    }

    private static func versionDeltaHighlights(
        from versionDeltas: [BASVersionDelta]
    ) -> [String] {
        Array(versionDeltas.prefix(2)).map { delta in
            let targetRef = delta.afterRef
            return [
                "\(delta.targetType) \(targetRef)",
                delta.rollbackRef.map { "rollback \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
        }
    }

    private static func retractionOrderHighlights(
        from retractionOrders: [BASRetractionOrder]
    ) -> [String] {
        Array(retractionOrders.prefix(2)).map { order in
            let status = order.executionState.replacingOccurrences(of: "_", with: " ")
            let targetRef = order.targetRefs.first ?? order.cascadeRefs.first ?? order.orderID
            return [
                "\(status) \(targetRef)",
                order.reasonCodes.first.map { "reason \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: " • ")
        }
    }

    private static func versionTreeLine(
        highlights: [String]
    ) -> String? {
        highlightLine(
            prefix: "L13 version tree",
            highlights: highlights
        )
    }

    private static func retractionLine(
        highlights: [String]
    ) -> String? {
        highlightLine(
            prefix: "L13 retraction",
            highlights: highlights
        )
    }

    private static func highlightLine(
        prefix: String,
        highlights: [String]
    ) -> String? {
        guard let first = highlights.first?.evolutionTrimmedNonEmpty else {
            return nil
        }

        let moreCount = highlights.count - 1
        return DecisionEvolutionNarrativeFormattingSupport.joined(
            [
                prefix,
                first,
                moreCount > 0 ? "+\(moreCount) more" : nil
            ]
            .compactMap { $0 }
        ).evolutionTrimmedNonEmpty
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
        let sovereignVerdictLine = lineageSummary.sovereignVerdictLevelID.map {
            "verdict \($0)"
        }
        let sovereignTokenLine: String? = {
            let scopes = lineageSummary.sovereignTokenScopeIDs
            guard scopes.isEmpty == false else { return nil }
            return "tokens \(Array(scopes.prefix(3)).joined(separator: ", "))"
        }()
        let sovereignWarrantLine: String? = {
            let scopes = lineageSummary.sovereignWarrantScopeIDs
            guard scopes.isEmpty == false else { return nil }
            return "warrants \(Array(scopes.prefix(3)).joined(separator: ", "))"
        }()
        let sovereignWarrantPolicyLine: String? = {
            let policyIDs = lineageSummary.sovereignWarrantPolicyIDs
            guard policyIDs.isEmpty == false else { return nil }
            return "policy \(Array(policyIDs.prefix(2)).joined(separator: ", "))"
        }()
        let sovereignWarrantTTLLine: String? = {
            let ttlIDs = lineageSummary.sovereignWarrantTTLIDs
            guard ttlIDs.isEmpty == false else { return nil }
            return "ttl \(Array(ttlIDs.prefix(2)).joined(separator: ", "))"
        }()
        let sovereignWarrantWitnessLine: String? = {
            let witnessCount = lineageSummary.sovereignWarrantWitnessCount
            guard witnessCount > 0 else { return nil }
            return "witnesses \(witnessCount)"
        }()
        let sovereignLockLine = lineageSummary.sovereignLockScopeID.map { "lock \($0)" }
        let quarantineLine: String? = {
            let zones = lineageSummary.sovereignQuarantineZoneIDs
            guard zones.isEmpty == false else { return nil }
            return "quarantine \(Array(zones.prefix(2)).joined(separator: ", "))"
        }()
        let sovereignAuditLine = (lineageSummary.sovereignAuditRuleIDs.first ?? lineageSummary.sovereignAuditEntryID)
            .map { "audit \($0)" }
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
            let recoveryParts: [String?] = [
                $0.kind.rawValue,
                $0.summary,
                $0.operatorReviewRequired ? "operator review required" : nil,
                $0.requiredConfirmations.isEmpty
                    ? nil
                    : "confirm \($0.requiredConfirmations.joined(separator: ", "))",
                $0.allowedActionClasses.isEmpty
                    ? nil
                    : "allow \($0.allowedActionClasses.joined(separator: ", "))",
                $0.blockedActionClasses.isEmpty
                    ? nil
                    : "block \($0.blockedActionClasses.joined(separator: ", "))",
                $0.remediationActions.isEmpty
                    ? nil
                    : "remediate \($0.remediationActions.joined(separator: ", "))"
            ]

            return DecisionEvolutionNarrativeFormattingSupport.joined(
                recoveryParts.compactMap { $0 }
            )
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
                sovereignWarrantLine,
                sovereignWarrantPolicyLine,
                sovereignWarrantTTLLine,
                sovereignWarrantWitnessLine,
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
        let contextLines = checkpointContextLayerLines(from: lineageSummary)
        let cognitionLine = checkpointCognitionLayerLine(from: lineageSummary)
        let dreamLoopLine = dreamLoopLine(from: lineageSummary.governanceSummary)
        let adjudicationLine = checkpointAdjudicationLayerLine(
            from: lineageSummary,
            brakeLine: brakeLine
        )
        let riskClimateLine = checkpointRiskClimateLayerLine(from: lineageSummary)

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
            contextLines.first,
            contextLines.dropFirst().first,
            cognitionLine,
            dreamLoopLine,
            adjudicationLine,
            riskClimateLine,
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "L13 evolution",
                "\(lineageSummary.updateTicketSummaries.count) tickets",
                reviewDirective
            ].compactMap { $0 }),
            sovereignLayerLine
        ]
        .compactMap { $0?.evolutionTrimmedNonEmpty }
    }

    private static func checkpointContextLayerLines(
        from lineageSummary: BASEvolutionLineageSummary
    ) -> [String] {
        guard let contextSummary = lineageSummary.contextSummary else {
            return [
                DecisionEvolutionEBrainPresentationSupport.fallbackContextLayerStackLine(
                    taskType: lineageSummary.taskType,
                    sessionID: lineageSummary.sessionID
                ),
                DecisionEvolutionEBrainPresentationSupport.fallbackContextPresenceLayerStackLine(
                    taskType: lineageSummary.taskType
                )
            ]
        }

        let primaryLine = DecisionEvolutionEBrainPresentationSupport.contextLayerStackLine(
            taskType: lineageSummary.taskType,
            emotionalLoadPercent: contextSummary.emotionalLoadPercent,
            timePressurePercent: contextSummary.timePressurePercent,
            relationPattern: contextSummary.relationPattern,
            ambiguityPercent: contextSummary.ambiguityPercent,
            consequencePercent: contextSummary.consequencePercent,
            manipulationHintCount: contextSummary.manipulationHintCount
        )
        let presenceLine = DecisionEvolutionEBrainPresentationSupport.contextPresenceLayerStackLine(
            sceneType: contextSummary.sceneType,
            roleRelationClass: contextSummary.roleRelationClass,
            powerDirection: contextSummary.powerDirection,
            powerStrengthPercent: contextSummary.powerStrengthPercent,
            urgencyPercent: contextSummary.urgencyPercent,
            routeMode: contextSummary.routeMode,
            guardRequired: contextSummary.guardRequired,
            continuityArc: contextSummary.continuityArc
        )

        return [primaryLine, presenceLine].compactMap { $0?.evolutionTrimmedNonEmpty }
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
            claimCount: cognitionSummary.claimCount,
            unknownCount: cognitionSummary.unknownCount,
            contradictionCount: cognitionSummary.contradictionCount,
            pressureSummary: cognitionSummary.pressureSummary,
            manipulationSummary: cognitionSummary.manipulationSummary,
            boundarySummary: cognitionSummary.boundarySummary,
            mirrorModeID: cognitionSummary.mirrorModeID,
            routeHint: cognitionSummary.routeHint,
            memoryAtomCount: cognitionSummary.memoryAtomCount,
            candidateCount: cognitionSummary.candidateCount,
            forecastCount: cognitionSummary.forecastCount,
            critiqueCount: cognitionSummary.critiqueCount,
            stopReasonID: cognitionSummary.stopReasonID
        )
    }

    private static func checkpointMirrorCalibrationLine(
        from lineageSummary: BASEvolutionLineageSummary
    ) -> String? {
        guard let cognitionSummary = lineageSummary.cognitionSummary else {
            return nil
        }

        return DecisionEvolutionEBrainPresentationSupport.mirrorCalibrationLine(
            mirrorModeID: cognitionSummary.mirrorModeID,
            routeHint: cognitionSummary.routeHint,
            calibrationPointCount: cognitionSummary.mirrorCalibrationPointCount,
            omittedSpeculationCount: cognitionSummary.mirrorOmittedSpeculationCount,
            toneGuard: cognitionSummary.mirrorToneGuard,
            pressureSummary: cognitionSummary.pressureSummary,
            manipulationSummary: cognitionSummary.manipulationSummary,
            boundarySummary: cognitionSummary.boundarySummary
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

    private static func checkpointRiskClimateLayerLine(
        from lineageSummary: BASEvolutionLineageSummary
    ) -> String? {
        var details = [String]()

        details.append("primary \(lineageSummary.permitMode)")

        if let assertionCeiling = lineageSummary.assertionCeiling?.evolutionTrimmedNonEmpty {
            details.append("assert \(assertionCeiling)")
        }

        if let delayType = lineageSummary.delayType?.evolutionTrimmedNonEmpty {
            details.append("delay \(delayType)")
        }

        if let substituteType = lineageSummary.substituteType?.evolutionTrimmedNonEmpty {
            details.append("substitute \(substituteType)")
        }

        if let sovereignHintLevel = lineageSummary.sovereignHintLevel?.evolutionTrimmedNonEmpty {
            details.append("sovereign \(sovereignHintLevel)")
        }

        guard details.count > 1 else {
            return nil
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            ["L11 wind gate"] + details
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
                thermalExchange: nil,
                breathScheduler: nil,
                integrityWeave: nil,
                organPackages: [],
                organDeltaPlan: nil,
                resumeFrame: nil,
                rollbackAnchor: nil,
                sovereignBridgeResult: nil
            )
        }

        let morphGraph = persistedMorphGraph(from: summary)
        let hotColdMap = persistedHotColdMap(from: summary)
        let precisionProfile = persistedPrecisionProfile(from: summary)
        let breathScheduler = persistedBreathScheduler(from: summary)
        let thermalExchange = persistedThermalExchange(from: summary)
        let integrityWeave = persistedIntegrityWeave(from: summary)
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
        let organPackages = persistedOrganPackages(from: summary)
        let organDeltaPlan = persistedOrganDeltaPlan(
            from: summary,
            organPackages: organPackages,
            sovereignBridgeResult: sovereignBridgeResult
        )

        return PersistedFoldedLungProjection(
            morphGraph: morphGraph,
            hotColdMap: hotColdMap,
            precisionProfile: precisionProfile,
            lungState: lungState,
            thermalExchange: thermalExchange,
            breathScheduler: breathScheduler,
            integrityWeave: integrityWeave,
            organPackages: organPackages,
            organDeltaPlan: organDeltaPlan,
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

    private static func persistedThermalExchange(
        from summary: BASEvolutionFoldedLungSummary
    ) -> BASThermalExchangeFrame? {
        guard
            summary.thermalExchangeID?.evolutionTrimmedNonEmpty != nil
                || summary.thermalExchangeMode?.evolutionTrimmedNonEmpty != nil
                || summary.thermalPredictedBand?.evolutionTrimmedNonEmpty != nil
                || summary.thermalCoolingActions.isEmpty == false
                || summary.thermalSuppressedOrganIDs.isEmpty == false
                || summary.thermalRerouteTargets.isEmpty == false
                || summary.thermalPrecisionDowngradeRecords.isEmpty == false
        else {
            return nil
        }

        return BASThermalExchangeFrame(
            exchangeID: summary.thermalExchangeID?.evolutionTrimmedNonEmpty
                ?? "thermal.persisted.\(summary.sourceFoldID)",
            exchangeMode: summary.thermalExchangeMode?.evolutionTrimmedNonEmpty ?? "steady_exchange",
            predictedThermalBand: summary.thermalPredictedBand?.evolutionTrimmedNonEmpty ?? "nominal",
            coolingActions: summary.thermalCoolingActions,
            suppressedOrgans: summary.thermalSuppressedOrganIDs.compactMap(BASNeuralOrgan.init(rawValue:)),
            reroutedOrgans: summary.thermalReroutedOrganIDs.compactMap(BASNeuralOrgan.init(rawValue:)),
            rerouteTargets: summary.thermalRerouteTargets,
            precisionDowngradePlan: summary.thermalPrecisionDowngradeRecords.compactMap(persistedPrecisionRecord),
            exchangeReasonCodes: summary.thermalExchangeReasonCodes
        )
    }

    private static func persistedIntegrityWeave(
        from summary: BASEvolutionFoldedLungSummary
    ) -> BASIntegrityWeaveFrame? {
        guard
            summary.integrityWeaveID?.evolutionTrimmedNonEmpty != nil
                || summary.integrityPurityState?.evolutionTrimmedNonEmpty != nil
                || summary.integrityVerificationHash?.evolutionTrimmedNonEmpty != nil
                || summary.integrityRequiredChecks.isEmpty == false
                || summary.integrityCompletedChecks.isEmpty == false
                || summary.integrityFailedChecks.isEmpty == false
                || summary.integrityContaminationRefs.isEmpty == false
        else {
            return nil
        }

        return BASIntegrityWeaveFrame(
            weaveID: summary.integrityWeaveID?.evolutionTrimmedNonEmpty
                ?? "integrity.persisted.\(summary.sourceFoldID)",
            foldChecksum: summary.integrityHash,
            rollbackIntegrityHash: summary.integrityHash,
            requiredChecks: summary.integrityRequiredChecks,
            completedChecks: summary.integrityCompletedChecks,
            failedChecks: summary.integrityFailedChecks,
            purityState: summary.integrityPurityState?.evolutionTrimmedNonEmpty ?? "verified",
            contaminationRefs: summary.integrityContaminationRefs,
            trustedSnapshotRef: summary.integrityTrustedSnapshotRef?.evolutionTrimmedNonEmpty
                ?? summary.safeSnapshotRef,
            verificationHash: summary.integrityVerificationHash?.evolutionTrimmedNonEmpty
                ?? summary.integrityHash
        )
    }

    private static func persistedOrganPackages(
        from summary: BASEvolutionFoldedLungSummary
    ) -> [BASOrganPackage] {
        summary.organPackageRecords.compactMap { record in
            guard let organ = BASNeuralOrgan(rawValue: record.organID) else {
                return nil
            }

            return BASOrganPackage(
                packageID: record.packageID,
                organType: organ,
                sizeMB: record.sizeMB,
                precisionOptions: record.precisionOptionIDs.compactMap(BASNeuralPrecisionTier.init(rawValue:)),
                loadTimeMs: record.loadTimeMs,
                thermalCost: record.thermalCost,
                sovereignClass: record.sovereignClass
            )
        }
    }

    private static func persistedOrganDeltaPlan(
        from summary: BASEvolutionFoldedLungSummary,
        organPackages: [BASOrganPackage],
        sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult?
    ) -> BASOrganDeltaPlan? {
        guard
            summary.organDeltaPlanID?.evolutionTrimmedNonEmpty != nil
                || summary.organDeltaMode?.evolutionTrimmedNonEmpty != nil
                || summary.organPackageRecords.isEmpty == false
        else {
            return nil
        }

        return BASOrganDeltaPlan(
            planID: summary.organDeltaPlanID?.evolutionTrimmedNonEmpty
                ?? "delta.persisted.\(summary.sourceFoldID)",
            deltaMode: summary.organDeltaMode?.evolutionTrimmedNonEmpty ?? "steady_retention",
            activatePackageIDs: summary.organDeltaActivatePackageIDs,
            preloadPackageIDs: summary.organDeltaPreloadPackageIDs,
            evictPackageIDs: summary.organDeltaEvictPackageIDs,
            retainPackageIDs: summary.organDeltaRetainPackageIDs.isEmpty
                ? organPackages
                    .filter { $0.sovereignClass == "protected_core" || $0.sovereignClass == "checkpoint_recovery" }
                    .map(\.packageID)
                : summary.organDeltaRetainPackageIDs,
            rollbackSafeRetainedPackageIDs: summary.organDeltaRollbackSafePackageIDs,
            triggeredActuationKinds: summary.organDeltaTriggeredActuationKinds.compactMap(BASSovereignActuationKind.init(rawValue:)),
            reasonCodes: summary.organDeltaReasonCodes.isEmpty
                ? (sovereignBridgeResult?.actuationKinds.isEmpty == false
                    ? ["sovereign.\((sovereignBridgeResult?.actuationKinds ?? []).map(\.rawValue).joined(separator: "+"))"]
                    : [])
                : summary.organDeltaReasonCodes
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
    let thermalExchange: BASThermalExchangeFrame?
    let breathScheduler: BASBreathSchedulerFrame?
    let integrityWeave: BASIntegrityWeaveFrame?
    let organPackages: [BASOrganPackage]
    let organDeltaPlan: BASOrganDeltaPlan?
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

    var organPackageLine: String? {
        organPackages.decisionOrganPackageLine
    }

    var lungLine: String? {
        lungState?.decisionLungLine
    }

    var thermalExchangeLine: String? {
        thermalExchange?.decisionThermalExchangeLine
    }

    var schedulerLine: String? {
        breathScheduler?.decisionSchedulerLine
    }

    var integrityWeaveLine: String? {
        integrityWeave?.decisionIntegrityWeaveLine
    }

    var organDeltaLine: String? {
        organDeltaPlan?.decisionOrganDeltaLine
    }

    var resumeLine: String? {
        resumeFrame?.decisionResumeLine
    }

    var rollbackLine: String? {
        rollbackAnchor?.decisionRollbackLine
    }

    var sovereignBridgeLine: String? {
        effectiveSovereignBridgeResult?.primaryLine
    }

    var sovereignBridgeDetailLines: [String] {
        effectiveSovereignBridgeResult?.detailLines ?? []
    }

    var sovereignBridgeSupplementalLines: [String] {
        effectiveSovereignBridgeResult?.supplementalLines ?? []
    }

    private var effectiveSovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult? {
        guard let sovereignBridgeResult else {
            return nil
        }
        guard let organDeltaPlan else {
            return sovereignBridgeResult
        }
        return sovereignBridgeResult.enriched(organDeltaPlan: organDeltaPlan)
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
            courtLine: courtLine,
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
            thermalExchange: anchor.thermalExchange ?? thermalExchange,
            breathScheduler: anchor.breathScheduler ?? breathScheduler,
            integrityWeave: anchor.integrityWeave ?? integrityWeave,
            organPackages: anchoredSnapshot?.organPackages ?? organPackages,
            organDeltaPlan: anchoredSnapshot?.organDeltaPlan ?? organDeltaPlan,
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
        detail: "Showing the active 14-layer turn synthesized from the current local runtime."
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
    let courtLine: String?
    let cognitionLine: String?
    let mirrorCalibrationLine: String?
    let alternativeActions: [String]
    let deliveryFallbackGuidance: String?
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
        case court
        case cognition
        case mirrorCalibration
        case foldedLung
        case organDelta
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
    let courtLine: String?
    let cognitionLine: String?
    let mirrorCalibrationLine: String?
    let taskLine: String?
    let actionLine: String?
    let auditLine: String?
    let activeKillSwitchesLine: String?
    let killSwitchesLine: String?
    let lungLine: String?
    let organDeltaLine: String?
    let schedulerLine: String?
    let hotColdLine: String?
    let resumeLine: String?
    let rollbackLine: String?
    let sovereignBridgeLine: String?
    let furnaceContributionLines: [String]
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
        courtLine: String? = nil,
        cognitionLine: String? = nil,
        mirrorCalibrationLine: String? = nil,
        taskLine: String?,
        actionLine: String?,
        auditLine: String?,
        activeKillSwitchesLine: String?,
        killSwitchesLine: String?,
        lungLine: String? = nil,
        organDeltaLine: String? = nil,
        schedulerLine: String? = nil,
        hotColdLine: String? = nil,
        resumeLine: String? = nil,
        rollbackLine: String? = nil,
        sovereignBridgeLine: String? = nil,
        furnaceContributionLines: [String] = [],
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
        self.courtLine = courtLine
        self.cognitionLine = cognitionLine
        self.mirrorCalibrationLine = mirrorCalibrationLine
        self.taskLine = taskLine
        self.actionLine = actionLine
        self.auditLine = auditLine
        self.activeKillSwitchesLine = activeKillSwitchesLine
        self.killSwitchesLine = killSwitchesLine
        self.lungLine = lungLine
        self.organDeltaLine = organDeltaLine
        self.schedulerLine = schedulerLine
        self.hotColdLine = hotColdLine
        self.resumeLine = resumeLine
        self.rollbackLine = rollbackLine
        self.sovereignBridgeLine = sovereignBridgeLine
        self.furnaceContributionLines = furnaceContributionLines
        self.traceLine = traceLine
    }
}

extension DecisionEvolutionReplayEntryPresentation {
    var windGateLine: String? {
        layerStackLines.first(where: { $0.hasPrefix("L11 wind gate") })
    }

    var dreamLoopLine: String? {
        layerStackLines.first(where: { $0.hasPrefix("L9 dream loop") })
    }

    var lineageMetadataText: String? {
        DecisionEvolutionCheckpointDetailPresentationSupport.combinedMetadataText(
            base: nil,
            supplementalLines: [
                DecisionEvolutionCheckpointDetailPresentationSupport.windGateMetadataLine(
                    layerStackLines: layerStackLines
                ),
                DecisionEvolutionCheckpointDetailPresentationSupport.dreamLoopMetadataLine(
                    layerStackLines: layerStackLines
                )
            ]
            .compactMap { $0 }
        )
    }

    var overviewSupplementaryDetailLines: [String] {
        overviewCardCopy.remainingDetailLines.filter { line in
            !line.hasPrefix("L9 dream loop")
                && !line.hasPrefix("L11 wind gate")
        }
    }

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
            diagnosticLine(.court, courtLine),
            diagnosticLine(.cognition, cognitionLine),
            diagnosticLine(.mirrorCalibration, mirrorCalibrationLine),
            diagnosticLine(.foldedLung, lungLine),
            diagnosticLine(.organDelta, organDeltaLine),
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

    var temporalMemoryLine: String? {
        layerStackLines
            .first(where: { $0.hasPrefix("L8 temporal field") })
            .map { $0.replacingOccurrences(of: "L8 temporal field", with: "Temporal memory") }
    }

    var dreamLoopLine: String? {
        layerStackLines.first(where: { $0.hasPrefix("L9 dream loop") })
    }

    var furnaceContributionLines: [String] {
        DecisionEvolutionEBrainPresentationSupport.furnaceContributionLines(
            layerStackLines: layerStackLines,
            temporalLine: temporalMemoryLine,
            governanceLine: governanceLine,
            versionTreeLine: versionTreeLine,
            retractionLine: retractionLine,
            sovereignBridgeLine: sovereignBridgeLine
        )
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
            courtLine: support.courtLine,
            cognitionLine: support.cognitionLine,
            mirrorCalibrationLine: support.mirrorCalibrationLine,
            alternativeActions: renderedOutput.alternativeActions,
            deliveryFallbackGuidance: renderedOutput.deliveryFallbackGuidance,
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
        let courtSummary = formattedTriSelfCourtSummary(
            agencyReservation: mergedChoice.agencyReservation,
            remandOrders: mergedChoice.remandOrders,
            courtDecisionDraft: mergedChoice.courtDecisionDraft
        )
        guard !vetoSummary.isEmpty else {
            guard !courtSummary.isEmpty else {
                return "\(base) • vetoed"
            }
            return "\(base) • vetoed • \(courtSummary)"
        }

        guard !courtSummary.isEmpty else {
            return "\(base) • vetoed (\(vetoSummary))"
        }

        return "\(base) • vetoed (\(vetoSummary)) • \(courtSummary)"
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

    private func formattedTriSelfCourtSummary(
        agencyReservation: BASAgencyReservation?,
        remandOrders: [BASRemandOrder]?,
        courtDecisionDraft: BASCourtDecisionDraft?
    ) -> String {
        var segments: [String] = []
        if let agencyReservation {
            segments.append(
                "agency \(agencyReservation.mode.rawValue.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).lowercased())"
            )
        }
        if let remandOrders,
           remandOrders.isEmpty == false {
            segments.append("remand \(remandOrders.map(\.targetLayer).joined(separator: ", "))")
        }
        if let disclosure = courtSummarySnippet(
            courtDecisionDraft?.requiredDisclosures.first
        ) {
            segments.append("disclose \(disclosure)")
        }
        if let unresolvedCost = courtSummarySnippet(
            courtDecisionDraft?.unresolvedCosts.first
        ) {
            segments.append("cost \(unresolvedCost)")
        }
        return segments.joined(separator: " • ")
    }

    private func courtSummarySnippet(_ text: String?) -> String? {
        guard let text else { return nil }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return nil }
        guard normalized.count > 72 else { return normalized }
        return String(normalized.prefix(69)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
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
        let furnaceContributionLines = eBrain?.furnaceContributionLines ?? []
        let sovereignBridgeLines = eBrain?.sovereignBridgeDetailLines.map(Optional.some) ?? []

        if let digest {
            let digestDetailLines = [
                replayRecoverySummary?.detailLine,
                eBrain?.riskFactorsLine,
                eBrain?.reasonCodesLine,
                eBrain?.cognitionLine,
                eBrain?.mirrorCalibrationLine,
                eBrain?.courtLine,
                digest.operationsLine,
                eBrain?.executionCapabilityLine,
                eBrain?.horizonLine,
                eBrain?.temporalLine,
                eBrain?.temporalMemoryLine,
                eBrain?.dreamLoopLine,
                eBrain?.evidenceLine,
                eBrain?.lungLine,
                eBrain?.organPackageLine,
                eBrain?.organDeltaLine,
                eBrain?.schedulerLine,
                eBrain?.hotColdLine,
                eBrain?.resumeLine,
                eBrain?.rollbackLine,
                eBrain?.governanceLine
            ]
            overviewPresentation = DecisionEvolutionReplayOverviewPresentation(
                labelLine: "\(digest.sourceDescriptor.title) • \(digest.compactStatusLine)",
                titleLine: digest.taskTitle,
                detailLines: DecisionEvolutionReplayEntryPresentation.uniqueOverviewLines(
                    digestDetailLines + sovereignBridgeLines
                )
            )
        } else {
            let traceLine = trace.map {
                "Trace: \($0.kind.title) • \($0.activeProvider?.title ?? $0.preferredProvider.title)"
            }
            let fallbackDetailLines = [
                traceLine,
                eBrain?.riskFactorsLine,
                eBrain?.reasonCodesLine,
                eBrain?.cognitionLine,
                eBrain?.mirrorCalibrationLine,
                eBrain?.courtLine,
                eBrain?.executionCapabilityLine,
                eBrain?.horizonLine,
                eBrain?.temporalLine,
                eBrain?.temporalMemoryLine,
                eBrain?.dreamLoopLine,
                eBrain?.evidenceLine,
                eBrain?.lungLine,
                eBrain?.organPackageLine,
                eBrain?.organDeltaLine,
                eBrain?.schedulerLine,
                eBrain?.hotColdLine,
                eBrain?.resumeLine,
                eBrain?.rollbackLine,
                eBrain?.governanceLine
            ]
            overviewPresentation = DecisionEvolutionReplayOverviewPresentation(
                labelLine: replayRecoverySummary?.sourceDescriptor.title ?? "Trace fallback",
                titleLine: summaryLine,
                detailLines: DecisionEvolutionReplayEntryPresentation.uniqueOverviewLines(
                    fallbackDetailLines + sovereignBridgeLines
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
            courtLine: eBrain?.courtLine,
            cognitionLine: eBrain?.cognitionLine,
            mirrorCalibrationLine: eBrain?.mirrorCalibrationLine,
            taskLine: replayRecoverySummary?.taskLine,
            actionLine: replayRecoverySummary?.actionLine,
            auditLine: replayRecoverySummary?.auditLine,
            activeKillSwitchesLine: replayRecoverySummary?.activeKillSwitchesLine,
            killSwitchesLine: replayRecoverySummary?.killSwitchesLine,
            lungLine: eBrain?.lungLine,
            organDeltaLine: eBrain?.organDeltaLine,
            schedulerLine: eBrain?.schedulerLine,
            hotColdLine: eBrain?.hotColdLine,
            resumeLine: eBrain?.resumeLine,
            rollbackLine: eBrain?.rollbackLine,
            sovereignBridgeLine: eBrain?.sovereignBridgeLine,
            furnaceContributionLines: furnaceContributionLines,
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
