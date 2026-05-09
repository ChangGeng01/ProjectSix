import Foundation
import BASRuntimeCore

// MARK: - Thought-fold observation primitives
//
// M62 — L3 思纹层 main-chain load-bearing observation model.
//
// L3 is the thought-fold layer: every turn produces a
// `BASThoughtFold` — a canonical compaction of the turn (foldID,
// checksum, compactSlots, candidateSignatures, plus ~12 ark refs
// for snapshots / rollback / resume / integrity / organ packages).
// Before M62 the fold was carried on `BASEBrainTurnResult` and
// threaded into the trace, but its structural anchors — the refs
// that tell the audit surface "this turn is hooked to an anchor
// point" — were never surfaced as typed per-subject evidence. This
// file lands the additive primitives so the coordinator can derive
// a typed per-turn L3 bundle that the L14 audit surface can
// reconcile against what the ark + integrity pipelines actually did
// on this turn.
//
// Design mirrors M55 / M56 / M57 / M58 / M59 / M60 / M61 on purpose:
// the L14 reconciler reads one shape across L1 / L3 / L4 / L5 / L6 /
// L7 / L9 / L10 / L11 / L12 / L13, and the coherent-by-construction
// join uses a single (sessionID, turnID) per turn.
//
// Design principles:
//   1. Immutability — every reading is a value; a bundle is
//      frozen once emitted.
//   2. Typed shape + kind — no free-form strings; two sealed
//      enums.
//   3. Subject-addressable — every observation carries a
//      subjectID (the concrete L3 subject the signal pertains to:
//      foldID, snapshot ref, rollback ref, resume ref, integrity
//      ref, organ package ref, or degradation reason code).
//   4. Budget-aware — per-signal L3 cost with clamped totalCost.
//      Degradation flags and integrity binds carry premium cost;
//      the baseline fold-sealed signal is cheap.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.

/// A categorical summary of the L3 fold phase at this turn —
/// every observation on a given turn carries the same shape.
public enum BASThoughtFoldShape:
    String, Sendable, Codable, CaseIterable
{
    /// Baseline — fold was sealed with normal anchors, no
    /// integrity weave, no degradation. Audit surface's lowest
    /// attention phase for L3.
    case quiet
    /// The fold carries at least one snapshot / rollback / resume
    /// ref — it is hooked into the ark pipeline for replay.
    case snapshotted
    /// The fold carries an integrity-weave ref — it is bound to a
    /// verified integrity frame. Highest-quality anchor phase.
    case integrityBound
    /// The fold has no snapshot / rollback / resume / integrity
    /// refs — it is untethered from the ark. Concerning but legal
    /// (a smoke-test turn or a degraded path). Mutually exclusive
    /// with `snapshotted` / `integrityBound` by construction.
    case orphan
    /// The fold has degradation reason codes — the pipeline
    /// noticed quality problems this turn. Highest-severity L3
    /// phase; overrides every other classification.
    case degraded
}

/// The seven upstream signals an L3 fold observation pipeline can
/// emit. Each pertains to exactly one fold subject (identified by
/// the `subjectID` field on the observation).
public enum BASThoughtFoldSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// Baseline — the fold was sealed this turn. Always emitted
    /// when a `BASThoughtFold` exists. subjectID = foldID.
    case foldSealed
    /// The fold's `snapshotRef` is non-nil. subjectID = snapshotRef.
    /// Emitted iff the ark attached a safe-snapshot pointer.
    case snapshotAnchored
    /// The fold's `rollbackAnchorRef` is non-nil. subjectID =
    /// rollbackAnchorRef. Emitted iff an explicit rollback anchor
    /// was seeded for this turn.
    case rollbackAnchored
    /// The fold's `resumeFrameRef` is non-nil. subjectID =
    /// resumeFrameRef. Emitted iff a resume frame was sealed.
    case resumeAnchored
    /// The fold's `integrityWeaveRef` is non-nil. subjectID =
    /// integrityWeaveRef. Emitted iff the integrity weave
    /// captured a verified frame for this turn.
    case integrityBound
    /// A single organ-package ref was attached. subjectID = the
    /// package ref. Emitted once per `organPackageRefs` entry (in
    /// array order).
    case organPackageBound
    /// A degradation reason code was attached. subjectID = the
    /// code. Emitted once per `degradedReasonCodes` entry (in
    /// array order). Each reason gets its own typed observation
    /// so the L14 surface can group by reason.
    case degradationFlagged
}

/// A single typed L3 fold observation. Salience and confidence are
/// in [0, 1]; content is opaque to the transport but carries the
/// signal-specific payload (fold ID / checksum / ref snippets).
/// `subjectID` is the concrete L3 subject (foldID, ref, or code).
public struct BASThoughtFoldObservation:
    Sendable, Equatable, Codable
{
    public let kind: BASThoughtFoldSignalKind
    public let shape: BASThoughtFoldShape
    public let subjectID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASThoughtFoldSignalKind,
        shape: BASThoughtFoldShape,
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

/// A bundle of L3 fold observations emitted in one turn.
/// chapter 四百五 / M986:adopts `BASBundleProtocol`。
public struct BASThoughtFoldObservationBundle:
    Sendable, Equatable, Codable, BASBundleProtocol
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASThoughtFoldObservation]
    public let emittedAt: Date

    /// chapter 四百五 / M986:`BASBundleProtocol` synthesized
    /// accessors。Stable bundleID derived from turnID。
    public var bundleID: String {
        "thought-fold-observation-bundle:\(turnID)"
    }

    public var schemaVersion: String { "1.0.0" }

    public var recordedAt: Date { emittedAt }


    public init(
        turnID: String,
        sessionID: String,
        observations: [BASThoughtFoldObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASThoughtFoldSignalKind
    ) -> [BASThoughtFoldObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Observations for a given shape, across all kinds, in
    /// emission order.
    public func observations(
        forShape shape: BASThoughtFoldShape
    ) -> [BASThoughtFoldObservation] {
        observations.filter { $0.shape == shape }
    }

    /// Observations for a given subject, across all shapes and
    /// kinds, in emission order.
    public func observations(
        forSubject subjectID: String
    ) -> [BASThoughtFoldObservation] {
        observations.filter { $0.subjectID == subjectID }
    }

    /// True iff the fold-sealed baseline was emitted (always true
    /// for a bundle derived from a real fold).
    public var hasFoldSeal: Bool {
        observations.contains { $0.kind == .foldSealed }
    }

    /// True iff at least one ark anchor (snapshot / rollback /
    /// resume) fired.
    public var hasAnyArkAnchor: Bool {
        observations.contains {
            $0.kind == .snapshotAnchored
                || $0.kind == .rollbackAnchored
                || $0.kind == .resumeAnchored
        }
    }

    /// True iff the integrity-weave binding fired.
    public var hasIntegrityBinding: Bool {
        observations.contains { $0.kind == .integrityBound }
    }

    /// True iff at least one organ package ref was attached.
    public var hasAnyOrganPackageBinding: Bool {
        observations.contains { $0.kind == .organPackageBound }
    }

    /// True iff any degradation reason fired.
    public var hasAnyDegradation: Bool {
        observations.contains { $0.kind == .degradationFlagged }
    }

    /// Core coverage contract: L3 has proof of activity when the
    /// fold-sealed baseline is present. Matches the "fold exists"
    /// floor the L14 surface expects.
    public var hasCoreSignalCoverage: Bool { hasFoldSeal }

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

/// Pure lookup: what does each L3 signal cost the L1 wake budget?
/// Values are weights in abstract budget units (0.0–1.0).
/// Degradation flags are the most expensive — each represents a
/// quality problem that needs handling. Integrity binding is the
/// next most expensive — it guards the strongest anchor. The
/// baseline fold-sealed signal is cheap.
public enum BASThoughtFoldSignalBudget {
    public static let signalCost:
        [BASThoughtFoldSignalKind: Double] = [
            .foldSealed: 0.05,
            .snapshotAnchored: 0.08,
            .rollbackAnchored: 0.08,
            .resumeAnchored: 0.05,
            .integrityBound: 0.12,
            .organPackageBound: 0.03,
            .degradationFlagged: 0.20
        ]

    public static func cost(
        for kind: BASThoughtFoldSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASThoughtFoldObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent L3 observation bundles
/// so the L14 audit surface (and integration tests) can inspect
/// what L3 emitted across a session. 128 entries covers any
/// realistic turn stream without unbounded growth.
public actor BASThoughtFoldObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASThoughtFoldObservationBundle] = []

    public init(
        capacity: Int =
            BASThoughtFoldObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASThoughtFoldObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot(
    ) -> [BASThoughtFoldObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASThoughtFoldObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASThoughtFoldObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
