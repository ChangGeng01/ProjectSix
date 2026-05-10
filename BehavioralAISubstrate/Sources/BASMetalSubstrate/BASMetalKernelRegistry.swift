// MARK: - BASMetalKernelRegistry — chapter 四百三十一 / M1098
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E middle-late entry。
// Actor-owned kernel dispatch table。
//
// ## Why this exists (system entropy framing)
//
// Today the substrate has zero unified kernel dispatch
// table。 Every adapter (BASMLXAdapter / future
// BASCoreMLAdapter / future raw-Metal kernels) holds its
// own ad-hoc lookup,leading to:
//   - duplicated kernel registrations across modules
//   - no central observability for "which op uses which
//     backend right now"
//   - no compile-time + runtime guard against missing
//     kernels for `(op, dtype, backing)` triples
//
// `BASMetalKernelRegistry` ships the actor-owned dispatch
// table:single source-of-truth (chapter 二百一一) for
// kernel registration + lookup + dispatch。 The hardware-
// aware scheduler (M1102) consults the registry for
// "which backings does this op support on this device"
// rather than asking each adapter individually。
//
// ## What this ships (M1098)
//
//   - `public actor BASMetalKernelRegistry`
//   - `register(_:)` adds / replaces a kernel by its key
//   - `kernel(for:)` returns the kernel matching a key
//     (or nil if unregistered)
//   - `kernels(forOperation:)` returns all registered
//     kernels for a given `BASNeuralOp`
//   - `dispatch(key:inputs:)` async dispatch facade
//     (returns `BASKernelDispatchResult` with output
//     bundle + key + observability fields)
//   - `registeredKeys` snapshot accessor for tests +
//     observability
//
// ## Doctrine pins held
//
//   - chapter 二百一一 — single source-of-truth (one
//     registry actor;all dispatches go through it)
//   - chapter 三百九二 — replay-determinism (registry
//     state is purely a dictionary of Sendable kernels;
//     dispatch outputs are Sendable bundles)
//   - chapter 一百八十五 — anti-magic-number (typed key,
//     typed dispatch result)
//   - ADR-014 OPT-IN — purely additive (no V1 hot path
//     consults the registry yet;M1102 scheduler will
//     be the first consumer)
//   - 红线 7 — hint-only (registry dispatch emits
//     observation,not commitment)

import Foundation

// MARK: - Dispatch result envelope

/// Sendable envelope returned from
/// `BASMetalKernelRegistry.dispatch(...)`。 Bundles the
/// kernel's output with the routing metadata so callers
/// can verify which kernel ran without holding a separate
/// reference。
public struct BASKernelDispatchResult:
    Equatable, Hashable, Sendable
{

    /// The key that routed this dispatch (mirrors the
    /// kernel's `key` property)。
    public let routedKey: BASKernelKey

    /// Output bundle from the kernel。
    public let outputs: BASKernelOutputs

    public init(
        routedKey: BASKernelKey,
        outputs: BASKernelOutputs
    ) {
        self.routedKey = routedKey
        self.outputs = outputs
    }
}

// MARK: - Lookup-failure error

/// Thrown when `BASMetalKernelRegistry.dispatch(...)`
/// receives a key that has no registered kernel。 Distinct
/// from `BASKernelError` (which the kernel itself throws)
/// so callers can disambiguate "no kernel registered" vs
/// "kernel ran + failed"。
public enum BASKernelLookupError: Error, Equatable, Sendable {

    /// No kernel registered for the requested key。
    case noKernelRegistered(key: BASKernelKey)
}

// MARK: - Registry actor

/// Actor-owned kernel dispatch table。 Single source-of-
/// truth for which kernels exist + which backings they
/// expect。
public actor BASMetalKernelRegistry {

    /// Registry storage:`[key: kernel]`。
    private var slots: [BASKernelKey: any BASMetalKernel] = [:]

    /// Build an empty registry。 Kernels are registered
    /// post-construction via `register(_:)`。
    public init() {}

    // MARK: - Registration

    /// Register (or replace) a kernel under its key。
    /// Returns the previously-registered kernel under
    /// that key,if any (so callers can detect overrides)。
    @discardableResult
    public func register(
        _ kernel: any BASMetalKernel
    ) -> (any BASMetalKernel)? {
        let previous = slots[kernel.key]
        slots[kernel.key] = kernel
        return previous
    }

    /// Remove the kernel registered under the given key。
    /// Returns the removed kernel,or nil if no kernel
    /// was registered。
    @discardableResult
    public func unregister(
        key: BASKernelKey
    ) -> (any BASMetalKernel)? {
        return slots.removeValue(forKey: key)
    }

    // MARK: - Lookup

    /// Returns the kernel registered for the given key,
    /// or nil if none。
    public func kernel(
        for key: BASKernelKey
    ) -> (any BASMetalKernel)? {
        return slots[key]
    }

    /// Returns all kernels registered for the given
    /// neural op (across any dtype + backing combination)。
    /// Order is sorted by `key.wireFormIdentifier` for
    /// replay-determinism。
    public func kernels(
        forOperation op: BASNeuralOp
    ) -> [any BASMetalKernel] {
        return slots.values
            .filter { $0.operation == op }
            .sorted {
                $0.key.wireFormIdentifier
                    < $1.key.wireFormIdentifier
            }
    }

    /// Snapshot of all registered keys。 Sorted by
    /// `wireFormIdentifier` for replay-determinism。 Test
    /// + observability seam。
    public var registeredKeys: [BASKernelKey] {
        return slots.keys
            .sorted {
                $0.wireFormIdentifier
                    < $1.wireFormIdentifier
            }
    }

    /// Total number of registered kernels。
    public var kernelCount: Int {
        return slots.count
    }

    // MARK: - Dispatch

    /// Async dispatch facade。 Looks up the kernel for the
    /// given key + invokes its `evaluate(inputs:)` +
    /// wraps the result in a `BASKernelDispatchResult`。
    ///
    /// Throws `BASKernelLookupError.noKernelRegistered` if
    /// no kernel is registered for the key。
    /// Re-throws any `BASKernelError` from the kernel。
    public func dispatch(
        key: BASKernelKey,
        inputs: BASKernelInputs
    ) async throws -> BASKernelDispatchResult {
        guard let kernel = slots[key] else {
            throw BASKernelLookupError
                .noKernelRegistered(key: key)
        }
        let outputs = try await kernel.evaluate(
            inputs: inputs)
        return BASKernelDispatchResult(
            routedKey: key,
            outputs: outputs)
    }
}
