// SPDX-License-Identifier: Apache-2.0
// M459 (chapter 一百二十一) — L2 异相器官 organ semantic aliases
// per Cthulhu Spec V1 §5.2 + Abyssal VINF §4.2.
//
// ## Why this exists
//
// Phase 1 strict audit of 14-layer Cthulhu coverage (chapter 一百二十
// 一 audit) revealed L2 organ aliases as a real whitepaper gap:
// Cthulhu Spec V1 §5.2 specifies 4 organ semantics (异相候选器官 /
// 反事实锻炉 / 批判刃核 / 旧印残响核); Abyssal VINF §4.2 lists 6
// organ names (主核皮层 / 反事实锻炉 / 批判刃核 / 风险脊 / 旧印核
// / 最小残响核). Phase 1 grep returned 0 typed aliases — the
// substrate had `BASOrganRegistry` / `BASOrganAdapter` etc. but no
// Cthulhu-aliased subset.
//
// This file ships the typed alias enum. Per Cthulhu Spec V1 §5.2
// doctrine: "只是器官语义，不是怪物化。对外仍保持正式命名,
// 对内可有深渊代号." — the aliases are INTERNAL audit-walker
// vocabulary, not user-facing organ names. Public Qinao surface
// continues to use formal names (Scout/Memory/Planner/etc.).
//
// ## Doctrine pins
//
// - **Internal-only naming**: per RL10 (主品牌不默认恐怖化),
//   these aliases never appear on public Qinao surface or UI.
//   They live in audit substrate vocabulary only.
// - **Stable kebab-case raw values**: cross-module string
//   consumers key on raw value; case names are Swift-conformant.
// - **Anti-drift**: 6 cases enumerated; tests walk `.allCases`
//   to catch future enum-case additions.
//
// ## DAG discipline
//
// Imports `Foundation` only.

import Foundation

// MARK: - BASAbyssalOrganAlias

/// 6 L2 organ semantic aliases per Abyssal VINF §4.2 + Cthulhu
/// Spec V1 §5.2. Stable kebab-case raw values for cross-module
/// audit-walker grep.
///
/// Per Abyssal VINF §4.2 mapping doctrine:
///
///  - `mainCoreCortex` (主核皮层) — primary cortex; Scout/Memory
///    semantic equivalent
///  - `counterfactualForge` (反事实锻炉) — counterfactual
///    generation organ; Planner/dream-loop equivalent
///  - `critiqueBladeCore` (批判刃核) — critic organ; L10 tribunal
///    + L7 mirror blade equivalent
///  - `riskRidge` (风险脊) — risk-detection ridge; L11
///    risk-climate equivalent
///  - `oldSealCore` (旧印核) — old-seal core; L14 sovereign
///    equivalent
///  - `minimalResonanceCore` (最小残响核) — minimal-residue
///    output organ; L14 stub-renderer equivalent
public enum BASAbyssalOrganAlias:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case mainCoreCortex = "main-core-cortex"
    case counterfactualForge = "counterfactual-forge"
    case critiqueBladeCore = "critique-blade-core"
    case riskRidge = "risk-ridge"
    case oldSealCore = "old-seal-core"
    case minimalResonanceCore = "minimal-resonance-core"

    /// White-paper anchor for each alias. Audit-walkers use this
    /// to navigate from typed code back to whitepaper §.
    public var whitePaperRef: String {
        switch self {
        case .mainCoreCortex:
            return "ABYSSAL_VINF §4.2 + CTHULHU_SPEC_V1 §5.2"
        case .counterfactualForge:
            return "ABYSSAL_VINF §4.2 + CTHULHU_SPEC_V1 §5.2 (anomalous-candidate organ)"
        case .critiqueBladeCore:
            return "ABYSSAL_VINF §4.2 + CTHULHU_SPEC_V1 §5.2"
        case .riskRidge:
            return "ABYSSAL_VINF §4.2"
        case .oldSealCore:
            return "ABYSSAL_VINF §4.2 + CTHULHU_SPEC_V1 §5.2 (旧印残响核)"
        case .minimalResonanceCore:
            return "ABYSSAL_VINF §4.2"
        }
    }

    /// Public Qinao surface name (formal, non-Cthulhu). Per
    /// RL10 doctrine — public vocabulary always non-恐怖化.
    public var publicSurfaceName: String {
        switch self {
        case .mainCoreCortex:
            return "Scout"
        case .counterfactualForge:
            return "Planner"
        case .critiqueBladeCore:
            return "Critic"
        case .riskRidge:
            return "Risk"
        case .oldSealCore:
            return "Sovereign"
        case .minimalResonanceCore:
            return "MinimalSurface"
        }
    }
}
