import Foundation

/// observe→DISPOSE (Line A) — the deterministic on-device ground-truth SOURCE for the adjudicator.
///
/// Apple-sovereign + sandboxed ⇒ no live network; the verified facts live in a local bank. This pure,
/// deterministic lookup is BOTH the ground-truth source AND the routing gate: a question that matches a
/// fact (by cues) with a non-empty assertion is adjudicated (agrees / contradicts); anything else returns
/// nil, so the caller ABSTAINS — the bank's coverage is the gate, no separate classifier needed.
///
/// Matching is intentionally simple + transparent (substring cues, case-insensitive). It can yield a
/// false `.contradicts` if a correct assertion is phrased differently from the canonical answer (e.g.
/// "the USA" vs "United States") — robust normalization/synonyms is a later refinement; for a curated
/// bank with canonical answers the binary check is the right first cut.
public enum BASFactBank {

    /// Resolve a turn against the bank. Returns the grounding reference + the GroundTruth (`.agrees` if the
    /// asserted value contains the verified answer, else `.contradicts`), or nil when no fact matches /
    /// the assertion is empty (⇒ caller abstains). Deterministic; no model, no network.
    public static func resolve(
        question: String,
        assertedValue: String,
        facts: [BASVerifiedFact],
        alias: BASAliasNormalizer = .common
    ) -> (reference: String, groundTruth: BASFactualBeliefAdjudicator.GroundTruth)? {
        let asserted = assertedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asserted.isEmpty else { return nil }
        let q = question.lowercased()
        guard let fact = facts.first(where: { f in
            !f.cues.isEmpty && f.cues.allSatisfy { q.contains($0.lowercased()) }
        }) else { return nil }
        // alias-aware compare (fixes "the USA" vs "United States" false-.contradicts)
        return (fact.reference, alias.decide(answer: fact.answer, claim: asserted))
    }

    /// Ingest the real on-device verified-fact dataset (`known_facts.json`: a list of
    /// `{question, options, correct_index}`) into `[BASVerifiedFact]`. The verified answer is
    /// `options[correct_index]`; cues are the question's distinctive content words. Entries with an
    /// out-of-range index or no usable cues are skipped (curated bank stays clean). Throws on malformed JSON.
    public static func load(knownFactsJSON data: Data) throws -> [BASVerifiedFact] {
        let entries = try JSONDecoder().decode([BASKnownFactEntry].self, from: data)
        return entries.compactMap { entry in
            guard entry.options.indices.contains(entry.correctIndex) else { return nil }
            let answer = entry.options[entry.correctIndex]
            let cues = derivedCues(from: entry.question)
            guard !cues.isEmpty, !answer.isEmpty else { return nil }
            return BASVerifiedFact(answer: answer,
                                   reference: "\(entry.question) The verified answer is \(answer).",
                                   cues: cues)
        }
    }

    /// Load facts already in `BASVerifiedFact` shape (`{answer, reference, cues}`, extra keys like
    /// `category` ignored) — e.g. the build-time Wikidata CC0 pull (`wikidata_facts.json`). Throws on
    /// malformed JSON. This is the coverage scale-out path (659 hardcoded → thousands → millions).
    public static func load(verifiedFactsJSON data: Data) throws -> [BASVerifiedFact] {
        try JSONDecoder().decode([BASVerifiedFact].self, from: data)
    }

    /// Distinctive content words of a question (lowercased, de-duped, stopwords + short tokens dropped).
    /// `resolve` requires ALL cues present ⇒ matches only near-verbatim questions ⇒ false-abstain over
    /// false-adjudicate (the safe bias for a verdict that overrides the user).
    static func derivedCues(from question: String) -> [String] {
        let stop: Set<String> = ["what", "is", "the", "of", "for", "which", "who", "whom", "does", "do",
                                  "are", "was", "were", "how", "many", "much", "that", "this", "its",
                                  "and", "or", "name", "did", "has", "have", "from"]
        var seen = Set<String>(); var out: [String] = []
        for w in question.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        where w.count > 2 && !stop.contains(w) && !seen.contains(w) {
            seen.insert(w); out.append(w)
        }
        return out
    }
}

/// One row of the `known_facts.json` dataset (MCQ-style verified fact).
public struct BASKnownFactEntry: Decodable, Sendable, Equatable {
    public let question: String
    public let options: [String]
    public let correctIndex: Int
    enum CodingKeys: String, CodingKey { case question, options, correctIndex = "correct_index" }
}

/// One curated, verified fact: the canonical `answer` (substring-matched, case-insensitive), the
/// `reference` statement injected into the verdict, and the question `cues` that must ALL appear (lowercased)
/// in a question for it to match. Pure value type — mirrors the project's small-Codable-struct convention.
public struct BASVerifiedFact: Sendable, Equatable, Codable {
    public let answer: String
    public let reference: String
    public let cues: [String]

    public init(answer: String, reference: String, cues: [String]) {
        self.answer = answer
        self.reference = reference
        self.cues = cues
    }
}
