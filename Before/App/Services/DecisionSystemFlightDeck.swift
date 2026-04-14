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
    let hostLine: String
    let inspectionHeadline: String
    let primaryGuardrailText: String?
}

extension DecisionSystemEBrainSummary {
    var presentation: DecisionSystemEBrainSummaryPresentation {
        DecisionSystemEBrainSummaryPresentation(
            sourceDescriptor: sourceDescriptor,
            statusLine: "\(runMode.uppercased()) • \(taskType.replacingOccurrences(of: "_", with: " ")) • \(riskLevel.uppercased()) → \(permitMode.uppercased())",
            routeLine: "Route \(deviceRoute) • Loops \(loopCount) • Cache \(cacheHitRate)% • Tickets \(updateTicketCount)",
            hostLine: "Host gate \(hostGatePercent)% • Fold \(foldChecksum) • Audit \(auditFindingCount)",
            inspectionHeadline: inspectionHeadline,
            primaryGuardrailText: blockers.first.map { "Guardrail: \($0)" }
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
    let signals: [String]
    let pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?

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
        signals: [String],
        pendingImportPreview: DecisionSessionEngineImportPreviewPresentation? = nil
    ) {
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
        self.signals = signals
        self.pendingImportPreview = pendingImportPreview
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
    let headline: String
    let signals: [String]
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
            summary(
                from: sessionEngineSnapshot,
                pendingImportPreview: pendingImportPreview
            )
        } else if let pendingImportPreview {
            summary(forPendingImportPreview: pendingImportPreview)
        } else {
            nil
        }
        let localModelLibrarySummary = summary(from: export.runtimeSnapshot.localModelLibrary)
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
        let inspection = BASEBrainConsoleSupport.inspectionBundle(for: turn)

        return DecisionSystemEBrainSummary(
            source: .liveRuntime,
            runMode: turn.budgetFrame.runMode.rawValue,
            taskType: turn.contextFrame.taskType.rawValue,
            riskLevel: turn.riskCard.riskLevel.rawValue,
            permitMode: turn.actionPermit.mode.rawValue,
            deviceRoute: turn.runtimeTrace.modelRoute,
            loopCount: turn.runtimeTrace.loopCount,
            cacheHitRate: Int((turn.runtimeTrace.cacheHitRate * 100).rounded()),
            hostGatePercent: Int((turn.hostGateValue * 100).rounded()),
            foldChecksum: String(turn.thoughtFold.checksum.prefix(12)),
            updateTicketCount: turn.updateTickets.count,
            auditFindingCount: turn.runtimeTrace.guardrailFindings.count,
            activeKillSwitches: turn.runtimeTrace.activeKillSwitches.map(\.rawValue),
            recommendedKillSwitches: turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue),
            killSwitches: orderedUnique(
                turn.runtimeTrace.activeKillSwitches.map(\.rawValue)
                + turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue)
            ),
            inspectionHeadline: inspection.summary,
            blockers: inspection.blockerSummary,
            checkpointID: nil,
            checkpointApprovalState: nil,
            checkpointRollbackReady: nil,
            checkpointApplyReady: nil
        )
    }

    private static func summary(
        from lineage: DecisionEvolutionLineageSnapshot
    ) -> DecisionSystemEBrainSummary {
        let factsBundle = lineage.eBrain.factsBundle(modeTitle: lineage.mode.shortTitle)
        return DecisionSystemEBrainSummary(
            source: lineage.eBrain.source == .liveRuntime ? .liveRuntime : .persistedCheckpoint,
            runMode: "checkpoint",
            taskType: lineage.eBrain.taskType,
            riskLevel: lineage.eBrain.riskLevel,
            permitMode: lineage.eBrain.permitMode,
            deviceRoute: "persisted",
            loopCount: 0,
            cacheHitRate: 0,
            hostGatePercent: lineage.eBrain.hostGatePercent,
            foldChecksum: lineage.eBrain.thoughtFoldChecksum,
            updateTicketCount: lineage.eBrain.updateTicketSummaries.count,
            auditFindingCount: lineage.eBrain.guardrailFindings.count,
            activeKillSwitches: lineage.eBrain.activeKillSwitches,
            recommendedKillSwitches: lineage.eBrain.killSwitches.filter {
                !lineage.eBrain.activeKillSwitches.contains($0)
            },
            killSwitches: lineage.eBrain.killSwitches,
            inspectionHeadline: "\(factsBundle.runtimeSummaryLine) • \(lineage.approvalState.rawValue)",
            blockers: lineage.diffSummary,
            checkpointID: lineage.checkpointID,
            checkpointApprovalState: lineage.approvalState.rawValue,
            checkpointRollbackReady: lineage.rollbackReady,
            checkpointApplyReady: lineage.hasBrainStateSnapshot
        )
    }

    private static func summary(
        from snapshot: DecisionSessionRuntimeSnapshot,
        pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?
    ) -> DecisionSystemSessionEngineSummary {
        DecisionSystemSessionEngineSummary(
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
            activeSession: snapshot.recentSessions.first,
            recentSessions: snapshot.recentSessions,
            headline: "Session Engine \(snapshot.layerPlacement.rawValue) protects edits, checkpoints, and recovery.",
            signals: [
                "Session Engine \(snapshot.layerPlacement.rawValue) • Sessions \(snapshot.sessions) • Active \(snapshot.activeSessions) • Stalled \(snapshot.stalledSessions)",
                "Branches \(snapshot.branches) • Merge-ready sessions \(snapshot.mergeReadySessions) • Merge-ready branches \(snapshot.mergeableBranches)",
                "Checkpoints \(snapshot.checkpoints) • Events \(snapshot.events) • Steps \(snapshot.steps)"
            ] + pendingImportSignals(for: pendingImportPreview)
                + replayRecoverySignals(for: snapshot.recentSessions)
                + checkpointDigestSignals(for: snapshot.recentSessions)
                + snapshot.recentSessions.prefix(2).map { session in
                let checkpointDescriptor = session.latestCheckpointID.map { "Checkpoint \($0)" } ?? "Checkpoint none"
                let recoveryDescriptor = if let latestRecoveryAt = session.latestRecoveryAt {
                    "Recovered \(latestRecoveryAt.formatted(date: .omitted, time: .shortened))"
                } else {
                    "Recoveries \(session.recoveryCount)"
                }
                let stepDescriptor = session.openStepAlertLine
                    ?? session.openStepFreshnessLine
                    ?? "Open steps \(session.openStepCount)"
                let mergeDescriptor = session.mergeReviewLine ?? "Merge review 0"
                return "\(session.headline) • \(checkpointDescriptor) • \(recoveryDescriptor) • \(stepDescriptor) • \(mergeDescriptor)"
            },
            pendingImportPreview: pendingImportPreview
        )
    }

    private static func summary(
        forPendingImportPreview preview: DecisionSessionEngineImportPreviewPresentation
    ) -> DecisionSystemSessionEngineSummary {
        DecisionSystemSessionEngineSummary(
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
            activeSession: nil,
            recentSessions: [],
            headline: "Session Engine folded_lung has a pending import draft ready for review before local recovery state is attached.",
            signals: pendingImportSignals(for: preview),
            pendingImportPreview: preview
        )
    }

    private static func pendingImportSignals(
        for preview: DecisionSessionEngineImportPreviewPresentation?
    ) -> [String] {
        guard let preview else { return [] }
        return [
            "Pending import • \(preview.bundleLine) • \(preview.importedLine)",
            "\(preview.unfinishedWorkSummary.title) • \(preview.countsLine)"
        ]
    }

    private static func replayRecoverySignals(
        for sessions: [DecisionSessionRuntimeInspectionSession]
    ) -> [String] {
        sessions.prefix(2).flatMap { session in
            let presentation = session.replayRecoverySummary
            return [
                "\(presentation.title) • \(presentation.replayLine) • \(presentation.recoveryLine)",
                "\(presentation.detailLine)\(presentation.killSwitchesLine.map { " • \($0)" } ?? "")"
            ]
        }
    }

    private static func checkpointDigestSignals(
        for sessions: [DecisionSessionRuntimeInspectionSession]
    ) -> [String] {
        sessions.prefix(2).flatMap { session in
            var signals: [String] = []

            let budgetLine = [session.latestCheckpointBudgetLine, session.latestCheckpointRouteLine]
                .compactMap { $0 }
                .joined(separator: " • ")

            if budgetLine.isEmpty == false {
                signals.append("\(session.title) • \(budgetLine)")
            }

            if let decisionLine = session.latestCheckpointDecisionLine {
                let taskSuffix = session.latestCheckpointTaskLine.map { " • \($0)" } ?? ""
                signals.append("\(session.title) • \(decisionLine)\(taskSuffix)")
            } else if let taskLine = session.latestCheckpointTaskLine {
                signals.append("\(session.title) • \(taskLine)")
            }

            if let actionLine = session.latestCheckpointActionLine {
                signals.append("\(session.title) • \(actionLine)")
            }

            return signals
        }
    }

    private static func summary(
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
            headline: "Local model library keeps Apple default while surfacing Gemma and configurable open-model runtime slots.",
            signals: [
                preferredLine,
                bundledLine,
                openModelLine,
                openModelRuntimeLine,
                openModelAssetLine
            ]
        )
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
                let runtimeSignals = [
                    sessionEngineSummary?.headline,
                    sessionEngineSummary?.signals.first,
                    localModelLibrarySummary?.headline,
                    localModelLibrarySummary?.signals.first
                ].compactMap { $0 }
                return DecisionSystemLayerReport(
                    layer: report.layer,
                    score: report.score,
                    health: report.health,
                    headline: report.headline,
                    signals: orderedUnique(report.signals + runtimeSignals),
                    blockers: report.blockers
                )
            case .data:
                let reviewSignals = sessionEngineSummary.map {
                    DecisionSessionEngineReviewDigestBuilder.build(from: $0).map {
                        "\($0.title) • \($0.detail)"
                    }
                } ?? []
                let eBrainFactSignals = [
                    effectiveEBrainFactsBundle?.summaryLine,
                    effectiveEBrainFactsBundle?.budgetLine,
                    effectiveEBrainFactsBundle?.taskLine,
                    effectiveEBrainFactsBundle?.auditLine,
                    effectiveEBrainFactsBundle?.activeKillSwitchesLine,
                    effectiveEBrainFactsBundle?.killSwitchesLine
                ].compactMap { $0 }
                let dataSignals =
                    (sessionEngineSummary.map { Array($0.signals.dropFirst()) } ?? [])
                    + reviewSignals
                    + eBrainFactSignals
                    + (localModelLibrarySummary.map { Array($0.signals.dropFirst()) } ?? [])
                return DecisionSystemLayerReport(
                    layer: report.layer,
                    score: report.score,
                    health: report.health,
                    headline: report.headline,
                    signals: orderedUnique(report.signals + dataSignals),
                    blockers: report.blockers
                )
            case .delivery:
                let deliverySignals = [
                    localModelLibrarySummary?.signals.dropFirst(2).first
                ].compactMap { $0 }
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

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }

}
