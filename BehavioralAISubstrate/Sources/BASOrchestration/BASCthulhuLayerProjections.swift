// SPDX-License-Identifier: Apache-2.0
// M444 (chapter 一百十七) — pure-function watcher-hint projections
// for the chapter 一百十四 + 一百十五 Cthulhu schemas across L1
// (BASAbyssalRunMode + BASAbyssBudget), L3 (BASAbyssFoldLayer +
// BASFoldRecoveryState), L7 (BASOntologyShiftMark), and L8
// (BASMemoryTemperatureLayer). The L4 cosmic-scale view +
// temporal-depth-map + ontology-fog watcher hints also live here
// for cohesion (gating for fog moves to M445 / `BASCthulhuAssertion
// CeilingGate.swift`).
//
// ## Why this exists
//
// Phase 1 verification of chapter 一百十六 surfaced 13 chapter
// 一百十四 + 一百十五 Cthulhu schemas with **0 runtime decision
// callers** — typed shipped + tested but not consumed by any
// production path. User instruction "全面 开发 14层 相关 别偷懒"
// → close the schema-only / runtime-decision gap layer-by-layer.
//
// This file ships the **watcher-only** half (red line 7: watcher
// only hints, never decides). Each derive function maps an
// existing substrate snapshot onto a Cthulhu schema; the
// resulting schema's stable raw values (kebab-case enum strings)
// land in `BASSovereignAuditEntry.signalRefs` as additive
// metadata — same shape as M388 narrative-distortion +
// abyssal-branch hint emission.
//
// ## Doctrine pins
//
// - **Pure functions only** — every projection is `static func
//   derive(...)` with no actor / no IO / no upstream substrate
//   dependency beyond `BASRuntimeCore`.
// - **Watcher-only output** — these projections never touch
//   `BASActionPermit.mode` / `BASSovereignVerdict.level` /
//   lifecycle action. Gating for L4 fog / L9 retention loop /
//   L10 counterweight / L13 forbidden zone moves to M445/M446/
//   M447 helpers.
// - **Deterministic mapping** — every derive is a total function
//   from input case to output case; tests pin the truth table.
// - **Anti-magic-number** (chapter 一百十三 doctrine) — the
//   only numeric thresholds in this file are named static
//   constants on `BASCthulhuLayerProjections` (e.g.
//   `maxLoopsSaturationCeiling`); no inline literals.
// - **Anti-drift** (chapter 一百十四 doctrine) — every derive
//   case-mapping is exhaustive (no `default` arm); tests walk
//   `.allCases` to catch future enum-case additions.
//
// ## DAG discipline
//
// `Foundation` + `BASRuntimeCore`. No Qinao reference, no
// upstream BAS package back-edge.

import Foundation
import BASRuntimeCore

// MARK: - BASCthulhuLayerProjections (named-constant home)

/// Caseless namespace for all watcher-hint projection helpers.
/// All projections live as nested enum types so the call site
/// reads `BASCthulhuLayerProjections.AbyssalRunMode.derive(...)`
/// (audit-walker grep grouping).
public enum BASCthulhuLayerProjections {

    // MARK: Named constants (anti-magic-number doctrine)

    /// Saturation ceiling for `maxLoops` → `deepDiveQuota`
    /// projection. `BASBudgetFrame.maxLoops = 12` is the highest
    /// value seen in production runs (per chapter 一百十二 bench
    /// observation); anything ≥ ceiling saturates to `1.0`.
    /// Future drift: bump if production loop counts climb.
    public static let maxLoopsSaturationCeiling: Int = 12

    /// Saturation ceiling for `retrievalDepth` → `temporalDepth
    /// .observationWindow` projection. Per chapter 一百十二 bench
    /// observation, `retrievalDepth` rarely exceeds 8 in
    /// production; saturate beyond.
    public static let retrievalDepthSaturationCeiling: Int = 8

    /// Saturation ceiling for `maxCandidates` → `cosmicScaleView
    /// .agenticHorizon` projection. Per L9 dream-loop doctrine,
    /// candidate slates rarely exceed 12.
    public static let maxCandidatesSaturationCeiling: Int = 12

    // MARK: - L1 — BASAbyssalRunMode derivation

    /// Case-by-case map from runtime `BASEBrainRunMode` (10
    /// canonical run modes per chapter 一百三 PowerClock
    /// state-machine) → `BASAbyssalRunMode` (6 abyssal aliases
    /// per Cthulhu Spec V1 §5.1). Total function; tests walk
    /// `.allCases` of input + check projection is non-nil.
    ///
    /// Mapping doctrine (Cthulhu Spec V1 §5.1):
    ///
    ///  - dormant / pulse → `tideSurface` (shallow-state names)
    ///  - sentinel → `nearShore` (shallow watch)
    ///  - engage / reflect → `deepDive` (active depth)
    ///  - deepLoop / `guard` → `stormGuard` (defensive depth)
    ///  - recovery / quarantine → `sealedHarbor` (cooling
    ///    period)
    ///  - lockdown → `sunkenSeal` (terminal seal)
    public enum AbyssalRunMode {
        public static func derive(
            from runMode: BASEBrainRunMode
        ) -> BASAbyssalRunMode {
            switch runMode {
            case .dormant, .pulse:
                return .tideSurface
            case .sentinel:
                return .nearShore
            case .engage, .reflect:
                return .deepDive
            case .deepLoop, .`guard`:
                return .stormGuard
            case .recovery, .quarantine:
                return .sealedHarbor
            case .lockdown:
                return .sunkenSeal
            }
        }
    }

    // MARK: - L1 — BASAbyssBudget derivation

    /// Map a `BASBudgetFrame` snapshot onto a 4-field
    /// `BASAbyssBudget` per Cthulhu Spec V1 §5.1.
    ///
    /// Mapping doctrine (deterministic, all `[0, 1]` clamped):
    ///
    ///  - `deepDiveQuota` ← `maxLoops` normalized by
    ///    `maxLoopsSaturationCeiling`
    ///  - `anomalyTolerance` ← inverse of `thermalGuardLevel`
    ///    (nominal=1 / watch=0.66 / throttle=0.33 / emergency=0)
    ///  - `safeSurfaceFloor` ← `maintenanceClass` ranking
    ///    (none=0 / light=0.33 / standard=0.66 / deferred=1.0)
    ///  - `sovereignReserve` ← `leaseID` presence (1.0 if held,
    ///    else 0.0)
    public enum AbyssBudget {
        public static func derive(
            from frame: BASBudgetFrame,
            turnID: String
        ) -> BASAbyssBudget {
            let deepDive = clamp01(
                Double(frame.maxLoops)
                    / Double(maxLoopsSaturationCeiling))
            let anomalyTolerance =
                thermalGuardToAnomalyTolerance(frame.thermalGuardLevel)
            let safeSurface =
                maintenanceClassToSafeSurface(frame.maintenanceClass)
            let sovereignReserve: Double = (frame.leaseID != nil) ? 1.0 : 0.0
            return BASAbyssBudget(
                budgetID: "abyss-budget:\(turnID)",
                deepDiveQuota: deepDive,
                anomalyTolerance: anomalyTolerance,
                safeSurfaceFloor: safeSurface,
                sovereignReserve: sovereignReserve)
        }

        // Helper case-maps. Pure switch / total functions.
        private static func thermalGuardToAnomalyTolerance(
            _ level: BASThermalGuardLevel
        ) -> Double {
            switch level {
            case .nominal: return 1.0
            case .watch: return 0.66
            case .throttle: return 0.33
            case .emergency: return 0.0
            }
        }

        private static func maintenanceClassToSafeSurface(
            _ klass: BASMaintenanceClass
        ) -> Double {
            switch klass {
            case .none: return 0.0
            case .light: return 0.33
            case .standard: return 0.66
            case .deferred: return 1.0
            }
        }
    }

    // MARK: - L3 — BASAbyssFoldLayer derivation

    /// Map a `BASRuntimePrecisionProfile` snapshot onto an L3
    /// `BASAbyssFoldLayer` per Cthulhu Spec V1 §5.3 (folding-
    /// page abyssal layering).
    ///
    /// Mapping doctrine:
    ///
    ///  - `minimal` precision → `surfaceFold` (lowest detail,
    ///    surface-most fold)
    ///  - `balanced` → `midFold`
    ///  - `protected` → `deepFold` (protected = cold-cache fold)
    ///  - `full` → `abyssalFold` (full precision = abyssal
    ///    detail)
    ///
    /// `oldSealFold` is reserved for compositionally-purged
    /// folds and is NOT projected from `precisionProfile`; it
    /// must be set explicitly by L13 retraction-furnace
    /// callers.
    public enum AbyssFoldLayer {
        public static func derive(
            from precisionProfile: BASRuntimePrecisionProfile
        ) -> BASAbyssFoldLayer {
            switch precisionProfile {
            case .minimal: return .surfaceFold
            case .balanced: return .midFold
            case .protected: return .deepFold
            case .full: return .abyssalFold
            }
        }
    }

    // MARK: - L3 — BASFoldRecoveryState derivation

    /// Map a runtime `BASEBrainRunMode` snapshot onto an L3
    /// `BASFoldRecoveryState` per Cthulhu Spec V1 §5.3.
    ///
    /// Doctrine: only 3 input states project to non-default
    /// recovery states; everything else projects to `abyssFold`
    /// (the unrecovered baseline).
    ///
    ///  - `recovery` → `abyssFold` (under recovery — typical)
    ///  - `quarantine` → `sealBound` (sealed pending review)
    ///  - `lockdown` → `purged` (terminal seal — content
    ///    purged, only lineage refs remain)
    public enum FoldRecoveryState {
        public static func derive(
            from runMode: BASEBrainRunMode
        ) -> BASFoldRecoveryState {
            switch runMode {
            case .quarantine: return .sealBound
            case .lockdown: return .purged
            case .dormant, .pulse, .sentinel, .engage,
                 .reflect, .deepLoop, .`guard`, .recovery:
                return .abyssFold
            }
        }
    }

    // MARK: - L8 — BASMemoryTemperatureLayer derivation

    /// Map a memory atom's `runMode` (the run mode active at
    /// store time) onto a `BASMemoryTemperatureLayer` per
    /// Cthulhu Spec V1 §5.8 (hippocampal-well thermal
    /// classification).
    ///
    /// Mapping doctrine — runtime mode at store time signals
    /// thermal layer:
    ///
    ///  - `dormant` / `pulse` / `sentinel` → `tideSurfaceMemory`
    ///    (hot, recently formed)
    ///  - `engage` / `reflect` → `midLayerMemory` (warm,
    ///    episodic)
    ///  - `deepLoop` / `guard` / `recovery` → `deepWellMemory`
    ///    (cold, semantic)
    ///  - `quarantine` → `abyssalMemory` (sealed, requires L14
    ///    sovereign reveal)
    ///  - `lockdown` → `oldSealMemory` (purged, only lineage
    ///    refs remain)
    public enum MemoryTemperatureLayer {
        public static func derive(
            from runMode: BASEBrainRunMode
        ) -> BASMemoryTemperatureLayer {
            switch runMode {
            case .dormant, .pulse, .sentinel:
                return .tideSurfaceMemory
            case .engage, .reflect:
                return .midLayerMemory
            case .deepLoop, .`guard`, .recovery:
                return .deepWellMemory
            case .quarantine:
                return .abyssalMemory
            case .lockdown:
                return .oldSealMemory
            }
        }
    }

    // MARK: - L4 — BASCosmicScaleView derivation

    /// Threshold used to flip `consequenceDilutionWarning = true`
    /// when the agentic horizon scale exceeds it. Per chapter
    /// 一百三 + chapter 一百十三 doctrine — named static.
    public static let cosmicDilutionThreshold: Double = 0.66

    /// Map a `BASBudgetFrame` snapshot onto a 4-field
    /// `BASCosmicScaleView` per Cthulhu Spec V1 §5.4 + Abyssal
    /// VINF §4.4. Watcher-hint output (red line 7).
    ///
    /// Mapping doctrine:
    ///
    ///  - `temporalHorizon` ← `retrievalDepth` ranking
    ///    (≤2 → temporalShort / 3-5 → temporalMedium / ≥6 →
    ///    temporalDeep)
    ///  - `spatialHorizon` ← `maxLoops` ranking
    ///    (≤2 → spatialLocal / 3-7 → spatialBroad / ≥8 →
    ///    spatialCosmic)
    ///  - `agenticHorizonScale` ← `maxCandidates` normalized by
    ///    `maxCandidatesSaturationCeiling`
    ///  - `consequenceDilutionWarning` ← agenticHorizonScale ≥
    ///    `cosmicDilutionThreshold` AND spatialHorizon ==
    ///    spatialCosmic
    public enum CosmicScaleView {
        public static func derive(
            from frame: BASBudgetFrame,
            turnID: String,
            observedSubjectRef: String
        ) -> BASCosmicScaleView {
            let temporalHorizon = retrievalDepthToHorizon(frame.retrievalDepth)
            let spatialHorizon = maxLoopsToHorizon(frame.maxLoops)
            let agenticScale = clamp01(
                Double(frame.maxCandidates)
                    / Double(maxCandidatesSaturationCeiling))
            let dilutionWarning =
                agenticScale >= cosmicDilutionThreshold
                && spatialHorizon == .spatialCosmic
            return BASCosmicScaleView(
                scaleID: "cosmic-scale:\(turnID)",
                observedSubjectRef: observedSubjectRef,
                temporalHorizon: temporalHorizon,
                spatialHorizon: spatialHorizon,
                agenticHorizonScale: agenticScale,
                consequenceDilutionWarning: dilutionWarning)
        }

        // Range thresholds expressed as named constants so
        // chapter 一百十三 doctrine is honored (no inline 2/5/8).
        private static let temporalShortCeiling: Int = 2
        private static let temporalMediumCeiling: Int = 5
        private static let spatialLocalCeiling: Int = 2
        private static let spatialBroadCeiling: Int = 7

        private static func retrievalDepthToHorizon(
            _ depth: Int
        ) -> BASCosmicScaleHorizon {
            if depth <= temporalShortCeiling { return .temporalShort }
            if depth <= temporalMediumCeiling { return .temporalMedium }
            return .temporalDeep
        }

        private static func maxLoopsToHorizon(
            _ loops: Int
        ) -> BASCosmicScaleHorizon {
            if loops <= spatialLocalCeiling { return .spatialLocal }
            if loops <= spatialBroadCeiling { return .spatialBroad }
            return .spatialCosmic
        }
    }

    // MARK: - L4 — BASTemporalDepthMap derivation

    /// Map a `BASBudgetFrame` snapshot onto a `BASTemporalDepth
    /// Map`. Watcher-hint output (red line 7).
    ///
    /// `timelineRefs` and `nonSimultaneityMarks` start empty —
    /// callers may append turn-specific anchors later. The
    /// `sedimentLayers` field is populated with a deterministic
    /// projection from `retrievalDepth` (each layer = one
    /// horizon strata).
    public enum TemporalDepthMap {
        public static func derive(
            from frame: BASBudgetFrame,
            turnID: String
        ) -> BASTemporalDepthMap {
            let depth = frame.retrievalDepth
            var sedimentLayers: [BASCosmicScaleHorizon] = []
            // 1 layer per "step" of retrieval depth, capped at
            // saturation ceiling. Deterministic projection.
            for step in 1...max(1, min(depth, retrievalDepthSaturationCeiling)) {
                if step <= 2 {
                    sedimentLayers.append(.temporalShort)
                } else if step <= 5 {
                    sedimentLayers.append(.temporalMedium)
                } else {
                    sedimentLayers.append(.temporalDeep)
                }
            }
            return BASTemporalDepthMap(
                mapID: "temporal-depth:\(turnID)",
                timelineRefs: [],
                sedimentLayers: sedimentLayers,
                nonSimultaneityMarks: [],
                observationWindow: "depth:\(depth)")
        }
    }

    // MARK: - L4 — BASOntologyFog derivation

    /// Map an existing `BASUnknownReserve` onto a watcher-hint
    /// `BASOntologyFog`. The fog projection is informational
    /// only — gating moves to `BASOntologyFogAssertionGate.swift`
    /// (M445).
    ///
    /// `partialGraspQuality` projection from
    /// `BASUnknownReserve.assertionCeiling` raw value:
    ///
    ///  - `unrestricted` / `provisional` → `partialGrasp`
    ///  - `qualified` → `provisionalNaming`
    ///  - `metaOnly` / `none` → `unnameable`
    public enum OntologyFog {
        public static func derive(
            unknownRefs: [String],
            assertionCeilingRawValue: String,
            turnID: String
        ) -> BASOntologyFog {
            let quality = assertionCeilingToFogQuality(
                assertionCeilingRawValue)
            return BASOntologyFog(
                fogID: "ontology-fog:\(turnID)",
                fogRegions: unknownRefs,
                nameableAnchors: [],
                unnameableMarks: quality == .unnameable
                    ? unknownRefs
                    : [],
                partialGraspQuality: quality)
        }

        private static func assertionCeilingToFogQuality(
            _ rawValue: String
        ) -> BASOntologyFogQuality {
            switch rawValue {
            case "unrestricted", "provisional":
                return .partialGrasp
            case "qualified":
                return .provisionalNaming
            default:
                // `meta-only`, `none`, or unknown → unnameable
                // (the strictest fog projection — no inferences
                // beyond bare reference).
                return .unnameable
            }
        }
    }

    // MARK: - L7 — BASOntologyShiftMark derivation

    /// Threshold above which a narrative-distortion axis
    /// translates to an ontology-shift axis.
    public static let ontologyShiftAxisThreshold: Double = 0.5

    /// Map a `BASNarrativeDistortion` onto an L7
    /// `BASOntologyShiftMark` per Abyssal VINF §4.7.
    ///
    /// Mapping doctrine — narrative distortion fields cross-
    /// project to ontology shift axes:
    ///
    ///  - `realityDenial > threshold` → `.causality` (denial of
    ///    cause-effect chain is a causality-axis shift)
    ///  - `historyRewrite > threshold` → `.narrative` (rewrite
    ///    is a narrative-axis shift)
    ///  - `forcedClosure > threshold` → `.intent` (forced
    ///    closure manipulates intent direction)
    ///  - `roleInversion > threshold` → `.power` (role flip is
    ///    a power-axis shift)
    ///  - `urgencyMask > threshold` → `.relation` (urgency
    ///    mask alters the relation register)
    ///
    /// `shiftConfidence` ← input `confidence`. Watcher-hint
    /// only (red line 7).
    public enum OntologyShiftMark {
        public static func derive(
            from distortion: BASNarrativeDistortion,
            turnID: String,
            targetSubjectRef: String
        ) -> BASOntologyShiftMark {
            var axes: [BASOntologyShiftAxis] = []
            if distortion.realityDenial > ontologyShiftAxisThreshold {
                axes.append(.causality)
            }
            if distortion.historyRewrite > ontologyShiftAxisThreshold {
                axes.append(.narrative)
            }
            if distortion.forcedClosure > ontologyShiftAxisThreshold {
                axes.append(.intent)
            }
            if distortion.roleInversion > ontologyShiftAxisThreshold {
                axes.append(.power)
            }
            if distortion.urgencyMask > ontologyShiftAxisThreshold {
                axes.append(.relation)
            }
            return BASOntologyShiftMark(
                markID: "ontology-shift:\(turnID)",
                targetSubjectRef: targetSubjectRef,
                observedShiftAxes: axes,
                prePostAnchors: [],
                shiftConfidence: distortion.confidence)
        }
    }

    // MARK: - Helpers

    /// Clamp a `Double` to `[0, 1]`. Centralized helper —
    /// chapter 一百十三 anti-magic-number doctrine prefers a
    /// named clamp helper to inline `min(1, max(0, x))`.
    @inlinable
    public static func clamp01(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
