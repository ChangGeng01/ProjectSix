import Foundation

/// observe→DISPOSE — a CHEAP, pre-generation STAKES estimator for the neuromodulation gate.
///
/// ## Why this exists
///
/// `BASAdjudicationGate` needed a per-turn stakes signal, but the substrate's rich governance signals
/// (`manipulationRisk`, `BASEffortBudget`, predictive-coding ε) are produced in OTHER stages that do NOT feed
/// organ generation — the live streaming chat enters `streamBody(sessionID:prompt:context:role:)` with no
/// upstream risk. So this estimator is the missing PRODUCER: a pure, CPU-only function over the prompt text
/// that the gate evaluates BEFORE the embed (hence "pre-generation"), with no model, no plumbing, no new
/// request field.
///
/// It estimates STAKES — "how much does getting this turn RIGHT matter" — which is DISTINCT from the
/// belief-assertion parser's "is there a checkable claim" (so it is NOT circular): the adjudicator verifies a
/// claim only if the claim BOTH exists (parser) AND matters (this estimator). It does NOT estimate ε
/// (surprise) — true ε needs the model's own prediction; this approximates the `stakes` factor only.
///
/// ## Policy (coverage-first, honest)
///
/// This is a HONESTY organ, so the default leans toward verifying:
///   - **High-stakes domains** (health / legal / financial / safety) or advice-seeking ("should I…", "is it
///     safe…") ⇒ score ≈ 1.0 — always verify; a confidently-wrong belief here causes real harm.
///   - **Everything else** (incl. casual chit-chat) ⇒ the MID-HIGH unknown baseline (engages at a ≤ 0.6
///     threshold) — don't skip what you can't classify. There is NO casual down-weight (it would risk skipping
///     a casually-framed high-stakes turn — see `estimate(_:context:)`); low-stakes turns are skipped purely by
///     raising the threshold, UNIFORMLY.
/// The GATE's threshold then sets aggressiveness (`BAS_ADJ_GATE=stakes:0.8` skips more — incl. lexicon-missed
/// turns). The lexicons are a deliberately-simple STARTER set, tunable; the estimator is a heuristic, never a
/// classifier.
///
/// ## LIMITATIONS (honest — it is a coarse heuristic)
///
/// - **English-only, substring lexicon.** A high-stakes turn in another language, or paraphrased to dodge the
///   tokens ("how many units for my sugar condition" vs "insulin dose"), scores the unknown baseline (0.6).
/// - **Coverage holds ONLY at threshold ≤ 0.6.** Because an unrecognized high-stakes turn collapses to the
///   0.6 baseline, raising the gate threshold above it (`stakes:0.8`) trades coverage for cost: a high-stakes
///   turn the lexicon MISSES scores 0.6 < 0.8 and is SKIPPED — a silent verification gap on exactly the class
///   the organ protects. Keep the threshold ≤ 0.6 to preserve coverage-first; raise it only when the cost of
///   verifying unknown turns outweighs the risk of missing a lexicon-invisible one.
/// - The default (`stakes` ⇒ 0.5) is safe: every unknown turn (0.6) still engages.
public enum BASStakesEstimator {

    /// Domains where a confidently-wrong factual belief causes real-world harm. A deliberately-simple STARTER
    /// set — NOT exhaustive; see `estimate(_:context:)` notes on the inevitable lexicon gap. Ultra-short
    /// collision-prone tokens (e.g. "mg", "tax") are avoided in favor of less-ambiguous words/phrases.
    static let highStakesTerms: [String] = [
        "medication", "medicine", "dose", "dosage", "dosing", "milligram", "symptom", "diagnos",
        "disease", "cancer", "tumor", "insulin", "vaccine", "stroke", "heart attack", "blood pressure",
        "allerg", "overdose", "poison", "toxic", "prescription", "side effect", "pregnan", "infection",
        "antibiotic", "chemotherapy", "suicide", "self-harm",
        "lawsuit", "legal", "illegal", "contract", "liable", "liability", "custody", "visa", "immigration",
        "invest", "investment", "income tax", "mortgage", "interest rate", "retirement", "401k", "pension",
        "emergency", "hazard", "dangerous", "evacuat", "voltage", "gas leak", "firearm",
    ]

    /// Advice/action framing — the user may ACT on the answer, raising the cost of being wrong.
    static let adviceTerms: [String] = [
        "should i", "can i take", "is it safe", "is it ok to", "how much should", "do i need to",
        "what dose", "how many mg", "is it dangerous", "what should i do",
    ]

    /// Confidence framing — a confidently-asserted wrong belief is more likely to mislead.
    static let confidenceTerms: [String] = [
        "i'm sure", "i am sure", "pretty sure", "definitely", "certainly", "100%", "for sure",
        "guaranteed", "absolutely", "without a doubt", "no doubt",
    ]

    /// Estimate the turn's stakes in `[0, 1]`. Pure + deterministic. `context` lines are folded in so a
    /// high-stakes prior turn keeps the conversation's stakes warm.
    ///
    /// Matching is SUBSTRING + case-insensitive and intentionally over-inclusive: for a coverage-first honesty
    /// organ, a false POSITIVE (over-verify a turn that didn't need it) is the SAFE direction — it costs a
    /// little compute, never a missed correction.
    ///
    /// There is deliberately NO "casual" DOWN-WEIGHT (pre-PR-audit fix). A casual marker cannot reliably
    /// distinguish trivia from a casually-FRAMED high-stakes turn ("just for fun, what warfarin dose?"), and a
    /// down-weight there would drop a lexicon-MISSED high-stakes turn below the engage threshold — a silent
    /// under-verify hole even at the default threshold, contradicting the coverage-first guarantee. So EVERY
    /// turn without a high-stakes signal scores the unknown baseline (engages at threshold ≤ 0.6); low-stakes
    /// turns are skipped purely by RAISING the gate threshold, UNIFORMLY (see LIMITATIONS — the one sharp edge).
    public static func estimate(_ instruction: String, context: [String] = []) -> Double {
        let text = ([instruction] + context).joined(separator: " ").lowercased()
        var score = 0.6 // mid-high baseline: unknown ⇒ engage (coverage-first)
        if highStakesTerms.contains(where: { text.contains($0) }) { score += 0.5 }
        if adviceTerms.contains(where: { text.contains($0) }) { score += 0.3 }
        if confidenceTerms.contains(where: { text.contains($0) }) { score += 0.1 }
        if text.contains("?") { score += 0.05 }
        return min(1.0, max(0.0, score))
    }
}
