import Foundation
import BASRuntimeCore

// MARK: - Risk observation primitives
//
// M26 — L11 风闸 Phase 1 seed: typed per-dimension risk
// observation model.
//
// L11 composes `BASActionPermit` from many upstream risk
// dimensions — irreversibility, harm potential, consequence
// horizon, novelty, coercion pressure. Before M26, those
// dimensions were implicit in whatever path produced the final
// permit. This file lands the additive primitives so an observer
// pipeline can emit *individual* typed risk readings per intent
// before the gate composes its decision.
//
// The primitives are additive — `BASActionPermit`, `BASRiskVector`,
// and every gate policy path is untouched. A later milestone will
// fold the bundle into permit assembly and stamp it onto the L14
// audit surface so an auditor can reconcile "what the risk
// observer claimed about intent I" against "what the permit
// that blocked / delayed / allowed intent I declared".
//
// Design mirrors M22/M23/M24/M25 on purpose: the L14 reconciler
// reads one shape across L6/L7/L9/L10/L11.
//
// Design principles:
//   1. Immutability — every reading is a value; a bundle is
//      frozen once emitted.
//   2. Typed signal kinds — no free-form strings; sealed enum.
//   3. Intent-addressable — every observation carries an intentID
//      so the L14 surface can group signals per intent without
//      string-parsing the content field.
//   4. Budget-aware — per-signal L1 cost with clamped totalCost.
//      Forward-simulation readings cost more than cheap surface
//      classifications.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.

/// The six upstream signals a risk observer pipeline can emit per
/// intent. Each maps 1:N into a part of the permit the gate
/// ultimately assembles.
public enum BASRiskSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// A raw hazard detection for an intent — the gate's
    /// "something looks dangerous" primitive.
    case hazardReading
    /// How hard the effect of the intent is to undo once applied.
    case irreversibilityReading
    /// Severity of the worst-case harm the intent could cause.
    case harmPotentialReading
    /// How far the consequences propagate forward in time / scope.
    case consequenceHorizonReading
    /// How unfamiliar the intent is versus the session's normal
    /// pattern — novelty tends to widen the gate.
    case noveltyReading
    /// A signal pushing the gate stance — either tighten (block /
    /// delay) or loosen (allow with care). Content carries the
    /// direction and reason.
    case gatePressure
}

/// A single typed risk observation. Salience and confidence are
/// both in [0, 1]; content is opaque to the transport but carries
/// the signal-specific payload (hazard description, reversibility
/// rationale, gate-pressure direction). `intentID` identifies
/// which intent this observation pertains to — multiple
/// observations may share an intentID.
public struct BASRiskObservation: Sendable, Equatable, Codable {
    public let kind: BASRiskSignalKind
    public let intentID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASRiskSignalKind,
        intentID: String,
        salience: Double,
        confidence: Double,
        content: String,
        observedAt: Date
    ) {
        self.kind = kind
        self.intentID = intentID
        self.salience = Self.clamp(salience)
        self.confidence = Self.clamp(confidence)
        self.content = content
        self.observedAt = observedAt
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// A bundle of risk observations emitted in one turn.
/// chapter 四百五 / M987:adopts `BASBundleProtocol`。
public struct BASRiskObservationBundle:
    Sendable, Equatable, Codable, BASBundleProtocol
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASRiskObservation]
    public let emittedAt: Date


    /// chapter 四百五 / M987:`BASBundleProtocol`
    /// synthesized accessors。
    public var bundleID: String {
        "risk-observation-bundle:\(turnID)"
    }

    public var schemaVersion: String { "1.0.0" }

    public var recordedAt: Date { emittedAt }
    public init(
        turnID: String,
        sessionID: String,
        observations: [BASRiskObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASRiskSignalKind
    ) -> [BASRiskObservation] {
        observations.filter { $0.kind == kind }
    }

    /// All observations for a given intent, across all kinds, in
    /// emission order.
    public func observations(
        forIntent intentID: String
    ) -> [BASRiskObservation] {
        observations.filter { $0.intentID == intentID }
    }

    /// Distinct intent IDs that appear anywhere in the bundle,
    /// first-seen order preserved.
    public var intentIDs: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for obs in observations
        where seen.insert(obs.intentID).inserted {
            ordered.append(obs.intentID)
        }
        return ordered
    }

    /// Highest-salience observation for a given kind, or `nil` if
    /// the bundle carries no reading on that signal.
    public func dominantObservation(
        of kind: BASRiskSignalKind
    ) -> BASRiskObservation? {
        observations(of: kind)
            .max(by: { $0.salience < $1.salience })
    }

    /// True iff the bundle carries at least one observation on
    /// each of the three *core* risk dimensions: hazardReading,
    /// irreversibilityReading, harmPotentialReading. These are
    /// the three pillars the gate composes first. A bundle
    /// lacking any of them should trigger a degraded permit mode,
    /// not silent allow.
    public var hasCoreSignalCoverage: Bool {
        let required: Set<BASRiskSignalKind> = [
            .hazardReading,
            .irreversibilityReading,
            .harmPotentialReading]
        let covered = Set(observations.map { $0.kind })
        return required.isSubset(of: covered)
    }

    /// Peak salience across all readings for a given intent — a
    /// rough "how dangerous does this intent look" heuristic.
    /// Returns 0 if no observations pertain to the intent.
    public func peakSalience(
        forIntent intentID: String
    ) -> Double {
        observations(forIntent: intentID)
            .map { $0.salience }
            .max() ?? 0
    }
}

// MARK: - Budget

/// Pure lookup: what does each risk signal cost the L1 wake
/// budget? Values are weights in abstract budget units (0.0–1.0).
/// Forward-simulation readings (consequenceHorizon, harmPotential)
/// are the most expensive; novelty and gate-pressure are cheapest.
public enum BASRiskObservationBudget {
    public static let signalCost:
        [BASRiskSignalKind: Double] = [
            .hazardReading: 0.15,
            .irreversibilityReading: 0.20,
            .harmPotentialReading: 0.25,
            .consequenceHorizonReading: 0.30,
            .noveltyReading: 0.10,
            .gatePressure: 0.10
        ]

    public static func cost(
        for kind: BASRiskSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASRiskObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent risk observation
/// bundles so the L14 audit surface (and integration tests) can
/// inspect what L11 emitted across a session. 128 entries covers
/// any realistic turn stream without unbounded growth.
public actor BASRiskObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASRiskObservationBundle] = []

    public init(
        capacity: Int =
            BASRiskObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(_ bundle: BASRiskObservationBundle) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot() -> [BASRiskObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASRiskObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASRiskObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
