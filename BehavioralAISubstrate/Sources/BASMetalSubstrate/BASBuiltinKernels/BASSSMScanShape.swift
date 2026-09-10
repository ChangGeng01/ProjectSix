// MARK: - BASSSMScanShape
// chapter 六百七十七 / M2087 第三刀 — typed Swift struct
//                                    mirroring MSL
//                                    SSMScanShape with
//                                    3 contiguous uint
//                                    layout for upload
//                                    to MTLBuffer
//
// ## Why this exists
//
// The chapter 六百七十七 / M2085 SSMScan.metal kernel
// accepts a shape struct via buffer(6):
//
//     struct SSMScanShape {
//         uint B;
//         uint L;
//         uint D;
//     };
//
// To upload this struct from Swift,we need a Swift-side
// type with EXACTLY the same memory layout:3 contiguous
// 32-bit unsigned integers,no padding,no struct
// alignment surprises。 `BASSSMScanShape` is that mirror。
//
// We use `UInt32` (Swift) instead of `Int` because
// `uint` in MSL is 32-bit unsigned across all Apple
// Silicon GPUs。 Mismatch (e.g. Int = 64-bit on macOS)
// would silently corrupt buffer(6) reads。
//
// ## Layout PROOF
//
// MemoryLayout<BASSSMScanShape>.size == 12 bytes
//   (3 UInt32 fields × 4 bytes each,no padding because
//    all fields are same-aligned 4-byte primitives)
// MemoryLayout<BASSSMScanShape>.stride == 12 bytes
// MemoryLayout<BASSSMScanShape>.alignment == 4 bytes
//
// Anti-drift PROOF tests at BASSSMScanShapeAntiDriftTests
// (sibling test file) verify these layout invariants。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed shape struct (no magic
//     integer triples scattered through kernel call sites)
//   - chapter 三百九二 — Codable for replay-determinism
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive typed surface)
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Swift-side mirror of the MSL `SSMScanShape` struct used
/// as buffer(6) in the chapter 六百七十七 / M2085 SSMScan
/// .metal compute kernel。
///
/// Memory layout:3 contiguous `UInt32` fields = 12 bytes
/// total。 No padding,no alignment surprises (all fields
/// same-aligned 4-byte primitives)。
///
/// Validated at construction:every field must be > 0
/// (zero-sized dispatch is undefined behavior;the kernel
/// returns early on out-of-grid threads but a zero
/// extent collapses the dispatch grid to empty)。
public struct BASSSMScanShape:
    Equatable, Hashable, Sendable, Codable
{
    /// Batch dimension。 Must be > 0。
    public let B: UInt32

    /// Sequence length dimension。 Must be > 0。
    public let L: UInt32

    /// Channel dimension。 Must be > 0。
    public let D: UInt32

    /// Construct a shape triple。 Precondition:every
    /// dimension must be strictly positive。 Use the
    /// `validated(...)` factory below if you need a
    /// throwing version (e.g. parsing from user input)。
    public init(B: UInt32, L: UInt32, D: UInt32) {
        precondition(B > 0, "BASSSMScanShape.B must be > 0")
        precondition(L > 0, "BASSSMScanShape.L must be > 0")
        precondition(D > 0, "BASSSMScanShape.D must be > 0")
        self.B = B
        self.L = L
        self.D = D
    }

    // MARK: - Derived shape metrics

    /// Total element count = B × L × D。 Useful for sizing
    /// the input/output payload Data lengths。
    public var elementCount: Int {
        return Int(B) * Int(L) * Int(D)
    }

    /// Per-element byte count for the float32 variant of
    /// the kernel。
    public static let bytesPerElement: Int = 4  // Float32

    /// Byte count of the (B, L, D) payload Data for x/
    /// delta/B/C/y buffers。
    public var payloadByteCount: Int {
        return elementCount * Self.bytesPerElement
    }

    /// Byte count of the A buffer (shape (D,))。
    public var aBufferByteCount: Int {
        return Int(D) * Self.bytesPerElement
    }

    // MARK: - Throwing validated factory

    /// Throwing factory that validates (B, L, D) without
    /// trapping。 Use when constructing from user input。
    public static func validated(
        B: UInt32, L: UInt32, D: UInt32
    ) throws -> BASSSMScanShape {
        if B == 0 || L == 0 || D == 0 {
            throw BASSSMScanShapeError.zeroDimension(
                B: B, L: L, D: D)
        }
        return BASSSMScanShape(B: B, L: L, D: D)
    }

    // MARK: - Linear index helper

    /// Row-major linear index for (b, t, d)。 Matches the
    /// MSL kernel's `((b * L) + t) * D + d` formula。
    public func linearIndex(b: Int, t: Int, d: Int) -> Int {
        return ((b * Int(L)) + t) * Int(D) + d
    }
}

// MARK: - Typed error

/// Typed error for `BASSSMScanShape.validated(...)` factory
/// failures。
public enum BASSSMScanShapeError:
    Error, Equatable, Sendable, Codable
{
    case zeroDimension(B: UInt32, L: UInt32, D: UInt32)
}
