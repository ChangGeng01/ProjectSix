import Foundation

struct MirrorInput: Equatable, Sendable {
    let prompt: String
    let emotion: String
    let relationship: String
    let reality: String
    let longTerm: String
    let selfLens: String
}

struct MirrorResult: Codable, Equatable, Sendable {
    let headline: String
    let coreTension: String
    let nextActionTitle: String
    let nextAction: String
}

enum MirrorEngine {
    static func evaluate(_ input: MirrorInput) -> MirrorResult {
        let emotion = input.emotion.lowercased()
        let relationship = input.relationship.lowercased()
        let reality = input.reality.lowercased()
        let longTerm = input.longTerm.lowercased()
        let selfLens = input.selfLens.lowercased()

        if containsAny(relationship + " " + selfLens, keywords: ["boundary", "respect", "smaller", "shrink", "shrunken", "unseen", "unsafe", "walk on eggshells"]) {
            return MirrorResult(
                headline: "This is not just about one decision.",
                coreTension: "Part of the weight here is whether staying inside this pattern keeps asking you to get smaller than you can live with.",
                nextActionTitle: "Write the boundary",
                nextAction: "Finish this sentence honestly: 'If this continues, what I can no longer keep surrendering is ...'"
            )
        }

        if containsAny(longTerm + " " + relationship, keywords: ["always", "again", "every time", "repeat", "pattern", "cycle"]) {
            return MirrorResult(
                headline: "Repetition is part of the signal.",
                coreTension: "A single painful moment hurts. A repeating structure quietly becomes a life shape. That pattern may be the real thing you are deciding about.",
                nextActionTitle: "Name the repeating pattern",
                nextAction: "Describe the pattern in one sentence without defending anyone inside it."
            )
        }

        if containsAny(emotion + " " + longTerm, keywords: ["fear", "afraid", "lose", "loss", "alone", "lonely", "regret", "舍不得"]) {
            return MirrorResult(
                headline: "Loss and fit may be tangled together.",
                coreTension: "This may be less about choosing pain or safety, and more about separating the fear of losing something from the question of whether it still fits your life.",
                nextActionTitle: "Separate loss from fit",
                nextAction: "Make two short lists: what you would miss, and what has already stopped fitting."
            )
        }

        if containsAny(reality, keywords: ["money", "rent", "family", "work", "kids", "distance", "visa", "home"]) {
            return MirrorResult(
                headline: "Reality deserves its own lane here.",
                coreTension: "Part of what feels emotional may actually be structural. If you do not separate those, every feeling starts carrying practical fear too.",
                nextActionTitle: "Split feeling from structure",
                nextAction: "Write one list for emotional pain and another for real-world constraints. Do not let them blur together."
            )
        }

        return MirrorResult(
            headline: "This needs honesty before it needs an answer.",
            coreTension: "Right now the decision still looks bundled together. The clearer move is to name what hurts, what keeps repeating, and what kind of self you are trying not to lose.",
            nextActionTitle: "Name the real question",
            nextAction: "Rewrite the decision as a truer question starting with: 'What I am really trying to understand is ...'"
        )
    }

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
