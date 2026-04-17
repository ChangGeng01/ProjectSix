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
    let pressureLine: String?
    let foldChecksum: String
    let updateTicketCount: Int
    let auditFindingCount: Int
    let activeKillSwitches: [String]
    let recommendedKillSwitches: [String]
    let killSwitches: [String]
    let inspectionHeadline: String
    let blockers: [String]
    let checkpointID: String?
    let checkpointApprovalState: String?
    let checkpointRollbackReady: Bool?
    let checkpointApplyReady: Bool?
}

struct DecisionSystemEBrainSummaryPresentation: Equatable, Sendable {
    let sourceDescriptor: DecisionEvolutionSourceDescriptor
    let statusLine: String
    let routeLine: String
    let pressureLine: String?
    let hostLine: String
    let inspectionHeadline: String
    let primaryGuardrailText: String?
}

extension DecisionSystemEBrainSummary {
    var presentation: DecisionSystemEBrainSummaryPresentation {
        DecisionSystemEBrainSummaryPresentation(
            sourceDescriptor: sourceDescriptor,
            statusLine: "\(runMode.uppercased()) • \(taskType.replacingOccurrences(of: "_", with: " ")) • \(DecisionEvolutionEBrainPresentationSupport.riskPermitLine(riskLevel: riskLevel, permitMode: permitMode))",
            routeLine: "Route \(deviceRoute) • Loops \(loopCount) • Cache \(cacheHitRate)% • Tickets \(updateTicketCount)",
            pressureLine: pressureLine,
            hostLine: "\(DecisionEvolutionEBrainPresentationSupport.hostFoldLine(hostGatePercent: hostGatePercent, foldChecksum: foldChecksum)) • Audit \(auditFindingCount)",
            inspectionHeadline: inspectionHeadline,
            primaryGuardrailText: blockers.first.map { "Guardrail: \($0)" }
        )
    }
}

extension BASEBrainTurnResult {
    var systemFlightDeckSummary: DecisionSystemEBrainSummary {
        let inspection = BASEBrainConsoleSupport.inspectionBundle(for: self)
        let factsBundle = DeveloperDecisionReplayEBrainSummary(turn: self).factsBundle()

        return DecisionSystemEBrainSummary(
            source: .liveRuntime,
            runMode: budgetFrame.runMode.rawValue,
            taskType: contextFrame.taskType.rawValue,
            riskLevel: riskCard.riskLevel.rawValue,
            permitMode: actionPermit.mode.rawValue,
            deviceRoute: runtimeTrace.modelRoute,
            loopCount: runtimeTrace.loopCount,
            cacheHitRate: Int((runtimeTrace.cacheHitRate * 100).rounded()),
            hostGatePercent: Int((hostGateValue * 100).rounded()),
            pressureLine: factsBundle.pressureLine,
            foldChecksum: String(thoughtFold.checksum.prefix(12)),
            updateTicketCount: updateTickets.count,
            auditFindingCount: runtimeTrace.guardrailFindings.count,
            activeKillSwitches: runtimeTrace.activeKillSwitches.map(\.rawValue),
            recommendedKillSwitches: runtimeTrace.recommendedKillSwitches.map(\.rawValue),
            killSwitches: DecisionSystemFlightDeckBuilder.orderedUnique(
                runtimeTrace.activeKillSwitches.map(\.rawValue)
                + runtimeTrace.recommendedKillSwitches.map(\.rawValue)
            ),
            inspectionHeadline: inspection.summary,
            blockers: inspection.blockerSummary,
            checkpointID: nil,
            checkpointApprovalState: nil,
            checkpointRollbackReady: nil,
            checkpointApplyReady: nil
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
            pressureLine: factsBundle.pressureLine,
            foldChecksum: eBrain.thoughtFoldChecksum,
            updateTicketCount: eBrain.updateTicketSummaries.count,
            auditFindingCount: eBrain.guardrailFindings.count,
            activeKillSwitches: eBrain.activeKillSwitches,
            recommendedKillSwitches: eBrain.killSwitches.filter {
                !eBrain.activeKillSwitches.contains($0)
            },
            killSwitches: eBrain.killSwitches,
            inspectionHeadline: "\(factsBundle.runtimeSummaryLine) • \(approvalState.rawValue)",
            blockers: diffSummary,
            checkpointID: checkpointID,
            checkpointApprovalState: approvalState.rawValue,
            checkpointRollbackReady: rollbackReady,
            checkpointApplyReady: hasBrainStateSnapshot
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
    let updateTicketSummaries: [String]
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
}

extension Optional where Wrapped == DecisionSystemFlightDeck {
    var sessionEnginePresentationOrUnattached: DecisionSessionEnginePresentation {
        self?.sessionEnginePresentation ?? .unattached
    }
}

enum DecisionSystemFlightDeckBuilder {
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
        let releaseControlSummary = DecisionEvolutionReleaseSummaryBuilder.build(
            evolutionControlSurface: evolutionControlSurface,
            eBrainSummary: resolvedSummary,
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
            eBrainSummary: resolvedSummary,
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
                    signals: orderedUnique(report.signals + dataSignals),
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

}
