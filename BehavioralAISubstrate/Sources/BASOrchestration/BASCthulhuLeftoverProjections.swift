// SPDX-License-Identifier: Apache-2.0
// M495-M498 (chapter 一百二十七) — chapter 一百二十一 Cthulhu
// leftover production wires. Closes the schema-only trap for the
// 4 Cthulhu schemas added in chapter 一百二十一 strict-audit
// (BASAbyssalOrganAlias / BASHumanAnchorProfile /
// BASNarrativeDistortionMap / BASSealedMemory) that landed as
// schema-only ships per chapter 一百十八 ship-with-production-
// wire doctrine.
//
// Each derive helper is pure value-typed — no actor, no IO, no
// upstream substrate-runtime back-edge. Same doctrine as
// BASKunlunLayerProjections (chapter 一百十七 / 一百二十五 /
// 一百二十六).
//
// 4 derive helpers:
//   - M495 BASNarrativeDistortionMap (L7) ← per-candidate
//     distortion aggregate
//   - M496 BASSealedMemory (L8) ← BASMemoryTemperatureLayer
//     bridge (one per turn when a sealable thermal class fires)
//   - M497 BASHumanAnchorProfile (L5) ← host-level anchor
//     configuration synthesized per turn
//   - M498 BASAbyssalOrganAlias (L2) ← run-mode → organ-alias
//     mapping (single dominant alias per turn)
//
// ## Doctrine pins
//
// - **Pure functions only** — every projection is `static`
//   with deterministic single input → single output mapping
// - **Watcher-only output** (red line 7) — derives never
//   touch permit.mode / verdict.level / lifecycle action
// - **Anti-magic-number** (chapter 一百十三) — every numeric
//   threshold via named static constant
// - **Anti-drift** (chapter 一百十四) — exhaustive switches;
//   no `default` arms
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore` + `BASPolicy` (for
// `BASBrainRiskLevel`) + `BASMemory` (for `BASSealedMemory` +
// helper enums).

import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

// MARK: - BASCthulhuLeftoverProjections

/// Caseless namespace for chapter 一百二十一 Cthulhu leftover
/// production-wire derives. Mirror of `BASCthulhuLayer
/// Projections` (chapter 一百十七) + `BASKunlunLayerProjections`
/// (chapter 一百二十五).
public enum BASCthulhuLeftoverProjections {

    // MARK: Named constants (anti-magic-number doctrine)

    /// Per-axis distortion threshold above which an L7 narrative-
    /// distortion subject is considered material (matches
    /// `BASCthulhuLayerProjections.ontologyShiftAxisThreshold`).
    public static let distortionMapAxisThreshold: Double = 0.5

    /// Risk-level scalar floor at which the substrate stops
    /// auto-revealing sealed memory atoms (per §5.8 reveal-mode
    /// transition table).
    public static let sealRevealRiskFloor: Double = 0.5

    // MARK: - M495 BASNarrativeDistortionMap derivation (L7)

    /// Project a per-candidate distortion map from a single
    /// distortion observation broadcast across the turn's
    /// candidate set. When `candidates` is empty OR all distortion
    /// axes are below threshold, returns `nil` so the audit-entry
    /// consumer elides the codes.
    ///
    /// Per chapter 一百二十一 §5.7 doctrine: the map is an
    /// aggregate readout, not the source-of-truth — single-
    /// subject distortion stays in `BASNarrativeDistortion`.
    public enum NarrativeDistortionMap {
        public static func derive(
            from distortion: BASNarrativeDistortion,
            candidateIDs: [String],
            turnID: String
        ) -> BASNarrativeDistortionMap? {
            guard !candidateIDs.isEmpty else { return nil }
            let materialAxis = max(
                distortion.realityDenial,
                max(distortion.historyRewrite,
                    max(distortion.forcedClosure,
                        max(distortion.roleInversion,
                            distortion.urgencyMask))))
            guard materialAxis >= distortionMapAxisThreshold
            else { return nil }
            // Mirror the same distortion to every candidate ref;
            // upstream may later differentiate per candidate.
            var perSubject:
                [String: BASNarrativeDistortion] = [:]
            for candidateID in candidateIDs {
                perSubject[candidateID] = distortion
            }
            // Dominant subject = first candidate (deterministic
            // ordering; upstream may compute per-subject scores).
            let dominant = candidateIDs.first
            return BASNarrativeDistortionMap(
                mapID: "distortion-map:\(turnID)",
                subjectRefs: candidateIDs,
                distortionsBySubject: perSubject,
                dominantSubjectRef: dominant)
        }
    }

    // MARK: - M496 BASSealedMemory derivation (L8)

    /// Project an L8 sealed-memory binding per turn from the L8
    /// thermal layer. Returns `nil` for `.tideSurfaceMemory`
    /// (unsealed surface — no envelope needed) so the audit-
    /// entry consumer elides the codes.
    ///
    /// Mapping doctrine per Cthulhu Spec V1 §5.8:
    ///   - tide surface → nil (no seal)
    ///   - mid layer → seal class `.midLayer` + disclosure
    ///     `.hostExplicitOnly`
    ///   - deep well → `.deepWell` + `.hostExplicitOnly`
    ///   - abyssal → `.abyssal` + `.sovereignWarrant`
    ///   - old seal → `.oldSeal` + `.never`
    public enum SealedMemory {
        public static func derive(
            from layer: BASMemoryTemperatureLayer,
            turnID: String
        ) -> BASSealedMemory? {
            guard let sealClass = sealClass(for: layer) else {
                return nil
            }
            let disclosure = disclosureMode(for: layer)
            let reentry = reentryConditions(for: layer)
            return BASSealedMemory(
                sealedMemoryID: "sealed-memory:\(turnID)",
                memoryRef: "memory:\(turnID)",
                sealClass: sealClass,
                disclosureMode: disclosure,
                reentryConditions: reentry)
        }

        private static func sealClass(
            for layer: BASMemoryTemperatureLayer
        ) -> BASSealClass? {
            switch layer {
            case .tideSurfaceMemory: return nil
            case .midLayerMemory: return .midLayer
            case .deepWellMemory: return .deepWell
            case .abyssalMemory: return .abyssal
            case .oldSealMemory: return .oldSeal
            }
        }

        private static func disclosureMode(
            for layer: BASMemoryTemperatureLayer
        ) -> BASSealDisclosureMode {
            switch layer {
            case .tideSurfaceMemory, .midLayerMemory,
                 .deepWellMemory:
                return .hostExplicitOnly
            case .abyssalMemory:
                return .sovereignWarrant
            case .oldSealMemory:
                return .never
            }
        }

        private static func reentryConditions(
            for layer: BASMemoryTemperatureLayer
        ) -> [String] {
            switch layer {
            case .tideSurfaceMemory:
                return []
            case .midLayerMemory, .deepWellMemory:
                return ["host-typed-recall"]
            case .abyssalMemory:
                return ["sovereign-warrant",
                        "host-typed-recall"]
            case .oldSealMemory:
                return []  // .never disclosure → no reentry
            }
        }
    }

    // MARK: - M497 BASHumanAnchorProfile derivation (L5)

    /// Project an L5 host-level anchor profile per turn from the
    /// host context + risk level. Empty arrays are populated by
    /// downstream host-config sources; this derive helper
    /// synthesizes the profile shell so the audit walker can
    /// query "which host invariants were honored on this turn?"
    /// without requiring a full host-config source on every turn.
    ///
    /// `dignityInvariants` populated by default with `"no-shame"`
    /// + `"no-condescension"` (universal invariants every host
    /// implicitly holds).
    public enum HumanAnchorProfile {
        public static func derive(
            hostID: String,
            riskLevel: BASBrainRiskLevel,
            turnID: String
        ) -> BASHumanAnchorProfile {
            let sensitivityWindows =
                sensitivityWindowsFor(riskLevel: riskLevel)
            return BASHumanAnchorProfile(
                profileID: "human-anchor-profile:\(turnID)",
                hostRef: hostID,
                dignityInvariants: defaultDignityInvariants,
                noExploitationGuards:
                    defaultExploitationGuards,
                sensitivityWindows: sensitivityWindows,
                anchoringRituals: [])
        }

        private static let defaultDignityInvariants: [String] = [
            "no-shame",
            "no-condescension",
            "no-urgency-coercion",
        ]

        private static let defaultExploitationGuards: [String] = [
            "no-vulnerability-mining",
            "no-emotional-leverage",
        ]

        private static func sensitivityWindowsFor(
            riskLevel: BASBrainRiskLevel
        ) -> [String] {
            switch riskLevel {
            case .low, .medium:
                return []
            case .high:
                return ["elevated-attention-window"]
            case .extreme:
                return ["elevated-attention-window",
                        "post-incident-window"]
            }
        }
    }

    // MARK: - M498 BASAbyssalOrganAlias derivation (L2)

    /// Project an L2 abyssal organ alias per turn from the bound
    /// run mode. Mirrors `BASCthulhuLayerProjections.AbyssalRun
    /// Mode` mapping table — every run mode resolves to a
    /// dominant organ alias for audit-walker grep.
    ///
    /// Per Cthulhu Spec V1 §5.2 doctrine: aliases are INTERNAL
    /// audit-walker vocabulary, never appear on public surface.
    public enum AbyssalOrganAlias {
        public static func derive(
            from runMode: BASEBrainRunMode
        ) -> BASAbyssalOrganAlias {
            switch runMode {
            case .dormant, .pulse, .sentinel:
                return .mainCoreCortex
            case .engage:
                return .counterfactualForge
            case .reflect, .deepLoop:
                return .critiqueBladeCore
            case .`guard`, .recovery:
                return .riskRidge
            case .quarantine:
                return .oldSealCore
            case .lockdown:
                return .minimalResonanceCore
            }
        }
    }

    // MARK: - M499 hostFragility actual computation

    /// M499 — derive the `hostFragility` scalar for
    /// `BASAbyssalPressure` from a `BASHumanAnchorSignal`. Pre-
    /// M499 the field was hard-coded to 0 (chapter 一百二十一
    /// schema-only ship); chapter 一百二十七 closes the
    /// computation gap by reading the anchor's three host-side
    /// risks.
    ///
    /// Per Cthulhu Spec V1 §5.11: `hostFragility` reflects the
    /// host's current vulnerability — high alienation / dignity /
    /// overwhelm risks all raise fragility independently. The
    /// scalar is the maximum of the three (taking the worst
    /// stressor as the host's fragility floor).
    ///
    /// Returns 0 when no anchor signal is available (backward-
    /// compat with v1.0.0 baselines).
    public enum HostFragilityProjection {
        public static func derive(
            from anchor: BASHumanAnchorSignal?
        ) -> Double {
            guard let anchor = anchor else { return 0 }
            return max(
                anchor.alienationRisk,
                max(anchor.dignityRisk,
                    anchor.overwhelmRisk))
        }

        /// M499 — re-build a `BASAbyssalPressure` with computed
        /// `hostFragility` folded in. Pure value-typed transform;
        /// preserves all other fields including `recommendedModes`
        /// and `sovereignEscalationHint`.
        public static func apply(
            fragility: Double,
            to pressure: BASAbyssalPressure
        ) -> BASAbyssalPressure {
            BASAbyssalPressure(
                pressureID: pressure.pressureID,
                unknownLoad: pressure.unknownLoad,
                consequenceRadius: pressure.consequenceRadius,
                evidenceDebt: pressure.evidenceDebt,
                ontologyDistortion: pressure.ontologyDistortion,
                manipulationIndex: pressure.manipulationIndex,
                narrativePollution: pressure.narrativePollution,
                recommendedModes: pressure.recommendedModes,
                sovereignEscalationHint:
                    pressure.sovereignEscalationHint,
                hostFragility: fragility)
        }
    }
}
