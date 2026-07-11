// MARK: - BASQuestionFitGate — the NLI question-fit gate (tier-0 expansion, 2026-07-11)
//
// The 完善-round residual risk class (2026-07-04, corpus-scale validation): QUALIFIER-DIFFERING
// questions at HIGH cosine — "capital of Australia's largest state" hit the "capital of Australia"
// fact at 0.82 and the short-circuit answered Canberra, a non-sequitur. Cosine measures TOPIC
// similarity; answering needs the fact to ENTAIL the whole question, qualifiers included.
//
// This gate is the deterministic, zero-cost entailment surrogate (the named NLI question-fit
// follow-up): the QUESTION's content words must all be covered by the fact's reference text.
// Any uncovered content word is a restriction the fact does not address ("largest", "state") ⇒
// UNFIT ⇒ tier-0 abstains and the turn flows to the LLM (false-abstain-over-false-answer bias —
// the gate can only REDUCE short-circuits, never add one). Asymmetric by design: the reference
// having EXTRA words is fine (it is the answer); the question having extra content words is not.
// The heavier LLM-based BASNLIEntailmentProbe stays where it was (verdict rescue) — spending an
// LLM call here would defeat tier-0's zero-call purpose.

import Foundation

public enum BASQuestionFitGate {

    /// Interrogative/stop machinery — words that carry no factual restriction. Kept small and
    /// conservative: an over-large stoplist erodes the gate (a swallowed qualifier = a wrong answer).
    static let stopwords: Set<String> = [
        "what", "which", "who", "whom", "whose", "where", "when", "how", "why",
        "is", "are", "was", "were", "be", "been", "being", "does", "do", "did",
        "the", "a", "an", "of", "in", "on", "at", "to", "for", "by", "with",
        "and", "or", "as", "its", "it", "this", "that", "there", "about",
        "tell", "me", "please", "many", "much",
    ]

    /// Normalize a token: lowercase, strip possessives ("australia's" → "australia") and
    /// non-alphanumerics. Returns nil for empties/stopwords.
    static func contentToken(_ raw: Substring) -> String? {
        var t = raw.lowercased()
        if t.hasSuffix("'s") || t.hasSuffix("’s") { t = String(t.dropLast(2)) }
        t = t.filter { $0.isLetter || $0.isNumber }
        guard t.count > 1, !stopwords.contains(t) else { return nil }
        return t
    }

    static func contentWords(_ text: String) -> Set<String> {
        Set(text.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "’" })
            .compactMap(contentToken))
    }

    /// A question token is covered when the reference contains it exactly OR a shared-stem form
    /// (prefix match ≥ 4 chars: "largest"/"large", "planets"/"planet") — morphological slack
    /// without admitting unrelated words.
    static func covered(_ token: String, by referenceWords: Set<String>) -> Bool {
        if referenceWords.contains(token) { return true }
        return referenceWords.contains { ref in
            let n = min(token.count, ref.count)
            return n >= 4 && token.prefix(n) == ref.prefix(n)
        }
    }

    /// true ⟺ the fact's reference text entails every content word of the question.
    public static func fits(question: String, reference: String) -> Bool {
        let q = contentWords(question)
        guard !q.isEmpty else { return false }   // no content ⇒ nothing to answer ⇒ unfit
        let r = contentWords(reference)
        return q.allSatisfy { covered($0, by: r) }
    }
}
