import Foundation

enum DecisionIntelligencePromptLibrary {
    static func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func clippedClause(from text: String, limit: Int = 56) -> String? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        guard !cleaned.isEmpty else { return nil }

        let separators = CharacterSet(charactersIn: ".!?;:")
        let firstClause = cleaned.components(separatedBy: separators).first ?? cleaned
        let collapsed = firstClause
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard !collapsed.isEmpty else { return nil }
        if collapsed.count <= limit {
            return collapsed
        }

        let clipped = String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
        return clipped + "…"
    }

    static func focusFragment(from text: String, fallback: String) -> String {
        clippedClause(from: text) ?? fallback
    }

    static func tokenSet(for text: String) -> Set<String> {
        let collapsed = String(
            normalized(text).map { character in
                character.isLetter || character.isNumber ? character : " "
            }
        )
        let stopWords: Set<String> = [
            "the", "and", "for", "with", "that", "this", "from", "just", "into",
            "your", "you", "are", "was", "were", "have", "what", "when", "than",
            "then", "them", "they", "will", "would", "should", "could", "about",
            "after", "before", "because", "there", "their", "while", "where",
            "which", "what", "been", "still", "over", "more", "less", "very"
        ]

        return Set(
            collapsed
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count >= 3 && !stopWords.contains($0) }
        )
    }

    static func overlapScore(candidate: String, prompt: String) -> Int {
        let candidateTokens = tokenSet(for: candidate)
        let promptTokens = tokenSet(for: prompt)
        return candidateTokens.intersection(promptTokens).count
    }
}
