import Foundation
import BASRuntimeCore

// MARK: - Shadow-trial observation primitives
//
// M28 — L13 Phase 1 seed: typed per-ticket shadow-trial
// observation model.
//
// L13 models growth: a proposed update is packaged as a ticket,
// run through a shadow trial (sandboxed execution against a
// reference corpus), compared against production for parity, and
// either promoted or quarantined. Before M28, those sub-events
// were implicit in whatever path produced the final promotion
// decision. This file lands the additive primitives so an
// observer pipeline can emit *individual* typed shadow-trial
// signals per ticket before the coordinator synthesizes the
// promotion outcome.
//
// The primitives are additive — `BASUpdateTicket`,
// `BASEvolutionLineageSummary`, and every evolution coordinator
// path is untouched. A later milestone will fold the bundle into
// promotion assembly and stamp it onto the L14 audit surface so
// an auditor can reconcile "what the shadow-trial observer
// claimed about ticket T" against "what the promotion decision
// for ticket T declared".
//
// Design mirrors M22/M23/M24/M25/M26/M27 on purpose: the L14
// reconciler reads one shape across L6/L7/L9/L10/L11/L12/L13.
//
// Design principles:
//   1. Immutability — every reading is a value; a bundle is
//      frozen once emitted.
//   2. Typed signal kinds — no free-form strings; sealed enum.
//   3. Ticket-addressable — every observation carries a ticketID
//      so the L14 surface can group signals per ticket without
//      string-parsing the content field.
//   4. Budget-aware — per-signal L1 cost with clamped totalCost.
//      Actually running a shadow trial costs far more than
//      recording a vote.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.

/// The six upstream signals a shadow-trial observer pipeline can
/// emit for a single ticket.
public enum BASShadowTrialSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// A new update ticket was seeded for consideration.
    case ticketIssued
    /// A shadow trial was executed against a reference corpus.
    case trialRun
    /// Parity between shadow trial and production was verified
    /// within tolerance.
    case parityVerified
    /// A regression versus production was detected in the trial.
    case regressionDetected
    /// A grader voted to promote the ticket.
    case promotionVote
    /// A grader voted to quarantine the ticket.
    case quarantineVote
}

/// A single typed shadow-trial observation. Salience and
/// confidence are in [0, 1]; content is opaque to the transport
/// but carries the signal-specific payload (regression details,
/// parity metrics, vote rationale). `ticketID` identifies which
/// update ticket this observation pertains to; multiple
/// observations may share a ticketID.
public struct BASShadowTrialObservation:
    Sendable, Equatable, Codable
{
    public let kind: BASShadowTrialSignalKind
    public let ticketID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASShadowTrialSignalKind,
        ticketID: String,
        salience: Double,
        confidence: Double,
        content: String,
        observedAt: Date
    ) {
        self.kind = kind
        self.ticketID = ticketID
        self.salience = Self.clamp(salience)
        self.confidence = Self.clamp(confidence)
        self.content = content
        self.observedAt = observedAt
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// A bundle of shadow-trial observations emitted in one turn.
public struct BASShadowTrialObservationBundle:
    Sendable, Equatable, Codable
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASShadowTrialObservation]
    public let emittedAt: Date

    public init(
        turnID: String,
        sessionID: String,
        observations: [BASShadowTrialObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASShadowTrialSignalKind
    ) -> [BASShadowTrialObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Observations for a given ticket, across all kinds, in
    /// emission order.
    public func observations(
        forTicket ticketID: String
    ) -> [BASShadowTrialObservation] {
        observations.filter { $0.ticketID == ticketID }
    }

    /// Distinct ticket IDs that appear anywhere in the bundle,
    /// first-seen order preserved.
    public var ticketIDs: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for obs in observations
        where seen.insert(obs.ticketID).inserted {
            ordered.append(obs.ticketID)
        }
        return ordered
    }

    /// True iff the bundle carries (a) a ticket issuance, (b) a
    /// trial run, and (c) either a parity verification or a
    /// regression detection. Without those three, no promotion
    /// decision should be made on any ticket in the bundle.
    public var hasCoreSignalCoverage: Bool {
        let covered = Set(observations.map { $0.kind })
        guard covered.contains(.ticketIssued),
              covered.contains(.trialRun)
        else { return false }
        return covered.contains(.parityVerified)
            || covered.contains(.regressionDetected)
    }

    /// Net promotion score for a ticket:
    ///   promotionVotes - quarantineVotes
    /// Positive values lean toward promote, negative toward
    /// quarantine, zero toward inconclusive. This is an advisory
    /// heuristic — the L14 coordinator makes the final call.
    public func netPromotionScore(
        forTicket ticketID: String
    ) -> Int {
        let scoped = observations(forTicket: ticketID)
        let promote = scoped.filter { $0.kind == .promotionVote }
            .count
        let quarantine = scoped.filter {
            $0.kind == .quarantineVote
        }.count
        return promote - quarantine
    }

    /// True iff at least one regression was detected for the
    /// given ticket — the simplest "should we block promotion"
    /// heuristic. The coordinator may still choose to promote
    /// after inspecting the regression, but a default-deny
    /// policy can consult this flag.
    public func regressionDetected(
        forTicket ticketID: String
    ) -> Bool {
        observations(forTicket: ticketID)
            .contains { $0.kind == .regressionDetected }
    }
}

// MARK: - Budget

/// Pure lookup: what does each shadow-trial signal cost the L1
/// wake budget? Values are weights in abstract budget units
/// (0.0–1.0). Actually executing a trial is the most expensive
/// signal — it runs a sandboxed pass over a reference corpus.
public enum BASShadowTrialObservationBudget {
    public static let signalCost:
        [BASShadowTrialSignalKind: Double] = [
            .ticketIssued: 0.10,
            .trialRun: 0.40,
            .parityVerified: 0.20,
            .regressionDetected: 0.20,
            .promotionVote: 0.05,
            .quarantineVote: 0.05
        ]

    public static func cost(
        for kind: BASShadowTrialSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASShadowTrialObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent shadow-trial
/// observation bundles so the L14 audit surface (and integration
/// tests) can inspect what L13 emitted across a session. 128
/// entries covers any realistic turn stream without unbounded
/// growth.
public actor BASShadowTrialObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASShadowTrialObservationBundle] = []

    public init(
        capacity: Int =
            BASShadowTrialObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASShadowTrialObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot() -> [BASShadowTrialObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASShadowTrialObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASShadowTrialObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
