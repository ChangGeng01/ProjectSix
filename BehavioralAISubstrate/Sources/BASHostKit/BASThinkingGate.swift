import Foundation

/// observe→DISPOSE (biomimetic-brain-efficiency) — the GROUNDED compute lever, MEASURED not assumed.
///
/// A reasoning model (Qwen3.5) dumps ~500 words of "Thinking Process" on EVERY turn, trivial or hard (measured:
/// "What is 2+2?" → 550 words). Turning thinking OFF is ~30× cheaper. The measured quality cost:
///   - factual / conversational turns: 4/4 correct WITH thinking off — the thinking was pure waste.
///   - multi-digit ARITHMETIC: thinking off broke it (47×89, 6371×8429 went wrong; the model can't do
///     multi-step computation in one forward pass).
/// So the win is real but TARGETED: keep thinking only where the turn needs multi-step computation, off
/// everywhere else. This gate is that cheap detector — NOT a difficulty oracle (general hard-reasoning detection
/// is the unsolved problem the surprise/length signals all failed at), just the one class that measurably breaks.
///
/// HONEST SCOPE: this catches multi-digit arithmetic (the measured failure class). It does NOT catch general
/// multi-step reasoning (formal proofs, logic puzzles) — those would also degrade with thinking off and are not
/// cheaply detectable. Treat this as "thinking-off by default + keep it for obvious computation", a partial gate.
public enum BASThinkingGate {

    private static let computeCues: [String] =
        ["multipl", "times", "divide", "divided", "product of", "calculate", "compute", "×", "*", "÷"]

    /// Keep the model's thinking ON for this turn? True only when the prompt looks like multi-step COMPUTATION
    /// (a ≥2-digit number AND a compute cue) — the class where thinking-off measurably breaks. Everything else
    /// ⇒ false ⇒ thinking off (the 30×-cheaper path that held 100% quality on factual/conversational turns).
    public static func needsThinking(_ prompt: String) -> Bool {
        let p = prompt.lowercased()
        let hasMultiDigit = firstMatch(#"\d{2,}"#, in: p)
        guard hasMultiDigit else { return false }
        return computeCues.contains { p.contains($0) }
    }

    private static func firstMatch(_ pattern: String, in s: String) -> Bool {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return false }
        return re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }
}
