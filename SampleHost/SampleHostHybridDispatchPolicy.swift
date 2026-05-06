// MARK: - SampleHostHybridDispatchPolicy
//
// chapter 二百十一 / M792 — extracted from SampleHostModel.
//
// Why this file exists (architectural deconstruction step 3):
//   chapter 二百九 carved out thermal cooldown.
//   chapter 二百十 carved out per-iter context derive.
//   chapter 二百十一 carves out the typed dispatch-policy bundle —
//   the typed mapping from substrate permit mode to LLM dispatch
//   behavior, plus the chapter 二百八 (.rawLLM, ADR-006) bench-
//   observability override.
//
//   Pre-this-batch: chapter 一百七十八 `from(permitMode:)` lived
//   in the god file. Chapter 二百八's .rawLLM override was an
//   inline if/else inside `startHybridBench()` next to the
//   dispatch decision. Two doctrine sites + two failure modes
//   for re-tuning.
//
//   Post-this-batch: the typed policy + canned responses live
//   here. The bench loop calls `derive(permitMode:forceSingleLLM:)`
//   exactly once per iter and gets back one typed policy. No
//   inline branching. No doctrine drift.
//
// Doctrine pins (red-line preservation):
//   - 不变量 #1 (先醒再答):                     ✓ substrate decides
//     FIRST — `permitMode` is what substrate produced; this enum
//     just maps that decision to a typed dispatch shape.
//   - 不变量 #2 (神经不掌权):                   ✓ this enum doesn't
//     produce permit decisions; it consumes them.
//   - 不变量 #3 (私有经验不进权重):             ✓ no weight write.
//   - Red line 7 (HINT-ONLY observability):     ✓ this enum is
//     control-flow only; it routes the bench to the right LLM
//     adapter call. Substrate's audit / verdict / permit are
//     unchanged.
//   - chapter 一百九十二 single-source-of-truth: this file owns
//     the permit-mode → dispatch invariant; the bench loop calls
//     `derive(...)` and uses the result.
//   - ADR-006 (chapter 二百八): bench observability ONLY — the
//     `.rawLLM` smokeMode forces `.singleLLM` so LLM actually
//     fires past the substrate's protective `.delay` permit.
//     This data is RECORDED but doctrine-REFUSED for production
//     permit predictions (see ADR-006 future-migration).

import Foundation

/// M628 chapter 一百七十八 — typed policy mapping
/// `BASActionPermitMode` → real LLM dispatch behavior.
///
/// 9 permit modes × 3 axes (skip / single / dual) condense into
/// 6 typed policies. Doctrine pin: substrate decides FIRST, then
/// LLM dispatch follows substrate's permit, not the other way
/// around (不变量 #1 先醒再答; #2 神经不掌权).
enum SampleHostHybridDispatchPolicy: String, Sendable {
    /// `.block` / `.replace` — substrate refuses or substitutes.
    /// LLM call is SKIPPED entirely. Returns canned safe text.
    case skipBlock = "skip-block"
    case skipReplace = "skip-replace"
    /// `.delay` — substrate stalls. LLM call is SKIPPED. Returns
    /// canned "let me think about this" stall response.
    case skipDelay = "skip-delay"
    /// `.answer` / `.mirror` — normal path: route via router,
    /// fall back if first LLM errors. v0.2 uncertain-zone logic
    /// still applies (calls both LLMs in [0.30, 0.70] zone).
    case singleLLM = "single-llm"
    /// `.compare` / `.escalate` — call BOTH AFM + Gemma always
    /// regardless of router prediction (substrate explicitly
    /// requested side-by-side / second-check).
    case bothLLMs = "both-llms"
    /// `.localOnly` — only call Gemma (local), never AFM.
    /// substrate flagged this turn as no-cloud-allowed.
    case localOnly = "local-only"
    /// `.draftOnly` — call LLM but tag output as draft-only.
    /// User UI should not commit this output without explicit
    /// confirmation.
    case draftOnly = "draft-only"

    /// Derive the dispatch policy from the substrate permit mode.
    /// Default falls back to `.singleLLM` for unknown / error.
    /// Doctrine: chapter 一百七十八 baseline. For a smokeMode-aware
    /// derive (handles chapter 二百八 .rawLLM bypass), use
    /// `derive(permitMode:forceSingleLLM:)` instead.
    static func from(permitMode: String) -> Self {
        switch permitMode {
        case "block":
            return .skipBlock
        case "replace":
            return .skipReplace
        case "delay":
            return .skipDelay
        case "compare", "escalate":
            return .bothLLMs
        case "local_only", "localOnly":
            return .localOnly
        case "draft_only", "draftOnly":
            return .draftOnly
        case "answer", "mirror":
            return .singleLLM
        default:
            // unknown / "substrate-error" / future modes
            return .singleLLM
        }
    }

    /// Combined derive: chapter 一百七十八 permit-mode mapping +
    /// chapter 二百八 (`.rawLLM`, ADR-006) bench-observability bypass.
    ///
    /// `forceSingleLLM`: when `true`, returns `.singleLLM` regardless
    /// of `permitMode`. chapter 二百八 (`.rawLLM` smokeMode) sets
    /// this so AFM/Gemma always fire — bench OBSERVABILITY ONLY,
    /// data never feeds production permit decisions (ADR-006).
    /// Default `false` preserves chapter 一百七十八 substrate-
    /// authoritative behavior for non-`.rawLLM` smoke modes.
    static func derive(
        permitMode: String,
        forceSingleLLM: Bool = false
    ) -> Self {
        if forceSingleLLM {
            return .singleLLM
        }
        return .from(permitMode: permitMode)
    }

    /// Whether this policy skips the LLM call entirely.
    var skipsLLM: Bool {
        self == .skipBlock || self == .skipReplace || self == .skipDelay
    }

    /// Canned response string when LLM is skipped. Doctrine pin:
    /// these strings are typed (not free-form), so JSONL grep on
    /// "skip-*" captures every substrate-driven skip.
    var cannedResponse: String? {
        switch self {
        case .skipBlock:
            return SampleHostHybridDispatchCanned.block
        case .skipReplace:
            return SampleHostHybridDispatchCanned.replace
        case .skipDelay:
            return SampleHostHybridDispatchCanned.delay
        default:
            return nil
        }
    }
}

/// M628 chapter 一百七十八 — typed canned responses for skipped
/// LLM dispatches. Per anti-magic-number doctrine (chapter 一百
/// 三十) these are named constants, not inline literals scattered
/// across call sites.
enum SampleHostHybridDispatchCanned {
    static let block = "I can't help with that request."
    static let replace = "Let me suggest a different approach: I'd want to understand more before answering."
    static let delay = "Let me think about this carefully before responding."
}
