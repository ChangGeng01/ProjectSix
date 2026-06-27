import Foundation

/// observe→DISPOSE (Line A) — alias-aware answer↔claim comparison. A raw `asserted.contains(answer)` substring
/// check false-`.contradicts` on synonym pairs ("the USA" vs "United States", "UK" vs "Britain") AND
/// false-`.agrees` on short tokens ("8"⊂"18", "Au"⊂"Australia") — both make the 4B obey a wrong verdict.
/// This normalizes both sides + compares by WORD TOKENS (never char-substring), fixing ONLY the curated
/// synonym groups below. SCOPE (honest): it does NOT do numeric equivalence ("2nd" vs "second", "8" vs
/// "eight") or open-ended paraphrase — those `.contradicts` and are the NLI head's job. A 7-group table
/// cannot bound the synonym class; this is a partial, auditable guard, not a closed fix.
public struct BASAliasNormalizer: Sendable, Equatable {

    private let canonical: [String: String]   // lowercased alias → canonical lowercased form

    /// `groups` are equivalence classes; the FIRST element is the canonical form for the class.
    public init(groups: [[String]]) {
        var map: [String: String] = [:]
        for group in groups {
            guard let canon = group.first?.lowercased() else { continue }
            for alias in group { map[normalizeKey(alias)] = canon }
        }
        canonical = map
    }

    /// Canonicalize a short value: trim, lowercase, strip surrounding punctuation, then map through the
    /// alias table. Unknown values pass through as their normalized-but-unmapped form.
    public func normalize(_ value: String) -> String {
        let key = normalizeKey(value)
        return canonical[key] ?? key
    }

    /// Alias-aware agree/contradict. `.agrees` iff the normalized claim and answer are EQUAL, or one is a
    /// multi-word contiguous WORD-token run of the other ("united states" ⊑ "united states of america").
    /// NEVER char-substring: single tokens must match exactly, so "8"≠"18", "74"≠"742", "au"≠"australia",
    /// "c"≠"ca" all correctly `.contradicts` (the prior `contains` false-AFFIRMED wrong users — anti-
    /// sycophancy inverted — across the numeric/symbol facts; audit 2026-06-28).
    public func decide(answer: String, claim: String) -> BASFactualBeliefAdjudicator.GroundTruth {
        let a = normalize(answer)
        let c = normalize(claim)
        guard !a.isEmpty, !c.isEmpty else { return .contradicts }
        if a == c { return .agrees }
        let at = a.split(separator: " ").map(String.init)
        let ct = c.split(separator: " ").map(String.init)
        return (Self.containsTokenRun(at, ct) || Self.containsTokenRun(ct, at)) ? .agrees : .contradicts
    }

    /// True iff `sub` (≥2 tokens) appears as a contiguous run inside `seq`. Single-token `sub` returns false
    /// (single tokens must match exactly via the `a == c` path) — this is what closes the substring false-affirm.
    private static func containsTokenRun(_ sub: [String], _ seq: [String]) -> Bool {
        guard sub.count >= 2, sub.count <= seq.count else { return false }
        for start in 0...(seq.count - sub.count) where Array(seq[start ..< start + sub.count]) == sub {
            return true
        }
        return false
    }

    /// A small curated default covering the most common synonym/format collisions.
    public static let common = BASAliasNormalizer(groups: [
        ["united states", "usa", "u.s.a.", "u.s.", "us", "united states of america", "america"],
        ["united kingdom", "uk", "u.k.", "britain", "great britain"],
        ["united nations", "un"],
        ["soviet union", "ussr", "u.s.s.r."],
        ["netherlands", "holland"],
        ["mount everest", "everest"],
        ["new york city", "nyc"],
    ])
}

/// Trim, lowercase, drop surrounding quotes/punctuation, strip a leading article, collapse internal
/// whitespace. Keeps internal alphanumerics + spaces so multi-word answers ("new york") survive.
private func normalizeKey(_ s: String) -> String {
    var t = s.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\"'’.,!?()")).lowercased()
    for article in ["the ", "a ", "an "] where t.hasPrefix(article) {
        t = String(t.dropFirst(article.count)); break
    }
    return t.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
}
