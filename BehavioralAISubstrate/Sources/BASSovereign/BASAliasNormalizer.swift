import Foundation

/// observe→DISPOSE (Line A) — alias-aware answer↔claim comparison, the cheap fix for the WORST failure
/// mode: a raw `asserted.contains(answer)` substring check yields a false `.contradicts` on synonym pairs
/// ("the USA" vs "United States", "UK" vs "Britain", "2nd" vs "second") — and the 4B then OBEYS a verdict
/// that GASLIGHTS a correct user. Normalizing both sides to a canonical form before comparing fixes the
/// common synonym/format cases deterministically, with ZERO model (the NLI head handles the harder
/// paraphrase/numeric-equivalence tail later). Curated groups stay small + auditable.
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

    /// Alias-aware agree/contradict: `.agrees` when the normalized claim and answer are equal or one
    /// contains the other (handles "United States" vs "the United States of America"); else `.contradicts`.
    public func decide(answer: String, claim: String) -> BASFactualBeliefAdjudicator.GroundTruth {
        let a = normalize(answer)
        let c = normalize(claim)
        guard !a.isEmpty, !c.isEmpty else { return .contradicts }
        return (a == c || a.contains(c) || c.contains(a)) ? .agrees : .contradicts
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
