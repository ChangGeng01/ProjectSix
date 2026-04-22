import Foundation

// MARK: - Neural organ registry observation primitives
//
// M64 — L2 神经器官层 main-chain load-bearing observation model.
//
// L2 is the neural organ plane: every turn the coordinator seals a
// `BASNeuralOrganMap` on the thought frame — the turn's canonical
// record of which organs are active (scoutStrip, coreCortex,
// simuRing, criticBlade, riskSpine, permitKnot, memoryCodecRidge,
// hostModulationMesh, toolIntentMesh, consistencyLattice, stubCore,
// tissueRouter), what precision tier each is running at, which
// neural morph is in effect (scout / engage / compare / deepLoop /
// guard / stub / quarantine / rollbackRebuild), which routing policy
// shapes the request, and what sovereign constraints + head
// guarantees are binding this turn.
//
// Before M64 the map was carried on the coordinator and threaded
// into the fold + trace, but its structural content — which organs
// fired, what precision they held, whether a sovereign constraint
// was binding — was never surfaced as typed per-subject evidence.
// This file lands the additive primitives so the coordinator can
// derive a typed per-turn L2 bundle that the L14 audit surface can
// reconcile against what the neural plane actually did on this turn.
//
// Design mirrors M55 / M56 / M57 / M58 / M59 / M60 / M61 / M62 /
// M63 on purpose: the L14 reconciler reads one shape across L1 / L3
// / L4 / L5 / L6 / L7 / L8 / L9 / L10 / L11 / L12 / L13, and the
// coherent-by-construction join uses a single (sessionID, turnID)
// per turn.
//
// Design principles:
//   1. Immutability — every reading is a value; a bundle is
//      frozen once emitted.
//   2. Typed shape + kind — no free-form strings; two sealed
//      enums.
//   3. Subject-addressable — every observation carries a
//      subjectID (the concrete L2 subject the signal pertains to:
//      morph rawValue, organ rawValue, routing policy rawValue,
//      constraint text, or guarantee text).
//   4. Budget-aware — per-signal L2 cost with clamped totalCost.
//      Sovereign constraints and head guarantees are premium cost;
//      baseline map-sealed and per-organ signals are cheap.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.

/// A categorical summary of the L2 neural organ phase at this turn —
/// every observation on a given turn carries the same shape.
public enum BASNeuralOrganShape:
    String, Sendable, Codable, CaseIterable
{
    /// Baseline — normal forward-running morph (scout / engage /
    /// compare / deepLoop). Audit surface's lowest attention phase
    /// for L2.
    case quiet
    /// Morph == `.guard` — protective mode (e.g. boundary conflict
    /// or policy lock is in effect). Intermediate concern.
    case guarded
    /// Morph == `.stub` — minimum safe render only. High concern;
    /// overrides `guarded`.
    case stubOnly
    /// Morph == `.rollbackRebuild` — recovering after a rollback.
    /// High concern; overrides `stubOnly`.
    case rebuilding
    /// Morph == `.quarantine` — organ plane isolated for safety.
    /// Highest concern; overrides every other classification.
    case quarantined
    /// The organ map was not sealed on this turn (coordinator ran
    /// without a neural plane). Mutually exclusive with every other
    /// classification.
    case absent
}

/// The six upstream signals an L2 neural organ observation pipeline
/// can emit. Each pertains to exactly one L2 subject (identified by
/// the `subjectID` field on the observation).
public enum BASNeuralOrganSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// Baseline — the organ map was sealed this turn. Always emitted
    /// when a `BASNeuralOrganMap` exists. subjectID =
    /// `morph.rawValue`.
    case organMapSealed
    /// An organ entry is active in `activeOrgans`. subjectID =
    /// organ.rawValue. Emitted once per entry in array order.
    case organActive
    /// A precision tier is set for an organ in `precisionMap`.
    /// subjectID = organ.rawValue. Emitted once per entry in array
    /// order.
    case precisionSet
    /// A routing policy is in effect. Always emitted when the map
    /// exists. subjectID = `routingPolicy.rawValue`.
    case routingPolicyApplied
    /// A sovereign constraint is binding this turn. subjectID = the
    /// constraint text. Emitted once per `sovereignConstraints`
    /// entry (in array order).
    case sovereignConstraintActive
    /// A head guarantee is active this turn. subjectID = the
    /// guarantee text. Emitted once per `headGuarantees` entry (in
    /// array order).
    case headGuaranteeActive
}

/// A single typed L2 neural organ observation. Salience and
/// confidence are in [0, 1]; content is opaque to the transport but
/// carries the signal-specific payload (morph summary / organ
/// summary / precision summary / policy summary / constraint text /
/// guarantee text). `subjectID` is the concrete L2 subject (morph
/// rawValue, organ rawValue, policy rawValue, constraint, or
/// guarantee).
public struct BASNeuralOrganObservation:
    Sendable, Equatable, Codable
{
    public let kind: BASNeuralOrganSignalKind
    public let shape: BASNeuralOrganShape
    public let subjectID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASNeuralOrganSignalKind,
        shape: BASNeuralOrganShape,
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

/// A bundle of L2 neural organ observations emitted in one turn.
public struct BASNeuralOrganObservationBundle:
    Sendable, Equatable, Codable
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASNeuralOrganObservation]
    public let emittedAt: Date

    public init(
        turnID: String,
        sessionID: String,
        observations: [BASNeuralOrganObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASNeuralOrganSignalKind
    ) -> [BASNeuralOrganObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Observations for a given shape, across all kinds, in
    /// emission order.
    public func observations(
        forShape shape: BASNeuralOrganShape
    ) -> [BASNeuralOrganObservation] {
        observations.filter { $0.shape == shape }
    }

    /// Observations for a given subject, across all shapes and
    /// kinds, in emission order.
    public func observations(
        forSubject subjectID: String
    ) -> [BASNeuralOrganObservation] {
        observations.filter { $0.subjectID == subjectID }
    }

    /// True iff the map-sealed baseline was emitted (always true
    /// for a bundle derived from a real `BASNeuralOrganMap`).
    public var hasMapSealed: Bool {
        observations.contains { $0.kind == .organMapSealed }
    }

    /// True iff at least one per-organ signal fired (organActive).
    public var hasAnyOrganSignal: Bool {
        observations.contains { $0.kind == .organActive }
    }

    /// True iff at least one precision tier entry fired.
    public var hasAnyPrecisionSignal: Bool {
        observations.contains { $0.kind == .precisionSet }
    }

    /// True iff the routing policy signal fired (always true when
    /// map is sealed).
    public var hasRoutingPolicy: Bool {
        observations.contains { $0.kind == .routingPolicyApplied }
    }

    /// True iff at least one sovereign constraint is binding this
    /// turn.
    public var hasAnySovereignConstraint: Bool {
        observations.contains { $0.kind == .sovereignConstraintActive }
    }

    /// True iff at least one head guarantee is active this turn.
    public var hasAnyHeadGuarantee: Bool {
        observations.contains { $0.kind == .headGuaranteeActive }
    }

    /// Core coverage contract: L2 has proof of activity when the
    /// map-sealed baseline is present. Matches the "neural plane
    /// was active" floor the L14 surface expects.
    public var hasCoreSignalCoverage: Bool { hasMapSealed }

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
}

// MARK: - Signal budget

/// Pure lookup: what does each L2 signal cost the L1 wake budget?
/// Values are weights in abstract budget units (0.0–1.0).
/// Sovereign constraints and head guarantees are the most expensive
/// — each represents a binding policy contract on this turn.
/// Baseline map-sealed and per-organ signals are cheap (many active
/// organs per turn is normal); routing policy is cheap (one per
/// turn at most).
public enum BASNeuralOrganSignalBudget {
    public static let signalCost:
        [BASNeuralOrganSignalKind: Double] = [
            .organMapSealed: 0.05,
            .organActive: 0.04,
            .precisionSet: 0.04,
            .routingPolicyApplied: 0.04,
            .sovereignConstraintActive: 0.12,
            .headGuaranteeActive: 0.10
        ]

    public static func cost(
        for kind: BASNeuralOrganSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASNeuralOrganObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent L2 observation bundles
/// so the L14 audit surface (and integration tests) can inspect
/// what L2 emitted across a session. 128 entries covers any
/// realistic turn stream without unbounded growth.
public actor BASNeuralOrganObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASNeuralOrganObservationBundle] = []

    public init(
        capacity: Int =
            BASNeuralOrganObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASNeuralOrganObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot(
    ) -> [BASNeuralOrganObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASNeuralOrganObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASNeuralOrganObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
