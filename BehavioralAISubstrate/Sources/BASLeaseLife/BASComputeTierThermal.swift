import Foundation
import BASRuntimeCore

// M102 — T3 Per-tier thermal twin + compute router (schema).
//
// Plan `l2-silly-piglet.md` §T3 ("L1 真实热模型 + 异构 CPU/GPU/NPU
// 路由") calls for a thermal twin that distinguishes per-compute-tier
// pressure (CPU vs GPU vs NPU) instead of the single scalar
// `BASThermalTwin` ships today. The scalar twin cannot express
// "CPU is hot but the ANE is cold, so scout can still run on ANE
// while core must defer" — a distinction iOS devices routinely
// expose through IOKit pressure signals.
//
// M102 lands the **typed surface** (per-tier reading, snapshot,
// router) as pure value types + pure functions. Platform integration
// (IOKit pressure read, ProcessInfo CPU thermal, Metal/MPS GPU
// signal) belongs in `BASAppleAdapters` and is **out of scope**
// here — the scope discipline mirrors M94 / M101 (schema + pure
// runner first; composition-layer wiring second).

// MARK: - BASComputeTier

/// The three compute tiers Apple Silicon SoCs expose as distinct
/// thermal / power domains. Stable raw values let cross-layer
/// consumers key on the string without importing the substrate.
public enum BASComputeTier:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// Traditional CPU performance / efficiency cores. Hottest
    /// under dense language-model decoding with CoreML CPU fallback.
    case cpu = "cpu"
    /// GPU / Metal compute. Intermediate thermal cost; heats on
    /// MPS matmul-heavy workloads.
    case gpu = "gpu"
    /// Apple Neural Engine (ANE). Coolest per-token cost under
    /// quantized model inference; the primary thermal sink only
    /// under sustained large-model workloads.
    case npu = "npu"
}

// MARK: - BASComputeTierThermalReading

/// One per-tier thermal snapshot. `level` is the qualitative
/// bucket (shared vocabulary with scalar `BASThermalTwin`), and
/// `headroom` is a normalized [0, 1] "how much more work this tier
/// can absorb before throttling" signal —— 1.0 = cool and ready,
/// 0.0 = already at thermal ceiling.
public struct BASComputeTierThermalReading:
    Sendable, Equatable, Codable, Hashable
{
    public let tier: BASComputeTier
    public let level: BASThermalLevel
    /// Normalized headroom in [0, 1]. Clamped on init.
    public let headroom: Double
    public let observedAt: Date

    public init(
        tier: BASComputeTier,
        level: BASThermalLevel,
        headroom: Double,
        observedAt: Date
    ) {
        self.tier = tier
        self.level = level
        self.headroom = Self.clamp(headroom)
        self.observedAt = observedAt
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

// MARK: - BASComputeTierThermalSnapshot

/// A bundle of three per-tier readings (one for each
/// `BASComputeTier`) captured at the same instant. The router uses
/// the full snapshot so decisions account for cross-tier pressure
/// correlations (e.g. CPU hot + GPU warm = shift to ANE-only).
public struct BASComputeTierThermalSnapshot:
    Sendable, Equatable, Codable, Hashable
{
    public let readings: [BASComputeTierThermalReading]
    public let snapshotAt: Date

    public init(
        readings: [BASComputeTierThermalReading],
        snapshotAt: Date
    ) {
        self.readings = readings
        self.snapshotAt = snapshotAt
    }

    /// Lookup for a specific tier. Nil if the snapshot did not
    /// include that tier (useful for partial snapshots on devices
    /// that cannot sample all three).
    public func reading(
        for tier: BASComputeTier
    ) -> BASComputeTierThermalReading? {
        readings.first { $0.tier == tier }
    }

    /// The coolest (highest headroom) tier in the snapshot.
    /// Returns nil for empty snapshots. Ties broken by insertion
    /// order.
    public var coolestTier: BASComputeTier? {
        readings.max(by: { $0.headroom < $1.headroom })?.tier
    }

    /// The hottest (lowest headroom) tier in the snapshot.
    /// Returns nil for empty snapshots. Ties broken by insertion
    /// order.
    public var hottestTier: BASComputeTier? {
        readings.min(by: { $0.headroom < $1.headroom })?.tier
    }
}

// MARK: - BASComputeRouter

/// Pure-function router that picks a `BASComputeTier` for a given
/// organ / role / snapshot.
///
/// Today's routing doctrine (deliberately simple — expansion point
/// as real IOKit signals come online in `BASAppleAdapters`):
///
/// 1. **Strict-floor filter**: any tier whose `headroom < minHeadroom`
///    is disqualified. Default `minHeadroom = 0.1` — below that,
///    scheduling onto the tier is actively harmful.
/// 2. **Preferred order**: the caller passes a preferred order
///    `[.npu, .gpu, .cpu]` (default for Apple Silicon LLM workloads)
///    — the first preferred tier still above the floor wins.
/// 3. **Fallback**: if every preferred tier is below the floor,
///    return the coolest available tier even if it is below the
///    floor — the workload has to land somewhere, better the
///    hottest-free than nothing.
/// 4. **Empty snapshot**: nil — the caller must treat this as "no
///    compute available this turn" and defer.
///
/// Pure function by design: same snapshot + same preferences →
/// same tier, no hidden state, no I/O.
public struct BASComputeRouter: Sendable {
    public let preferredOrder: [BASComputeTier]
    public let minHeadroom: Double

    public init(
        preferredOrder: [BASComputeTier] = [.npu, .gpu, .cpu],
        minHeadroom: Double = 0.1
    ) {
        self.preferredOrder = preferredOrder
        self.minHeadroom = min(1, max(0, minHeadroom))
    }

    /// Decide which tier this workload should land on given the
    /// current per-tier thermal snapshot.
    ///
    /// - Parameter snapshot: live per-tier reading bundle.
    /// - Returns: the tier the router selects, or `nil` when the
    ///   snapshot is empty.
    public func route(
        snapshot: BASComputeTierThermalSnapshot
    ) -> BASComputeTier? {
        guard !snapshot.readings.isEmpty else { return nil }

        // First pass: preferred order, strict headroom floor.
        for tier in preferredOrder {
            guard let reading = snapshot.reading(for: tier) else {
                continue
            }
            if reading.headroom >= minHeadroom {
                return tier
            }
        }

        // Fallback: every preferred tier is below floor. Return
        // the coolest tier in the snapshot so the workload can
        // still make progress rather than stalling.
        return snapshot.coolestTier
    }
}
