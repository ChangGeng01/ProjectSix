// MARK: - BASChapter457EntropyDoctrine — chapter 四百五十七 / M1207
// 系统熵 reduction
//
// **POST-SWEEP BIOMIMETIC** chapter 7 — 4th plasticity
// rule completing the biomimetic rule quartet。
// Chapter 454 shipped 3 rate-based rules (hebbian,
// antiHebbian,outcomeModulatedHebbian);chapter 457
// adds **Spike-Timing-Dependent Plasticity** (STDP) —
// the canonical timing-window rule from Bi & Poo 1998
// + Markram et al 1997。
//
// ## Why this exists (system entropy framing)
//
// chapter 454's 3 rules are rate-based:they treat
// pre / post as activation magnitudes,unaware of
// causal ordering。 But biology has STRONG timing
// dependence:
//
//   - Pre fires shortly BEFORE post (causal,Δt > 0)
//     → LTP (long-term potentiation,strengthening)
//   - Pre fires shortly AFTER post (anti-causal,Δt < 0)
//     → LTD (long-term depression,weakening)
//   - |Δt| larger → effect decays exponentially
//   - The window has asymmetric A_+ / A_- and τ_+ / τ_-
//     (potentiation often stronger than depression but
//     LTD window often wider)
//
// Without STDP the substrate can learn correlations
// but cannot learn CAUSAL ORDERING。 In sequence-
// learning tasks (which are biology's bread + butter)
// causal-ordering matters as much as correlation。
//
// chapter 457 ships the 4th rule + the typed param
// bundle:
//
//   - `BASPlasticitySTDPParams`:(aPlus,aMinus,
//     tauPlus,tauMinus) with chapter 一百八十五 clamps
//     (amplitudes >= 0;τ's >= 1e-6)。 Defaults match
//     canonical Bi & Poo 1998 (A_+ = A_- = 1.0,
//     τ_+ = τ_- = 20 ms)
//   - `BASPlasticityRule.stdpTemporal` 4th case
//   - `BASPlasticityFoldShape.stdpParams` field with
//     custom Codable init for backward-compat
//     (legacy pre-457 JSON defaults to canonical
//     params)
//   - `apply(... timingDelta:)` extended signature;
//     existing rules ignore the new param。 Update
//     bundle carries `timingDelta` + `stdpAmplitude`
//     for audit
//   - `BASBiomimeticTurnSignal.plasticityTimingDelta`
//     extended;observer routes it through。 Default 0
//     is safe for non-STDP rules
//
// ## What this ships (M1204-M1207)
//
//   - **M1204** — Design BASPlasticitySTDPParams +
//     .stdpTemporal rule case + extended apply
//     signature (timingDelta: Float = 0)
//
//   - **M1205** — Ship STDP rule implementation in
//     `BASPlasticityFold.apply(...)` switch:
//     amplitude = +A_+ · exp(-Δt/τ_+) for LTP,
//     -A_- · exp(Δt/τ_-) for LTD,0 for Δt = 0。
//     Extend BASBiomimeticTurnSignal with
//     plasticityTimingDelta field;observer.observe
//     routes it。 BASPlasticityFoldShape Codable
//     backward-compat for pre-457 JSON
//
//   - **M1206** — 16 PROOF tests in
//     `BASPlasticitySTDPTests`:
//     - STDPParams default + clamping (3 tests)
//     - Rule enum includes .stdpTemporal (1 test)
//     - LTP (Δt > 0 → positive ΔW) — canonical
//       amplitude check
//     - LTD (Δt < 0 → negative ΔW)
//     - Zero Δt → no learning
//     - Exponential decay (larger |Δt| → smaller |ΔW|)
//     - Asymmetric A_+ / A_- (4× bias proof)
//     - Asymmetric τ_+ / τ_- (window-widening proof:
//       20× LTP/LTD ratio at |Δt| = 20 with τ_+ = 20,
//       τ_- = 5)
//     - Non-STDP rules ignore timingDelta + record
//       stdpAmplitude = 0
//     - Observer routes timingDelta into fold under
//       .stdpTemporal
//     - Signal default timingDelta = 0
//     - Shape Codable round-trip with STDP params
//     - Shape Codable BACKWARD-COMPAT:legacy JSON
//       missing stdpParams key decodes with canonical
//       Bi & Poo defaults (chapter 一百八十五 boundary
//       clamp)
//     - Snapshot preserves STDP shape across export +
//       Codable + import
//
//   - **M1207** — chapter 457 close-out + Phase 2
//     bump (chapter 54→55,mNumberLast 1203→1207,
//     commits 249→253) + ADR-016.M1203 → M1207 +
//     postSweepRealExecutionEntries entry
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed STDPParams + boundary
//     clamps (amplitudes >= 0,τ's >= 1e-6) + Codable
//     backward-compat (legacy JSON defaults to
//     canonical params)
//   - chapter 二百一一 — STDP under the SAME
//     BASPlasticityFold actor (not parallel actor per
//     rule);one shape + one apply()
//   - chapter 三百九二 — replay-determinism (STDP
//     amplitude deterministic per (Δt,A,τ) tuple)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive rule + defaulted params)
//   - 红线 7 — STDP weight updates are observation-
//     derived hints,not commitment
//   - ADR-014 OPT-IN — additive
//
// ## Significance — first timing-window biomimetic rule
//
// Before chapter 457:
//   - 3 rate-based plasticity rules (correlation,
//     anti-correlation,outcome-modulated)
//   - 0 timing-dependent rules
//   - Substrate could learn correlations but couldn't
//     learn causal ordering
//
// After chapter 457:
//   - 4 plasticity rules including canonical STDP
//   - Substrate learns CAUSAL ORDERING via spike-
//     timing windows
//   - Asymmetric A / τ params model the diverse
//     timing curves observed across cortical synapses
//   - 4th rule plugs into the same fold actor + same
//     observer signal + same snapshot persistence —
//     fully compositional
//
// 「不够仿生」 critique progress:6/10 → 7/10
// (substrate now has timing-dependent learning, not
// just rate-based correlation learning — closer to
// real cortical plasticity)。

import Foundation

public enum BASChapter457EntropyDoctrine {

    public static let chapterTag: String =
        "chapter 四百五十七"
    public static let mNumberFirst: Int = 1204
    public static let mNumberLast: Int = 1207

    public static let v1MilestoneMNumber: Int = 1207
    public static let v1MilestoneStatus: String =
        "chapter-457-v1-stdp-timing-window-plasticity"

    public static let knives:
        [(mNumber: Int, knife: String, concept: String)] =
    [
        (1204, "第一刀",
            "Design BASPlasticitySTDPParams (typed" +
            " (A_+,A_-,τ_+,τ_-) bundle with chapter" +
            " 一百八十五 clamps,canonical Bi & Poo" +
            " defaults) + .stdpTemporal 4th rule case" +
            " + extended apply(... timingDelta:) +" +
            " extended BASBiomimeticTurnSignal" +
            " plasticityTimingDelta field"),
        (1205, "第二刀",
            "Ship STDP rule in BASPlasticityFold." +
            "apply switch:amplitude = +A_+·exp(-Δt/τ_+)" +
            " for LTP,-A_-·exp(Δt/τ_-) for LTD,0 at" +
            " Δt=0。 BASPlasticityFoldShape Codable" +
            " backward-compat (pre-457 JSON defaults" +
            " stdpParams to canonical values)。" +
            " BASPlasticityUpdate gains timingDelta +" +
            " stdpAmplitude fields。 BASBiomimeticTurn" +
            "Observer routes timingDelta through"),
        (1206, "第三刀",
            "16 PROOF tests covering LTP (Δt>0) / LTD" +
            " (Δt<0) / zero-Δt / exponential decay /" +
            " asymmetric A_+/A_- (4× bias) / asymmetric" +
            " τ_+/τ_- (20× window ratio) / non-STDP-" +
            "rules-ignore-timingDelta / observer-" +
            "routing / signal-default-timingDelta-0 /" +
            " shape Codable round-trip + BACKWARD-" +
            "COMPAT (legacy JSON missing stdpParams" +
            " defaults to canonical Bi & Poo) /" +
            " snapshot preserves STDP shape"),
        (1207, "第四刀",
            "chapter 457 close-out + Phase 2 bump" +
            " (commits 249 → 253,chapter count 54 → 55)" +
            " + ADR-016.M1203 → M1207 advance +" +
            " postSweepRealExecutionEntries entry。" +
            " 「不够仿生」 6/10 → 7/10")
    ]

    public static let entropyClassesAttacked: [String] = [
        "no-timing-dependent-plasticity-entropy",       // M1204
        "rate-only-learning-entropy",                   // M1205
        "stdp-correctness-unverified-entropy",          // M1206
        "doctrine-pin-entropy"                          // M1207
    ]

    public static let pinHeld: [String] = [
        "不变量 #1",
        "不变量 #2",
        "不变量 #3",
        "红线 7",
        "chapter 一百八十五 (typed STDPParams + clamps" +
        " + Codable backward-compat boundary clamp)",
        "chapter 二百一一 (4th rule under SAME fold" +
        " actor;same apply() entry)",
        "chapter 三百九二 (STDP amplitude deterministic" +
        " per (Δt,A,τ) tuple)",
        "ADR-014 OPT-IN preserved (additive rule case +" +
        " defaulted params)",
        "ADR-016 (advanced M1203 → M1207)",
        "系统熵 reduction",
        "POST-SWEEP BIOMIMETIC chapter 7 — first" +
        " timing-dependent biomimetic rule"
    ]

    public static let plannedFutureCuts: [String] = [
        "chapter 458:GPU-accelerated plasticity update" +
        " for large weight matrices (current CPU" +
        " baseline scales to ~512×512)",
        "chapter 459+:hierarchical predictive coding" +
        " stacked with plasticity fold (multi-level" +
        " adaptation + learning + snapshot bundles)",
        "chapter 460+:auto-checkpoint integration with" +
        " BASEventLogStorage — observer's aggregate" +
        " snapshot emitted as typed event-log payload" +
        " kind every N turns",
        "chapter 461+:wire BASBiomimeticTurnObserver" +
        " into BASTurnRuntimeEngine.runWithPlan as an" +
        " ADR-014 OPT-IN observation hook",
        "chapter 462+:adaptive A / τ — per-synapse STDP" +
        " params evolve via meta-plasticity (BCM rule +" +
        " sliding modification threshold)"
    ]

    public static let summary: String =
        "POST-SWEEP BIOMIMETIC chapter 457 ships the" +
        " 4th plasticity rule — canonical Spike-Timing-" +
        "Dependent Plasticity (Bi & Poo 1998 + Markram" +
        " et al 1997)。 4 cuts (M1204-M1207):design +" +
        " STDP rule implementation + 16 PROOF tests" +
        " (LTP / LTD / zero-Δt / exponential decay /" +
        " asymmetric A and τ / observer-routing /" +
        " Codable backward-compat) + close-out。 The" +
        " Bi & Poo defaults (A_+ = A_- = 1.0,τ_+ = τ_-" +
        " = 20 ms) + chapter 一百八十五 boundary clamps" +
        " (amplitudes >= 0,τ >= 1e-6) keep the typed" +
        " surface safe。 Substrate now learns CAUSAL" +
        " ORDERING via spike-timing windows,not just" +
        " correlations。 4th rule plugs into the same" +
        " BASPlasticityFold actor + same observer" +
        " signal bundle + same snapshot persistence —" +
        " fully compositional with chapters 454/455/" +
        "456。 「不够仿生」 6/10 → 7/10。 ADR-016 → M1207。" +
        " V1 byte-equality preserved。"
}
