// MARK: - BASEvidenceMatcher
// ADR-020 Arc-2 — latent plumbing for evidence-resolving deliberation.
//
// PURE, deterministic, STRING-BASED key derivation + matching。 The
// matcher operates on plain strings (NOT on BASOrchestration types)
// so it stays in BASMemory (Foundation + BASRuntimeCore only)。
//
// ## The single key function
//
// `evidenceKey(contentType:content:)` is the ONE function that turns
// "a content type + some prose" into a stable matching key。 It is
// used for BOTH sides of a match:
//   - to derive the key an unknown-bucket VALUE would need
//     (e.g。 missingFacts: ["the budget"]),and
//   - to derive a `BASEvidenceAtom.evidenceKey` from its content。
// Because the SAME normalization runs on both sides,equal semantic
// content under the same content type → equal key。
//
// ## Anti-"theater" guarantee
//
// Matching is EXACT key equality only — never fuzzy,never Jaccard,
// never substring。 A near-miss prose atom must NOT resolve a required
// key。 The only tolerance is in `normalize` (case / whitespace /
// punctuation),which is deterministic + idempotent。
//
// DORMANT (ADR-020 Arc-2 Step 2a):nothing in production references
// this type yet。 Byte-equal-by-construction — no existing type is
// modified + nothing is wired into the runtime。

import Foundation

/// Pure, deterministic evidence-key derivation + matching over plain
/// strings + a `BASEvidenceLedger`。 No Date / Random / I/O — every
/// function is a pure function of its inputs。 See ADR-020 Arc-2。
public enum BASEvidenceMatcher {

    /// Default relevance floor an atom's confidence must reach to
    /// count as resolving evidence。 Reuses the repo's 0.3 relevance
    /// convention (the same floor used elsewhere for "is this signal
    /// strong enough to act on")。
    public static let defaultRelevanceFloor: Double = 0.3

    /// The separator between the content-type tag + the normalized
    /// content in an evidence key。 A colon mirrors the `"fact: …"` /
    /// `"role: …"` prefix convention used when recording unknown-set
    /// buckets (see `BASRoutedMirrorBladeRecording`)。
    private static let keySeparator = ":"

    /// The set of punctuation scalars stripped during normalization。
    /// Stripping punctuation is what lets `"$5."` + `"5"` normalize to
    /// the same token,so semantically-equal content matches。
    private static let punctuationToStrip: CharacterSet =
        .punctuationCharacters.union(.symbols)

    // MARK: - Normalization

    /// Normalize `raw` to a stable matching token:lowercased,
    /// punctuation + symbols stripped,whitespace collapsed to single
    /// spaces,trimmed。 Deterministic + idempotent
    /// (`normalize(normalize(x)) == normalize(x)`)。 No Date / Random。
    public static func normalize(_ raw: String) -> String {
        let lowered = raw.lowercased()
        // Strip punctuation + symbols by replacing each such scalar
        // with a space (so "a.b" → "a b",not "ab" — preserves token
        // boundaries),then collapse runs of whitespace below。
        let depunctuated = String(String.UnicodeScalarView(
            lowered.unicodeScalars.map { scalar in
                punctuationToStrip.contains(scalar) ? " " : scalar
            }))
        // Collapse any run of whitespace (incl。 the spaces we just
        // injected) to a single space,dropping empty pieces。
        let collapsed = depunctuated
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed
    }

    // MARK: - Key derivation

    /// The single evidence-matching key for `content` under
    /// `contentType`:`"<rawValue>:<normalized content>"`。 Used for
    /// BOTH an unknown-set bucket value + a `BASEvidenceAtom.content`,
    /// so equal semantic content under the same type → equal key。 The
    /// content-type tag means equal content under DIFFERENT types does
    /// NOT collide。 Pure。
    public static func evidenceKey(
        contentType: BASEvidenceContentType,
        content: String
    ) -> String {
        "\(contentType.rawValue)\(keySeparator)\(normalize(content))"
    }

    // MARK: - Resolution

    /// The subset of `requiredKeys` for which `ledger` holds at least
    /// one atom whose `evidenceKey` EXACTLY equals the required key AND
    /// whose `confidence >= relevanceFloor`。 EXACT key equality only
    /// (never fuzzy / substring) — the anti-"theater" guarantee。 Pure。
    ///
    /// - Parameters:
    ///   - requiredKeys: the keys to test (typically derived via
    ///     `evidenceKey` from a frame's unknown buckets)。
    ///   - ledger: the evidence store to query。
    ///   - relevanceFloor: minimum atom confidence to count as
    ///     resolving (default `defaultRelevanceFloor`)。
    /// - Returns: the resolved subset of `requiredKeys`。
    public static func resolvedKeys(
        requiredKeys: [String],
        in ledger: BASEvidenceLedger,
        relevanceFloor: Double = defaultRelevanceFloor
    ) -> Set<String> {
        var resolved: Set<String> = []
        for key in requiredKeys {
            let hit = ledger.matches(
                evidenceKey: key,
                relevanceFloor: relevanceFloor)
            if !hit.isEmpty {
                resolved.insert(key)
            }
        }
        return resolved
    }
}
