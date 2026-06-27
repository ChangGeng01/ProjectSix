import Foundation

/// observe→DISPOSE (Line A) — the (deliberately conservative, SWAPPABLE) claim extractor.
///
/// At runtime the only input is the user's free-text turn; to adjudicate, the substrate must extract the
/// user's ASSERTED value. This is the brittle link, kept SAFE by two choices: (1) it fires ONLY on a small
/// set of explicit assertion frames ("the answer is X", "I'm pretty sure it's X", "it's X, right?",
/// "isn't it X") and returns nil otherwise — **false-abstain over false-extract**, the safe bias for a
/// verdict that overrides the user; (2) it is a pure `(String) -> String?` so the decorator accepts ANY
/// extractor — a small NLI/extraction model is the proper upgrade, dropped in without touching the rest.
public enum BASBeliefAssertionParser {

    // Each pattern's capture group 1 = the asserted value (non-greedy, bounded by punctuation / "right" /
    // end), then post-processed by `tighten` (negation ⇒ abstain, truncate at clause boundary, cap 4 words).
    // NOT robust to reported/conditional speech ("my teacher said the answer is X") — regex can't tell;
    // that's the NLI/structured extractor's job.
    private static let patterns: [String] = [
        #"(?i)\bthe answer is\s+([\p{L}\p{N}][\p{L}\p{N} '’.\-]{0,40}?)\s*(?:[,.?!]|\bright\b|$)"#,
        #"(?i)\bi(?:'|’)?m (?:pretty |fairly |quite )?(?:sure|certain)(?: that)?(?: it(?:'|’)?s| the answer is)?\s+([\p{L}\p{N}][\p{L}\p{N} '’.\-]{0,40}?)\s*(?:[,.?!]|\bright\b|$)"#,
        #"(?i)\bi think (?:it(?:'|’)?s|it is|the answer is)\s+([\p{L}\p{N}][\p{L}\p{N} '’.\-]{0,40}?)\s*(?:[,.?!]|\bright\b|$)"#,
        #"(?i)\bit(?:'|’)?s\s+([\p{L}\p{N}][\p{L}\p{N} '’.\-]{0,40}?)\s*,?\s*\bright\b"#,
        #"(?i)\bisn(?:'|’)?t it\s+([\p{L}\p{N}][\p{L}\p{N} '’.\-]{0,40}?)\s*(?:[,.?!]|$)"#,
    ]

    /// Extract the user's asserted value from `turn`, or nil when no explicit frame matches OR the capture
    /// is negated / spans a clause boundary (⇒ abstain). Pure + deterministic. STILL BRITTLE by nature —
    /// regex cannot reliably tell reported/conditional speech from a genuine belief; the NLI/structured
    /// extractor is the real fix. This only tightens the worst over-captures the audit (2026-06-28) found.
    public static func assertedValue(in turn: String) -> String? {
        let ns = turn as NSString
        let full = NSRange(location: 0, length: ns.length)
        for p in patterns {
            guard let re = try? NSRegularExpression(pattern: p),
                  let m = re.firstMatch(in: turn, range: full), m.numberOfRanges > 1 else { continue }
            let g = m.range(at: 1)
            guard g.location != NSNotFound else { continue }
            let raw = ns.substring(with: g).trimmingCharacters(in: CharacterSet(charactersIn: " .,?!'’\t\n"))
            if let v = tighten(raw) { return v }
        }
        return nil
    }

    private static let negators: Set<String> = ["not", "no", "never", "isn't", "isnt", "aren't", "arent", "wasn't", "wasnt"]
    private static let clauseBoundaries: Set<String> =
        ["but", "because", "and", "so", "my", "while", "although", "though", "if", "since", "or", "yet", "that", "which", "when"]

    /// Negated capture ⇒ nil (we can't infer the POSITIVE belief). Otherwise truncate at the first clause
    /// boundary and cap to 4 words (the {0,40} capture grabbed whole clauses → phantom beliefs that gaslit
    /// correct users). false-abstain over false-extract — returns nil if nothing survives.
    private static func tighten(_ raw: String) -> String? {
        var words = raw.split(separator: " ").map(String.init)
        guard let head = words.first?.lowercased(), !negators.contains(head) else { return nil }
        if let cut = words.firstIndex(where: { clauseBoundaries.contains($0.lowercased()) }) {
            words = Array(words.prefix(cut))
        }
        if words.count > 4 { words = Array(words.prefix(4)) }
        let v = words.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " .,?!'’"))
        return v.isEmpty ? nil : v
    }
}
