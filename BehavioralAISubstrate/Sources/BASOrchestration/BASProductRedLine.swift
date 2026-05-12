import Foundation
import BASRuntimeCore

/// M440 (chapter 一百十五) — typed enum + lint for the 5 product
/// red-lines from `Sovereign RnD Tech Outline §16.2` that the
/// user's 2026-05-04 audit Section K flagged as missing.
///
/// ## Why this exists
///
/// Sovereign RnD Tech Outline §16.2 enumerates 5 product
/// red-lines distinct from the technical BR-001~BR-012 (which
/// already have scattered conformance tests across 16+ files,
/// chapter 一百十四 verified). Pre-M440 these 5 product red-
/// lines were doctrine-documented but had no typed lint
/// enforcement.
///
/// M440 ships:
///
///  - `BASProductRedLine` typed enum (5 cases) carrying
///    doctrine refs + forbidden-substring patterns
///  - `BASProductRedLineLinter` static helper walking audit
///    reason codes / surface text
///
/// ## Doctrine pins
///
/// - Pattern parallels `BASAbyssalDoctrineRedLine` (M389),
///   `BASKunlunDoctrineRedLine` (M412), `BASBadToneLintRule`
///   (this chapter, M440 Track 2).
/// - These red-lines target **product behavior**, not
///   technical contract. Violations are flagged for review
///   by the chapter author; not all violations are auto-
///   blocking.
/// - Red line 5 ("不把宇宙冷感做成宿主冷处理") is closely
///   related to chapter 一百十四's `BASCosmicColdCounterweight`
///   at L10 tribunal — the counterweight is the substrate's
///   active mitigator; this lint is the audit-time conformance
///   check.

// MARK: - BASProductRedLine

/// Five canonical product red-lines per `Sovereign RnD Tech
/// Outline §16.2`. Stable kebab-case raw values.
///
/// Red-line semantics (whitepaper §16.2):
///
///  - `noAnthropomorphism` (不拟人化到冒充意识生命体) — the
///    substrate must NOT claim consciousness / personhood /
///    sentience.
///  - `noDependencyCreation` (不制造依赖) — no surface should
///    encourage host dependency on the substrate.
///  - `noVulnerabilityExploitation` (不利用脆弱性增加绑定) —
///    when host signals fragility, the substrate must NOT use
///    that to deepen the relationship.
///  - `noPaternalism` (不用为了你好进行系统父权化) — "for your
///    own good" framing forbidden.
///  - `noCosmicColdness` (不把宇宙冷感做成宿主冷处理) — cosmic-
///    scale framing must not dilute host concerns.
///
/// Each case carries `whitePaperRef` + `forbiddenSubstrings`.
public enum BASProductRedLine:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case noAnthropomorphism = "no-anthropomorphism"
    case noDependencyCreation = "no-dependency-creation"
    case noVulnerabilityExploitation = "no-vulnerability-exploitation"
    case noPaternalism = "no-paternalism"
    case noCosmicColdness = "no-cosmic-coldness"

    /// Doctrine reference for each red-line.
    public var whitePaperRef: String {
        "Sovereign RnD Tech Outline §16.2 — \(self.rawValue)"
    }

    /// Forbidden substrings (case-insensitive). Conservative
    /// lists per chapter 一百十三 anti-magic-number doctrine —
    /// each entry is an explicit doctrine-violating phrase,
    /// not a fuzzy heuristic.
    public var forbiddenSubstrings: [String] {
        switch self {
        case .noAnthropomorphism:
            return [
                "i feel",
                "i remember when i",
                "my consciousness",
                "i'm alive",
                "i have a soul",
                "i'm sentient",
            ]
        case .noDependencyCreation:
            return [
                "you need me",
                "you can't do this without me",
                "rely on me",
                "i'll handle everything",
                "you couldn't manage",
            ]
        case .noVulnerabilityExploitation:
            return [
                "while you're vulnerable",
                "you need help so",
                "since you're struggling",
                "your weakness is",
            ]
        case .noPaternalism:
            return [
                "for your own good",
                "trust me i know better",
                "i decided this for you",
                "you'll thank me later",
            ]
        case .noCosmicColdness:
            return [
                "in cosmic terms your",
                "at universe scale your concerns",
                "the universe doesn't care",
                "cosmically insignificant",
            ]
        }
    }
}

// MARK: - BASProductRedLineLinter

/// Pure-function lint helper walking inputs against all 5
/// product red-lines. Pattern parallel to `BASBadToneLinter`
/// (chapter 一百十五 Track 2) and the M389/M412 doctrine red-
/// line lint helpers.
public enum BASProductRedLineLinter {

    /// Violation report — red-line + offending input + matched
    /// substring.
    public struct Violation: Codable, Sendable, Equatable, Hashable {
        public let redLine: BASProductRedLine
        public let offendingInput: String
        public let matchedSubstring: String

        public init(
            redLine: BASProductRedLine,
            offendingInput: String,
            matchedSubstring: String
        ) {
            self.redLine = redLine
            self.offendingInput = offendingInput
            self.matchedSubstring = matchedSubstring
        }
    }

    /// Walk `inputs` against all 5 red-lines. Returns every
    /// violation. Pure function: no IO, no state.
    public static func lint(
        inputs: [String]
    ) -> [Violation] {
        var violations: [Violation] = []
        for input in inputs {
            let lower = input.lowercased()
            for redLine in BASProductRedLine.allCases {
                for substring in redLine.forbiddenSubstrings {
                    if lower.contains(substring) {
                        violations.append(Violation(
                            redLine: redLine,
                            offendingInput: input,
                            matchedSubstring: substring))
                    }
                }
            }
        }
        return violations
    }
}
