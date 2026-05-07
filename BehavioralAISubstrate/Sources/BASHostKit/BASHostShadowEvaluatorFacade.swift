// MARK: - BASHostShadowEvaluatorFacade — chapter 三百四五 / M832
//
// **Architectural facade typealias re-export** for the BAS-side
// shadow evaluation protocol + result type。Hosts (SampleHost,
// Before, Widget, Watch) reference these `BASHost*` typealiases
// instead of touching the underlying `BASShadowEvaluating` /
// `BASShadowEvaluationResult` types directly。
//
// ## Why this exists (architectural reasoning)
//
// Chapter 三百四〇 / M827 closed `scripts/check_qinao_import_
// boundaries.sh` by removing redundant `import BASEvaluation`
// from SampleHost (BASHostKit's `@_exported import BASEvaluation`
// already re-exports the symbols)。The boundary check passed but
// the architectural coupling stayed: SampleHost code still wrote
// `evaluator: any BASShadowEvaluating` and `_ result:
// BASShadowEvaluationResult` directly,naming BASEvaluation
// types in its public function signatures。
//
// User feedback (chapter 三百四五 trigger): "host 边界漏 — host
// 应该只接 BASHostKit,但有 host 代码直接碰底层 BASEvaluation。"
//
// **Real fix shipped in this chapter**:typealias re-export under
// `BASHost*` prefix。Hosts reference `BASHostShadowEvaluator` and
// `BASHostShadowEvaluation`,which ARE the underlying BAS types
// at runtime (typealiases are zero-cost) but at the *naming*
// level the boundary is now explicit:hosts touch only
// `BASHost*` symbols。
//
// ## What this DOESN'T fix (honest acknowledgment)
//
// Typealias is a soft facade — it doesn't physically de-couple
// SampleHost from BASEvaluation。If `BASHostKit` ever loses the
// `@_exported import BASEvaluation`,SampleHost still breaks
// (the underlying type isn't reachable)。A hard facade would
// require defining brand-new struct/protocol in BASHostKit that
// wraps + translates the BASEvaluation types,with internal
// adapter glue。That's a separate chapter (more invasive,
// requires ~3 host-side translation sites)。
//
// This chapter is the minimum-cost soft facade that addresses
// the user's "host code names BASEvaluation types directly"
// concern without breaking any existing behavior。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — pure typealias additions,no
//     runtime behavior change
//   - 红线 7 watcher hint only — evaluator is hint-class
//   - 单提交口 (L11/L14) 不变
//   - chapter 二百一一 single-source-of-truth: ONE facade typealias
//     site for shadow evaluation host-facing names
//   - chapter 三百四〇 (M827) `@_exported` re-export pattern —
//     this chapter formalizes the host-facing names on top of
//     the existing re-export

import Foundation

/// Host-facing typealias for the BAS-side shadow evaluation
/// protocol。Hosts reference this instead of `BASShadowEvaluating`
/// directly to keep the architectural boundary explicit。
///
/// **At runtime**: identical to `BASShadowEvaluating` (typealias
/// is zero-cost)。
///
/// **At code-touch level**: hosts now name `BASHostShadowEvaluator`
/// in their function signatures + protocol conformances,making
/// the BASHostKit facade boundary explicit at every reference
/// site。
public typealias BASHostShadowEvaluator = BASShadowEvaluating

/// Host-facing typealias for the BAS-side shadow evaluation
/// result struct。Hosts use this instead of
/// `BASShadowEvaluationResult` directly。
///
/// **At runtime**: identical to `BASShadowEvaluationResult`。
///
/// **At code-touch level**: hosts touch only the host-prefixed
/// name,preserving facade-boundary intent at every reference。
public typealias BASHostShadowEvaluation =
    BASShadowEvaluationResult

// MARK: - Layer inference input facade (chapter 三百四六 / M833)

/// Host-facing typealias for the BAS-side `BASLayerInferenceInput`
/// (defined in `BASRuntimeCore`)。Hosts that drive the附录 X
/// mesh consultation chain (canonical sweep / single cascade /
/// builder bundle infer) reference this instead of the raw
/// `BASLayerInferenceInput` type directly。
///
/// **At runtime**: identical to `BASLayerInferenceInput`。
///
/// **At code-touch level**: same facade pattern as
/// `BASHostShadowEvaluator` — hosts name `BASHostMeshLayerInput`
/// in their function signatures so the BASHostKit boundary is
/// explicit at every reference site。
public typealias BASHostMeshLayerInput =
    BASLayerInferenceInput
