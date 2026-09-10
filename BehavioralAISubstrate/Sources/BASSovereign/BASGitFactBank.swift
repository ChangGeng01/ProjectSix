// MARK: - BASGitFactBank — the git-self-grounding fact bank (The Ledger, grounding increment 1)
//
// The panel's seed made concrete: "the git log IS the fact source." The operator's own commit
// history is an external, tamper-evident, append-only RECORD, so a journal claim that CITES a
// commit (a commit-qualified SHA token) or a marker (#N / H\d+ / M\d+ / ch\d+) can be resolved by
// pure, deterministic Set-membership — no model, no network, no external oracle. This respects the
// 4B hard lesson (retrieval-vs-factual-sycophancy): the model is NEVER asked "is this claim true";
// the git record adjudicates, a pure function disposes.
//
// ── What this grounds (and what it deliberately does not) ────────────────────────────────────
// It checks RECORD-CONSISTENCY of structured citations only: "does the commit you cited exist in
// the record" (.agrees) / "the SHA you cited is a prefix of NO commit" (.contradicts — the
// fabricated/misremembered-citation catch). It does NOT ground paraphrased prose (a claim
// describing a ship in words with no SHA/marker abstains — the false-abstain-over-false-adjudicate
// doctrine, same as BASFactBank), does NOT judge whether a decision was right, and never
// contradicts on an unmatched issue marker (an issue is legitimately discussed before its commit
// exists ⇒ markers are AGREES-ONLY).
//
// Abstain bias, enforced structurally:
//   • a hex run must be COMMIT-QUALIFIED (preceded by a context word, or parenthesized) — bare hex
//     ("the badge color deadbee1") abstains;
//   • a hex run must contain ≥1 digit — all-letter hex-shaped English words ("defaced") abstain;
//   • an unmatched marker abstains; git unavailable is the CALLER's honest `unavailable`, never a
//     fabricated match.

import Foundation

public enum BASGitFactBank {

    /// The ingested record: a pure function of `git log --format=%H%x09%s` bytes — reproducible.
    public struct GitFacts: Sendable, Equatable {
        /// 7- and 8-char SHA prefixes (O(1) membership for the two common citation lengths).
        public let prefixes7: Set<String>
        public let prefixes8: Set<String>
        /// Full 40-char SHAs (prefix scan for longer citations).
        public let fullShas: [String]
        /// Lowercased markers extracted from subjects: #N / hN / mN / chN.
        public let markers: Set<String>
        /// Subject line by canonical 8-char prefix (reference display / telemetry).
        public let subjectBySha8: [String: String]

        public var isEmpty: Bool { fullShas.isEmpty }
    }

    /// One resolved citation: the cited token, the matched commit's canonical sha8 (SHA matches
    /// only — a marker names no single commit), and the record-consistency ground truth.
    public typealias Resolution = (token: String, sha8: String?, truth: BASFactualBeliefAdjudicator.GroundTruth)

    // MARK: - ingest (pure parse)

    /// Parse `git log --no-merges --format=%H%x09%s` output into the fact record. Malformed lines
    /// (no tab / non-40-hex sha) are skipped — the bank stays clean, never guesses.
    public static func ingest(gitLog: String) -> GitFacts {
        var p7: Set<String> = [], p8: Set<String> = []
        var fulls: [String] = []
        var markers: Set<String> = []
        var subjects: [String: String] = [:]
        for line in gitLog.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let tab = line.firstIndex(of: "\t") else { continue }
            let sha = String(line[..<tab]).lowercased()
            let subject = String(line[line.index(after: tab)...])
            guard sha.count == 40, sha.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else { continue }
            fulls.append(sha)
            p7.insert(String(sha.prefix(7)))
            p8.insert(String(sha.prefix(8)))
            subjects[String(sha.prefix(8))] = subject
            markers.formUnion(extractMarkers(from: subject))
        }
        return GitFacts(prefixes7: p7, prefixes8: p8, fullShas: fulls,
                        markers: markers, subjectBySha8: subjects)
    }

    // MARK: - resolve (pure Set-membership adjudication)

    /// Resolve a journal claim against the record. Returns nil (⇒ caller abstains, byte-parity with
    /// the ungrounded seal) when the claim carries no resolvable citation. Fail-closed priority: a
    /// fabricated SHA (`.contradicts`) outranks any co-present match — surfacing the bad citation is
    /// the protective outcome.
    public static func resolve(claim: String, facts: GitFacts) -> Resolution? {
        guard !facts.isEmpty else { return nil }
        let lower = claim.lowercased()
        let words = lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)

        // 1) SHA citations — the primary, contradicts-capable signal.
        var firstMatch: Resolution?
        for (i, w) in words.enumerated() where isShaShaped(w) {
            let qualified = (i > 0 && Self.contextWords.contains(words[i - 1]))
                || lower.contains("(\(w))")
            guard qualified else { continue }
            if let full = lookup(w, in: facts) {
                if firstMatch == nil { firstMatch = (w, String(full.prefix(8)), .agrees) }
            } else {
                return (w, nil, .contradicts)   // fabricated citation — fail-closed, outranks matches
            }
        }
        if let m = firstMatch { return m }

        // 2) Markers — AGREES-ONLY (absent marker ⇒ abstain, never contradicts).
        for marker in extractMarkers(from: lower) where facts.markers.contains(marker) {
            return (marker, nil, .agrees)
        }
        return nil
    }

    // MARK: - helpers

    /// Words that qualify the FOLLOWING hex token as a commit citation. Deliberately excludes
    /// "sealed" — the journal's own seal IDs are hex and must not be checked against the git log.
    static let contextWords: Set<String> = [
        "commit", "commits", "sha", "shas", "rev", "revision",
        "merged", "landed", "pushed", "shipped",
    ]

    /// Hex-shaped citation candidate: 7–40 hex chars AND ≥1 digit (all-letter hex-shaped English
    /// words — "defaced", "accede" — abstain; a real SHA prefix is all-letters ~0.1% of the time,
    /// the acceptable cost of the abstain bias).
    static func isShaShaped(_ w: String) -> Bool {
        w.count >= 7 && w.count <= 40
            && w.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) }
            && w.contains(where: \.isNumber)
    }

    private static func lookup(_ token: String, in facts: GitFacts) -> String? {
        switch token.count {
        case 7: return facts.prefixes7.contains(token)
            ? facts.fullShas.first { $0.hasPrefix(token) } : nil
        case 8: return facts.prefixes8.contains(token)
            ? facts.fullShas.first { $0.hasPrefix(token) } : nil
        default: return facts.fullShas.first { $0.hasPrefix(token) }
        }
    }

    /// Markers in `text`, lowercased: `#N` (scanned with adjacency to digits) and word-bounded
    /// hN / mN / chN tokens (the repo's audit/chapter convention).
    static func extractMarkers(from text: String) -> Set<String> {
        var out: Set<String> = []
        let lower = text.lowercased()
        // #N — '#' is stripped by word tokenization, so scan it directly.
        var idx = lower.startIndex
        while let hash = lower[idx...].firstIndex(of: "#") {
            var j = lower.index(after: hash)
            var digits = ""
            while j < lower.endIndex, lower[j].isNumber { digits.append(lower[j]); j = lower.index(after: j) }
            if !digits.isEmpty { out.insert("#\(digits)") }
            idx = j
        }
        // hN / mN / chN as whole word-tokens.
        for w in lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            for prefix in ["ch", "h", "m"] where w.hasPrefix(prefix) {
                let rest = w.dropFirst(prefix.count)
                if !rest.isEmpty, rest.allSatisfy(\.isNumber) { out.insert(String(w)); break }
            }
        }
        return out
    }
}
