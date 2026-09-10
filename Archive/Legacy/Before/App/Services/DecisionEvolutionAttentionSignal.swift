import Foundation

enum DecisionEvolutionAttentionSeverity: String, Equatable, Sendable {
    case none
    case review
    case blocked
    case rollbackWatch
}

enum DecisionEvolutionAttentionPresentationSupport {
    static let rollbackReadyHeadline = "Rollback-ready active checkpoint is available"
    static let rollbackReadyDetail = "Evolution Control can restore the previous checkpoint without rebuilding the full lineage path."
    static let quietHeadline = "Evolution is quiet"

    static func reviewBadgeValue(
        pendingReviewCount: Int
    ) -> String {
        pendingReviewCount > 9 ? "9+" : String(pendingReviewCount)
    }
}

enum DecisionEvolutionHorizonTriggerReasonSupport {
    private static let preferredPrefixes = [
        "Evidence ",
        "Temporal ",
        "Persistence ",
        "Horizon ",
        "Capability "
    ]

    static func preferredLine(
        from horizonDiagnosticsLines: [String]
    ) -> String? {
        for prefix in preferredPrefixes {
            if let line = horizonDiagnosticsLines.first(where: { $0.hasPrefix(prefix) }) {
                return line
            }
        }

        return horizonDiagnosticsLines.first
    }

    static func enrichedAuditTriggerReason(
        baseReason: String?,
        horizonDiagnosticsLines: [String]
    ) -> String? {
        let trimmedBaseReason = trimmed(baseReason)
        let preferredHorizonLine = preferredLine(
            from: horizonDiagnosticsLines
        ).flatMap(trimmed)

        guard let preferredHorizonLine else {
            return trimmedBaseReason
        }

        guard let trimmedBaseReason else {
            return preferredHorizonLine
        }

        guard trimmedBaseReason != preferredHorizonLine,
              !trimmedBaseReason.contains(preferredHorizonLine) else {
            return trimmedBaseReason
        }

        return "\(trimmedBaseReason) • \(preferredHorizonLine)"
    }

    static func enrichedAuditInstruction(
        baseInstruction: String?,
        horizonDiagnosticsLines: [String]
    ) -> String? {
        let trimmedBaseInstruction = trimmed(baseInstruction)
        let preferredHorizonLine = preferredLine(
            from: horizonDiagnosticsLines
        ).flatMap(trimmed)

        guard let preferredHorizonLine else {
            return trimmedBaseInstruction
        }

        let focusInstruction = "Horizon focus: \(preferredHorizonLine)."
        guard let trimmedBaseInstruction else {
            return focusInstruction
        }

        guard !trimmedBaseInstruction.contains(preferredHorizonLine) else {
            return trimmedBaseInstruction
        }

        return "\(trimmedBaseInstruction) \(focusInstruction)"
    }

    private static func trimmed(
        _ text: String?
    ) -> String? {
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedText, !trimmedText.isEmpty else {
            return nil
        }
        return trimmedText
    }
}

struct DecisionEvolutionAttentionPresentation: Equatable, Sendable {
    let severity: DecisionEvolutionAttentionSeverity
    let badgeValue: String?
    let headline: String
    let detail: String?
    let pendingReviewCount: Int
    let killSwitches: [String]
    let rollbackReady: Bool

    static func build(
        workspace: DecisionEvolutionWorkspaceSnapshot
    ) -> DecisionEvolutionAttentionPresentation {
        workspace.policy().attentionPresentation()
    }

    static func build(
        policy: DecisionEvolutionPolicyOutput
    ) -> DecisionEvolutionAttentionPresentation {
        policy.attentionPresentation()
    }
}

struct DecisionEvolutionAttentionSignal: Equatable, Sendable {
    let severity: DecisionEvolutionAttentionSeverity
    let badgeValue: String?
    let headline: String
    let detail: String?
    let pendingReviewCount: Int
    let killSwitches: [String]
    let rollbackReady: Bool

    var requiresAttention: Bool {
        severity != .none
    }

    func resolvedTriggerReason(
        fallback: String?,
        controlEntryKind: DecisionEvolutionWidgetControlEntryKind? = nil,
        horizonDiagnosticsLines: [String] = []
    ) -> String? {
        let trimmedDetail = detail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseReason: String? = if let trimmedDetail, !trimmedDetail.isEmpty {
            trimmedDetail
        } else if let trimmedFallback, !trimmedFallback.isEmpty {
            trimmedFallback
        } else {
            String?.none
        }

        if controlEntryKind == .audit {
            return DecisionEvolutionHorizonTriggerReasonSupport.enrichedAuditTriggerReason(
                baseReason: baseReason,
                horizonDiagnosticsLines: horizonDiagnosticsLines
            )
        }

        return baseReason
    }

    static func build(
        workspace: DecisionEvolutionWorkspaceSnapshot
    ) -> DecisionEvolutionAttentionSignal {
        build(
            policy: workspace.policy()
        )
    }

    static func build(
        policy: DecisionEvolutionPolicyOutput
    ) -> DecisionEvolutionAttentionSignal {
        let presentation = DecisionEvolutionAttentionPresentation.build(
            policy: policy
        )

        return DecisionEvolutionAttentionSignal(
            severity: presentation.severity,
            badgeValue: presentation.badgeValue,
            headline: presentation.headline,
            detail: presentation.detail,
            pendingReviewCount: presentation.pendingReviewCount,
            killSwitches: presentation.killSwitches,
            rollbackReady: presentation.rollbackReady
        )
    }
}
