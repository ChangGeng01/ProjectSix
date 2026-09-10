import Foundation
import BASHostKit

struct DecisionEvolutionRuntimeAnchorResolver {
    static func selectionContext(
        for turn: BASEBrainTurnResult,
        explicitCheckpointID: String? = nil
    ) -> DecisionTestingCheckpointSelectionContext {
        DecisionTestingCheckpointSelectionContext(
            mode: turn.replayMode,
            source: .liveRuntime,
            referenceDate: turn.runtimeTrace.recordedAt,
            explicitCheckpointID: explicitCheckpointID?.evolutionTrimmedNonEmpty,
            thoughtFoldChecksum: turn.thoughtFold.checksum.evolutionTrimmedNonEmpty,
            sessionID: turn.runtimeTrace.sessionID.evolutionTrimmedNonEmpty,
            riskLevel: turn.riskCard.riskLevel.rawValue,
            permitMode: turn.actionPermit.mode.rawValue,
            hostGatePercent: Int((turn.hostGateValue * 100).rounded()),
            reviewDirectiveLine: turn.updateTickets.lazy.compactMap(\.reviewDirectiveLine).compactMap(\.evolutionTrimmedNonEmpty).first,
            rollbackAnchorID: DecisionFoldedLungCoordinator.snapshot(for: turn).rollbackAnchor.anchorID
        )
    }

    static func selectionContext(
        for anchor: DecisionSessionCheckpointEBrainAnchor,
        referenceDate: Date,
        mode: DecisionMode? = nil,
        source: DeveloperDecisionReplayEBrainSource? = nil,
        explicitCheckpointID: String? = nil
    ) -> DecisionTestingCheckpointSelectionContext {
        DecisionTestingCheckpointSelectionContext(
            mode: mode,
            source: source,
            referenceDate: referenceDate,
            explicitCheckpointID: explicitCheckpointID?.evolutionTrimmedNonEmpty,
            thoughtFoldChecksum: anchor.thoughtFoldChecksum,
            sessionID: anchor.sessionID,
            riskLevel: anchor.riskLevel,
            permitMode: anchor.permitMode,
            hostGatePercent: anchor.hostGatePercent,
            reviewDirectiveLine: anchor.reviewDirectiveLine,
            rollbackAnchorID: anchor.rollbackAnchor?.anchorID
        )
    }

    static func preferredLineage(
        in lineages: [DecisionEvolutionLineageSnapshot],
        matching context: DecisionTestingCheckpointSelectionContext
    ) -> DecisionEvolutionLineageSnapshot? {
        guard let first = lineages.first else {
            return nil
        }

        return lineages.dropFirst().reduce(first) { best, candidate in
            if isPreferred(candidate, over: best, matching: context) {
                return candidate
            }

            if isPreferred(best, over: candidate, matching: context) {
                return best
            }

            return candidate.checkpointID > best.checkpointID ? candidate : best
        }
    }

    private static func isPreferred(
        _ lhs: DecisionEvolutionLineageSnapshot,
        over rhs: DecisionEvolutionLineageSnapshot,
        matching context: DecisionTestingCheckpointSelectionContext
    ) -> Bool {
        if context.hasRuntimeAnchor {
            return isPreferredUsingRuntimeAnchor(lhs, over: rhs, matching: context)
        }

        return isPreferredUsingReplayContext(lhs, over: rhs, matching: context)
    }

    private static func isPreferredUsingRuntimeAnchor(
        _ lhs: DecisionEvolutionLineageSnapshot,
        over rhs: DecisionEvolutionLineageSnapshot,
        matching context: DecisionTestingCheckpointSelectionContext
    ) -> Bool {
        let explicitCheckpointID = context.explicitCheckpointID?.evolutionTrimmedNonEmpty
        let lhsExplicitMatch = lhs.checkpointID == explicitCheckpointID
        let rhsExplicitMatch = rhs.checkpointID == explicitCheckpointID
        if lhsExplicitMatch != rhsExplicitMatch {
            return lhsExplicitMatch
        }

        let lhsFoldScore = thoughtFoldMatchScore(
            candidate: lhs.eBrain.thoughtFoldChecksum,
            anchor: context.thoughtFoldChecksum
        )
        let rhsFoldScore = thoughtFoldMatchScore(
            candidate: rhs.eBrain.thoughtFoldChecksum,
            anchor: context.thoughtFoldChecksum
        )
        let lhsRollbackScore = rollbackAnchorMatchScore(
            candidate: lhs.eBrain.rollbackAnchor?.anchorID,
            anchor: context.rollbackAnchorID
        )
        let rhsRollbackScore = rollbackAnchorMatchScore(
            candidate: rhs.eBrain.rollbackAnchor?.anchorID,
            anchor: context.rollbackAnchorID
        )
        if lhsRollbackScore != rhsRollbackScore {
            return lhsRollbackScore > rhsRollbackScore
        }
        if lhsFoldScore != rhsFoldScore {
            return lhsFoldScore > rhsFoldScore
        }

        let lhsSessionMatch = lhs.eBrain.sessionID == context.sessionID?.evolutionTrimmedNonEmpty
        let rhsSessionMatch = rhs.eBrain.sessionID == context.sessionID?.evolutionTrimmedNonEmpty
        if lhsSessionMatch != rhsSessionMatch {
            return lhsSessionMatch
        }

        let lhsReviewDirectiveScore = reviewDirectiveMatchScore(
            candidate: lhs.eBrain.reviewDirectiveLine,
            anchor: context.reviewDirectiveLine
        )
        let rhsReviewDirectiveScore = reviewDirectiveMatchScore(
            candidate: rhs.eBrain.reviewDirectiveLine,
            anchor: context.reviewDirectiveLine
        )
        if lhsReviewDirectiveScore != rhsReviewDirectiveScore {
            return lhsReviewDirectiveScore > rhsReviewDirectiveScore
        }

        let lhsRiskPermitScore = riskPermitMatchScore(candidate: lhs.eBrain, anchor: context)
        let rhsRiskPermitScore = riskPermitMatchScore(candidate: rhs.eBrain, anchor: context)
        if lhsRiskPermitScore != rhsRiskPermitScore {
            return lhsRiskPermitScore > rhsRiskPermitScore
        }

        let lhsHostGateScore = hostGateMatchScore(
            candidate: lhs.eBrain.hostGatePercent,
            anchor: context.hostGatePercent
        )
        let rhsHostGateScore = hostGateMatchScore(
            candidate: rhs.eBrain.hostGatePercent,
            anchor: context.hostGatePercent
        )
        if lhsHostGateScore != rhsHostGateScore {
            return lhsHostGateScore > rhsHostGateScore
        }

        let lhsDistance = abs(lhs.eBrain.recordedAt.timeIntervalSince(context.referenceDate))
        let rhsDistance = abs(rhs.eBrain.recordedAt.timeIntervalSince(context.referenceDate))
        if lhsDistance != rhsDistance {
            return lhsDistance < rhsDistance
        }

        let lhsModeScore = lhs.mode == context.mode ? 1 : 0
        let rhsModeScore = rhs.mode == context.mode ? 1 : 0
        if lhsModeScore != rhsModeScore {
            return lhsModeScore > rhsModeScore
        }

        if let contextSource = context.source {
            let lhsSourceScore = lhs.eBrain.source == contextSource ? 1 : 0
            let rhsSourceScore = rhs.eBrain.source == contextSource ? 1 : 0
            if lhsSourceScore != rhsSourceScore {
                return lhsSourceScore > rhsSourceScore
            }
        }

        if lhs.eBrain.recordedAt != rhs.eBrain.recordedAt {
            return lhs.eBrain.recordedAt > rhs.eBrain.recordedAt
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.checkpointID > rhs.checkpointID
    }

    private static func isPreferredUsingReplayContext(
        _ lhs: DecisionEvolutionLineageSnapshot,
        over rhs: DecisionEvolutionLineageSnapshot,
        matching context: DecisionTestingCheckpointSelectionContext
    ) -> Bool {
        let lhsModeScore = lhs.mode == context.mode ? 1 : 0
        let rhsModeScore = rhs.mode == context.mode ? 1 : 0
        if lhsModeScore != rhsModeScore {
            return lhsModeScore > rhsModeScore
        }

        if let contextSource = context.source {
            let lhsSourceScore = lhs.eBrain.source == contextSource ? 1 : 0
            let rhsSourceScore = rhs.eBrain.source == contextSource ? 1 : 0
            if lhsSourceScore != rhsSourceScore {
                return lhsSourceScore > rhsSourceScore
            }
        }

        let lhsDistance = abs(lhs.eBrain.recordedAt.timeIntervalSince(context.referenceDate))
        let rhsDistance = abs(rhs.eBrain.recordedAt.timeIntervalSince(context.referenceDate))
        if lhsDistance != rhsDistance {
            return lhsDistance < rhsDistance
        }

        if lhs.eBrain.recordedAt != rhs.eBrain.recordedAt {
            return lhs.eBrain.recordedAt > rhs.eBrain.recordedAt
        }

        return lhs.checkpointID > rhs.checkpointID
    }

    private static func thoughtFoldMatchScore(
        candidate: String?,
        anchor: String?
    ) -> Int {
        guard let candidate = candidate?.evolutionTrimmedNonEmpty,
              let anchor = anchor?.evolutionTrimmedNonEmpty else {
            return 0
        }

        if candidate == anchor {
            return 2
        }

        if candidate.hasPrefix(anchor) || anchor.hasPrefix(candidate) {
            return 1
        }

        return 0
    }

    private static func reviewDirectiveMatchScore(
        candidate: String?,
        anchor: String?
    ) -> Int {
        guard let candidate = candidate?.evolutionTrimmedNonEmpty,
              let anchor = anchor?.evolutionTrimmedNonEmpty else {
            return 0
        }

        return candidate == anchor ? 1 : 0
    }

    private static func rollbackAnchorMatchScore(
        candidate: String?,
        anchor: String?
    ) -> Int {
        guard let candidate = candidate?.evolutionTrimmedNonEmpty,
              let anchor = anchor?.evolutionTrimmedNonEmpty else {
            return 0
        }

        return candidate == anchor ? 3 : 0
    }

    private static func riskPermitMatchScore(
        candidate: DeveloperDecisionReplayEBrainSummary,
        anchor: DecisionTestingCheckpointSelectionContext
    ) -> Int {
        let riskLevel = anchor.riskLevel?.evolutionTrimmedNonEmpty
        let permitMode = anchor.permitMode?.evolutionTrimmedNonEmpty

        guard riskLevel != nil || permitMode != nil else {
            return 0
        }

        let riskMatches = candidate.riskLevel == riskLevel
        let permitMatches = candidate.permitMode == permitMode

        switch (riskLevel != nil, permitMode != nil) {
        case (true, true):
            if riskMatches && permitMatches {
                return 2
            }
            if riskMatches || permitMatches {
                return 1
            }
            return 0
        case (true, false):
            return riskMatches ? 1 : 0
        case (false, true):
            return permitMatches ? 1 : 0
        case (false, false):
            return 0
        }
    }

    private static func hostGateMatchScore(
        candidate: Int,
        anchor: Int?
    ) -> Int {
        guard let anchor else {
            return 0
        }

        return candidate == anchor ? 1 : 0
    }
}

enum DecisionTestingEBrainSource: String, Equatable, Sendable {
    case liveRuntime = "live_runtime"
    case persistedCheckpoint = "persisted_checkpoint"

    var sourceDescriptor: DecisionEvolutionSourceDescriptor {
        switch self {
        case .liveRuntime:
            .liveRuntimeDefault
        case .persistedCheckpoint:
            .checkpointRecoveryDefault
        }
    }

    var title: String {
        sourceDescriptor.title
    }
}

struct DecisionEvolutionLineageSnapshot: Identifiable, Equatable, Sendable {
    let checkpointID: String
    let previousCheckpointID: String?
    let createdAt: Date
    let mode: DecisionMode
    let approvalState: DecisionEvolutionApprovalState
    let rollbackReady: Bool
    let hasBrainStateSnapshot: Bool
    let diffSummary: [String]
    let eBrain: DeveloperDecisionReplayEBrainSummary

    var id: String { checkpointID }

    init(
        checkpointID: String,
        previousCheckpointID: String? = nil,
        createdAt: Date,
        mode: DecisionMode,
        approvalState: DecisionEvolutionApprovalState,
        rollbackReady: Bool,
        hasBrainStateSnapshot: Bool = false,
        diffSummary: [String],
        eBrain: DeveloperDecisionReplayEBrainSummary
    ) {
        self.checkpointID = checkpointID
        self.previousCheckpointID = previousCheckpointID
        self.createdAt = createdAt
        self.mode = mode
        self.approvalState = approvalState
        self.rollbackReady = rollbackReady
        self.hasBrainStateSnapshot = hasBrainStateSnapshot
        self.diffSummary = diffSummary
        self.eBrain = eBrain
    }
}

struct DecisionEvolutionEffectiveEBrainContext: Equatable, Sendable {
    let summary: DeveloperDecisionReplayEBrainSummary?
    let source: DecisionTestingEBrainSource?
    let factsBundle: DecisionEvolutionEBrainFactsBundle?
    let thoughtFoldChecksum: String?
    let updateTicketSummaries: [String]
    let reviewDirectiveLine: String?
    let runtimeAuditFindings: [String]
    let effectiveActiveKillSwitches: [String]
    let recommendedKillSwitches: [String]

    static let empty = DecisionEvolutionEffectiveEBrainContext(
        summary: nil,
        source: nil,
        factsBundle: nil,
        thoughtFoldChecksum: nil,
        updateTicketSummaries: [],
        reviewDirectiveLine: nil,
        runtimeAuditFindings: [],
        effectiveActiveKillSwitches: [],
        recommendedKillSwitches: []
    )
}

struct DecisionReviewCheckpointSnapshot: Identifiable, Equatable, Sendable {
    let checkpointID: String
    let previousCheckpointID: String?
    let createdAt: Date
    let mode: DecisionMode
    let approvalState: DecisionEvolutionApprovalState
    let rollbackReady: Bool
    let hasBrainStateSnapshot: Bool
    let diffSummary: [String]
    let eBrain: DeveloperDecisionReplayEBrainSummary?
    let fallbackRiskLevel: String?
    let fallbackPermitMode: String?

    var id: String { checkpointID }

    var applyReady: Bool {
        hasBrainStateSnapshot
    }

    var primarySummary: String {
        diffSummary.first
            ?? eBrain?.reviewDirectiveLine?.evolutionTrimmedNonEmpty
            ?? eBrain?.updateTicketSummaries.first?.evolutionTrimmedNonEmpty
            ?? (eBrain == nil
                ? "This checkpoint predates persisted lineage data but still needs review."
                : "This checkpoint is ready for review.")
    }

    init(
        checkpointID: String,
        previousCheckpointID: String? = nil,
        createdAt: Date,
        mode: DecisionMode,
        approvalState: DecisionEvolutionApprovalState,
        rollbackReady: Bool,
        hasBrainStateSnapshot: Bool,
        diffSummary: [String],
        eBrain: DeveloperDecisionReplayEBrainSummary?,
        fallbackRiskLevel: String? = nil,
        fallbackPermitMode: String? = nil
    ) {
        self.checkpointID = checkpointID
        self.previousCheckpointID = previousCheckpointID
        self.createdAt = createdAt
        self.mode = mode
        self.approvalState = approvalState
        self.rollbackReady = rollbackReady
        self.hasBrainStateSnapshot = hasBrainStateSnapshot
        self.diffSummary = diffSummary
        self.eBrain = eBrain
        self.fallbackRiskLevel = fallbackRiskLevel
        self.fallbackPermitMode = fallbackPermitMode
    }
}

extension DecisionReviewCheckpointSnapshot {
    init(checkpoint: DecisionEvolutionCheckpoint) {
        self.init(
            checkpointID: checkpoint.id,
            previousCheckpointID: checkpoint.previousCheckpointID,
            createdAt: checkpoint.createdAt,
            mode: checkpoint.mode,
            approvalState: checkpoint.approvalState,
            rollbackReady: checkpoint.rollbackReady,
            hasBrainStateSnapshot: checkpoint.brainStateSnapshot != nil,
            diffSummary: checkpoint.diffSummary,
            eBrain: checkpoint.lineageSummary.map(DeveloperDecisionReplayEBrainSummary.init(lineageSummary:)),
            fallbackRiskLevel: checkpoint.calibrationStatus.rawValue,
            fallbackPermitMode: checkpoint.boundaryMode.rawValue
        )
    }

    init(summary: DecisionEvolutionCheckpointSummary, mode: DecisionMode) {
        self.init(
            checkpointID: summary.id,
            previousCheckpointID: summary.previousCheckpointID,
            createdAt: summary.createdAt,
            mode: mode,
            approvalState: summary.approvalState,
            rollbackReady: summary.rollbackReady,
            hasBrainStateSnapshot: false,
            diffSummary: summary.diffSummary,
            eBrain: summary.lineageSummary.map(DeveloperDecisionReplayEBrainSummary.init(lineageSummary:))
        )
    }

    init(lineage: DecisionEvolutionLineageSnapshot) {
        self.init(
            checkpointID: lineage.checkpointID,
            previousCheckpointID: lineage.previousCheckpointID,
            createdAt: lineage.createdAt,
            mode: lineage.mode,
            approvalState: lineage.approvalState,
            rollbackReady: lineage.rollbackReady,
            hasBrainStateSnapshot: lineage.hasBrainStateSnapshot,
            diffSummary: lineage.diffSummary,
            eBrain: lineage.eBrain
        )
    }
}

struct DecisionTestingCheckpointSelectionContext: Equatable, Sendable {
    let mode: DecisionMode?
    let source: DeveloperDecisionReplayEBrainSource?
    let referenceDate: Date
    let explicitCheckpointID: String?
    let thoughtFoldChecksum: String?
    let sessionID: String?
    let riskLevel: String?
    let permitMode: String?
    let hostGatePercent: Int?
    let reviewDirectiveLine: String?
    let rollbackAnchorID: String?

    init(
        mode: DecisionMode?,
        source: DeveloperDecisionReplayEBrainSource?,
        referenceDate: Date,
        explicitCheckpointID: String? = nil,
        thoughtFoldChecksum: String? = nil,
        sessionID: String? = nil,
        riskLevel: String? = nil,
        permitMode: String? = nil,
        hostGatePercent: Int? = nil,
        reviewDirectiveLine: String? = nil,
        rollbackAnchorID: String? = nil
    ) {
        self.mode = mode
        self.source = source
        self.referenceDate = referenceDate
        self.explicitCheckpointID = explicitCheckpointID?.evolutionTrimmedNonEmpty
        self.thoughtFoldChecksum = thoughtFoldChecksum?.evolutionTrimmedNonEmpty
        self.sessionID = sessionID?.evolutionTrimmedNonEmpty
        self.riskLevel = riskLevel?.evolutionTrimmedNonEmpty
        self.permitMode = permitMode?.evolutionTrimmedNonEmpty
        self.hostGatePercent = hostGatePercent
        self.reviewDirectiveLine = reviewDirectiveLine?.evolutionTrimmedNonEmpty
        self.rollbackAnchorID = rollbackAnchorID?.evolutionTrimmedNonEmpty
    }
}

extension DecisionTestingCheckpointSelectionContext {
    fileprivate func merged(with supplement: DecisionTestingCheckpointSelectionContext?) -> DecisionTestingCheckpointSelectionContext {
        guard let supplement else {
            return self
        }

        return DecisionTestingCheckpointSelectionContext(
            mode: mode ?? supplement.mode,
            source: source ?? supplement.source,
            referenceDate: referenceDate,
            explicitCheckpointID: explicitCheckpointID ?? supplement.explicitCheckpointID,
            thoughtFoldChecksum: thoughtFoldChecksum ?? supplement.thoughtFoldChecksum,
            sessionID: sessionID ?? supplement.sessionID,
            riskLevel: riskLevel ?? supplement.riskLevel,
            permitMode: permitMode ?? supplement.permitMode,
            hostGatePercent: hostGatePercent ?? supplement.hostGatePercent,
            reviewDirectiveLine: reviewDirectiveLine ?? supplement.reviewDirectiveLine,
            rollbackAnchorID: rollbackAnchorID ?? supplement.rollbackAnchorID
        )
    }

    fileprivate var hasRuntimeAnchor: Bool {
        explicitCheckpointID?.evolutionTrimmedNonEmpty != nil
            || thoughtFoldChecksum?.evolutionTrimmedNonEmpty != nil
            || sessionID?.evolutionTrimmedNonEmpty != nil
            || riskLevel?.evolutionTrimmedNonEmpty != nil
            || permitMode?.evolutionTrimmedNonEmpty != nil
            || hostGatePercent != nil
            || reviewDirectiveLine?.evolutionTrimmedNonEmpty != nil
            || rollbackAnchorID?.evolutionTrimmedNonEmpty != nil
    }
}

extension BASEBrainTurnResult {
    var replayMode: DecisionMode? {
        if let workflow = hostContext.workRoutines.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            if let match = DecisionMode.allCases.first(where: {
                workflow.contains($0.rawValue) || workflow.contains($0.shortTitle.lowercased())
            }) {
                return match
            }
        }

        if let sessionMode = runtimeTrace.sessionID
            .split(separator: "|")
            .first?
            .split(separator: ".")
            .last
            .map(String.init),
           let match = DecisionMode(rawValue: sessionMode) {
            return match
        }

        return nil
    }
}

struct DecisionTestingRuntimeExport {
    let generatedAt: Date
    let runtimeSnapshot: DecisionTestingRuntimeSnapshot
    let sessionEngineSnapshot: DecisionSessionRuntimeSnapshot?
    let pendingSessionEngineImportPreview: DecisionSessionEnginePendingImportPreview?
    let registeredProviders: [DecisionModelProviderDescriptor]
    let intelligenceTelemetry: DecisionIntelligenceTelemetrySnapshot
    let cacheTelemetry: DecisionIntelligenceCacheTelemetrySnapshot
    let circuitBreakerSnapshot: DecisionIntelligenceCircuitBreakerSnapshot
    let recentTraces: [DecisionIntelligenceTrace]
    let recentReplay: [DeveloperDecisionReplayEntry]
    let persistedCheckpointLineages: [DecisionEvolutionLineageSnapshot]
    let pendingReviewCheckpoints: [DecisionReviewCheckpointSnapshot]
    let activeCheckpointHint: DecisionReviewCheckpointSnapshot?
    let activeCheckpointSource: DecisionEvolutionActiveCheckpointSource
    let restorableCheckpointIDs: Set<String>
    let activeKillSwitches: [String]
    let eBrainTurn: BASEBrainTurnResult?

    init(
        generatedAt: Date,
        runtimeSnapshot: DecisionTestingRuntimeSnapshot,
        sessionEngineSnapshot: DecisionSessionRuntimeSnapshot? = nil,
        pendingSessionEngineImportPreview: DecisionSessionEnginePendingImportPreview? = nil,
        registeredProviders: [DecisionModelProviderDescriptor],
        intelligenceTelemetry: DecisionIntelligenceTelemetrySnapshot,
        cacheTelemetry: DecisionIntelligenceCacheTelemetrySnapshot,
        circuitBreakerSnapshot: DecisionIntelligenceCircuitBreakerSnapshot,
        recentTraces: [DecisionIntelligenceTrace],
        recentReplay: [DeveloperDecisionReplayEntry],
        persistedCheckpointLineages: [DecisionEvolutionLineageSnapshot],
        pendingReviewCheckpoints: [DecisionReviewCheckpointSnapshot],
        activeCheckpointHint: DecisionReviewCheckpointSnapshot?,
        activeCheckpointSource: DecisionEvolutionActiveCheckpointSource = .none,
        restorableCheckpointIDs: Set<String> = [],
        activeKillSwitches: [String] = [],
        eBrainTurn: BASEBrainTurnResult?
    ) {
        self.generatedAt = generatedAt
        self.runtimeSnapshot = runtimeSnapshot
        self.sessionEngineSnapshot = sessionEngineSnapshot
        self.pendingSessionEngineImportPreview = pendingSessionEngineImportPreview
        self.registeredProviders = registeredProviders
        self.intelligenceTelemetry = intelligenceTelemetry
        self.cacheTelemetry = cacheTelemetry
        self.circuitBreakerSnapshot = circuitBreakerSnapshot
        self.recentTraces = recentTraces
        self.recentReplay = recentReplay
        self.persistedCheckpointLineages = persistedCheckpointLineages
        self.pendingReviewCheckpoints = pendingReviewCheckpoints
        self.activeCheckpointHint = activeCheckpointHint
        self.activeCheckpointSource = activeCheckpointSource
        self.restorableCheckpointIDs = restorableCheckpointIDs
        self.activeKillSwitches = activeKillSwitches
        self.eBrainTurn = eBrainTurn
    }

    var evolutionControlSurface: DecisionEvolutionControlSurface {
        evolutionControlSurfaceInventory.buildControlSurface(
            preferredCheckpointSelectionContext: preferredCheckpointSelectionContext
        )
    }

    var evolutionControlSurfaceInventory: DecisionEvolutionControlSurfaceInventory {
        DecisionEvolutionControlSurfaceInventory(
            pendingReviewQueue: effectivePendingReviewCheckpoints,
            persistedLineages: persistedCheckpointLineages,
            activeCheckpoint: activeCheckpointHint,
            activeCheckpointSource: activeCheckpointSource,
            restorableCheckpointIDs: restorableCheckpointIDs
        )
    }

    var pendingReviewCheckpointLineages: [DecisionEvolutionLineageSnapshot] {
        persistedCheckpointLineages
            .filter { $0.approvalState == .reviewSuggested }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.checkpointID > rhs.checkpointID
            }
    }

    var pendingReviewCheckpointCount: Int {
        effectivePendingReviewCheckpoints.count
    }

    var effectivePendingReviewCheckpoints: [DecisionReviewCheckpointSnapshot] {
        let checkpoints = if pendingReviewCheckpoints.isEmpty {
            pendingReviewCheckpointLineages.map(DecisionReviewCheckpointSnapshot.init(lineage:))
        } else {
            pendingReviewCheckpoints
        }

        return checkpoints.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.checkpointID > rhs.checkpointID
        }
    }

    var latestCheckpointLineage: DecisionEvolutionLineageSnapshot? {
        evolutionControlSurfaceInventory.latestPersistedLineage(
            matching: preferredCheckpointSelectionContext
        )?.applying(anchor: latestSessionCheckpointAnchor)
    }

    var latestAutomaticCheckpointLineage: DecisionEvolutionLineageSnapshot? {
        evolutionControlSurfaceInventory.latestAutomaticLineage(
            matching: preferredCheckpointSelectionContext
        )?.applying(anchor: latestSessionCheckpointAnchor)
    }

    var preferredCheckpointSelectionContext: DecisionTestingCheckpointSelectionContext? {
        if let eBrainTurn {
            return DecisionEvolutionRuntimeAnchorResolver.selectionContext(
                for: eBrainTurn,
                explicitCheckpointID: activeCheckpointHint?.checkpointID
            )
        }

        if let preferredReplayCheckpointSelectionContext {
            return preferredReplayCheckpointSelectionContext.merged(
                with: preferredSessionCheckpointSelectionContext
            )
        }

        return preferredSessionCheckpointSelectionContext
    }

    func selectedCheckpointLineage(
        matching context: DecisionTestingCheckpointSelectionContext? = nil
    ) -> DecisionEvolutionLineageSnapshot? {
        evolutionControlSurfaceInventory.selectedCheckpointLineage(
            matching: context
        )?.applying(anchor: latestSessionCheckpointAnchor)
    }

    private func selectedCheckpointLineage(
        in lineages: [DecisionEvolutionLineageSnapshot],
        matching context: DecisionTestingCheckpointSelectionContext? = nil
    ) -> DecisionEvolutionLineageSnapshot? {
        evolutionControlSurfaceInventory.selectedCheckpointLineage(
            in: lineages,
            matching: context
        )?.applying(anchor: latestSessionCheckpointAnchor)
    }

    var effectiveEBrainSummary: DeveloperDecisionReplayEBrainSummary? {
        evolutionRuntimeFacts(currentBrainState: nil).effectiveEBrainSummary
    }

    var effectiveEBrainSource: DecisionTestingEBrainSource? {
        evolutionRuntimeFacts(currentBrainState: nil).effectiveEBrainSource
    }

    var effectiveEBrainFactsBundle: DecisionEvolutionEBrainFactsBundle? {
        evolutionRuntimeFacts(currentBrainState: nil).effectiveEBrainFactsBundle
    }

    var effectiveLayerStackLines: [String] {
        evolutionRuntimeFacts(currentBrainState: nil).layerStackLines
    }

    var runtimePolicyLineage: BeforeRuntimePolicyLineage {
        runtimeSnapshot.runtimePolicyLineage
    }

    var runtimePolicyIssues: [BeforeRuntimePolicyIssue] {
        runtimeSnapshot.runtimePolicyIssues
    }

    var executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame {
        if eBrainTurn == nil,
           let persistedSessionCheckpointExecutionCapabilityFrame {
            return persistedSessionCheckpointExecutionCapabilityFrame
        }

        return runtimeSnapshot.executionCapabilityFrame
    }

    var liveEBrainKernelFrame: DecisionEBrainKernelFrame? {
        guard let eBrainTurn else {
            return nil
        }

        return DecisionEBrainKernelFrame.build(
            from: eBrainTurn,
            executionCapabilityFrame: executionCapabilityFrame
        )
    }

    var liveEBrainPresentationFrame: DecisionEBrainPresentationFrame? {
        guard let eBrainTurn else {
            return nil
        }

        return DecisionEBrainPresentationFrame.build(
            from: eBrainTurn,
            executionCapabilityFrame: executionCapabilityFrame
        )
    }

    var flightDeck: DecisionSystemFlightDeck {
        DecisionSystemFlightDeckBuilder.build(from: self, eBrainTurn: eBrainTurn)
    }

    func flightDeck(
        eBrainTurn: BASEBrainTurnResult? = nil
    ) -> DecisionSystemFlightDeck {
        DecisionSystemFlightDeckBuilder.build(
            from: self,
            eBrainTurn: eBrainTurn ?? self.eBrainTurn
        )
    }

    var thoughtFoldChecksum: String? {
        evolutionRuntimeFacts(currentBrainState: nil).thoughtFoldChecksum
    }

    var updateTicketSummaries: [String] {
        evolutionRuntimeFacts(currentBrainState: nil).updateTicketSummaries
    }

    var runtimeAuditFindings: [String] {
        evolutionRuntimeFacts(currentBrainState: nil).runtimeAuditFindings
    }

    var recommendedKillSwitches: [String] {
        evolutionRuntimeFacts(currentBrainState: nil).recommendedKillSwitches
    }

    var effectiveActiveKillSwitches: [String] {
        evolutionRuntimeFacts(currentBrainState: nil).effectiveActiveKillSwitches
    }

    func evolutionRuntimeFacts(
        currentBrainState: CurrentBrainState?
    ) -> DecisionEvolutionRuntimeFacts {
        let effectiveEBrainContext = resolvedEffectiveEBrainContext()
        let currentBrainAutomaticCheckpoint = currentBrainState?.evolutionState.latestCheckpoint
            .flatMap { checkpoint -> DecisionReviewCheckpointSnapshot? in
                guard checkpoint.approvalState == .automatic else {
                    return nil
                }

                return DecisionReviewCheckpointSnapshot(
                    summary: checkpoint,
                    mode: currentBrainState?.mode ?? .quick
                )
            }
        let coverageFacts = evolutionControlSurface.coverageFacts(
            latestPersistedLineage: latestCheckpointLineage,
            recoveredCheckpointOverride: currentBrainAutomaticCheckpoint ?? evolutionControlSurface.activeCheckpoint
        )

        return DecisionEvolutionRuntimeFacts(
            effectiveEBrainSummary: effectiveEBrainContext.summary,
            effectiveEBrainSource: effectiveEBrainContext.source,
            effectiveEBrainFactsBundle: effectiveEBrainContext.factsBundle,
            layerStackLines: effectiveEBrainContext.factsBundle?.layerStackLines ?? [],
            thoughtFoldChecksum: effectiveEBrainContext.thoughtFoldChecksum,
            updateTicketSummaries: effectiveEBrainContext.updateTicketSummaries,
            runtimeAuditFindings: effectiveEBrainContext.runtimeAuditFindings,
            effectiveActiveKillSwitches: effectiveEBrainContext.effectiveActiveKillSwitches,
            recommendedKillSwitches: effectiveEBrainContext.recommendedKillSwitches,
            coverageFacts: coverageFacts
        )
    }

    private func resolvedEffectiveEBrainContext() -> DecisionEvolutionEffectiveEBrainContext {
        if let eBrainTurn {
            let summary = DeveloperDecisionReplayEBrainSummary(turn: eBrainTurn)
            return DecisionEvolutionEffectiveEBrainContext(
                summary: summary,
                source: .liveRuntime,
                factsBundle: summary
                    .factsBundle(modeTitle: preferredCheckpointSelectionContext?.mode?.shortTitle)
                    .applying(executionCapabilityFrame: executionCapabilityFrame),
                thoughtFoldChecksum: String(eBrainTurn.thoughtFold.checksum.prefix(12)),
                updateTicketSummaries: eBrainTurn.updateTickets.map(\.summary),
                reviewDirectiveLine: eBrainTurn.updateTickets.lazy.compactMap(\.reviewDirectiveLine).compactMap(\.evolutionTrimmedNonEmpty).first,
                runtimeAuditFindings: eBrainTurn.runtimeTrace.guardrailFindings.map(\.summary),
                effectiveActiveKillSwitches: orderedUnique(
                    activeKillSwitches + eBrainTurn.runtimeTrace.activeKillSwitches.map(\.rawValue)
                ),
                recommendedKillSwitches: eBrainTurn.runtimeTrace.recommendedKillSwitches.map(\.rawValue)
            )
        }

        if let latestCheckpointLineage {
            let summary = latestCheckpointLineage.eBrain
            return DecisionEvolutionEffectiveEBrainContext(
                summary: summary,
                source: .persistedCheckpoint,
                factsBundle: latestCheckpointLineage.factsBundle.applying(
                    executionCapabilityFrame: persistedSessionCheckpointExecutionCapabilityFrame
                ),
                thoughtFoldChecksum: summary.thoughtFoldChecksum,
                updateTicketSummaries: summary.updateTicketSummaries,
                reviewDirectiveLine: summary.reviewDirectiveLine?.evolutionTrimmedNonEmpty,
                runtimeAuditFindings: summary.guardrailFindings,
                effectiveActiveKillSwitches: activeKillSwitches,
                recommendedKillSwitches: summary.killSwitches.filter {
                    !summary.activeKillSwitches.contains($0)
                }
            )
        }

        return DecisionEvolutionEffectiveEBrainContext(
            summary: nil,
            source: nil,
            factsBundle: nil,
            thoughtFoldChecksum: nil,
            updateTicketSummaries: [],
            reviewDirectiveLine: nil,
            runtimeAuditFindings: [],
            effectiveActiveKillSwitches: activeKillSwitches,
            recommendedKillSwitches: []
        )
    }

    func evolutionCoverageFacts(
        currentBrainState: CurrentBrainState?
    ) -> DecisionEvolutionCoverageFacts {
        evolutionRuntimeFacts(currentBrainState: currentBrainState).coverageFacts
    }

    func attaching(
        eBrainTurn: BASEBrainTurnResult?
    ) -> DecisionTestingRuntimeExport {
        DecisionTestingRuntimeExport(
            generatedAt: generatedAt,
            runtimeSnapshot: runtimeSnapshot,
            sessionEngineSnapshot: sessionEngineSnapshot,
            pendingSessionEngineImportPreview: pendingSessionEngineImportPreview,
            registeredProviders: registeredProviders,
            intelligenceTelemetry: intelligenceTelemetry,
            cacheTelemetry: cacheTelemetry,
            circuitBreakerSnapshot: circuitBreakerSnapshot,
            recentTraces: recentTraces,
            recentReplay: recentReplay,
            persistedCheckpointLineages: persistedCheckpointLineages,
            pendingReviewCheckpoints: pendingReviewCheckpoints,
            activeCheckpointHint: activeCheckpointHint,
            activeCheckpointSource: activeCheckpointSource,
            restorableCheckpointIDs: restorableCheckpointIDs,
            activeKillSwitches: activeKillSwitches,
            eBrainTurn: eBrainTurn
        )
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }

    private var preferredReplayCheckpointSelectionContext: DecisionTestingCheckpointSelectionContext? {
        guard let preferredReplay = recentReplay.first(where: { !$0.isCheckpointOnlyRecovery }) else {
            return nil
        }

        return DecisionTestingCheckpointSelectionContext(
            mode: preferredReplay.mode,
            source: preferredReplay.eBrain?.source,
            referenceDate: preferredReplay.timestamp,
            explicitCheckpointID: preferredReplay.preferredCheckpointID,
            thoughtFoldChecksum: preferredReplay.eBrain?.thoughtFoldChecksum,
            sessionID: preferredReplay.eBrain?.sessionID,
            riskLevel: preferredReplay.eBrain?.riskLevel,
            permitMode: preferredReplay.eBrain?.permitMode,
            hostGatePercent: preferredReplay.eBrain?.hostGatePercent,
            reviewDirectiveLine: preferredReplay.eBrain?.reviewDirectiveLine,
            rollbackAnchorID: preferredReplay.eBrain?.rollbackAnchor?.anchorID
        )
    }

    private var preferredSessionCheckpointSelectionContext: DecisionTestingCheckpointSelectionContext? {
        sessionEngineSnapshot?.recentSessions.lazy.compactMap { session in
            guard let anchor = session.latestCheckpointEBrainAnchor else {
                return nil
            }

            return DecisionEvolutionRuntimeAnchorResolver.selectionContext(
                for: anchor,
                referenceDate: session.updatedAt
            )
        }.first
    }

    var persistedSessionCheckpointExecutionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? {
        latestSessionCheckpointAnchor?.executionCapabilityFrame
    }

    private var latestSessionCheckpointAnchor: DecisionSessionCheckpointEBrainAnchor? {
        sessionEngineSnapshot?.recentSessions.lazy.compactMap(\.latestCheckpointEBrainAnchor).first
    }

    var basLifecycleSummary: BASLifecycleSummary {
        basRuntimeInspectionCompilation.lifecycleSummary
    }

    var basNeuralSummary: BASNeuralSummary {
        basRuntimeInspectionCompilation.neuralSummary
    }

    var basBrainSummary: BASBrainSummary {
        basRuntimeInspectionCompilation.brainSummary
    }

    var basRuntimeInspectionSummary: BASRuntimeInspectionSummary {
        basRuntimeInspectionCompilation.runtimeInspectionSummary
    }

    var basFlightDeckCompilation: BASAppleFlightDeckCompilation {
        BASAppleFlightDeckBuilder.build(
            from: BASAppleFlightDeckSourceInput(
                generatedAt: generatedAt,
                registeredProviderIDs: registeredProviders.map { $0.kind.rawValue },
                activeProviderID: runtimeSnapshot.runtimeStatus.active.rawValue,
                activeProviderTitle: runtimeSnapshot.runtimeStatus.active.title,
                backendTitle: runtimeSnapshot.gemmaBackendResolution.effectiveBackend.title,
                activeTaskGraphTaskCount: runtimeSnapshot.activeTaskGraph?.tasks.count ?? 0,
                hardwareAccelerationActive: runtimeSnapshot.gemmaBackendResolution.isHardwareAccelerated,
                runningOnSimulator: runtimeSnapshot.deviceCapabilities.isSimulator,
                onDeviceIntelligenceEnabled: runtimeSnapshot.preferences.onDeviceIntelligenceMode != .off,
                fallbackTitle: runtimeSnapshot.runtimeStatus.fallback?.title,
                inspectionSummary: basRuntimeInspectionSummary,
                brainSummary: basBrainSummary
            )
        )
    }

    private var basRuntimeInspectionCompilation: BASAppleRuntimeInspectionCompilation {
        let adaptationMatrix = runtimeSnapshot.executionProfile.adaptationMatrix

        return BASAppleRuntimeExportBuilder.compileRuntimeInspection(
            from: BASAppleRuntimeInspectionExportSourceInput(
                activeProviderID: runtimeSnapshot.runtimeStatus.active.rawValue,
                fallbackProviderID: runtimeSnapshot.runtimeStatus.fallback?.rawValue,
                runtimeGearID: adaptationMatrix.runtimeGear.rawValue,
                environmentClassID: adaptationMatrix.environmentClass.rawValue,
                deviceClassID: adaptationMatrix.deviceClass.rawValue,
                languageModeID: adaptationMatrix.languageMode.rawValue,
                taskEntropyIDByKind: adaptationMatrix.strategiesByKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = item.value.entropy.rawValue
                },
                preferredProviderIDByKind: adaptationMatrix.strategiesByKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = item.value.preferredProvider.rawValue
                },
                strategyByKind: adaptationMatrix.strategiesByKind.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = BASAppleRuntimeInspectionAdaptiveStrategySourceInput(
                        kindID: item.value.kind.rawValue,
                        entropyID: item.value.entropy.rawValue,
                        runtimeGearID: item.value.runtimeGear.rawValue,
                        contextBudget: item.value.contextBudget,
                        outputCharacterBudget: item.value.outputCharacterBudget,
                        timeBudgetMs: item.value.timeBudgetMs,
                        toolCallBudget: item.value.toolCallBudget,
                        retrievalItemBudget: item.value.retrievalItemBudget,
                        retrievalModeID: item.value.retrievalMode.rawValue,
                        thinkingModeID: item.value.thinkingMode.rawValue,
                        outputModeID: item.value.outputMode.rawValue,
                        toneID: item.value.tone.rawValue,
                        actionSpace: item.value.actionSpace,
                        responseLanguageID: item.value.responseLanguage.rawValue,
                        allowsModelInvocation: item.value.allowsModelInvocation
                    )
                },
                effectivePreferredProviderIDByKind: Dictionary(
                    grouping: recentTraces.compactMap { trace in
                        trace.runtimeStrategy.map { (trace.kind.rawValue, $0.preferredProvider.rawValue) }
                    },
                    by: \.0
                )
                .compactMapValues { grouped in
                    grouped.first?.1
                },
                traceRecords: recentTraces.map { trace in
                    BASAppleRuntimeInspectionTraceSourceRecordInput(
                        kindID: trace.kind.rawValue,
                        hasContextState: trace.contextState != nil,
                        generation: trace.contextState?.generation,
                        rebuiltSession: trace.contextState?.rebuiltSession ?? false,
                        staleFieldCount: trace.contextState?.staleFieldCount ?? 0,
                        anchorFieldCount: trace.contextState?.anchorFieldCount ?? 0,
                        hasFrontstageState: trace.frontstageState != nil,
                        retainedEvidenceCount: trace.frontstageState?.retainedEvidenceCount ?? 0,
                        droppedEvidenceCount: trace.frontstageState?.droppedEvidenceCount ?? 0,
                        droppedInjectedEvidenceCount: trace.frontstageState?.droppedInjectedEvidenceCount ?? 0,
                        droppedDuplicateEvidenceCount: trace.frontstageState?.droppedDuplicateEvidenceCount ?? 0,
                        droppedBudgetEvidenceCount: trace.frontstageState?.droppedBudgetEvidenceCount ?? 0,
                        suppressedBehaviorCount: trace.neuralState?.suppressedBehaviors.count,
                        dominantActionID: trace.neuralState?.dominantAction?.rawValue,
                        strongestSignalID: trace.neuralState?.dominantActivations.first?.signal.rawValue,
                        dominantReactionWeightID: trace.brainState?.reactionWeights.dominantKey.rawValue,
                        profileCoreCount: trace.brainState?.profileCore.count,
                        activeGoalCount: trace.brainState?.activeGoals.count,
                        relevantMemoryCount: trace.brainState?.relevantMemories.count,
                        loadedPromotedMemoryCount: trace.brainState?.memoryGovernance.loadedPromotedMemoryCount,
                        loadedPendingMemoryCount: trace.brainState?.memoryGovernance.loadedPendingMemoryCount,
                        pendingCandidateCount: trace.brainState?.memoryGovernance.pendingCandidateCount,
                        promotedRecordCount: trace.brainState?.memoryGovernance.totalRecordCount,
                        screenedOutMemoryCount: trace.brainState?.memoryGovernance.screenedOutMemoryCount,
                        loadedEligibilityReasonCounts: trace.brainState?.memoryGovernance.loadedReasonCounts.reduce(into: [:]) { partialResult, item in
                            partialResult[item.key.rawValue] = item.value
                        } ?? [:],
                        screenedOutEligibilityReasonCounts: trace.brainState?.memoryGovernance.screenedOutReasonCounts.reduce(into: [:]) { partialResult, item in
                            partialResult[item.key.rawValue] = item.value
                        } ?? [:],
                        snapshotFingerprint: trace.brainState?.verificationSnapshot.fingerprint,
                        lowTrustMemoryLoadRate: trace.brainState?.verificationSnapshot.lowTrustMemoryLoadRate,
                        riskFlagIDs: trace.brainState?.verificationSnapshot.riskFlags.map(\.rawValue) ?? [],
                        identityRoleID: trace.brainState?.identityProfile.role.rawValue,
                        boundaryModeID: trace.brainState?.boundaryPolicy.mode.rawValue,
                        activeConstraintIDs: trace.brainState?.boundaryPolicy.activeConstraints.map(\.rawValue) ?? [],
                        calibrationStatusID: trace.brainState?.calibrationState.status.rawValue,
                        calibrationAlertIDs: trace.brainState?.calibrationState.alerts.map(\.rawValue) ?? [],
                        evolutionCheckpointCount: trace.brainState?.evolutionState.checkpointCount,
                        evolutionPendingReviewCount: trace.brainState?.evolutionState.pendingReviewCount,
                        evolutionRollbackReady: trace.brainState?.evolutionState.rollbackReady,
                        attemptedProviderIDs: trace.attemptedProviders.map(\.rawValue),
                        runtimeStrategy: trace.runtimeStrategy.map { strategy in
                            BASAppleRuntimeInspectionAdaptiveStrategySourceInput(
                                kindID: strategy.kind.rawValue,
                                entropyID: strategy.entropy.rawValue,
                                runtimeGearID: strategy.runtimeGear.rawValue,
                                contextBudget: strategy.contextBudget,
                                outputCharacterBudget: strategy.outputCharacterBudget,
                                timeBudgetMs: strategy.timeBudgetMs,
                                toolCallBudget: strategy.toolCallBudget,
                                retrievalItemBudget: strategy.retrievalItemBudget,
                                retrievalModeID: strategy.retrievalMode.rawValue,
                                thinkingModeID: strategy.thinkingMode.rawValue,
                                outputModeID: strategy.outputMode.rawValue,
                                toneID: strategy.tone.rawValue,
                                actionSpace: strategy.actionSpace,
                                responseLanguageID: strategy.responseLanguage.rawValue,
                                allowsModelInvocation: strategy.allowsModelInvocation
                            )
                        },
                        semanticPromptFingerprint: trace.semanticPromptFingerprint,
                        stablePrefixFingerprint: trace.stablePrefixFingerprint,
                        consistencyChecked: trace.consistencyCheck != nil,
                        consistencyRejected: trace.consistencyRejected,
                        consistencyViolationKindIDs: trace.consistencyCheck?.violations.map(\.kind.rawValue) ?? []
                    )
                },
                telemetrySummary: intelligenceTelemetry.substrateSummary,
                totalCacheEntries: cacheTelemetry.entryCountByKind.values.reduce(0, +),
                totalCacheLookupCount: cacheTelemetry.totalHits + cacheTelemetry.totalMisses,
                totalCacheRejectedStores: cacheTelemetry.totalRejectedStores,
                totalCacheQuarantinedHits: cacheTelemetry.totalQuarantinedHits,
                dominantBackendID: dominantGemmaBackend?.rawValue,
                registeredProviderCount: registeredProviders.count,
                registeredOpenModelProviderCount: registeredProviders.filter { $0.track == .builtInOpenModel }.count,
                activeCircuitProviderIDs: circuitBreakerSnapshot.activeProviders.map(\.rawValue),
                circuitTripCount: circuitBreakerSnapshot.totalTripCount,
                circuitTripCountByProvider: circuitBreakerSnapshot.totalTripCountByProvider.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = item.value
                },
                circuitTripCountByReason: circuitBreakerSnapshot.totalTripCountByReason.reduce(into: [:]) { partialResult, item in
                    partialResult[item.key.rawValue] = item.value
                },
                traceCount: recentTraces.count,
                replayCount: recentReplay.count
            )
        )
    }

    private var dominantGemmaBackend: InferenceBackendKind? {
        intelligenceTelemetry.gemmaBackendCount
            .max { lhs, rhs in lhs.value < rhs.value }?
            .key
    }

}

struct DecisionTestingSubstrateInspectionSnapshot {
    let export: DecisionTestingRuntimeExport
    let eBrainTurn: BASEBrainTurnResult?

    var synchronizedExport: DecisionTestingRuntimeExport {
        export.attaching(eBrainTurn: eBrainTurn)
    }

    var effectiveEBrainSummary: DeveloperDecisionReplayEBrainSummary? {
        synchronizedExport.effectiveEBrainSummary
    }

    var effectiveEBrainSource: DecisionTestingEBrainSource? {
        synchronizedExport.effectiveEBrainSource
    }

    var effectiveEBrainFactsBundle: DecisionEvolutionEBrainFactsBundle? {
        synchronizedExport.effectiveEBrainFactsBundle
    }

    var effectiveLayerStackLines: [String] {
        synchronizedExport.effectiveLayerStackLines
    }

    var liveEBrainKernelFrame: DecisionEBrainKernelFrame? {
        synchronizedExport.liveEBrainKernelFrame
    }

    var liveEBrainPresentationFrame: DecisionEBrainPresentationFrame? {
        synchronizedExport.liveEBrainPresentationFrame
    }

    var runtimePolicyLineage: BeforeRuntimePolicyLineage {
        synchronizedExport.runtimePolicyLineage
    }

    var runtimePolicyIssues: [BeforeRuntimePolicyIssue] {
        synchronizedExport.runtimePolicyIssues
    }

    var latestPersistenceIssue: PersistenceIssueRecord? {
        PersistenceIssueRecorder.latestIssue()
    }

    var latestPersistenceRemediationSnapshot: PersistenceRemediationSnapshot? {
        latestPersistenceIssue?.remediationSnapshot
    }

    var latestPersistenceNotice: String? {
        latestPersistenceIssue?.displayMessage
    }

    var flightDeck: DecisionSystemFlightDeck {
        synchronizedExport.flightDeck
    }

    func consoleSnapshot(
        currentBrainState: CurrentBrainState?
    ) -> BASHostConsoleSnapshot {
        BehavioralAISubstrateBridge.consoleSnapshot(
            from: synchronizedExport,
            currentBrainState: currentBrainState,
            eBrainTurn: eBrainTurn
        )
    }
}

private extension DeveloperDecisionReplayEntry {
    var isCheckpointOnlyRecovery: Bool {
        if case .checkpoint = record {
            return true
        }
        return false
    }
}
