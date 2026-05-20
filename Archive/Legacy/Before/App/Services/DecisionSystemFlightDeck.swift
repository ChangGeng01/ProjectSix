import Foundation
import BASHostKit

enum DecisionSystemLayer: String, CaseIterable, Identifiable, Sendable {
    case runtime
    case data
    case memory
    case safety
    case orchestration
    case observability
    case evaluation
    case delivery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runtime: "Runtime"
        case .data: "Data"
        case .memory: "Memory"
        case .safety: "Safety"
        case .orchestration: "Orchestration"
        case .observability: "Observability"
        case .evaluation: "Evaluation"
        case .delivery: "Delivery"
        }
    }
}

enum DecisionSystemLayerHealth: String, Sendable {
    case strong
    case watch
    case critical

    var title: String {
        rawValue.capitalized
    }
}

struct DecisionSystemLayerReport: Identifiable, Equatable, Sendable {
    let layer: DecisionSystemLayer
    let score: Int
    let health: DecisionSystemLayerHealth
    let headline: String
    let signals: [String]
    let blockers: [String]

    var id: DecisionSystemLayer { layer }

    var surfaceSummaryLine: String? {
        blockers.first.map { "Blocker: \($0)" } ?? signals.first
    }

    var surfaceSummaryUsesHealthTint: Bool {
        !blockers.isEmpty
    }
}

struct DecisionSystemEBrainSummary: Equatable, Sendable {
    let source: DecisionTestingEBrainSource
    let runMode: String
    let taskType: String
    let riskLevel: String
    let permitMode: String
    let deviceRoute: String
    let loopCount: Int
    let cacheHitRate: Int
    let hostGatePercent: Int
    let presenceLine: String?
    let pressureLine: String?
    let actionLine: String?
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let courtLine: String?
    let governanceLine: String?
    let foldChecksum: String
    let updateTicketCount: Int
    let auditFindingCount: Int
    let activeKillSwitches: [String]
    let recommendedKillSwitches: [String]
    let killSwitches: [String]
    let sovereignVerdictLine: String?
    let sovereignAuthorityLine: String?
    let sovereignAuditLine: String?
    let versionTreeLine: String?
    let retractionLine: String?
    let inspectionHeadline: String
    let blockers: [String]
    let layerStackLines: [String]
    let checkpointID: String?
    let checkpointApprovalState: String?
    let checkpointRollbackReady: Bool?
    let checkpointApplyReady: Bool?
    let executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame?
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
        source: DecisionTestingEBrainSource,
        runMode: String,
        taskType: String,
        riskLevel: String,
        permitMode: String,
        deviceRoute: String,
        loopCount: Int,
        cacheHitRate: Int,
        hostGatePercent: Int,
        presenceLine: String? = nil,
        pressureLine: String?,
        actionLine: String? = nil,
        riskFactorsLine: String? = nil,
        reasonCodesLine: String? = nil,
        courtLine: String? = nil,
        governanceLine: String? = nil,
        foldChecksum: String,
        updateTicketCount: Int,
        auditFindingCount: Int,
        activeKillSwitches: [String],
        recommendedKillSwitches: [String],
        killSwitches: [String],
        sovereignVerdictLine: String? = nil,
        sovereignAuthorityLine: String? = nil,
        sovereignAuditLine: String? = nil,
        versionTreeLine: String? = nil,
        retractionLine: String? = nil,
        inspectionHeadline: String,
        blockers: [String],
        layerStackLines: [String],
        checkpointID: String?,
        checkpointApprovalState: String?,
        checkpointRollbackReady: Bool?,
        checkpointApplyReady: Bool?,
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? = nil,
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
        self.runMode = runMode
        self.taskType = taskType
        self.riskLevel = riskLevel
        self.permitMode = permitMode
        self.deviceRoute = deviceRoute
        self.loopCount = loopCount
        self.cacheHitRate = cacheHitRate
        self.hostGatePercent = hostGatePercent
        self.presenceLine = presenceLine
        self.pressureLine = pressureLine
        self.actionLine = actionLine
        self.riskFactorsLine = riskFactorsLine
        self.reasonCodesLine = reasonCodesLine
        self.courtLine = courtLine
        self.governanceLine = governanceLine
        self.foldChecksum = foldChecksum
        self.updateTicketCount = updateTicketCount
        self.auditFindingCount = auditFindingCount
        self.activeKillSwitches = activeKillSwitches
        self.recommendedKillSwitches = recommendedKillSwitches
        self.killSwitches = killSwitches
        self.sovereignVerdictLine = sovereignVerdictLine
        self.sovereignAuthorityLine = sovereignAuthorityLine
        self.sovereignAuditLine = sovereignAuditLine
        self.versionTreeLine = versionTreeLine
        self.retractionLine = retractionLine
        self.inspectionHeadline = inspectionHeadline
        self.blockers = blockers
        self.layerStackLines = layerStackLines
        self.checkpointID = checkpointID
        self.checkpointApprovalState = checkpointApprovalState
        self.checkpointRollbackReady = checkpointRollbackReady
        self.checkpointApplyReady = checkpointApplyReady
        self.executionCapabilityFrame = executionCapabilityFrame
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
}

struct DecisionSystemEBrainSummaryPresentation: Equatable, Sendable {
    let sourceDescriptor: DecisionEvolutionSourceDescriptor
    let statusLine: String
    let routeLine: String
    let presenceLine: String?
    let pressureLine: String?
    let actionLine: String?
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let courtLine: String?
    let governanceLine: String?
    let hostLine: String
    let sovereignVerdictLine: String?
    let sovereignAuthorityLine: String?
    let sovereignAuditLine: String?
    let inspectionHeadline: String
    let primaryGuardrailText: String?
    let detailLines: [String]
    let alertLine: String?
    let layerStackLines: [String]
    let executionCapabilityLine: String?
    let horizonLine: String?
    let temporalLine: String?
    let evidenceLine: String?
    let worldPriorContract: DecisionEBrainWorldPriorContract?
    let temporalKnowledgeContract: DecisionEBrainTemporalKnowledgeContract?
    let evidenceContract: DecisionEBrainEvidenceContract?
    let persistenceLine: String?
    let persistenceContract: DecisionEBrainPersistenceContract?

    init(
        sourceDescriptor: DecisionEvolutionSourceDescriptor,
        statusLine: String,
        routeLine: String,
        presenceLine: String? = nil,
        pressureLine: String?,
        actionLine: String? = nil,
        riskFactorsLine: String? = nil,
        reasonCodesLine: String? = nil,
        courtLine: String? = nil,
        governanceLine: String? = nil,
        hostLine: String,
        sovereignVerdictLine: String? = nil,
        sovereignAuthorityLine: String? = nil,
        sovereignAuditLine: String? = nil,
        inspectionHeadline: String,
        primaryGuardrailText: String?,
        detailLines: [String],
        alertLine: String?,
        layerStackLines: [String] = [],
        executionCapabilityLine: String? = nil,
        horizonLine: String? = nil,
        temporalLine: String? = nil,
        evidenceLine: String? = nil,
        worldPriorContract: DecisionEBrainWorldPriorContract? = nil,
        temporalKnowledgeContract: DecisionEBrainTemporalKnowledgeContract? = nil,
        evidenceContract: DecisionEBrainEvidenceContract? = nil,
        persistenceLine: String? = nil,
        persistenceContract: DecisionEBrainPersistenceContract? = nil
    ) {
        self.sourceDescriptor = sourceDescriptor
        self.statusLine = statusLine
        self.routeLine = routeLine
        self.presenceLine = presenceLine
        self.pressureLine = pressureLine
        self.actionLine = actionLine
        self.riskFactorsLine = riskFactorsLine
        self.reasonCodesLine = reasonCodesLine
        self.courtLine = courtLine
        self.governanceLine = governanceLine
        self.hostLine = hostLine
        self.sovereignVerdictLine = sovereignVerdictLine
        self.sovereignAuthorityLine = sovereignAuthorityLine
        self.sovereignAuditLine = sovereignAuditLine
        self.inspectionHeadline = inspectionHeadline
        self.primaryGuardrailText = primaryGuardrailText
        self.detailLines = detailLines
        self.alertLine = alertLine
        self.layerStackLines = layerStackLines
        self.executionCapabilityLine = executionCapabilityLine
        self.horizonLine = horizonLine
        self.temporalLine = temporalLine
        self.evidenceLine = evidenceLine
        self.worldPriorContract = worldPriorContract
        self.temporalKnowledgeContract = temporalKnowledgeContract
        self.evidenceContract = evidenceContract
        self.persistenceLine = persistenceLine
        self.persistenceContract = persistenceContract
    }
}

struct DecisionEvolutionEBrainDigestPresentation: Equatable, Sendable {
    let sourceDescriptor: DecisionEvolutionSourceDescriptor
    let compactStatusLine: String
    let taskTitle: String
    let operationsLine: String
}

struct DecisionSystemFlightDeckEBrainDigestPresentation: Equatable, Sendable {
    let digest: DecisionEvolutionEBrainDigestPresentation
    let statusLine: String
    let routeLine: String
    let presenceLine: String?
    let pressureLine: String?
    let actionLine: String?
    let hostLine: String
    let inspectionHeadline: String
    let primaryGuardrailText: String?
    let detailLines: [String]
    let summaryLines: [String]
    let alertLine: String?
    let layerStackLines: [String]
}

extension DecisionSystemFlightDeckEBrainDigestPresentation {
    fileprivate static func uniqueLines(_ values: [String?]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmedValue.isEmpty,
                  !uniqueValues.contains(trimmedValue) else {
                return
            }
            uniqueValues.append(trimmedValue)
        }
    }
}

extension DecisionSystemEBrainSummary {
    private static func uniqueLines(_ values: [String?]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmedValue.isEmpty,
                  !uniqueValues.contains(trimmedValue) else {
                return
            }
            uniqueValues.append(trimmedValue)
        }
    }

    var compactStatusLine: String {
        "\(runMode.uppercased()) • \(riskLevel.uppercased()) → \(permitMode.uppercased())"
    }

    var taskTitle: String {
        DecisionEvolutionEBrainPresentationSupport.taskTitle(taskType)
    }

    var digestPresentation: DecisionEvolutionEBrainDigestPresentation {
        DecisionEvolutionEBrainDigestPresentation(
            sourceDescriptor: sourceDescriptor,
            compactStatusLine: compactStatusLine,
            taskTitle: taskTitle,
            operationsLine: "Audit \(auditFindingCount) • Active kill switches \(activeKillSwitches.count) • Recommended \(recommendedKillSwitches.count) • Host gate \(hostGatePercent)%"
        )
    }

    private var horizonDiagnosticsDetail: String? {
        let detail = DecisionEvolutionNarrativeFormattingSupport.joined(
            [riskFactorsLine, reasonCodesLine, courtLine, governanceLine].compactMap { $0 }
        )
        return detail.isEmpty ? nil : detail
    }

    private var horizonAlertLine: String? {
        guard horizonDiagnosticsDetail != nil else {
            return nil
        }
        return "Horizon diagnostics active"
    }

    private var windGateLine: String? {
        layerStackLines.first { $0.hasPrefix("L11 wind gate") }
    }

    private var windGateSummaryLine: String? {
        guard let windGateLine else {
            return nil
        }

        let segments = windGateLine
            .components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard segments.count > 1 else {
            return "Wind gate active"
        }

        let detail = DecisionEvolutionEBrainPresentationSupport.humanizedWindGateDetail(
            segments.dropFirst().joined(separator: " • ")
        )
        guard detail.isEmpty == false else {
            return "Wind gate active"
        }

        return "Wind gate: \(detail)"
    }

    var furnaceContributionLines: [String] {
        DecisionEvolutionEBrainPresentationSupport.furnaceContributionLines(
            layerStackLines: layerStackLines,
            temporalLine: executionCapabilityFrame?.temporalLine,
            governanceLine: governanceLine,
            versionTreeLine: versionTreeLine,
            retractionLine: retractionLine,
            sovereignBridgeLine: sovereignBridgeLine
        )
    }

    var foldedLungLines: [String] {
        DecisionEvolutionEBrainPresentationSupport.foldedLungLines(
            layerStackLines: layerStackLines,
            lungLine: lungLine,
            morphLine: morphLine,
            hotColdLine: hotColdLine,
            precisionLine: precisionLine,
            organPackageLine: organPackageLine,
            organDeltaLine: organDeltaLine,
            schedulerLine: schedulerLine,
            thermalExchangeLine: thermalExchangeLine,
            integrityWeaveLine: integrityWeaveLine,
            resumeLine: resumeLine,
            rollbackLine: rollbackLine
        )
    }

    var presentation: DecisionSystemEBrainSummaryPresentation {
        let statusLine = "\(runMode.uppercased()) • \(taskTitle) • \(DecisionEvolutionEBrainPresentationSupport.riskPermitLine(riskLevel: riskLevel, permitMode: permitMode))"
        let routeLine = "Route \(deviceRoute) • Loops \(loopCount) • Cache \(cacheHitRate)% • Tickets \(updateTicketCount)"
        let executionCapabilityLine = executionCapabilityFrame?.detailLine
        let horizonLine = executionCapabilityFrame?.horizonLine
        let temporalLine = executionCapabilityFrame?.temporalLine
        let evidenceLine = executionCapabilityFrame?.evidenceLine
        let persistenceLine = executionCapabilityFrame?.persistenceLine
        let worldPriorContract = executionCapabilityFrame?.worldPriorContract
        let temporalKnowledgeContract = executionCapabilityFrame?.temporalKnowledgeContract
        let evidenceContract = executionCapabilityFrame?.evidenceContract
        let persistenceContract = executionCapabilityFrame?.persistenceContract
        let hostLine = "\(DecisionEvolutionEBrainPresentationSupport.hostFoldLine(hostGatePercent: hostGatePercent, foldChecksum: foldChecksum)) • Audit \(auditFindingCount)"
        let guardrailAlertLine = blockers.first.map { "Guardrail: \($0)" }
        let alertLine = guardrailAlertLine ?? horizonAlertLine

        return DecisionSystemEBrainSummaryPresentation(
            sourceDescriptor: sourceDescriptor,
            statusLine: statusLine,
            routeLine: routeLine,
            presenceLine: presenceLine,
            pressureLine: pressureLine,
            actionLine: actionLine,
            riskFactorsLine: riskFactorsLine,
            reasonCodesLine: reasonCodesLine,
            courtLine: courtLine,
            governanceLine: governanceLine,
            hostLine: hostLine,
            sovereignVerdictLine: sovereignVerdictLine,
            sovereignAuthorityLine: sovereignAuthorityLine,
            sovereignAuditLine: sovereignAuditLine,
            inspectionHeadline: inspectionHeadline,
            primaryGuardrailText: alertLine,
            detailLines: Self.uniqueLines([
                statusLine,
                routeLine,
                presenceLine,
                riskFactorsLine,
                reasonCodesLine,
                courtLine,
                windGateSummaryLine,
                executionCapabilityLine,
                horizonLine,
                temporalLine,
                evidenceLine,
                persistenceLine,
                pressureLine,
                actionLine,
                governanceLine,
                hostLine,
                sovereignVerdictLine,
                sovereignAuthorityLine,
                sovereignAuditLine,
                inspectionHeadline,
                morphLine,
                hotColdLine,
                precisionLine,
                organPackageLine,
                lungLine,
                organDeltaLine,
                thermalExchangeLine,
                schedulerLine,
                integrityWeaveLine,
                resumeLine,
                rollbackLine
            ] + furnaceContributionLines.map(Optional.some) + sovereignBridgeDetailLines.map(Optional.some)),
            alertLine: alertLine,
            layerStackLines: layerStackLines,
            executionCapabilityLine: executionCapabilityLine,
            horizonLine: horizonLine,
            temporalLine: temporalLine,
            evidenceLine: evidenceLine,
            worldPriorContract: worldPriorContract,
            temporalKnowledgeContract: temporalKnowledgeContract,
            evidenceContract: evidenceContract,
            persistenceLine: persistenceLine,
            persistenceContract: persistenceContract
        )
    }

    func applying(
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame?
    ) -> DecisionSystemEBrainSummary {
        DecisionSystemEBrainSummary(
            source: source,
            runMode: runMode,
            taskType: taskType,
            riskLevel: riskLevel,
            permitMode: permitMode,
            deviceRoute: deviceRoute,
            loopCount: loopCount,
            cacheHitRate: cacheHitRate,
            hostGatePercent: hostGatePercent,
            presenceLine: presenceLine,
            pressureLine: pressureLine,
            actionLine: actionLine,
            riskFactorsLine: riskFactorsLine,
            reasonCodesLine: reasonCodesLine,
            courtLine: courtLine,
            governanceLine: governanceLine,
            foldChecksum: foldChecksum,
            updateTicketCount: updateTicketCount,
            auditFindingCount: auditFindingCount,
            activeKillSwitches: activeKillSwitches,
            recommendedKillSwitches: recommendedKillSwitches,
            killSwitches: killSwitches,
            sovereignVerdictLine: sovereignVerdictLine,
            sovereignAuthorityLine: sovereignAuthorityLine,
            sovereignAuditLine: sovereignAuditLine,
            versionTreeLine: versionTreeLine,
            retractionLine: retractionLine,
            inspectionHeadline: inspectionHeadline,
            blockers: blockers,
            layerStackLines: layerStackLines,
            checkpointID: checkpointID,
            checkpointApprovalState: checkpointApprovalState,
            checkpointRollbackReady: checkpointRollbackReady,
            checkpointApplyReady: checkpointApplyReady,
            executionCapabilityFrame: executionCapabilityFrame,
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

    private var lungLine: String? {
        lungState?.decisionLungLine
    }

    private var organDeltaLine: String? {
        organDeltaPlan?.decisionOrganDeltaLine
    }

    private var morphLine: String? {
        morphGraph?.decisionMorphLine
    }

    private var hotColdLine: String? {
        hotColdMap?.decisionHotColdLine
    }

    private var precisionLine: String? {
        precisionProfile?.decisionPrecisionLine
    }

    private var organPackageLine: String? {
        organPackages.decisionOrganPackageLine
    }

    private var thermalExchangeLine: String? {
        thermalExchange?.decisionThermalExchangeLine
    }

    private var schedulerLine: String? {
        breathScheduler?.decisionSchedulerLine
    }

    private var integrityWeaveLine: String? {
        integrityWeave?.decisionIntegrityWeaveLine
    }

    private var resumeLine: String? {
        resumeFrame?.decisionResumeLine
    }

    private var rollbackLine: String? {
        rollbackAnchor?.decisionRollbackLine
    }

    private var sovereignBridgeLine: String? {
        effectiveSovereignBridgeResult?.primaryLine
    }

    private var sovereignBridgeDetailLines: [String] {
        effectiveSovereignBridgeResult?.detailLines ?? []
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
}

extension BASEBrainTurnResult {
    var systemFlightDeckSummary: DecisionSystemEBrainSummary {
        let inspection = BASEBrainConsoleSupport.inspectionBundle(for: self)
        let replaySummary = DeveloperDecisionReplayEBrainSummary(turn: self)
        let factsBundle = replaySummary.factsBundle()
        let foldedLung = DecisionFoldedLungCoordinator.snapshot(for: self)

        return DecisionSystemEBrainSummary(
            source: .liveRuntime,
            runMode: budgetFrame.runMode.displayTitle,
            taskType: contextFrame.taskType.rawValue,
            riskLevel: riskCard.riskLevel.rawValue,
            permitMode: actionPermit.mode.rawValue,
            deviceRoute: runtimeTrace.modelRoute,
            loopCount: runtimeTrace.loopCount,
            cacheHitRate: Int((runtimeTrace.cacheHitRate * 100).rounded()),
            hostGatePercent: Int((hostGateValue * 100).rounded()),
            presenceLine: factsBundle.displayPresenceLine(),
            pressureLine: factsBundle.pressureLine,
            actionLine: factsBundle.actionLine,
            riskFactorsLine: factsBundle.riskFactorsLine,
            reasonCodesLine: factsBundle.reasonCodesLine,
            courtLine: factsBundle.courtLine,
            governanceLine: factsBundle.governanceLine,
            foldChecksum: String(thoughtFold.checksum.prefix(12)),
            updateTicketCount: updateTickets.count,
            auditFindingCount: runtimeTrace.guardrailFindings.count,
            activeKillSwitches: runtimeTrace.activeKillSwitches.map(\.rawValue),
            recommendedKillSwitches: runtimeTrace.recommendedKillSwitches.map(\.rawValue),
            killSwitches: DecisionSystemFlightDeckBuilder.orderedUnique(
                runtimeTrace.activeKillSwitches.map(\.rawValue)
                + runtimeTrace.recommendedKillSwitches.map(\.rawValue)
            ),
            sovereignVerdictLine: replaySummary.sovereignVerdictLine,
            sovereignAuthorityLine: replaySummary.sovereignAuthorityLine,
            sovereignAuditLine: replaySummary.sovereignAuditLine,
            versionTreeLine: replaySummary.versionTreeLine,
            retractionLine: replaySummary.retractionLine,
            inspectionHeadline: inspection.summary,
            blockers: inspection.blockerSummary,
            layerStackLines: factsBundle.layerStackLines,
            checkpointID: nil,
            checkpointApprovalState: nil,
            checkpointRollbackReady: nil,
            checkpointApplyReady: nil,
            morphGraph: foldedLung.morphGraph,
            hotColdMap: foldedLung.hotColdMap,
            precisionProfile: foldedLung.precisionProfile,
            lungState: foldedLung.lungState,
            thermalExchange: foldedLung.thermalExchange,
            breathScheduler: foldedLung.breathScheduler,
            integrityWeave: foldedLung.integrityWeave,
            organPackages: foldedLung.organPackages,
            organDeltaPlan: foldedLung.organDeltaPlan,
            resumeFrame: foldedLung.resumeFrame,
            rollbackAnchor: foldedLung.rollbackAnchor,
            sovereignBridgeResult: foldedLung.sovereignBridgeResult
        )
    }
}

extension DecisionEvolutionLineageSnapshot {
    var systemFlightDeckSummary: DecisionSystemEBrainSummary {
        let factsBundle = factsBundle

        return DecisionSystemEBrainSummary(
            source: eBrain.source == .liveRuntime ? .liveRuntime : .persistedCheckpoint,
            runMode: "checkpoint",
            taskType: eBrain.taskType,
            riskLevel: eBrain.riskLevel,
            permitMode: eBrain.permitMode,
            deviceRoute: "persisted",
            loopCount: 0,
            cacheHitRate: 0,
            hostGatePercent: eBrain.hostGatePercent,
            presenceLine: factsBundle.displayPresenceLine(),
            pressureLine: factsBundle.pressureLine,
            actionLine: factsBundle.actionLine,
            riskFactorsLine: factsBundle.riskFactorsLine,
            reasonCodesLine: factsBundle.reasonCodesLine,
            courtLine: factsBundle.courtLine,
            governanceLine: factsBundle.governanceLine,
            foldChecksum: eBrain.thoughtFoldChecksum,
            updateTicketCount: eBrain.updateTicketSummaries.count,
            auditFindingCount: eBrain.guardrailFindings.count,
            activeKillSwitches: eBrain.activeKillSwitches,
            recommendedKillSwitches: eBrain.killSwitches.filter {
                !eBrain.activeKillSwitches.contains($0)
            },
            killSwitches: eBrain.killSwitches,
            sovereignVerdictLine: eBrain.sovereignVerdictLine,
            sovereignAuthorityLine: eBrain.sovereignAuthorityLine,
            sovereignAuditLine: eBrain.sovereignAuditLine,
            versionTreeLine: factsBundle.versionTreeLine,
            retractionLine: factsBundle.retractionLine,
            inspectionHeadline: "\(factsBundle.runtimeSummaryLine) • \(approvalState.rawValue)",
            blockers: diffSummary,
            layerStackLines: factsBundle.layerStackLines,
            checkpointID: checkpointID,
            checkpointApprovalState: approvalState.rawValue,
            checkpointRollbackReady: rollbackReady,
            checkpointApplyReady: hasBrainStateSnapshot,
            executionCapabilityFrame: eBrain.executionCapability?.executionCapabilityFrame,
            morphGraph: eBrain.morphGraph,
            hotColdMap: eBrain.hotColdMap,
            precisionProfile: eBrain.precisionProfile,
            lungState: eBrain.lungState,
            thermalExchange: eBrain.thermalExchange,
            breathScheduler: eBrain.breathScheduler,
            organPackages: eBrain.organPackages,
            organDeltaPlan: eBrain.organDeltaPlan,
            resumeFrame: eBrain.resumeFrame,
            rollbackAnchor: eBrain.rollbackAnchor,
            sovereignBridgeResult: eBrain.sovereignBridgeResult
        )
    }
}

struct DecisionSystemSessionEngineSummary: Equatable, Sendable {
    let layerPlacement: DecisionSessionLayerPlacement
    let sessions: Int
    let activeSessions: Int
    let stalledSessions: Int
    let mergeReadySessions: Int
    let mergeableBranches: Int
    let branches: Int
    let checkpoints: Int
    let events: Int
    let steps: Int
    let activeSession: DecisionSessionRuntimeInspectionSession?
    let recentSessions: [DecisionSessionRuntimeInspectionSession]
    let headline: String
    let signalBreakdown: DecisionSessionSummarySignalBreakdown
    let pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?

    var signals: [String] {
        signalBreakdown.allSignals
    }

    init(
        layerPlacement: DecisionSessionLayerPlacement,
        sessions: Int,
        activeSessions: Int,
        stalledSessions: Int,
        mergeReadySessions: Int = 0,
        mergeableBranches: Int = 0,
        branches: Int,
        checkpoints: Int,
        events: Int,
        steps: Int,
        activeSession: DecisionSessionRuntimeInspectionSession?,
        recentSessions: [DecisionSessionRuntimeInspectionSession],
        headline: String,
        signals: [String] = [],
        signalBreakdown: DecisionSessionSummarySignalBreakdown? = nil,
        pendingImportPreview: DecisionSessionEngineImportPreviewPresentation? = nil
    ) {
        let resolvedSignalBreakdown = signalBreakdown
            ?? DecisionSessionSummarySignalBreakdown.legacy(signals)
        self.layerPlacement = layerPlacement
        self.sessions = sessions
        self.activeSessions = activeSessions
        self.stalledSessions = stalledSessions
        self.mergeReadySessions = mergeReadySessions
        self.mergeableBranches = mergeableBranches
        self.branches = branches
        self.checkpoints = checkpoints
        self.events = events
        self.steps = steps
        self.activeSession = activeSession
        self.recentSessions = recentSessions
        self.headline = headline
        self.signalBreakdown = resolvedSignalBreakdown
        self.pendingImportPreview = pendingImportPreview
    }
}

extension DecisionSystemSessionEngineSummary {
    private static func summary(
        layerPlacement: DecisionSessionLayerPlacement,
        sessions: Int,
        activeSessions: Int,
        stalledSessions: Int,
        mergeReadySessions: Int,
        mergeableBranches: Int,
        branches: Int,
        checkpoints: Int,
        events: Int,
        steps: Int,
        recentSessions: [DecisionSessionRuntimeInspectionSession],
        headline: String,
        pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?
    ) -> DecisionSystemSessionEngineSummary {
        DecisionSystemSessionEngineSummary(
            layerPlacement: layerPlacement,
            sessions: sessions,
            activeSessions: activeSessions,
            stalledSessions: stalledSessions,
            mergeReadySessions: mergeReadySessions,
            mergeableBranches: mergeableBranches,
            branches: branches,
            checkpoints: checkpoints,
            events: events,
            steps: steps,
            activeSession: recentSessions.first,
            recentSessions: recentSessions,
            headline: headline,
            signalBreakdown: DecisionSessionSummaryPresentationSupport.summarySignalBreakdown(
                layerPlacement: layerPlacement,
                sessions: sessions,
                activeSessions: activeSessions,
                stalledSessions: stalledSessions,
                mergeReadySessions: mergeReadySessions,
                mergeableBranches: mergeableBranches,
                branches: branches,
                checkpoints: checkpoints,
                events: events,
                steps: steps,
                recentSessions: recentSessions,
                pendingImportPreview: pendingImportPreview
            ),
            pendingImportPreview: pendingImportPreview
        )
    }

    private static func recentSessions(
        runtimeSnapshot: DecisionSessionRuntimeSnapshot?,
        inspectionBySessionID: [String: DecisionSessionRuntimeInspectionSession]
    ) -> [DecisionSessionRuntimeInspectionSession] {
        if let runtimeSnapshot {
            return runtimeSnapshot.recentSessions
        }
        return inspectionBySessionID.values.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func effectiveMergeCounts(
        runtimeSnapshot: DecisionSessionRuntimeSnapshot?,
        recentSessions: [DecisionSessionRuntimeInspectionSession]
    ) -> (mergeReadySessions: Int, mergeableBranches: Int) {
        let derivedMergeReadySessions = recentSessions.filter { $0.mergeableBranchCount > 0 }.count
        let derivedMergeableBranches = recentSessions.reduce(into: 0) { $0 += $1.mergeableBranchCount }

        return (
            max(runtimeSnapshot?.mergeReadySessions ?? 0, derivedMergeReadySessions),
            max(runtimeSnapshot?.mergeableBranches ?? 0, derivedMergeableBranches)
        )
    }

    static func runtimeSummary(
        from snapshot: DecisionSessionRuntimeSnapshot,
        pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?
    ) -> DecisionSystemSessionEngineSummary {
        summary(
            layerPlacement: snapshot.layerPlacement,
            sessions: snapshot.sessions,
            activeSessions: snapshot.activeSessions,
            stalledSessions: snapshot.stalledSessions,
            mergeReadySessions: snapshot.mergeReadySessions,
            mergeableBranches: snapshot.mergeableBranches,
            branches: snapshot.branches,
            checkpoints: snapshot.checkpoints,
            events: snapshot.events,
            steps: snapshot.steps,
            recentSessions: snapshot.recentSessions,
            headline: DecisionSessionSummaryPresentationSupport.runtimeHeadline(
                layerPlacement: snapshot.layerPlacement
            ),
            pendingImportPreview: pendingImportPreview
        )
    }

    static func pendingImportSummary(
        for preview: DecisionSessionEngineImportPreviewPresentation
    ) -> DecisionSystemSessionEngineSummary {
        summary(
            layerPlacement: .foldedLung,
            sessions: 0,
            activeSessions: 0,
            stalledSessions: 0,
            mergeReadySessions: 0,
            mergeableBranches: 0,
            branches: 0,
            checkpoints: 0,
            events: 0,
            steps: 0,
            recentSessions: [],
            headline: DecisionSessionSummaryPresentationSupport.pendingImportHeadline(),
            pendingImportPreview: preview
        )
    }

    static func controlCenterSummary(
        runtimeSnapshot: DecisionSessionRuntimeSnapshot?,
        inspectionBySessionID: [String: DecisionSessionRuntimeInspectionSession],
        pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?
    ) -> DecisionSystemSessionEngineSummary {
        let recentSessions = recentSessions(
            runtimeSnapshot: runtimeSnapshot,
            inspectionBySessionID: inspectionBySessionID
        )
        let inspectionAggregate = DecisionSessionSummaryPresentationSupport.inspectionAggregate(
            sessions: recentSessions
        )
        let mergeCounts = effectiveMergeCounts(
            runtimeSnapshot: runtimeSnapshot,
            recentSessions: recentSessions
        )

        return summary(
            layerPlacement: runtimeSnapshot?.layerPlacement ?? .foldedLung,
            sessions: runtimeSnapshot?.sessions ?? inspectionAggregate.sessions,
            activeSessions: runtimeSnapshot?.activeSessions ?? inspectionAggregate.activeSessions,
            stalledSessions: runtimeSnapshot?.stalledSessions ?? inspectionAggregate.stalledSessions,
            mergeReadySessions: mergeCounts.mergeReadySessions,
            mergeableBranches: mergeCounts.mergeableBranches,
            branches: runtimeSnapshot?.branches ?? inspectionAggregate.branches,
            checkpoints: runtimeSnapshot?.checkpoints ?? inspectionAggregate.checkpoints,
            events: runtimeSnapshot?.events ?? 0,
            steps: runtimeSnapshot?.steps ?? 0,
            recentSessions: recentSessions,
            headline: DecisionSessionControlPresentationSupport.summaryHeadline,
            pendingImportPreview: pendingImportPreview
        )
    }

}

struct DecisionSystemLocalModelLibrarySummary: Equatable, Sendable {
    let preferredProvider: DecisionModelProviderPreference
    let importedGemmaCount: Int
    let hasBundledGemmaAsset: Bool
    let preferredGemmaAssetID: String?
    let preferredGemmaAssetFileName: String?
    let openModelSlotTitle: String?
    let openModelSlotStableID: String?
    let openModelRuntimeTitle: String?
    let openModelRuntimeMode: OpenModelLocalRuntimeMode?
    let openModelRuntimeAssetFileName: String?
    let preferredLine: String
    let bundledLine: String
    let openModelSlotLine: String
    let openModelRuntimeLine: String
    let openModelAssetLine: String
    let headline: String

    var signals: [String] {
        [
            preferredLine,
            bundledLine,
            openModelSlotLine,
            openModelRuntimeLine,
            openModelAssetLine
        ]
    }

    var runtimeLayerSignals: [String] {
        [headline, preferredLine]
    }

    var dataLayerSignals: [String] {
        [
            bundledLine,
            openModelSlotLine,
            openModelRuntimeLine,
            openModelAssetLine
        ]
    }

    var deliveryLayerSignals: [String] {
        [openModelSlotLine]
    }

    var overviewLine: String {
        headline
    }

    static func summary(
        from snapshot: DecisionLocalModelLibrarySnapshot
    ) -> DecisionSystemLocalModelLibrarySummary {
        let bundledLine = snapshot.hasAnyGemmaAsset
            ? "Gemma assets \(snapshot.allGemmaAssets.count) • Imported \(snapshot.importedGemmaAssets.count) • Bundled \(snapshot.bundledGemmaAsset == nil ? 0 : 1)"
            : "No local Gemma asset is currently available."
        let preferredLine = if let preferredAsset = snapshot.preferredGemmaAsset {
            "Preferred \(snapshot.preferredProvider.title) • Gemma asset \(preferredAsset.fileName)"
        } else {
            "Preferred \(snapshot.preferredProvider.title) • Gemma asset automatic"
        }
        let openModelLine = if let openModelSlot = snapshot.openModelSlot {
            if let stableID = openModelSlot.stableID {
                "Open-model slot \(openModelSlot.title) • \(stableID)"
            } else {
                "Open-model slot \(openModelSlot.title)"
            }
        } else {
            "Open-model slot not registered"
        }
        let openModelRuntimeLine = if let runtimeStatus = snapshot.openModelRuntimeStatus {
            "Open-model runtime \(runtimeStatus.title) • \(snapshot.openModelRuntimeAssetFileName ?? "automatic asset")"
        } else if snapshot.openModelSlot != nil {
            "Open-model runtime waiting for imported asset"
        } else if snapshot.hasAnyOpenModelAsset {
            "Open-model runtime pending activation"
        } else {
            "Open-model runtime has no imported asset"
        }
        let openModelAssetLine = if let preferredOpenModelAsset = snapshot.preferredOpenModelAsset {
            "Open-model assets \(snapshot.importedOpenModelAssets.count) • Preferred asset \(preferredOpenModelAsset.fileName)"
        } else if snapshot.hasAnyOpenModelAsset {
            "Open-model assets \(snapshot.importedOpenModelAssets.count) • Automatic asset selection"
        } else {
            "No imported open-model asset is currently available."
        }

        return DecisionSystemLocalModelLibrarySummary(
            preferredProvider: snapshot.preferredProvider,
            importedGemmaCount: snapshot.importedGemmaAssets.count,
            hasBundledGemmaAsset: snapshot.bundledGemmaAsset != nil,
            preferredGemmaAssetID: snapshot.preferredGemmaAssetID,
            preferredGemmaAssetFileName: snapshot.preferredGemmaAsset?.fileName,
            openModelSlotTitle: snapshot.openModelSlot?.title,
            openModelSlotStableID: snapshot.openModelSlot?.stableID,
            openModelRuntimeTitle: snapshot.openModelRuntimeStatus?.title ?? (snapshot.openModelSlot != nil ? "Waiting for import" : nil),
            openModelRuntimeMode: snapshot.openModelRuntimeStatus?.mode,
            openModelRuntimeAssetFileName: snapshot.openModelRuntimeAssetFileName,
            preferredLine: preferredLine,
            bundledLine: bundledLine,
            openModelSlotLine: openModelLine,
            openModelRuntimeLine: openModelRuntimeLine,
            openModelAssetLine: openModelAssetLine,
            headline: "Local model library keeps Apple default while surfacing Gemma and configurable open-model runtime slots."
        )
    }
}

struct DecisionSystemCheckpointQueueItem: Identifiable, Equatable, Sendable {
    let checkpointID: String
    let createdAt: Date
    let mode: DecisionMode
    let approvalState: String
    let rollbackReady: Bool
    let applyReady: Bool
    let hasLineage: Bool
    let primarySummary: String
    let riskLevel: String?
    let permitMode: String?
    let hostGatePercent: Int?
    let summaryText: String
    let usesSecondarySummaryTone: Bool
    let metadataText: String?
    let foldedLungTitle: String?
    let foldedLungLines: [String]
    let updateTicketSummaries: [String]
    let courtLine: String?
    let auditFindings: [String]
    let killSwitches: [String]

    var id: String { checkpointID }
}

enum DecisionSystemReleaseState: String, Equatable, Sendable {
    case ready
    case watch
    case blocked

    var title: String {
        rawValue.capitalized
    }
}

struct DecisionSystemReleaseControlSummary: Equatable, Sendable {
    let state: DecisionSystemReleaseState
    let headline: String
    let reasons: [String]
    let activeKillSwitches: [String]
    let recommendedKillSwitches: [String]
    let killSwitches: [String]
    let pendingReviewCount: Int
    let rollbackReadyCount: Int
    let canRestoreActiveCheckpoint: Bool
    let canRollbackActiveCheckpoint: Bool
    let activeCheckpointID: String?
    let activeCheckpointSource: DecisionEvolutionActiveCheckpointSource
    let reviewCheckpointID: String?
    let presenceLine: String?
    let primaryBlocker: DecisionEvolutionPrimaryBlocker?

    init(
        state: DecisionSystemReleaseState,
        headline: String,
        reasons: [String],
        activeKillSwitches: [String],
        recommendedKillSwitches: [String],
        killSwitches: [String],
        pendingReviewCount: Int,
        rollbackReadyCount: Int,
        canRestoreActiveCheckpoint: Bool,
        canRollbackActiveCheckpoint: Bool,
        activeCheckpointID: String?,
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource,
        reviewCheckpointID: String?,
        presenceLine: String? = nil,
        primaryBlocker: DecisionEvolutionPrimaryBlocker? = nil
    ) {
        self.state = state
        self.headline = headline
        self.reasons = reasons
        self.activeKillSwitches = activeKillSwitches
        self.recommendedKillSwitches = recommendedKillSwitches
        self.killSwitches = killSwitches
        self.pendingReviewCount = pendingReviewCount
        self.rollbackReadyCount = rollbackReadyCount
        self.canRestoreActiveCheckpoint = canRestoreActiveCheckpoint
        self.canRollbackActiveCheckpoint = canRollbackActiveCheckpoint
        self.activeCheckpointID = activeCheckpointID
        self.activeCheckpointSource = activeCheckpointSource
        self.reviewCheckpointID = reviewCheckpointID
        self.presenceLine = presenceLine
        self.primaryBlocker = primaryBlocker
    }
}

struct DecisionSystemFlightDeck: Equatable, Sendable {
    let generatedAt: Date
    let overallScore: Int
    let overallHealth: DecisionSystemLayerHealth
    let layerReports: [DecisionSystemLayerReport]
    let sessionEngineSummary: DecisionSystemSessionEngineSummary?
    let localModelLibrarySummary: DecisionSystemLocalModelLibrarySummary?
    let isPureLocalClosedLoop: Bool
    let dominantBlockers: [String]
    let eBrainSummary: DecisionSystemEBrainSummary?
    let releaseControlSummary: DecisionSystemReleaseControlSummary
    let evolutionControlSurface: DecisionEvolutionControlSurface
    let pendingReviewCheckpointCount: Int
    let pendingReviewQueue: [DecisionSystemCheckpointQueueItem]

    var sessionEnginePresentation: DecisionSessionEnginePresentation {
        DecisionSessionEnginePresentation.build(from: sessionEngineSummary)
    }

    var eBrainDigestPresentation: DecisionSystemFlightDeckEBrainDigestPresentation? {
        guard let eBrainSummary else {
            return nil
        }

        let summaryPresentation = eBrainSummary.presentation
        let digestPresentation = eBrainSummary.digestPresentation
        let operationsLine = "Audit \(eBrainSummary.auditFindingCount) • Active kill switches \(releaseControlSummary.activeKillSwitches.count) • Recommended \(releaseControlSummary.recommendedKillSwitches.count) • Host gate \(eBrainSummary.hostGatePercent)%"
        let summaryLines = DecisionSystemFlightDeckBuilder.removingLayerStackSignals(
            from: DecisionSystemFlightDeckEBrainDigestPresentation.uniqueLines(
                [operationsLine]
                + Array(summaryPresentation.detailLines.dropFirst()).map(Optional.some)
            ),
            layerStackLines: summaryPresentation.layerStackLines
        )
        return DecisionSystemFlightDeckEBrainDigestPresentation(
            digest: DecisionEvolutionEBrainDigestPresentation(
                sourceDescriptor: digestPresentation.sourceDescriptor,
                compactStatusLine: digestPresentation.compactStatusLine,
                taskTitle: digestPresentation.taskTitle,
                operationsLine: operationsLine
            ),
            statusLine: summaryPresentation.statusLine,
            routeLine: summaryPresentation.routeLine,
            presenceLine: summaryPresentation.presenceLine,
            pressureLine: summaryPresentation.pressureLine,
            actionLine: summaryPresentation.actionLine,
            hostLine: summaryPresentation.hostLine,
            inspectionHeadline: summaryPresentation.inspectionHeadline,
            primaryGuardrailText: summaryPresentation.primaryGuardrailText,
            detailLines: summaryPresentation.detailLines,
            summaryLines: summaryLines,
            alertLine: summaryPresentation.alertLine,
            layerStackLines: summaryPresentation.layerStackLines
        )
    }
}

extension Optional where Wrapped == DecisionSystemFlightDeck {
    var sessionEnginePresentationOrUnattached: DecisionSessionEnginePresentation {
        self?.sessionEnginePresentation ?? .unattached
    }
}

enum DecisionSystemFlightDeckBuilder {
    private static let layerStackTrimCharacters = CharacterSet(charactersIn: " •")
        .union(.whitespacesAndNewlines)

    static func build(
        from export: DecisionTestingRuntimeExport,
        eBrainTurn: BASEBrainTurnResult? = nil
    ) -> DecisionSystemFlightDeck {
        let compilation = export.basFlightDeckCompilation
        let pendingImportPreview = export.pendingSessionEngineImportPreview?.presentation
        let sessionEngineSummary: DecisionSystemSessionEngineSummary? = if let sessionEngineSnapshot = export.sessionEngineSnapshot {
            DecisionSystemSessionEngineSummary.runtimeSummary(
                from: sessionEngineSnapshot,
                pendingImportPreview: pendingImportPreview
            )
        } else if let pendingImportPreview {
            DecisionSystemSessionEngineSummary.pendingImportSummary(for: pendingImportPreview)
        } else {
            nil
        }
        let localModelLibrarySummary = DecisionSystemLocalModelLibrarySummary.summary(
            from: export.runtimeSnapshot.localModelLibrary
        )
        let evolutionRuntimeFacts = export.evolutionRuntimeFacts(currentBrainState: nil)
        let reports = augment(
            reports: compilation.layerReports.map(layerReport(from:)),
            sessionEngineSummary: sessionEngineSummary,
            localModelLibrarySummary: localModelLibrarySummary,
            effectiveEBrainFactsBundle: evolutionRuntimeFacts.effectiveEBrainFactsBundle
        )
        let resolvedTurn = eBrainTurn ?? export.eBrainTurn
        let evolutionControlSurface = export.evolutionControlSurface
        let resolvedSummary = resolvedTurn.map(summary(from:))
            ?? evolutionControlSurface.latestPersistedLineage.map(summary(from:))
        let surfacedSummary = resolvedSummary.map { summary in
            let resolvedExecutionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? =
                summary.executionCapabilityFrame
                ?? {
                    if resolvedTurn != nil, summary.source == .liveRuntime {
                        return export.executionCapabilityFrame
                    }

                    if let persistedSessionCheckpointExecutionCapabilityFrame = export.persistedSessionCheckpointExecutionCapabilityFrame {
                        return persistedSessionCheckpointExecutionCapabilityFrame
                    }

                    return export.executionCapabilityFrame
                }()

            guard let resolvedExecutionCapabilityFrame else {
                return summary
            }

            return summary.applying(
                executionCapabilityFrame: resolvedExecutionCapabilityFrame
            )
        }
        let releaseControlSummary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: evolutionControlSurface,
            eBrainSummary: surfacedSummary,
            dominantBlockers: compilation.dominantBlockers,
            activeKillSwitches: evolutionRuntimeFacts.effectiveActiveKillSwitches,
            recommendedKillSwitchesHint: evolutionRuntimeFacts.recommendedKillSwitches
        )

        return DecisionSystemFlightDeck(
            generatedAt: compilation.generatedAt,
            overallScore: compilation.overallScore,
            overallHealth: DecisionSystemLayerHealth(rawValue: compilation.overallHealthID) ?? .watch,
            layerReports: reports,
            sessionEngineSummary: sessionEngineSummary,
            localModelLibrarySummary: localModelLibrarySummary,
            isPureLocalClosedLoop: compilation.isPureLocalClosedLoop,
            dominantBlockers: compilation.dominantBlockers,
            eBrainSummary: surfacedSummary,
            releaseControlSummary: releaseControlSummary,
            evolutionControlSurface: evolutionControlSurface,
            pendingReviewCheckpointCount: evolutionControlSurface.pendingReviewCount,
            pendingReviewQueue: evolutionControlSurface.pendingReviewPresentations
                .prefix(3)
                .map(\.queueItem)
        )
    }

    private static func layerReport(
        from report: BASAppleFlightDeckLayerReport
    ) -> DecisionSystemLayerReport {
        let layer = DecisionSystemLayer(rawValue: report.layerID) ?? .observability
        return DecisionSystemLayerReport(
            layer: layer,
            score: report.score,
            health: DecisionSystemLayerHealth(rawValue: report.healthID) ?? .watch,
            headline: report.headline,
            signals: report.signals,
            blockers: report.blockers
        )
    }

    private static func summary(from turn: BASEBrainTurnResult) -> DecisionSystemEBrainSummary {
        turn.systemFlightDeckSummary
    }

    private static func summary(
        from lineage: DecisionEvolutionLineageSnapshot
    ) -> DecisionSystemEBrainSummary {
        lineage.systemFlightDeckSummary
    }

    private static func augment(
        reports: [DecisionSystemLayerReport],
        sessionEngineSummary: DecisionSystemSessionEngineSummary?,
        localModelLibrarySummary: DecisionSystemLocalModelLibrarySummary?,
        effectiveEBrainFactsBundle: DecisionEvolutionEBrainFactsBundle?
    ) -> [DecisionSystemLayerReport] {
        return reports.map { report in
            switch report.layer {
            case .runtime:
                let runtimeSignals =
                    (sessionEngineSummary.map {
                        DecisionSessionSummaryPresentationSupport.runtimeLayerSignals(summary: $0)
                    } ?? [])
                    + (localModelLibrarySummary?.runtimeLayerSignals ?? [])
                return DecisionSystemLayerReport(
                    layer: report.layer,
                    score: report.score,
                    health: report.health,
                    headline: report.headline,
                    signals: orderedUnique(report.signals + runtimeSignals),
                    blockers: report.blockers
                )
            case .data:
                let eBrainFactSignals = effectiveEBrainFactsBundle?.dataLayerSignals ?? []
                let dataSignals =
                    (sessionEngineSummary.map {
                        DecisionSessionSummaryPresentationSupport.dataLayerSignals(summary: $0)
                    } ?? [])
                    + eBrainFactSignals
                    + (localModelLibrarySummary?.dataLayerSignals ?? [])
                return DecisionSystemLayerReport(
                    layer: report.layer,
                    score: report.score,
                    health: report.health,
                    headline: report.headline,
                    signals: removingLayerStackSignals(
                        from: report.signals + dataSignals,
                        layerStackLines: effectiveEBrainFactsBundle?.layerStackLines ?? []
                    ),
                    blockers: report.blockers
                )
            case .delivery:
                let deliverySignals = localModelLibrarySummary?.deliveryLayerSignals ?? []
                return DecisionSystemLayerReport(
                    layer: report.layer,
                    score: report.score,
                    health: report.health,
                    headline: report.headline,
                    signals: orderedUnique(report.signals + deliverySignals),
                    blockers: report.blockers
                )
            default:
                return report
            }
        }
    }

    fileprivate static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }

    static func removingLayerStackSignals(
        from values: [String],
        layerStackLines: [String]
    ) -> [String] {
        let normalizedValues = values.compactMap(normalizedSignal)
        let normalizedLayerStackLines = layerStackLines.compactMap(normalizedSignal)
        guard !normalizedLayerStackLines.isEmpty else {
            return orderedUnique(normalizedValues)
        }

        let exactLayerSignals = Set(normalizedLayerStackLines)
        let joinedLayerSignal = normalizedLayerStackLines.joined(separator: " | ")
        let layerMarkers = Set(normalizedLayerStackLines.compactMap(layerMarker))

        return orderedUnique(
            normalizedValues.filter { signal in
                if exactLayerSignals.contains(signal) || signal == joinedLayerSignal {
                    return false
                }

                return !layerMarkers.contains(where: { marker in
                    signal == marker
                        || signal.hasPrefix("\(marker) •")
                        || signal.hasPrefix("\(marker):")
                })
            }
        )
    }

    private static func layerMarker(_ value: String) -> String? {
        guard let normalized = normalizedSignal(value) else {
            return nil
        }

        let firstSegment = normalized.components(separatedBy: " • ").first ?? normalized
        let marker = firstSegment
            .components(separatedBy: ":")
            .first?
            .trimmingCharacters(in: layerStackTrimCharacters)

        return marker?.isEmpty == false ? marker : nil
    }

    private static func normalizedSignal(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: layerStackTrimCharacters)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

}
