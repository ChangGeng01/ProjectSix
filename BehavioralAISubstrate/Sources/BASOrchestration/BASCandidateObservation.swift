import Foundation
import BASRuntimeCore

// MARK: - Candidate observation primitives
//
// M24 — L9 梦环 Phase 1 seed: typed per-candidate observation
// model.
//
// `BASCandidateFrontier` already captures the per-turn frontier
// summary that the coordinator emits (dominance order, reversible
// paths, guard paths, diversity, delay). What's missing upstream
// is a primitive way for the dream-loop generator pipeline to
// emit *individual* signals per candidate *before* the frontier is
// assembled. Before M24, those signals were implicit in whatever
// path produced the final frontier struct.
//
// This file lands the additive primitives. The frontier is
// untouched; no coordinator path is rewired. A later milestone
// will fold the bundle into `BASCandidateFrontier` assembly and
// stamp the bundle onto the L14 audit surface so an auditor can
// reconcile "what the dream-loop observer claimed about candidate
// C" against "what the final frontier said about candidate C".
//
// Design mirrors M22/M23 on purpose: the L14 reconciler reads one
// shape across L6/L7/L9, not three.
//
// Design principles:
//   1. Immutability — every observation is a value; a bundle is
//      frozen once emitted.
//   2. Typed signal kinds — no free-form strings; sealed enum.
//   3. Candidate-addressable — every observation carries a
//      candidateID so the L14 surface can group signals per
//      candidate without string-parsing the content field.
//   4. Budget-aware — per-signal L1 cost with clamped totalCost.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.

/// The six upstream signals a dream-loop observer pipeline can
/// emit for a single candidate. Each maps 1:N into a part of
/// `BASCandidateFrontier`, but at the observation stage the
/// frontier builder consumes many of these into one structured
/// whole.
public enum BASCandidateSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// A raw candidate draft surfaced by the generator.
    /// Maps to `BASCandidateFrontier.candidateIDs`.
    case candidate
    /// A dominance / ranking observation. Maps to
    /// `BASCandidateFrontier.dominanceOrder`.
    case dominanceSignal
    /// A reversibility assessment for one candidate. Maps to
    /// `BASCandidateFrontier.reversiblePaths`.
    case reversibilitySignal
    /// A guardian-branch flag — a safety fallback path surfaced
    /// for the frontier. Maps to
    /// `BASCandidateFrontier.guardPaths`.
    case guardianBranch
    /// A diversity score contribution. Maps to
    /// `BASCandidateFrontier.diversityScore`.
    case diversitySignal
    /// A delay recommendation for one candidate. Maps to
    /// `BASCandidateFrontier.delayedPaths`.
    case delayRecommendation
}

/// A single typed candidate observation. Salience and confidence
/// are both in [0, 1]; content is opaque to the transport but
/// carries the signal-specific payload (e.g. reversibility
/// rationale, delay reason). `candidateID` identifies which
/// candidate this observation pertains to — multiple observations
/// may share a candidateID.
public struct BASCandidateObservation:
    Sendable, Equatable, Codable
{
    public let kind: BASCandidateSignalKind
    public let candidateID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASCandidateSignalKind,
        candidateID: String,
        salience: Double,
        confidence: Double,
        content: String,
        observedAt: Date
    ) {
        self.kind = kind
        self.candidateID = candidateID
        self.salience = Self.clamp(salience)
        self.confidence = Self.clamp(confidence)
        self.content = content
        self.observedAt = observedAt
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// A bundle of candidate observations emitted in one turn, keyed
/// by turn ID so the L14 surface can later correlate the bundle
/// with the final `BASCandidateFrontier`. The bundle is additive
/// to the turn — a light turn (no deliberation) can emit zero
/// observations without breaking any contract.
/// chapter 四百五 / M986:adopts `BASBundleProtocol`。
public struct BASCandidateObservationBundle:
    Sendable, Equatable, Codable, BASBundleProtocol
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASCandidateObservation]
    public let emittedAt: Date

    /// chapter 四百五 / M986:`BASBundleProtocol` synthesized
    /// accessors。Stable bundleID derived from turnID。
    public var bundleID: String {
        "candidate-observation-bundle:\(turnID)"
    }

    public var schemaVersion: String { "1.0.0" }

    public var recordedAt: Date { emittedAt }


    public init(
        turnID: String,
        sessionID: String,
        observations: [BASCandidateObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASCandidateSignalKind
    ) -> [BASCandidateObservation] {
        observations.filter { $0.kind == kind }
    }

    /// All observations that pertain to a specific candidate,
    /// across all signal kinds, in emission order.
    public func observations(
        forCandidate candidateID: String
    ) -> [BASCandidateObservation] {
        observations.filter { $0.candidateID == candidateID }
    }

    /// Distinct candidate IDs that appear anywhere in the bundle,
    /// first-seen order preserved.
    public var candidateIDs: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for obs in observations
        where seen.insert(obs.candidateID).inserted {
            ordered.append(obs.candidateID)
        }
        return ordered
    }

    /// Highest-salience observation for a given kind, or `nil` if
    /// the bundle carries no reading on that signal.
    public func dominantObservation(
        of kind: BASCandidateSignalKind
    ) -> BASCandidateObservation? {
        observations(of: kind)
            .max(by: { $0.salience < $1.salience })
    }

    /// True iff the bundle carries at least one observation on
    /// each of the three *core* signals: `candidate`,
    /// `reversibilitySignal`, `guardianBranch`. You need raw
    /// candidates, a reversibility reading to anchor what can be
    /// undone, and a guardian-branch flag to ensure the frontier
    /// has a safety fallback. A bundle lacking any of these
    /// should trigger a degraded frontier mode, not silent
    /// success.
    public var hasCoreSignalCoverage: Bool {
        let required: Set<BASCandidateSignalKind> = [
            .candidate, .reversibilitySignal, .guardianBranch]
        let covered = Set(observations.map { $0.kind })
        return required.isSubset(of: covered)
    }
}

// MARK: - Budget

/// Pure lookup: what does each candidate signal cost the L1 wake
/// budget? Values are weights in abstract budget units (0.0–1.0);
/// a later milestone will fold `totalCost(for:)` into
/// `BASBudgetFrame.thermalGuardLevel` downgrade logic.
public enum BASCandidateObservationBudget {
    /// Per-signal cost. Guardian-branch generation is the most
    /// expensive (safety fallback synthesis); dominance and
    /// diversity signals are cheapest (comparisons over already-
    /// generated candidates).
    public static let signalCost:
        [BASCandidateSignalKind: Double] = [
            .candidate: 0.15,
            .dominanceSignal: 0.10,
            .reversibilitySignal: 0.25,
            .guardianBranch: 0.30,
            .diversitySignal: 0.10,
            .delayRecommendation: 0.10
        ]

    public static func cost(
        for kind: BASCandidateSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    /// Total cost of a bundle — sum of per-observation costs.
    /// Clamped to [0, 1] so downstream consumers never see a
    /// pathological bundle that would drive a budget frame
    /// negative.
    public static func totalCost(
        for bundle: BASCandidateObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent candidate observation
/// bundles so the L14 audit surface (and integration tests) can
/// inspect what L9 emitted across a session. 128 entries covers
/// any realistic turn stream without unbounded growth.
public actor BASCandidateObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASCandidateObservationBundle] = []

    public init(
        capacity: Int =
            BASCandidateObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASCandidateObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot() -> [BASCandidateObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    /// All bundles for a given session, most-recent-last.
    public func bundles(
        forSession sessionID: String
    ) -> [BASCandidateObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    /// The bundle with the given turn ID, or `nil` if no such
    /// bundle has been recorded (or it has aged out of the ring).
    public func bundle(
        forTurn turnID: String
    ) -> BASCandidateObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
