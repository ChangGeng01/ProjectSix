// SPDX-License-Identifier: Apache-2.0
// M549-M554 (chapter 一百三十七) — Audit Explainability Bench per
// Appendix Q.2.3.
//
// ## Why this exists
//
// 假设 #3 in user audit: "honest satisfaction is a meaningful
// metric — maybe '~99.97%' is self-audit theater, external
// observer doesn't care". This bench tests the assumption by
// asking an LLM-as-judge to reconstruct system decisions from
// audit reason codes alone.
//
// **Hypothesis**: if audit trail is reconstructable by external
// LLM judge, the trail carries genuine information; if confidence
// is low (< 60), the codes are opaque jargon and "honest
// satisfaction" is theater.
//
// ## Design
//
// Pure value-typed bench:
//   1. Take N audit signalRefs strings (per turn output)
//   2. Construct LLM-as-judge prompt asking for reconstruction
//   3. Send through any `QinaoOrganEndpoint` (AFM, MLX, or
//      deterministic fallback)
//   4. Parse confidence score from response
//   5. Aggregate across N turns
//
// Deterministic-fallback path lets unit tests verify plumbing
// without real LLM. AFM-gated test verifies real LLM-as-judge.
//
// ## Reuses
//
// - `QinaoOrganEndpoint.produceBody(prompt:context:role:sessionID:)`
//   protocol from `QinaoLoop/QinaoOrganEndpoint.swift`
// - Sample-host mode pattern from M306 chapter 七十一 / M328
//   `--*-demo` arg dispatch

import Foundation

/// Per-turn audit explainability score derived from LLM-as-judge
/// reconstruction prompt.
public struct AuditExplainabilityScore: Sendable, Equatable {
    /// Confidence integer 0-100 parsed from response. 0 when
    /// response doesn't contain a "CONFIDENCE: NN" line.
    public let confidence: Int
    /// Total characters in the LLM response. Larger response =
    /// LLM had more to say about the trail; tiny response often
    /// indicates "I don't know".
    public let responseLength: Int
    /// `true` if response contains decision-related keywords
    /// (decision/permit/verdict/risk). Catches LLM responses
    /// that don't engage with the trail at all.
    public let containsDecisionKeywords: Bool
    /// Stable identifier to anchor the score back to its source
    /// turn (e.g. session-turn ID).
    public let turnID: String

    public init(
        confidence: Int,
        responseLength: Int,
        containsDecisionKeywords: Bool,
        turnID: String
    ) {
        self.confidence = max(0, min(100, confidence))
        self.responseLength = responseLength
        self.containsDecisionKeywords =
            containsDecisionKeywords
        self.turnID = turnID
    }
}

/// Aggregate audit explainability over N turns.
public struct AuditExplainabilityAggregate: Sendable, Equatable
{
    /// Median confidence across all turns. Anti-magic-number:
    /// 50 = "could go either way";<60 = trail opaque;>80 =
    /// trail reconstructable.
    public let medianConfidence: Int
    /// 25th percentile confidence (catches worst-case turns).
    public let p25Confidence: Int
    /// 75th percentile confidence.
    public let p75Confidence: Int
    /// Count of turns scored.
    public let turnCount: Int
    /// Per-turn raw scores for spot-check.
    public let scores: [AuditExplainabilityScore]

    public init(
        medianConfidence: Int,
        p25Confidence: Int,
        p75Confidence: Int,
        turnCount: Int,
        scores: [AuditExplainabilityScore]
    ) {
        self.medianConfidence = medianConfidence
        self.p25Confidence = p25Confidence
        self.p75Confidence = p75Confidence
        self.turnCount = turnCount
        self.scores = scores
    }
}

/// Pure-function bench namespace. Plumbing-only — tests pass any
/// `QinaoOrganEndpoint` (AFM / MLX / deterministic stub).
public enum AuditExplainabilityBench {

    /// Evaluate a single turn's audit trail.
    public static func evaluate(
        signalRefs: [String],
        turnID: String,
        endpoint: any QinaoOrganEndpoint,
        sessionID: String
    ) async throws -> AuditExplainabilityScore {
        let prompt = buildPrompt(signalRefs: signalRefs)
        let response = try await endpoint.produceBody(
            prompt: prompt,
            context: [],
            role: .scout,
            sessionID: sessionID)
        return AuditExplainabilityScore(
            confidence: parseConfidence(
                response.body),
            responseLength: response.body.count,
            containsDecisionKeywords: containsDecisionKeywords(
                in: response.body),
            turnID: turnID)
    }

    /// Aggregate explainability across N turns.
    public static func aggregate(
        scores: [AuditExplainabilityScore]
    ) -> AuditExplainabilityAggregate {
        guard !scores.isEmpty else {
            return AuditExplainabilityAggregate(
                medianConfidence: 0,
                p25Confidence: 0,
                p75Confidence: 0,
                turnCount: 0,
                scores: [])
        }
        let sorted = scores
            .map(\.confidence)
            .sorted()
        let median = sorted[sorted.count / 2]
        let p25 = sorted[max(0, sorted.count / 4)]
        let p75 = sorted[
            min(sorted.count - 1, (sorted.count * 3) / 4)]
        return AuditExplainabilityAggregate(
            medianConfidence: median,
            p25Confidence: p25,
            p75Confidence: p75,
            turnCount: scores.count,
            scores: scores)
    }

    /// **Confidence threshold for "trail is opaque jargon"**:
    /// median < 60 means audit codes can't be reconstructed by
    /// external LLM judge → honest-satisfaction claim is broken.
    /// Anti-magic-number: named static.
    public static let opaqueTrailThreshold: Int = 60

    /// **Confidence threshold for "trail is reconstructable"**:
    /// median > 80 means audit codes carry genuine information
    /// → honest-satisfaction claim is supported.
    public static let reconstructableTrailThreshold: Int = 80

    // MARK: - Internal helpers

    /// Build the LLM-as-judge reconstruction prompt. Stable shape
    /// for cross-bench comparison.
    public static func buildPrompt(
        signalRefs: [String]
    ) -> String {
        """
        Below are audit reason codes from a single turn of a
        decision system. Each code is a stable string identifier.

        Codes:
        \(signalRefs.joined(separator: "\n"))

        Reading ONLY these codes (no other context):

        1. What decision did the system most likely make this turn?
        2. List the top 3 reasons supporting that decision.
        3. Did the system consider any red-line constraints?

        End your response with a single line: "CONFIDENCE: NN"
        where NN is an integer 0-100 indicating how confidently
        you can reconstruct the decision from these codes alone.
        Use 0 for "no idea", 100 for "fully reconstructable".
        """
    }

    /// Parse "CONFIDENCE: NN" line. Returns 0 if not found or
    /// malformed.
    public static func parseConfidence(
        _ text: String
    ) -> Int {
        let lowered = text.lowercased()
        guard let range = lowered.range(
            of: "confidence:")
        else { return 0 }
        let after = text[range.upperBound...]
        // Take first 16 chars after the marker, look for digits.
        let prefix = String(after.prefix(16))
        let digitChars = prefix.filter {
            $0.isNumber || $0.isWhitespace || $0 == "."
        }
        let trimmed = digitChars
            .trimmingCharacters(in: .whitespaces)
        let firstToken = trimmed.split(
            separator: " ").first
            ?? trimmed.split(separator: "\n").first
            ?? Substring(trimmed)
        let intPart = firstToken.split(separator: ".").first
            ?? firstToken
        return Int(String(intPart)) ?? 0
    }

    /// Check if response engages with decision content.
    public static func containsDecisionKeywords(
        in text: String
    ) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("decision")
            || lowered.contains("permit")
            || lowered.contains("verdict")
            || lowered.contains("risk")
            || lowered.contains("reason")
    }
}
