// MARK: - BASAgentPersonaForbiddenDetector
// chapter 九百六十九 / M3550 — Phase 4 close:Forbidden persona detector
//
// User design Section 11.5 + plan PHASE 4 ch4 (close):reject
// personas that match known-harmful patterns,specifically:
//
//   - shame:high challenge + low warmth + low guard + cold tone
//     (designed to make user feel bad rather than help)
//   - gaslight:high directness + high skepticism + ZERO warmth +
//     ZERO comparison (designed to dismiss the user's perception)
//   - absolute-paternal:high challenge + zero comparison + zero
//     creativity + warm tone (paternal-but-controlling — "I know
//     best,no alternatives")
//   - controlling:low comparison + low creativity + high challenge
//     + zero guard (rigid + aggressive)
//
// Per plan Phase 4 close + ch 944 audit:these are NOT a substitute
// for sovereign clamp;they are an ADDITIONAL safety filter that
// catches forbidden patterns ANYTIME — including HIGH-tier overlays
// that pass through Risk + Sovereign clamps but still compose into
// a harmful pattern。
//
// ## Detector,not gate
//
// The detector RETURNS findings;it does NOT block。 The caller
// (`BASAgentPersonaSDK.createAgentPersona`) decides whether to
// reject + audit。 This separation lets the SDK + audit layer
// adapt policy per consumer without changing the detector itself。
//
// ## Pure-fn discipline
//
// Same as ch 957-968 — pure function,no actor,no I/O。 Bounded
// by 4 patterns × 1 persona = constant time。 No DoS surface。
//
// ## Why pattern-based not ML
//
// Per ch 944 H2 + plan:detection MUST be deterministic +
// auditable + explainable。 Pattern-based rules are 100%
// replayable + reason-codeable for the audit ledger。 An ML
// classifier would add uncertainty + opacity that ch 944
// review flagged as unacceptable for safety-critical filters。

import Foundation

// MARK: - Pattern enum

/// 4 known forbidden persona patterns。 Pin asserted by ch 969
/// tests:`allCases.count == 4`。 Future patterns added here MUST
/// bump the pin + come with regression tests。
public enum BASAgentPersonaForbiddenPattern: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    case shame
    case gaslight
    case absolutePaternal
    case controlling
}

// MARK: - Finding

public struct BASAgentPersonaForbiddenFinding:
    Sendable, Equatable, Hashable, Codable
{
    public let pattern: BASAgentPersonaForbiddenPattern
    /// 0.0-1.0 — how strongly the persona matches the pattern。
    /// 1.0 = textbook match;0.5 = ambiguous;< 0.5 not reported。
    public let matchScore: Double
    /// Specific field values that contributed to the match,
    /// for audit trail。 Sorted for deterministic replay。
    public let evidence: [String]

    public init(
        pattern: BASAgentPersonaForbiddenPattern,
        matchScore: Double,
        evidence: [String] = []
    ) {
        self.pattern = pattern
        self.matchScore = matchScore
        self.evidence = evidence.sorted()
    }
}

// MARK: - Detector

public enum BASAgentPersonaForbiddenDetector {

    /// Match-score threshold — findings below this score are
    /// not reported。 Plan/ch 969 default 0.6 — strong-enough
    /// signal to flag。 Caller can post-filter further。
    public static let defaultReportThreshold: Double = 0.6

    /// Scan a composed persona against all 4 forbidden patterns。
    /// Returns sorted (by pattern enum order) findings ≥
    /// threshold。 Empty = no forbidden patterns detected。
    public static func scan(
        _ persona: BASAgentPersonaSpec,
        reportThreshold: Double = defaultReportThreshold
    ) -> [BASAgentPersonaForbiddenFinding] {
        var findings: [BASAgentPersonaForbiddenFinding] = []
        for pattern in
            BASAgentPersonaForbiddenPattern.allCases
        {
            let f = score(persona, pattern: pattern)
            if f.matchScore >= reportThreshold {
                findings.append(f)
            }
        }
        return findings.sorted {
            $0.pattern.rawValue < $1.pattern.rawValue
        }
    }

    /// True if persona matches ANY forbidden pattern above
    /// the threshold。 Convenience for callers who don't need
    /// detailed findings。
    public static func anyForbidden(
        _ persona: BASAgentPersonaSpec,
        reportThreshold: Double = defaultReportThreshold
    ) -> Bool {
        !scan(persona,
              reportThreshold: reportThreshold).isEmpty
    }

    // MARK: - Per-pattern scoring

    private static func score(
        _ p: BASAgentPersonaSpec,
        pattern: BASAgentPersonaForbiddenPattern
    ) -> BASAgentPersonaForbiddenFinding {
        switch pattern {
        case .shame:
            return scoreShame(p)
        case .gaslight:
            return scoreGaslight(p)
        case .absolutePaternal:
            return scoreAbsolutePaternal(p)
        case .controlling:
            return scoreControlling(p)
        }
    }

    /// Shame:high challenge (≥ 0.75) + low warmth (≤ 0.20) +
    /// low guard (≤ 0.20) + cold/formal tone。 4 contributors,
    /// each worth 0.25 of match score。
    private static func scoreShame(
        _ p: BASAgentPersonaSpec
    ) -> BASAgentPersonaForbiddenFinding {
        var score = 0.0
        var evidence: [String] = []
        if p.challengeIntensity >= 0.75 {
            score += 0.25
            evidence.append(formatEv(
                "challenge", p.challengeIntensity, "≥0.75"))
        }
        if p.warmth <= 0.20 {
            score += 0.25
            evidence.append(formatEv(
                "warmth", p.warmth, "≤0.20"))
        }
        if p.guardBias <= 0.20 {
            score += 0.25
            evidence.append(formatEv(
                "guard", p.guardBias, "≤0.20"))
        }
        if isColdTone(p.tone) {
            score += 0.25
            evidence.append("tone=\(p.tone)(cold)")
        }
        return BASAgentPersonaForbiddenFinding(
            pattern: .shame,
            matchScore: score,
            evidence: evidence)
    }

    /// Gaslight:high directness (≥ 0.80) + high skepticism
    /// (≥ 0.80) + zero warmth (≤ 0.15) + zero comparison
    /// (≤ 0.15)。 4 contributors。
    private static func scoreGaslight(
        _ p: BASAgentPersonaSpec
    ) -> BASAgentPersonaForbiddenFinding {
        var score = 0.0
        var evidence: [String] = []
        if p.directness >= 0.80 {
            score += 0.25
            evidence.append(formatEv(
                "directness", p.directness, "≥0.80"))
        }
        if p.skepticism >= 0.80 {
            score += 0.25
            evidence.append(formatEv(
                "skepticism", p.skepticism, "≥0.80"))
        }
        if p.warmth <= 0.15 {
            score += 0.25
            evidence.append(formatEv(
                "warmth", p.warmth, "≤0.15"))
        }
        if p.comparisonBias <= 0.15 {
            score += 0.25
            evidence.append(formatEv(
                "comparison", p.comparisonBias, "≤0.15"))
        }
        return BASAgentPersonaForbiddenFinding(
            pattern: .gaslight,
            matchScore: score,
            evidence: evidence)
    }

    /// Absolute-paternal:high challenge (≥ 0.65) + zero
    /// comparison (≤ 0.20) + zero creativity (≤ 0.20) + warm
    /// tone。 The "warm voice giving rigid orders" pattern。
    private static func scoreAbsolutePaternal(
        _ p: BASAgentPersonaSpec
    ) -> BASAgentPersonaForbiddenFinding {
        var score = 0.0
        var evidence: [String] = []
        if p.challengeIntensity >= 0.65 {
            score += 0.25
            evidence.append(formatEv(
                "challenge", p.challengeIntensity, "≥0.65"))
        }
        if p.comparisonBias <= 0.20 {
            score += 0.25
            evidence.append(formatEv(
                "comparison", p.comparisonBias, "≤0.20"))
        }
        if p.creativityBias <= 0.20 {
            score += 0.25
            evidence.append(formatEv(
                "creativity", p.creativityBias, "≤0.20"))
        }
        // chapter 九百六十九.5 USER-PASS-6 H4 fix:absolute-
        // paternal requires BOTH warm-tone AND high-warmth (the
        // "warm voice giving rigid orders" pattern requires BOTH
        // signals)。 Previously OR-logic produced false positives
        // for tone="warm"/warmth=0.10 + tone="cool"/warmth=0.90
        // mismatches。
        if isWarmTone(p.tone) && p.warmth >= 0.5 {
            score += 0.25
            let evStr =
                "tone=\(p.tone)/warmth=\(formatNum(p.warmth))"
            evidence.append("\(evStr)(warm-AND-warmth)")
        }
        return BASAgentPersonaForbiddenFinding(
            pattern: .absolutePaternal,
            matchScore: score,
            evidence: evidence)
    }

    /// Controlling:low comparison (≤ 0.20) + low creativity
    /// (≤ 0.20) + high challenge (≥ 0.70) + zero guard (≤ 0.20)。
    /// Rigid + aggressive + unbounded。
    private static func scoreControlling(
        _ p: BASAgentPersonaSpec
    ) -> BASAgentPersonaForbiddenFinding {
        var score = 0.0
        var evidence: [String] = []
        if p.comparisonBias <= 0.20 {
            score += 0.25
            evidence.append(formatEv(
                "comparison", p.comparisonBias, "≤0.20"))
        }
        if p.creativityBias <= 0.20 {
            score += 0.25
            evidence.append(formatEv(
                "creativity", p.creativityBias, "≤0.20"))
        }
        if p.challengeIntensity >= 0.70 {
            score += 0.25
            evidence.append(formatEv(
                "challenge", p.challengeIntensity, "≥0.70"))
        }
        if p.guardBias <= 0.20 {
            score += 0.25
            evidence.append(formatEv(
                "guard", p.guardBias, "≤0.20"))
        }
        return BASAgentPersonaForbiddenFinding(
            pattern: .controlling,
            matchScore: score,
            evidence: evidence)
    }

    // MARK: - Helpers

    private static func isColdTone(_ tone: String) -> Bool {
        ["cool", "cold", "formal", "clinical", "detached"]
            .contains(tone.lowercased())
    }

    private static func isWarmTone(_ tone: String) -> Bool {
        ["warm", "playful", "friendly", "empathetic"]
            .contains(tone.lowercased())
    }

    private static func formatNum(_ v: Double) -> String {
        String(format: "%.3f", v)
    }

    private static func formatEv(
        _ field: String, _ value: Double, _ rule: String
    ) -> String {
        "\(field)=\(formatNum(value))\(rule)"
    }
}
