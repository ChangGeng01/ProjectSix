import Foundation
import BASObservability

// MARK: - M58 main-chain derivation from the turn's finalized
//         `[BASUpdateTicket]` list
//
// M58 graduates the L13 evolution surface from raw ticket list to
// main-chain load-bearing observation output. The derivation lives
// in BASOrchestration (next to the rest of the observation family)
// and imports BASObservability to read `BASUpdateTicket`. This is
// the first BASOrchestration → BASObservability edge; it is safe
// because BASObservability does not import BASOrchestration, so
// no cycle.
//
// The derive function is a pure value transform:
//   - No I/O, no actor hop.
//   - Deterministic for the same (tickets, turnID, sessionID,
//     emittedAt) tuple.
//   - Coherent-by-construction with the governed ticket list: every
//     signal references fields the coordinator has already sealed
//     before calling `derive`.
//
// Consumers:
//   - `EBrainRuntimeCoordinator.run(request:)` calls
//     `thoughtFrame.withDerivedUpdateTicketObservationBundle(...)`
//     right after `evolutionGovernance.updateTickets` is assigned.
//   - The L14 audit surface reads
//     `BASThoughtFrame.updateTicketObservationBundle` to reconcile
//     "what L13 claimed about ticket T" against "what ticket T
//     actually proposed and whether governance accepted it".
//   - M32's L13 coverage projection reads `hasCoreSignalCoverage`
//     (= has `.submission`) from the derived bundle.

extension BASUpdateTicketObservationBundle {
    /// M58 — Derive an L13 update-ticket observation bundle from
    /// the turn's finalized `[BASUpdateTicket]` list. The derivation
    /// is deterministic: for the same input (tickets, turnID,
    /// sessionID, emittedAt) it produces the same bundle
    /// byte-for-byte. No I/O, no actor hop.
    ///
    /// Primary path: tickets non-empty → iterate in source order.
    /// Each ticket emits one submission signal plus additional
    /// signals per mutation-kind it carries:
    ///   - `.submission`            always — subjectID =
    ///                               ticketID, salience derived
    ///                               from the ticket's `confidence`,
    ///                               shape classified from the
    ///                               ticket's mutation footprint.
    ///   - `.hostChangeProposed`    gated on `resolvedHostChangeCandidate`
    ///                               — content carries changeType /
    ///                               proposedDelta fragments.
    ///   - `.memoryWriteProposed`   gated on non-empty
    ///                               `memoryWriteSuggestion` —
    ///                               content carries a length-bounded
    ///                               preview of the suggestion.
    ///   - `.ruleCandidateProposed` gated on non-empty
    ///                               `ruleCandidateRef` — content
    ///                               carries the reference.
    ///   - `.conflictDetected`      gated on `conflictFlag == true`
    ///                               — salience 1.0, highest budget
    ///                               cost.
    ///   - `.reviewRequired`        gated on `requiresReview == true`
    ///                               — salience 0.85.
    ///
    /// Empty path: tickets empty → return a bundle with zero
    /// observations. This is the legitimate "no-evolution turn"
    /// signal. `hasCoreSignalCoverage == false` on this path —
    /// the L14 audit surface interprets that as "no evolution
    /// evidence", NOT as a coverage gap.
    ///
    /// DUPLICATE-ticketID CONTRACT: upstream can (pathologically)
    /// produce two `BASUpdateTicket` instances with the same
    /// `ticketID`. This function does NOT dedup — it emits the
    /// per-ticket signals for each, preserving ticket order. The
    /// `subjectIDs` helper on the resulting bundle uses first-seen
    /// dedup which is the intended coverage semantics (one subject
    /// listed once even when observed twice).
    public static func derive(
        fromUpdateTickets tickets: [BASUpdateTicket],
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASUpdateTicketObservationBundle {
        var observations: [BASUpdateTicketObservation] = []

        for ticket in tickets {
            let shape = classifyShape(of: ticket)
            let trimmedMemoryWrite = ticket.memoryWriteSuggestion?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let hasMemoryWrite =
                (trimmedMemoryWrite?.isEmpty == false)
            let hostChange = ticket.resolvedHostChangeCandidate
            let trimmedRuleRef = ticket.ruleCandidateRef?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let hasRuleCandidate =
                (trimmedRuleRef?.isEmpty == false)

            // Submission — always emitted, one per ticket.
            // Salience ≈ confidence so downstream filters can
            // prioritize high-confidence proposals; confidence
            // reflects the ticket's own confidence, clamped with
            // a floor of 0.5 (submissions are always observably
            // true even if the ticket is low-confidence, but
            // zero is never meaningful).
            let submissionConfidence =
                max(0.5, ticket.confidence)
            observations.append(BASUpdateTicketObservation(
                kind: .submission,
                shape: shape,
                subjectID: ticket.ticketID,
                salience: ticket.confidence,
                confidence: submissionConfidence,
                content:
                    "l13.submission.ticket:"
                    + ticket.ticketID
                    + ".shape:" + shape.rawValue
                    + ".confidence:"
                    + formatFraction(ticket.confidence),
                observedAt: emittedAt
            ))

            // Host-change proposal.
            if let hostChange {
                observations.append(BASUpdateTicketObservation(
                    kind: .hostChangeProposed,
                    shape: shape,
                    subjectID: ticket.ticketID,
                    salience: 0.90,
                    confidence: max(0.5, hostChange.confidence),
                    content:
                        "l13.host-change.type:"
                        + hostChange.changeType
                        + ".candidate:" + hostChange.candidateID
                        + ".delta-count:"
                        + String(hostChange.proposedDelta.count)
                        + ".approval:" + hostChange.approvalState,
                    observedAt: emittedAt
                ))
            }

            // Memory-write proposal.
            if let trimmedMemoryWrite, hasMemoryWrite {
                observations.append(BASUpdateTicketObservation(
                    kind: .memoryWriteProposed,
                    shape: shape,
                    subjectID: ticket.ticketID,
                    salience: 0.75,
                    confidence: submissionConfidence,
                    content:
                        "l13.memory-write.len:"
                        + String(trimmedMemoryWrite.count)
                        + ".preview:"
                        + truncated(
                            trimmedMemoryWrite,
                            maxLength: 40),
                    observedAt: emittedAt
                ))
            }

            // Rule-candidate proposal.
            if let trimmedRuleRef, hasRuleCandidate {
                observations.append(BASUpdateTicketObservation(
                    kind: .ruleCandidateProposed,
                    shape: shape,
                    subjectID: ticket.ticketID,
                    salience: 0.75,
                    confidence: submissionConfidence,
                    content:
                        "l13.rule-candidate.ref:"
                        + trimmedRuleRef,
                    observedAt: emittedAt
                ))
            }

            // Conflict detection — highest cost, L14 audit target.
            if ticket.conflictFlag {
                observations.append(BASUpdateTicketObservation(
                    kind: .conflictDetected,
                    shape: shape,
                    subjectID: ticket.ticketID,
                    salience: 1.0,
                    confidence: 1.0,
                    content:
                        "l13.conflict.ticket:" + ticket.ticketID,
                    observedAt: emittedAt
                ))
            }

            // Review requirement.
            if ticket.requiresReview {
                observations.append(BASUpdateTicketObservation(
                    kind: .reviewRequired,
                    shape: shape,
                    subjectID: ticket.ticketID,
                    salience: 0.85,
                    confidence: 1.0,
                    content:
                        "l13.review.ticket:" + ticket.ticketID
                        + ".conflict:"
                        + String(ticket.conflictFlag),
                    observedAt: emittedAt
                ))
            }
        }

        return BASUpdateTicketObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            observations: observations,
            emittedAt: emittedAt
        )
    }
}

// MARK: - Shape classification
//
// Every observation on a given ticket carries the same shape —
// it's a ticket-level categorical summary, not a per-signal one.
// Classification rules:
//   - No mutation of any kind → `.reviewOnly` (the ticket exists
//     purely to flag the turn for review).
//   - Exactly one mutation kind → that kind (`.hostChange` /
//     `.memoryWrite` / `.ruleCandidate`).
//   - Two or more mutation kinds → `.composite` (the L14 surface
//     must cross-check before promoting any one).
fileprivate func classifyShape(
    of ticket: BASUpdateTicket
) -> BASUpdateTicketShape {
    let hasHostChange =
        ticket.resolvedHostChangeCandidate != nil
    let trimmedMemoryWrite = ticket.memoryWriteSuggestion?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let hasMemoryWrite = (trimmedMemoryWrite?.isEmpty == false)
    let trimmedRuleRef = ticket.ruleCandidateRef?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let hasRuleCandidate = (trimmedRuleRef?.isEmpty == false)

    var mutationCount = 0
    if hasHostChange { mutationCount += 1 }
    if hasMemoryWrite { mutationCount += 1 }
    if hasRuleCandidate { mutationCount += 1 }

    guard mutationCount > 0 else { return .reviewOnly }
    if mutationCount > 1 { return .composite }

    if hasHostChange { return .hostChange }
    if hasMemoryWrite { return .memoryWrite }
    // hasRuleCandidate — by elimination.
    return .ruleCandidate
}

// MARK: - Content helpers

/// Truncate a string to at most `maxLength` characters without
/// breaking grapheme boundaries, appending an ellipsis sentinel
/// when truncation occurred. Used only for observation content
/// previews — downstream consumers treat content as opaque.
fileprivate func truncated(
    _ string: String,
    maxLength: Int
) -> String {
    guard string.count > maxLength else { return string }
    let prefix = string.prefix(max(0, maxLength))
    return prefix + "…"
}

/// Format a fractional value in [0, 1] as a 2-decimal string so
/// content fields are deterministic across locales.
fileprivate func formatFraction(_ value: Double) -> String {
    let clamped = min(1, max(0, value))
    let scaled = Int((clamped * 100).rounded())
    let padded = scaled < 10 ? "0\(scaled)" : "\(scaled)"
    return "0." + padded
}
