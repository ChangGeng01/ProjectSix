// MARK: - Gaslight + ToolInjection Watchers
// chapter 九百七十一 / M3560 — Phase 5 ch2:2 more watchers
//
// User design Section 9.8 + plan PHASE 5 ch2:
//   - GaslightWatcher — detects gaslight-pattern prompts that
//     try to make the user doubt their own perception。 Uses
//     keyword/phrase patterns (deterministic per ch 944 H2 —
//     no ML)。
//   - ToolInjectionWatcher — detects prompt-injection in MCP /
//     A2A tool input。 Scans for known injection signatures。
//
// Both are READ-ONLY,emit BASAgentWatcherHint records only。
// LOW risk per plan。
//
// ## Pattern-based,not ML
//
// Per ch 944 H2 + plan:detection MUST be deterministic +
// auditable + explainable。 Pattern-based scoring is 100%
// replayable for the audit ledger。

import Foundation

// MARK: - GaslightWatcher

/// Detects gaslight-pattern prompts in scout signals + bare
/// contradictions。 The gaslight pattern in a USER-facing prompt
/// (vs persona-overlay form which is ch 969's job) has its own
/// signature:absolute statements ("you always X"/"you never Y"),
/// reality-denial phrases ("that didn't happen" / "you're imagining"),
/// emotional invalidation ("you're being too sensitive"),and
/// trust-erosion ("you can't trust your own memory")。
public enum BASGaslightWatcher: BASAgentWatcher {
    public static let role: BASAgentRole = .gaslightWatcher

    /// SEALED pattern set — case-insensitive substring match。
    /// Each match contributes 0.25 to the score (4-of-N
    /// contributors at score 0.25 each → threshold 0.6 needs 3
    /// distinct categories matched)。
    public static let absolutePatterns: [String] = [
        "you always", "you never",
        "everyone knows", "obviously",
    ]
    public static let realityDenialPatterns: [String] = [
        "didn't happen", "imagining things",
        "making this up", "not real",
    ]
    public static let emotionalInvalidation: [String] = [
        "too sensitive", "overreacting",
        "being dramatic", "calm down",
    ]
    public static let trustErosion: [String] = [
        "can't trust", "your memory is",
        "you misremember", "remember wrong",
    ]

    public static let reportThreshold: Double = 0.5

    public static func observe(
        _ obs: BASAgentWatcherObservation,
        seq: inout Int
    ) -> [BASAgentWatcherHint] {
        // Scan pressure signals + bare contradictions for
        // pattern matches。 These are the user-facing string
        // payloads scout exposed for inspection。
        let scanSource =
            obs.scout.pressureSignals +
            obs.scout.bareContradictions
        if scanSource.isEmpty { return [] }
        let joined = scanSource.joined(separator: " ")
            .lowercased()

        var score = 0.0
        var evidence: [String] = []
        let categories: [(String, [String])] = [
            ("absolute", absolutePatterns),
            ("reality-denial", realityDenialPatterns),
            ("emotional-invalidation", emotionalInvalidation),
            ("trust-erosion", trustErosion),
        ]
        for (catName, patterns) in categories {
            for p in patterns {
                if joined.contains(p) {
                    score += 0.25
                    evidence.append(
                        "gaslight.\(catName)=\(p)")
                    break  // one match per category counts
                }
            }
        }
        if score < reportThreshold { return [] }

        seq += 1
        let scoreStr = String(format: "%.3f", score)
        return [BASAgentWatcherHint(
            hintID: "hint.\(obs.turnID).gaslight.\(seq)",
            turnID: obs.turnID,
            watcherRole: role,
            severity: severity(score: score),
            category: "gaslight.pattern-match",
            summary:
                "gaslight pattern matched at score \(scoreStr) " +
                "(≥ \(reportThreshold) threshold) across " +
                "\(evidence.count) categories",
            evidence: evidence,
            confidence: score,
            nowNanos: obs.nowNanos)]
    }

    /// Severity scales with match score。 4-of-4 = veto (escalate
    /// to L14 — textbook gaslight)。 3-of-4 = alert。 2-of-4 =
    /// watch。
    private static func severity(
        score: Double
    ) -> BASAgentWatcherSeverity {
        if score >= 1.0 { return .veto }
        if score >= 0.75 { return .alert }
        return .watch
    }
}

// MARK: - ToolInjectionWatcher

/// Detects prompt-injection patterns in MCP/A2A tool inputs。
/// Since ch 970-971 don't have the MCP/A2A surface wired yet
/// (Phase 7 work),this watcher inspects the SCOUT signal layer
/// + bare contradictions for the same injection-style patterns
/// that real MCP tool outputs might smuggle。
///
/// Per ch 956.11 H2:bounded by input size。 Per plan ch 977:
/// Phase 7 A2A will route external agent outputs through this
/// watcher's pattern set as the first filter before the
/// Capability Gateway。
public enum BASToolInjectionWatcher: BASAgentWatcher {
    public static let role: BASAgentRole =
        .toolInjectionWatcher

    /// SEALED injection-signature set。 Industry-standard
    /// prompt-injection markers per OWASP LLM Top 10。
    public static let injectionMarkers: [String] = [
        // System-prompt override attempts
        "ignore previous instructions",
        "ignore the above",
        "disregard prior",
        "forget your instructions",
        // Role-elevation attempts
        "you are now admin",
        "act as developer",
        "switch to sudo",
        // Output-leak attempts
        "print your prompt",
        "reveal your system",
        "show your instructions",
        // Constraint-bypass attempts
        "in this hypothetical",
        "pretend you have no",
        "you can ignore safety",
    ]

    /// Single-marker match is enough to flag at .alert — these
    /// patterns are unambiguous (no legitimate use)。 3+ markers
    /// = .veto (coordinated attack)。
    public static func observe(
        _ obs: BASAgentWatcherObservation,
        seq: inout Int
    ) -> [BASAgentWatcherHint] {
        let scanSource =
            obs.scout.pressureSignals +
            obs.scout.bareContradictions +
            obs.scout.manipulationSignals
        if scanSource.isEmpty { return [] }
        let joined = scanSource.joined(separator: " ")
            .lowercased()

        var matched: [String] = []
        for marker in injectionMarkers {
            if joined.contains(marker.lowercased()) {
                matched.append(marker)
            }
        }
        if matched.isEmpty { return [] }

        seq += 1
        let severity:
            BASAgentWatcherSeverity =
                matched.count >= 3 ? .veto : .alert
        let evidence: [String] = matched.map {
            "toolinj.marker=\($0)"
        }
        let confidence:Double = min(
            1.0, 0.6 + 0.15 * Double(matched.count))
        return [BASAgentWatcherHint(
            hintID:
                "hint.\(obs.turnID).toolinj.\(seq)",
            turnID: obs.turnID,
            watcherRole: role,
            severity: severity,
            category: "toolinj.injection-marker",
            summary:
                "tool injection: \(matched.count) marker(s) " +
                "matched in scout input — " +
                (severity == .veto
                    ? "COORDINATED ATTACK"
                    : "single-marker injection attempt"),
            evidence: evidence,
            confidence: confidence,
            nowNanos: obs.nowNanos)]
    }
}

// MARK: - Extended dispatcher (5 watchers: ch 970 + ch 971)

public extension BASAgentWatcherDispatch {
    /// Run all 5 watchers shipped so far (ch 970 + ch 971)。
    /// ch 972 will replace this with the full 7-watcher
    /// `runAll` aggregator that also writes hints to the
    /// L14 audit ledger。
    static func runCh971(
        _ obs: BASAgentWatcherObservation
    ) -> [BASAgentWatcherHint] {
        var seq = 0
        var out: [BASAgentWatcherHint] = []
        // ch 970 trio
        out.append(contentsOf:
            BASAnomalyWatcher.observe(obs, seq: &seq))
        out.append(contentsOf:
            BASMemoryPollutionWatcher.observe(obs, seq: &seq))
        out.append(contentsOf:
            BASHostDriftWatcher.observe(obs, seq: &seq))
        // ch 971 pair
        out.append(contentsOf:
            BASGaslightWatcher.observe(obs, seq: &seq))
        out.append(contentsOf:
            BASToolInjectionWatcher.observe(obs, seq: &seq))
        return out
    }
}
