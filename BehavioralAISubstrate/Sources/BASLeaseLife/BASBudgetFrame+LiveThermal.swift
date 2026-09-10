import Foundation
import BASRuntimeCore

// MARK: - M67 live-thermal budget helper
//
// M67 closes the last mile between the L1 lifecycle's live thermal
// reading (M66 `QinaoLifecycle` → `BASLeaseLifeCoordinator` →
// `BASThermalTwin`) and the per-turn `BASBudgetFrame` that the
// coordinator carries through the main chain.
//
// Before M67, budget frames were built with a `thermalGuardLevel`
// value the caller had to supply. The intended source (the live
// thermal twin) existed on the lifecycle side, but there was no
// value transform that plumbed "ask the twin, stamp the budget"
// into a single call. Hosts either invented a constant, copied the
// previous turn's reading, or called the thermal twin themselves
// and then rebuilt the whole frame — which defeats the point of
// routing all budget state through the coordinator.
//
// The helper is a pure value transform:
//   - No I/O, no actor hop, no allocation beyond a struct copy.
//   - Deterministic: two calls with the same (frame, level) pair
//     produce identical output.
//   - Non-throwing: no invariant the caller could violate. The
//     `BASThermalGuardLevel` enum covers every valid state.
//   - Preserves every other field of the frame — schema version,
//     run mode, loop / candidate / decode caps, retrieval depth,
//     precision profile, device route, maintenance allowed /
//     class, lease metadata, wake intent, allowed heads, policy
//     fields — so callers can use it mid-pipeline without having
//     to re-read the budget from scratch.
//
// Usage on the Qinao main chain:
//
//     // Before building the turn, let the lifecycle sample fresh:
//     let reading = await lifecycle.resample()
//     // Route the live reading into the budget the caller had
//     // already planned:
//     let routedBudget = plannedBudget
//         .withLiveThermalGuardLevel(reading.thermal.guardLevel)
//
// A shorter variant that reads the twin's current guard level in
// one hop is provided as a coordinator-backed convenience:
//
//     let routedBudget = await plannedBudget
//         .withLiveThermalGuardLevel(from: lifecycle)
//
// Both helpers live in `BASLeaseLife` because the L1 domain owns
// the thermal-to-budget binding. `BASLeaseLife` already depends on
// `BASRuntimeCore` (where `BASBudgetFrame` and the guard enum are
// defined), so this helper adds no new edges to the dependency
// graph.

extension BASBudgetFrame {
    /// Return a copy of this budget frame with its
    /// `thermalGuardLevel` replaced by the provided live value.
    /// Every other field — schema version, run mode, caps,
    /// precision profile, device route, lease metadata, maintenance
    /// class, policy identifiers, allowed heads — is preserved.
    ///
    /// This is the canonical "plumb the live thermal reading into
    /// the per-turn budget" seam. Hosts building a main-chain turn
    /// call it once, right after sampling the L1 lifecycle, and
    /// before handing the budget to downstream stages.
    ///
    /// - Parameter level: The thermal guard level to stamp into the
    ///   returned frame. Typically sourced from
    ///   `BASThermalTwin.Reading.guardLevel` or
    ///   `BASLeaseLifeCoordinator.TurnRecorded.thermal.guardLevel`.
    /// - Returns: A new `BASBudgetFrame` identical to `self` except
    ///   that `thermalGuardLevel` is `level`.
    public func withLiveThermalGuardLevel(
        _ level: BASThermalGuardLevel
    ) -> BASBudgetFrame {
        var copy = self
        copy.thermalGuardLevel = level
        return copy
    }
}

// MARK: - Coordinator-backed convenience

extension BASBudgetFrame {
    /// Convenience that asks a `BASLeaseLifeCoordinator` for its
    /// current thermal reading and stamps the resulting guard level
    /// into a copy of this budget frame. Equivalent to:
    ///
    ///     let reading = await coordinator.thermalActor()
    ///         .currentReading() ?? coordinator.thermalActor().sample()
    ///     return withLiveThermalGuardLevel(reading.guardLevel)
    ///
    /// Uses the cached reading when one is available — the thermal
    /// twin samples on `recordTurn`/`resample`, so in practice the
    /// cache is warm whenever the host has observed a turn. When no
    /// reading has been captured yet (first turn, or a fresh
    /// lifecycle), a sample is forced so the returned frame always
    /// carries a live reading rather than a stale default.
    ///
    /// - Parameter coordinator: The L1 lease/life coordinator (the
    ///   same one `QinaoLifecycle` wraps).
    /// - Returns: A new `BASBudgetFrame` identical to `self` except
    ///   that `thermalGuardLevel` is the coordinator's live guard
    ///   level.
    public func withLiveThermalGuardLevel(
        from coordinator: BASLeaseLifeCoordinator
    ) async -> BASBudgetFrame {
        let twin = await coordinator.thermalActor()
        // audit policy-obs-misc LOW-6: use a fresh-or-resample reading, not a possibly-stale cache.
        let reading = await twin.readingFresherThan()
        return withLiveThermalGuardLevel(reading.guardLevel)
    }
}
