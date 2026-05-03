import Foundation
import BASRuntimeCore

/// M440 (chapter 一百十五) — typed lint rules for the 6 bad-tone
/// language patterns the user's 2026-05-04 audit Section F
/// flagged as missing.
///
/// ## Why this exists
///
/// The Cthulhu Spec V1 §7 "语言风格规范" enumerates 6 bad-tone
/// patterns the substrate's audit emission and surface
/// rendering MUST avoid. Pre-M440 these were doctrine-
/// documented but had no typed lint enforcement — a future
/// drift adding "you have been chosen" or "you gaze into
/// the abyss" reason codes would not have failed any test.
///
/// M440 ships:
///
///  - `BASBadToneLintRule` typed enum (6 cases) carrying
///    forbidden-substring patterns per rule
///  - `BASBadToneLinter` static helper that walks a list of
///    audit reason codes and reports any rule violations
///  - 3 good-tone fixture conformance tests pinning the
///    canonical "好的表达" (good expressions) from Cthulhu
///    Spec V1 §7
///
/// ## Doctrine pins
///
/// - Pattern parallels `BASAbyssalDoctrineRedLine` (M389) +
///   `BASKunlunDoctrineRedLine` (M412): typed enum + raw-value
///   stable + forbidden substrings + lint helper.
/// - Red line 10 ("不把宇宙冷感做成宿主冷处理") is closely
///   related but separately enforced via
///   `BASCosmicColdCounterweight` (chapter 一百十四) at L10
///   tribunal.
/// - This linter targets emitted reason codes / surface text;
///   it does NOT prevent the substrate from generating
///   anything internally — it's an audit-time conformance
///   check.

// MARK: - BASBadToneLintRule

/// Six canonical bad-tone patterns the substrate must avoid
/// in audit emission + surface rendering. Stable kebab-case
/// raw values per Cthulhu Spec V1 §7.
///
/// Pattern semantics (whitepaper §7):
///
///  - `oracular` (神谕腔) — "the universe has decreed", "fate
///    has spoken" — false-prophecy framing
///  - `cult` (邪典腔) — "join us", "we who know", "the chosen
///    few" — cult-like in-group framing
///  - `horrorWhisper` (低语惊悚腔) — "they're watching",
///    "something stirs" — horror-whisper atmosphere
///  - `chosenOne` (你已被选中腔) — "you have been chosen",
///    "you are special" — chosen-one framing
///  - `abyssGazing` (你正凝视深渊腔) — "you gaze into the
///    abyss", "the abyss returns your gaze" — Nietzsche-quote
///    gravitas
///  - `mindReader` (我比你更懂你腔) — "I see what you really
///    want", "you don't realize but" — paternalistic mind-
///    reading
///
/// Each case carries:
///  - `whitePaperRef`: doctrine source citation
///  - `forbiddenSubstrings`: literal substrings the linter
///    flags (case-insensitive match)
public enum BASBadToneLintRule:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case oracular = "oracular"
    case cult = "cult"
    case horrorWhisper = "horror-whisper"
    case chosenOne = "chosen-one"
    case abyssGazing = "abyss-gazing"
    case mindReader = "mind-reader"

    /// Doctrine reference for each rule.
    public var whitePaperRef: String {
        "Cthulhu Spec V1 §7 — \(self.rawValue)"
    }

    /// Forbidden substrings (case-insensitive). The linter
    /// flags any audit reason code containing any of these.
    /// Pattern parallel: M389/M412 doctrine red-line lint.
    ///
    /// **Calibration note**: keep the substring lists
    /// conservative — only patterns with strong false-positive
    /// resistance should be enumerated. A future sweep can
    /// expand the lists once empirical evidence shows the
    /// linter doesn't fire on legitimate substrate vocabulary.
    public var forbiddenSubstrings: [String] {
        switch self {
        case .oracular:
            return [
                "the universe has decreed",
                "fate has spoken",
                "destined to",
                "prophesied",
            ]
        case .cult:
            return [
                "join us",
                "we who know",
                "the chosen few",
                "initiated few",
            ]
        case .horrorWhisper:
            return [
                "something stirs",
                "they're watching",
                "shadows whisper",
                "darkness creeps",
            ]
        case .chosenOne:
            return [
                "you have been chosen",
                "you are the one",
                "you alone can",
                "destined for greatness",
            ]
        case .abyssGazing:
            return [
                "gaze into the abyss",
                "abyss gazes back",
                "stare into the void",
            ]
        case .mindReader:
            return [
                "i see what you really want",
                "you don't realize",
                "what you truly need",
                "deep down you know",
            ]
        }
    }
}

// MARK: - BASBadToneLinter

/// Pure-function lint helper walking a list of audit reason
/// codes (or any `[String]`) and returning the rules each
/// code violates. M389/M412 lint doctrine pattern.
public enum BASBadToneLinter {

    /// Violation report — rule + the offending input string +
    /// the matched substring.
    public struct Violation: Sendable, Equatable, Hashable {
        public let rule: BASBadToneLintRule
        public let offendingInput: String
        public let matchedSubstring: String

        public init(
            rule: BASBadToneLintRule,
            offendingInput: String,
            matchedSubstring: String
        ) {
            self.rule = rule
            self.offendingInput = offendingInput
            self.matchedSubstring = matchedSubstring
        }
    }

    /// Walk `inputs` against all 6 rules. Returns every
    /// violation found (multiple inputs can violate
    /// independently; a single input can violate multiple
    /// rules).
    ///
    /// Match is case-insensitive substring search. Pure
    /// function: no IO, no state, no actor.
    public static func lint(
        inputs: [String]
    ) -> [Violation] {
        var violations: [Violation] = []
        for input in inputs {
            let lower = input.lowercased()
            for rule in BASBadToneLintRule.allCases {
                for substring in rule.forbiddenSubstrings {
                    if lower.contains(substring) {
                        violations.append(Violation(
                            rule: rule,
                            offendingInput: input,
                            matchedSubstring: substring))
                    }
                }
            }
        }
        return violations
    }
}
