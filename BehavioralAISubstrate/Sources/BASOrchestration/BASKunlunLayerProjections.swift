// SPDX-License-Identifier: Apache-2.0
// M480-M485 (chapter 一百二十五 / Stream A → production-wire) —
// Kunlun layer projection helpers, mirror of `BASCthulhuLayer
// Projections` (chapter 一百十七 M444 pattern). Ships derive
// helpers for 6 chapter-一百二十二/三/四 schemas so they can
// flow through the L14 sovereign audit emission seam.
//
// 6 derive helpers wired this chapter:
//   - M480 BASAscentLease (L1 朝升暮潜) ← BASBudgetFrame
//   - M481 BASAxisDeviation (L6 离中) ← BASKunlunAxisAlignment
//     + BASRiskCard
//   - M482 BASGatePressure (L6 过门压强) ← BASRiskCard +
//     BASActionPermit
//   - M483 BASYaochiMemoryLayer (L8 瑶池) ← BASEBrainRunMode
//     thermal layer mapping
//   - M484 BASTianhengProfile (L10 天衡庭) ← BASTribunal
//     observation mergedScore + risk drift
//   - M485 BASJadePermitGrade (L11 玉律风闸) ← BASActionPermit
//
// Per chapter 一百十八 ship-with-production-wire doctrine: this
// file is the watcher-hint mirror that closes the schema-only
// trap from chapters 一百二十二/三/四. Each helper is a pure
// function from existing turn state — no actor, no IO, no
// upstream substrate-runtime dependency beyond `BASRuntimeCore`,
// `BASPolicy` (for permit), `BASMemory` (for sanctum policy
// vocabulary).
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
//   no `default` arms; tests walk `.allCases`
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore` + `BASPolicy`. No
// upstream BAS package back-edge.

import Foundation
import BASPolicy
import BASRuntimeCore

// MARK: - BASKunlunLayerProjections

/// Caseless namespace for all Kunlun watcher-hint projection
/// helpers. Mirrors `BASCthulhuLayerProjections` (chapter 一百
/// 十七).
public enum BASKunlunLayerProjections {

    // MARK: Named constants (anti-magic-number doctrine)

    /// Saturation ceiling for `maxLoops` → `gateBudget`
    /// projection on AscentLease. Higher loop count → more
    /// gate-passes. Per chapter 一百十二 bench observation,
    /// `maxLoops = 12` saturates production paths.
    public static let maxLoopsGateBudgetCeiling: Int = 12

    /// Risk-level → deviationScore mapping floor. Above this
    /// risk level the substrate considers the situation
    /// drifting from centerline.
    public static let deviationRiskFloor: Double = 0.4

    /// Pressure urgency threshold above which `gateRequired`
    /// flips to `true` regardless of explicit permit gate.
    public static let pressureUrgencyGateThreshold: Double = 0.7

    /// Equilibrium centerBias value when permit mode is
    /// `.answer` (i.e. no narrowing happened — host has full
    /// agency).
    public static let centerBiasOnAnswerMode: Double = 0.85

    /// Equilibrium dignity floor baseline (raised when risk
    /// is high so dignity preservation kicks in earlier).
    public static let dignityFloorBaseline: Double = 0.5
    public static let dignityFloorHighRisk: Double = 0.75
    public static let dignityFloorExtremeRisk: Double = 0.9

    /// Permit-grade clarity score baseline derived from permit
    /// mode (high for clean modes, low for narrowed).
    public static let clarityScoreCleanMode: Double = 0.85
    public static let clarityScoreNarrowedMode: Double = 0.5

    /// Reversibility score baseline derived from permit's
    /// `delayWindow` presence (delayed = reversible).
    public static let reversibilityScoreDelayed: Double = 0.85
    public static let reversibilityScoreImmediate: Double = 0.5

    // MARK: - M480 BASAscentLease derivation

    /// Project a `BASBudgetFrame` snapshot onto an L1 ascent
    /// lease. Mirrors `BASCthulhuLayerProjections.AbyssBudget
    /// .derive` (chapter 一百十七) but maps the budget to the
    /// Kunlun ascent vocabulary.
    ///
    /// Mapping doctrine:
    ///  - `ascentMode` ← runMode → BASAscentMode (mirror of
    ///    BASCthulhuLayerProjections AbyssalRunMode mapping
    ///    table but Kunlun-flavored)
    ///  - `maxSteps` ← `frame.maxLoops`
    ///  - `gateBudget` ← `frame.maxLoops` capped at
    ///    `maxLoopsGateBudgetCeiling`
    ///  - `returnRequired` ← always true (per §5.1 doctrine
    ///    "每次登临都必须有回峰条件")
    ///  - `sovereignReserve` ← 1 if `frame.leaseID != nil`,
    ///    else 0
    public enum AscentLease {
        public static func derive(
            from frame: BASBudgetFrame,
            turnID: String
        ) -> BASAscentLease {
            BASAscentLease(
                leaseID: "ascent-lease:\(turnID)",
                runLeaseRef: frame.leaseID ?? "no-lease",
                ascentMode: ascentMode(from: frame.runMode),
                maxSteps: frame.maxLoops,
                gateBudget: min(
                    frame.maxLoops,
                    maxLoopsGateBudgetCeiling),
                returnRequired: true,
                sovereignReserve: frame.leaseID != nil ? 1 : 0)
        }

        /// Mirror of `BASCthulhuLayerProjections.AbyssalRunMode
        /// .derive` — same case-by-case map, Kunlun side.
        private static func ascentMode(
            from runMode: BASEBrainRunMode
        ) -> BASAscentMode {
            switch runMode {
            case .dormant, .pulse:
                return .morningAscent
            case .sentinel, .engage:
                return .ascending
            case .reflect:
                return .returning
            case .deepLoop, .`guard`, .recovery:
                return .eveningRest
            case .quarantine, .lockdown:
                return .sealed
            }
        }
    }

    // MARK: - M481 BASAxisDeviation derivation

    /// Project a `BASBrainRiskLevel` snapshot onto an L6 axis-
    /// deviation watcher hint.
    ///
    /// Mapping doctrine:
    ///  - `deviationScore` ← risk level numeric
    ///    (.low=0.2 / .medium=0.5 / .high=0.7 / .extreme=0.9)
    ///  - `reasonCodes` ← derived risk-level label
    ///  - `correctionHint` ← optional centerline direction
    public enum AxisDeviation {
        public static func derive(
            from riskLevel: BASBrainRiskLevel,
            turnID: String,
            situationRef: String,
            centerlineRef: String
        ) -> BASAxisDeviation {
            let score = deviationScore(from: riskLevel)
            let reasons = reasonCodes(from: riskLevel)
            let hint = correctionHint(from: riskLevel)
            return BASAxisDeviation(
                deviationID: "axis-deviation:\(turnID)",
                situationRef: situationRef,
                centerlineRef: centerlineRef,
                deviationScore: score,
                reasonCodes: reasons,
                correctionHint: hint)
        }

        private static func deviationScore(
            from riskLevel: BASBrainRiskLevel
        ) -> Double {
            switch riskLevel {
            case .low: return 0.2
            case .medium: return 0.5
            case .high: return 0.7
            case .extreme: return 0.9
            }
        }

        private static func reasonCodes(
            from riskLevel: BASBrainRiskLevel
        ) -> [String] {
            switch riskLevel {
            case .low: return []
            case .medium: return ["risk-medium-drift"]
            case .high: return ["risk-high-drift"]
            case .extreme: return ["risk-extreme-axis-overreach"]
            }
        }

        private static func correctionHint(
            from riskLevel: BASBrainRiskLevel
        ) -> String? {
            switch riskLevel {
            case .low: return nil
            case .medium: return "return-to-centerline"
            case .high: return "narrow-and-recheck"
            case .extreme: return "halt-and-defer"
            }
        }
    }

    // MARK: - M482 BASGatePressure derivation

    /// Project a `BASBrainRiskLevel` + `BASActionPermit` onto
    /// an L6 gate-pressure watcher hint.
    public enum GatePressure {
        public static func derive(
            from riskLevel: BASBrainRiskLevel,
            permit: BASActionPermit,
            turnID: String,
            situationRef: String
        ) -> BASGatePressure {
            let urgency = urgencyFromRisk(riskLevel)
            let reversible = permit.delayWindow != nil
                || permit.mode == .delay
            let gateRequired = urgency
                >= pressureUrgencyGateThreshold
                || permit.requireSecondCheck
            return BASGatePressure(
                pressureID: "gate-pressure:\(turnID)",
                situationRef: situationRef,
                approachingDomains: domainsFromPermit(permit),
                urgency: urgency,
                reversible: reversible,
                gateRequired: gateRequired)
        }

        private static func urgencyFromRisk(
            _ riskLevel: BASBrainRiskLevel
        ) -> Double {
            switch riskLevel {
            case .low: return 0.1
            case .medium: return 0.4
            case .high: return 0.75
            case .extreme: return 0.95
            }
        }

        private static func domainsFromPermit(
            _ permit: BASActionPermit
        ) -> [String] {
            // Use permit's allowedDomains as the "approaching"
            // signal — the domains the host is asking the
            // substrate to act on.
            permit.allowedDomains
        }
    }

    // MARK: - M483 BASYaochiMemoryLayer derivation

    /// Project a `BASEBrainRunMode` snapshot onto an L8
    /// Yaochi memory layer (Kunlun-side parallel to chapter
    /// 一百十五 BASMemoryTemperatureLayer enum).
    ///
    /// Mapping doctrine: high-sensitivity layers (yaochi /
    /// old-seal) require both anchor + sovereign gate.
    public enum YaochiMemoryLayer {
        public static func derive(
            from runMode: BASEBrainRunMode,
            turnID: String
        ) -> BASYaochiMemoryLayer {
            let policy = sanctumPolicy(from: runMode)
            let anchor = !policy.isEmpty
            let sovereignGate = (runMode == .quarantine
                || runMode == .lockdown)
            return BASYaochiMemoryLayer(
                layerID: "yaochi-layer:\(turnID)",
                memoryRefs: [],
                sanctumPolicy: policy,
                revealConditions: revealConditions(from: runMode),
                humanAnchorRequired: anchor,
                sovereignGateRequired: sovereignGate)
        }

        private static func sanctumPolicy(
            from runMode: BASEBrainRunMode
        ) -> String {
            switch runMode {
            case .dormant, .pulse, .sentinel, .engage,
                 .reflect, .deepLoop:
                return ""  // open layer; no sanctum
            case .`guard`, .recovery:
                return "deep-well"
            case .quarantine:
                return "yaochi-strict"
            case .lockdown:
                return "old-seal"
            }
        }

        private static func revealConditions(
            from runMode: BASEBrainRunMode
        ) -> [String] {
            switch runMode {
            case .dormant, .pulse, .sentinel, .engage,
                 .reflect, .deepLoop:
                return []
            case .`guard`, .recovery:
                return ["host-anchor"]
            case .quarantine:
                return ["host-anchor", "sovereign-warrant"]
            case .lockdown:
                return ["sovereign-warrant",
                        "post-cooling-period"]
            }
        }
    }

    // MARK: - M484 BASTianhengProfile derivation

    /// Project a `BASBrainRiskLevel` + permit mode onto an
    /// L10 Tianheng equilibrium profile.
    ///
    /// Higher risk → narrower permit → lower centerBias →
    /// higher dignity/agency floors (host-protection raises
    /// when system narrows agency).
    public enum TianhengProfile {
        public static func derive(
            from riskLevel: BASBrainRiskLevel,
            permitMode: BASActionPermitMode,
            turnID: String
        ) -> BASTianhengProfile {
            let centerBias = centerBiasFor(permitMode)
            let dignityFloor = dignityFloorFor(riskLevel)
            let agencyFloor = agencyFloorFor(permitMode)
            let imbalances = imbalanceCodesFor(
                riskLevel: riskLevel,
                permitMode: permitMode)
            return BASTianhengProfile(
                profileID: "tianheng-profile:\(turnID)",
                idClaims: [],
                egoConstraints: [],
                superegoClaims: [],
                centerBias: centerBias,
                dignityFloor: dignityFloor,
                agencyFloor: agencyFloor,
                imbalanceCodes: imbalances)
        }

        private static func centerBiasFor(
            _ mode: BASActionPermitMode
        ) -> Double {
            mode == .answer
                ? centerBiasOnAnswerMode
                : 0.5
        }

        private static func dignityFloorFor(
            _ riskLevel: BASBrainRiskLevel
        ) -> Double {
            switch riskLevel {
            case .low, .medium: return dignityFloorBaseline
            case .high: return dignityFloorHighRisk
            case .extreme: return dignityFloorExtremeRisk
            }
        }

        private static func agencyFloorFor(
            _ mode: BASActionPermitMode
        ) -> Double {
            switch mode {
            case .answer: return 0.85
            case .mirror, .compare: return 0.65
            case .delay, .draftOnly, .localOnly: return 0.5
            case .escalate, .replace, .block: return 0.3
            }
        }

        private static func imbalanceCodesFor(
            riskLevel: BASBrainRiskLevel,
            permitMode: BASActionPermitMode
        ) -> [String] {
            var codes: [String] = []
            if riskLevel == .extreme {
                codes.append("extreme-risk-pressure")
            }
            if permitMode == .block || permitMode == .replace {
                codes.append("agency-narrowed")
            }
            return codes
        }
    }

    // MARK: - M485 BASJadePermitGrade derivation

    /// Project a `BASActionPermit` onto an L11 jade-canon
    /// permit grade. clarity / reversibility / provenance
    /// scores derived from permit shape.
    public enum JadePermitGrade {
        public static func derive(
            from permit: BASActionPermit,
            turnID: String
        ) -> BASJadePermitGrade {
            let clarity = clarityScore(from: permit.mode)
            let reversibility = reversibilityScore(from: permit)
            let provenance = provenanceScore(from: permit)
            let gates = gateRequirements(
                forClarity: clarity,
                reversibility: reversibility,
                provenance: provenance)
            let revPath = permit.escalationHintRef ?? ""
            return BASJadePermitGrade(
                gradeID: "jade-permit-grade:\(turnID)",
                actionPermitRef: "permit:\(permit.mode.rawValue)",
                clarityScore: clarity,
                reversibilityScore: reversibility,
                provenanceScore: provenance,
                gateRequirements: gates,
                revocationPath: revPath)
        }

        private static func clarityScore(
            from mode: BASActionPermitMode
        ) -> Double {
            switch mode {
            case .answer, .mirror:
                return clarityScoreCleanMode
            case .compare, .draftOnly, .localOnly, .delay:
                return clarityScoreCleanMode
            case .escalate, .replace, .block:
                return clarityScoreNarrowedMode
            }
        }

        private static func reversibilityScore(
            from permit: BASActionPermit
        ) -> Double {
            permit.delayWindow != nil
                ? reversibilityScoreDelayed
                : reversibilityScoreImmediate
        }

        private static func provenanceScore(
            from permit: BASActionPermit
        ) -> Double {
            // Reason codes count → provenance signal.
            // Higher count = more documented basis.
            let count = Double(permit.reasonCodes.count)
            return min(1.0, count / 5.0 + 0.3)
        }

        private static func gateRequirements(
            forClarity clarity: Double,
            reversibility: Double,
            provenance: Double
        ) -> [String] {
            // Mirror BASJadePermitGrade.gateMandatoryScoreThreshold
            // (0.5) — when any score is below, gateRequirements
            // must be non-empty.
            let threshold = BASJadePermitGrade
                .gateMandatoryScoreThreshold
            let belowThreshold = clarity < threshold
                || reversibility < threshold
                || provenance < threshold
            return belowThreshold ? ["jade-canon-review"] : []
        }
    }
}

// MARK: - BASBrainRiskLevel reference

// `BASBrainRiskLevel` lives in BASPolicy (`EBrainRiskPlaneCore.swift`).
// Imported above via `import BASPolicy`.
