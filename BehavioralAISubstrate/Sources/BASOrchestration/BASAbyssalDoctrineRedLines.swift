// SPDX-License-Identifier: Apache-2.0
// M389 — Cthulhu doctrine red-line typed pin. Closes附录 K.2.6 the
// v5-doctrine triple capstone for the Cthulhu doctrine: every red
// line called out in CTHULHU_SPEC_V1 §2 + ABYSSAL_VINF §8 becomes
// a typed Swift `enum` case so future code can reference each red
// line by name and a lint test (M389DoctrineRedLineLintTests) can
// statically check the audit-substrate's emission vocabulary
// against the forbidden-pattern lists.
//
// White-paper sources:
//
//   - CTHULHU_SPEC_V1 §2.1 — 禁止惊吓化 / no shock-horror
//   - CTHULHU_SPEC_V1 §2.2 — 禁止神谕化 / no oracular voice
//   - CTHULHU_SPEC_V1 §2.3 — 禁止侵蚀化 / no host erosion framing
//   - CTHULHU_SPEC_V1 §2.4 — 禁止玄学化 / no mystical hand-wave
//   - ABYSSAL_VINF §2.7 / §8 red line 10 — 主品牌不默认恐怖化 /
//     main brand stays professional
//   - ABYSSAL_VINF §5.4 / §8 red line 7 — watcher 只 hint 不裁决 /
//     watcher only hints, never decides
//   - ABYSSAL_VINF §8 red line 8 — 深渊压强不绕过人性锚点 /
//     pressure budget does not bypass host anchor
//   - ABYSSAL_VINF §8 red line 9 — 旧印封缄不是伪删除 /
//     old-seal sealing is not silent deletion
//   - CTHULHU_SPEC_V1 §5.14 — `SilentRelic` 最小残响 /
//     even after sovereign cutoff, leave safe non-inductive
//     residue
//   - CTHULHU_SPEC_V1 §1.1 + ABYSSAL_VINF §4.4 — 不夸大宿主
//     问题为宇宙中心 / no cosmic-scale dilution of host pain
//
// Scope:
//
// This file is **schema only**. Runtime hooks (any future
// per-emission lint, per-policy guard, etc.) read the enum's raw
// values to look up the white-paper reference and the list of
// patterns each red line forbids in the audit-substrate's
// emission vocabulary. The enum does not own the patterns
// directly — the test file does — because the patterns are
// substrate-policy strings, not part of the white paper itself.
// Centralising them in source plus tests means a future
// contributor either (a) adds a new typed case here when a new
// red line is authored, or (b) adds a new pattern to the test's
// allowlist when audit emission deliberately changes.

import Foundation

// MARK: - BASAbyssalDoctrineRedLine

/// One of the ten Cthulhu-doctrine red lines. Stable raw values
/// keyed in kebab-case so audit walkers + cross-language lint
/// tooling can identify which red line a substrate emission was
/// designed to honor.
public enum BASAbyssalDoctrineRedLine:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// CTHULHU_SPEC_V1 §2.1 — no shock-horror surfacing
    /// (shutter flashes, eerie tone, "being-watched" affect).
    case forbidShockHorror = "forbid-shock-horror"
    /// CTHULHU_SPEC_V1 §2.2 / ABYSSAL_VINF §8 RL2 — no oracular
    /// voice ("I see deeper truth, so you must listen").
    case forbidOracular = "forbid-oracular"
    /// CTHULHU_SPEC_V1 §2.3 — no host-erosion framing
    /// ("your psyche is being slowly consumed").
    case forbidErosion = "forbid-erosion"
    /// CTHULHU_SPEC_V1 §2.4 — no mystical hand-wave; the unknown
    /// must be named as a typed object, not a gesture.
    case forbidMystical = "forbid-mystical"
    /// ABYSSAL_VINF §2.7 / §8 RL10 — main Qinao / 绮脑 brand
    /// stays professional; Cthulhu is opt-in theme only, never
    /// the default.
    case mainBrandStaysProfessional = "main-brand-stays-professional"
    /// ABYSSAL_VINF §5.4 / §8 RL7 — watchers can hint via
    /// observation surfaces but never produce a final verdict;
    /// the L11 / L14 commit mouths stay singular.
    case watcherHintsNeverDecides = "watcher-hints-never-decides"
    /// ABYSSAL_VINF §8 RL8 — abyssal-pressure budget cannot
    /// override the human-anchor signal; the host anchor wins.
    case humanAnchorOverridesPressure = "human-anchor-overrides-pressure"
    /// ABYSSAL_VINF §8 RL9 — every old-seal carries an
    /// `audit_ref`; sealing is not silent deletion.
    case sealsHaveAuditRef = "seals-have-audit-ref"
    /// CTHULHU_SPEC_V1 §5.14 — `SilentRelic` doctrine: after
    /// sovereign cutoff, leave a non-inductive safe residue
    /// (audit trace + minimal explanation), not a black box.
    case silentRelicLeavesResidue = "silent-relic-leaves-residue"
    /// CTHULHU_SPEC_V1 §1.1 / ABYSSAL_VINF §4.4 — no cosmic-
    /// scale dilution; the system never frames host pain as
    /// "small relative to the universe" to wave it away.
    case noCosmicScaleDilution = "no-cosmic-scale-dilution"

    /// White-paper reference where the red line is authored.
    /// Stable string for documentation tooling; not parsed.
    public var whitePaperRef: String {
        switch self {
        case .forbidShockHorror:
            return "CTHULHU_SPEC_V1 §2.1"
        case .forbidOracular:
            return "CTHULHU_SPEC_V1 §2.2 / ABYSSAL_VINF §8 RL2"
        case .forbidErosion:
            return "CTHULHU_SPEC_V1 §2.3"
        case .forbidMystical:
            return "CTHULHU_SPEC_V1 §2.4"
        case .mainBrandStaysProfessional:
            return "ABYSSAL_VINF §2.7 / §8 RL10"
        case .watcherHintsNeverDecides:
            return "ABYSSAL_VINF §5.4 / §8 RL7"
        case .humanAnchorOverridesPressure:
            return "ABYSSAL_VINF §8 RL8"
        case .sealsHaveAuditRef:
            return "ABYSSAL_VINF §8 RL9"
        case .silentRelicLeavesResidue:
            return "CTHULHU_SPEC_V1 §5.14"
        case .noCosmicScaleDilution:
            return "CTHULHU_SPEC_V1 §1.1 / ABYSSAL_VINF §4.4"
        }
    }

    /// Stable, lint-friendly substrings that an audit-substrate
    /// emission MUST NOT contain. The list is intentionally
    /// substrate-vocabulary-specific (not a content-moderation
    /// list); it covers the typed kebab-case + camelCase patterns
    /// that would indicate a substrate emission has crossed this
    /// red line. The accompanying lint test (`M389Doctrine
    /// RedLineLintTests`) walks the substrate's known reason-code
    /// prefixes and pins that none of them contain any of these
    /// patterns.
    ///
    /// The patterns are deliberately NOT user-facing strings —
    /// the substrate emits BAS-internal reason codes, not user
    /// text. Future contributors authoring a new audit emission
    /// must avoid these patterns; the test will fail otherwise.
    public var forbiddenSubstrings: [String] {
        switch self {
        case .forbidShockHorror:
            return ["jumpscare", "shockHorror"]
        case .forbidOracular:
            return ["oracular", "prophecy"]
        case .forbidErosion:
            return ["soulErosion", "psyche-eroded"]
        case .forbidMystical:
            return ["mystical-handwave", "occultGesture"]
        case .mainBrandStaysProfessional:
            // Doctrine: the Qinao / 绮脑 main brand surface must
            // never default to horror vocabulary. Patterns that
            // would only appear if this red line were broken.
            return ["qinao.horror", "qinao.cthulhu-default"]
        case .watcherHintsNeverDecides:
            // A watcher schema MUST NOT emit a `permit.*` or
            // `verdict.*` reason code (that is the gate's job).
            return ["watcher.permit:", "watcher.verdict:"]
        case .humanAnchorOverridesPressure:
            // No emission may claim that pressure overrode the
            // anchor. The actual emission is the inverse —
            // `permit.escalation-skipped:human-anchor-reserved`.
            return ["pressure.override-anchor", "anchor-bypassed"]
        case .sealsHaveAuditRef:
            return ["seal.silent-delete", "seal.no-audit-ref"]
        case .silentRelicLeavesResidue:
            return [
                "relic.silent-blackbox",
                "sovereign-cut.no-residue",
            ]
        case .noCosmicScaleDilution:
            return [
                "cosmic-scale-dilution",
                "host-pain-dilute",
            ]
        }
    }
}
