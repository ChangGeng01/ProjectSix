import Foundation
import BASRuntimeCore

// MARK: - Decomposition observation primitives
//
// M23 — L7 镜刃 Phase 1 seed: typed per-signal observation model.
//
// `BASDecomposeFrame` already captures a rich per-turn decomposition
// (fact shards / unknowns / contradictions / pressure vectors /
// manipulation patterns / mirror draft / canonical frame). What is
// missing upstream of it is a primitive way for an observer pipeline
// to emit *individual* decomposition readings before the frame is
// assembled. Before M23, those readings were implicit in whatever
// builder ran inside the coordinator.
//
// This file lands the additive primitives. The frame is untouched;
// no coordinator path is rewired. A later milestone will fold the
// bundle into `BASDecomposeFrame` assembly and stamp the bundle
// onto the L14 audit surface so an auditor can reconcile "what the
// observer pipeline claimed to see" against "what the final frame
// declared".
//
// Design mirrors M22 (L6 presence observation) on purpose: the
// L14 reconciler will want one shape, not two, when it reads
// upstream-vs-frame divergence across L6 and L7.
//
// Design principles:
//   1. Immutability — every observation is a value; a bundle is
//      frozen once emitted.
//   2. Typed signal kinds — no free-form strings; `BASDecomposition
//      SignalKind` is a sealed enum. Adding a kind is an API
//      change that fans out to every consumer, by design.
//   3. Budget-aware — `BASDecompositionObservationBudget` returns
//      the L1 budget cost per signal so callers can decide, before
//      observation, whether they can afford the pass.
//   4. Auditable — `BASDecompositionObservationLedger` is an
//      append-only ring actor. The L14 surface reconciles the
//      ledger against the final `BASDecomposeFrame`.

/// The six upstream signals an L7 observer pipeline can emit.
/// Each maps 1:1 to a part of `BASDecomposeFrame` but at the
/// observation stage — the frame builder consumes many of these
/// into one structured whole.
public enum BASDecompositionSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// A piece of claimed ground truth extracted from the turn
    /// input. Maps to `BASDecomposeFrame.factShards`.
    case factShard
    /// A question / gap / missing premise surfaced during
    /// decomposition. Maps to `BASDecomposeFrame.unknownRecords`.
    case unknown
    /// A detected conflict between two or more claims, goals, or
    /// constraints. Maps to
    /// `BASDecomposeFrame.contradictionRecords`.
    case contradiction
    /// A pressure / urgency / affect reading. Maps to
    /// `BASDecomposeFrame.pressureVectors`.
    case pressure
    /// A manipulation / social-engineering / coercion pattern.
    /// Maps to `BASDecomposeFrame.manipulationPatterns`.
    case manipulation
    /// A provisional restatement of the situation from the
    /// system's point of view. Maps to
    /// `BASDecomposeFrame.mirrorDraft`.
    case mirrorDraft
}

/// A single typed decomposition observation. Salience and
/// confidence are both in [0, 1]; content is opaque to the
/// transport but carries the signal-specific payload the frame
/// builder will consume.
public struct BASDecompositionObservation:
    Sendable, Equatable, Codable
{
    public let kind: BASDecompositionSignalKind
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASDecompositionSignalKind,
        salience: Double,
        confidence: Double,
        content: String,
        observedAt: Date
    ) {
        self.kind = kind
        self.salience = Self.clamp(salience)
        self.confidence = Self.clamp(confidence)
        self.content = content
        self.observedAt = observedAt
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// A bundle of decomposition observations emitted in one turn,
/// keyed by turn ID so the L14 surface can later reconcile the
/// bundle with the `BASDecomposeFrame` that the coordinator
/// eventually produced. The bundle is additive to the turn —
/// callers may emit zero observations on a light turn without
/// breaking any contract.
/// chapter 四百五 / M987:adopts `BASBundleProtocol`。
public struct BASDecompositionObservationBundle:
    Sendable, Equatable, Codable, BASBundleProtocol
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASDecompositionObservation]
    public let emittedAt: Date


    /// chapter 四百五 / M987:`BASBundleProtocol`
    /// synthesized accessors。
    public var bundleID: String {
        "decomposition-observation-bundle:\(turnID)"
    }

    public var schemaVersion: String { "1.0.0" }

    public var recordedAt: Date { emittedAt }
    public init(
        turnID: String,
        sessionID: String,
        observations: [BASDecompositionObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASDecompositionSignalKind
    ) -> [BASDecompositionObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Highest-salience observation for a kind, or `nil` if the
    /// bundle carries no reading on that signal.
    public func dominantObservation(
        of kind: BASDecompositionSignalKind
    ) -> BASDecompositionObservation? {
        observations(of: kind)
            .max(by: { $0.salience < $1.salience })
    }

    /// True iff the bundle carries at least one observation on
    /// each of the three *core* signals — factShard,
    /// contradiction, mirrorDraft. Fact shards provide raw
    /// material; contradictions surface conflicts that drive
    /// adjudication; the mirror draft is the provisional
    /// synthesis. A bundle lacking any of these should trigger a
    /// degraded frame mode, not silent success.
    public var hasCoreSignalCoverage: Bool {
        let required: Set<BASDecompositionSignalKind> = [
            .factShard, .contradiction, .mirrorDraft]
        let covered = Set(observations.map { $0.kind })
        return required.isSubset(of: covered)
    }

    /// Total salience mass of the bundle — useful as a rough
    /// "how much did we see this turn" heuristic.
    public var totalSalience: Double {
        observations.reduce(0.0) { $0 + $1.salience }
    }
}

// MARK: - Budget

/// Pure lookup: what does each decomposition signal cost the L1
/// wake budget? Values are weights in abstract budget units
/// (0.0–1.0); a later milestone will fold `totalCost(for:)` into
/// `BASBudgetFrame.thermalGuardLevel` downgrade logic.
public enum BASDecompositionObservationBudget {
    /// Per-signal cost in abstract budget units. These are not
    /// percentages of anything — they are weights that the budget
    /// frame maps to concrete CPU/time budget in a later wiring
    /// milestone.
    ///
    /// Ordering rationale:
    ///   - factShard (0.10) is cheap string extraction.
    ///   - unknown (0.15) requires gap detection over the frame
    ///     under construction.
    ///   - pressure (0.20) requires affect scoring.
    ///   - contradiction (0.25) requires cross-reference reasoning.
    ///   - manipulation (0.30) requires adversarial-pattern scan.
    ///   - mirrorDraft (0.35) is the most expensive: a provisional
    ///     synthesis pass that must touch every other signal.
    public static let signalCost:
        [BASDecompositionSignalKind: Double] = [
            .factShard: 0.10,
            .unknown: 0.15,
            .pressure: 0.20,
            .contradiction: 0.25,
            .manipulation: 0.30,
            .mirrorDraft: 0.35
        ]

    public static func cost(
        for kind: BASDecompositionSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    /// Total cost of a bundle — sum of per-observation costs.
    /// Clamped to [0, 1] so downstream consumers never see a
    /// pathological bundle that would drive a budget frame
    /// negative.
    public static func totalCost(
        for bundle: BASDecompositionObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent decomposition bundles
/// so the L14 audit surface (and integration tests) can inspect
/// what L7 emitted across a session. 128 entries covers any
/// realistic turn stream without unbounded growth.
public actor BASDecompositionObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASDecompositionObservationBundle] = []

    public init(
        capacity: Int =
            BASDecompositionObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASDecompositionObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot() -> [BASDecompositionObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    /// All bundles for a given session, most-recent-last.
    public func bundles(
        forSession sessionID: String
    ) -> [BASDecompositionObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    /// The bundle with the given turn ID, or `nil` if no such
    /// bundle has been recorded (or it has aged out of the ring).
    public func bundle(
        forTurn turnID: String
    ) -> BASDecompositionObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}

// MARK: - M54 main-chain derivation from a completed BASDecomposeFrame

extension BASDecompositionObservationBundle {
    /// M54 — Derive an L7 observation bundle from a completed
    /// `BASDecomposeFrame`. The derivation is deterministic: for the
    /// same input frame + turn/session + emittedAt it produces the
    /// same bundle byte-for-byte. No I/O, no actor hop.
    ///
    /// Signal mapping (each signal kind is emitted iff the frame
    /// carries structural evidence for it):
    ///   - `.factShard`     emitted iff `factShards` non-empty.
    ///                      salience = `min(1, count * 0.15)` — signal
    ///                      grows with shard count, saturates at ~7.
    ///                      confidence = mean of `certainty` across
    ///                      shards (reflects how confident the frame
    ///                      is in the facts it gathered).
    ///   - `.unknown`       emitted iff `unknownRecords` non-empty.
    ///                      salience = `min(1, count * 0.25)`.
    ///                      confidence = fraction of unknowns with
    ///                      `blocking == true` (blocking unknowns
    ///                      matter structurally; if none blocks, the
    ///                      pipeline is less sure these gaps matter).
    ///   - `.contradiction` emitted iff `contradictionRecords`
    ///                      non-empty. salience = max `severity`.
    ///                      confidence = fraction with
    ///                      `unresolved == true` (resolved
    ///                      contradictions carry less signal weight
    ///                      for this turn).
    ///   - `.pressure`      emitted iff `pressureVectors` non-empty.
    ///                      salience = max `strength`.
    ///                      confidence = mean `authenticity`
    ///                      (manufactured pressure should be lower
    ///                      confidence than authentic pressure).
    ///   - `.manipulation`  emitted iff `manipulationPatterns`
    ///                      non-empty. salience = max pattern
    ///                      `confidence` (confidence in the
    ///                      manipulation pattern IS the primary
    ///                      signal strength).
    ///                      confidence = `min(1, count * 0.33)`
    ///                      (more patterns converging = more
    ///                      confidence the frame saw something).
    ///   - `.mirrorDraft`   emitted iff `mirrorDraft != nil` AND draft
    ///                      has non-empty `summary` or `toneGuard`.
    ///                      salience = mode-dependent (silent 0.3,
    ///                      soft 0.6, hard 0.8) — hard mirror carries
    ///                      more observation weight.
    ///                      confidence = `0.8` if calibrationPoints
    ///                      non-empty else `0.5`.
    ///
    /// Invariants:
    ///   - a completely empty `BASDecomposeFrame` (no facts, no
    ///     unknowns, no contradictions, no pressure, no manipulation,
    ///     no mirror draft) produces a bundle with zero observations.
    ///   - `hasCoreSignalCoverage` (factShard + contradiction +
    ///     mirrorDraft) iff the frame carried evidence for all three.
    ///   - budget cost via `BASDecompositionObservationBudget.totalCost`
    ///     clamps to [0, 1] even at max 6-kind emission (the raw sum
    ///     is 1.35; the clamp prevents runaway).
    public static func derive(
        from decomposeFrame: BASDecomposeFrame,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASDecompositionObservationBundle {
        var observations: [BASDecompositionObservation] = []

        // .factShard — iff fact shards present
        if decomposeFrame.factShards.isEmpty == false {
            let shards = decomposeFrame.factShards
            let salience = min(1.0, Double(shards.count) * 0.15)
            let meanCertainty = shards.reduce(0.0) {
                $0 + $1.certainty
            } / Double(shards.count)
            observations.append(BASDecompositionObservation(
                kind: .factShard,
                salience: salience,
                confidence: meanCertainty,
                content: "shards:\(shards.count)",
                observedAt: emittedAt
            ))
        }

        // .unknown — iff unknown records present
        if decomposeFrame.unknownRecords.isEmpty == false {
            let records = decomposeFrame.unknownRecords
            let salience = min(1.0, Double(records.count) * 0.25)
            let blockingCount = records.filter { $0.blocking }.count
            let confidence =
                Double(blockingCount) / Double(records.count)
            observations.append(BASDecompositionObservation(
                kind: .unknown,
                salience: salience,
                confidence: confidence,
                content: "records:\(records.count)"
                    + "|blocking:\(blockingCount)",
                observedAt: emittedAt
            ))
        }

        // .contradiction — iff contradiction records present
        if decomposeFrame.contradictionRecords.isEmpty == false {
            let records = decomposeFrame.contradictionRecords
            let maxSeverity =
                records.map { $0.severity }.max() ?? 0
            let unresolvedCount = records.filter { $0.unresolved }.count
            let confidence =
                Double(unresolvedCount) / Double(records.count)
            observations.append(BASDecompositionObservation(
                kind: .contradiction,
                salience: maxSeverity,
                confidence: confidence,
                content: "records:\(records.count)"
                    + "|unresolved:\(unresolvedCount)",
                observedAt: emittedAt
            ))
        }

        // .pressure — iff pressure vectors present
        if decomposeFrame.pressureVectors.isEmpty == false {
            let vectors = decomposeFrame.pressureVectors
            let maxStrength =
                vectors.map { $0.strength }.max() ?? 0
            let meanAuthenticity = vectors.reduce(0.0) {
                $0 + $1.authenticity
            } / Double(vectors.count)
            observations.append(BASDecompositionObservation(
                kind: .pressure,
                salience: maxStrength,
                confidence: meanAuthenticity,
                content: "vectors:\(vectors.count)",
                observedAt: emittedAt
            ))
        }

        // .manipulation — iff manipulation patterns present
        if decomposeFrame.manipulationPatterns.isEmpty == false {
            let patterns = decomposeFrame.manipulationPatterns
            let maxConfidence =
                patterns.map { $0.confidence }.max() ?? 0
            let bundleConfidence =
                min(1.0, Double(patterns.count) * 0.33)
            observations.append(BASDecompositionObservation(
                kind: .manipulation,
                salience: maxConfidence,
                confidence: bundleConfidence,
                content: "patterns:\(patterns.count)",
                observedAt: emittedAt
            ))
        }

        // .mirrorDraft — iff draft present with non-empty text
        if let draft = decomposeFrame.mirrorDraft,
           draft.summary.isEmpty == false
            || draft.toneGuard.isEmpty == false {
            let salience: Double
            switch draft.mode {
            case .silent: salience = 0.3
            case .soft:   salience = 0.6
            case .hard:   salience = 0.8
            }
            let confidence =
                draft.calibrationPoints.isEmpty ? 0.5 : 0.8
            observations.append(BASDecompositionObservation(
                kind: .mirrorDraft,
                salience: salience,
                confidence: confidence,
                content: "mode:\(draft.mode.rawValue)"
                    + "|calibrations:"
                    + "\(draft.calibrationPoints.count)",
                observedAt: emittedAt
            ))
        }

        return BASDecompositionObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            observations: observations,
            emittedAt: emittedAt
        )
    }
}
