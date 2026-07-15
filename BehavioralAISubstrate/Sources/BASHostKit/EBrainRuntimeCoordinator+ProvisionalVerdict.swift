import Foundation
import BASObservability
import BASPolicy
import BASRuntimeCore

// MARK: - ADR-020 Arc-3 Phase B — pre-render provisional sovereign verdict.
//
// Phase A (EBrainRuntimeCoordinator+SovereignVerdict.swift) extracted the
// sovereign verdict's escalation-level lattice into `computeVerdictDecision`,
// a render-independent pure function of pre-render-settled inputs. Phase B
// reuses that core to compute a PRE-RENDER forecast of the post-render verdict
// LEVEL, before any seal/render artifact exists (ADR-020 §2/§3).
//
// This is DEAD CODE on introduction: there are ZERO call sites in the runtime
// (`runTurn` wiring is Phase C). Because it adds no call edge and mutates no
// existing path, the substrate stays byte-equal-by-construction — there is no
// flag and nothing to gate.
//
// OBSERVATION-ONLY by design: the one endpoint a provisional verdict *could*
// gate — reducing deliberation caution ahead of render — is excluded as
// architecturally unsafe (ADR-020 §1), because a caution-REDUCING forecast
// could only ever make the host less safe. So this type forecasts; it decides
// nothing. The file deliberately imports no render/seal module.

/// Named constants for the pre-render provisional verdict (ADR-020 Phase B).
/// All thresholds live here so the proxy has no magic numbers; the uncertainty
/// thresholds are owned by `BASDeliberationCaution.isGenuinelyUncertain` and are
/// NOT duplicated here.
private enum BASProvisionalVerdictConstants {
    /// The provisional verdict cares about the escalation LEVEL, not the
    /// post-render quarantine/rollback ref IDs. Passing empty refs to the
    /// decision core is exactly what makes the forecast render-independent:
    /// refs are opaque to the lattice and never influence the level.
    static let renderIndependentQuarantineSources: [String] = []
    static let renderIndependentRollbackSource: String? = nil
}

/// A faithful PRE-RENDER forecast of the post-render sovereign verdict's
/// escalation LEVEL (ADR-020 Arc-3 §2/§3).
///
/// OBSERVATION-ONLY — it gates nothing. The single caution-reduction endpoint
/// it could gate is excluded as architecturally unsafe (ADR-020 §1): a
/// caution-reducing forecast could only make the host less safe, so the
/// provisional verdict is permitted to *forecast* but never to *relax*.
///
/// Contract: `provisionalLevel == finalLevel` for the production evolution
/// service; a conservative bound otherwise. The fidelity of this equality
/// (and the exact bound for non-production services) is characterized in
/// Phase C, where the forecast is wired against the real post-render verdict.
///
/// `renderIndependent` is always `true` for the values this type produces: it
/// is derived solely from pre-render-settled inputs plus empty ref
/// placeholders, so it carries no dependence on any seal/render artifact.
public struct BASProvisionalVerdict: Equatable, Sendable {
    /// The forecast escalation level (the lattice output of
    /// `computeVerdictDecision`, computed with empty refs).
    public let provisionalLevel: BASSovereignVerdictLevel

    /// The reason codes the decision lattice accumulated, in lattice order
    /// (unordered/unfiltered — the final verdict applies its own ordering;
    /// the provisional surfaces the raw forecast trail).
    public let reasonCodes: [String]

    /// The confidence floor observed for this turn, echoed verbatim (nil when
    /// the caller had no uncertainty ledger). Echoed so callers can audit the
    /// uncertainty signal that fed `isGenuinelyUncertain` without re-deriving it.
    public let confidenceFloorSeen: Double?

    /// The maximum evidence debt observed for this turn, echoed verbatim
    /// (nil when absent). Echoed for the same audit reason as above.
    public let maxEvidenceDebtSeen: Double?

    /// Whether the matter is genuinely uncertain, composed from the same
    /// predicate the deliberation loop trusts
    /// (`BASDeliberationCaution.isGenuinelyUncertain`). Observation-only here.
    public let isGenuinelyUncertain: Bool

    /// Always `true` for values this type produces (see the type doc): the
    /// forecast depends on no render/seal artifact.
    public let renderIndependent: Bool

    public init(
        provisionalLevel: BASSovereignVerdictLevel,
        reasonCodes: [String],
        confidenceFloorSeen: Double?,
        maxEvidenceDebtSeen: Double?,
        isGenuinelyUncertain: Bool,
        renderIndependent: Bool
    ) {
        self.provisionalLevel = provisionalLevel
        self.reasonCodes = reasonCodes
        self.confidenceFloorSeen = confidenceFloorSeen
        self.maxEvidenceDebtSeen = maxEvidenceDebtSeen
        self.isGenuinelyUncertain = isGenuinelyUncertain
        self.renderIndependent = renderIndependent
    }
}

extension BASEBrainRuntimeCoordinator {

    /// Compute a PRE-RENDER provisional sovereign verdict (ADR-020 Arc-3
    /// Phase B). DEAD CODE on introduction — no runtime call site (Phase C
    /// wires it), so the substrate stays byte-equal-by-construction.
    ///
    /// Faithful to Phase A's render-independent decision core: it reuses
    /// `computeVerdictDecision` unchanged, supplying EMPTY quarantine/rollback
    /// refs (the forecast cares about the LEVEL, not the post-render ref IDs —
    /// and empty refs are precisely what keeps the result render-independent).
    ///
    /// `static` (matching `computeVerdictDecision`): it reads no instance
    /// state. `policyLineagePresent` is passed in rather than read from
    /// `self.policyLineage`, so the forecast is unit-testable without a
    /// coordinator.
    ///
    /// `needsProtectedWriteLane` proxy: the production
    /// `buildSovereignVerdict` derives this from `request.activeKillSwitches`,
    /// `actionPermit.mode`, and `updateTickets`. Pre-render we lack
    /// `updateTickets`, so the ticket clause
    /// (`$0.requiresReview || $0.conflictFlag`) is replaced by the
    /// conservative proxy `actionPermit.mode == .block` — production
    /// `conflictFlag` mirrors the block/replace permit modes, so this proxy
    /// never UNDER-states the need for a protected write lane.
    ///
    /// OBSERVATION-ONLY: the returned value gates nothing.
    public static func buildProvisionalVerdict(
        policyLineagePresent: Bool,
        budgetFrame: BASBudgetFrame,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        emergencyBrake: BASEmergencyBrake,
        activeKillSwitches: [BASKillSwitchID],
        confidenceFloor: Double?,
        maxEvidenceDebt: Double?,
        leaseEnded: Bool
    ) -> BASProvisionalVerdict {
        // Pre-render proxy for the render-derived `needsProtectedWriteLane`.
        // The `updateTickets` clause of the production predicate is replaced by
        // the conservative `actionPermit.mode == .block` proxy (see doc above).
        let needsProtectedWriteLane =
            activeKillSwitches.contains(.requireReviewedWrites)
            || actionPermit.mode == .delay
            || actionPermit.mode == .replace
            || actionPermit.mode == .block
            // audit hostkit-spine F8: the docstring promises this proxy NEVER under-states the need
            // for a protected lane, but a high-risk card (whose production conflictFlag would demand
            // one) was missing. Add it so the conservative "or higher, never under" contract holds.
            || riskCard.riskLevel >= .high

        // Reuse Phase A's render-independent decision core with EMPTY refs —
        // the forecast cares about the LEVEL, not post-render ref IDs, and
        // empty refs are what make the result render-independent.
        let decision = computeVerdictDecision(
            policyLineagePresent: policyLineagePresent,
            budgetFrame: budgetFrame,
            riskCard: riskCard,
            actionPermit: actionPermit,
            emergencyBrake: emergencyBrake,
            activeKillSwitches: activeKillSwitches,
            needsProtectedWriteLane: needsProtectedWriteLane,
            quarantineSources: BASProvisionalVerdictConstants
                .renderIndependentQuarantineSources,
            rollbackSource: BASProvisionalVerdictConstants
                .renderIndependentRollbackSource
        )

        let isGenuinelyUncertain = BASDeliberationCaution.isGenuinelyUncertain(
            confidenceFloor: confidenceFloor,
            maxEvidenceDebt: maxEvidenceDebt,
            leaseEnded: leaseEnded
        )

        return BASProvisionalVerdict(
            provisionalLevel: decision.level,
            reasonCodes: decision.reasonCodes,
            confidenceFloorSeen: confidenceFloor,
            maxEvidenceDebtSeen: maxEvidenceDebt,
            isGenuinelyUncertain: isGenuinelyUncertain,
            renderIndependent: true
        )
    }
}
