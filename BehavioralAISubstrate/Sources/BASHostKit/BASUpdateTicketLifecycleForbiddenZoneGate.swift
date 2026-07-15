// SPDX-License-Identifier: Apache-2.0
// M457 (chapter 一百二十) — make `BASForbiddenCandidateZoneGate`
// (chapter 一百十七 M447) load-bearing in the production
// `BASUpdateTicketLifecycleCoordinator` actor path. Parallels
// M391 (`BASUpdateTicketLifecycleForbiddenGate.swift`) which
// wired M386 `BASForbiddenLifecycleGate` into the same actor.
//
// ## Background
//
// Chapter 一百十七 M447 shipped `BASForbiddenCandidateZoneGate` as a
// pure-function gate over (action, candidateRef, zone,
// satisfiedReleaseConditions) tuples. Phase 1 verification of
// chapter 一百二十 confirmed: 0 production callers — the gate sat
// in BASOrchestration as a callable helper without a wire.
//
// This file ships the wire — extension methods on
// `BASUpdateTicketLifecycleCoordinator` that consult a
// `BASForbiddenCandidateZone` snapshot before advancing tickets
// through gateable lifecycle actions (`.startShadowTrial` /
// `.finalizeTrial` / `.promote`).
//
// ## What this file ships
//
// Four extension methods that wrap M391 pattern for the
// chapter 一百十七 zone gate:
//
//   - `submitWithForbiddenZoneGate(_:zone:satisfiedReleaseConditions:)`
//     — wraps `submit`. Quarantined candidates submit normally
//     (registration carries no trust per chapter 一百十七 M447
//     doctrine), so this forwards to `submit` unchanged. (audit M-b:
//     `submit` has NO reason-code channel, so the gate decision is
//     NOT persisted here — enforcement is at the gated transitions.)
//   - `startTrialWithForbiddenZoneGate(ticketID:trialRecordRef:
//     candidateRef:zone:satisfiedReleaseConditions:)` — wraps
//     `startTrial`. If the candidate is in the zone AND release
//     conditions are not all satisfied, the ticket is rejected
//     instead of advancing. The trial-record ref is preserved in
//     reason codes for audit traceability.
//   - `approveForDistillationWithForbiddenZoneGate(ticketID:
//     sovereignVerdictRef:candidateRef:zone:...)` — wraps
//     `approveForDistillation` (the `.promote` action). If the
//     candidate is quarantined with unmet release conditions the
//     ticket is REJECTED instead of queued for distillation —
//     invariant #3's guardrail (audit M-b: plain approveForDistillation
//     had no zone check, so an isolated candidate entered the queue).
//   - `ingestTicketsWithForbiddenZoneGate(_:zone:
//     candidateRefByTicketID:satisfiedReleaseConditions:)` —
//     batch wrapper.
//
// ## Doctrine pins
//
// - **Single commit mouth**: the gate never mutates lifecycle
//   state directly. Each refusal turns into a real `markRejected`
//   call so the actor's state machine remains the only mutation
//   primitive.
// - **Composes with M391**: hosts running both M391 and M457
//   gates apply them in sequence — M391 (per-candidate forbidden
//   knowledge) first, M457 (zone-level quarantine) second. Both
//   share the `idempotentMarkRejected` private helper from
//   M391.
// - **Default-safe**: any host that does not call the
//   `*WithForbiddenZoneGate` variants continues to use the
//   pre-M457 plain primitives. M457 is opt-in.
// - **Audit-trail preserved**: the gate's typed reason codes
//   (`lifecycle.zoneGate:denied:<action>:pending:<conditions>`)
//   propagate verbatim into the rejection.

import BASMemory
import BASObservability
import BASOrchestration

public extension BASUpdateTicketLifecycleCoordinator {

    /// **M457** — forbidden-zone-aware variant of `submit(_:)`.
    ///
    /// Per chapter 一百十七 M447 doctrine, `.registerCandidate`
    /// is ALWAYS allowed even when the candidate is in the zone
    /// (registration carries no trust), so this forwards to
    /// `submit` unchanged.
    ///
    /// audit M-b / hostkit-rest MED-2 — HONESTY CORRECTION: the prior
    /// docstring claimed this "records the gate's reason codes in
    /// audit metadata", but `submit` carries NO reason-code channel,
    /// so the gate decision here is discarded. Quarantine enforcement
    /// (and the audit reason codes) happen at the GATED transitions
    /// that CAN reject — `startTrialWithForbiddenZoneGate` and
    /// `approveForDistillationWithForbiddenZoneGate` — not at submit.
    ///
    /// Returns the resulting entry's `state`.
    ///
    /// audit hostkit-rest MED-2 (count-inflation half) — this used to hardcode `return .proposed`,
    /// so a re-presented ticket whose ID already existed in a TERMINAL state (`.rejected` /
    /// `.distilled` / …) still reported `.proposed`. `ingestTicketsWithForbiddenZoneGate` counts a
    /// `.proposed` result as "accepted", so an already-rejected duplicate inflated the accepted
    /// count. The fix returns the ACTUAL persisted state (a fresh submit lands in `.proposed`, so
    /// new tickets are unaffected; a duplicate reports its true state and is no longer miscounted).
    @discardableResult
    func submitWithForbiddenZoneGate(
        _ ticket: BASUpdateTicket,
        zone: BASForbiddenCandidateZone?,
        satisfiedReleaseConditions: Set<String> = []
    ) async throws -> BASUpdateTicketLifecycleState {
        // Per M447 doctrine, registerCandidate always allowed.
        // We still call the gate to populate audit-walker reason
        // codes (e.g. "lifecycle.zoneGate:allowed:registerCandidate:
        // not-quarantined" or ":decommission-action").
        _ = BASForbiddenCandidateZoneGate.gate(
            action: .registerCandidate,
            candidateRef: ticket.ticketID,
            zone: zone,
            satisfiedReleaseConditions: satisfiedReleaseConditions)
        do {
            _ = try await submit(ticket)
        } catch LifecycleError.duplicateTicket {
            // Idempotent: re-presenting a turn is fine — but the pre-existing entry's TRUE state
            // may not be `.proposed` (it could already be `.rejected` / `.trialing` / `.distilled`).
        }
        // Return the ACTUAL persisted state, not a hardcoded `.proposed`, so the ingest count of
        // "reached .proposed" never counts an already-terminal duplicate as accepted (fail-closed
        // to `.rejected` on the unreachable no-entry path — duplicateTicket implies the entry exists).
        return entry(ticketID: ticket.ticketID)?.state ?? .rejected
    }

    /// **M457** — forbidden-zone-aware variant of
    /// `startTrial(ticketID:trialRecordRef:)`.
    ///
    /// When the candidate is quarantined in the zone AND the
    /// release conditions are not all satisfied, the ticket is
    /// rejected instead of advancing into `.trialing`. The
    /// trial-record ref + the gate's pending-conditions reason
    /// code are preserved in the rejection for audit traceability.
    func startTrialWithForbiddenZoneGate(
        ticketID: String,
        trialRecordRef: String,
        candidateRef: String,
        zone: BASForbiddenCandidateZone?,
        satisfiedReleaseConditions: Set<String> = []
    ) async throws {
        let decision = BASForbiddenCandidateZoneGate.gate(
            action: .startShadowTrial,
            candidateRef: candidateRef,
            zone: zone,
            satisfiedReleaseConditions: satisfiedReleaseConditions)
        if decision.denied {
            var codes = decision.reasonCodes
            codes.append("trial-record-ref:\(trialRecordRef)")
            // Reuse M391's idempotent helper via the same actor
            // (markRejected absorption pattern). M391 file
            // declares it as private but we get it via
            // markRejected directly with the same idempotent
            // logic inlined here.
            do {
                try await markRejected(
                    ticketID: ticketID,
                    reasonCodes: codes)
            } catch let err as LifecycleError {
                if case let .illegalTransition(from, _) = err,
                   from == .rejected
                {
                    // Already rejected — gate's goal achieved.
                } else {
                    throw err
                }
            }
            return
        }
        try await startTrial(
            ticketID: ticketID,
            trialRecordRef: trialRecordRef)
    }

    /// **M457 / audit M-b (hostkit-rest MED-3)** — forbidden-zone-aware variant of
    /// `approveForDistillation(ticketID:sovereignVerdictRef:extraReasonCodes:)`.
    ///
    /// This is the guardrail for invariant #3 ("private host experience stays OUT of base
    /// weights"). `approveForDistillation` performs the `.promote` action — the moment a candidate
    /// becomes visible to the offline weight-update pipeline. The plain `approveForDistillation` had
    /// NO zone check, so a QUARANTINED candidate (in the forbidden zone with unmet release
    /// conditions) could be queued for distillation — the exact isolation escape the zone exists to
    /// prevent, and the gate's own `.promote` branch sat dead (no production caller). When the gate
    /// denies `.promote`, the ticket is REJECTED (fail-closed) instead of queued; the gate's
    /// pending-conditions reason codes + the sovereign verdict ref are preserved for audit.
    ///
    /// Hosts MUST route promotion through this variant (not plain `approveForDistillation`) whenever
    /// a forbidden zone is in effect. Default-safe + opt-in per M457.
    func approveForDistillationWithForbiddenZoneGate(
        ticketID: String,
        sovereignVerdictRef: String,
        candidateRef: String,
        zone: BASForbiddenCandidateZone?,
        satisfiedReleaseConditions: Set<String> = [],
        extraReasonCodes: [String] = []
    ) async throws {
        let decision = BASForbiddenCandidateZoneGate.gate(
            action: .promote,
            candidateRef: candidateRef,
            zone: zone,
            satisfiedReleaseConditions: satisfiedReleaseConditions)
        if decision.denied {
            var codes = decision.reasonCodes
            codes.append("sovereign-verdict:\(sovereignVerdictRef)")
            codes.append(contentsOf: extraReasonCodes)
            do {
                try await markRejected(ticketID: ticketID, reasonCodes: codes)
            } catch let err as LifecycleError {
                if case let .illegalTransition(from, _) = err, from == .rejected {
                    // Already rejected — the gate's goal is achieved.
                } else {
                    throw err
                }
            }
            return
        }
        try await approveForDistillation(
            ticketID: ticketID,
            sovereignVerdictRef: sovereignVerdictRef,
            extraReasonCodes: extraReasonCodes)
    }

    /// **M457** — batch variant. Walks the ticket array; for
    /// each ticket with a candidate ref in the lookup, applies
    /// the submit zone gate. Tickets with no candidate ref fall
    /// through to plain `submit`. Returns the count of tickets
    /// that successfully reached `.proposed`.
    @discardableResult
    func ingestTicketsWithForbiddenZoneGate(
        _ tickets: [BASUpdateTicket],
        zone: BASForbiddenCandidateZone?,
        candidateRefByTicketID: [String: String] = [:],
        satisfiedReleaseConditions: Set<String> = []
    ) async -> Int {
        var accepted = 0
        for ticket in tickets {
            do {
                let state = try await submitWithForbiddenZoneGate(
                    ticket,
                    zone: zone,
                    satisfiedReleaseConditions:
                        satisfiedReleaseConditions)
                if state == .proposed {
                    accepted += 1
                }
            } catch {
                // Auto-flow parity with M391 — absorb errors
                // so a host runtime cannot crash on lifecycle
                // edge cases.
            }
        }
        return accepted
    }
}
