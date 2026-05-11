// MARK: - BASKernelEvaluateLatencyProbe
// chapter 四百九十八 / M1371 — typed instrumentation wrapper
// that adds latency observation around any BASMetalKernel
//
// Bridges:
//   - BASMetalKernel.evaluate(inputs:) → wraps the call
//   - BASMPSGraphKernelBuildLatencyResult (M1369) →
//     emits typed per-call latency observation
//   - BASMPSGraphExecutableCache (M1297) → records the
//     observation as a cache miss (probe doesn't itself
//     cache;it just observes wall-clock)
//
// Pure additive substrate-internal surface。 Hosts wrap
// any BASMetalKernel via:
//
//   let probed = BASKernelEvaluateLatencyProbe(
//       inner: BASMPSGraphRMSNormKernel())
//   let result = try await probed.evaluateAndObserve(
//       inputs: inputs)
//   // result.outputs == inner kernel's outputs
//   // result.latency == typed BASMPSGraphKernelBuildLatencyResult
//
// HONEST SCOPE: this probe does NOT cache compiled
// MPSGraph executables。 It TIMES the call and reports
// wall-clock latency as a typed observation。 Real
// caching (storing compiled graphs in actor-isolated
// state) is a future kernel-internal change deferred
// to Tier 2 phase K or follow-up arc。

import Foundation
import BASRuntimeCore

/// Typed result pair returned by the probe — original
/// kernel outputs + typed latency observation。
public struct BASKernelEvaluateLatencyProbeResult:
    Sendable
{
    public let outputs: BASKernelOutputs
    public let latency: BASMPSGraphKernelBuildLatencyResult

    public init(
        outputs: BASKernelOutputs,
        latency: BASMPSGraphKernelBuildLatencyResult
    ) {
        self.outputs = outputs
        self.latency = latency
    }
}

/// Typed instrumentation wrapper around any BASMetalKernel。
/// Forwards `evaluate(inputs:)` to the inner kernel,
/// measuring wall-clock time and emitting a typed
/// BASMPSGraphKernelBuildLatencyResult。
///
/// ACTOR ISOLATION: the probe itself is Sendable (holds
/// only an actor reference + immutable config)。 The
/// inner kernel's actor isolation is preserved。
public struct BASKernelEvaluateLatencyProbe: Sendable {

    private let inner: any BASMetalKernel

    public init(inner: any BASMetalKernel) {
        self.inner = inner
    }

    /// Forward the call to the inner kernel,measuring
    /// wall-clock time。 Returns the inner kernel's
    /// outputs + a typed latency result observation。
    public func evaluateAndObserve(
        inputs: BASKernelInputs
    ) async throws -> BASKernelEvaluateLatencyProbeResult
    {
        let startNanos = DispatchTime.now()
            .uptimeNanoseconds
        let outputs = try await inner.evaluate(
            inputs: inputs)
        let endNanos = DispatchTime.now()
            .uptimeNanoseconds
        let totalNanos = endNanos &- startNanos
        // Probe doesn't separate build from dispatch
        // (would require modifying kernels)。 Reports
        // totalNanos as buildNanos for honest per-call
        // observation;dispatch + cache fields zero。
        let latencyBody =
            BASMPSGraphKernelBuildLatencyResultBody(
                operation: inner.key.operation,
                dataType: inner.key.dataType,
                inputShapes: inputs.descriptors
                    .map(\.shape),
                buildNanos: totalNanos,
                dispatchNanos: 0,
                cacheHitSavedNanos: 0,
                wasCacheHit: false)
        let latencyResult =
            BASMPSGraphKernelBuildLatencyResult(
                success: true,
                body: latencyBody)
        return BASKernelEvaluateLatencyProbeResult(
            outputs: outputs,
            latency: latencyResult)
    }

    /// The inner kernel's typed key — pass-through。
    public var key: BASKernelKey { inner.key }

    /// The inner kernel's typed operation — pass-through。
    public var operation: BASNeuralOp { inner.operation }
}
