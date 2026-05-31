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

    // MARK: - Phase-1c — project directly from a completed turn result

    /// Project from a completed `BASEBrainTurnResult`. Sources every input the
    /// result exposes — risk card, permit, brake, budget (runMode), host-gate,
    /// update tickets (→ the BR-007 protected-write proxy), policy lineage
    /// (BR-006), and the identity fields. The 4 hard flags (BR-003/004/005/012)
    /// still default engine-laxer pending their plumbing; `operation` and
    /// `evidenceSufficient` default to the conservative (laxer) values until a
    /// richer signal is threaded (Phase-1c+). Pure + deterministic.
    public static func projectFromResult(
        _ result: BASEBrainTurnResult,
        operation: BASSovereignVerdictEngine.OperationDomain = .pureInference,
        evidenceSufficient: Bool = true
    ) -> BASSovereignTurnObservations {
        // Mirror the coordinator's own protected-write derivation (minus the
        // request-only kill-switch term, whose omission only ever UNDER-sets the
        // flag → engine-laxer → no false `.coordinatorLaxer`).
        let needsProtectedWriteLane =
            result.actionPermit.mode == .delay
            || result.actionPermit.mode == .replace
            || result.updateTickets.contains { $0.requiresReview || $0.conflictFlag }
        return project(
            sessionID: result.runtimeTrace.sessionID,
            turnID: result.thoughtFold.foldID,
            snapshotRef: result.thoughtFold.snapshotRef ?? "",
            policyHash: result.sovereignVerdict?.policyHash ?? "",
            policyLineagePresent: result.policyLineage != nil,
            budgetFrame: result.budgetFrame,
            riskCard: result.riskCard,
            actionPermit: result.actionPermit,
            emergencyBrake: result.emergencyBrake,
            needsProtectedWriteLane: needsProtectedWriteLane,
            quarantineCount: 0,
            operation: operation,
            evidenceSufficient: evidenceSufficient,
            hostGateValue: result.hostGateValue)
    }

    /// Phase-1c opt-in one-call per-turn shadow: project from the result + run
    /// the verifier, taking the coordinator level from the result's own sovereign
    /// verdict. No-op / byte-equal when `verifier` is nil. OBSERVATION-ONLY — a
    /// host turn loop calls this once after the turn; it never halts or mutates.
    @discardableResult
    public static func shadowVerifyResult(
        _ result: BASEBrainTurnResult,
        verifier: BASSovereignTurnVerifier?,
        sink: (@Sendable (BASSovereignTurnVerifierReport) -> Void)? = nil
    ) async -> BASSovereignTurnVerifierReport? {
        guard verifier != nil else { return nil }
        return await runShadowIfEnabled(
            observations: projectFromResult(result),
            coordinatorLevel: result.sovereignVerdict?.verdictLevel,
            verifier: verifier,
            sink: sink)
    }

    /// Host-friendly one-call live shadow that needs ONLY BASHostKit — the host
    /// neither imports nor names any `BASSovereign` type. It constructs a default
    /// verifier internally, runs the shadow from the result, and hands a compact
    /// parity SUMMARY STRING to `sink` (`parity=… engine=… coordinator=…
    /// acceptable=…`). A **no-op** (byte-equal) when `enabled` is false — the
    /// default-OFF path a host gates behind a flag / env var (e.g.
    /// `BAS_SHADOW_PARITY=enabled`). This is the per-turn call a host turn loop
    /// makes to gather ADR-022 §6 parity evidence. OBSERVATION-ONLY: it never
    /// halts and never mutates the turn; acting on `acceptable=false`
    /// (`.coordinatorLaxer`) is the operator's evidence-gated Phase-2 decision.
    public static func shadowVerifyResultWithDefaultEngine(
        _ result: BASEBrainTurnResult,
        enabled: Bool,
        ledgerSeed: String = "shadow-parity",
        sink: (@Sendable (String) -> Void)? = nil
    ) async {
        if let line = await shadowParitySummary(
            result, enabled: enabled, ledgerSeed: ledgerSeed) {
            sink?(line)
        }
    }

    /// Returns a compact parity summary string for one turn, or nil when
    /// `enabled` is false (the no-op / byte-equal path). Host-friendly: needs
    /// ONLY BASHostKit — the per-turn evidence one-liner a host turn loop uses
    /// (`if let line = await shadowParitySummary(result, enabled: flag) { log(line) }`).
    /// OBSERVATION-ONLY.
    public static func shadowParitySummary(
        _ result: BASEBrainTurnResult,
        enabled: Bool,
        ledgerSeed: String = "shadow-parity"
    ) async -> String? {
        guard enabled else { return nil }   // OFF → no-op → byte-equal
        let verifier = BASSovereignTurnVerifier(
            engine: BASSovereignVerdictEngine(ledger: .withSeed(ledgerSeed)))
        guard let report = await shadowVerifyResult(result, verifier: verifier)
        else { return nil }
        return "parity=\(report.parity.rawValue) "
            + "engine=\(report.engineVerdict.verdictLevel.rawValue) "
            + "coordinator=\(report.coordinatorLevel?.rawValue ?? "nil") "
            + "acceptable=\(report.isAcceptable)"
    }
}
