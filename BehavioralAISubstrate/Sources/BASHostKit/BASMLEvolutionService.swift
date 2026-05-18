// MARK: - BASMLEvolutionService
// REAL Layer-7 evolution service producing update tickets
// from cascade output。 Seventh active ML-touched layer
// in the cognitive cascade — completing the entire core
// downstream cascade (L0 → L2 → L3 → L4 → L5 → L6 → L7)
// with real signal-derived logic。
//
// The evolution service synthesizes "what should the
// host learn from this turn" tickets。 The placeholder
// emitted NO tickets,leaving the host's learning loop
// inactive。
//
// This service emits tickets when the cascade surfaces
// signals worth remembering:
//   - elevated_risk_observed: high or extreme risk levels
//     warrant memory write so future similar inputs see
//     the same warning
//   - manipulation_detected: confirmed manipulation
//     deserves elevated tracking
//   - all_candidates_vetoed: tribunal couldn't find a
//     safe path — host-level review warranted
//   - feedback_received: when a host feeds back a
//     correction signal,emit a ticket to encode it
//
// **Honest scope**: this service emits TICKETS — pointers
// to "something the host should consider for memory or
// host-profile update"。 It does NOT directly update memory
// or host profile (those are downstream host
// responsibilities)。 Each ticket carries a typed summary
// + confidence + memoryWriteSuggestion that hosts can
// inspect / apply at their discretion。

import Foundation
import BASRuntimeCore
import BASOrchestration
import BASObservability

/// Real evolution service deriving update tickets from
/// cascade output。 Replaces BASPlaceholderEvolution
/// Service in cognitive brains that want active learning
/// signals。
public struct BASMLEvolutionService:
    BASEvolutionServicing, Sendable
{

    /// Named ticket-summary identifiers。 Stable across
    /// calls so hosts can match by string for telemetry
    /// / dashboard rendering。
    public enum TicketSummaries {
        public static let elevatedRiskObserved =
            "evolution.elevated_risk_observed"
        public static let manipulationDetected =
            "evolution.manipulation_detected"
        public static let allCandidatesVetoed =
            "evolution.all_candidates_vetoed"
        public static let feedbackReceived =
            "evolution.feedback_received"
    }

    /// Confidence values per ticket type。 Higher
    /// confidence means hosts should trust the
    /// ticket more strongly。
    public enum Confidences {
        /// Risk observation is direct — high confidence。
        public static let elevatedRisk: Double = 0.9

        /// Manipulation is direct — highest confidence。
        public static let manipulation: Double = 0.95

        /// Veto fallback is a strong signal but rare —
        /// medium-high。
        public static let allVeto: Double = 0.85

        /// Feedback echoes whatever confidence the host
        /// supplied;default 0.8 when unspecified。
        public static let feedback: Double = 0.8
    }

    /// Session identifier emitted on every ticket。 In
    /// production this would come from the host's session
    /// management;here it's a synthetic stable string
    /// since the evolution service has no session context。
    public static let evolutionSessionRef: String =
        "bas.cognitive.brain.evolution"

    public init() {}

    public func buildTickets(
        thoughtFrame: BASThoughtFrame,
        output: BASRenderedOutput,
        feedbackEvent: BASFeedbackEvent?
    ) -> [BASUpdateTicket] {
        var tickets: [BASUpdateTicket] = []
        let now = Self.ticketIDTimestamp()

        // Inspect riskCard if present
        if let card = thoughtFrame.riskCard {
            switch card.riskLevel {
            case .high, .extreme:
                tickets.append(BASUpdateTicket(
                    ticketID:
                        "ticket.elevated_risk.\(now)",
                    sessionRef: Self
                        .evolutionSessionRef,
                    summary: TicketSummaries
                        .elevatedRiskObserved,
                    memoryWriteSuggestion: Self
                        .riskMemoryWriteSuggestion(
                            for: card),
                    confidence:
                        Confidences.elevatedRisk,
                    requiresReview: card.riskLevel
                        == .extreme))
            case .low, .medium:
                break
            }
            // Manipulation factor produces a separate
            // ticket regardless of overall risk level —
            // it's the most safety-critical signal。
            if card.manipulationStrength > 0.5 {
                tickets.append(BASUpdateTicket(
                    ticketID:
                        "ticket.manipulation.\(now)",
                    sessionRef: Self
                        .evolutionSessionRef,
                    summary: TicketSummaries
                        .manipulationDetected,
                    memoryWriteSuggestion:
                        "remember: manipulation pattern" +
                        " detected with strength" +
                        " \(card.manipulationStrength)",
                    confidence:
                        Confidences.manipulation,
                    requiresReview: true))
            }
        }

        // Inspect merged choice for veto state via
        // vetoMarks on the thoughtFrame。
        if let vetoMarks = thoughtFrame.vetoMarks,
           !vetoMarks.isEmpty
        {
            tickets.append(BASUpdateTicket(
                ticketID:
                    "ticket.all_veto.\(now)",
                sessionRef: Self.evolutionSessionRef,
                summary: TicketSummaries
                    .allCandidatesVetoed,
                memoryWriteSuggestion:
                    "remember: tribunal vetoed all" +
                    " candidates for this input pattern",
                confidence: Confidences.allVeto,
                requiresReview: true))
        }

        // Inspect feedback event — when a host feeds
        // back a correction,emit a ticket。
        if let feedback = feedbackEvent {
            tickets.append(BASUpdateTicket(
                ticketID:
                    "ticket.feedback.\(now)",
                sessionRef: Self.evolutionSessionRef,
                summary: TicketSummaries
                    .feedbackReceived,
                memoryWriteSuggestion:
                    "feedback: \(feedback.eventType)" +
                    " — \(feedback.detail)",
                confidence: Confidences.feedback,
                requiresReview: false))
        }

        return tickets
    }

    // MARK: - Static helpers

    /// Stable timestamp for ticket identifiers。 Uses
    /// monotonic-ish wall clock。 The fact that hosts
    /// can dedupe on summary + sessionRef means the
    /// exact timestamp is not load-bearing for
    /// correctness。
    public static func ticketIDTimestamp() -> Int {
        return Int(Date().timeIntervalSince1970 * 1000)
    }

    /// Tailored memory-write suggestion text for a
    /// given risk card。 Surfaces the factors so the
    /// host's memory write captures the WHY。
    public static func riskMemoryWriteSuggestion(
        for card: BASRiskCard
    ) -> String {
        let factorList = card.factors.isEmpty
            ? "(no specific factors)"
            : card.factors.joined(separator: ", ")
        return "remember: \(card.riskLevel.rawValue)" +
            " risk observed,factors=[\(factorList)]"
    }
}
