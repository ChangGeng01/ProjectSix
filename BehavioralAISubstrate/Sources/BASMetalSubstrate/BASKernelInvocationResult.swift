// MARK: - BASKernelInvocationResult
// chapter 四百八十一 / M1300 — first REAL BASResult<Body>
// typealias migration in the substrate。 Closes part of
// chapter 477 "更极致 / 低熵复杂系统" gap with the
// FIRST production-grade adoption of the BASResult<Body>
// generic primitive (shipped at M1088 / chapter 429 but
// never adopted in production until now)。
//
// Previous BASBundle<Item> adoptions (M1281 + M1286 +
// M1297) proved that ONE generic primitive can carry
// production payload。 M1300 proves the pattern scales
// to a DIFFERENT primitive shape:`BASResult<Body>`
// (success + body + diagnostics)。
//
// ## What this ships (M1300)
//
//   - `BASKernelInvocationResultBody` typed body struct
//     (kernelKey + executionNanos + outputElementCount)
//   - `BASKernelInvocationResult = BASResult<
//     BASKernelInvocationResultBody>` typealias
//   - Convenience accessors on BASResult when Body ==
//     BASKernelInvocationResultBody:
//       - .executionMicroseconds (typed access)
//       - .hasError (boolean derived from .success +
//         .diagnostics)
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed body struct
//   - chapter 二百一一 — single source-of-truth for
//     kernel invocation result envelope
//   - chapter 三百九二 — Codable + sortedKeys JSON
//     stable
//   - chapter 四百二十九 — BASResult<Body> generic
//     primitive finally adopted in production
//   - chapter 四百七十六 first BASBundle adoption +
//     chapter 四百八十 third BASBundle adoption pattern
//     extended to a NEW primitive (BASResult)
//   - ADR-014 OPT-IN — purely additive
//   - 红线 7 — result is observation, not commitment

import Foundation
import BASRuntimeCore

// MARK: - Typed body

/// Typed body for kernel-invocation results。 Carried
/// inside `BASResult<...>` envelope (success flag +
/// diagnostics)。
public struct BASKernelInvocationResultBody:
    Equatable, Hashable, Codable, Sendable
{

    /// The kernel key dispatched。 Mirrors
    /// `BASKernelKey` shape (operation + dataType +
    /// backingKind)。
    public let kernelKey: BASKernelKey

    /// Wall-clock execution time in nanoseconds (matches
    /// `BASKernelOutputs.executionNanos`)。
    public let executionNanos: UInt64

    /// Total element count in output payloads (sum of
    /// `descriptor.elementCount` across all output
    /// descriptors)。
    public let outputElementCount: Int

    public init(
        kernelKey: BASKernelKey,
        executionNanos: UInt64,
        outputElementCount: Int
    ) {
        self.kernelKey = kernelKey
        self.executionNanos = executionNanos
        self.outputElementCount = outputElementCount
    }
}

// MARK: - Generic result alias (1st real adoption)

/// FIRST real `BASResult<Body>` typealias migration in
/// the substrate (after M1088 / chapter 429 generic
/// primitive shipped + 3 BASBundle adoptions M1281 +
/// M1286 + M1297)。 Carries kernel invocation outcome
/// with typed body + success flag + diagnostics。
public typealias BASKernelInvocationResult =
    BASResult<BASKernelInvocationResultBody>

// MARK: - Convenience accessors

extension BASResult
    where Body == BASKernelInvocationResultBody
{

    /// Execution time as microseconds (1e-6 precision)。
    /// Convenience derived from body.executionNanos。
    public var executionMicroseconds: Double {
        return Double(body.executionNanos) / 1000.0
    }

    /// Whether the result indicates an error。 Equivalent
    /// to `!success || !diagnostics.isEmpty`。
    public var hasError: Bool {
        return !success || !diagnostics.isEmpty
    }

    /// Build a typed result from a `BASKernelOutputs` +
    /// the dispatched kernel key。 Computes output element
    /// count + wraps in `BASResult` envelope with
    /// `success: true` and empty diagnostics。
    public static func from(
        outputs: BASKernelOutputs,
        kernelKey: BASKernelKey
    ) -> BASKernelInvocationResult {
        let elementCount = outputs.descriptors
            .reduce(0) { $0 + $1.elementCount }
        let body = BASKernelInvocationResultBody(
            kernelKey: kernelKey,
            executionNanos: outputs.executionNanos,
            outputElementCount: elementCount)
        return BASKernelInvocationResult(
            success: true,
            body: body,
            diagnostics: [])
    }
}
