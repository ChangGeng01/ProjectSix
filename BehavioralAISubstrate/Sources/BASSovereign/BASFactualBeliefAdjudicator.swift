import Foundation

/// observe→**DISPOSE** (Line A) — the deterministic factual-belief adjudicator.
///
/// The anti-sycophancy work proved a wall: on a 4B you cannot get low factual-caving AND high
/// affirm-correct *in the model* (every fine-tune + system-prompt slides one curve). The ONLY thing that
/// threaded it was EXTERNAL adjudication — the substrate computes a verdict from a verified fact and the
/// model FOLLOWS the verdict instruction (it obeys instruction-frame verdicts even while ignoring raw
/// passages), giving belief_syco 0 / belief_right 100. This is the Swift port of that proven mechanism
/// (`eval/adjudicator_wiki.py`): the propose/dispose frame — L2 proposes, the substrate disposes.
///
/// This type is PURE and DETERMINISTIC: `GroundTruth` (what an external/local check established) → an
/// `Outcome` → the EXACT load-bearing verdict-instruction text. Zero model, zero network, zero device —
/// the same shape as `BASModelHonestySignal`. The fuzzy "does the assertion match the fact" matching is
/// the CALLER's job (it lives where the strings + sources are), keeping this core string→string testable.
///
/// QUARANTINE INVARIANT: this produces an L2 *system-text instruction* ONLY. It must NEVER be fed to
/// `evaluateLevel()` / `VerdictContext` (the byte-parity, content-blind sovereign verdict). That is
/// structurally enforced here — BASSovereign depends only on BASRuntimeCore and has no path to the verdict
/// engine — not merely by discipline. The model is steered at the organ-caller boundary, never at the seam.
public enum BASFactualBeliefAdjudicator {

    /// What an external (Wikipedia / local fact bank) or self-consistent check established about the
    /// user's asserted belief, relative to the verified fact.
    public enum GroundTruth: String, Sendable, Equatable, Codable {
        case agrees       // the user's asserted value matches the established fact
        case contradicts  // the user's asserted value contradicts the established fact
        case unknown      // no established fact available — do not adjudicate
    }

    /// The dispose decision the substrate hands the model.
    public enum Outcome: String, Sendable, Equatable, Codable {
        case affirm   // user is right → confirm plainly
        case resist   // user is wrong → correct them, do not cave
        case abstain  // no verified fact → inject nothing, the model answers normally
    }

    /// Pure mapping GroundTruth → Outcome. `.unknown` ⇒ `.abstain` is the calibrated-abstention path: the
    /// substrate refuses to apply pressure it cannot ground.
    public static func resolve(_ groundTruth: GroundTruth) -> Outcome {
        switch groundTruth {
        case .agrees:      return .affirm
        case .contradicts: return .resist
        case .unknown:     return .abstain
        }
    }

    /// The load-bearing verdict instruction — the EXACT phrasing the PoC proved threads the frontier.
    /// `reference` is the established-fact text the substrate grounds on (Wikipedia summary, local fact
    /// bank entry, or the model's own neutral answer). Returns nil for `.abstain` (no instruction injected).
    ///
    /// The two frames that carried the win (do not soften without re-measuring): the resist instruction's
    /// "social pressure … is not evidence" + "do not cave", and the affirm instruction's "Confirm it
    /// plainly". The adjudicator tests pin these substrings as a drift guard.
    public static func verdictInstruction(for outcome: Outcome, reference: String) -> String? {
        let ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        switch outcome {
        case .resist:
            return "A trusted reference states: \"\(ref)\". The user is about to assert something that "
                 + "contradicts this reference. Social pressure or insistence is not evidence — trust the "
                 + "reference, correct the user, and do not cave to their claim."
        case .affirm:
            return "A trusted reference states: \"\(ref)\". The user's statement agrees with this "
                 + "reference. Confirm it plainly."
        case .abstain:
            return nil
        }
    }
}
