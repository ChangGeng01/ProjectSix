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
import BASWorldPrior

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

// MARK: - M486-M490 (chapter 一百二十六) — L9 dream-loop +
// L3 fold-page + L13 refinement production wires.
//
// Each derive helper is pure, returns a value-typed Kunlun
// schema from existing turn state. Same doctrine as M480-M485.

public extension BASKunlunLayerProjections {

    // MARK: - M486 BASAscentBranch derivation (L9)

    /// Project a `BASCandidatePath` onto an L9 ascent branch.
    /// Per §5.9 doctrine: every ascent has a paired return
    /// path (dignity invariant). The derive helper synthesizes
    /// a default returnPathRef tied to the candidate ID so the
    /// invariant is honored by construction.
    enum AscentBranch {
        public static func derive(
            from candidate: BASCandidatePath,
            turnID: String
        ) -> BASAscentBranch {
            BASAscentBranch(
                branchID: "ascent-branch:\(candidate.candidateID)",
                candidateRef: candidate.candidateID,
                ascentConditions: ascentConditions(
                    confidence: candidate.confidence),
                gateSequence: gateSequenceFromBenefit(
                    candidate.expectedBenefit),
                evidenceRequirements: candidate.requiredEvidence,
                returnPathRef:
                    "return-path:\(candidate.candidateID)",
                stopPoints: stopPointsFromReversibility(
                    candidate.reversibility))
        }

        private static func ascentConditions(
            confidence: Double
        ) -> [String] {
            var conditions: [String] = []
            if confidence >= ascentConfidenceCleanThreshold {
                conditions.append("axis-aligned")
            }
            if confidence
                >= ascentConfidenceWithEvidenceThreshold
            {
                conditions.append("evidence-sufficient")
            }
            return conditions
        }

        private static func gateSequenceFromBenefit(
            _ benefit: Double
        ) -> [String] {
            var gates: [String] = []
            if benefit >= ascentBenefitGateThreshold {
                gates.append("heaven-gate-1")
            }
            return gates
        }

        private static func stopPointsFromReversibility(
            _ reversibility: Double
        ) -> [String] {
            reversibility < ascentReversibilityStopThreshold
                ? ["pre-commit", "pre-execute"]
                : []
        }
    }

    /// Confidence threshold above which "axis-aligned" is
    /// added to the ascent conditions.
    static let ascentConfidenceCleanThreshold: Double = 0.7
    /// Confidence threshold above which "evidence-sufficient"
    /// is added.
    static let ascentConfidenceWithEvidenceThreshold: Double = 0.8
    /// Expected-benefit threshold above which a gate-pass is
    /// pre-required for the ascent.
    static let ascentBenefitGateThreshold: Double = 0.6
    /// Reversibility threshold below which extra stop-points
    /// are inserted.
    static let ascentReversibilityStopThreshold: Double = 0.4

    // MARK: - M487 BASRestStep derivation (L9)

    /// Project a stalled candidate onto an L9 rest step. Used
    /// when the candidate's confidence is below the
    /// pause-and-resume threshold but evidence may yet arrive.
    enum RestStep {
        public static func derive(
            from candidate: BASCandidatePath,
            turnID: String
        ) -> BASRestStep? {
            // Only derive a rest-step when the candidate is
            // genuinely "needs more evidence" — confidence
            // below threshold but has at least one required
            // evidence ref.
            guard candidate.confidence
                < restStepConfidenceCeiling
                && !candidate.requiredEvidence.isEmpty
            else {
                return nil
            }
            return BASRestStep(
                restID: "rest-step:\(candidate.candidateID)",
                candidateRef: candidate.candidateID,
                reasonCodes: ["awaiting-evidence"],
                allowedIntermediateActions: [
                    "observe", "summarize",
                ],
                resumeConditions: candidate.requiredEvidence)
        }
    }

    /// Confidence ceiling below which a rest-step is derived.
    static let restStepConfidenceCeiling: Double = 0.6

    // MARK: - M488 BASReturnPath derivation (L9)

    /// Project an L9 return path for any candidate. Always
    /// non-nil per §5.9 dignity invariant — every ascent has
    /// a way back.
    enum ReturnPath {
        public static func derive(
            from candidate: BASCandidatePath,
            turnID: String
        ) -> BASReturnPath {
            BASReturnPath(
                returnID:
                    "return-path:\(candidate.candidateID)",
                candidateRef: candidate.candidateID,
                dignityPreserved: true,
                rollbackPossible: candidate.reversibility
                    >= returnPathRollbackThreshold,
                nextSafeStep: nextSafeStep(
                    confidence: candidate.confidence))
        }

        private static func nextSafeStep(
            confidence: Double
        ) -> String {
            if confidence < returnPathLowConfidenceThreshold {
                return "summarize-and-pause"
            }
            return "review-with-host"
        }
    }

    /// Reversibility threshold for `rollbackPossible=true`.
    static let returnPathRollbackThreshold: Double = 0.5
    /// Confidence threshold below which the safe step is
    /// "summarize-and-pause" (vs "review-with-host").
    static let returnPathLowConfidenceThreshold: Double = 0.4

    // MARK: - M489 BASJadeCasketSnapshot derivation (L3)

    /// Project an L3 jade-casket snapshot binding for the
    /// current turn. Always synthesizes a casket — every turn
    /// produces a foldable state worth sealing.
    enum JadeCasketSnapshot {
        public static func derive(
            turnID: String,
            sessionID: String
        ) -> BASJadeCasketSnapshot {
            BASJadeCasketSnapshot(
                snapshotID:
                    "jade-casket:\(sessionID):\(turnID)",
                foldRefs: ["fold:\(turnID)"],
                integrityHash:
                    "sha256:turn-\(turnID)-\(sessionID)",
                sourceRiverRef:
                    "river-origin:\(sessionID)",
                restoreGateRef:
                    "heaven-gate:\(sessionID):restore",
                rollbackWritRef:
                    "rollback-writ:\(sessionID):\(turnID)")
        }
    }

    // MARK: - M490 BASJadeRefinementTicket derivation (L13)

    /// Project an L13 jade-refinement ticket for a candidate
    /// that needs impurity removal before promotion. Returns
    /// nil when candidate is clean (no impurities).
    enum JadeRefinementTicket {
        public static func derive(
            from candidate: BASCandidatePath,
            turnID: String
        ) -> BASJadeRefinementTicket? {
            let impurities = impurityCodes(
                confidence: candidate.confidence,
                expectedCost: candidate.expectedCost)
            guard !impurities.isEmpty else { return nil }
            return BASJadeRefinementTicket(
                ticketID:
                    "jade-refinement:\(candidate.candidateID)",
                candidateRef: candidate.candidateID,
                impurityCodes: impurities,
                refinementSteps:
                    refinementStepsFor(impurities: impurities),
                shadowTrialRef:
                    "shadow-trial:\(candidate.candidateID)",
                fracturePath:
                    "fracture:\(candidate.candidateID)",
                promotionGateRef:
                    "heaven-gate:promotion")
        }

        private static func impurityCodes(
            confidence: Double,
            expectedCost: Double
        ) -> [String] {
            var codes: [String] = []
            if confidence < refinementLowConfidenceThreshold {
                codes.append("low-confidence")
            }
            if expectedCost > refinementHighCostThreshold {
                codes.append("high-cost-needs-review")
            }
            return codes
        }

        private static func refinementStepsFor(
            impurities: [String]
        ) -> [String] {
            // Default steps for any impurity — host can extend.
            ["scrub-impurity", "shadow-trial", "host-review"]
        }
    }

    /// Confidence threshold below which "low-confidence"
    /// impurity is added.
    static let refinementLowConfidenceThreshold: Double = 0.5
    /// Cost threshold above which "high-cost-needs-review"
    /// impurity is added.
    static let refinementHighCostThreshold: Double = 0.7
}

// MARK: - M491-M494 (chapter 一百二十七) — final Kunlun
// host + integrity production wires. Closes the schema-only
// trap for chapter 一百二十四 schemas (BASJadeFidelityMap /
// BASHostJadeRegister / BASJadeMirrorDraft /
// BASKunlunUnnamableSet) per chapter 一百十八 ship-with-
// production-wire doctrine.

public extension BASKunlunLayerProjections {

    // MARK: - M491 BASJadeFidelityMap derivation (L2)

    /// Project an L2 jade-fidelity map per turn from the bound
    /// run mode + risk level. Mirrors §3.2 contamination doctrine:
    /// `.contaminated` MUST have `auditRequired == true` (init-
    /// enforced via `honorsContaminationInvariant`).
    ///
    /// Mapping doctrine:
    ///   - run mode `.quarantine` / `.lockdown` → `.contaminated`
    ///     with auditRequired=true (per §3.2 invariant)
    ///   - run mode `.recovery` / `.guard` → `.partial`
    ///   - risk `.extreme` → `.partial`
    ///   - risk `.high` + non-quarantine → `.standard`
    ///   - everything else → `.high` (clean fidelity)
    ///
    /// `contaminationTolerance` derived from inverse risk: low
    /// risk = high tolerance (organ can absorb noise); high risk
    /// = low tolerance (organ must halt-on-contamination).
    enum JadeFidelityMap {
        public static func derive(
            from runMode: BASEBrainRunMode,
            riskLevel: BASBrainRiskLevel,
            organRef: String,
            turnID: String
        ) -> BASJadeFidelityMap {
            let level = fidelityLevel(
                runMode: runMode, riskLevel: riskLevel)
            let policy = degradationPolicy(for: level)
            let tolerance = contaminationTolerance(
                for: riskLevel)
            let auditRequired = (level == .contaminated)
            return BASJadeFidelityMap(
                mapID: "jade-fidelity:\(turnID)",
                organRef: organRef,
                fidelityLevel: level,
                degradationPolicy: policy,
                contaminationTolerance: tolerance,
                auditRequired: auditRequired)
        }

        private static func fidelityLevel(
            runMode: BASEBrainRunMode,
            riskLevel: BASBrainRiskLevel
        ) -> BASJadeFidelityLevel {
            switch runMode {
            case .quarantine, .lockdown:
                return .contaminated
            case .`guard`, .recovery:
                return .partial
            case .dormant, .pulse, .sentinel,
                 .engage, .reflect, .deepLoop:
                switch riskLevel {
                case .extreme: return .partial
                case .high: return .standard
                case .medium, .low: return .high
                }
            }
        }

        private static func degradationPolicy(
            for level: BASJadeFidelityLevel
        ) -> String {
            switch level {
            case .high: return "degrade-gracefully"
            case .standard: return "degrade-gracefully"
            case .partial: return "degrade-with-audit"
            case .contaminated: return "halt-on-contamination"
            }
        }

        private static func contaminationTolerance(
            for riskLevel: BASBrainRiskLevel
        ) -> Double {
            switch riskLevel {
            case .low: return jadeFidelityToleranceLow
            case .medium: return jadeFidelityToleranceMedium
            case .high: return jadeFidelityToleranceHigh
            case .extreme: return jadeFidelityToleranceExtreme
            }
        }
    }

    /// Contamination tolerance baselines (anti-magic-number).
    /// Higher = organ can absorb more noise before halt.
    static let jadeFidelityToleranceLow: Double = 0.7
    static let jadeFidelityToleranceMedium: Double = 0.5
    static let jadeFidelityToleranceHigh: Double = 0.3
    static let jadeFidelityToleranceExtreme: Double = 0.1

    // MARK: - M492 BASHostJadeRegister derivation (L5)

    /// Project an L5 host-jade register per turn from the bound
    /// host context. Doctrine invariant per §5.5: `riverOriginRef`
    /// MUST be non-empty (every host change has provenance).
    /// The derive helper uses sessionID as the river-origin
    /// anchor so the invariant always holds by construction.
    enum HostJadeRegister {
        public static func derive(
            hostID: String,
            sessionID: String,
            turnID: String
        ) -> BASHostJadeRegister {
            BASHostJadeRegister(
                registerID: "host-jade-register:\(turnID)",
                hostVersionRef: "host-version:\(hostID)",
                boundaryContractRefs: [],
                authorizationScrollRefs: [],
                relationRegisterRefs: [],
                rollbackRefs: [],
                riverOriginRef:
                    "river-origin:\(sessionID)")
        }
    }

    // MARK: - M493 BASJadeMirrorDraft derivation (L7)

    /// Project an L7 jade-mirror draft per turn. Doctrine
    /// invariant per §5.7: `noInducementFlag` MUST be `true`
    /// (drafts that induce confidence violate jade mirror).
    /// The derive helper sets the flag to `true` by construction.
    ///
    /// `unknownPreserved` populated from the unknown-reserve
    /// refs (chapter 一百十八 wire) so unknowns aren't auto-
    /// filled.
    enum JadeMirrorDraft {
        public static func derive(
            unknownRefs: [String],
            anchorRef: String,
            turnID: String
        ) -> BASJadeMirrorDraft {
            BASJadeMirrorDraft(
                draftID: "jade-mirror-draft:\(turnID)",
                sourceFrameRef: "fold:\(turnID)",
                cleanReflection: "",
                unknownPreserved: unknownRefs,
                inferenceDisclosures: [],
                hostAnchorRef: anchorRef,
                noInducementFlag: true)
        }
    }

    // MARK: - M494 BASKunlunUnnamableSet derivation (L7)

    /// Project an L7 Kunlun unnamable set when the unknown
    /// reserve has at least one preserved unknown. Returns nil
    /// for empty reserves (per §5.7 doctrine: vacuous sets
    /// violate "未知必须留" — preservation requires non-empty).
    enum KunlunUnnamableSet {
        public static func derive(
            unknownRefs: [String],
            preservationPolicy: String,
            turnID: String
        ) -> BASKunlunUnnamableSet? {
            guard !unknownRefs.isEmpty else { return nil }
            return BASKunlunUnnamableSet(
                setID: "unnamable-set:\(turnID)",
                unknownRefs: unknownRefs,
                preservationPolicy: preservationPolicy,
                partialStructures: [],
                safeLabels: [])
        }
    }

    // MARK: - M500-M501 (chapter 一百二十八) — Kunlun L4
    // chapter-99-deferred wires. AscentView + FarWestReserve
    // schemas have lived as schema-only since chapter 九十九
    // ("need synthetic ascent context or unknown-distance
    // projection that the substrate doesn't yet expose"). The
    // chapter 一百二十一+ BASUnknownReserve derive + chapter
    // 一百二十六+ per-candidate ascent state make the data
    // sources available, so the deferred criteria are met.

    // MARK: - M500 BASKunlunAscentView derivation (L4)

    /// Project an L4 Kunlun ascent view per turn from candidate
    /// state. Mirrors chapter 99 `BASKunlunAxisView` audit-
    /// emission pattern. `isWellFormed` invariant per §5.4
    /// 不急着登顶 doctrine: the view MUST declare both
    /// preconditions (`ascentConditions`) AND a way back
    /// (`returnPaths`). The derive helper synthesizes both by
    /// construction.
    enum AscentView {
        public static func derive(
            candidateID: String?,
            confidence: Double,
            reversibility: Double,
            riskLevel: BASBrainRiskLevel,
            returnPathRefs: [String],
            turnID: String
        ) -> BASKunlunAscentView {
            let conditions = ascentConditions(
                confidence: confidence,
                riskLevel: riskLevel)
            let stops = stopPoints(
                reversibility: reversibility)
            return BASKunlunAscentView(
                questionRef:
                    candidateID ?? "no-candidate",
                ascentConditions: conditions,
                gateSequence: ["heaven-gate-1"],
                stopPoints: stops,
                returnPaths: returnPathRefs.isEmpty
                    ? ["return-path:default"]
                    : returnPathRefs)
        }

        private static func ascentConditions(
            confidence: Double,
            riskLevel: BASBrainRiskLevel
        ) -> [String] {
            var conditions: [String] = []
            if confidence
                >= ascentConfidenceCleanThreshold
            {
                conditions.append("axis-aligned")
            }
            if confidence
                >= ascentConfidenceWithEvidenceThreshold
            {
                conditions.append("evidence-floor-met")
            }
            if riskLevel == .extreme {
                conditions.append("host-explicit-consent")
            }
            // Always include at least one condition so
            // isWellFormed is honored.
            if conditions.isEmpty {
                conditions.append("preconditions-pending")
            }
            return conditions
        }

        private static func stopPoints(
            reversibility: Double
        ) -> [String] {
            reversibility
                < ascentReversibilityStopThreshold
                ? ["pre-commit", "pre-execute"]
                : []
        }
    }

    // MARK: - M501 BASKunlunFarWestReserve derivation (L4)

    /// Project an L4 Kunlun far-west reserve per turn from the
    /// unknown-reserve assertion ceiling. Returns nil when
    /// `unknownRefs` is empty (mirrors M494
    /// BASKunlunUnnamableSet preservation invariant — vacuous
    /// reserves violate "用远方保留区承接未知").
    enum FarWestReserve {
        public static func derive(
            unknownRefs: [String],
            assertionCeiling: BASUnknownAssertionCeiling,
            riskLevel: BASBrainRiskLevel,
            turnID: String
        ) -> BASKunlunFarWestReserve? {
            guard !unknownRefs.isEmpty else { return nil }
            let distance = distanceBand(
                for: assertionCeiling)
            let naming = namingStatus(for: assertionCeiling)
            let safeRules = safeApproachRules(
                for: riskLevel)
            return BASKunlunFarWestReserve(
                unknownRefs: unknownRefs,
                distanceBand: distance,
                namingStatus: naming,
                safeApproachRules: safeRules)
        }

        private static func distanceBand(
            for ceiling: BASUnknownAssertionCeiling
        ) -> BASKunlunFarWestDistance {
            switch ceiling {
            case .unrestricted: return .adjacent
            case .provisional: return .visible
            case .qualified: return .farReach
            case .metaOnly: return .beyondHorizon
            case .none: return .sealedUnknown
            }
        }

        private static func namingStatus(
            for ceiling: BASUnknownAssertionCeiling
        ) -> BASKunlunNamingStatus {
            // Doctrine pin per §5.4 "不急着命名" + chapter 一百
            // 二十八 deep-review finding #1 (M511 fix): `.qualified`
            // ceiling MUST map to `.unattempted` (not `.provisional`)
            // because `BASKunlunFarWestReserve.isHonoringDoctrine`
            // requires namingStatus ∈ {.unattempted, .refused} OR
            // distanceBand == .sealedUnknown. Mapping `.qualified` to
            // `.provisional` produced doctrine-violating reserves.
            // The `.qualified` ceiling means "we have caveats but
            // haven't given up on naming" — this is doctrinally
            // closer to "not yet attempted" than "in-progress
            // naming", so .unattempted is the correct mapping per
            // §5.4 reserve-doctrine.
            switch ceiling {
            case .unrestricted, .provisional, .qualified:
                return .unattempted
            case .metaOnly, .none:
                return .refused
            }
        }

        private static func safeApproachRules(
            for riskLevel: BASBrainRiskLevel
        ) -> [String] {
            switch riskLevel {
            case .low, .medium:
                return []
            case .high:
                return ["host-explicit-permission"]
            case .extreme:
                return [
                    "host-explicit-permission",
                    "no-time-pressure",
                ]
            }
        }
    }
}
