import Foundation
import BASRuntimeCore
import BASMemory

// MARK: - Hippocampal memory observation primitives
//
// M63 — L8 海马层 main-chain load-bearing observation model.
//
// L8 is the hippocampal memory plane: every turn the coordinator
// retrieves a `BASMemoryBundle` from the memory service — the
// working-memory window on this turn, carrying typed
// `BASMemoryAtom`s (hot / warm / cold / relation / routine / rule)
// with per-atom promotion state (candidate / admitted / frozen /
// retired), top-level conflict refs, and an optional
// `BASTemporalMemoryField` that carries the long-life subsurfaces —
// temperature profiles, provenance seals, episode arcs, conflict
// clusters, continuity anchors, replay frames, quarantine records,
// sanctum entries, and forget cascades.
//
// Before M63 the bundle was carried on the coordinator and threaded
// into the trace + fold, but its structural content — which atoms
// were admitted vs. held as candidates, which conflicts are open,
// which quarantines or forget cascades are active — was never
// surfaced as typed per-subject evidence. This file lands the
// additive primitives so the coordinator can derive a typed per-turn
// L8 bundle that the L14 audit surface can reconcile against what
// the hippocampus actually did on this turn.
//
// Design mirrors M55 / M56 / M57 / M58 / M59 / M60 / M61 / M62 on
// purpose: the L14 reconciler reads one shape across L1 / L3 / L4 /
// L5 / L6 / L7 / L8 / L9 / L10 / L11 / L12 / L13, and the
// coherent-by-construction join uses a single (sessionID, turnID)
// per turn.
//
// Design principles:
//   1. Immutability — every reading is a value; a bundle is
//      frozen once emitted.
//   2. Typed shape + kind — no free-form strings; two sealed
//      enums.
//   3. Subject-addressable — every observation carries a
//      subjectID (the concrete L8 subject the signal pertains to:
//      hostVersionRef, memoryID, conflictRef, quarantineID, or
//      cascadeID).
//   4. Budget-aware — per-signal L8 cost with clamped totalCost.
//      Forget cascades and quarantines are premium cost; baseline
//      bundle retrieval and per-atom signals are cheap.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.

/// A categorical summary of the L8 hippocampal memory phase at this
/// turn — every observation on a given turn carries the same shape.
public enum BASHippocampalMemoryShape:
    String, Sendable, Codable, CaseIterable
{
    /// Baseline — atoms retrieved, no conflicts, no quarantine,
    /// no forget cascade. Audit surface's lowest attention phase
    /// for L8.
    case quiet
    /// Conflicts are flagged in the bundle (top-level
    /// `conflictRefs` non-empty) but no quarantine or forget
    /// cascade is running yet. Intermediate concern.
    case conflicted
    /// The temporal field carries at least one quarantine record —
    /// atoms are withheld from retrieval pending release. High
    /// concern; overrides `conflicted`.
    case quarantined
    /// The temporal field carries at least one forget cascade —
    /// active deletion is in progress. Highest concern; overrides
    /// every other classification.
    case forgetting
    /// No atoms retrieved, no conflicts, no temporal field
    /// activity. The hippocampus returned empty on this turn —
    /// either a cold-start turn or a retrieval miss. Mutually
    /// exclusive with every other classification.
    case empty
}

/// The eight upstream signals an L8 hippocampal memory observation
/// pipeline can emit. Each pertains to exactly one L8 subject
/// (identified by the `subjectID` field on the observation).
public enum BASHippocampalMemorySignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// Baseline — the memory bundle was retrieved this turn.
    /// Always emitted when a `BASMemoryBundle` exists. subjectID =
    /// `activeHostVersion` or "<unversioned>" if nil.
    case bundleRetrieved
    /// A memory atom is in the `.admitted` promotion state and not
    /// frozen. subjectID = atom.memoryID. Emitted once per admitted
    /// atom in bundle.atoms iteration order.
    case atomAdmitted
    /// A memory atom is in the `.candidate` promotion state and not
    /// frozen. subjectID = atom.memoryID. Emitted once per candidate
    /// atom in bundle.atoms iteration order.
    case atomCandidate
    /// A memory atom is frozen (either `frozen: true` or
    /// `promotionState == .frozen`). subjectID = atom.memoryID.
    /// Emitted once per frozen atom in bundle.atoms iteration
    /// order.
    case atomFrozen
    /// A memory atom is in the `.retired` promotion state. subjectID
    /// = atom.memoryID. Emitted once per retired atom in
    /// bundle.atoms iteration order.
    case atomRetired
    /// A top-level conflict reference was flagged. subjectID = the
    /// ref. Emitted once per `conflictRefs` entry (in array order).
    case conflictFlagged
    /// A quarantine record is present in the temporal field.
    /// subjectID = `quarantineID`. Emitted once per
    /// `quarantineRecords` entry (in array order). Each record gets
    /// its own typed observation so the L14 surface can group by
    /// quarantine ID.
    case quarantineRecorded
    /// A forget cascade is present in the temporal field. subjectID
    /// = `cascadeID`. Emitted once per `forgetCascades` entry (in
    /// array order). Each cascade gets its own typed observation so
    /// the L14 surface can group by cascade ID.
    case forgetCascadeBound
}

/// A single typed L8 hippocampal memory observation. Salience and
/// confidence are in [0, 1]; content is opaque to the transport but
/// carries the signal-specific payload (atom summary / conflict
/// fingerprint / quarantine reason codes / cascade execution state).
/// `subjectID` is the concrete L8 subject (hostVersion ref, memoryID,
/// conflictRef, quarantineID, or cascadeID).
public struct BASHippocampalMemoryObservation:
    Sendable, Equatable, Codable
{
    public let kind: BASHippocampalMemorySignalKind
    public let shape: BASHippocampalMemoryShape
    public let subjectID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASHippocampalMemorySignalKind,
        shape: BASHippocampalMemoryShape,
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

/// A bundle of L8 hippocampal memory observations emitted in one
/// turn.
/// chapter 四百五 / M986:adopts `BASBundleProtocol`。
public struct BASHippocampalMemoryObservationBundle:
    Sendable, Equatable, Codable, BASBundleProtocol
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASHippocampalMemoryObservation]
    public let emittedAt: Date

    /// chapter 四百五 / M986:`BASBundleProtocol` synthesized
    /// accessors。Stable bundleID derived from turnID。
    public var bundleID: String {
        "hippocampal-memory-observation-bundle:\(turnID)"
    }

    public var schemaVersion: String { "1.0.0" }

    public var recordedAt: Date { emittedAt }


    public init(
        turnID: String,
        sessionID: String,
        observations: [BASHippocampalMemoryObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASHippocampalMemorySignalKind
    ) -> [BASHippocampalMemoryObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Observations for a given shape, across all kinds, in
    /// emission order.
    public func observations(
        forShape shape: BASHippocampalMemoryShape
    ) -> [BASHippocampalMemoryObservation] {
        observations.filter { $0.shape == shape }
    }

    /// Observations for a given subject, across all shapes and
    /// kinds, in emission order.
    public func observations(
        forSubject subjectID: String
    ) -> [BASHippocampalMemoryObservation] {
        observations.filter { $0.subjectID == subjectID }
    }

    /// True iff the bundle-retrieved baseline was emitted (always
    /// true for a bundle derived from a real `BASMemoryBundle`).
    public var hasBundleRetrieval: Bool {
        observations.contains { $0.kind == .bundleRetrieved }
    }

    /// True iff at least one per-atom signal fired (admitted /
    /// candidate / frozen / retired).
    public var hasAnyAtomSignal: Bool {
        observations.contains {
            $0.kind == .atomAdmitted
                || $0.kind == .atomCandidate
                || $0.kind == .atomFrozen
                || $0.kind == .atomRetired
        }
    }

    /// True iff at least one atom was reported as frozen this turn.
    public var hasAnyFrozenAtom: Bool {
        observations.contains { $0.kind == .atomFrozen }
    }

    /// True iff at least one top-level conflict ref was flagged.
    public var hasAnyConflict: Bool {
        observations.contains { $0.kind == .conflictFlagged }
    }

    /// True iff at least one quarantine record fired.
    public var hasAnyQuarantine: Bool {
        observations.contains { $0.kind == .quarantineRecorded }
    }

    /// True iff at least one forget cascade fired.
    public var hasAnyForgetCascade: Bool {
        observations.contains { $0.kind == .forgetCascadeBound }
    }

    /// Core coverage contract: L8 has proof of activity when the
    /// bundle-retrieved baseline is present. Matches the "memory
    /// was read" floor the L14 surface expects.
    public var hasCoreSignalCoverage: Bool { hasBundleRetrieval }

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

/// Pure lookup: what does each L8 signal cost the L1 wake budget?
/// Values are weights in abstract budget units (0.0–1.0).
/// Forget cascades are the most expensive — each represents an
/// active deletion in progress. Quarantines are next — they guard
/// a withholding decision. Conflict flags are medium-expensive.
/// Per-atom signals are cheap (many admitted atoms per turn is
/// normal); the baseline bundle-retrieved signal is cheapest.
public enum BASHippocampalMemorySignalBudget {
    public static let signalCost:
        [BASHippocampalMemorySignalKind: Double] = [
            .bundleRetrieved: 0.02,
            .atomAdmitted: 0.04,
            .atomCandidate: 0.04,
            .atomFrozen: 0.08,
            .atomRetired: 0.06,
            .conflictFlagged: 0.10,
            .quarantineRecorded: 0.15,
            .forgetCascadeBound: 0.20
        ]

    public static func cost(
        for kind: BASHippocampalMemorySignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASHippocampalMemoryObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent L8 observation bundles
/// so the L14 audit surface (and integration tests) can inspect
/// what L8 emitted across a session. 128 entries covers any
/// realistic turn stream without unbounded growth.
public actor BASHippocampalMemoryObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASHippocampalMemoryObservationBundle] = []

    public init(
        capacity: Int =
            BASHippocampalMemoryObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASHippocampalMemoryObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot(
    ) -> [BASHippocampalMemoryObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASHippocampalMemoryObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASHippocampalMemoryObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
