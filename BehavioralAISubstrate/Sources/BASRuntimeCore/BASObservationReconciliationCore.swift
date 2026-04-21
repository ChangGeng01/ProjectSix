import Foundation

// MARK: - Cross-layer observation reconciliation
//
// M31 — unified coverage summary + report scaffold.
//
// M22–M28 and M30 seeded observation primitives for L4 / L6 / L7 /
// L9 / L10 / L11 / L12 / L13, and M21 added an L8 reconciler. Each
// layer's primitive lives in its own module (BASWorldPrior,
// BASOrchestration, BASPolicy, BASMemory) and must stay there —
// BASSovereign (L14) is deliberately isolated to BASRuntimeCore to
// keep the microkernel free of downstream influence.
//
// This file introduces a *pure*, per-layer-agnostic coverage-summary
// value plus a cross-layer report so an L14 reconciler — or any
// audit surface — can compare "what each layer observed" in a
// uniform shape without dragging every observation-producing module
// into a single umbrella. Callers at the edge convert their concrete
// `*ObservationBundle` into a `BASObservationCoverageSummary` and
// feed summaries into `BASObservationReconciliationReport`. The
// bundle types themselves are untouched.
//
// Design principles:
//   1. No upstream coupling — this file lives in BASRuntimeCore and
//      never imports an observation-producing module.
//   2. Typed layer enum — every summary declares which of the 14
//      cognitive layers produced it; the reconciler indexes by
//      layer.
//   3. Value semantics + `Sendable` + `Codable` — summaries and
//      reports can be captured, shipped, and audited.
//   4. Additive only — no existing primitive changes; callers opt in.

/// The 14 cognitive layers the substrate models. Used by the
/// reconciler to tag each coverage summary with its producing layer.
///
/// The raw values are stable strings so that reports serialize
/// deterministically across builds.
///
/// Projection status (M32 wave): 8 of 14 layers carry a
/// `*ObservationBundle` → `BASObservationCoverageSummary`
/// projection — L4 (worldPrior), L6 (presenceEye), L7 (mirrorBlade),
/// L9 (dreamLoop), L10 (triSelfTribunal), L11 (riskClimate),
/// L12 (gentleHand), L13 (evolutionFurnace). The remaining six —
/// L1, L2, L3, L5, L8, L14 — do not yet emit observation primitives
/// in this shape; the reconciler treats a silent layer as either
/// "not expected" or "expected but silent" based on the caller's
/// `expected` list. The enum is complete up front so downstream
/// observation primitives can extend coverage without a breaking
/// change.
public enum BASCognitiveLayer: String, Sendable, Codable, CaseIterable {
    /// L1 — Lease & Life kernel.
    case leaseLife = "L1"
    /// L2 — Neural organ runtime.
    case neuralOrgan = "L2"
    /// L3 — Thought-fold / morph graph.
    case thoughtFold = "L3"
    /// L4 — World prior vault.
    case worldPrior = "L4"
    /// L5 — Host constitution.
    case hostConstitution = "L5"
    /// L6 — Presence eye.
    case presenceEye = "L6"
    /// L7 — Mirror blade / decomposition.
    case mirrorBlade = "L7"
    /// L8 — Hippocampal well / temporal memory field.
    case hippocampalWell = "L8"
    /// L9 — Dream loop / candidate frontier.
    case dreamLoop = "L9"
    /// L10 — Tri-self tribunal.
    case triSelfTribunal = "L10"
    /// L11 — Risk climate / wind gate.
    case riskClimate = "L11"
    /// L12 — Gentle hand / soft hand UI.
    case gentleHand = "L12"
    /// L13 — Evolution furnace / shadow trials.
    case evolutionFurnace = "L13"
    /// L14 — Sovereign microkernel.
    case sovereign = "L14"
}

/// Neutral, per-layer coverage summary. Any concrete
/// `*ObservationBundle` (M22–M28, M30 — and any later primitive that
/// follows the same pattern) can be projected into this shape by the
/// caller. The reconciler then reasons over summaries without having
/// to know the bundle's concrete type.
///
/// Fields correspond 1:1 with what every observation-primitive
/// bundle already exposes:
///   - `turnID` / `sessionID` / `emittedAt` — ledger keys
///   - `totalObservations` — `observations.count`
///   - `distinctSubjectCount` — size of the bundle's typed
///     subject/ticket/template list
///   - `hasCoreSignalCoverage` — the bundle's health heuristic
///   - `budgetTotalCost` — clamped `Budget.totalCost(for:)`
public struct BASObservationCoverageSummary:
    Sendable, Equatable, Codable
{
    public let layer: BASCognitiveLayer
    public let turnID: String
    public let sessionID: String
    public let totalObservations: Int
    public let distinctSubjectCount: Int
    public let hasCoreSignalCoverage: Bool
    public let budgetTotalCost: Double
    public let emittedAt: Date

    public init(
        layer: BASCognitiveLayer,
        turnID: String,
        sessionID: String,
        totalObservations: Int,
        distinctSubjectCount: Int,
        hasCoreSignalCoverage: Bool,
        budgetTotalCost: Double,
        emittedAt: Date
    ) {
        self.layer = layer
        self.turnID = turnID
        self.sessionID = sessionID
        // Defensive floors — an observation pipeline must never
        // report negative counts. Clamp at zero rather than trap.
        self.totalObservations = max(0, totalObservations)
        self.distinctSubjectCount = max(0, distinctSubjectCount)
        self.hasCoreSignalCoverage = hasCoreSignalCoverage
        self.budgetTotalCost = min(1, max(0, budgetTotalCost))
        self.emittedAt = emittedAt
    }
}

/// Aggregate coverage report across several layers for a single
/// turn. The reconciler stores summaries indexed by layer so a
/// duplicate arrival (same layer, new summary) replaces the older
/// reading rather than silently accumulating. Order of insertion
/// is preserved for deterministic iteration.
///
/// Invariants enforced on every construction path (init, appending,
/// decode):
///   - at most one summary per `BASCognitiveLayer`, last-write-wins
///     with first-seen order preserved
///   - every retained summary's `turnID` / `sessionID` matches the
///     report's `turnID` / `sessionID`; mismatched summaries are
///     silently dropped (defensive — a value type should never
///     carry a broken invariant forward)
public struct BASObservationReconciliationReport:
    Sendable, Equatable, Codable
{
    public let turnID: String
    public let sessionID: String
    public let summaries: [BASObservationCoverageSummary]

    public init(
        turnID: String,
        sessionID: String,
        summaries: [BASObservationCoverageSummary] = []
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.summaries = Self.dedupedAndFiltered(
            summaries,
            turnID: turnID,
            sessionID: sessionID)
    }

    /// Custom `Decodable` conformance that re-runs the
    /// dedup + turn/session filter post-decode, closing the invariant
    /// hole where a crafted JSON payload carrying duplicate layers or
    /// cross-turn summaries would otherwise bypass the designated
    /// init.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self)
        let turnID = try container.decode(
            String.self, forKey: .turnID)
        let sessionID = try container.decode(
            String.self, forKey: .sessionID)
        let raw = try container.decode(
            [BASObservationCoverageSummary].self,
            forKey: .summaries)
        self.turnID = turnID
        self.sessionID = sessionID
        self.summaries = Self.dedupedAndFiltered(
            raw,
            turnID: turnID,
            sessionID: sessionID)
    }

    private enum CodingKeys: String, CodingKey {
        case turnID
        case sessionID
        case summaries
    }

    /// Normalize a raw summaries array into the invariant-respecting
    /// form: drop anything whose `turnID` / `sessionID` disagree with
    /// the enclosing report, then deduplicate on layer with
    /// last-write-wins and first-seen order preserved.
    private static func dedupedAndFiltered(
        _ summaries: [BASObservationCoverageSummary],
        turnID: String,
        sessionID: String
    ) -> [BASObservationCoverageSummary] {
        var keptOrder: [BASCognitiveLayer] = []
        var latest: [BASCognitiveLayer: BASObservationCoverageSummary] = [:]
        for s in summaries
        where s.turnID == turnID && s.sessionID == sessionID {
            if latest[s.layer] == nil {
                keptOrder.append(s.layer)
            }
            latest[s.layer] = s
        }
        return keptOrder.compactMap { latest[$0] }
    }

    /// Return a new report with `summary` appended. If the layer
    /// already has a summary it is replaced in place; first-seen
    /// order is preserved (immutable update). If the summary's
    /// `turnID` / `sessionID` do not match the report's, the call is
    /// a no-op — a coverage summary can never cross turn/session
    /// boundaries in a single report.
    public func appending(
        _ summary: BASObservationCoverageSummary
    ) -> BASObservationReconciliationReport {
        guard summary.turnID == turnID,
              summary.sessionID == sessionID
        else { return self }
        var next = summaries
        if let idx = next.firstIndex(where: { $0.layer == summary.layer }) {
            next[idx] = summary
        } else {
            next.append(summary)
        }
        return BASObservationReconciliationReport(
            turnID: turnID,
            sessionID: sessionID,
            summaries: next)
    }

    /// Summary for a given layer, or `nil` if no observation
    /// pipeline has reported for that layer this turn.
    public func summary(
        forLayer layer: BASCognitiveLayer
    ) -> BASObservationCoverageSummary? {
        summaries.first { $0.layer == layer }
    }

    /// Layers that reported a summary this turn, in first-seen
    /// order.
    public var coveredLayers: [BASCognitiveLayer] {
        summaries.map { $0.layer }
    }

    /// Layers (from the provided expectation) that did *not* report
    /// this turn. An L14 reconciler can use this to flag silent
    /// layers — a layer that the coordinator ran but produced no
    /// observations is an audit-worthy anomaly.
    public func missingLayers(
        expected: [BASCognitiveLayer]
    ) -> [BASCognitiveLayer] {
        let covered = Set(summaries.map { $0.layer })
        return expected.filter { !covered.contains($0) }
    }

    /// Layers whose observation pipeline reported but whose
    /// `hasCoreSignalCoverage` is false. These are layers that
    /// spoke this turn but did not produce enough signal to prove
    /// the layer actually acted healthily.
    public var layersWithoutCoreCoverage: [BASCognitiveLayer] {
        summaries
            .filter { !$0.hasCoreSignalCoverage }
            .map { $0.layer }
    }

    /// Total observation count across every reporting layer.
    public var totalObservations: Int {
        summaries.reduce(0) { $0 + $1.totalObservations }
    }

    /// Total L1 wake-budget weight consumed by all reporting
    /// layers, clamped to [0, 1]. Budget clamping is idempotent —
    /// each layer already clamps its own total; summing then
    /// re-clamping lets the reconciler enforce a top-level ceiling.
    public var totalBudgetCost: Double {
        let sum = summaries.reduce(0.0) { $0 + $1.budgetTotalCost }
        return min(1, max(0, sum))
    }

    /// True iff every expected layer reported AND every reporting
    /// layer has core signal coverage. This is the minimum bar an
    /// L14 reconciler should require before declaring a turn
    /// "fully observed".
    public func isFullyObserved(
        expected: [BASCognitiveLayer]
    ) -> Bool {
        guard missingLayers(expected: expected).isEmpty
        else { return false }
        return layersWithoutCoreCoverage.isEmpty
    }
}
