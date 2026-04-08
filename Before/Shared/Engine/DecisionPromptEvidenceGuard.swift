import Foundation

struct DecisionPromptEvidenceFilterResult: Equatable, Sendable {
    let retained: [String]
    let droppedCount: Int
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

    static func filter(_ evidence: [String]) -> DecisionPromptEvidenceFilterResult {
        var retained: [String] = []
        var seen: Set<String> = []
        var droppedCount = 0

        for raw in evidence {
            let normalized = normalize(raw)
            guard !normalized.isEmpty else { continue }

            if looksInjected(normalized) {
                droppedCount += 1
                continue
            }

            if seen.insert(normalized).inserted {
                retained.append(normalized)
            }
        }

        return DecisionPromptEvidenceFilterResult(
            retained: retained,
            droppedCount: droppedCount
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
}
