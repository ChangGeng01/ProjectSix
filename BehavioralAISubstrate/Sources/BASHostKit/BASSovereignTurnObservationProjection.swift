// MARK: - BASSovereignTurnObservationProjection
// ADR-022 / ch1044 严查 #3 — Sovereign verdict parity SHADOW gate, Phase 1.
//
// Builds the engine-facing `BASSovereignTurnObservations` from settled,
// pre-render turn state so a host can run `BASSovereignTurnVerifier` ALONGSIDE
// the coordinator's `buildSovereignVerdict` and OBSERVE verdict drift.
//
// ## Why this is byte-equal (红线 7)
//
// Nothing here is called by the coordinator's production path —
// `buildSovereignVerdict` is untouched. The projection + shadow run are
// host-driven and OBSERVATION-ONLY: they never mutate the coordinator's verdict
// and never halt. So this slice is byte-equal *by construction*, not merely by a
// default-off flag. Phase 2 (acting on `.coordinatorLaxer` to force a halt) is a
// separate, later, gated arc (ADR-022 §2) and is NOT here.
//
// ## Conservative-default discipline (ADR-022 §4, corrected)
//
// Flags without a faithful local source default toward making the ENGINE LAXER
// (`false` / neutral), NOT stricter. Making the engine artificially strict would
// risk a FALSE `.coordinatorLaxer` (engine > coordinator on a healthy turn). In
// the shadow we prefer a false negative (a missed divergence) over a false
// positive (a spurious halt-signal). The unsourced flags below are wired in
// later Phase-1b increments as their sources are threaded to this seam.

import Foundation
import BASRuntimeCore
import BASPolicy
import BASSovereign

public enum BASSovereignTurnObservationProjection {

    /// Project settled, pre-render turn state into the engine's observation.
    /// Pure + deterministic (same inputs → same output → replay-safe).
    ///
    /// The caller (the coordinator at `buildSovereignVerdict`, or a host) supplies
    /// the already-derived primitives — `policyLineagePresent`,
    /// `needsProtectedWriteLane`, `quarantineCount`, `snapshotRef`, `policyHash`,
    /// `operation`, `evidenceSufficient` — exactly as the coordinator computes
    /// them; the rich frames supply the rest.
    public static func project(
        sessionID: String,
        turnID: String,
        snapshotRef: String,
        policyHash: String,
        policyLineagePresent: Bool,
        budgetFrame: BASBudgetFrame,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        emergencyBrake: BASEmergencyBrake,
        needsProtectedWriteLane: Bool,
        quarantineCount: Int,
        operation: BASSovereignVerdictEngine.OperationDomain,
        evidenceSufficient: Bool,
        hostGateValue: Double = 1.0
    ) -> BASSovereignTurnObservations {
        let riskHighPlus = riskCard.riskLevel >= .high
        let brakeElevated = emergencyBrake.brakeLevel != .none
        return BASSovereignTurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: snapshotRef,
            policyHash: policyHash,
            // BR-006 — faithfully sourced.
            policyLineageMissing: !policyLineagePresent,
            // BR-012 — not sourced at this seam → conservative false (laxer).
            auditEntryMissing: false,
            // BR-009 — faithfully sourced.
            runtimeUnstableInHighRisk: brakeElevated && riskHighPlus,
            // BR-010 — faithfully sourced.
            riskPermitHeadConflict: actionPermit.mode == .answer && riskHighPlus,
            // BR-003 — not sourced at this seam → conservative false (laxer).
            externalSideEffectWithoutSCT: false,
            // BR-005 — not sourced at this seam → conservative false (laxer).
            hostRemovalBypassed: false,
            // BR-007 — the coordinator's own protected-write-lane signal
            // (kill-switch / permit .delay|.replace / update-ticket review|conflict).
            unauthorizedSelfMutation: needsProtectedWriteLane,
            // BR-004 — not sourced at this seam → conservative false (laxer).
            memoryOrHostWriteBypass: false,
            // Soft signals — straight from the risk card.
            irreversibilityScore: riskCard.irreversibility,
            manipulationStrength: riskCard.manipulationStrength,
            uncertaintyScore: riskCard.uncertainty,
            gsiScore: riskCard.gsiScore,
            // hostGateValue (L13): defaults to 1.0 (full integrity → a 0.0
            // integrity-loss signal = engine-laxer) when the caller can't supply
            // it. Phase-1b lets the host thread the real
            // `BASEBrainTurnResult.hostGateValue` through this param.
            hostGateValue: hostGateValue,
            quarantineCount: max(0, quarantineCount),
            runMode: budgetFrame.runMode,
            emergencyBrakeLevel: emergencyBrake.brakeLevel,
            operation: operation,
            evidenceSufficient: evidenceSufficient
        )
    }

    /// Phase-1 SHADOW run: project-then-verify, OBSERVATION-ONLY.
    ///
    /// The caller supplies the verifier (which wraps a `BASSovereignVerdictEngine`)
    /// and the coordinator's own verdict level for the same turn. This returns the
    /// parity report; it NEVER halts and NEVER mutates the coordinator's verdict.
    /// A `.coordinatorLaxer` parity is the signal a *future* Phase-2 gate would act
    /// on — here it is for the host to record/log only.
    public static func shadowVerify(
        _ observations: BASSovereignTurnObservations,
        coordinatorLevel: BASSovereignVerdictLevel?,
        using verifier: BASSovereignTurnVerifier
    ) async throws -> BASSovereignTurnVerifierReport {
        try await verifier.verify(observations, coordinatorLevel: coordinatorLevel)
    }

    /// Phase-1b OPT-IN per-turn shadow — the carrier. A **no-op** when
    /// `verifier` is nil: that is the default-OFF / byte-equal path. The host
    /// holds the (verifier, sink) pair; both nil means the shadow never runs, so
    /// the turn is bit-identical (红线 7). When enabled, it verifies and hands the
    /// parity report to `sink`, then returns it. OBSERVATION-ONLY — it never
    /// halts and never mutates the coordinator's verdict. A verify error is
    /// swallowed (the shadow must NEVER break a real turn); Phase-2 — which acts
    /// on `.coordinatorLaxer` — is a separate, later, gated arc.
    @discardableResult
    public static func runShadowIfEnabled(
        observations: BASSovereignTurnObservations,
        coordinatorLevel: BASSovereignVerdictLevel?,
        verifier: BASSovereignTurnVerifier?,
        sink: (@Sendable (BASSovereignTurnVerifierReport) -> Void)? = nil
    ) async -> BASSovereignTurnVerifierReport? {
        guard let verifier else { return nil }
        guard let report = try? await verifier.verify(
            observations, coordinatorLevel: coordinatorLevel
        ) else { return nil }
        sink?(report)
        return report
    }
}
