// SPDX-License-Identifier: Apache-2.0
// M391 — make `BASForbiddenLifecycleGate` (M386) load-bearing in the
// production `BASUpdateTicketLifecycleCoordinator` actor path.
//
// Background
// ----------
//
// M386 shipped `BASForbiddenLifecycleGate` as a pure-function gate
// over `BASEvolutionLifecycleAction` — the abstract evolution
// lifecycle vocabulary used by the M333 demo. The production actor
// `BASUpdateTicketLifecycleCoordinator` (in BASObservability) uses
// a distinct vocabulary (`submit` / `startTrial` /
// `markTrialOutcome` / `approveForDistillation` / `markDistilled`
// / `markRejected`). Without a bridge, M386 was a pure helper with
// zero production callers — the most explicit "deferred" item in
// chapter 八十七 (附录 K.2.3).
//
// What this file ships
// --------------------
//
// Three extension methods on `BASUpdateTicketLifecycleCoordinator`
// that wrap the existing primitives with forbidden-gate awareness:
//
//   - `submitWithForbiddenGate(_:forbidden:)` — wraps `submit`. If
//     the paired candidate would refuse `.registerCandidate` per
//     M386, the ticket is submitted (so the lifecycle has a record
//     of it) and immediately rejected via `markRejected` with the
//     gate's reason codes. Hosts running with strict policy see
//     the ticket land in `.rejected` rather than persist as
//     `.proposed` indefinitely.
//   - `startTrialWithForbiddenGate(ticketID:trialRecordRef:forbidden:)`
//     — wraps `startTrial`. If the candidate would refuse
//     `.startShadowTrial` (e.g. `sovereignReviewState == .held` or
//     `shadowTrialPolicy == .none`), the ticket is rejected
//     instead of advancing. The trial-record ref is preserved in
//     the rejection reason codes for audit traceability.
//   - `ingestTurnResultWithForbiddenGate(_:forbiddenByTicketID:)`
//     — wraps `ingestTurnResult`. Walks the turn's update tickets;
//     for each one that has an entry in the forbidden lookup
//     table, applies the submit gate variant; for tickets with no
//     forbidden record, falls through to plain `submit`.
//
// Doctrine pins
// -------------
//
//   - **Single commit mouth**: the gate never mutates lifecycle
//     state directly. Each refusal turns into a real
//     `markRejected` call so the actor's state machine remains
//     the only mutation primitive.
//   - **Default-safe**: any host that does not call the
//     `*WithForbiddenGate` variants continues to use the
//     pre-M391 plain primitives. M391 is opt-in.
//   - **Audit-trail preserved**: the gate's typed reason codes
//     (`lifecycle.gated:forbidden:<reason>`) propagate verbatim
//     into the rejection. The audit ledger then records both the
//     original ticket and its forbidden-driven rejection.
//   - **Idempotent on duplicates**: the underlying actor methods
//     throw `duplicateTicket` / `unknownTicket` errors; this
//     extension absorbs `duplicateTicket` from the wrapped
//     `submit` (the ticket already exists in `.proposed` or
//     `.rejected`), so re-presenting a turn does not crash. Other
//     errors propagate as the underlying methods would.

import BASMemory
import BASObservability

public extension BASUpdateTicketLifecycleCoordinator {

    /// **M391** — forbidden-gate-aware variant of `submit(_:)`.
    ///
    /// When the paired candidate's
    /// `BASForbiddenLifecycleGate.gate(action: .registerCandidate,
    /// candidate:)` returns refused, the ticket is submitted and
    /// then immediately rejected with the gate's reason codes.
    /// When the candidate is `nil` or the gate passes, the ticket
    /// is submitted normally.
    ///
    /// Returns the resulting entry's `state` so the caller can
    /// branch on `.proposed` (passed) vs `.rejected` (gated).
    @discardableResult
    func submitWithForbiddenGate(
        _ ticket: BASUpdateTicket,
        forbidden candidate: BASForbiddenKnowledgeCandidate?
    ) async throws -> BASUpdateTicketLifecycleState {
        let decision = BASForbiddenLifecycleGate.gate(
            action: .registerCandidate,
            candidate: candidate)

        // Submit through the actor's primary mouth either way —
        // the ticket needs a record even if it will be rejected
        // immediately (so the audit trail is contiguous).
        do {
            _ = try await submit(ticket)
        } catch LifecycleError.duplicateTicket {
            // Re-presenting a turn is idempotent; existing entry
            // already covers this ticket. Continue to gate check
            // — if the gate refuses now, we still want to record
            // the rejection on the existing entry.
        }

        if decision.refused {
            // Chapter 九十一 deep-review fix #3 + chapter
            // 九十一.5 honesty correction: absorb the single
            // already-rejected case via the shared helper so
            // both `submitWithForbiddenGate` and
            // `startTrialWithForbiddenGate` reject idempotently.
            try await idempotentMarkRejected(
                ticketID: ticket.ticketID,
                reasonCodes: decision.reasonCodes)
            return .rejected
        }
        return .proposed
    }

    /// **M391** — forbidden-gate-aware variant of
    /// `startTrial(ticketID:trialRecordRef:)`.
    ///
    /// When the paired candidate's
    /// `BASForbiddenLifecycleGate.gate(action: .startShadowTrial,
    /// candidate:)` returns refused, the ticket is rejected
    /// instead of advancing into `.trialing`. The trial-record ref
    /// is preserved in the rejection reason codes so the audit
    /// trail still shows what trial would have been started.
    func startTrialWithForbiddenGate(
        ticketID: String,
        trialRecordRef: String,
        forbidden candidate: BASForbiddenKnowledgeCandidate?
    ) async throws {
        let decision = BASForbiddenLifecycleGate.gate(
            action: .startShadowTrial,
            candidate: candidate)
        if decision.refused {
            var codes = decision.reasonCodes
            codes.append("trial-record-ref:\(trialRecordRef)")
            // Chapter 九十一.5 honesty correction: same
            // idempotent guard as `submitWithForbiddenGate`.
            // Pre-correction `markRejected` here threw
            // `illegalTransition(from: .rejected, _)` when the
            // ticket had already been rejected (concurrent
            // caller / re-presented turn). The shared helper
            // absorbs that single case.
            try await idempotentMarkRejected(
                ticketID: ticketID,
                reasonCodes: codes)
            return
        }
        try await startTrial(
            ticketID: ticketID,
            trialRecordRef: trialRecordRef)
    }

    /// **Chapter 九十一.5 helper** — apply `markRejected` and
    /// absorb the single idempotent-already-rejected error case.
    /// Other illegal-transition errors (terminal `.distilled`
    /// etc.) still propagate so callers see real bugs.
    ///
    /// Doctrine: any-state → `.rejected` is legal *except* from
    /// `.rejected` itself; treating that single transition as
    /// idempotent matches the gate's intent ("end up rejected")
    /// without double-rejecting or surfacing a stale-state error
    /// to the host.
    /// **Chapter 一百三十一 M514**: visibility lifted from
    /// `private` to `internal` so chapter-一百三十一 Counter-Host
    /// Gate extension (`BASUpdateTicketLifecycleCounterHostGate
    /// .swift`) can reuse the same idempotent-rejection helper.
    /// Doctrine unchanged.
    internal func idempotentMarkRejected(
        ticketID: String,
        reasonCodes: [String]
    ) async throws {
        do {
            try await markRejected(
                ticketID: ticketID,
                reasonCodes: reasonCodes)
        } catch let err as LifecycleError {
            let alreadyRejected: Bool = {
                if case let .illegalTransition(from, _) = err,
                   from == .rejected
                {
                    return true
                }
                return false
            }()
            guard alreadyRejected else { throw err }
            // already in `.rejected` — gate's goal achieved.
        }
    }

    /// **M391** — forbidden-gate-aware variant of
    /// `ingestTurn(_:)`.
    ///
    /// Walks the ticket array; for each ticket whose ID appears
    /// in `forbiddenByTicketID`, applies the submit gate variant.
    /// Tickets with no forbidden record fall through to plain
    /// `submit`. Returns the number of tickets that successfully
    /// reached `.proposed` (rejected ones are excluded from the
    /// count so observability metrics distinguish accepted from
    /// gated).
    @discardableResult
    func ingestTicketsWithForbiddenGate(
        _ tickets: [BASUpdateTicket],
        forbiddenByTicketID: [String: BASForbiddenKnowledgeCandidate]
    ) async -> Int {
        var accepted = 0
        for ticket in tickets {
            let forbidden = forbiddenByTicketID[ticket.ticketID]
            do {
                let state = try await submitWithForbiddenGate(
                    ticket, forbidden: forbidden)
                if state == .proposed {
                    accepted += 1
                }
            } catch {
                // Other errors (illegal transition etc.) are
                // absorbed for parity with `ingestTurn` —
                // auto-flow path must not crash a host runtime.
            }
        }
        return accepted
    }

    /// **M391** — forbidden-gate-aware variant of
    /// `ingestTurnResult(_:)`. Convenience wrapper for hosts
    /// already holding a `BASEBrainTurnResult`.
    @discardableResult
    func ingestTurnResultWithForbiddenGate(
        _ turn: BASEBrainTurnResult,
        forbiddenByTicketID: [String: BASForbiddenKnowledgeCandidate]
    ) async -> Int {
        await ingestTicketsWithForbiddenGate(
            turn.updateTickets,
            forbiddenByTicketID: forbiddenByTicketID)
    }
}
