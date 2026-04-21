import Foundation
import BASRuntimeCore

// MARK: - World-prior observation primitives
//
// M30 — L4 Phase 1 seed: typed per-template world-prior observation
// model.
//
// L4 is the world-knowledge layer: causal templates, counterfactual
// seeds, boundary bedrock, domain bridges, evidence grammar. Before
// M30, the signals upstream of a `BASWorldPriorRiskAssessment` were
// implicit — you could see which template got matched in the final
// assessment, but not which templates were *tried*, which
// counterfactuals were seeded, which bedrock axioms were consulted,
// which cross-domain bridges were crossed. This file lands the
// additive primitives so an observer pipeline can emit *individual*
// typed world-prior signals per template before the assessment
// folds them into a final verdict.
//
// The primitives are additive — `BASWorldPriorVault`,
// `BASWorldPriorRiskAssessment`, `BASWorldPriorCounterfactualSeeder`,
// and every consumer path is untouched. A later milestone will fold
// the bundle into the L14 audit surface so an auditor can reconcile
// "what the world-prior observer claimed for template T" against
// "what the assessment for template T actually used".
//
// Design mirrors M22/M23/M24/M25/M26/M27/M28 on purpose: the L14
// reconciler reads one shape across L6/L7/L9/L10/L11/L12/L13 and now
// L4.
//
// Design principles:
//   1. Immutability — every reading is a value; a bundle is frozen
//      once emitted.
//   2. Typed signal kinds — no free-form strings; sealed enum.
//   3. Template-addressable — every observation carries a templateID
//      so the L14 surface can group signals per world-prior source
//      without string-parsing the content field.
//   4. Budget-aware — per-signal L1 cost with clamped totalCost.
//      Counterfactual seeding (branch synthesis against a prior)
//      costs more than a routine template match.
//   5. Evidence-aware — every observation carries the evidence level
//      of the underlying prior, so downstream audit can propagate
//      uncertainty without re-querying the vault.
//   6. Auditable — append-only ring actor ledger keyed by turn and
//      session.

/// The six upstream signals a world-prior observer pipeline can emit
/// for a single template/prior.
public enum BASWorldPriorSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// A causal template from the vault was matched against the
    /// turn's situation.
    case templateMatched
    /// A counterfactual branch was seeded from this template.
    case counterfactualSeeded
    /// A boundary bedrock axiom was consulted (and, implicitly, not
    /// overridden by L5).
    case boundaryBedrockConsulted
    /// A cross-domain bridge carried structure from one domain into
    /// another — analogy / isomorphism application.
    case domainBridgeCrossed
    /// Evidence-level changed for this template during the turn
    /// (widening or narrowing of uncertainty).
    case evidenceRevised
    /// A contradiction was detected between the template's prior
    /// and the turn's evidence. Two axiomatic claims colliding is
    /// the spec-level "must surface" case.
    case priorContradiction
}

/// A single typed world-prior observation. Salience and confidence
/// are in [0, 1]; content is opaque to the transport but carries
/// the signal-specific payload (match rationale, bridge mapping,
/// contradiction details). `templateID` identifies which causal
/// template / bedrock axiom / bridge / counterfactual seed this
/// observation pertains to; multiple observations may share a
/// templateID. `evidenceLevel` carries the evidence grammar rung
/// the underlying prior sits on, so downstream audit propagates
/// uncertainty without re-querying the vault.
public struct BASWorldPriorObservation:
    Sendable, Equatable, Codable
{
    public let kind: BASWorldPriorSignalKind
    public let templateID: String
    public let evidenceLevel: BASWorldPriorEvidenceLevel
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASWorldPriorSignalKind,
        templateID: String,
        evidenceLevel: BASWorldPriorEvidenceLevel,
        salience: Double,
        confidence: Double,
        content: String,
        observedAt: Date
    ) {
        self.kind = kind
        self.templateID = templateID
        self.evidenceLevel = evidenceLevel
        self.salience = Self.clamp(salience)
        self.confidence = Self.clamp(confidence)
        self.content = content
        self.observedAt = observedAt
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// A bundle of world-prior observations emitted in one turn.
public struct BASWorldPriorObservationBundle:
    Sendable, Equatable, Codable
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASWorldPriorObservation]
    public let emittedAt: Date

    public init(
        turnID: String,
        sessionID: String,
        observations: [BASWorldPriorObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASWorldPriorSignalKind
    ) -> [BASWorldPriorObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Observations for a given template, across all kinds, in
    /// emission order.
    public func observations(
        forTemplate templateID: String
    ) -> [BASWorldPriorObservation] {
        observations.filter { $0.templateID == templateID }
    }

    /// Distinct template IDs that appear anywhere in the bundle,
    /// first-seen order preserved.
    public var templateIDs: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for obs in observations
        where seen.insert(obs.templateID).inserted {
            ordered.append(obs.templateID)
        }
        return ordered
    }

    /// The highest evidence rung reached for a given template
    /// across this turn, or `nil` if the template didn't appear.
    /// L4's uncertainty grammar keeps the higher evidence winning
    /// unless both sides are axiomatic; this accessor surfaces
    /// that top level so audit can reason about confidence without
    /// re-opening the vault.
    public func highestEvidenceLevel(
        forTemplate templateID: String
    ) -> BASWorldPriorEvidenceLevel? {
        observations(forTemplate: templateID)
            .map { $0.evidenceLevel }
            .max()
    }

    /// True iff at least one `priorContradiction` was observed for
    /// the given template — the simplest "audit must surface this"
    /// heuristic. The downstream risk assessor may still choose to
    /// proceed after inspecting the contradiction, but a
    /// default-deny policy can consult this flag.
    public func priorContradiction(
        forTemplate templateID: String
    ) -> Bool {
        observations(forTemplate: templateID)
            .contains { $0.kind == .priorContradiction }
    }

    /// True iff the bundle carries (a) a template match and
    /// (b) either a counterfactual seed or a boundary bedrock
    /// consultation. Without that minimum pair, no world-prior
    /// reasoning actually fired this turn.
    public var hasCoreSignalCoverage: Bool {
        let covered = Set(observations.map { $0.kind })
        guard covered.contains(.templateMatched)
        else { return false }
        return covered.contains(.counterfactualSeeded)
            || covered.contains(.boundaryBedrockConsulted)
    }
}

// MARK: - Budget

/// Pure lookup: what does each world-prior signal cost the L1 wake
/// budget? Values are weights in abstract budget units (0.0–1.0).
/// Counterfactual seeding is the most expensive signal — it runs a
/// branch-synthesis pass against the vault prior.
public enum BASWorldPriorObservationBudget {
    public static let signalCost:
        [BASWorldPriorSignalKind: Double] = [
            .templateMatched: 0.10,
            .counterfactualSeeded: 0.30,
            .boundaryBedrockConsulted: 0.15,
            .domainBridgeCrossed: 0.20,
            .evidenceRevised: 0.10,
            .priorContradiction: 0.20
        ]

    public static func cost(
        for kind: BASWorldPriorSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASWorldPriorObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent world-prior observation
/// bundles so the L14 audit surface (and integration tests) can
/// inspect what L4 emitted across a session. 128 entries covers any
/// realistic turn stream without unbounded growth.
public actor BASWorldPriorObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASWorldPriorObservationBundle] = []

    public init(
        capacity: Int =
            BASWorldPriorObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASWorldPriorObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot() -> [BASWorldPriorObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASWorldPriorObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASWorldPriorObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
