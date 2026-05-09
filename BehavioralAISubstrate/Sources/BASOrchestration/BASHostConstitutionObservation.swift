import Foundation
import BASRuntimeCore
import BASMemory

// MARK: - Host-constitution observation primitives
//
// M61 — L5 宿纹层 main-chain load-bearing observation model.
//
// L5 is the host-constitution vault: 12 domains (identity /
// values / goals / boundaries / relations / rhythm / style /
// routines / consent / narrative / protection / version lineage)
// that define a single host's individual envelope. Before M61 the
// coordinator carried `hostConstitution` / `hostVersionTree` /
// `hostForgetRequest` as static reference state — consumed by the
// thought-fold and trace but never surfaced as typed per-subject
// evidence. This file lands the additive primitives so the
// coordinator can derive a typed per-turn signal bundle that the
// L14 audit surface can reconcile with whatever governance actually
// happened on the pipeline.
//
// Design mirrors M55 / M56 / M57 / M58 / M59 / M60 on purpose: the
// L14 reconciler reads one shape across L1 / L4 / L5 / L6 / L7 /
// L9 / L10 / L11 / L12 / L13, and the coherent-by-construction join
// uses a single (sessionID, turnID) per turn.
//
// Design principles:
//   1. Immutability — every reading is a value; a bundle is
//      frozen once emitted.
//   2. Typed shape + kind — no free-form strings; two sealed
//      enums.
//   3. Subject-addressable — every observation carries a
//      subjectID (the governance subject the signal pertains to:
//      active/committed/frozen versionID, pending candidateID, or
//      forget requestID) so the L14 surface can group signals per
//      subject.
//   4. Budget-aware — per-signal L1 cost with clamped totalCost.
//      Forget requests and unbootstrapped states carry premium
//      cost; anchor / committed versions are cheap steady cost.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.
//   6. Coexistence with M40 — the existing
//      `BASHostCandidatePipelineObservationSnapshot` (pure
//      coverage value) and
//      `BASHostCandidatePipelineObservationBudget` (coverage cost)
//      remain unchanged. M61 adds typed per-signal evidence on top
//      of that coverage projection.

/// A categorical summary of what L5 was doing at this turn's
/// moment in time — the governance "phase". Every observation on a
/// given turn carries the same shape.
public enum BASHostConstitutionShape:
    String, Sendable, Codable, CaseIterable
{
    /// Nothing in flight — the active version is bootstrapped, no
    /// pending candidates, no frozen versions, no forget request.
    /// The audit surface's lowest-attention phase.
    case quiet
    /// At least one pending candidate exists — the pipeline is
    /// actively governing. Reviewers and approvers have work to do.
    case governing
    /// At least one frozen version exists — governance has taken a
    /// hard stop on at least one lineage node. Rollback to that
    /// node is forbidden until thaw.
    case frozen
    /// A forget request is in flight — highest-severity governance
    /// state. L5 is processing a host-initiated deletion cascade
    /// that every other layer must respect.
    case forgetting
    /// The constitution is unbootstrapped — either
    /// `hostConstitution` is nil or its `activeVersion` is empty.
    /// L5 has no identity front; every downstream reconciliation
    /// should gate on this.
    case unbootstrapped
}

/// The six upstream signals an L5 observation pipeline can emit.
/// Each pertains to exactly one governance subject (identified by
/// the `subjectID` field on the observation).
public enum BASHostConstitutionSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// Baseline — the host constitution is bootstrapped with an
    /// active version. subjectID = activeVersionID. Emitted iff
    /// the constitution is present AND `activeVersion` is
    /// non-empty.
    case anchorActive
    /// A committed version exists in the version tree. subjectID =
    /// versionID. Emitted once per committed version (not per
    /// turn; per version). A bootstrapped tree with only the
    /// active version yields exactly one of these.
    case versionCommitted
    /// A candidate is pending approval in the pipeline. subjectID =
    /// candidateID. Emitted once per pending candidate.
    case candidatePending
    /// A version is frozen. subjectID = versionID. Emitted once per
    /// frozen version. Distinct from `versionCommitted` — a
    /// version can be both committed and frozen, and each signal
    /// contributes independently.
    case versionFrozen
    /// A forget request is in flight. subjectID = requestID.
    /// Emitted once per active forget request (exactly zero or
    /// one; the pipeline processes them serially).
    case forgetInFlight
    /// The constitution is unbootstrapped — either missing
    /// entirely or its activeVersion is empty. subjectID =
    /// `"host.unbootstrapped"` (synthetic; no real ID to anchor
    /// on). Mutually exclusive with `.anchorActive`: a bundle
    /// cannot carry both.
    case constitutionUnbootstrapped
}

/// A single typed L5 governance observation. Salience and
/// confidence are in [0, 1]; content is opaque to the transport
/// but carries the signal-specific payload (activeVersion / host
/// ID / candidate count / forget scope).
/// `subjectID` is the governance subject the observation pertains
/// to.
public struct BASHostConstitutionObservation:
    Sendable, Equatable, Codable
{
    public let kind: BASHostConstitutionSignalKind
    public let shape: BASHostConstitutionShape
    public let subjectID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASHostConstitutionSignalKind,
        shape: BASHostConstitutionShape,
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

/// A bundle of L5 observations emitted in one turn.
/// chapter 四百五 / M986:adopts `BASBundleProtocol`。
public struct BASHostConstitutionObservationBundle:
    Sendable, Equatable, Codable, BASBundleProtocol
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASHostConstitutionObservation]
    public let emittedAt: Date

    /// chapter 四百五 / M986:`BASBundleProtocol` synthesized
    /// accessors。Stable bundleID derived from turnID。
    public var bundleID: String {
        "host-constitution-observation-bundle:\(turnID)"
    }

    public var schemaVersion: String { "1.0.0" }

    public var recordedAt: Date { emittedAt }


    public init(
        turnID: String,
        sessionID: String,
        observations: [BASHostConstitutionObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASHostConstitutionSignalKind
    ) -> [BASHostConstitutionObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Observations for a given shape, across all kinds, in
    /// emission order.
    public func observations(
        forShape shape: BASHostConstitutionShape
    ) -> [BASHostConstitutionObservation] {
        observations.filter { $0.shape == shape }
    }

    /// Observations for a given subject, across all shapes and
    /// kinds, in emission order.
    public func observations(
        forSubject subjectID: String
    ) -> [BASHostConstitutionObservation] {
        observations.filter { $0.subjectID == subjectID }
    }

    /// True iff the bundle carries an active-anchor observation —
    /// the coverage floor matches M40's `hasCoreSignalCoverage`.
    /// An unbootstrapped bundle returns false (the
    /// `.constitutionUnbootstrapped` signal is present, but core
    /// coverage is the identity-front floor).
    public var hasAnyAnchor: Bool {
        observations.contains { $0.kind == .anchorActive }
    }

    /// True iff any pending candidate was observed this turn.
    public var hasAnyPending: Bool {
        observations.contains { $0.kind == .candidatePending }
    }

    /// True iff any frozen version was observed this turn.
    public var hasAnyFrozen: Bool {
        observations.contains { $0.kind == .versionFrozen }
    }

    /// True iff a forget request was observed this turn.
    public var hasForgetInFlight: Bool {
        observations.contains { $0.kind == .forgetInFlight }
    }

    /// True iff the constitution was observed as unbootstrapped.
    public var isUnbootstrapped: Bool {
        observations.contains { $0.kind == .constitutionUnbootstrapped }
    }

    /// Core coverage contract: L5 has proof of activity when the
    /// active-version anchor is present. Matches M40 pipeline
    /// coverage projection semantics so downstream reconcilers can
    /// use one floor across both surfaces.
    public var hasCoreSignalCoverage: Bool { hasAnyAnchor }

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

/// Pure lookup: what does each L5 signal cost the L1 wake budget?
/// Values are weights in abstract budget units (0.0–1.0).
/// Forget-in-flight and unbootstrapped are the most expensive —
/// both demand reconciliation work. Anchor / committed versions
/// are cheap steady cost.
///
/// Distinct from `BASHostCandidatePipelineObservationBudget` in
/// `BASMemory`: that budget costs a coverage snapshot for M40.
/// This one costs individual bundle signals for the M61 main-chain
/// observation surface.
public enum BASHostConstitutionSignalBudget {
    public static let signalCost:
        [BASHostConstitutionSignalKind: Double] = [
            .anchorActive: 0.05,
            .versionCommitted: 0.02,
            .candidatePending: 0.10,
            .versionFrozen: 0.08,
            .forgetInFlight: 0.25,
            .constitutionUnbootstrapped: 0.15
        ]

    public static func cost(
        for kind: BASHostConstitutionSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASHostConstitutionObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent L5 observation bundles
/// so the L14 audit surface (and integration tests) can inspect
/// what L5 emitted across a session. 128 entries covers any
/// realistic turn stream without unbounded growth.
public actor BASHostConstitutionObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASHostConstitutionObservationBundle] = []

    public init(
        capacity: Int =
            BASHostConstitutionObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASHostConstitutionObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot(
    ) -> [BASHostConstitutionObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASHostConstitutionObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASHostConstitutionObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
