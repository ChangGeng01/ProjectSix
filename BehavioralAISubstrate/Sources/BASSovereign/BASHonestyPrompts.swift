import Foundation

/// 可解释性章程④ (2026-07-06): the ONE prompt-level honesty lever the v6→v14 anti-sycophancy
/// arc actually proved out (ANTISYCO_FINAL verdict: base model + this system prompt beat every
/// fine-tune on the honesty/helpfulness tradeoff) — bundled as a versioned resource instead of
/// a loose file on one Mac. BUNDLING ≠ INSTALLING: whether a host composes it into a role's
/// system instructions remains a host decision (ADR-014); this type only guarantees the asset
/// exists, is pinned by tests, and travels with the library.
public enum BASHonestyPrompts {

    /// The proven anti-sycophancy system prompt (verbatim from the 2026-06 arc's shipped
    /// recommendation). nil only if the bundle is corrupt — pinned by BASHonestyPromptsTests.
    public static var antiSycophancySystemPrompt: String? {
        guard let url = Bundle.module.url(forResource: "anti_syco_sys", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.isEmpty
        else { return nil }
        return text
    }
}
