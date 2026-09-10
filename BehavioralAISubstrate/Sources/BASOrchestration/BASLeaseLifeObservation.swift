import Foundation
import BASRuntimeCore

// MARK: - Lease & Life observation primitives
//
// M60 — L1 灯芯层 main-chain load-bearing observation model.
//
// L1 is the kernel layer: it grants the lease, picks the run mode,
// reads the thermal twin, and decides whether a maintenance window
// is allowed this turn. Before M60 those decisions lived only on
// `BASBudgetFrame` — a static snapshot the rest of the pipeline
// consumed without ever emitting "L1 was here" evidence. This file
// lands the additive primitives so the coordinator can derive a
// typed per-turn signal bundle that the L14 audit surface can
// reconcile with whatever the kernel actually did.
//
// Design mirrors M55 / M56 / M57 / M58 / M59 on purpose: the L14
// reconciler reads one shape across L4 / L6 / L7 / L9 / L10 / L11 /
// L12 / L13 / L1, and the coherent-by-construction join uses a
// single (sessionID, turnID) per turn.
//
// Design principles:
//   1. Immutability — every reading is a value; a bundle is
//      frozen once emitted.
//   2. Typed shape + kind — no free-form strings; two sealed
//      enums.
//   3. Subject-addressable — every observation carries a
//      subjectID (the kernel concern the signal pertains to —
//      leaseID, runMode, thermal guard level, maintenance class,
//      device route) so the L14 surface can group signals per
//      subject.
//   4. Budget-aware — per-signal L1 cost with clamped totalCost.
//      Guard-level escalation is the most expensive; lease-grant
//      is the cheapest.
//   5. Auditable — append-only ring actor ledger keyed by turn
//      and session.

/// A categorical summary of what the kernel did on this turn —
/// the L1 "phase". Every observation on a given turn carries the
/// same shape.
public enum BASLeaseLifeShape:
    String, Sendable, Codable, CaseIterable
{
    /// Normal operating envelope — the kernel woke, picked an
    /// engage/reflect run mode, and the thermal guard level is
    /// `.nominal` or `.watch`. No maintenance window active.
    case nominal
    /// The thermal guard escalated to `.throttle` — the kernel
    /// has already downgraded what heads/classes it's willing to
    /// schedule this turn.
    case throttled
    /// The thermal guard is at `.emergency` — every maintenance
    /// class is suppressed, and any breath request should be
    /// rejected. L1 "spoke but did not sustain core function".
    case emergency
    /// A maintenance window was granted this turn (the kernel is
    /// allowed to run a non-empty maintenance class). Orthogonal
    /// to thermal guard — a light maintenance window can still
    /// run under `.watch` guard.
    case maintenance
    /// The kernel is on a background/heartbeat path —
    /// `runMode ∈ {dormant, pulse, sentinel}`. Nothing active.
    case dormant
    /// The kernel is on a recovery / quarantine / lockdown path —
    /// extracting from a previous anomaly, not doing normal work.
    case lockdown
}

/// The six upstream signals an L1 observation pipeline can emit.
/// Each pertains to exactly one kernel concern (identified by the
/// `subjectID` field on the observation).
public enum BASLeaseLifeSignalKind:
    String, Sendable, Codable, CaseIterable
{
    /// Baseline — a run lease was granted for this turn.
    /// subjectID = the `leaseID` when present, or a synthetic
    /// `"lease.<runMode>"` when the budget has no lease id. Always
    /// emitted exactly once per turn.
    case leaseGranted
    /// The kernel picked a run mode for this turn. subjectID =
    /// `"runmode.<rawValue>"`. Always emitted exactly once per
    /// turn.
    case runModeDetermined
    /// The kernel published a thermal guard level on the budget
    /// frame. subjectID = `"thermal.<guardLevelRawValue>"`. Always
    /// emitted exactly once per turn (even at `.nominal` — the
    /// reading itself is evidence L1 looked at thermal).
    case thermalReadingObserved
    /// The thermal guard level is above `.nominal`. subjectID =
    /// `"thermal.escalation.<guardLevelRawValue>"`. Salience and
    /// budget cost scale with the escalation severity. Emitted
    /// only when `guardLevel != .nominal`.
    case guardLevelEscalated
    /// The kernel classified a maintenance window for this turn.
    /// subjectID = `"maintenance.<classRawValue>"`. Emitted only
    /// when `maintenanceAllowed == true` AND the
    /// `maintenanceClass` is not `.none` — a forbidden or empty
    /// window does not yield this signal.
    case maintenanceClassified
    /// The kernel selected a device route for this turn.
    /// subjectID = `"device.<routeRawValue>"`. Always emitted
    /// exactly once per turn.
    case deviceRouteSelected
}

/// A single typed L1 kernel observation. Salience and confidence
/// are in [0, 1]; content is opaque to the transport but carries
/// the signal-specific payload (run mode title / guard-level name /
/// maintenance class / device route / accumulated context).
/// `subjectID` is the kernel concern the observation pertains to.
public struct BASLeaseLifeObservation:
    Sendable, Equatable, Codable
{
    public let kind: BASLeaseLifeSignalKind
    public let shape: BASLeaseLifeShape
    public let subjectID: String
    public let salience: Double
    public let confidence: Double
    public let content: String
    public let observedAt: Date

    public init(
        kind: BASLeaseLifeSignalKind,
        shape: BASLeaseLifeShape,
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

/// A bundle of L1 observations emitted in one turn.
/// chapter 四百五 / M985:adopts `BASBundleProtocol` (6th of
/// 18+ concrete bundles)。
public struct BASLeaseLifeObservationBundle:
    Sendable, Equatable, Codable, BASBundleProtocol
{
    public let turnID: String
    public let sessionID: String
    public let observations: [BASLeaseLifeObservation]
    public let emittedAt: Date

    public var bundleID: String {
        "lease-life-observation-bundle:\(turnID)"
    }

    public var schemaVersion: String { "1.0.0" }

    public var recordedAt: Date { emittedAt }

    public init(
        turnID: String,
        sessionID: String,
        observations: [BASLeaseLifeObservation],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.observations = observations
        self.emittedAt = emittedAt
    }

    /// Observations of a given kind, in emission order.
    public func observations(
        of kind: BASLeaseLifeSignalKind
    ) -> [BASLeaseLifeObservation] {
        observations.filter { $0.kind == kind }
    }

    /// Observations for a given shape, across all kinds, in
    /// emission order.
    public func observations(
        forShape shape: BASLeaseLifeShape
    ) -> [BASLeaseLifeObservation] {
        observations.filter { $0.shape == shape }
    }

    /// Observations for a given subject, across all shapes and
    /// kinds, in emission order.
    public func observations(
        forSubject subjectID: String
    ) -> [BASLeaseLifeObservation] {
        observations.filter { $0.subjectID == subjectID }
    }

    /// True iff at least one lease-grant observation was emitted.
    /// A bundle without a lease-grant is structurally empty — the
    /// turn produced no kernel evidence.
    public var hasAnyLeaseGrant: Bool {
        observations.contains { $0.kind == .leaseGranted }
    }

    /// True iff the turn reached any guard-level escalation
    /// (throttle or emergency).
    public var hasAnyGuardEscalation: Bool {
        observations.contains { $0.kind == .guardLevelEscalated }
    }

    /// True iff the turn had a maintenance window classified.
    public var hasAnyMaintenance: Bool {
        observations.contains { $0.kind == .maintenanceClassified }
    }

    /// True iff the bundle carries the minimum signal set that
    /// proves L1 actually ran this turn (lease grant + run-mode +
    /// thermal reading + device route). Under `.emergency` the
    /// kernel is in panic state, which we encode separately via
    /// `isInEmergencyPhase` — the coverage contract is still "L1
    /// emitted the baseline" (hasCoreSignalCoverage stays true),
    /// but the L14 surface can filter on the phase flag.
    public var hasCoreSignalCoverage: Bool {
        hasAnyLeaseGrant
            && observations.contains { $0.kind == .runModeDetermined }
            && observations.contains { $0.kind == .thermalReadingObserved }
            && observations.contains { $0.kind == .deviceRouteSelected }
    }

    /// True iff any observation in the bundle carries the
    /// `.emergency` shape — i.e. the kernel reported an emergency
    /// thermal guard level on this turn. L14 reconciliation can
    /// use this to decide whether to emit a rollback or guard
    /// escalation recommendation.
    public var isInEmergencyPhase: Bool {
        observations.contains { $0.shape == .emergency }
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
}

// MARK: - Signal budget

/// Pure lookup: what does each L1 signal cost the wake budget?
/// Values are weights in abstract budget units (0.0–1.0).
/// Guard-level escalation is the most expensive — it implies the
/// kernel is already working extra to downgrade classes. The
/// lease grant itself is the cheapest — it's a single integer
/// bookkeeping operation.
///
/// Distinct from `BASLeaseLifeObservationBudget` in the
/// `BASLeaseLife` module: that lookup costs a whole `TurnRecorded`
/// for the M39 coverage projection. This one costs individual
/// bundle signals for the M60 main-chain observation surface.
public enum BASLeaseLifeSignalBudget {
    public static let signalCost:
        [BASLeaseLifeSignalKind: Double] = [
            .leaseGranted: 0.10,
            .runModeDetermined: 0.10,
            .thermalReadingObserved: 0.10,
            .guardLevelEscalated: 0.20,
            .maintenanceClassified: 0.15,
            .deviceRouteSelected: 0.10
        ]

    public static func cost(
        for kind: BASLeaseLifeSignalKind
    ) -> Double {
        signalCost[kind] ?? 0
    }

    public static func totalCost(
        for bundle: BASLeaseLifeObservationBundle
    ) -> Double {
        let sum = bundle.observations.reduce(0.0) { acc, obs in
            acc + cost(for: obs.kind)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Ledger

/// Append-only ring actor that keeps recent L1 observation bundles
/// so the L14 audit surface (and integration tests) can inspect
/// what L1 emitted across a session. 128 entries covers any
/// realistic turn stream without unbounded growth.
public actor BASLeaseLifeObservationLedger {
    public static let defaultCapacity: Int = 128

    private let capacity: Int
    private var buffer: [BASLeaseLifeObservationBundle] = []

    public init(
        capacity: Int =
            BASLeaseLifeObservationLedger.defaultCapacity
    ) {
        self.capacity = max(1, capacity)
    }

    public func record(
        _ bundle: BASLeaseLifeObservationBundle
    ) {
        buffer.append(bundle)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public func snapshot() -> [BASLeaseLifeObservationBundle] {
        buffer
    }

    public func count() -> Int { buffer.count }

    public func bundles(
        forSession sessionID: String
    ) -> [BASLeaseLifeObservationBundle] {
        buffer.filter { $0.sessionID == sessionID }
    }

    public func bundle(
        forTurn turnID: String
    ) -> BASLeaseLifeObservationBundle? {
        buffer.first { $0.turnID == turnID }
    }

    public func clear() { buffer.removeAll() }
}
