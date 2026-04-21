import Foundation
import BASRuntimeCore

// MARK: - L2 neural-organ coverage projection
//
// M41 — additive edge projection from `BASOrganRegistry` (actor-owned
// L2 neural-organ inventory: registered adapter descriptors +
// registration order + role coverage) to the neutral
// `BASObservationCoverageSummary` defined in `BASRuntimeCore` (M31).
// Extends the M32/M37/M38/M39/M40 wave from 12-of-14 to **13-of-14**
// projected layers. Remaining one: L3 (thoughtFold).
//
// Like L5 (M40), L8 (M37), L14 (M38), L1 (M39), the registry carries
// no intrinsic turn/session — it represents the organ inventory at
// whatever moment the caller snapshots it. The projection therefore
// takes turn/session/emittedAt as arguments and follows the same
// dual pure/async pattern established in the L14 and L5 projections:
//
//   1. A pure static helper `projectCoverage(from:turnID:sessionID:
//      emittedAt:)` accepts a value snapshot and produces the
//      coverage summary synchronously — useful for snapshot-in-hand
//      callers and deterministic tests.
//   2. An async method on the actor reads its own state, assembles
//      the snapshot, and defers to the pure helper. Both paths
//      produce byte-identical summaries for the same input, which
//      is the M6 parity discipline every coverage-projected layer
//      upholds.
//
// Design principles:
//   1. Additive — `BASOrganRegistry`, `BASOrganAdapter`, every
//      provider implementation and consumer path are untouched.
//      Callers opt in via
//      `coverageSummary(turnID:sessionID:emittedAt:)`.
//   2. Pure helper is deterministic — same snapshot + same keys
//      always yield the same summary.
//   3. Neutral shape — the L14 reconciler consumes L2 in exactly
//      the same way it consumes every other projected layer.
//   4. Leaf discipline preserved — this file lives in `BASOrgan`
//      and imports only `BASRuntimeCore`.

// MARK: - Budget

/// Pure lookup: what does each L2 provider cost the L1 wake budget?
/// L2 is the second-cheapest layer in the substrate (after L1) when
/// idle — a registered descriptor is just a handle; the heavy cost
/// only materializes when a draft is actually requested. The
/// coverage budget here reflects the *bookkeeping weight* of an
/// organ registry at rest:
///
/// - Each provider carries a flat base cost (it occupies a named
///   slot the reconciler may have to page through).
/// - Each role a provider advertises adds a small per-role cost
///   (a provider supporting both `.scout` and `.core` demands
///   the registry audit two dispatch paths).
/// - On-device providers receive a multiplier discount: L1 does
///   not pay the network-round-trip premium when the model is
///   resident on the device.
/// - Off-device providers receive a multiplier premium:
///   remote/distant providers consume power for the transport
///   and add audit weight to the export path.
///
/// Weights are summed across all registered providers and clamped
/// to `[0, 1]`.
public enum BASOrganRegistryObservationBudget {
    /// Flat cost of carrying a single registered provider.
    public static let perProviderBaseCost: Double = 0.03

    /// Cost per role a provider advertises. A provider that
    /// supports both `.scout` and `.core` pays this twice.
    public static let perRoleSupportedCost: Double = 0.01

    /// Multiplier applied to a provider's raw cost when it runs
    /// on-device. On-device providers are cheaper because L1
    /// already owns the power envelope.
    public static let onDeviceMultiplier: Double = 0.7

    /// Multiplier applied to a provider's raw cost when it runs
    /// off-device (remote LLM, bridged MLX process, etc). Off-
    /// device providers are more expensive because they push the
    /// wake budget beyond L1's direct jurisdiction.
    public static let remoteMultiplier: Double = 1.2

    /// Cost for a single descriptor — base + per-role × role-count
    /// × on-device / remote multiplier. Exposed separately so
    /// callers can audit per-provider accounting.
    public static func cost(
        for descriptor: BASOrganDescriptor
    ) -> Double {
        let raw = perProviderBaseCost
            + perRoleSupportedCost
                * Double(descriptor.supportedRoles.count)
        let m = descriptor.runsOnDevice
            ? onDeviceMultiplier
            : remoteMultiplier
        return raw * m
    }

    /// Total clamped cost for a snapshot.
    public static func totalCost(
        for snapshot: BASOrganRegistryObservationSnapshot
    ) -> Double {
        let sum = snapshot.descriptors.reduce(0.0) { acc, d in
            acc + cost(for: d)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Snapshot shape

/// Pure, `Sendable`, `Equatable` value capturing the registry's
/// observable state at projection time. The pure projection helper
/// is keyed off this type rather than the actor so callers can
/// compose coverage summaries in tests without instantiating the
/// registry.
///
/// Descriptor ordering follows the registry's `registrationOrder`,
/// which preserves first-seen order (re-registration does not move
/// a provider to the back). This is deliberate — audit consumers
/// expect a stable iteration sequence.
public struct BASOrganRegistryObservationSnapshot:
    Sendable, Equatable
{
    public let descriptors: [BASOrganDescriptor]

    public init(descriptors: [BASOrganDescriptor]) {
        self.descriptors = descriptors
    }
}

// MARK: - Coverage projection

extension BASOrganRegistry {
    /// Pure projection from a snapshot value into a coverage
    /// summary. Does not touch actor state so it's safe to call
    /// from anywhere, including unit tests that never instantiate
    /// a registry.
    ///
    /// Observation / subject accounting:
    ///   - `totalObservations` sums per-descriptor contributions.
    ///     Each descriptor contributes one descriptor-level
    ///     observation (the provider is registered) plus one
    ///     observation per role it advertises (each supported role
    ///     is a dispatch path the registry must honor).
    ///   - `distinctSubjectCount` collapses on `providerID`. The
    ///     registry enforces uniqueness by construction — a
    ///     duplicate would be a pathological decode, so we collapse
    ///     defensively with `Set` rather than trust the caller.
    ///   - `hasCoreSignalCoverage` is true iff the registry covers
    ///     *both* `.scout` and `.core` roles. A two-tier organ
    ///     surface is L2's minimum viable signal — a registry that
    ///     only has scouts can answer L1 wake arbitration but
    ///     cannot sustain L9/L10 deliberation; a registry that only
    ///     has core can sustain deliberation but will burn budget
    ///     on every L1 prefilter. Either single-role configuration
    ///     is L2-visible but structurally incomplete.
    public static func projectCoverage(
        from snapshot: BASOrganRegistryObservationSnapshot,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASObservationCoverageSummary {
        let totalObservations = snapshot.descriptors.reduce(0) {
            acc, d in
            acc + 1 + d.supportedRoles.count
        }

        // Collapse on providerID defensively. Registry invariant
        // already enforces uniqueness, but the pure helper is
        // called with raw snapshots in tests so we keep the
        // reduction robust.
        let uniqueProviderIDs = Set(
            snapshot.descriptors.map { $0.providerID })
        let distinctSubjectCount = uniqueProviderIDs.count

        // Core-signal coverage: both roles must be covered by at
        // least one registered provider. Either role alone is
        // insufficient — the substrate's two-tier model assumes
        // Scout + Core are always jointly available.
        var rolesCovered: Set<BASOrganRole> = []
        for d in snapshot.descriptors {
            rolesCovered.formUnion(d.supportedRoles)
        }
        let hasCoreSignalCoverage =
            rolesCovered.contains(.scout)
                && rolesCovered.contains(.core)

        return BASObservationCoverageSummary(
            layer: .neuralOrgan,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: totalObservations,
            distinctSubjectCount: distinctSubjectCount,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASOrganRegistryObservationBudget.totalCost(
                    for: snapshot),
            emittedAt: emittedAt)
    }

    /// Async actor path: read the registry's state, assemble a
    /// snapshot, and project. Parity with the pure path is
    /// guaranteed by construction — this method only reads
    /// descriptors then calls `projectCoverage(from:...)`.
    public func coverageSummary(
        turnID: String,
        sessionID: String,
        emittedAt: Date = Date()
    ) -> BASObservationCoverageSummary {
        let snapshot = currentCoverageSnapshot()
        return Self.projectCoverage(
            from: snapshot,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: emittedAt)
    }

    /// The `BASOrganRegistryObservationSnapshot` for the registry's
    /// current state. Exposed so L14 reconciler tests can check
    /// actor/pure parity explicitly.
    public func currentCoverageSnapshot(
    ) -> BASOrganRegistryObservationSnapshot {
        BASOrganRegistryObservationSnapshot(
            descriptors: descriptors())
    }
}
