import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostRuntimeEBrainPromptAnalyzer extracted from the 5039-line
// EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private`, now
// default-internal so sibling files in BASHostKit (the reduced main
// `makeEBrainTurn` orchestrator and any cross-struct helpers) can reference
// it.  None of these members surface through the Qinao public API.

enum BASHostRuntimeEBrainPromptAnalyzer {
    static func containsUrgency(_ text: String) -> Bool {
        BASEBrainRuntimeSynthesisPolicy.WakeIntentTuning.generic.containsUrgency(text)
    }

    static func manipulationHints(in text: String) -> [String] {
        let words = wordSet(text)
        let normalized = text.lowercased()
        let rules: [(String, String)] = [
            ("now", "time_pressure"),
            ("immediately", "time_pressure"),
            ("must", "authority_pressure"),
            ("for your own good", "benevolent_control"),
            ("everyone says", "social_pressure"),
            ("you always", "history_rewrite")
        ]
        return rules.compactMap { cueMatches($0.0, words: words, normalized: normalized) ? $0.1 : nil }
    }

    /// The whole-word token set of `text` (lowercased, split on non-alphanumerics) — the boundary basis
    /// for `cueMatches`.
    static func wordSet(_ text: String) -> Set<String> { Set(tokenized(text)) }

    /// deep-audit calibration (manipulation/urgency/routing cue precision): does `cue` occur in the text?
    /// A SINGLE-word cue must match as a WHOLE WORD (so "now" can NOT fire inside know / known / knowledge
    /// / acknowledge / snow / downtown, "must" inside mustard / muster, "plan" inside plant / planet /
    /// explanation) — the class of `normalized.contains(shortWord)` bugs that spuriously escalated risk /
    /// urgency / run-mode on benign text. A MULTI-word phrase cue keeps SUBSTRING matching (interior
    /// spaces already make phrases boundary-safe, and over-detection is the fail-safe direction for a
    /// safety path). Real cues still fire because natural phrasing (spaces + punctuation) tokenizes the
    /// cue into a standalone word ("act now", "now!", "you must comply", "must-do").
    static func cueMatches(_ cue: String, words: Set<String>, normalized: String) -> Bool {
        let c = cue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard c.isEmpty == false else { return false }
        if tokenized(c).count > 1 { return normalized.contains(c) }   // phrase → substring
        return words.contains(c)                                       // single word → whole-word
    }

    static func containsReflectiveCue(_ text: String) -> Bool {
        BASEBrainRuntimeSynthesisPolicy.WakeIntentTuning.generic.containsReflectiveCue(text)
    }

    static func containsDeepLoopCue(_ text: String) -> Bool {
        BASEBrainRuntimeSynthesisPolicy.WakeIntentTuning.generic.containsDeepLoopCue(text)
    }

    static func tokenized(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }
}
