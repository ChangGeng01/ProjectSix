import Foundation
import BASRuntimeCore

// MARK: - Update-ticket observation primitives
//
// M58 — L13 进化编案 Phase 1 seed: typed per-ticket evolution
// observation model.
//
// L13 is the evolution-candidate surface — the place where a
// completed turn proposes changes (memory writes, host
// constitution edits, new rules) that the sovereign layer (L14)
// will later judge and either promote or reject. Before M58 those
// proposals were implicit in the raw `BASUpdateTicket` list. This
// file lands the additive primitives so an observer pipeline can
// emit typed per-ticket signals that the L14 surface can
// reconcile with whatever ticket governance + rollout actually
// produced.
//
// Design mirrors M22/M23/M24/M25/M26/M27 on purpose: the L14
// reconciler reads one shape across L6/L7/L9/L10/L11/L12/L13.
//
// Design principles:
//   1. Immutability — every reading is a value; a bundle is
//      frozen once emitted.
//   2. Typed shape + kind — no free-form strings; two sealed
//      enums.
//   3. Subject-addressable — every observation carries a
//      subjectID (the ticketID the signal pertains to) so the
//      L14 surface can group signals per subject.
//   4. Budget-aware — per-signal L1 cost with clamped totalCost.
//      Conflict (reconciliation required) is the most expensive;
//      bare submission is the cheapest.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.

/// A categorical summary of what an update ticket is about.
/// Every observation on a given ticket carries the same shape.
public enum BASUpdateTicketShape:
    String, Sendable, Codable, CaseIterable
{
    /// The ticket only proposes a memory write — no host-profile
    /// mutation and no new rule.
    case memoryWrite
    /// The ticket proposes a change to the host constitution
    /// (via `resolvedHostChangeCandidate`) and nothing else.
    case hostChange
    /// The ticket proposes a new rule candidate and nothing else.
    case ruleCandidate
    /// The ticket proposes at least two of the above three kinds
    /// of mutation in the same breath — the reconciler must
    /// cross-check them before any one promotes.
    case composite
    /// The ticket proposes no mutation at all. It exists purely
    /// because the evolution service flagged the turn for review
    /// (`requiresReview == true` or `conflictFlag == true`).
    case reviewOnly
}

/// The six upstream signals an update-ticket observer pipeline
/// can emit. Each pertains to exactly one ticket (identified by
/// the `subjectID` field on the observation).
public enum BASUpdateTicketSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// Baseline — this ticket was submitted by the evolution
    /// service. Always emitted exactly once per ticket.
    case submission
    /// The ticket proposes a host-constitution change candidate.
    case hostChangeProposed
    /// The ticket proposes a memory write.
    case memoryWriteProposed
    /// The ticket proposes a new rule candidate reference.
    case ruleCandidateProposed
    /// The ticket has its `conflictFlag` set — governance
    /// flagged a reconciliation requirement before promotion.
    case conflictDetected
    /// The ticket requires human review before promotion
    /// (`requiresReview == true`).
    case reviewRequired
}

/// A single typed update-ticket observation. Salience and
/// confidence are in [0, 1]; content is opaque to the transport
/// but carries the signal-specific payload (change type / memory
/// suggestion fragment / conflict reason). `subjectID` is the
/// ticketID the observation pertains to; multiple observations
/// share a subjectID when the ticket carries multiple mutation
/// kinds.
public struct BASUpdateTicketObservation:
    Sendable, Equatable, Codable
{
    public let kind: BASUpdateTicketSignalKind
    public let shape: BASUpdateTicketShape
    public let subjectID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASUpdateTicketSignalKind,
        shape: BASUpdateTicketShape,
        subjectID: String,
        salience: Double,
        confidence: Double,
        content: String,
        observedAt: Date
    ) {
        self.kind = kind
        self.shape = shape
        self.subjectID = subjectID
        self.salience = Self.clamp(salience)
        self.confidence = Self.clamp(confidence)
        self.content = content
        self.observedAt = observedAt
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// A bundle of update-ticket observations emitted in one turn.
/// chapter 四百五 / M986:adopts `BASBundleProtocol`。
public struct BASUpdateTicketObservationBundle:
    Sendable, Equatable, Codable, BASBundleProtocol
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASUpdateTicketObservation]
    public let emittedAt: Date

    /// chapter 四百五 / M986:`BASBundleProtocol` synthesized
    /// accessors。Stable bundleID derived from turnID。
    public var bundleID: String {
        "update-ticket-observation-bundle:\(turnID)"
    }

    public var schemaVersion: String { "1.0.0" }

    public var recordedAt: Date { emittedAt }


    public init(
        turnID: String,
        sessionID: String,
        observations: [BASUpdateTicketObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASUpdateTicketSignalKind
    ) -> [BASUpdateTicketObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Observations for a given shape, across all kinds, in
    /// emission order.
    public func observations(
        forShape shape: BASUpdateTicketShape
    ) -> [BASUpdateTicketObservation] {
        observations.filter { $0.shape == shape }
    }

    /// Observations for a given subject, across all shapes and
    /// kinds, in emission order.
    public func observations(
        forSubject subjectID: String
    ) -> [BASUpdateTicketObservation] {
        observations.filter { $0.subjectID == subjectID }
    }

    /// True iff at least one submission observation was emitted.
    /// A bundle with zero submissions is structurally empty —
    /// the turn produced no evolution tickets.
    public var hasAnySubmission: Bool {
        observations.contains { $0.kind == .submission }
    }

    /// True iff at least one ticket proposed a mutation (host
    /// change, memory write, or rule candidate). A bundle where
    /// every ticket is `reviewOnly` returns false — those tickets
    /// exist to flag a turn for human review without proposing a
    /// change to act on.
    public var hasAnyMutationProposal: Bool {
        observations.contains {
            $0.kind == .hostChangeProposed
                || $0.kind == .memoryWriteProposed
                || $0.kind == .ruleCandidateProposed
        }
    }

    /// True iff any ticket in the bundle flagged a conflict. The
    /// L14 audit surface treats this as a reconciliation signal.
    public var hasAnyConflict: Bool {
        observations.contains { $0.kind == .conflictDetected }
    }

    /// True iff any ticket in the bundle requires human review.
    public var hasAnyReviewRequirement: Bool {
        observations.contains { $0.kind == .reviewRequired }
    }

    /// True iff the bundle carries at least a submission — the
    /// minimum signal set that proves L13 actually emitted a
    /// ticket this turn. An empty bundle (no tickets) returns
    /// false; that is the legitimate "no-evolution turn" signal.
    public var hasCoreSignalCoverage: Bool {
        hasAnySubmission
    }

    /// Distinct subject IDs that appear anywhere in the bundle,
    /// first-seen order preserved. For an L13 bundle this is the
    /// set of ticketIDs observed this turn.
    public var subjectIDs: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for obs in observations
        where seen.insert(obs.subjectID).inserted {
            ordered.append(obs.subjectID)
        }
        return ordered
    }
}

// MARK: - Budget

/// Pure lookup: what does each update-ticket signal cost the L1
/// wake budget? Values are weights in abstract budget units
/// (0.0–1.0). Conflict is the most expensive — it forces a
/// reconciliation pass. Submission is the cheapest — a bare
/// submission with no mutation claims is nearly free to audit.
public enum BASUpdateTicketObservationBudget {
    public static let signalCost:
        [BASUpdateTicketSignalKind: Double] = [
            .submission: 0.10,
            .hostChangeProposed: 0.20,
            .memoryWriteProposed: 0.15,
            .ruleCandidateProposed: 0.15,
            .conflictDetected: 0.25,
            .reviewRequired: 0.15
        ]

    public static func cost(
        for kind: BASUpdateTicketSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASUpdateTicketObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent update-ticket
/// observation bundles so the L14 audit surface (and integration
/// tests) can inspect what L13 emitted across a session. 128
/// entries covers any realistic turn stream without unbounded
/// growth.
public actor BASUpdateTicketObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASUpdateTicketObservationBundle] = []

    public init(
        capacity: Int =
            BASUpdateTicketObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASUpdateTicketObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot() -> [BASUpdateTicketObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASUpdateTicketObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASUpdateTicketObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
