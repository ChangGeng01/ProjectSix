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
    let killSwitches: [String]
    let inspectionHeadline: String
    let blockers: [String]
    let checkpointID: String?
    let checkpointApprovalState: String?
    let checkpointRollbackReady: Bool?
    let checkpointApplyReady: Bool?
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
    let killSwitches: [String]
    let pendingReviewCount: Int
    let rollbackReadyCount: Int
    let canRestoreActiveCheckpoint: Bool
    let canRollbackActiveCheckpoint: Bool
    let activeCheckpointID: String?
    let reviewCheckpointID: String?
}

struct DecisionSystemFlightDeck: Equatable, Sendable {
    let generatedAt: Date
    let overallScore: Int
    let overallHealth: DecisionSystemLayerHealth
    let layerReports: [DecisionSystemLayerReport]
    let isPureLocalClosedLoop: Bool
    let dominantBlockers: [String]
    let eBrainSummary: DecisionSystemEBrainSummary?
    let releaseControlSummary: DecisionSystemReleaseControlSummary
    let evolutionControlSurface: DecisionEvolutionControlSurface
    let pendingReviewCheckpointCount: Int
    let pendingReviewQueue: [DecisionSystemCheckpointQueueItem]
}

enum DecisionSystemFlightDeckBuilder {
    static func build(
        from export: DecisionTestingRuntimeExport,
        eBrainTurn: BASEBrainTurnResult? = nil
    ) -> DecisionSystemFlightDeck {
        let compilation = export.basFlightDeckCompilation
        let reports = compilation.layerReports.map(layerReport(from:))
        let resolvedTurn = eBrainTurn ?? export.eBrainTurn
        let evolutionControlSurface = export.evolutionControlSurface
        let resolvedSummary = resolvedTurn.map(summary(from:))
            ?? evolutionControlSurface.latestPersistedLineage.map(summary(from:))
        let releaseControlSummary = releaseSummary(
            evolutionControlSurface: evolutionControlSurface,
            eBrainSummary: resolvedSummary,
            dominantBlockers: compilation.dominantBlockers
        )

        return DecisionSystemFlightDeck(
            generatedAt: compilation.generatedAt,
            overallScore: compilation.overallScore,
            overallHealth: DecisionSystemLayerHealth(rawValue: compilation.overallHealthID) ?? .watch,
            layerReports: reports,
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
            killSwitches: turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue),
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
        DecisionSystemEBrainSummary(
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
            killSwitches: lineage.eBrain.killSwitches,
            inspectionHeadline: "Recovered from \(lineage.mode.shortTitle) checkpoint • \(lineage.approvalState.rawValue)",
            blockers: lineage.diffSummary,
            checkpointID: lineage.checkpointID,
            checkpointApprovalState: lineage.approvalState.rawValue,
            checkpointRollbackReady: lineage.rollbackReady,
            checkpointApplyReady: lineage.hasBrainStateSnapshot
        )
    }

    private static func releaseSummary(
        evolutionControlSurface: DecisionEvolutionControlSurface,
        eBrainSummary: DecisionSystemEBrainSummary?,
        dominantBlockers: [String]
    ) -> DecisionSystemReleaseControlSummary {
        let blockerSignals = eBrainSummary?.source == .persistedCheckpoint ? [] : dominantBlockers
        let killSwitches = orderedUnique(
            activeKillSwitches(
                from: eBrainSummary,
                controlSurface: evolutionControlSurface
            )
        )
        let queueAuditFindings = evolutionControlSurface.queueAuditFindings
        let queueKillSwitches = evolutionControlSurface.queueKillSwitches
        let canRestoreActiveCheckpoint = evolutionControlSurface.activePresentation?.applyReady == true
        let canRollbackActiveCheckpoint = evolutionControlSurface.canRollbackActiveCheckpoint
        let state: DecisionSystemReleaseState
        let headline: String
        var reasons: [String] = []

        if !killSwitches.isEmpty {
            state = .blocked
            headline = "Blocked by active kill switches"
            reasons.append("Kill switches are active on the current release path.")
        } else if !blockerSignals.isEmpty {
            state = .blocked
            headline = "Blocked by runtime guardrails"
            reasons.append(contentsOf: blockerSignals)
        } else if evolutionControlSurface.activePresentation == nil {
            state = .watch
            headline = "Watching for the first active checkpoint"
            reasons.append("No active checkpoint is attached to the current release path yet.")
            if evolutionControlSurface.pendingReviewCount > 0 {
                reasons.append("\(evolutionControlSurface.pendingReviewCount) checkpoint(s) still require review before promotion.")
                appendQueueSignals(
                    to: &reasons,
                    auditFindings: queueAuditFindings,
                    killSwitches: queueKillSwitches
                )
            }
        } else if !canRestoreActiveCheckpoint {
            state = .blocked
            headline = "Blocked until the active checkpoint is restorable"
            reasons.append("The active checkpoint does not currently have a restorable brain-state snapshot.")
        } else if evolutionControlSurface.pendingReviewCount > 0 {
            state = .watch
            headline = "Watching the pending review queue"
            reasons.append("\(evolutionControlSurface.pendingReviewCount) checkpoint(s) still require review.")
            appendQueueSignals(
                to: &reasons,
                auditFindings: queueAuditFindings,
                killSwitches: queueKillSwitches
            )
        } else if !evolutionControlSurface.reviewAuditFindings.isEmpty {
            state = .watch
            headline = "Watching audit findings before wider rollout"
            reasons.append(contentsOf: evolutionControlSurface.reviewAuditFindings)
        } else if !canRollbackActiveCheckpoint {
            state = .watch
            headline = "Watching rollback readiness"
            reasons.append("The active checkpoint does not currently expose a previous checkpoint for rollback.")
        } else {
            state = .ready
            headline = "Ready for guarded pilot rollout"
            if let checkpointID = evolutionControlSurface.activePresentation?.checkpointID {
                reasons.append("Active checkpoint \(checkpointID) is restorable.")
            } else {
                reasons.append("The active checkpoint is restorable.")
            }
        }

        return DecisionSystemReleaseControlSummary(
            state: state,
            headline: headline,
            reasons: reasons,
            killSwitches: killSwitches,
            pendingReviewCount: evolutionControlSurface.pendingReviewCount,
            rollbackReadyCount: evolutionControlSurface.rollbackReadyCount,
            canRestoreActiveCheckpoint: canRestoreActiveCheckpoint,
            canRollbackActiveCheckpoint: canRollbackActiveCheckpoint,
            activeCheckpointID: evolutionControlSurface.activePresentation?.checkpointID,
            reviewCheckpointID: evolutionControlSurface.reviewPresentation?.checkpointID
        )
    }

    private static func appendQueueSignals(
        to reasons: inout [String],
        auditFindings: [String],
        killSwitches: [String]
    ) {
        if !killSwitches.isEmpty {
            reasons.append("Pending review kill switches: \(killSwitches.joined(separator: " • "))")
        }

        if !auditFindings.isEmpty {
            reasons.append("Pending review findings: \(auditFindings.joined(separator: " • "))")
        }
    }

    private static func activeKillSwitches(
        from eBrainSummary: DecisionSystemEBrainSummary?,
        controlSurface: DecisionEvolutionControlSurface
    ) -> [String] {
        if eBrainSummary?.source == .liveRuntime {
            return eBrainSummary?.killSwitches ?? []
        }

        if let activeCheckpointID = controlSurface.activePresentation?.checkpointID,
           eBrainSummary?.checkpointID == activeCheckpointID {
            return eBrainSummary?.killSwitches
                ?? controlSurface.activePresentation?.killSwitches
                ?? []
        }

        return controlSurface.activePresentation?.killSwitches ?? []
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }
}
