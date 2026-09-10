import Foundation
import BASRuntimeCore

// MARK: - L1 lease-life coverage projection
//
// M39 — additive edge projection from
// `BASLeaseLifeCoordinator.TurnRecorded` (the turn-bound snapshot
// that captures lung pressure + thermal reading + any breath IDs
// the scheduler cancelled under guard-level escalation) to the
// neutral `BASObservationCoverageSummary` defined in
// `BASRuntimeCore` (M31). Extends the M32/M37/M38 wave from
// 10-of-14 to **11-of-14** projected layers. Remaining three:
// L2 (neuralOrgan), L3 (thoughtFold), L5 (hostConstitution).
//
// Like L8 (M37) and L14 (M38), L1's record does not carry an
// intrinsic turn/session — `TurnRecorded` is a per-turn value the
// caller pairs with whatever turn/session context they're running
// in. The projection therefore takes both keys as arguments.
//
// Design principles:
//   1. Additive — `BASLeaseLifeCoordinator`,
//      `BASLungStateAccumulator`, `BASThermalTwin`,
//      `BASBreathScheduler`, and every consumer path are
//      untouched. Callers opt in via `coverageSummary(turnID:
//      sessionID:)` on the turn-recorded value.
//   2. Pure — no actor hops; same `TurnRecorded` + same keys yield
//      the same summary.
//   3. Neutral shape — the L14 reconciler consumes L1 in exactly
//      the same way it consumes every other projected layer.
//   4. Isolation preserved — this file lives in `BASLeaseLife`
//      and imports only `BASRuntimeCore`. The sovereign microkernel
//      remains decoupled.

// MARK: - Budget

/// Pure lookup: what does each lease-life turn-recording cost the
/// L1 wake budget? Values are weights in abstract budget units
/// (0.0–1.0). The kernel itself is the budget *authority*; its
/// self-cost reflects the bookkeeping overhead of measuring lung
/// pressure, reading the thermal twin, and reconciling the
/// scheduler.
///
/// Guard-level multipliers:
///   - `.nominal` / `.watch` — 1× (normal operating envelope)
///   - `.throttle` — 1.5× (the kernel is already doing extra work
///     to drop disallowed classes)
///   - `.emergency` — 2× (cancelAll pass plus the audit weight of
///     a panic state)
public enum BASLeaseLifeObservationBudget {
    public static let turnBaseCost: Double = 0.05
    public static let cancelledBreathCost: Double = 0.02
    public static let throttleMultiplier: Double = 1.5
    public static let emergencyMultiplier: Double = 2.0

    /// Guard-level multiplier applied to the raw base + per-breath
    /// cost. Exposed separately so callers can reason about the two
    /// factors independently.
    public static func multiplier(
        for guardLevel: BASThermalGuardLevel
    ) -> Double {
        switch guardLevel {
        case .nominal, .watch: return 1.0
        case .throttle: return throttleMultiplier
        case .emergency: return emergencyMultiplier
        }
    }

    /// Clamped total cost for a single turn's `TurnRecorded`.
    public static func cost(
        for recorded: BASLeaseLifeCoordinator.TurnRecorded
    ) -> Double {
        let base = turnBaseCost
            + cancelledBreathCost
                * Double(recorded.cancelledBreathIDs.count)
        let m = multiplier(for: recorded.thermal.guardLevel)
        return min(1, max(0, base * m))
    }
}

// MARK: - Coverage projection

extension BASLeaseLifeCoordinator.TurnRecorded {
    /// L1 has "core signal coverage" for a turn iff the kernel
    /// actually delivered a usable operating envelope. Under
    /// `.emergency` guard level the kernel is in panic state —
    /// every maintenance wakeup is a liability and all breaths
    /// have been cancelled — which is an L1-visible anomaly the
    /// reconciler should treat as "L1 spoke but did not sustain
    /// core function". Any other guard level (`.nominal` /
    /// `.watch` / `.throttle`) counts as core coverage.
    public var hasCoreSignalCoverage: Bool {
        thermal.guardLevel != .emergency
    }

    /// Neutral coverage summary for L1. Three governance subjects
    /// are active per recorded turn:
    ///   - lung (cross-turn pressure accumulator)
    ///   - thermal (OS state + fused guard level)
    ///   - each cancelled breath (by `id`, one subject per cancel)
    ///
    /// Total observations map to per-subject readings: 2 base
    /// (lung + thermal) plus one per cancelled breath. The
    /// `emittedAt` stamp uses the thermal reading's `observedAt`
    /// as the closest wall-clock correspondence to when L1
    /// actually produced this snapshot.
    public func coverageSummary(
        turnID: String,
        sessionID: String
    ) -> BASObservationCoverageSummary {
        let totalObservations = 2 + cancelledBreathIDs.count
        // Each cancelled breath is a distinct scheduler-pool
        // subject; lung and thermal are their own fixed subjects.
        // `Set` collapses pathological duplicate IDs if the
        // scheduler ever produced a repeated cancel (the coordinator
        // uses `Set` internally so duplicates shouldn't surface,
        // but the defensive collapse keeps projection robust).
        let uniqueCancelled = Set(cancelledBreathIDs)
        let distinctSubjectCount = 2 + uniqueCancelled.count
        return BASObservationCoverageSummary(
            layer: .leaseLife,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: totalObservations,
            distinctSubjectCount: distinctSubjectCount,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASLeaseLifeObservationBudget.cost(for: self),
            emittedAt: thermal.observedAt)
    }
}
