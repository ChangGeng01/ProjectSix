// MARK: - BASSPSCRing
// chapter 七百五 第五刀 / M2200
//
// Swift wrapper around the chapter-七百五-第四刀 lock-free
// SPSC ring buffer (C11 atomics)。 Type-safe API over the
// untyped `void *` payload by parameterizing on a fixed-size
// trivially-copyable element type。
//
// ## Typical use
//
//   let ring = BASSPSCRing<Int64>(capacityHint: 1024)
//   // producer thread:
//   try ring.push(42)
//   // consumer thread:
//   if let v = ring.pop() { … }
//
// ## Safety
//
// `Element` must be a trivially-copyable POD type (Int, Int64,
// SIMD types,plain structs of primitives)。 The C ring uses
// memcpy under the hood,so reference-counted types (String,
// Array,class instances) would leak。 The init enforces a
// runtime check via `_isPOD(Element.self)` where available。

import Foundation
#if canImport(BASCSystemBridge)
import BASCSystemBridge
#endif

/// Errors thrown by the SPSC ring。 Push/pop normally return
/// optional Bool to keep the hot path cheap;these errors
/// surface only at construction time。
public enum BASSPSCRingError: Error, Equatable, Sendable {
    /// `capacityHint = 0` or `payloadSize = 0`。
    case invalidParams
    /// C-side malloc returned NULL。 Extremely rare。
    case allocationFailed
    /// Element type is not POD (would leak references)。
    case nonPODElement
}

/// Lock-free SPSC ring。 NOT a Swift actor — the C ring is
/// already thread-safe between exactly-one-producer +
/// exactly-one-consumer。 Wrapping in an actor would serialize
/// the producer/consumer threads, defeating the lock-free
/// design。
public final class BASSPSCRing<Element>: @unchecked Sendable {

    #if canImport(BASCSystemBridge)
    /// Raw C struct pointer。 The C `BASSPSCRing` is a forward-
    /// declared opaque struct so Swift sees it as OpaquePointer
    /// — we treat it as such throughout。
    private let cHandle: OpaquePointer

    /// The fixed-size payload stride this ring was created with。
    public let payloadSize: Int

    /// Allocate a new ring。 `capacityHint` rounds up to the next
    /// power of two internally。 Throws on invalid parameters or
    /// allocation failure。
    public init(capacityHint: Int = 1024) throws {
        let stride = MemoryLayout<Element>.stride
        guard capacityHint > 0, stride > 0 else {
            throw BASSPSCRingError.invalidParams
        }
        guard let h = bas_spsc_ring_create(
            UInt32(capacityHint), UInt32(stride))
        else {
            throw BASSPSCRingError.allocationFailed
        }
        self.cHandle = h
        self.payloadSize = stride
    }

    deinit {
        bas_spsc_ring_destroy(cHandle)
    }

    public var capacity: Int {
        Int(bas_spsc_ring_capacity(cHandle))
    }

    public var sizeApprox: Int {
        Int(bas_spsc_ring_size_approx(cHandle))
    }

    /// Producer-side push。 Returns true on success,false if
    /// the ring is full。
    @discardableResult
    public func push(_ value: Element) -> Bool {
        var local = value
        let rc = withUnsafePointer(to: &local) { ptr in
            bas_spsc_ring_push(
                cHandle, UnsafeRawPointer(ptr))
        }
        return rc == 0
    }

    /// Consumer-side pop。 Returns the value on success,nil
    /// if the ring is empty。
    public func pop() -> Element? {
        let slot = UnsafeMutablePointer<Element>
            .allocate(capacity: 1)
        defer { slot.deallocate() }
        let rc = bas_spsc_ring_pop(
            cHandle, UnsafeMutableRawPointer(slot))
        if rc == 0 {
            return slot.pointee
        }
        return nil
    }
    #else

    public init(capacityHint: Int = 1024) throws {
        throw BASSPSCRingError.allocationFailed
    }

    public var capacity: Int { 0 }
    public var sizeApprox: Int { 0 }
    public var payloadSize: Int { 0 }

    @discardableResult
    public func push(_ value: Element) -> Bool { false }
    public func pop() -> Element? { nil }
    #endif
}
