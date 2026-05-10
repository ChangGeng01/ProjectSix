// MARK: - BASKernelKey — chapter 四百三十一 / M1098
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase E middle-late entry。 Typed
// lookup key for the kernel registry。
//
// ## Why this exists (system entropy framing)
//
// `BASMetalKernelRegistry` (the actor that owns the kernel
// dispatch table) needs a Sendable + Hashable lookup key
// that names "which kernel implements which neural op for
// which dtype + backing combination"。 Without a typed key
// the registry would key by raw `String` — exactly the
// magic-number anti-pattern chapter 一百八十五 forbids。
//
// `BASKernelKey` carries:
//   - the `BASNeuralOp` the kernel implements
//   - the `BASTensorDataType` it operates on
//   - the `BASTensorBackingKind` it expects for inputs
//
// Same op + dtype + backing → same key → same kernel slot
// in the registry。 Multiple registrations under the same
// key replace (chapter 二百一一 single source-of-truth)。
//
// ## What this ships (M1098)
//
//   - `BASKernelKey` Sendable + Hashable + Codable struct
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number。 Lookup key is
//     typed,not a raw `String`。
//   - chapter 二百一一 — single source-of-truth。 One key
//     shape;all registrations + lookups consume it。
//   - chapter 三百九二 — replay-determinism。 Codable via
//     String-rawvalue components。
//   - ADR-014 OPT-IN — purely additive。

import Foundation

/// Typed lookup key for the kernel registry。 Names the
/// `(operation, dataType, backingKind)` triple that
/// uniquely identifies a kernel slot。
public struct BASKernelKey:
    Equatable, Hashable, Codable, Sendable
{

    /// The neural op this kernel implements。
    public let operation: BASNeuralOp

    /// The element dtype this kernel operates on。
    public let dataType: BASTensorDataType

    /// The backing kind this kernel expects for its
    /// input tensors。 (Output backing is the kernel's
    /// choice — recorded in `BASKernelOutputs`。)
    public let backingKind: BASTensorBackingKind

    public init(
        operation: BASNeuralOp,
        dataType: BASTensorDataType,
        backingKind: BASTensorBackingKind
    ) {
        self.operation = operation
        self.dataType = dataType
        self.backingKind = backingKind
    }

    /// Compose a stable wire-form identifier for this key
    /// (e.g. for log lines + observability)。 Format:
    /// `"<op>|<dtype>|<backing>"`。
    public var wireFormIdentifier: String {
        return "\(operation.rawValue)" +
            "|\(dataType.rawValue)" +
            "|\(backingKind.rawValue)"
    }
}
