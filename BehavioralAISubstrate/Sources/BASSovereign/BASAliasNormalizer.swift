import Foundation

/// observe→DISPOSE (Line A) — alias-aware answer↔claim comparison. A raw `asserted.contains(answer)` substring
/// check false-`.contradicts` on synonym pairs ("the USA" vs "United States", "UK" vs "Britain") AND
/// false-`.agrees` on short tokens ("8"⊂"18", "Au"⊂"Australia") — both make the 4B obey a wrong verdict.
/// This normalizes both sides + compares by WORD TOKENS (never char-substring), plus cardinal/ordinal
/// number-word equivalence ("8"="eight", "2"="second"="2nd"). SCOPE (honest): synonyms are covered ONLY for
/// the curated groups below; open-ended paraphrase / cross-lingual / unlisted synonyms still `.contradicts`
/// and are the (device-only) NLI head's job. A curated table cannot bound the synonym class; this is a
/// partial, auditable guard, not a closed fix.
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

    /// Canonicalize a short value: trim, lowercase, strip surrounding punctuation, map through the alias
    /// table, then map cardinal/ordinal number-words to digits ("eight"→"8", "second"/"2nd"→"2") so the
    /// numeric atomic-number facts don't false-`.contradicts` a correct user who wrote the word form.
    public func normalize(_ value: String) -> String {
        let key = normalizeKey(value)
        let aliased = canonical[key] ?? key
        return Self.numberWords[aliased] ?? aliased
    }

    /// Cardinal + ordinal number-words and ordinal-digit forms → bare digits. Bounded, deterministic; the
    /// open-ended numeric/paraphrase tail beyond this is the (device-only) NLI head's job.
    private static let numberWords: [String: String] = {
        let cardinals = ["zero": "0", "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
                         "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10", "eleven": "11",
                         "twelve": "12", "thirteen": "13", "fourteen": "14", "fifteen": "15", "sixteen": "16",
                         "seventeen": "17", "eighteen": "18", "nineteen": "19", "twenty": "20"]
        let ordinalWords = ["first": "1", "second": "2", "third": "3", "fourth": "4", "fifth": "5",
                            "sixth": "6", "seventh": "7", "eighth": "8", "ninth": "9", "tenth": "10"]
        var m = cardinals
        for (k, v) in ordinalWords { m[k] = v }
        for n in 1...20 {                                   // "1st", "2nd", "3rd", "4th"…"20th"
            let suffix = (n % 10 == 1 && n != 11) ? "st" : (n % 10 == 2 && n != 12) ? "nd"
                       : (n % 10 == 3 && n != 13) ? "rd" : "th"
            m["\(n)\(suffix)"] = "\(n)"
        }
        return m
    }()

    /// Alias-aware agree / contradict / ABSTAIN. `.agrees` iff the normalized claim and answer are EQUAL (after
    /// alias-group canonicalization + number-word folding); a multi-word contiguous overlap that is NOT equal is
    /// AMBIGUOUS ⇒ `.unknown` (abstain), because the same run can mean the same entity ("new york" ⊑ "new york
    /// city") or different ones ("Republic of Korea" ⊑ "Democratic People's Republic of Korea"); a value with no
    /// shared run ⇒ `.contradicts`. NEVER char-substring: single tokens must match exactly, so "8"≠"18",
    /// "74"≠"742", "au"≠"australia",
    /// "c"≠"ca" all correctly `.contradicts` (the prior `contains` false-AFFIRMED wrong users — anti-
    /// sycophancy inverted — across the numeric/symbol facts; audit 2026-06-28).
    public func decide(answer: String, claim: String) -> BASFactualBeliefAdjudicator.GroundTruth {
        let a = normalize(answer)
        let c = normalize(claim)
        guard !a.isEmpty, !c.isEmpty else { return .contradicts }
        if a == c { return .agrees }
        let at = a.split(separator: " ").map(String.init)
        let ct = c.split(separator: " ").map(String.init)
        // AMBIGUOUS multi-word overlap ⇒ ABSTAIN, not affirm (audit 2026-06-29). A contiguous run shared by both
        // can be the SAME entity ("new york" ⊑ "new york city") OR DIFFERENT entities split by a qualifier
        // ("Republic of Korea" ⊑ "Democratic People's Republic of Korea") — a token-only rule cannot tell them
        // apart, so the old `.agrees` FALSE-AFFIRMED a wrong user (the symmetric gaslight). Curated synonyms are
        // already resolved above by normalize()→`a == c`; the unlisted overlap tail is the NLI head's job. Return
        // .unknown so the caller ABSTAINS (false-abstain over false-adjudicate). A genuine mismatch with NO shared
        // run still `.contradicts`.
        if Self.containsTokenRun(at, ct) || Self.containsTokenRun(ct, at) { return .unknown }
        return .contradicts
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
        ["mumbai", "bombay"],
        ["beijing", "peking"],
        ["myanmar", "burma"],
        ["czechia", "czech republic"],
        ["turkey", "türkiye", "turkiye"],
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
