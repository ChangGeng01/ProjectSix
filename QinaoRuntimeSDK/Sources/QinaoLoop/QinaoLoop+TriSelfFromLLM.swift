import Foundation

// M289 — L10 tri-self tribunal real-LLM three-voice scoring.
//
// `triSelfScore(for:worldPriorContradiction:)` (M74) is a pure
// heuristic: numeric inputs in, weighted-formula concern out, fixed
// reason-code thresholds. That's enough to make the schema closed
// and testable, but it's also why honesty-board 24.8 lists "L10
// 真模型 vote" as a still-open candidate — three pretend-voices
// driven by three weighted sums aren't the same as guardian / scout /
// harmony genuinely speaking.
//
// M289 ships the pure helpers that let an LLM speak the three
// voices: a prompt builder that turns a `CandidateInput` into a
// structured prompt asking for `GUARDIAN/SCOUT/HARMONY concern:` +
// `reasons:` lines, and a parser that pulls the LLM's reply back
// into a `TriSelfScore`. Both are pure deterministic helpers — no
// I/O, no actor hop. Wiring them through an organ endpoint and
// folding the resulting score into the existing
// `triSelfScores(sessionID:)` lookup is a separate milestone (M290+).
//
// Doctrine
//
// - **Pure helpers only.** This file has no organ-endpoint
//   dependency, no async surface, no LLM call. The TDD path is
//   "given prompt text, given LLM reply text, what TriSelfScore?"
// - **Heuristic remains the fallback.** When LLM output can't be
//   parsed into all three voices, the parser invokes the supplied
//   fallback closure (typically returning the M74 heuristic
//   score). Hybrid output ("LLM said guardian, heuristic said
//   scout/harmony") is forbidden — too brittle and too hard to
//   audit. Either the LLM speaks all three voices cleanly or we
//   fall back wholesale.
// - **Reason code grammar matches M74.** The parser extracts
//   comma-separated reason strings; downstream audit code already
//   keys on the M74 vocabulary
//   (manipulation-risk / evidence-gap / emotional-bias / etc.).
//   The parser does not validate vocabulary — it trusts the LLM
//   to use the right codes when prompted correctly. Out-of-vocab
//   reasons are accepted verbatim so future expansion doesn't
//   require parser changes.

extension QinaoLoop {

    /// M289 — build a tri-self tribunal prompt for one candidate.
    /// The output text instructs the LLM to play guardian / scout /
    /// harmony in turn and reply in a parseable line-oriented format.
    ///
    /// Stable surface: same `(candidate, wpc)` pair always produces
    /// the same prompt text byte-for-byte. Tests pin the section
    /// headers and key fields so prompt drift is caught.
    public static func makeTriSelfPrompt(
        for candidate: CandidateInput,
        worldPriorContradiction: Double
    ) -> String {
        let wpc = clampUnit(worldPriorContradiction)
        return """
            You are a three-voice tribunal judging one candidate action. \
            Speak as each voice in turn.

            VOICES
            - GUARDIAN: protector. Cares about manipulation pressure, \
            host-boundary conflict, world-prior contradiction.
            - SCOUT: explorer. Cares about evidence gaps, low \
            confidence, low expected benefit.
            - HARMONY: reconciler. Cares about emotional bias, low \
            reversibility (cost of regret).

            CANDIDATE
            - id: \(candidate.candidateID)
            - title: \(candidate.title)
            - action: \(candidate.actionSummary)
            - expected_benefit: \(formatUnit(candidate.expectedBenefit))
            - expected_cost: \(formatUnit(candidate.expectedCost))
            - reversibility: \(formatUnit(candidate.reversibility))
            - confidence: \(formatUnit(candidate.confidence))
            - evidence_gap: \(formatUnit(candidate.evidenceGap))
            - manipulation_risk: \(formatUnit(candidate.manipulationRisk))
            - emotional_bias: \(formatUnit(candidate.emotionalBias))
            - boundary_conflict: \(formatUnit(candidate.boundaryConflict))
            - world_prior_contradiction: \(formatUnit(wpc))

            REPLY FORMAT (each line exactly once, in this order):
            GUARDIAN concern: <0.0-1.0>
            GUARDIAN reasons: <comma-separated reason codes, or empty>
            SCOUT concern: <0.0-1.0>
            SCOUT reasons: <comma-separated reason codes, or empty>
            HARMONY concern: <0.0-1.0>
            HARMONY reasons: <comma-separated reason codes, or empty>
            """
    }

    /// M289 — parse a tri-self LLM reply into a `TriSelfScore`.
    /// When any voice's concern line is missing or unparseable, the
    /// parser invokes the `fallback` closure and returns its result
    /// instead — hybrid output is forbidden by doctrine.
    ///
    /// - Parameters:
    ///   - llmOutput: raw text from the organ endpoint.
    ///   - candidateID: identity of the candidate (forwarded into
    ///     the resulting `TriSelfScore`).
    ///   - fallback: closure producing the heuristic `TriSelfScore`
    ///     to return on parse failure. Typically wraps
    ///     `triSelfScore(for:worldPriorContradiction:)`.
    /// - Returns: an `LLMTriSelfParseResult` whose `usedLLM` flag
    ///   tells callers whether the LLM output drove the score
    ///   (`true`) or the fallback did (`false`).
    public static func parseTriSelfScore(
        from llmOutput: String,
        candidateID: String,
        fallback: () -> TriSelfScore
    ) -> LLMTriSelfParseResult {
        guard let g = extractVoice(
            "guardian", from: llmOutput),
              let s = extractVoice(
                  "scout", from: llmOutput),
              let h = extractVoice(
                  "harmony", from: llmOutput)
        else {
            return LLMTriSelfParseResult(
                score: fallback(), usedLLM: false)
        }
        let dominant = dominantTriSelfVoice(
            guardian: g.concern,
            scout: s.concern,
            harmony: h.concern)
        let score = TriSelfScore(
            candidateID: candidateID,
            guardVoice: TriSelfVoiceReading(
                concern: g.concern, reasonCodes: g.reasons),
            scoutVoice: TriSelfVoiceReading(
                concern: s.concern, reasonCodes: s.reasons),
            harmonyVoice: TriSelfVoiceReading(
                concern: h.concern, reasonCodes: h.reasons),
            dominantVoice: dominant)
        return LLMTriSelfParseResult(
            score: score, usedLLM: true)
    }

    /// Result envelope letting callers tell LLM-driven scores from
    /// fallback-driven ones for audit.
    public struct LLMTriSelfParseResult: Equatable, Sendable {
        public let score: TriSelfScore
        public let usedLLM: Bool
        public init(score: TriSelfScore, usedLLM: Bool) {
            self.score = score
            self.usedLLM = usedLLM
        }
    }

    // MARK: - Internal helpers

    /// Extract one voice's concern + reasons. Returns nil if the
    /// concern line is missing or unparseable. Reasons line is
    /// optional — missing reasons line yields empty array (the
    /// voice spoke but flagged nothing).
    static func extractVoice(
        _ voice: String, from text: String
    ) -> (concern: Double, reasons: [String])? {
        let lower = text.lowercased()
        let voiceLower = voice.lowercased()
        guard let concern = extractConcern(
            voice: voiceLower, in: lower)
        else { return nil }
        let reasons = extractReasons(
            voice: voiceLower, in: lower)
        return (clampUnit(concern), reasons)
    }

    /// Extract `<voice> concern: <number>` from lowercased text.
    static func extractConcern(
        voice: String, in lower: String
    ) -> Double? {
        let prefix = "\(voice) concern:"
        for line in lower.split(
            whereSeparator: { $0 == "\n" || $0 == "\r" })
        {
            let trimmed = line.trimmingCharacters(
                in: .whitespaces)
            if trimmed.hasPrefix(prefix) {
                let after = trimmed.dropFirst(prefix.count)
                    .trimmingCharacters(in: .whitespaces)
                if let value = Double(after) {
                    return value
                }
                // Allow trailing junk: "0.7 (high)" → take leading
                // numeric prefix if present.
                let head = after.prefix(
                    while: { $0.isNumber || $0 == "." || $0 == "-" })
                if let value = Double(head), !head.isEmpty {
                    return value
                }
                return nil
            }
        }
        return nil
    }

    /// Extract `<voice> reasons: a, b, c` from lowercased text.
    /// Returns empty array if the reasons line is missing or has
    /// nothing after the colon.
    static func extractReasons(
        voice: String, in lower: String
    ) -> [String] {
        let prefix = "\(voice) reasons:"
        for line in lower.split(
            whereSeparator: { $0 == "\n" || $0 == "\r" })
        {
            let trimmed = line.trimmingCharacters(
                in: .whitespaces)
            if trimmed.hasPrefix(prefix) {
                let after = trimmed.dropFirst(prefix.count)
                    .trimmingCharacters(in: .whitespaces)
                if after.isEmpty { return [] }
                return after.split(separator: ",")
                    .map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }
                    .filter { !$0.isEmpty }
            }
        }
        return []
    }

    /// Format a [0,1] value as `"0.42"` (2 decimals) for stable
    /// prompt strings. Idempotent for tests.
    static func formatUnit(_ x: Double) -> String {
        let clamped = clampUnit(x)
        return String(format: "%.2f", clamped)
    }
}
