import Foundation

struct DecisionPromptEvidenceFilterResult: Equatable, Sendable {
    let retained: [String]
    let retainedCount: Int
    let droppedInjectedCount: Int
    let droppedDuplicateCount: Int
    let droppedBudgetCount: Int

    var droppedCount: Int {
        droppedInjectedCount + droppedDuplicateCount + droppedBudgetCount
    }
}

enum DecisionPromptEvidenceGuard {
    private static let suspiciousMarkers = [
        "```",
        "<script",
        "<style",
        "<html",
        "<body",
        "<div",
        "<span",
        "<tool",
        "</tool",
        "<thinking",
        "[thinking]",
        "function_call",
        "tool_call",
        "arguments_json",
        "assistant_response",
        "developer_message",
        "[immutable prefix]",
        "[adaptive prefix]",
        "[volatile suffix]"
    ]

    private static let markupRegex = try? NSRegularExpression(
        pattern: #"<[A-Za-z!/][^>]{0,120}>"#,
        options: []
    )

    static func filter(_ evidence: [String], maxRetained: Int) -> DecisionPromptEvidenceFilterResult {
        var sanitizedEvidence: [(index: Int, text: String)] = []
        var seen: Set<String> = []
        var droppedInjectedCount = 0
        var droppedDuplicateCount = 0

        for (index, raw) in evidence.enumerated() {
            let normalized = normalize(raw)
            guard !normalized.isEmpty else { continue }

            if looksInjected(normalized) {
                droppedInjectedCount += 1
                continue
            }

            if seen.insert(normalized).inserted {
                sanitizedEvidence.append((index, normalized))
            } else {
                droppedDuplicateCount += 1
            }
        }

        let retained = retainBudgetedEvidence(
            sanitizedEvidence,
            maxRetained: maxRetained
        )
        let droppedBudgetCount = max(0, sanitizedEvidence.count - retained.count)

        return DecisionPromptEvidenceFilterResult(
            retained: retained,
            retainedCount: retained.count,
            droppedInjectedCount: droppedInjectedCount,
            droppedDuplicateCount: droppedDuplicateCount,
            droppedBudgetCount: droppedBudgetCount
        )
    }

    private static func normalize(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func looksInjected(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        if suspiciousMarkers.contains(where: { lowercased.contains($0) }) {
            return true
        }

        guard let markupRegex else { return false }
        let range = NSRange(lowercased.startIndex..<lowercased.endIndex, in: lowercased)
        return markupRegex.firstMatch(in: lowercased, options: [], range: range) != nil
    }

    private static func retainBudgetedEvidence(
        _ evidence: [(index: Int, text: String)],
        maxRetained: Int
    ) -> [String] {
        guard maxRetained > 0 else { return [] }
        guard evidence.count > maxRetained else {
            return evidence.map(\.text)
        }

        let prioritized = evidence.sorted { lhs, rhs in
            let lhsPriority = retentionPriority(for: lhs.text)
            let rhsPriority = retentionPriority(for: rhs.text)
            if lhsPriority == rhsPriority {
                return lhs.index < rhs.index
            }
            return lhsPriority > rhsPriority
        }

        let retainedIndexes = Set(prioritized.prefix(maxRetained).map(\.index))
        return evidence
            .filter { retainedIndexes.contains($0.index) }
            .map(\.text)
    }

    private static func retentionPriority(for evidence: String) -> Int {
        let lowercased = evidence.lowercased()
        switch true {
        case lowercased.hasPrefix("current perspective:"),
             lowercased.hasPrefix("after perspective:"),
             lowercased.hasPrefix("current headline:"),
             lowercased.hasPrefix("core tension:"):
            return 100
        case lowercased.hasPrefix("next action:"):
            return 90
        case lowercased.hasPrefix("next action title:"):
            return 80
        case lowercased.hasPrefix("current summary:"):
            return 70
        case lowercased.hasPrefix("verdict:"),
             lowercased.hasPrefix("primary action:"):
            return 60
        case lowercased.hasPrefix("focus title:"),
             lowercased.hasPrefix("focus description:"):
            return 50
        default:
            return 40
        }
    }
}
