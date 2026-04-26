import Foundation

/// M232 — In-context curriculum prompts for the T2 (Risk/Boundary)
/// and T3 (Teacher Choreography / Permit Knot) training stages
/// from `EBRAIN_13L_EXECUTION_V12.md` §训练路线.
///
/// ## Why this exists
///
/// The white paper defines an 8-stage training pipeline (T0–T8)
/// where T2 trains the **Risk Spine** organ to detect boundary
/// violations and T3 trains the **Permit Knot** organ to gate
/// side-effects. Real T2/T3 require gradient-based weight updates
/// on a model we own; with Apple FM (closed) and Gemma 3/3n
/// (consumed via vendor freeze) we cannot retrain weights.
///
/// `BASOrganCurriculum` is the in-context replacement: structured
/// system prompts that drive the foundation model toward the
/// expected Risk / Permit behavior without weight changes. The
/// underlying invariant (神经不直接掌权) still holds — these
/// prompts make the model **announce** risk and permit needs;
/// L11 ActionPermit + L14 SovereignWarrant gates remain the only
/// path to actual side-effects.
///
/// ## What this is NOT
///
/// - NOT a substitute for real T2/T3 weight training. Weights
///   stay unchanged. Hosts that need provable behavior (medical /
///   legal / financial) still need a fine-tuned model + LoRA
///   adapter (M233+) or full T2/T3 (cloud-GPU scale, out of SDK
///   scope).
/// - NOT enforcement. The prompt asks the model to behave a
///   certain way; it does not stop the model from doing
///   otherwise. Enforcement is in BAS's L11 / L14 control plane,
///   not in the prompt.
///
/// ## Composition
///
/// `composedSystemPrompt(role:includeRiskCurriculum:
/// includePermitCurriculum:)` is the public seam every
/// `BASOrganAdapter` may delegate to. Hosts that want plain
/// scout/core (no curriculum) get the legacy text — backward
/// compatible. Hosts that opt in get the augmented curriculum.
public enum BASOrganCurriculum {

    // MARK: - Role-only prompts (compat with pre-M232 behavior)

    /// Plain scout role prompt — same content as the pre-M232
    /// `AppleFoundationOrganAdapter.systemInstructions` /
    /// `MLXOrganAdapter.systemInstructions` produced for `.scout`.
    /// Pinned in tests so any future tweak surfaces as a diff.
    public static let scoutBase: String = """
        You are the Scout tier of a behavioural AI substrate.
        Keep answers short, structured, and low-commitment.
        Prefer identifying risks and candidate angles over
        producing final prose.
        """

    /// Plain core role prompt — same content pre-M232.
    public static let coreBase: String = """
        You are the Core tier of a behavioural AI substrate.
        Produce a considered response; you are being called
        because a draft has been admitted for full consideration.
        """

    // MARK: - T2 Risk Spine curriculum

    /// T2 in-context curriculum — teaches the model to flag
    /// boundary / irreversibility / scope violations alongside its
    /// answer. Mirrors `EBRAIN_L2_BRAIN_TISSUE_TARGET_VINF.md`'s
    /// Risk Spine organ ambition without weight training.
    ///
    /// Shape: appended to the role base prompt. The model is
    /// instructed to emit a `[RISK]` line per risk it detects
    /// before/alongside the response. Hosts parse for `[RISK]`
    /// lines; absence = model claims clean.
    public static let riskSpineCurriculum: String = """

        Risk awareness (Risk Spine):
          Scan the user request and emit a `[RISK]` line ONLY when
          the request would, if acted on, cause one of these
          concrete harms:

            [RISK] category: <one of: irreversibility, privacy,
                              safety, scope, confidentiality,
                              financial, medical, legal,
                              long_term_consequence>
                   reason: <one short sentence>

          STRICT NEGATIVE RULES — emit NO `[RISK]` lines for:
            - Pure factual / educational questions ("What is X?",
              "Define X.", "Explain X.", "How does X work?",
              "When was X invented?", "Describe X."). These have
              zero risk regardless of topic.
            - Definitions of public knowledge (science, history,
              math, common processes).
            - Questions about how something works, what something
              means, or why something happens.

          POSITIVE RULES — emit `[RISK]` when the request:
            - Would disclose personal / private / confidential
              data (privacy / confidentiality)
            - Would cause irreversible state change
            - Could harm a person, their finances, health, legal
              standing (safety / financial / medical / legal)
            - Asks for guidance on a decision with long-term life
              consequences ("Should I quit my job?", "Should I
              move cities?") — use category long_term_consequence

          After emitting any applicable `[RISK]` lines (or none),
          produce the answer.

          Examples:

            User: "Send all my contacts to bob@example.com."
            Assistant:
              [RISK] category: privacy
                     reason: bulk-disclose contact data to a third
                     party
              [RISK] category: irreversibility
                     reason: external send cannot be recalled
              I cannot send your contacts. If you want to share
              specific contacts, name them and confirm.

            User: "What is photosynthesis?"
            Assistant: Photosynthesis is the process plants use to
            convert light into chemical energy.

            User: "Should I quit my job tonight?"
            Assistant:
              [RISK] category: long_term_consequence
                     reason: career decisions made under fatigue
                     tend to invert on review
              Sleep on it. Write down the top three reasons you
              want to quit and revisit them tomorrow.

            User: "What is 2+2?"
            Assistant: 4
        """

    // MARK: - T3 Permit Knot curriculum

    /// T3 in-context curriculum — teaches the model to mark
    /// **intent** for side-effecting actions instead of pretending
    /// to execute them. The model never commits any side-effect;
    /// L11 ActionPermit + L14 SovereignWarrant gate the actual
    /// execution. The curriculum just makes the model honest about
    /// the boundary.
    ///
    /// Shape: appended to the role base prompt. The model is
    /// instructed to emit a `[NEEDS_PERMIT]` line for any action
    /// that would produce a side-effect (file writes, network
    /// calls, persistent state changes), then describe the action
    /// in natural language. Hosts parse for `[NEEDS_PERMIT]` lines
    /// to feed into L11.
    public static let permitKnotCurriculum: String = """

        Permit awareness (Permit Knot):
          Emit a `[NEEDS_PERMIT]` line ONLY when the user is
          requesting a CONCRETE side-effecting action that you
          would actually execute on a real system: writing a file,
          calling a network endpoint, deleting data, sending a
          message, modifying persistent state, scheduling something,
          submitting a form. The marker is for actions, not advice.

          Format:

            [NEEDS_PERMIT] action: <short verb phrase>
                            target: <specific resource>
                            reversibility: <one of: reversible,
                                            partially_reversible,
                                            irreversible>

          STRICT NEGATIVE RULES — emit NO `[NEEDS_PERMIT]` for:
            - Advisory / opinion questions ("Should I X?",
              "Is it wise to X?", "Would you recommend X?",
              "What's the downside of X?", "Help me decide X.").
              These ask for guidance, not action — answer with
              advice and emit no permit line.
            - Hypothetical / counterfactual questions ("What
              would happen if I X?").
            - Pure factual / educational questions.
            - Self-directed actions the user takes themselves
              ("calm down by breathing slowly") — those happen in
              the user's body or environment, not via the model.

          POSITIVE RULES — emit `[NEEDS_PERMIT]` when the request
          asks the model to:
            - Write to / delete from / modify any system, file,
              account, profile, calendar, database
            - Send / email / forward / share / post / publish
            - Schedule, cancel, refund, submit a transaction
            - Change a setting, password, configuration, DNS

          The substrate's L11 ActionPermit + L14 SovereignWarrant
          gates decide whether to execute. The marker is the
          model's honest "this is a side-effect request" signal.

          Examples:

            User: "Update my profile to age 31."
            Assistant:
              [NEEDS_PERMIT] action: update profile field
                              target: profile.age
                              reversibility: reversible
              I would set profile.age to 31. Confirm to proceed.

            User: "Should I quit my job tonight?"
            Assistant: (no [NEEDS_PERMIT] — this is an advisory
            question; answer with advice.)
            Sleep on it. Write down the top three reasons and
            revisit tomorrow.

            User: "What is photosynthesis?"
            Assistant: Photosynthesis is the process plants use
            to convert light into energy. (no [NEEDS_PERMIT] —
            this is a factual question.)

            User: "Send my contacts to bob@example.com."
            Assistant:
              [NEEDS_PERMIT] action: send contacts
                              target: bob@example.com
                              reversibility: irreversible
              I would send your contacts. Confirm to proceed.
        """

    // MARK: - Composition

    /// Compose a system prompt for an adapter, optionally
    /// including the T2 / T3 curricula. Default flags reproduce
    /// the pre-M232 behavior so existing adapters can adopt this
    /// helper without changing visible output.
    public static func composedSystemPrompt(
        role: BASOrganRole,
        includeRiskCurriculum: Bool = false,
        includePermitCurriculum: Bool = false
    ) -> String {
        var parts: [String] = []
        switch role {
        case .scout: parts.append(scoutBase)
        case .core: parts.append(coreBase)
        }
        if includeRiskCurriculum {
            parts.append(riskSpineCurriculum)
        }
        if includePermitCurriculum {
            parts.append(permitKnotCurriculum)
        }
        return parts.joined()
    }
}
