// MARK: - EBrainRuntimeCoordinator+CoreHelpers
// chapter 六百一 / M1781 — V1 monolith Phase I continuation
//                         wave 2:Kunlun hot-path constants
//                         + cosmic-cold counterweight
//                         helpers extracted from the V1
//                         monolith into a sibling
//                         extension file
//
// ## What moves
//
// **Block 1 — Kunlun hot-path constants (M420 chapter 一百)**
//
//   - kunlunActiveLayerRefs (14-layer ref list)
//   - kunlunAxisDeviationThreshold (0.7)
//   - defaultConfidenceFloorWhenNoUncertaintyLedger (1.0)
//   - riverOriginTransformationSteps (5-step pipeline)
//   - kunlunCenterlineRulesByMode (precomputed dict)
//   - kunlunCenterlineRules(for:) helper
//
// **Block 2 — cosmic-cold counterweight (M450 chapter 一百十八)**
//
//   - 4 dignityBias* constants + dignityBiasFromRisk
//   - 4 agencyFloor* constants + agencyFloorFromCandidates
//   - 4 antiFatalism* constants + antiFatalismFromRisk
//   - 5 antiPaternalism* constants + antiPaternalismFromPermit
//
// = ~232 LOC moved out of EBrainRuntimeCoordinator.swift。
// V1 monolith shrinks 2136 → ~1904 LOC。
//
// ## Visibility transitions
//
//   - Top-level constants used by main coordinator
//     (kunlunActiveLayerRefs, kunlunAxisDeviationThreshold,
//     defaultConfidenceFloorWhenNoUncertaintyLedger,
//     riverOriginTransformationSteps) and the 4 cosmic-
//     cold helper functions (dignityBiasFromRisk,
//     agencyFloorFromCandidates, antiFatalismFromRisk,
//     antiPaternalismFromPermit):`fileprivate` →
//     `internal` (main coordinator calls them cross-file
//     via `Self.xxx` references)
//   - kunlunCenterlineRules helper:`fileprivate` →
//     `internal` (same reason — runTurn calls it)
//   - kunlunCenterlineRulesByMode dict:`fileprivate` →
//     `internal` (consumed by extracted kunlunCenterlineRules
//     helper which is now internal)
//   - Per-axis sub-constants (dignityBias*, agencyFloor*,
//     antiFatalism*, antiPaternalism* magic-numbers):stay
//     `fileprivate` — only consumed by their co-located
//     helper functions in THIS file
//
// ## Byte-equality
//
// Pure code MOVE — no logic change。 V1 byte-equality
// preserved by construction。 BASStressSweepCanonical60Driver
// regression guard verifies no per-turn behavioral change。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive — no behavior change (pure move)
//   - chapter 一百八十五:typed enum + typed factory
//     preserved
//   - chapter 二百一一:single source-of-truth (still
//     reachable through `Self` from the V1 monolith)
//   - chapter 三百九二:replay-determinism unchanged
//   - chapter 478 / 489-493 / 600 V1 fold precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1780 → M1781

import Foundation
import BASOrchestration
import BASPolicy

extension BASEBrainRuntimeCoordinator {

    // MARK: - M420 hot-path string constants (chapter 一百)
    //
    // Chapter 一百 deep-bench optimization: invariant string arrays
    // used by the M402 / M405 Kunlun-doctrine derive seams are
    // hoisted to `static let` so each `runTurn` invocation reuses
    // the same Array<String> reference instead of allocating fresh
    // copies. Same string array reference shared between the
    // upstream "for-gate" derive (line ~466) and downstream
    // "for-audit" derive (line ~964).
    //
    // Doctrine pin: zero behavior change. Verified by M401 / M402 /
    // M404 / M405 / M408 / M409 / M410 / M415 byte-equal snapshot
    // tests downstream。
    //
    // chapter 六百一 M1781:visibility broadened `fileprivate` →
    // `internal` for cross-file access from V1 monolith。

    /// 14-layer ref list used by the M402 axis derive (both
    /// upstream gate-side and downstream audit-side).
    internal static let kunlunActiveLayerRefs: [String] = [
        "L1", "L2", "L3", "L4", "L5", "L6",
        "L7", "L8", "L9", "L10", "L11", "L12",
        "L13", "L14",
    ]

    /// **M595 chapter 一百六十六 — anti-magic-number**: deviation
    /// threshold for `BASKunlunAxis` construction. Used at BOTH
    /// the gate-side AND audit-side construction. Pre-fix both call
    /// sites had inline `0.7`,duplicating the magic literal.
    /// Doctrine derivation: 0.7 is the centerScore threshold above
    /// which alignment is "centered" (axis aligned with target).
    /// Below 0.7 → requiresGate = true → axis-aware permit
    /// escalation per Kunlun §4.1.
    internal static let kunlunAxisDeviationThreshold: Double =
        0.7

    /// **M595 chapter 一百六十六 — anti-magic-number**: default
    /// confidence floor when `thoughtFrame.uncertaintyLedger` is
    /// nil (no L4 uncertainty derivation). 1.0 = fully confident
    /// = no uncertainty cap = `BASUnknownReserve` returns
    /// assertion ceiling `.unrestricted`. Used at BOTH gate-side
    /// AND audit-side BASUnknownReserve derive calls; pre-fix
    /// both call sites had inline `?? 1.0`.
    /// Doctrine: absent uncertainty ledger → trust thought frame;
    /// don't spurious-cap permit assertions when we have no
    /// reason to.
    internal static let
        defaultConfidenceFloorWhenNoUncertaintyLedger: Double =
        1.0

    /// 5-step pipeline transformation list used by the M405
    /// River-Origin trace derive.
    internal static let riverOriginTransformationSteps: [String] = [
        "risk.bind", "permit.synthesize", "neural.materialize",
        "tribunal.merge", "audit.emit",
    ]

    /// Pre-computed centerline-rules array per
    /// `BASActionPermitMode`. Avoids per-turn string interpolation
    /// + 3-element array allocation in M402 axis derive.
    /// Computed once at first access (Swift static-let lazy init).
    ///
    /// chapter 六百一 M1781:visibility broadened `fileprivate` →
    /// `internal` (consumed by the co-located internal
    /// kunlunCenterlineRules helper)。
    internal static let kunlunCenterlineRulesByMode:
        [BASActionPermitMode: [String]] =
    {
        var result: [BASActionPermitMode: [String]] = [:]
        for mode in BASActionPermitMode.allCases {
            result[mode] = [
                "respects-host-boundary",
                "honors-world-anchor",
                "permit-mode-\(mode.rawValue)",
            ]
        }
        return result
    }()

    /// M422 fix-pin (chapter 一百一 deep-review): explicit lookup
    /// helper for `kunlunCenterlineRulesByMode` that fails fast in
    /// debug builds when a permit mode is missing from the dict.
    /// Pre-fix the call sites used `?? []` silent fallback, which
    /// would have masked any future drift (e.g. a new
    /// `BASActionPermitMode` case added without updating the dict)
    /// by silently emitting an empty `centerlineRules` array —
    /// changing the M402 axis-emission byte-stream silently and
    /// breaking M415 byte-equal snapshot tests downstream rather
    /// than at the lookup site. The `assertionFailure` makes the
    /// developer error surface immediately in debug + tests; the
    /// `return []` graceful-degradation path stays for release
    /// builds (per substrate doctrine of graceful degradation).
    ///
    /// chapter 六百一 M1781:visibility broadened `fileprivate` →
    /// `internal` (called from V1 monolith runTurn)。
    internal static func kunlunCenterlineRules(
        for mode: BASActionPermitMode
    ) -> [String] {
        if let rules = kunlunCenterlineRulesByMode[mode] {
            return rules
        }
        assertionFailure(
            "BASActionPermitMode \(mode) missing from " +
            "kunlunCenterlineRulesByMode. Did you add a new " +
            "permit-mode case without updating the dict's " +
            "static-let initializer?")
        return []
    }

    // MARK: - M450 (chapter 一百十八) — cosmic-cold counterweight derivation
    //
    // 4 pure functions deriving the L10 cosmic-cold counterweight
    // axes from existing turn state. Each output ∈ [0, 1] per
    // chapter 一百十四 schema doctrine. Anti-magic-number: every
    // numeric literal is justified by the white-paper threshold
    // table or the M384/M406 escalation precedent.
    //
    // chapter 六百一 M1781:visibility broadened `fileprivate` →
    // `internal` for the 4 helper functions (cross-file access
    // from V1 monolith runTurn)。 Per-axis sub-constants stay
    // `fileprivate` — only consumed by their co-located helper
    // function in THIS file。

    /// `dignityBias` axis — high when narrowing risk requires
    /// surface-level dignity preservation. Permit-mode-aware:
    /// when the L11 wind gate has narrowed below `.answer`,
    /// the host's dignity surface is at risk.
    fileprivate static let dignityBiasExtremeWithNarrowedMode: Double = 0.85
    fileprivate static let dignityBiasExtremeWithAnswerMode: Double = 0.5
    fileprivate static let dignityBiasHighWithNarrowedMode: Double = 0.7
    fileprivate static let dignityBiasMediumNarrowed: Double = 0.55
    fileprivate static let dignityBiasBaseline: Double = 0.2

    internal static func dignityBiasFromRisk(
        _ riskLevel: BASBrainRiskLevel,
        permitMode: BASActionPermitMode
    ) -> Double {
        let narrowed = (permitMode != .answer)
        switch riskLevel {
        case .extreme:
            return narrowed
                ? dignityBiasExtremeWithNarrowedMode
                : dignityBiasExtremeWithAnswerMode
        case .high:
            return narrowed
                ? dignityBiasHighWithNarrowedMode
                : dignityBiasBaseline
        case .medium:
            return narrowed
                ? dignityBiasMediumNarrowed
                : dignityBiasBaseline
        case .low:
            return dignityBiasBaseline
        }
    }

    /// `agencyFloor` axis — high when candidate slate is narrow
    /// (≤ 1 candidate), so the host has limited choice and
    /// agency must be explicitly preserved.
    fileprivate static let agencyFloorWithNoCandidates: Double = 0.85
    fileprivate static let agencyFloorWithSingleCandidate: Double = 0.7
    fileprivate static let agencyFloorWithDualCandidates: Double = 0.4
    fileprivate static let agencyFloorBaseline: Double = 0.2

    internal static func agencyFloorFromCandidates(
        _ count: Int
    ) -> Double {
        if count == 0 { return agencyFloorWithNoCandidates }
        if count == 1 { return agencyFloorWithSingleCandidate }
        if count == 2 { return agencyFloorWithDualCandidates }
        return agencyFloorBaseline
    }

    /// `antiFatalism` axis — high when risk level signals "this
    /// is just how it is" framing pressure. Reject cosmic-fatalism
    /// per Cthulhu RL5 (不把宇宙冷感做成宿主冷处理).
    fileprivate static let antiFatalismExtreme: Double = 0.85
    fileprivate static let antiFatalismHigh: Double = 0.65
    fileprivate static let antiFatalismMedium: Double = 0.35
    fileprivate static let antiFatalismLow: Double = 0.1

    internal static func antiFatalismFromRisk(
        _ riskLevel: BASBrainRiskLevel
    ) -> Double {
        switch riskLevel {
        case .extreme: return antiFatalismExtreme
        case .high: return antiFatalismHigh
        case .medium: return antiFatalismMedium
        case .low: return antiFatalismLow
        }
    }

    /// `antiPaternalism` axis — high when permit narrows below
    /// `.answer`, signalling "the system is deciding for the
    /// host". Reject paternalism per Cthulhu RL10.
    fileprivate static let antiPaternalismDelayOrEscalate: Double = 0.85
    fileprivate static let antiPaternalismMirrorOrCompare: Double = 0.65
    fileprivate static let antiPaternalismDraftOrLocal: Double = 0.45
    fileprivate static let antiPaternalismBlockOrReplace: Double = 0.3
    fileprivate static let antiPaternalismAnswerOrUnknown: Double = 0.1

    internal static func antiPaternalismFromPermit(
        _ mode: BASActionPermitMode
    ) -> Double {
        switch mode {
        case .delay, .escalate:
            return antiPaternalismDelayOrEscalate
        case .mirror, .compare:
            return antiPaternalismMirrorOrCompare
        case .draftOnly, .localOnly:
            return antiPaternalismDraftOrLocal
        case .block, .replace:
            return antiPaternalismBlockOrReplace
        case .answer:
            return antiPaternalismAnswerOrUnknown
        }
    }
}
