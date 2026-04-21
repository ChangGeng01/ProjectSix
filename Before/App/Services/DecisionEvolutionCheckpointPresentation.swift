import Foundation

enum DecisionEvolutionCheckpointRecoverySupport {
    static let unavailableAvailabilityText = "Live brain state is unavailable right now, but persisted checkpoints remain reviewable and restorable from local lineage."
    static let pendingEmptyMessage = "Evolution checkpoints appear after the current brain is loaded."
    static let recoveredEmptyMessage = "Recovered checkpoints remain visible here even without a live current brain."
    static let noPersistedLineageHeadline = "No persisted checkpoint lineage is attached yet"
    static let timelineRecoveryNotice = "Recovered from the last stable checkpoint after an incomplete or stalled step."
    static let recoveredDescriptorDetail = "Showing recovered lineage restored from a persisted checkpoint."
    static let recoveredWorkspaceDescriptorDetail = "Recovered lineage stored in persisted checkpoints remains visible even when no live runtime turn is attached."

    static func timelineCheckpointDetail(
        goal: String,
        basedOnEventSeq: Int
    ) -> String {
        goal.isEmpty
            ? "Recovered stable state at event \(basedOnEventSeq)."
            : goal
    }

    static func availabilityText(
        hasCurrentBrainState: Bool,
        hasAnyCheckpoint: Bool
    ) -> String {
        if hasCurrentBrainState {
            return DecisionEvolutionCheckpointLexiconSupport.rollbackStateTitle(
                rollbackReady: true
            )
        }

        return hasAnyCheckpoint
            ? unavailableAvailabilityText
            : pendingEmptyMessage
    }

    static func emptyMessage(
        hasCurrentBrainState: Bool,
        hasAnyCheckpoint: Bool
    ) -> String {
        if hasCurrentBrainState {
            return pendingEmptyMessage
        }

        return hasAnyCheckpoint
            ? recoveredEmptyMessage
            : pendingEmptyMessage
    }

    static func activeCheckpointHeadline(
        source: DecisionEvolutionActiveCheckpointSource
    ) -> String {
        source.visibleCheckpointHeadline
    }

    static func activeCheckpointReason(
        source: DecisionEvolutionActiveCheckpointSource
    ) -> String {
        source.visibleCheckpointReason
    }
}

enum DecisionEvolutionCheckpointDetailPresentationSupport {
    static let emptyLineageMessage = "No persisted checkpoint lineage is available yet."
    static let lineagePendingSummaryText = "Lineage pending • review details stay available, but recovered risk facts are not attached yet."
    static let presenceTitle = DecisionEvolutionPresencePresentationSupport.title
    static let foldedLungTitle = DecisionEvolutionFoldedLungPresentationSupport.title
    static let ticketsPrefix = "Tickets"
    static let auditPrefix = "Audit"
    static let killSwitchesPrefix = "Kill switches"
    static let diffPrefix = "Diff"
    static let selectTitle = "Select"
    static let selectedTitle = "Selected"
    private static let foldedLungPriorityPrefixes = [
        "L3 compression runtime",
        "Breath ",
        "Morph graph",
        "Integrity weave",
        "Rollback anchor",
        "Hot pack",
        "Precision profile",
        "Thermal exchanger",
        "Resume frame"
    ]

    static func rollbackStateTitle(rollbackReady: Bool) -> String {
        DecisionEvolutionCheckpointLexiconSupport.rollbackStateTitle(
            rollbackReady: rollbackReady
        )
    }

    static func rollbackBadgeTitle(rollbackReady: Bool) -> String {
        DecisionEvolutionCheckpointLexiconSupport.rollbackBadgeTitle(
            rollbackReady: rollbackReady
        )
    }

    static func labeledLine(prefix: String, values: [String]) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: prefix,
            values: values
        )
    }

    static func diffLine(values: [String]) -> String? {
        labeledLine(prefix: diffPrefix, values: values)
    }

    static func recordedLine(createdAt: Date, checkpointID: String) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: createdAt, relativeTo: .now)
        return "Recorded \(relative) • \(checkpointID)"
    }

    static func selectionAction(
        isSelected: Bool
    ) -> DecisionEvolutionCheckpointSelectionActionPresentation {
        DecisionEvolutionCheckpointSelectionActionPresentation(
            title: isSelected ? selectedTitle : selectTitle,
            usesPrimaryStyle: isSelected
        )
    }

    static func summaryBadges(
        riskLevel: String?,
        permitMode: String?,
        activeSource: DecisionEvolutionActiveCheckpointSource,
        rollbackReady: Bool
    ) -> [DecisionEvolutionSummaryBadgePresentation] {
        var badges: [DecisionEvolutionSummaryBadgePresentation] = []

        if let riskLevel {
            badges.append(
                DecisionEvolutionSummaryBadgePresentation(
                    title: riskLevel.uppercased(),
                    tone: .ember
                )
            )
        }

        if let permitMode {
            badges.append(
                DecisionEvolutionSummaryBadgePresentation(
                    title: permitMode.uppercased(),
                    tone: .moss
                )
            )
        }

        if activeSource != .none {
            badges.append(
                DecisionEvolutionSummaryBadgePresentation(
                    title: activeSource.shortTitle,
                    tone: .blue
                )
            )
        }

        badges.append(
            DecisionEvolutionSummaryBadgePresentation(
                title: rollbackBadgeTitle(rollbackReady: rollbackReady),
                tone: rollbackReady ? .moss : .ember
            )
        )

        return badges
    }

    static func diffBulletLines(values: [String]) -> [String] {
        values.map { "\u{2022} \($0)" }
    }

    static func windGateMetadataLine(layerStackLines: [String]) -> String? {
        metadataLayerLine(
            layerPrefix: "L11 wind gate",
            displayPrefix: "Wind gate",
            activeFallback: "Wind gate active",
            layerStackLines: layerStackLines
        )
    }

    static func dreamLoopMetadataLine(layerStackLines: [String]) -> String? {
        metadataLayerLine(
            layerPrefix: "L9 dream loop",
            displayPrefix: "Dream loop",
            activeFallback: "Dream loop active",
            layerStackLines: layerStackLines
        )
    }

    static func combinedMetadataText(
        base: String?,
        supplementalLines: [String]
    ) -> String? {
        let parts = ([base?.evolutionTrimmedNonEmpty] + supplementalLines.map(\.evolutionTrimmedNonEmpty))
            .compactMap { $0 }

        guard parts.isEmpty == false else {
            return nil
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined(parts)
    }

    static func foldedLungLines(
        eBrain: DeveloperDecisionReplayEBrainSummary?
    ) -> [String] {
        guard let eBrain else {
            return []
        }

        let allLines = DecisionEvolutionEBrainPresentationSupport.foldedLungLines(
            layerStackLines: eBrain.layerStackLines,
            lungLine: eBrain.lungLine,
            morphLine: eBrain.morphLine,
            hotColdLine: eBrain.hotColdLine,
            precisionLine: eBrain.precisionLine,
            organPackageLine: eBrain.organPackageLine,
            organDeltaLine: eBrain.organDeltaLine,
            schedulerLine: eBrain.schedulerLine,
            thermalExchangeLine: eBrain.thermalExchangeLine,
            integrityWeaveLine: eBrain.integrityWeaveLine,
            resumeLine: eBrain.resumeLine,
            rollbackLine: eBrain.rollbackLine
        )

        let prioritized = orderedUnique(
            foldedLungPriorityPrefixes.compactMap { prefix in
                allLines.first(where: { $0.hasPrefix(prefix) })
            }
        )
        if prioritized.isEmpty == false {
            return Array(prioritized.prefix(5))
        }

        return Array(allLines.prefix(3))
    }

    static func presenceLines(
        eBrain: DeveloperDecisionReplayEBrainSummary?
    ) -> [String] {
        let presenceLine = eBrain?.layerStackLines
            .first(where: { $0.hasPrefix("L6 presence") })
            .map { Self.droppingKnownPrefix($0, prefix: "L6 presence • ") }
            .flatMap(\.evolutionTrimmedNonEmpty)
            .map { "Presence \($0)" }

        return DecisionEvolutionPresencePresentationSupport.lines(
            presenceLine: presenceLine,
            reasons: []
        )
    }

    private static func orderedUnique(
        _ values: [String]
    ) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard uniqueValues.contains(value) == false else { return }
            uniqueValues.append(value)
        }
    }

    private static func metadataLayerLine(
        layerPrefix: String,
        displayPrefix: String,
        activeFallback: String,
        layerStackLines: [String]
    ) -> String? {
        guard let rawLine = layerStackLines.first(where: { $0.hasPrefix(layerPrefix) })?
            .evolutionTrimmedNonEmpty
        else {
            return nil
        }

        let components = rawLine.components(separatedBy: " • ")
        guard components.count > 1 else {
            return activeFallback
        }

        let rawDetail = components.dropFirst().joined(separator: " • ").evolutionTrimmedNonEmpty
        let detail = rawDetail.map { detail in
            layerPrefix == "L11 wind gate"
                ? DecisionEvolutionEBrainPresentationSupport.humanizedWindGateDetail(detail)
                : detail
        }
        return detail.map { "\(displayPrefix) \($0)" } ?? activeFallback
    }

    private static func droppingKnownPrefix(
        _ value: String,
        prefix: String
    ) -> String {
        guard value.hasPrefix(prefix) else {
            return value
        }

        return String(value.dropFirst(prefix.count))
    }
}

struct DecisionEvolutionCheckpointSelectionActionPresentation: Equatable, Sendable {
    let title: String
    let usesPrimaryStyle: Bool
}

enum DecisionEvolutionSummaryBadgeTone: Equatable, Sendable {
    case ember
    case moss
    case secondary
    case blue
    case orange
    case red
}

struct DecisionEvolutionSummaryBadgePresentation: Equatable, Sendable {
    let title: String
    let tone: DecisionEvolutionSummaryBadgeTone
}

enum DecisionEvolutionCheckpointLexiconSupport {
    static let missingCheckpointToken = "none"
    static let automaticApprovalTitle = "Automatic"
    static let reviewSuggestedApprovalTitle = "Review suggested"
    static let activeCheckpointRoleTitle = "Active checkpoint"
    static let reviewHeadRoleTitle = "Review head"
    static let activeRuntimeRoleTitle = "Active"
    static let rollbackReadyTitle = "Rollback ready"
    static let rollbackUnavailableTitle = "Rollback unavailable"
    static let rollbackReadyBadgeTitle = "ROLLBACK READY"
    static let rollbackWatchBadgeTitle = "ROLLBACK WATCH"

    static func checkpointToken(_ checkpointID: String?) -> String {
        checkpointID ?? missingCheckpointToken
    }

    static func checkpointRoleTitle(
        _ role: DecisionEvolutionCheckpointRole
    ) -> String {
        switch role {
        case .active:
            activeCheckpointRoleTitle
        case .reviewHead:
            reviewHeadRoleTitle
        }
    }

    static func runtimeRoleTitle(isActive: Bool) -> String {
        isActive ? activeRuntimeRoleTitle : reviewHeadRoleTitle
    }

    static func rollbackStateTitle(rollbackReady: Bool) -> String {
        rollbackReady ? rollbackReadyTitle : rollbackUnavailableTitle
    }

    static func rollbackBadgeTitle(rollbackReady: Bool) -> String {
        rollbackReady ? rollbackReadyBadgeTitle : rollbackWatchBadgeTitle
    }

    static func rollbackReadyCountBadgeTitle(_ count: Int) -> String {
        "\(count) \(rollbackReadyBadgeTitle)"
    }

    static func approvalStateTitle(
        _ approvalState: DecisionEvolutionApprovalState
    ) -> String {
        switch approvalState {
        case .automatic:
            automaticApprovalTitle
        case .reviewSuggested:
            reviewSuggestedApprovalTitle
        }
    }
}

struct DecisionEvolutionCheckpointPresentation: Identifiable, Equatable, Sendable {
    let checkpointID: String
    let createdAt: Date
    let mode: DecisionMode
    let approvalState: DecisionEvolutionApprovalState
    let rollbackReady: Bool
    let applyReady: Bool
    let headline: String
    let primarySummary: String
    let displayRiskLevel: String?
    let displayPermitMode: String?
    let lineageRiskLevel: String?
    let lineagePermitMode: String?
    let lineageHostGatePercent: Int?
    let summaryText: String
    let usesSecondarySummaryTone: Bool
    let metadataText: String?
    let presenceTitle: String?
    let presenceLines: [String]
    let foldedLungTitle: String?
    let foldedLungLines: [String]
    let updateTicketSummaries: [String]
    let courtLine: String?
    let auditFindings: [String]
    let killSwitches: [String]
    let diffSummary: [String]

    var id: String { checkpointID }

    var approvalStateTitle: String {
        DecisionEvolutionCheckpointLexiconSupport.approvalStateTitle(approvalState)
    }

    var rollbackStateTitle: String {
        DecisionEvolutionCheckpointDetailPresentationSupport.rollbackStateTitle(
            rollbackReady: rollbackReady
        )
    }

    var rollbackBadgeTitle: String {
        DecisionEvolutionCheckpointDetailPresentationSupport.rollbackBadgeTitle(
            rollbackReady: rollbackReady
        )
    }

    func selectionActionPresentation(
        isSelected: Bool
    ) -> DecisionEvolutionCheckpointSelectionActionPresentation {
        DecisionEvolutionCheckpointDetailPresentationSupport.selectionAction(
            isSelected: isSelected
        )
    }

    func summaryBadgePresentations(
        activeSource: DecisionEvolutionActiveCheckpointSource = .none
    ) -> [DecisionEvolutionSummaryBadgePresentation] {
        DecisionEvolutionCheckpointDetailPresentationSupport.summaryBadges(
            riskLevel: displayRiskLevel,
            permitMode: displayPermitMode,
            activeSource: activeSource,
            rollbackReady: rollbackReady
        )
    }

    var ticketsLine: String? {
        DecisionEvolutionCheckpointDetailPresentationSupport.labeledLine(
            prefix: DecisionEvolutionCheckpointDetailPresentationSupport.ticketsPrefix,
            values: updateTicketSummaries
        )
    }

    var auditLine: String? {
        DecisionEvolutionCheckpointDetailPresentationSupport.labeledLine(
            prefix: DecisionEvolutionCheckpointDetailPresentationSupport.auditPrefix,
            values: auditFindings
        )
    }

    var courtSummaryLine: String? {
        courtLine
    }

    var killSwitchesLine: String? {
        DecisionEvolutionCheckpointDetailPresentationSupport.labeledLine(
            prefix: DecisionEvolutionCheckpointDetailPresentationSupport.killSwitchesPrefix,
            values: killSwitches
        )
    }

    var diffLine: String? {
        DecisionEvolutionCheckpointDetailPresentationSupport.diffLine(values: diffSummary)
    }

    var diffBulletLines: [String] {
        DecisionEvolutionCheckpointDetailPresentationSupport.diffBulletLines(values: diffSummary)
    }

    var recordedLine: String {
        DecisionEvolutionCheckpointDetailPresentationSupport.recordedLine(
            createdAt: createdAt,
            checkpointID: checkpointID
        )
    }

    var hasLineage: Bool {
        lineageRiskLevel != nil
            || lineagePermitMode != nil
            || metadataText != nil
            || !presenceLines.isEmpty
            || !foldedLungLines.isEmpty
            || !updateTicketSummaries.isEmpty
            || courtLine != nil
            || !auditFindings.isEmpty
            || !killSwitches.isEmpty
    }

    var queueItem: DecisionSystemCheckpointQueueItem {
        DecisionSystemCheckpointQueueItem(
            checkpointID: checkpointID,
            createdAt: createdAt,
            mode: mode,
            approvalState: approvalState.rawValue,
            rollbackReady: rollbackReady,
            applyReady: applyReady,
            hasLineage: hasLineage,
            primarySummary: primarySummary,
            riskLevel: lineageRiskLevel,
            permitMode: lineagePermitMode,
            hostGatePercent: lineageHostGatePercent,
            summaryText: summaryText,
            usesSecondarySummaryTone: usesSecondarySummaryTone,
            metadataText: metadataText,
            foldedLungTitle: foldedLungTitle,
            foldedLungLines: foldedLungLines,
            updateTicketSummaries: updateTicketSummaries,
            courtLine: courtLine,
            auditFindings: auditFindings,
            killSwitches: killSwitches
        )
    }

    init(
        snapshot: DecisionReviewCheckpointSnapshot,
        rollbackReadyOverride: Bool? = nil
    ) {
        checkpointID = snapshot.checkpointID
        createdAt = snapshot.createdAt
        mode = snapshot.mode
        approvalState = snapshot.approvalState
        rollbackReady = rollbackReadyOverride ?? snapshot.rollbackReady
        applyReady = snapshot.applyReady
        headline = DecisionEvolutionEBrainPresentationSupport.recoveredCheckpointTitle(
            modeTitle: snapshot.mode.shortTitle
        )
        primarySummary = snapshot.primarySummary
        displayRiskLevel = snapshot.resolvedRiskLevel
        displayPermitMode = snapshot.resolvedPermitMode
        lineageRiskLevel = snapshot.riskLevel
        lineagePermitMode = snapshot.permitMode
        lineageHostGatePercent = snapshot.hostGatePercent
        updateTicketSummaries = snapshot.updateTicketSummaries
        courtLine = snapshot.eBrain?.courtLine
        auditFindings = snapshot.auditFindings
        killSwitches = snapshot.killSwitches
        diffSummary = snapshot.diffSummary

        if let riskLevel = snapshot.resolvedRiskLevel,
           let permitMode = snapshot.resolvedPermitMode {
            summaryText = DecisionEvolutionEBrainPresentationSupport.riskPermitLine(
                riskLevel: riskLevel,
                permitMode: permitMode
            )
            usesSecondarySummaryTone = snapshot.eBrain == nil
        } else {
            summaryText = DecisionEvolutionCheckpointDetailPresentationSupport.lineagePendingSummaryText
            usesSecondarySummaryTone = true
        }

        let baseMetadataText: String?
        if let sessionID = snapshot.sessionID,
           let hostGatePercent = snapshot.hostGatePercent,
           let thoughtFoldChecksum = snapshot.thoughtFoldChecksum {
            baseMetadataText = DecisionEvolutionEBrainPresentationSupport.sessionHostFoldLine(
                sessionID: sessionID,
                hostGatePercent: hostGatePercent,
                foldChecksum: thoughtFoldChecksum
            )
        } else {
            baseMetadataText = nil
        }

        metadataText = DecisionEvolutionCheckpointDetailPresentationSupport.combinedMetadataText(
            base: baseMetadataText,
            supplementalLines: [
                DecisionEvolutionCheckpointDetailPresentationSupport.windGateMetadataLine(
                    layerStackLines: snapshot.eBrain?.layerStackLines ?? []
                ),
                DecisionEvolutionCheckpointDetailPresentationSupport.dreamLoopMetadataLine(
                    layerStackLines: snapshot.eBrain?.layerStackLines ?? []
                )
            ]
            .compactMap { $0 }
        )
        presenceLines = DecisionEvolutionCheckpointDetailPresentationSupport.presenceLines(
            eBrain: snapshot.eBrain
        )
        presenceTitle = presenceLines.isEmpty
            ? nil
            : DecisionEvolutionCheckpointDetailPresentationSupport.presenceTitle
        foldedLungLines = DecisionEvolutionCheckpointDetailPresentationSupport.foldedLungLines(
            eBrain: snapshot.eBrain
        )
        foldedLungTitle = foldedLungLines.isEmpty
            ? nil
            : DecisionEvolutionCheckpointDetailPresentationSupport.foldedLungTitle
    }

    init(checkpoint: DecisionEvolutionCheckpoint) {
        self.init(snapshot: DecisionReviewCheckpointSnapshot(checkpoint: checkpoint))
    }
}

extension DecisionReviewCheckpointSnapshot {
    var presentation: DecisionEvolutionCheckpointPresentation {
        DecisionEvolutionCheckpointPresentation(snapshot: self)
    }

    func presentation(
        rollbackReadyOverride: Bool? = nil
    ) -> DecisionEvolutionCheckpointPresentation {
        DecisionEvolutionCheckpointPresentation(
            snapshot: self,
            rollbackReadyOverride: rollbackReadyOverride
        )
    }
}

extension DecisionEvolutionCheckpoint {
    var presentation: DecisionEvolutionCheckpointPresentation {
        DecisionEvolutionCheckpointPresentation(checkpoint: self)
    }
}
