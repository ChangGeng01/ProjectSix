// MARK: - EBrainL10TribunalCore — chapter 二百七十七 / M764
//
// Phase Alpha 第三刀:从 EBrainCognitionPlaneCore.swift 抽出 L10
// tribunal types。chapter 一百七十七 vision L10 = "三我庭" — Id /
// Ego / Superego full-body tribunal,arbitration + court decision
// + agency reservation + remand。
//
// 抽出 13 types:
//   - BASTriSelfScore (per-candidate id/ego/superego score)
//   - BASCourtVetoType / BASVetoMark (veto types + marks)
//   - BASTradeoffLedger
//   - BASAgencyReservationMode / BASAgencyReservation
//   - BASRemandOrder / BASCourtDecisionDraft
//   - BASIdImpulseProfile / BASEgoRealityAssessment /
//     BASSuperegoJudgment / BASArbitrationFrame
//   - BASMergedChoice (final tribunal output)
//
// **0 behavior change**:types literal-identical to pre-extraction
// versions。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保:纯 file org refactor
//   - 红线 7 watcher hint only:types are schema definitions
//   - chapter 二百十一 single-source-of-truth:types 仍 owned by
//     one file (god file → dedicated file)

import Foundation
import BASRuntimeCore

public struct BASTriSelfScore: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var idScore: Double
    public var egoScore: Double
    public var superegoScore: Double
    public var mergedScore: Double
    public var veto: Bool

    public init(
        schemaVersion: String = BASTriSelfScore.currentSchemaVersion,
        candidateID: String,
        idScore: Double,
        egoScore: Double,
        superegoScore: Double,
        mergedScore: Double,
        veto: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.idScore = idScore
        self.egoScore = egoScore
        self.superegoScore = superegoScore
        self.mergedScore = mergedScore
        self.veto = veto
    }
}

public enum BASCourtVetoType: String, Codable, CaseIterable, Sendable {
    case boundary
    case dignity
    case hostConstitution
    case irreversibility
    case sovereignPrecondition
    case calibration
}

public struct BASVetoMark: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var vetoType: BASCourtVetoType
    public var reasonCodes: [String]
    public var compensable: Bool

    public init(
        schemaVersion: String = BASVetoMark.currentSchemaVersion,
        candidateID: String,
        vetoType: BASCourtVetoType,
        reasonCodes: [String] = [],
        compensable: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.vetoType = vetoType
        self.reasonCodes = reasonCodes
        self.compensable = compensable
    }
}

public struct BASTradeoffLedger: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var gains: [String]
    public var costs: [String]
    public var sacrifices: [String]
    public var unresolvedTensions: [String]

    public init(
        schemaVersion: String = BASTradeoffLedger.currentSchemaVersion,
        candidateID: String,
        gains: [String] = [],
        costs: [String] = [],
        sacrifices: [String] = [],
        unresolvedTensions: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.gains = gains
        self.costs = costs
        self.sacrifices = sacrifices
        self.unresolvedTensions = unresolvedTensions
    }
}

public enum BASAgencyReservationMode: String, Codable, CaseIterable, Sendable {
    case retainChoice
    case compareOnly
    case delayRight
    case noAutoMerge
}

public struct BASAgencyReservation: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var mode: BASAgencyReservationMode
    public var reasons: [String]
    public var expiresWith: String?

    public init(
        schemaVersion: String = BASAgencyReservation.currentSchemaVersion,
        mode: BASAgencyReservationMode,
        reasons: [String] = [],
        expiresWith: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.reasons = reasons
        self.expiresWith = expiresWith?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASRemandOrder: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var targetLayer: String
    public var requiredWork: [String]
    public var reasonCodes: [String]

    public init(
        schemaVersion: String = BASRemandOrder.currentSchemaVersion,
        targetLayer: String,
        requiredWork: [String] = [],
        reasonCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.targetLayer = targetLayer.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requiredWork = requiredWork
        self.reasonCodes = reasonCodes
    }
}

public struct BASCourtDecisionDraft: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var preferredCandidateID: String
    public var fallbackCandidateIDs: [String]
    public var guardCandidateID: String?
    public var requiredDisclosures: [String]
    public var unresolvedCosts: [String]
    public var agencyMode: BASAgencyReservationMode?
    public var readinessLevel: String

    public init(
        schemaVersion: String = BASCourtDecisionDraft.currentSchemaVersion,
        preferredCandidateID: String,
        fallbackCandidateIDs: [String] = [],
        guardCandidateID: String? = nil,
        requiredDisclosures: [String] = [],
        unresolvedCosts: [String] = [],
        agencyMode: BASAgencyReservationMode? = nil,
        readinessLevel: String
    ) {
        self.schemaVersion = schemaVersion
        self.preferredCandidateID = preferredCandidateID
        self.fallbackCandidateIDs = fallbackCandidateIDs
        self.guardCandidateID = guardCandidateID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requiredDisclosures = requiredDisclosures
        self.unresolvedCosts = unresolvedCosts
        self.agencyMode = agencyMode
        self.readinessLevel = readinessLevel.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - M89 · L10 full-body tribunal schema (target-state whitepaper §5.2–§5.4 + §5.1)

/// M89 — Freudian-id analogue profile. One of the three sub-records
/// every `BASArbitrationFrame` aggregates.
///
/// The whitepaper (`docs/EBRAIN_L10_TRI_SELF_COURT_TARGET_VINF.md` §5.2)
/// defines the Id voice as "raw drives / relief seeking / aversion
/// targets / unmet needs / vitality load". This schema records one
/// complete per-turn snapshot of those signals.
///
/// All scalar fields are normalised to `[0, 1]` by the init clamp so
/// a sloppy caller cannot poison downstream reasoning with out-of-range
/// values.
public struct BASIdImpulseProfile: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable ID for cross-reference from `BASArbitrationFrame`.
    public var profileID: String
    /// Free-text relief targets the id voice is seeking — e.g.
    /// `"stop-conversation-pain"`, `"rapid-win-dopamine"`.
    public var desiredRelief: [String]
    /// How much the id voice wants control recovery this turn.
    /// `0` = content; `1` = desperate. Clamped.
    public var controlRecoveryNeed: Double
    /// Free-text aversion targets the id voice is trying to escape —
    /// e.g. `"lonely-silence"`, `"public-embarrassment"`.
    public var aversionTargets: [String]
    /// Urgency pressure on the id voice. `0` = no rush; `1` =
    /// panic. Clamped.
    public var urgencyFeel: Double
    /// Free-text unmet needs feeding the id voice — e.g.
    /// `"sleep"`, `"recognition"`, `"touch"`.
    public var unmetNeeds: [String]
    /// Vitality load / energetic charge behind the id voice this
    /// turn. `0` = depleted; `1` = fully charged. Clamped.
    public var vitalityLoad: Double

    public init(
        schemaVersion: String = BASIdImpulseProfile.currentSchemaVersion,
        profileID: String,
        desiredRelief: [String] = [],
        controlRecoveryNeed: Double = 0,
        aversionTargets: [String] = [],
        urgencyFeel: Double = 0,
        unmetNeeds: [String] = [],
        vitalityLoad: Double = 0
    ) {
        self.schemaVersion = schemaVersion
        self.profileID = profileID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.desiredRelief = desiredRelief
        self.controlRecoveryNeed = min(max(controlRecoveryNeed, 0), 1)
        self.aversionTargets = aversionTargets
        self.urgencyFeel = min(max(urgencyFeel, 0), 1)
        self.unmetNeeds = unmetNeeds
        self.vitalityLoad = min(max(vitalityLoad, 0), 1)
    }
}

/// M89 — Freudian-ego analogue reality assessment. One of the three
/// sub-records every `BASArbitrationFrame` aggregates.
///
/// The whitepaper (§5.3) defines the Ego voice as "reality testing /
/// feasibility / timing / evidence readiness / resource costs /
/// realism". This schema records those signals per turn.
///
/// `feasibleCandidateIDs` and `blockedCandidateIDs` MUST be disjoint
/// (a candidate is either feasible or blocked, never both); callers
/// enforce that invariant — the init does not re-check it to keep the
/// structure cheap on the hot path.
public struct BASEgoRealityAssessment: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable ID for cross-reference from `BASArbitrationFrame`.
    public var assessmentID: String
    /// Candidate IDs the ego voice considers feasible this turn.
    public var feasibleCandidateIDs: [String]
    /// Candidate IDs the ego voice considers blocked (timing /
    /// evidence / resource constraint violated).
    public var blockedCandidateIDs: [String]
    /// Timing fit for the chosen path. `0` = wrong time / window
    /// missed; `1` = ideal window. Clamped.
    public var timingFit: Double
    /// Evidence readiness — do we have enough information to act
    /// safely? `0` = almost nothing; `1` = fully informed. Clamped.
    public var evidenceReadiness: Double
    /// Free-text resource costs the ego voice is tracking — e.g.
    /// `"2h-focus"`, `"$50-cash"`, `"one-favor-from-N"`.
    public var resourceCosts: [String]
    /// Lease fit — does the action fit within the current lease
    /// budget (time / token / thermal / attention)? Clamped to
    /// `[0, 1]`.
    public var leaseFit: Double
    /// Overall realism score for the turn's path. Aggregate of the
    /// above signals. Clamped.
    public var realismScore: Double

    public init(
        schemaVersion: String = BASEgoRealityAssessment.currentSchemaVersion,
        assessmentID: String,
        feasibleCandidateIDs: [String] = [],
        blockedCandidateIDs: [String] = [],
        timingFit: Double = 0,
        evidenceReadiness: Double = 0,
        resourceCosts: [String] = [],
        leaseFit: Double = 0,
        realismScore: Double = 0
    ) {
        self.schemaVersion = schemaVersion
        self.assessmentID = assessmentID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.feasibleCandidateIDs = feasibleCandidateIDs
        self.blockedCandidateIDs = blockedCandidateIDs
        self.timingFit = min(max(timingFit, 0), 1)
        self.evidenceReadiness = min(max(evidenceReadiness, 0), 1)
        self.resourceCosts = resourceCosts
        self.leaseFit = min(max(leaseFit, 0), 1)
        self.realismScore = min(max(realismScore, 0), 1)
    }
}

/// M89 — Freudian-superego analogue judgment. One of the three
/// sub-records every `BASArbitrationFrame` aggregates.
///
/// The whitepaper (§5.4) defines the Superego voice as "internalized
/// norms / dignity risks / boundary conflicts / value violations /
/// relation ethics / irreversibility warnings / veto candidates".
/// This schema records those signals per turn.
///
/// Unlike the id / ego voices this one carries **no scalar scores** —
/// only categorical evidence arrays. The superego voice in the
/// whitepaper is structurally different: it speaks by naming harms,
/// not by grading alternatives.
public struct BASSuperegoJudgment: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable ID for cross-reference from `BASArbitrationFrame`.
    public var judgmentID: String
    /// Free-text dignity-risk codes — e.g. `"public-shaming"`,
    /// `"self-respect-erosion"`.
    public var dignityRisks: [String]
    /// Free-text boundary-conflict codes — e.g. `"sleep-boundary"`,
    /// `"commitment-to-spouse"`.
    public var boundaryConflicts: [String]
    /// Free-text value-violation codes — e.g. `"honesty"`,
    /// `"promise-keeping"`.
    public var valueViolations: [String]
    /// Free-text relation-ethics load entries — e.g. `"owe-trust-to-N"`,
    /// `"unpaid-debt-to-M"`.
    public var relationEthicsLoad: [String]
    /// Free-text irreversible-warning codes — e.g. `"cannot-unsend"`,
    /// `"burns-bridge-with-employer"`.
    public var irreversibleWarnings: [String]
    /// Candidate IDs the superego voice recommends vetoing outright.
    public var vetoCandidateIDs: [String]

    public init(
        schemaVersion: String = BASSuperegoJudgment.currentSchemaVersion,
        judgmentID: String,
        dignityRisks: [String] = [],
        boundaryConflicts: [String] = [],
        valueViolations: [String] = [],
        relationEthicsLoad: [String] = [],
        irreversibleWarnings: [String] = [],
        vetoCandidateIDs: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.judgmentID = judgmentID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dignityRisks = dignityRisks
        self.boundaryConflicts = boundaryConflicts
        self.valueViolations = valueViolations
        self.relationEthicsLoad = relationEthicsLoad
        self.irreversibleWarnings = irreversibleWarnings
        self.vetoCandidateIDs = vetoCandidateIDs
    }
}

/// M89 — L10 tribunal arbitration frame. The top-level record that
/// bundles the three sub-profiles (`BASIdImpulseProfile`,
/// `BASEgoRealityAssessment`, `BASSuperegoJudgment`) with references
/// back to the other tribunal objects already shipped
/// (`BASVetoMark`, `BASRemandOrder`, `BASTradeoffLedger`,
/// `BASCourtDecisionDraft`, `BASAgencyReservation`) plus string refs
/// to upstream / sibling artefacts (candidate frontier / host
/// constitution / memory bundle / outcomes / adversarial critiques).
///
/// The whitepaper (§5.1) describes this as the "integrated tribunal
/// verdict" — the single object L14 reads to decide sovereign
/// disposition, the single object audit ledgers stream.
///
/// ## Design choices
///
/// - **Holds the three sub-records directly, not by ID.** Whitepaper
///   says `id_profile_ref` but in Swift inlining the optional
///   sub-record gives callers a complete object without a lookup
///   table. The sub-record's own `profileID` / `assessmentID` /
///   `judgmentID` serves as the cross-reference ID when needed.
/// - **External objects referenced by ID string.** Candidate frontier,
///   host constitution, memory bundle, tradeoff ledgers, vetoes,
///   remands, decision draft — all keep their own audit-trail IDs
///   and we point at those so the frame stays small.
/// - **All optional sub-records default to nil.** A tribunal turn
///   that skipped one voice (e.g. fast-track emergency that bypasses
///   superego) still materializes a valid frame with the missing
///   voice as `nil`.
public struct BASArbitrationFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable ID for this tribunal turn.
    public var frameID: String
    /// ID of the candidate frontier this tribunal worked over.
    public var candidateFrontierRef: String?
    /// IDs of any prior turn outcomes that feed this tribunal.
    public var outcomeRefs: [String]
    /// IDs of adversarial critique frames this tribunal considered.
    public var adversarialRefs: [String]
    /// ID of the host constitution state the tribunal read.
    public var hostConstitutionRef: String?
    /// ID of the memory bundle this tribunal referenced.
    public var memoryBundleRef: String?
    /// Inlined id-voice profile. `nil` if the voice was skipped.
    public var idProfile: BASIdImpulseProfile?
    /// Inlined ego-voice assessment. `nil` if the voice was skipped.
    public var egoAssessment: BASEgoRealityAssessment?
    /// Inlined superego-voice judgment. `nil` if the voice was skipped.
    public var superegoJudgment: BASSuperegoJudgment?
    /// IDs of `BASTradeoffLedger` records that this tribunal referenced.
    public var tradeoffLedgerRefs: [String]
    /// ID of the `BASAgencyReservation` this tribunal chose.
    public var agencyReservationRef: String?
    /// IDs of `BASVetoMark` records this tribunal applied.
    public var vetoRefs: [String]
    /// IDs of `BASRemandOrder` records this tribunal issued.
    public var remandRefs: [String]
    /// ID of the `BASCourtDecisionDraft` this tribunal produced.
    public var decisionDraftRef: String?

    public init(
        schemaVersion: String = BASArbitrationFrame.currentSchemaVersion,
        frameID: String,
        candidateFrontierRef: String? = nil,
        outcomeRefs: [String] = [],
        adversarialRefs: [String] = [],
        hostConstitutionRef: String? = nil,
        memoryBundleRef: String? = nil,
        idProfile: BASIdImpulseProfile? = nil,
        egoAssessment: BASEgoRealityAssessment? = nil,
        superegoJudgment: BASSuperegoJudgment? = nil,
        tradeoffLedgerRefs: [String] = [],
        agencyReservationRef: String? = nil,
        vetoRefs: [String] = [],
        remandRefs: [String] = [],
        decisionDraftRef: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.frameID = frameID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateFrontierRef = candidateFrontierRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.outcomeRefs = outcomeRefs
        self.adversarialRefs = adversarialRefs
        self.hostConstitutionRef = hostConstitutionRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.memoryBundleRef = memoryBundleRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.idProfile = idProfile
        self.egoAssessment = egoAssessment
        self.superegoJudgment = superegoJudgment
        self.tradeoffLedgerRefs = tradeoffLedgerRefs
        self.agencyReservationRef = agencyReservationRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.vetoRefs = vetoRefs
        self.remandRefs = remandRefs
        self.decisionDraftRef = decisionDraftRef?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASMergedChoice: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.1.0"

    public var schemaVersion: String
    public var candidateID: String
    public var title: String
    public var actionSummary: String
    public var vetoApplied: Bool
    public var vetoReasonCodes: [String]
    public var vetoMarks: [BASVetoMark]?
    public var tradeoffLedgers: [BASTradeoffLedger]?
    public var agencyReservation: BASAgencyReservation?
    public var remandOrders: [BASRemandOrder]?
    public var courtDecisionDraft: BASCourtDecisionDraft?

    public init(
        schemaVersion: String = BASMergedChoice.currentSchemaVersion,
        candidateID: String,
        title: String,
        actionSummary: String,
        vetoApplied: Bool = false,
        vetoReasonCodes: [String] = [],
        vetoMarks: [BASVetoMark]? = nil,
        tradeoffLedgers: [BASTradeoffLedger]? = nil,
        agencyReservation: BASAgencyReservation? = nil,
        remandOrders: [BASRemandOrder]? = nil,
        courtDecisionDraft: BASCourtDecisionDraft? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.title = title
        self.actionSummary = actionSummary
        self.vetoApplied = vetoApplied
        self.vetoReasonCodes = vetoReasonCodes
        self.vetoMarks = vetoMarks
        self.tradeoffLedgers = tradeoffLedgers
        self.agencyReservation = agencyReservation
        self.remandOrders = remandOrders
        self.courtDecisionDraft = courtDecisionDraft
    }
}
