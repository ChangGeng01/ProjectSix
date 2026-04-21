import Foundation
import BASRuntimeCore

// MARK: - Tribunal observation primitives
//
// M25 — L10 三我庭 Phase 1 seed: typed per-voice tribunal
// observation model.
//
// L10 models deliberation as a three-voice tribunal:
//   - 质我 (baseSelf) — the raw / reactive / honest voice
//   - 律我 (ruleSelf) — the principled / ethical voice
//   - 向我 (aspireSelf) — the goal-directed / growth voice
//
// Each voice can vote on a subject (usually a candidate from the
// L9 frontier), raise objections, offer concessions, and the
// tribunal produces a convergence signal when the three align. A
// rigorous coordinator path is upstream of this file; M25 lands
// the additive primitives so an observer pipeline can emit
// per-voice signals that the L14 surface can reconcile with
// whatever decision L10 eventually produced.
//
// Design mirrors M22/M23/M24 on purpose: the L14 reconciler reads
// one shape across L6/L7/L9/L10.
//
// Design principles:
//   1. Immutability — every observation is a value; a bundle is
//      frozen once emitted.
//   2. Typed voices and signal kinds — no free-form strings;
//      sealed enums.
//   3. Subject-addressable — every observation carries a
//      subjectID (commonly a candidateID from the L9 frontier, but
//      the tribunal can deliberate on any typed subject ID).
//   4. Budget-aware — per-signal L1 cost with clamped totalCost.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.

/// The three voices of the L10 tribunal.
public enum BASTribunalVoice:
    String, Sendable, Codable, CaseIterable
{
    /// 质我 — raw, honest, reactive. Surfaces what the system
    /// actually wants before rules or aspirations weigh in.
    case baseSelf
    /// 律我 — principled. Applies host boundaries, explicit
    /// rules, and safety constraints to the subject.
    case ruleSelf
    /// 向我 — aspirational. Weighs the subject against the
    /// host's long-horizon goals and growth trajectory.
    case aspireSelf
}

/// Disposition a voice can take toward a subject.
public enum BASTribunalDisposition:
    String, Sendable, Codable, CaseIterable
{
    case affirm
    case oppose
    case abstain
}

/// The five upstream signals a tribunal observer pipeline can
/// emit. Each is attributed to one voice and directed at one
/// subject (candidate, decision, etc.).
public enum BASTribunalSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// A typed vote from one voice on one subject.
    case vote
    /// A cross-voice objection — one voice raising a structural
    /// concern a vote alone can't capture.
    case objection
    /// A cross-voice concession — one voice backing down from a
    /// prior stance in light of another voice's argument.
    case concession
    /// A convergence reading — the three voices have aligned on a
    /// subject. Emitted by the tribunal as a whole, not by any
    /// single voice.
    case convergence
    /// A dissent reading — the three voices remain split and the
    /// subject cannot advance without further deliberation.
    case dissent
}

/// A single typed tribunal observation. Salience and confidence
/// are both in [0, 1]; content is opaque to the transport and
/// carries the signal-specific payload (reasoning, objection
/// text, concession rationale). `voice` may be nil for
/// convergence / dissent signals that the tribunal emits as a
/// whole; `disposition` is populated only for `.vote` signals.
public struct BASTribunalObservation: Sendable, Equatable, Codable {
    public let kind: BASTribunalSignalKind
    public let voice: BASTribunalVoice?
    public let disposition: BASTribunalDisposition?
    public let subjectID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASTribunalSignalKind,
        voice: BASTribunalVoice?,
        disposition: BASTribunalDisposition?,
        subjectID: String,
        salience: Double,
        confidence: Double,
        content: String,
        observedAt: Date
    ) {
        self.kind = kind
        self.voice = voice
        self.disposition = disposition
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

/// A bundle of tribunal observations emitted in one turn.
public struct BASTribunalObservationBundle:
    Sendable, Equatable, Codable
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASTribunalObservation]
    public let emittedAt: Date

    public init(
        turnID: String,
        sessionID: String,
        observations: [BASTribunalObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASTribunalSignalKind
    ) -> [BASTribunalObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Observations attributed to a given voice, in emission
    /// order. Convergence / dissent signals (voice == nil) are
    /// never returned by this filter.
    public func observations(
        by voice: BASTribunalVoice
    ) -> [BASTribunalObservation] {
        observations.filter { $0.voice == voice }
    }

    /// Observations directed at a given subject, across all
    /// voices and kinds, in emission order.
    public func observations(
        forSubject subjectID: String
    ) -> [BASTribunalObservation] {
        observations.filter { $0.subjectID == subjectID }
    }

    /// Distinct subject IDs that appear anywhere in the bundle,
    /// first-seen order preserved.
    public var subjectIDs: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for obs in observations
        where seen.insert(obs.subjectID).inserted {
            ordered.append(obs.subjectID)
        }
        return ordered
    }

    /// True iff at least one vote was cast by each of the three
    /// voices. A tribunal with fewer than three voices on record
    /// should degrade, not silently return a majority.
    public var allVoicesSpoke: Bool {
        let voting = observations
            .filter { $0.kind == .vote }
            .compactMap { $0.voice }
        let heard = Set(voting)
        return BASTribunalVoice.allCases
            .allSatisfy { heard.contains($0) }
    }

    /// The latest vote (by emission order) from `voice` on
    /// `subjectID`, or `nil` if that voice never voted on that
    /// subject.
    public func vote(
        by voice: BASTribunalVoice,
        on subjectID: String
    ) -> BASTribunalObservation? {
        observations.last {
            $0.kind == .vote
                && $0.voice == voice
                && $0.subjectID == subjectID
        }
    }

    /// True iff the three voices cast matching dispositions on
    /// the given subject — a structural convergence signal that
    /// the coordinator can read before it emits a
    /// `.convergence` observation of its own.
    public func voicesAgree(on subjectID: String) -> Bool {
        let dispositions = BASTribunalVoice.allCases
            .compactMap { vote(by: $0, on: subjectID)?.disposition }
        guard dispositions.count == BASTribunalVoice.allCases.count
        else { return false }
        return Set(dispositions).count == 1
    }
}

// MARK: - Budget

/// Pure lookup: what does each tribunal signal cost the L1 wake
/// budget? Values are weights in abstract budget units (0.0–1.0).
/// Objections are most expensive (cross-voice synthesis over the
/// full subject state); votes are cheapest.
public enum BASTribunalObservationBudget {
    public static let signalCost:
        [BASTribunalSignalKind: Double] = [
            .vote: 0.10,
            .objection: 0.25,
            .concession: 0.15,
            .convergence: 0.10,
            .dissent: 0.10
        ]

    public static func cost(
        for kind: BASTribunalSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASTribunalObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent tribunal observation
/// bundles so the L14 audit surface (and integration tests) can
/// inspect what L10 emitted across a session. 128 entries covers
/// any realistic turn stream without unbounded growth.
public actor BASTribunalObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASTribunalObservationBundle] = []

    public init(
        capacity: Int =
            BASTribunalObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASTribunalObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot() -> [BASTribunalObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASTribunalObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASTribunalObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
