// MARK: - BASMetalSubstrateBundleAdoptions
// chapter 四百八十三 / M1308 — batch ships 3 NEW
// BASBundle<Item> typealias adoptions in one file
// (efficient sprawl-migration count growth)。
//
// Brings BASBundle adoption count from 3 → 6:
//   - M1281 BASKernelDispatchOutcomeBundle      (1st)
//   - M1286 BASMPSGraphKernelCoverageBundle     (2nd)
//   - M1297 BASMPSGraphCacheObservationBundle   (3rd)
//   - M1308 BASKernelKeyRegistryBundle          (4th — this)
//   - M1308 BASTensorBackingKindObservationBundle (5th)
//   - M1308 BASNeuralOpInvocationBundle         (6th)

import Foundation
import BASRuntimeCore

// MARK: - 4th adoption: BASKernelKeyRegistryBundle

/// Typed item:one registered kernel key + its op +
/// dtype + backing kind triplet。
public struct BASKernelKeyRegistryBundleItem:
    Equatable, Hashable, Codable, Sendable
{
    public let key: BASKernelKey
    public let registeredAtMs: Int64

    public init(
        key: BASKernelKey,
        registeredAtMs: Int64
    ) {
        self.key = key
        self.registeredAtMs = registeredAtMs
    }
}

/// 4th REAL BASBundle<Item> typealias migration —
/// snapshot of registered kernel keys with timestamps。
public typealias BASKernelKeyRegistryBundle =
    BASBundle<BASKernelKeyRegistryBundleItem>

// MARK: - 5th adoption: BASTensorBackingKindObservationBundle

/// Typed item:one observation of a tensor backing-kind
/// dispatch attempt。
public struct BASTensorBackingKindObservationItem:
    Equatable, Hashable, Codable, Sendable
{
    public let backingKind: BASTensorBackingKind
    public let observationSequence: Int

    public init(
        backingKind: BASTensorBackingKind,
        observationSequence: Int
    ) {
        self.backingKind = backingKind
        self.observationSequence = observationSequence
    }
}

/// 5th REAL BASBundle<Item> typealias migration —
/// tracks which tensor backings are exercised per turn。
public typealias BASTensorBackingKindObservationBundle =
    BASBundle<BASTensorBackingKindObservationItem>

// MARK: - 6th adoption: BASNeuralOpInvocationBundle

/// Typed item:one neural-op invocation outcome record。
public struct BASNeuralOpInvocationItem:
    Equatable, Hashable, Codable, Sendable
{
    public let op: BASNeuralOp
    public let executionNanos: UInt64
    public let succeeded: Bool

    public init(
        op: BASNeuralOp,
        executionNanos: UInt64,
        succeeded: Bool
    ) {
        self.op = op
        self.executionNanos = executionNanos
        self.succeeded = succeeded
    }
}

/// 6th REAL BASBundle<Item> typealias migration —
/// per-turn aggregate of neural-op invocation outcomes。
public typealias BASNeuralOpInvocationBundle =
    BASBundle<BASNeuralOpInvocationItem>

extension BASBundle
    where Item == BASNeuralOpInvocationItem
{
    /// Total successful invocation count。
    public var successfulInvocationCount: Int {
        items.filter { $0.succeeded }.count
    }

    /// Sum of executionNanos across all invocations。
    public var totalExecutionNanos: UInt64 {
        items.reduce(UInt64(0)) {
            $0 &+ $1.executionNanos
        }
    }
}
