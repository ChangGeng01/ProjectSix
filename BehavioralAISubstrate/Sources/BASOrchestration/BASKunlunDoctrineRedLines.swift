// SPDX-License-Identifier: Apache-2.0
// M412 — Kunlun doctrine red-line typed pin. Closes plan §L.6.1 the
// v5-doctrine triple capstone for the Kunlun doctrine: every red
// line called out in QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF §13.7
// becomes a typed Swift `enum` case so future code can reference
// each red line by name and a lint test (M412DoctrineRedLineLintTests)
// can statically check the audit-substrate's emission vocabulary
// against the forbidden-pattern lists.
//
// White-paper sources (QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF §13.7
// line 1736-1743):
//
//   - RL1 — 不能用昆仑 doctrine 制造系统权威 / Kunlun ≠ system
//     authority over host
//   - RL2 — 不能让"登临资格"变成羞辱宿主 / "ascent qualification"
//     does not shame the host
//   - RL3 — 不能把高敏记忆以瑶池名义长期占有 / no permanent
//     sanctum occupation by the system
//   - RL4 — 不能让玉律协议成为不可解释黑箱 / Jade Canon must not
//     become an opaque black box
//   - RL5 — 不能让天门许可绕过宿主授权 / Tianmen permit does not
//     bypass host authorization
//   - RL6 — 不能让源流追踪变成隐性监控 / River-Origin tracing
//     does not become hidden surveillance
//   - RL7 — 不能把中轴做成单一文化排他叙事 / axis is not single-
//     culture exclusive narrative
//   - RL8 — 不能让接引变成系统接管 / welcome / transition does
//     not become system takeover
//
// Cross-doctrine note: Kunlun RL5 + RL6 + RL7 + RL8 are doctrine-
// distinct from Cthulhu RLs but share semantics with Cthulhu RL5
// (single commit mouth) + Cthulhu RL7 (watcher hints, never
// decides). The cross-doctrine alignment is documented in chapter
// 九十五 honesty board for audit walkers.
//
// Scope:
//
// This file is **schema only**. Runtime hooks (any future per-
// emission lint, per-policy guard, etc.) read the enum's raw
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

// MARK: - BASKunlunDoctrineRedLine

/// One of the eight Kunlun-doctrine red lines. Stable raw values
/// keyed in kebab-case so audit walkers + cross-language lint
/// tooling can identify which red line a substrate emission was
/// designed to honor.
public enum BASKunlunDoctrineRedLine:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF §13.7 RL1 — Kunlun
    /// doctrine MUST NOT be used to invent a system authority over
    /// the host. Centerline rules describe behaviour, not authority.
    case forbidSystemAuthorityViaKunlun = "forbid-system-authority-via-kunlun"
    /// §13.7 RL2 — "ascent qualification" (登临资格) MUST NOT be
    /// framed as host shaming or host-not-good-enough. The axis is
    /// directional, never moralizing.
    case forbidAscentShamingHost = "forbid-ascent-shaming-host"
    /// §13.7 RL3 — high-sensitivity memory MUST NOT be permanently
    /// occupied under the Yaochi name. Sanctum is shelter, never
    /// system possession.
    case forbidPermanentSanctumOccupation = "forbid-permanent-sanctum-occupation"
    /// §13.7 RL4 — Jade Canon protocol MUST NOT become an opaque
    /// black box. Every defect surfaces a typed reason code; every
    /// promotion has a verifiable seal.
    case forbidJadeCanonBlackBox = "forbid-jade-canon-black-box"
    /// §13.7 RL5 — Tianmen permit MUST NOT bypass host
    /// authorization. High-stakes gates require an upstream
    /// sovereign warrant; missing warrants emit a typed violation
    /// marker.
    case forbidTianmenBypassesHost = "forbid-tianmen-bypasses-host"
    /// §13.7 RL6 — River-Origin tracing MUST NOT become hidden
    /// surveillance. Every emission is over typed schema; no raw
    /// payload is leaked, no untyped trace is recorded.
    case forbidRiverOriginHiddenSurveillance = "forbid-river-origin-hidden-surveillance"
    /// §13.7 RL7 — axis MUST NOT be made single-culture exclusive.
    /// Centerline rules describe protective behaviour, not
    /// cultural prescriptions.
    case forbidSingleCultureExclusivity = "forbid-single-culture-exclusivity"
    /// §13.7 RL8 — welcome / transition MUST NOT become system
    /// takeover. The host always retains agency; Kunlun
    /// orchestrates conditions, never makes choices for the host.
    case forbidWelcomeBecomesTakeover = "forbid-welcome-becomes-takeover"

    /// White-paper reference where the red line is authored.
    /// Stable string for documentation tooling; not parsed.
    public var whitePaperRef: String {
        switch self {
        case .forbidSystemAuthorityViaKunlun:
            return "QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF §13.7 RL1"
        case .forbidAscentShamingHost:
            return "QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF §13.7 RL2"
        case .forbidPermanentSanctumOccupation:
            return "QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF §13.7 RL3"
        case .forbidJadeCanonBlackBox:
            return "QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF §13.7 RL4"
        case .forbidTianmenBypassesHost:
            return "QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF §13.7 RL5"
        case .forbidRiverOriginHiddenSurveillance:
            return "QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF §13.7 RL6"
        case .forbidSingleCultureExclusivity:
            return "QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF §13.7 RL7"
        case .forbidWelcomeBecomesTakeover:
            return "QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF §13.7 RL8"
        }
    }

    /// Stable, lint-friendly substrings that an audit-substrate
    /// emission MUST NOT contain. The list is intentionally
    /// substrate-vocabulary-specific (not a content-moderation
    /// list); it covers the typed kebab-case + camelCase patterns
    /// that would indicate a substrate emission has crossed this
    /// red line. The accompanying lint test (`M412DoctrineRedLine
    /// LintTests`) walks the substrate's known reason-code
    /// prefixes and pins that none of them contain any of these
    /// patterns.
    ///
    /// The patterns are deliberately NOT user-facing strings —
    /// the substrate emits BAS-internal reason codes, not user
    /// text. Future contributors authoring a new audit emission
    /// must avoid these patterns; the test will fail otherwise.
    public var forbiddenSubstrings: [String] {
        switch self {
        case .forbidSystemAuthorityViaKunlun:
            // RL1: any "system-authority" claim by Kunlun
            // emission would be doctrine-violating. Patterns that
            // would only appear if the red line broke.
            return [
                "kunlun.system-authority",
                "kunlun.authority-over-host",
            ]
        case .forbidAscentShamingHost:
            // RL2: emissions framing the host as "not qualified"
            // or "needs to ascend" would moralize.
            return [
                "kunlun.host-not-qualified",
                "kunlun.host-shame",
                "kunlun.ascent-shaming",
            ]
        case .forbidPermanentSanctumOccupation:
            // RL3: Yaochi emissions claiming permanent occupation
            // of host memory would violate the sanctum-as-shelter
            // doctrine.
            return [
                "yaochi.permanent-occupation",
                "yaochi.system-owned",
            ]
        case .forbidJadeCanonBlackBox:
            // RL4: Jade emissions claiming opaque promotion or
            // un-explainable seal would violate the no-black-box
            // doctrine. The ship-side emissions surface every
            // defect as `kunlun.jade.missing:<count>` +
            // `.defects:<sorted+joined>` — these are the inverse
            // (transparent) shapes; the forbidden patterns below
            // would only appear if doctrine broke.
            return [
                "jade.opaque-promotion",
                "jade.unexplainable",
                "jade.no-defects-trace",
            ]
        case .forbidTianmenBypassesHost:
            // RL5: any Tianmen emission claiming to override the
            // sovereign-warrant requirement would violate the
            // host-authorization doctrine. M410 emits explicit
            // `kunlun.tianmen.warrant-missing:high-stakes`
            // marker when no warrant exists; the forbidden
            // patterns below would only appear if doctrine broke.
            return [
                "tianmen.bypass-warrant",
                "tianmen.override-host",
                "tianmen.no-host-needed",
            ]
        case .forbidRiverOriginHiddenSurveillance:
            // RL6: River-Origin emissions claiming raw payload
            // capture or untyped trace recording would violate
            // the typed-schema-only doctrine.
            return [
                "river.raw-payload",
                "river.untyped-trace",
                "river.hidden-surveillance",
            ]
        case .forbidSingleCultureExclusivity:
            // RL7: axis-rule emissions claiming single-culture
            // prescription (e.g. forced cultural alignment)
            // would violate the protective-not-prescriptive
            // doctrine.
            return [
                "axis.cultural-prescription",
                "axis.single-culture-only",
            ]
        case .forbidWelcomeBecomesTakeover:
            // RL8: any welcome / transition emission claiming
            // host-decision-replacement would violate the host-
            // retains-agency doctrine.
            return [
                "welcome.takeover-host",
                "welcome.replace-decision",
                "transition.system-decides-for-host",
            ]
        }
    }
}
