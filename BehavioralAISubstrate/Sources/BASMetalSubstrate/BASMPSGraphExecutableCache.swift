// MARK: - BASMPSGraphExecutableCache
// chapter 四百八十 / M1297 — closes MPSGraph build-
// overhead gap exposed at chapter 476 M1280 doctrine:
//
//   > "Build the rmsNorm graph fresh per call (graphs
//   >  are lightweight + caching them across batch
//   >  sizes is a future optimization in chapter 451+)"
//
// Every MPSGraph kernel today builds a fresh graph per
// `evaluate()` call。 Graph compilation (device IR
// generation, op fusion, MTL pipeline state caching)
// dominates per-call latency for small dispatches — 1-3
// ms per kernel invoke on M-series GPU。 For batch size
// sweeps where shapes are reused across many calls,
// caching the compiled graph eliminates this overhead。
//
// ## What this ships (M1297)
//
//   - `BASMPSGraphCacheKey` — typed cache key combining
//     (operation, dataType, ordered input shapes)。
//     Hashable + Sendable for cross-actor lookup。
//   - `BASMPSGraphExecutableCache` actor — typed
//     observation of cache hits/misses + hit-ratio
//     accessor for scheduler tuning + audit replay
//     evidence。
//   - `BASMPSGraphCacheObservationBundle` —
//     `BASBundle<BASMPSGraphCacheHitObservationItem>`
//     third real BASBundle<Item> typealias migration
//     (after M1281 KernelDispatchOutcomeBundle + M1286
//     KernelCoverageBundle)
//
// ## Why this is observation-first
//
// M1297 SHIPS THE OBSERVATION LAYER。 Kernels track their
// own cached graphs internally — the cache type here is
// for cross-kernel hit-ratio aggregation。 M1298 ships
// the matMul kernel wired to use this observation layer
// + measure speedup against the M1277 baseline。
//
// Honest scope:per-kernel graph caching is medium-risk
// (kernel actor + non-Sendable MPSGraph + thread safety
// concerns)。 Observation layer first reduces the blast
// radius — if the matMul wiring breaks, the observation
// layer survives intact for future kernels to adopt
// incrementally。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed cache key + typed
//     bundle item
//   - chapter 二百一一 — single source-of-truth for
//     MPSGraph cache observation
//   - chapter 三百九二 — Codable + sortedKeys JSON
//     replay-determinism preserved
//   - chapter 四百二十九 — 3rd real BASBundle<Item>
//     adoption (sprawl migration progress)
//   - chapter 四百七十六 — first BASBundle migration
//     pattern
//   - ADR-014 OPT-IN — purely additive
//   - 红线 7 — cache is observation, not commitment

import Foundation
import BASRuntimeCore
@preconcurrency import MetalPerformanceShadersGraph

// MARK: - Typed cache key

/// Typed cache key for MPSGraph executable caching。
/// Combines (operation, dataType, ordered input shapes)
/// so a single key identifies every unique MPSGraph
/// build configuration。
public struct BASMPSGraphCacheKey:
    Equatable, Hashable, Codable, Sendable
{

    /// The neural op the cached graph implements。
    public let operation: BASNeuralOp

    /// Element dtype of the cached graph。 Same op +
    /// different dtype → different cache entry。
    public let dataType: BASTensorDataType

    /// Ordered list of input tensor shapes。 Same op +
    /// dtype + different shapes → different cache entry
    /// (each shape combination compiles separately
    /// inside MPSGraph)。
    public let inputShapes: [[Int]]

    public init(
        operation: BASNeuralOp,
        dataType: BASTensorDataType,
        inputShapes: [[Int]]
    ) {
        self.operation = operation
        self.dataType = dataType
        self.inputShapes = inputShapes
    }
}

// MARK: - Typed observation item

/// One entry in a `BASMPSGraphCacheObservationBundle` —
/// pins a single cache lookup outcome (hit or miss) for
/// scheduler tuning + audit replay evidence。
public struct BASMPSGraphCacheHitObservationItem:
    Equatable, Hashable, Codable, Sendable
{

    /// The key looked up。
    public let key: BASMPSGraphCacheKey

    /// True if the lookup found a cached graph;false if
    /// it triggered a fresh build。
    public let wasHit: Bool

    /// Monotonic sequence index within the observation
    /// session (0-based)。 Replay-determinism via
    /// chapter 三百九二。
    public let sequenceIndex: Int

    public init(
        key: BASMPSGraphCacheKey,
        wasHit: Bool,
        sequenceIndex: Int
    ) {
        self.key = key
        self.wasHit = wasHit
        self.sequenceIndex = sequenceIndex
    }
}

// MARK: - Generic bundle alias (3rd real adoption)

/// THIRD real `BASBundle<Item>` typealias migration in
/// the substrate (after M1281
/// BASKernelDispatchOutcomeBundle + M1286
/// BASMPSGraphKernelCoverageBundle)。 Aggregates per-
/// session MPSGraph cache hit/miss observations。
public typealias BASMPSGraphCacheObservationBundle =
    BASBundle<BASMPSGraphCacheHitObservationItem>

extension BASBundle
    where Item == BASMPSGraphCacheHitObservationItem
{
    public var hitCount: Int {
        items.filter { $0.wasHit }.count
    }
    public var missCount: Int {
        items.filter { !$0.wasHit }.count
    }
    public var hitRatio: Double {
        guard !items.isEmpty else { return 0 }
        return Double(hitCount) / Double(items.count)
    }
}

// MARK: - Cache observation actor

/// Actor owning per-kernel-instance MPSGraph cache
/// observation state。 Each kernel records hits + misses
/// here via `recordHit(key:)` / `recordMiss(key:)`。
/// Audit replay + scheduler tuning consume the
/// aggregated bundle via `bundle()`。
///
/// chapter 三百九二 replay-determinism:hits + misses
/// are recorded in sequential order;the bundle's
/// sequenceIndex preserves invocation ordering。
public actor BASMPSGraphExecutableCache {

    private var observations:
        [BASMPSGraphCacheHitObservationItem] = []
    private var nextSequenceIndex: Int = 0

    /// M2033 chapter 六百六十四 第一刀:per-key compiled
    /// `MPSGraphExecutable` storage slot。 Kernel actors
    /// consult `cachedExecutable(forKey:)` first;on miss
    /// they compile a fresh executable and call
    /// `storeExecutable(_:forKey:)` to amortize across
    /// subsequent dispatches。 Non-Sendable executable
    /// references stay isolated to this actor — kernel
    /// callers always go through `async` accessors。
    private var executables:
        [BASMPSGraphCacheKey: MPSGraphExecutable] = [:]

    public init() {}

    // MARK: - M2033 MPSGraphExecutable storage slot

    /// Look up a compiled executable for the given key。
    /// Returns nil on cache miss — caller should compile
    /// the executable and `storeExecutable(_:forKey:)` it。
    public func cachedExecutable(
        forKey key: BASMPSGraphCacheKey
    ) -> MPSGraphExecutable? {
        return executables[key]
    }

    /// Store a compiled executable under the given key。
    /// Subsequent `cachedExecutable(forKey:)` calls with
    /// the same key return this executable instead of
    /// recompiling。 Per-thermal-state-cache-key contract
    /// per chapter 二百四:callers compose the thermal
    /// band into the cache key when thermal-sensitive
    /// pipelines must invalidate on transitions。
    public func storeExecutable(
        _ executable: MPSGraphExecutable,
        forKey key: BASMPSGraphCacheKey
    ) {
        executables[key] = executable
    }

    /// Number of compiled executables stored。 Useful
    /// for tests asserting "1000 dispatches with 7 unique
    /// shapes left 7 executables in the cache"。
    public var executableCount: Int {
        return executables.count
    }

    /// Record a cache hit for the given key。
    public func recordHit(
        key: BASMPSGraphCacheKey
    ) {
        observations.append(
            BASMPSGraphCacheHitObservationItem(
                key: key,
                wasHit: true,
                sequenceIndex: nextSequenceIndex))
        nextSequenceIndex += 1
    }

    /// Record a cache miss for the given key。
    public func recordMiss(
        key: BASMPSGraphCacheKey
    ) {
        observations.append(
            BASMPSGraphCacheHitObservationItem(
                key: key,
                wasHit: false,
                sequenceIndex: nextSequenceIndex))
        nextSequenceIndex += 1
    }

    /// Total hits observed since construction or last
    /// reset。
    public var hitCount: Int {
        observations.filter { $0.wasHit }.count
    }

    /// Total misses observed since construction or last
    /// reset。
    public var missCount: Int {
        observations.filter { !$0.wasHit }.count
    }

    /// Total cache lookups observed。
    public var totalLookups: Int { observations.count }

    /// Hit ratio。 Returns 0 when no lookups recorded
    /// (avoids divide-by-zero)。
    public var hitRatio: Double {
        guard !observations.isEmpty else { return 0 }
        return Double(hitCount)
            / Double(observations.count)
    }

    /// Snapshot the current observation set as a typed
    /// `BASMPSGraphCacheObservationBundle`。 Used by
    /// audit replay + scheduler tuning consumers。
    public func bundle(
        bundleID: String = UUID().uuidString
    ) -> BASMPSGraphCacheObservationBundle {
        return BASMPSGraphCacheObservationBundle(
            bundleID: bundleID,
            schemaVersion: "1.0.0",
            items: observations,
            metadata: [
                "cache-purpose": "mpsgraph-executable"
            ],
            recordedAt: Date(
                timeIntervalSince1970: 1_704_067_200))
    }

    /// Reset the observation set + drop compiled
    /// executables。 Useful for tests + per-turn cache
    /// instrumentation that wants fresh counters per turn
    /// + GPU memory release on thermal-state transitions。
    public func reset() {
        observations.removeAll()
        nextSequenceIndex = 0
        executables.removeAll()
    }
}
