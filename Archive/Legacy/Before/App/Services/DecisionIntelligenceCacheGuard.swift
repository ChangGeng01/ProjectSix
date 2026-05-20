import Foundation

enum DecisionIntelligenceCacheGuardReason: String, Codable, Sendable {
    case suspiciousMarkup = "suspicious_markup"
    case suspiciousControlTokens = "suspicious_control_tokens"
    case excessiveLength = "excessive_length"
}

enum DecisionIntelligenceCacheGuard {
    private static let suspiciousMarkupTokens = [
        "<script",
        "</",
        "```",
        "{json",
        "\"role\":",
        "http://",
        "https://"
    ]

    private static let suspiciousControlTokens = [
        "assistant:",
        "system:",
        "tool call",
        "function(",
        "ignore previous",
        "developer message"
    ]

    static func validate(_ result: QuickCheckResult) -> DecisionIntelligenceCacheGuardReason? {
        validateStrings(
            [
                result.currentPerspective,
                result.afterPerspective
            ],
            maxFieldLength: 420
        )
    }

    static func validate(_ result: BalanceBoardResult) -> DecisionIntelligenceCacheGuardReason? {
        validateStrings(
            [
                result.headline,
                result.summary,
                result.focusTitle,
                result.focusDescription,
                result.nextAction
            ],
            maxFieldLength: 520
        )
    }

    static func validate(_ result: MirrorResult) -> DecisionIntelligenceCacheGuardReason? {
        validateStrings(
            [
                result.headline,
                result.coreTension,
                result.nextActionTitle,
                result.nextAction
            ],
            maxFieldLength: 520
        )
    }

    static func validate(_ candidate: ReminderSelectionCandidate) -> DecisionIntelligenceCacheGuardReason? {
        validateStrings([candidate.content], maxFieldLength: 220)
    }

    private static func validateStrings(
        _ strings: [String],
        maxFieldLength: Int
    ) -> DecisionIntelligenceCacheGuardReason? {
        for value in strings {
            let normalized = value.lowercased()
            if value.count > maxFieldLength {
                return .excessiveLength
            }
            if suspiciousMarkupTokens.contains(where: normalized.contains) {
                return .suspiciousMarkup
            }
            if suspiciousControlTokens.contains(where: normalized.contains) {
                return .suspiciousControlTokens
            }
        }

        return nil
    }
}
