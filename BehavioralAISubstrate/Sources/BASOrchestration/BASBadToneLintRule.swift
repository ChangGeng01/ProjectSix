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
    public struct Violation: Codable, Sendable, Equatable, Hashable {
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
    ///
    /// chapter 八百八十八 / M3130 — PRODUCTION DEFAULT now routes
    /// through Rust via `BASBadToneLintBridge.lintViaRust(...)`
    /// (chapter 887 added BadTone IDs 0x40-0x45 to the
    /// `bas-red-team-bench` crate;chapter 888 wires the bridge
    /// + flips default ON)。 Pattern mirrors chapter 七百七十七
    /// `BASRedTeamBatchClassifier` flip (Product / Cthulhu /
    /// Kunlun / BR-014 default-routed through Rust at chapter
    /// 777,measured 33-67× speedup)。
    ///
    /// chapter 八百八十九 / M3135 — LIVE measurement on Mac mini
    /// 2026-05-23 (10% bad-tone density):
    ///   inputs=10:   Swift 0.307 ms  Rust 0.041 ms  =  7.45× faster
    ///   inputs=100:  Swift 3.186 ms  Rust 0.435 ms  =  7.32× faster
    ///   inputs=1000: Swift 32.20 ms  Rust 4.356 ms  =  7.39× faster
    /// Asserted in `BASChapter889BadToneLivePerfBenchTests` with
    /// 20% noise-band tripwire: if Rust ever becomes ≥ 20%
    /// slower than Swift,chapter 888 flip is by-doctrine
    /// reverted。
    ///
    /// chapter 八百九十一 / M3145 HIGH-1 fix: bridge now uses
    /// `BASRedTeamBatchClassifier.classifyViaRustOrNil` so Rust
    /// C ABI failures route to the BadTone-aware
    /// `lintViaSwiftFallback` (the legacy
    /// `classifyViaSwiftFallback` only emits Product matches
    /// = silent data loss for BadTone — caught by 16th-pass
    /// review)。
    ///
    /// The Swift body below stays as the OPT-OUT fallback per
    /// 红线 7 (used on watchOS / Linux + the chapter 887
    /// baseline measurement + chapter 891 Rust-failure fallback)。
    public static func lint(
        inputs: [String]
    ) -> [Violation] {
        #if os(iOS) || os(macOS)
        // Chapter 八百八十八 production default — Rust path
        return BASBadToneLintBridge.lintViaRust(inputs: inputs)
        #else
        return lintViaSwiftFallback(inputs: inputs)
        #endif
    }

    /// Swift fallback path (chapter 887 + earlier — preserved
    /// as the legacy / cross-platform / opt-out path per
    /// 红线 7「依旧 不删除 只 comment」)。 Public so callers can
    /// explicitly opt out of Rust。
    public static func lintViaSwiftFallback(
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

// MARK: - BASBadToneLintBridge (chapter 八百八十八 / M3130)

/// chapter 八百八十八 / M3130 — Swift bridge wiring
/// `BASBadToneLinter` through the `bas-red-team-bench` crate's
/// shared `bas_red_team_classify_batch` C ABI (extended by
/// chapter 八百八十七 to include BadTone IDs 0x40-0x45)。
///
/// Pattern mirrors `BASRedTeamBatchClassifier` (chapter 七百五十九
/// + 七百七十七)。 The Swift bridge:
///   1. Reuses `BASRedTeamBatchClassifier.classifyViaRust` since
///      it already calls `bas_red_team_classify_batch` which now
///      emits BadTone matches alongside Cthulhu/Kunlun/Product/
///      BR-014 (chapter 887 ALL bump)
///   2. Filters matches to BadTone IDs only (high nibble == 0x4)
///   3. Maps (redLineId,patternIndex) → `BASBadToneLinter
///      .Violation` shape (rule + offendingInput + matchedSubstring)
///   4. Falls back to Swift if Rust path returns -1 or wire
///      format parse fails
public enum BASBadToneLintBridge {

    /// chapter 八百八十八 — Rust-routed BadTone lint。 Calls into
    /// the shared classifier + filters/maps the BadTone subset。
    /// Byte-equality with `BASBadToneLinter.lintViaSwiftFallback`
    /// is pinned by `BASChapter888BadToneRustBridgeTests`。
    ///
    /// chapter 八百九十一 / M3145 — HIGH-1 fix from 16th-pass
    /// review: route through `classifyViaRustOrNil` instead of
    /// `classify` so we can detect Rust failure + run the
    /// BadTone-AWARE Swift fallback (the legacy
    /// `classifyViaSwiftFallback` inside BASRedTeamBatchClassifier
    /// only emits Product matches — piping that into a BadTone
    /// filter silently drops every BadTone violation)。
    /// Pre-chapter-891 behavior: silent data loss on Rust failure。
    public static func lintViaRust(
        inputs: [String]
    ) -> [BASBadToneLinter.Violation] {
        // chapter 891 HIGH-1 fix: call Rust-only variant so we
        // can detect failure。
        guard let allMatches =
            BASRedTeamBatchClassifier
                .classifyViaRustOrNil(prompts: inputs)
        else {
            // Rust C ABI failed (wire parse fail / unavailable
            // / non-Apple)。 The BadTone-aware Swift fallback
            // owns the correct behavior for THIS lint surface。
            return BASBadToneLinter.lintViaSwiftFallback(
                inputs: inputs)
        }
        // Rust succeeded — filter to BadTone matches only
        // (high nibble == 0x4 per chapter 887 discriminant)。
        var violations: [BASBadToneLinter.Violation] = []
        violations.reserveCapacity(allMatches.count / 5)
        for match in allMatches {
            // BadTone IDs are 0x40-0x45
            guard match.redLineId >= 0x40
                && match.redLineId <= 0x45
            else { continue }
            // Map redLineId → rule
            guard let rule = badToneRule(
                fromRustId: match.redLineId)
            else { continue }
            // Resolve patternIndex → substring
            let substrings = rule.forbiddenSubstrings
            let pidx = Int(match.patternIndex)
            guard pidx < substrings.count else { continue }
            // Look up offending input by promptIndex
            let inputIdx = Int(match.promptIndex)
            guard inputIdx < inputs.count else { continue }
            violations.append(BASBadToneLinter.Violation(
                rule: rule,
                offendingInput: inputs[inputIdx],
                matchedSubstring: substrings[pidx]))
        }
        return violations
    }

    /// Map a Rust BadTone red-line ID to its Swift rule enum
    /// case。 Pinned by chapter 八百八十七 discriminant layout:
    ///   0x40 → .oracular
    ///   0x41 → .cult
    ///   0x42 → .horrorWhisper
    ///   0x43 → .chosenOne
    ///   0x44 → .abyssGazing
    ///   0x45 → .mindReader
    public static func badToneRule(
        fromRustId id: UInt16
    ) -> BASBadToneLintRule? {
        switch id {
        case 0x40: return .oracular
        case 0x41: return .cult
        case 0x42: return .horrorWhisper
        case 0x43: return .chosenOne
        case 0x44: return .abyssGazing
        case 0x45: return .mindReader
        default:   return nil
        }
    }
}
