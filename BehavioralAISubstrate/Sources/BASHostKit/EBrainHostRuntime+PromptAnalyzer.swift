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
        let normalized = text.lowercased()
        let rules: [(String, String)] = [
            ("now", "time_pressure"),
            ("immediately", "time_pressure"),
            ("must", "authority_pressure"),
            ("for your own good", "benevolent_control"),
            ("everyone says", "social_pressure"),
            ("you always", "history_rewrite")
        ]
        return rules.compactMap { normalized.contains($0.0) ? $0.1 : nil }
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
