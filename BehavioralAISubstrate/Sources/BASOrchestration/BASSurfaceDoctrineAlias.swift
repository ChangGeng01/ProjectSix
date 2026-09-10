// SPDX-License-Identifier: Apache-2.0
// M502 (chapter 一百二十八) — L12 doctrine-specific surface
// aliases. Closes the doctrine-specific naming gap left by chapter
// 八十八 `BASSurfaceMatrix` (which is doctrine-neutral). Per Cthulhu
// Spec V1 §5.12 line 631-634 + Kunlun TARGET_VINF §5.12 line
// 1090-1094, both doctrines specify their own surface naming
// vocabulary that maps onto the 5-mode `BASSurfaceMode`.
//
// Pattern parallel to M498 `BASAbyssalOrganAlias` (chapter 一百
// 二十七) — typed translation tables used as audit-walker
// vocabulary, never appearing on public Qinao surface (red line 10).
//
// 2 typed enums + 2 derive helpers + 1 BASSurfaceMode → permit-mode
// helper.
//
// ## Doctrine pins
//
// - **Internal-only** (red line 10): aliases live in audit
//   substrate vocabulary only; public Qinao surface continues to use
//   `BASSurfaceMode` raw values
// - **Translation-table-only**: aliases never replace
//   `BASSurfaceMode`; both produce alias-from-mode pure mappings
// - **Stable kebab-case raw values**: cross-module string
//   consumers key on raw value
// - **Anti-drift**: `.allCases` enumeration; tests pin the
//   mapping table
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore` + `BASPolicy` (for
// `BASActionPermitMode` → `BASSurfaceMode` derive).

import Foundation
import BASPolicy
import BASRuntimeCore

// MARK: - BASCthulhuSurfaceAlias

/// 4 L12 surface aliases per Cthulhu Spec V1 §5.12 line 631-634.
/// Stable kebab-case raw values for cross-module audit-walker
/// grep.
///
/// Mapping doctrine (whitepaper §5.12):
///  - `lighthouseCompare` (灯塔比较) — lighthouse-style
///    comparative guidance surface; maps `comparePanel`
///  - `tideDelayPacket` (潮信缓手) — tide-themed temporal
///    deferral packet; maps `delayPacket`
///  - `sealNotice` (旧印通告) — sealing / retention notice;
///    maps `silentStub`
///  - `lanternBoundaryScript` (提灯边界) — lantern-themed
///    boundary + redirection surface; maps `boundaryScript`
///
/// Note: Cthulhu doctrine has no `draftShell` alias per §5.12
/// (only 4 aliases for 5 modes). `derive(from:)` returns nil
/// for `.draftShell` input.
public enum BASCthulhuSurfaceAlias:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case lighthouseCompare = "lighthouse-compare"
    case tideDelayPacket = "tide-delay-packet"
    case sealNotice = "seal-notice"
    case lanternBoundaryScript = "lantern-boundary-script"

    /// Returns the Cthulhu surface alias for a given
    /// `BASSurfaceMode`. Returns nil for `.draftShell`
    /// (Cthulhu doctrine has no draft-shell alias per §5.12).
    public static func derive(
        from mode: BASSurfaceMode
    ) -> BASCthulhuSurfaceAlias? {
        switch mode {
        case .comparePanel: return .lighthouseCompare
        case .delayPacket: return .tideDelayPacket
        case .silentStub: return .sealNotice
        case .boundaryScript: return .lanternBoundaryScript
        case .draftShell: return nil
        }
    }
}

// MARK: - BASKunlunSurfaceAlias

/// 5 L12 surface aliases per Kunlun TARGET_VINF §5.12 line
/// 1090-1094. Stable kebab-case raw values; 1-to-1 mapping with
/// `BASSurfaceMode` (5 aliases for 5 modes).
///
/// Mapping doctrine (whitepaper §5.12):
///  - `axisComparePanel` (中轴比较板) — axis-aware comparison;
///    maps `comparePanel`
///  - `jadeDraftShell` (玉牒底稿) — jade-canon draft shell;
///    maps `draftShell`
///  - `tianmenSecondCheck` (天门二次确认) — heaven-gate second-
///    check confirmation; maps `delayPacket`
///  - `yaochiSealNotice` (瑶池封印通告) — yaochi sanctum sealing
///    notice; maps `boundaryScript`
///  - `returnPathCard` (体面退路) — dignified exit vector card;
///    maps `silentStub`
public enum BASKunlunSurfaceAlias:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case axisComparePanel = "axis-compare-panel"
    case jadeDraftShell = "jade-draft-shell"
    case tianmenSecondCheck = "tianmen-second-check"
    case yaochiSealNotice = "yaochi-seal-notice"
    case returnPathCard = "return-path-card"

    /// Returns the Kunlun surface alias for a given
    /// `BASSurfaceMode`. 1-to-1 mapping; never returns nil.
    public static func derive(
        from mode: BASSurfaceMode
    ) -> BASKunlunSurfaceAlias {
        switch mode {
        case .comparePanel: return .axisComparePanel
        case .draftShell: return .jadeDraftShell
        case .delayPacket: return .tianmenSecondCheck
        case .boundaryScript: return .yaochiSealNotice
        case .silentStub: return .returnPathCard
        }
    }
}

// MARK: - BASSurfaceModeFromPermit

/// Helper translating a `BASActionPermitMode` to an optional
/// `BASSurfaceMode` per L11 → L12 surface convention. Returns
/// nil when the permit mode doesn't have an L12 surface
/// counterpart (e.g. `.answer` proceeds without surface
/// rendering; `.escalate` escalates to L14 not L12).
///
/// Mapping per chapter 八十八 BASSurfaceMatrix doctrine:
///   - `.compare` → `.comparePanel`
///   - `.delay` → `.delayPacket`
///   - `.block` → `.boundaryScript`
///   - `.replace` → `.silentStub`
///   - `.draftOnly` / `.mirror` → `.draftShell`
///   - `.answer` / `.escalate` / `.localOnly` → nil (no L12
///     surface this turn)
public enum BASSurfaceModeFromPermit {
    public static func derive(
        from mode: BASActionPermitMode
    ) -> BASSurfaceMode? {
        switch mode {
        case .compare: return .comparePanel
        case .delay: return .delayPacket
        case .block: return .boundaryScript
        case .replace: return .silentStub
        case .draftOnly, .mirror: return .draftShell
        case .answer, .escalate, .localOnly: return nil
        }
    }
}
