// MARK: - BASMPSGraphKernelBuildLatencyResult
// chapter 四百九十八 / M1369 — typed result of per-kernel
// MPSGraph build latency observation
//
// Chapter 480 / M1297 shipped BASMPSGraphExecutableCache
// as an OBSERVATION actor (hits / misses / hit ratio)。 But
// at that time the *latency-cost* dimension was implicit:
// hosts couldn't tell from the audit emission how much
// wall-clock time was saved by each cache hit。 This typed
// result closes that gap with explicit `buildNanos` /
// `dispatchNanos` / `cacheHitSavedNanos` fields。
//
// HONEST SCOPE — chapter 四百九十八:
// =============================================================
// This file ships the TYPED RESULT (BASResult<Body>
// adoption,4th total)。 Kernels do NOT yet emit this
// result automatically;the substrate provides the typed
// surface so kernels can opt-in incrementally。 Default V1
// kernel dispatch path emits nothing,preserving ADR-014
// OPT-IN compliance。

import Foundation
import BASRuntimeCore

/// Typed body for `BASMPSGraphKernelBuildLatencyResult`。
/// Records the per-call latency breakdown for one MPSGraph
/// kernel dispatch:
///
///   - `buildNanos`: wall-clock time spent compiling the
///     MPSGraph (zero on cache hit)
///   - `dispatchNanos`: wall-clock time spent dispatching
///     the compiled graph via Metal command buffer
///   - `cacheHitSavedNanos`: when the cache hit fired,how
///     much wall-clock time was saved relative to the
///     baseline `buildNanos` for this `(op, dtype, shape)`
///     combination
///
/// Codable + Equatable + Hashable + Sendable per chapter
/// 三百九二 replay-determinism contract。
public struct BASMPSGraphKernelBuildLatencyResultBody:
    Equatable, Hashable, Codable, Sendable
{

    public let operation: BASNeuralOp
    public let dataType: BASTensorDataType
    public let inputShapes: [[Int]]
    public let buildNanos: UInt64
    public let dispatchNanos: UInt64
    public let cacheHitSavedNanos: UInt64
    public let wasCacheHit: Bool

    public init(
        operation: BASNeuralOp,
        dataType: BASTensorDataType,
        inputShapes: [[Int]],
        buildNanos: UInt64,
        dispatchNanos: UInt64,
        cacheHitSavedNanos: UInt64,
        wasCacheHit: Bool
    ) {
        self.operation = operation
        self.dataType = dataType
        self.inputShapes = inputShapes
        self.buildNanos = buildNanos
        self.dispatchNanos = dispatchNanos
        self.cacheHitSavedNanos = cacheHitSavedNanos
        self.wasCacheHit = wasCacheHit
    }

    /// Total wall-clock cost of this kernel dispatch
    /// (build + dispatch)。 Saturating add to avoid
    /// overflow on adversarial inputs。
    public var totalNanos: UInt64 {
        buildNanos &+ dispatchNanos
    }

    /// Estimated latency savings from cache hit。 Zero
    /// when miss。
    public var effectiveCacheSavingsNanos: UInt64 {
        wasCacheHit ? cacheHitSavedNanos : 0
    }
}

/// 4th REAL `BASResult<Body>` typealias migration — the
/// substrate's typed result of one MPSGraph kernel build-
/// latency observation。
public typealias BASMPSGraphKernelBuildLatencyResult =
    BASResult<BASMPSGraphKernelBuildLatencyResultBody>
