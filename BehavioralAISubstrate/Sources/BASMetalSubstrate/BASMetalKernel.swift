// MARK: - BASMetalKernel — chapter 四百三十一 / M1098
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E middle-late entry。
// Sendable kernel contract conformed by every kernel
// implementation registered with `BASMetalKernelRegistry`。
//
// ## Why this exists (system entropy framing)
//
// Today the substrate has zero typed kernel contract。
// BASMLXAdapter dispatches via untyped `MLXModel.generate(...)`
// — no shared protocol naming "what inputs / what outputs /
// what fail modes"。 Without a typed contract,every adapter
// reinvents kernel binding + the registry cannot ship a
// uniform dispatch facade。
//
// `BASMetalKernel` is the Sendable contract:
//   - typed key + operation
//   - async `evaluate(inputs:) -> outputs` taking +
//     returning Sendable bundles
//   - typed `BASKernelError` for failure modes
//
// MLX / CoreML / raw MTLBuffer kernels live in higher
// layers (BASMLXAdapter,future BASCoreMLAdapter); they
// conform to this protocol by wrapping their adapter-
// specific dispatch behind the Sendable evaluate seam。
//
// ## What this ships (M1098)
//
//   - `BASMetalKernel` protocol (Sendable)
//   - `BASKernelInputs` Sendable bundle (descriptors +
//     cpu-bytes payloads)
//   - `BASKernelOutputs` Sendable bundle (descriptors +
//     cpu-bytes payloads + nanoseconds elapsed)
//   - `BASKernelError` typed error enum
//
// ## Sendability discipline
//
// Inputs + outputs carry Sendable `Data` payloads,not
// opaque `AnyObject` MTLBuffer/MLMultiArray handles。 GPU-
// resident kernels are wrapped:they accept the cpu-bytes
// path,upload to MTLBuffer inside the kernel's actor-
// isolated context,dispatch,and download the result back
// to cpu-bytes for the Sendable return path。 This costs
// upload/download per-call but makes the kernel testable +
// replay-deterministic without GPU access。 Hot-path kernels
// will ship a separate "GPU-resident handoff" pathway in a
// future commit (chapter 四百三十二+)。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     errors + typed bundles)
//   - chapter 二百一一 — single source-of-truth (one
//     kernel protocol;all registrations conform)
//   - chapter 三百九二 — replay-determinism (Sendable
//     bundles round-trip via cpu-bytes Data)
//   - ADR-014 OPT-IN — purely additive
//   - 红线 7 — hint-only (kernel dispatch is observation
//     emission,not commitment authority)

import Foundation

// MARK: - Sendable input / output bundles

/// Sendable input bundle handed to a kernel。 Each input
/// tensor is paired with its descriptor + raw cpu bytes。
///
/// Inputs are by-value Data so cross-actor + cross-process
/// dispatch is free。 GPU-resident kernels upload to
/// MTLBuffer inside their isolated context。
public struct BASKernelInputs: Equatable, Hashable, Sendable {

    /// Per-input tensor descriptor。 Length must equal
    /// `payloads.count`。
    public let descriptors: [BASTensorDescriptor]

    /// Per-input raw cpu bytes (matching each descriptor's
    /// `byteCount`)。 Length must equal `descriptors.count`。
    public let payloads: [Data]

    public init(
        descriptors: [BASTensorDescriptor],
        payloads: [Data]
    ) {
        precondition(
            descriptors.count == payloads.count,
            "BASKernelInputs descriptors + payloads " +
            "counts must match")
        for (i, desc) in descriptors.enumerated() {
            precondition(
                desc.byteCount == payloads[i].count,
                "BASKernelInputs payload[\(i)] byte count " +
                "(\(payloads[i].count)) must equal " +
                "descriptor.byteCount (\(desc.byteCount))")
        }
        self.descriptors = descriptors
        self.payloads = payloads
    }

    /// Convenience zero-input bundle for kernels that
    /// take no inputs (e.g. constant generators)。
    public static let empty = BASKernelInputs(
        descriptors: [], payloads: [])
}

/// Sendable output bundle returned from a kernel。 Mirrors
/// `BASKernelInputs` shape with an extra `executionNanos`
/// observability field。
public struct BASKernelOutputs: Equatable, Hashable, Sendable {

    /// Per-output tensor descriptor。
    public let descriptors: [BASTensorDescriptor]

    /// Per-output raw cpu bytes。
    public let payloads: [Data]

    /// Wall-clock kernel execution time in nanoseconds。
    /// Used by the hardware-aware scheduler (M1102) to
    /// refine `BASANECapability.estimatedLatencyMs`。
    public let executionNanos: UInt64

    public init(
        descriptors: [BASTensorDescriptor],
        payloads: [Data],
        executionNanos: UInt64
    ) {
        precondition(
            descriptors.count == payloads.count,
            "BASKernelOutputs descriptors + payloads " +
            "counts must match")
        for (i, desc) in descriptors.enumerated() {
            precondition(
                desc.byteCount == payloads[i].count,
                "BASKernelOutputs payload[\(i)] byte " +
                "count (\(payloads[i].count)) must equal " +
                "descriptor.byteCount (\(desc.byteCount))")
        }
        self.descriptors = descriptors
        self.payloads = payloads
        self.executionNanos = executionNanos
    }
}

// MARK: - Typed error enum

/// Typed kernel failure modes。 Returned via `throws` from
/// `BASMetalKernel.evaluate(...)`。
public enum BASKernelError: Error, Equatable, Sendable {

    /// Input bundle did not match the kernel's expected
    /// shape (e.g. wrong rank,wrong dtype,wrong axis size)。
    case shapeMismatch(reason: String)

    /// Input bundle dtype did not match this kernel's
    /// dtype slot in the registry。
    case dataTypeMismatch(
        expected: BASTensorDataType,
        actual: BASTensorDataType)

    /// Required Apple Silicon framework (Metal / MPS /
    /// CoreML) is unavailable on this platform (e.g.
    /// watchOS attempting Metal dispatch)。
    case frameworkUnavailable(framework: String)

    /// Live device dispatch failed (e.g. MTLDevice
    /// command-buffer error)。 Carries an opaque message。
    case deviceDispatchFailure(reason: String)

    /// Kernel is not implemented at this M-number
    /// (placeholder registered but evaluate() not yet
    /// wired)。 Used by stub kernels during phased rollout。
    case notImplemented(operation: BASNeuralOp)
}

// MARK: - Kernel protocol

/// Sendable contract conformed by every kernel registered
/// with `BASMetalKernelRegistry`。
///
/// Kernels are stateless dispatch facades — all per-call
/// state lives in the inputs + outputs bundles。 Kernel
/// instances are themselves Sendable (so the registry can
/// hold them across actor boundaries)。
public protocol BASMetalKernel: Sendable {

    /// Typed lookup key for this kernel。 Used by the
    /// registry to route `(operation, dtype, backing)`
    /// triples to the right slot。
    var key: BASKernelKey { get }

    /// Convenience accessor:`key.operation`。
    var operation: BASNeuralOp { get }

    /// Async dispatch entry point。 Takes a Sendable input
    /// bundle and returns a Sendable output bundle (or
    /// throws a typed `BASKernelError`)。
    ///
    /// Kernels MUST validate their inputs against their
    /// registered key:
    ///   - All `inputs.descriptors[i].dataType` ==
    ///     `key.dataType`
    ///   - All `inputs.descriptors[i].backingKind` ==
    ///     `key.backingKind` (or `.cpuBytes` for
    ///     simulator paths)
    /// Mismatches throw `.dataTypeMismatch` /
    /// `.shapeMismatch`。
    func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs
}

// MARK: - Default protocol implementations

extension BASMetalKernel {

    /// Default `operation` accessor reads from the typed
    /// key — kernel implementations rarely need to
    /// override this。
    public var operation: BASNeuralOp {
        return key.operation
    }
}
