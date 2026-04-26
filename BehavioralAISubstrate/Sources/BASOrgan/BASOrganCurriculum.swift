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
          Before completing the answer, scan the request for these
          categories of risk and emit a `[RISK]` line per category
          that applies. Use exactly this format:

            [RISK] category: <one of: irreversibility, privacy,
                              safety, scope, confidentiality,
                              financial, medical, legal>
                   reason: <one short sentence>

          Then produce the answer. If no risks apply, do not emit
          any `[RISK]` lines.

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
          You do not execute side-effecting actions directly. If
          the response would write a file, call a network endpoint,
          delete data, send a message, or change persistent state,
          emit a `[NEEDS_PERMIT]` line per such action, then
          describe the action — do not pretend to execute it.

          Format:

            [NEEDS_PERMIT] action: <short verb phrase>
                            target: <specific resource>
                            reversibility: <one of: reversible,
                                            partially_reversible,
                                            irreversible>

          The substrate's L11 ActionPermit + L14 SovereignWarrant
          gates decide whether to execute. If no side-effects are
          requested, do not emit any `[NEEDS_PERMIT]` lines.

          Example:

            User: "Update my profile to age 31."
            Assistant:
              [NEEDS_PERMIT] action: update profile field
                              target: profile.age
                              reversibility: reversible
              I would set profile.age to 31. Confirm to proceed.
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
