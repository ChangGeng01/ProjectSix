import Foundation

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
    let updateTicketSummaries: [String]
    let auditFindings: [String]
    let killSwitches: [String]
    let diffSummary: [String]

    var id: String { checkpointID }

    var approvalStateTitle: String {
        switch approvalState {
        case .automatic:
            "Automatic"
        case .reviewSuggested:
            "Review suggested"
        }
    }

    var hasLineage: Bool {
        lineageRiskLevel != nil
            || lineagePermitMode != nil
            || metadataText != nil
            || !updateTicketSummaries.isEmpty
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
            updateTicketSummaries: updateTicketSummaries,
            auditFindings: auditFindings,
            killSwitches: killSwitches
        )
    }

    init(snapshot: DecisionReviewCheckpointSnapshot) {
        checkpointID = snapshot.checkpointID
        createdAt = snapshot.createdAt
        mode = snapshot.mode
        approvalState = snapshot.approvalState
        rollbackReady = snapshot.rollbackReady
        applyReady = snapshot.applyReady
        headline = "Recovered \(snapshot.mode.shortTitle) checkpoint"
        primarySummary = snapshot.primarySummary
        displayRiskLevel = snapshot.resolvedRiskLevel
        displayPermitMode = snapshot.resolvedPermitMode
        lineageRiskLevel = snapshot.riskLevel
        lineagePermitMode = snapshot.permitMode
        lineageHostGatePercent = snapshot.hostGatePercent
        updateTicketSummaries = snapshot.updateTicketSummaries
        auditFindings = snapshot.auditFindings
        killSwitches = snapshot.killSwitches
        diffSummary = snapshot.diffSummary

        if let riskLevel = snapshot.resolvedRiskLevel,
           let permitMode = snapshot.resolvedPermitMode {
            summaryText = "\(Self.displayToken(riskLevel)) → \(Self.displayToken(permitMode))"
            usesSecondarySummaryTone = snapshot.eBrain == nil
        } else {
            summaryText = "Lineage pending • review details stay available, but recovered risk facts are not attached yet."
            usesSecondarySummaryTone = true
        }

        if let sessionID = snapshot.sessionID,
           let hostGatePercent = snapshot.hostGatePercent,
           let thoughtFoldChecksum = snapshot.thoughtFoldChecksum {
            metadataText = "Session \(sessionID) • Host gate \(hostGatePercent)% • Fold \(thoughtFoldChecksum)"
        } else {
            metadataText = nil
        }
    }

    init(checkpoint: DecisionEvolutionCheckpoint) {
        self.init(snapshot: DecisionReviewCheckpointSnapshot(checkpoint: checkpoint))
    }

    private static func displayToken(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }
}

extension DecisionReviewCheckpointSnapshot {
    var presentation: DecisionEvolutionCheckpointPresentation {
        DecisionEvolutionCheckpointPresentation(snapshot: self)
    }
}

extension DecisionEvolutionCheckpoint {
    var presentation: DecisionEvolutionCheckpointPresentation {
        DecisionEvolutionCheckpointPresentation(checkpoint: self)
    }
}
