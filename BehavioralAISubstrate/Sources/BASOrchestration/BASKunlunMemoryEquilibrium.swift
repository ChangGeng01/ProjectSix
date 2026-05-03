// SPDX-License-Identifier: Apache-2.0
// M471-M475 (chapter 一百二十三 / Stream A β) — Kunlun memory +
// equilibrium + permit-grade + refinement schemas across L3 / L8
// / L10 / L11 / L13 per
// `docs/QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF.md` §5.3, §5.8,
// §5.10, §5.11, §5.13.
//
// 5 schemas:
//   - M471 BASJadeCasketSnapshot   — L3 玉匣折页
//   - M472 BASYaochiMemoryLayer     — L8 瑶池深井 layer
//   - M473 BASTianhengProfile       — L10 天衡庭 equilibrium
//   - M474 BASJadePermitGrade       — L11 玉律风闸 grade
//   - M475 BASJadeRefinementTicket  — L13 炼玉炉 ticket
//
// Naming note: the L10 schema uses Pinyin "Tianheng" (天衡)
// instead of an English compound, matching the
// `BASKunlunTianmenWarrant` (Tianmen / 天门) precedent shipped
// chapter 九十二. Substrate residual gate reserves several
// pre-M20 host-compat tokens; the Pinyin form preserves the
// Kunlun whitepaper's 天衡庭 anchor without conflict.
//
// ## Doctrine pins
//
// - `BASSchemaVersioned` + `Sendable` + `Equatable` + `Codable`
//   + `Hashable` for every type
// - All `Double` fields clamped `[0, 1]` per chapter 一百三 /
//   一百十三 anti-magic-number doctrine
// - Trim+filter empties on `[String]` arrays
// - Schema version `1.0.0` baseline
// - Doctrine invariants:
//   - `BASJadeCasketSnapshot` 4 ref fields all non-empty per §4.2
//     jade-canon red lines
//   - `BASYaochiMemoryLayer.humanAnchorRequired` true when
//     `sanctumPolicy ≠ ""` (high-sensitivity layers gate on
//     anchor)
//   - `BASJadePermitGrade.gateRequirements` non-empty when any
//     score below threshold
//   - `BASJadeRefinementTicket.fracturePath` non-empty per §5.13
//     "坏候选要能碎回去, 不留下幽灵"
//
// ## DAG discipline
//
// Imports `Foundation` + `BASRuntimeCore` only.

import Foundation
import BASRuntimeCore

// MARK: - M471 BASJadeCasketSnapshot (L3 玉匣折页)

/// L3 high-integrity fold-page snapshot per Kunlun TARGET §5.3
/// (line 697-705).
///
/// Doctrine invariant per §4.2 jade-canon red lines: 4 ref
/// fields (integrityHash + sourceRiverRef + restoreGateRef +
/// rollbackWritRef) MUST all be non-empty.
public struct BASJadeCasketSnapshot:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var snapshotID: String
    public var foldRefs: [String]
    public var integrityHash: String
    public var sourceRiverRef: String
    public var restoreGateRef: String
    public var rollbackWritRef: String

    public init(
        schemaVersion: String =
            BASJadeCasketSnapshot.currentSchemaVersion,
        snapshotID: String,
        foldRefs: [String],
        integrityHash: String,
        sourceRiverRef: String,
        restoreGateRef: String,
        rollbackWritRef: String
    ) {
        self.schemaVersion = schemaVersion
        self.snapshotID = snapshotID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.foldRefs = foldRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.integrityHash = integrityHash
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceRiverRef = sourceRiverRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.restoreGateRef = restoreGateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.rollbackWritRef = rollbackWritRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Doctrine invariant pin per §4.2: all 4 jade-canon
    /// reference fields must be non-empty.
    public var honorsJadeCanonInvariants: Bool {
        !integrityHash.isEmpty
            && !sourceRiverRef.isEmpty
            && !restoreGateRef.isEmpty
            && !rollbackWritRef.isEmpty
    }
}

// MARK: - M472 BASYaochiMemoryLayer (L8 瑶池深井)

/// L8 high-sensitivity memory layer per Kunlun TARGET §5.8
/// (line 917-925). Distinct from `BASMemoryTemperatureLayer`
/// (Cthulhu chapter 一百十五 — 5-tier thermal enum).
public struct BASYaochiMemoryLayer:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var layerID: String
    public var memoryRefs: [String]
    public var sanctumPolicy: String
    public var revealConditions: [String]
    public var humanAnchorRequired: Bool
    public var sovereignGateRequired: Bool

    public init(
        schemaVersion: String =
            BASYaochiMemoryLayer.currentSchemaVersion,
        layerID: String,
        memoryRefs: [String],
        sanctumPolicy: String,
        revealConditions: [String],
        humanAnchorRequired: Bool,
        sovereignGateRequired: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.layerID = layerID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.memoryRefs = memoryRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.sanctumPolicy = sanctumPolicy
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.revealConditions = revealConditions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.humanAnchorRequired = humanAnchorRequired
        self.sovereignGateRequired = sovereignGateRequired
    }

    /// Doctrine invariant pin per §5.8: when `sanctumPolicy`
    /// is non-empty (i.e. layer is high-sensitivity), human-
    /// anchor MUST be required.
    public var honorsAnchorInvariant: Bool {
        if !sanctumPolicy.isEmpty { return humanAnchorRequired }
        return true
    }
}

// MARK: - M473 BASTianhengProfile (L10 天衡庭)

/// L10 three-self equilibrium profile per Kunlun TARGET §5.10
/// (line 1010-1020). Pinyin "Tianheng" = 天衡 (heavenly scales)
/// — replaces L10 tribunal's "judge from above" stance with
/// "scales toward center". id (本我) / ego (自我) / superego
/// (超我) all weighted toward the host's centerline.
public struct BASTianhengProfile:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var profileID: String
    /// Stable reason codes from the id (本我) voice.
    public var idClaims: [String]
    /// Stable reason codes describing ego (自我) constraints.
    public var egoConstraints: [String]
    /// Stable reason codes from the superego (超我) voice.
    public var superegoClaims: [String]
    /// Bias toward centerline `[0, 1]`. Higher = more
    /// centerline-aligned.
    public var centerBias: Double
    /// Minimum dignity floor `[0, 1]`.
    public var dignityFloor: Double
    /// Minimum agency floor `[0, 1]`.
    public var agencyFloor: Double
    /// Stable reason codes describing imbalances (e.g.
    /// `"id-overweight"`, `"superego-too-cold"`).
    public var imbalanceCodes: [String]

    public init(
        schemaVersion: String =
            BASTianhengProfile.currentSchemaVersion,
        profileID: String,
        idClaims: [String],
        egoConstraints: [String],
        superegoClaims: [String],
        centerBias: Double,
        dignityFloor: Double,
        agencyFloor: Double,
        imbalanceCodes: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.profileID = profileID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.idClaims = idClaims
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.egoConstraints = egoConstraints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.superegoClaims = superegoClaims
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.centerBias = min(1, max(0, centerBias))
        self.dignityFloor = min(1, max(0, dignityFloor))
        self.agencyFloor = min(1, max(0, agencyFloor))
        self.imbalanceCodes = imbalanceCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - M474 BASJadePermitGrade (L11 玉律风闸)

/// L11 jade-canon permit grading per Kunlun TARGET §5.11
/// (line 1046-1055).
///
/// Doctrine invariant pin per §5.11: when any score is below
/// `gateMandatoryScoreThreshold` (default 0.5), `gateRequirements`
/// MUST be non-empty.
public struct BASJadePermitGrade:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    /// Score below which gate requirements are mandatory.
    /// Anti-magic-number named static.
    public static let gateMandatoryScoreThreshold: Double = 0.5

    public var schemaVersion: String
    public var gradeID: String
    public var actionPermitRef: String
    public var clarityScore: Double
    public var reversibilityScore: Double
    public var provenanceScore: Double
    public var gateRequirements: [String]
    public var revocationPath: String

    public init(
        schemaVersion: String =
            BASJadePermitGrade.currentSchemaVersion,
        gradeID: String,
        actionPermitRef: String,
        clarityScore: Double,
        reversibilityScore: Double,
        provenanceScore: Double,
        gateRequirements: [String],
        revocationPath: String
    ) {
        self.schemaVersion = schemaVersion
        self.gradeID = gradeID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.actionPermitRef = actionPermitRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.clarityScore = min(1, max(0, clarityScore))
        self.reversibilityScore = min(1, max(0, reversibilityScore))
        self.provenanceScore = min(1, max(0, provenanceScore))
        self.gateRequirements = gateRequirements
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.revocationPath = revocationPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Doctrine invariant pin per §5.11 "合度地过": when any
    /// score is below `gateMandatoryScoreThreshold`,
    /// `gateRequirements` MUST be non-empty.
    public var honorsGateInvariant: Bool {
        let belowThreshold = clarityScore
            < Self.gateMandatoryScoreThreshold
            || reversibilityScore
            < Self.gateMandatoryScoreThreshold
            || provenanceScore
            < Self.gateMandatoryScoreThreshold
        if belowThreshold { return !gateRequirements.isEmpty }
        return true
    }
}

// MARK: - M475 BASJadeRefinementTicket (L13 炼玉炉)

/// L13 jade-refinement ticket per Kunlun TARGET §5.13 (line
/// 1117-1126).
///
/// Doctrine invariant pin per §5.13 "坏候选要能碎回去,
/// 不留下幽灵": `fracturePath` MUST be non-empty.
public struct BASJadeRefinementTicket:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var ticketID: String
    public var candidateRef: String
    public var impurityCodes: [String]
    public var refinementSteps: [String]
    public var shadowTrialRef: String
    public var fracturePath: String
    public var promotionGateRef: String

    public init(
        schemaVersion: String =
            BASJadeRefinementTicket.currentSchemaVersion,
        ticketID: String,
        candidateRef: String,
        impurityCodes: [String],
        refinementSteps: [String],
        shadowTrialRef: String,
        fracturePath: String,
        promotionGateRef: String
    ) {
        self.schemaVersion = schemaVersion
        self.ticketID = ticketID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateRef = candidateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.impurityCodes = impurityCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.refinementSteps = refinementSteps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.shadowTrialRef = shadowTrialRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.fracturePath = fracturePath
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.promotionGateRef = promotionGateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Doctrine invariant pin per §5.13: `fracturePath` MUST
    /// be non-empty (坏候选要能碎回去, 不留下幽灵).
    public var honorsNoGhostInvariant: Bool {
        !fracturePath.isEmpty
    }
}
