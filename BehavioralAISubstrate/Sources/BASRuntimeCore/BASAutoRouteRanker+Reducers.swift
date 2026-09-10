// MARK: - BASAutoRouteRanker+Reducers
// God-object extraction (audit ch1040, WS1): the Reducers domain, split out of the
// BASAutoRouteRanker junk-drawer. Pure relocation, same namespace + symbols, byte-equal.

import Foundation
import CryptoKit
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif
#if canImport(Darwin)
import Darwin
#endif

extension BASAutoRouteRanker {

    // MARK: - Naive fallback

    internal static func swiftNaiveCosine(
        _ a: [Float], _ b: [Float]
    ) -> Float {
        var dot: Float = 0
        var na:  Float = 0
        var nb:  Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na  += a[i] * a[i]
            nb  += b[i] * b[i]
        }
        if na == 0 || nb == 0 { return 0 }
        return dot
            / (na.squareRoot() * nb.squareRoot())
    }

    // MARK: - L8 Memory Atom Reducer
    //         (chapter 七百五十一 第二刀 / M2427)
    //
    // MATURATION ARC L8 Memory port — admission-confidence
    // tiebreak rule from BASMemoryAtomReducer.applyAdmitted。
    // Primitive-arg classifier matching chapter 七百三十九 risk_plane
    // winning pattern (small-arg classifiers WIN on FFI overhead)。

    /// Returns the bas-atom-reducer ABI version。
    public static func atomReducerABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_atom_reducer_abi_version()
        #else
        return 0
        #endif
    }

    /// Routed implementation of `BASMemoryAtomReducer` admission-
    /// confidence tiebreak rule。 Returns `true` if a fresh
    /// `.admitted` event should REPLACE the existing atom,`false`
    /// if existing should be kept (no-op)。
    ///
    /// Byte-identical to the Swift switch ladder at
    /// `BASMemoryAtomReducer.swift` lines 170-186 per the
    /// chapter 七百五十一 第二刀 byte-equality test。
    public static func atomReducerShouldReplaceAdmitted(
        existingConfidence: Double,
        newConfidence: Double,
        tiebreakKeepsExisting: Bool
    ) -> Bool {
        #if os(iOS) || os(macOS)
        let flag: Int32 = tiebreakKeepsExisting ? 1 : 0
        let rc = bas_atom_reducer_should_replace_admitted(
            existingConfidence,
            newConfidence,
            flag)
        return rc != 0
        #else
        // Non-Apple platforms (watchOS) — fall back to the
        // Swift logic byte-for-byte so the routed helper is
        // safe to call from any code path。
        if existingConfidence > newConfidence { return false }
        if existingConfidence < newConfidence { return true }
        return !tiebreakKeepsExisting
        #endif
    }

    // MARK: - L8 Memory Atom Reducer batched
    //         (chapter 七百五十三 第二刀 / M2434)
    //         DEACTIVATED chapter 七百五十七 第一刀 / M2438
    //
    // Batched admission-tiebreak — measured 0.82× LOSS across
    // 4 perf-grid cells (N=16/256/1024/4096)。 Swift-side
    // `[Int32]` buffer alloc + withUnsafeBufferPointer chains
    // dominate the FFI savings for trivial primitive math。
    // Per user directive 2026-05-20「先把 所有 能 comment 都
    // comment」+「亏的不要硬上」,this opt-in Swift bridge
    // is wrapped in `#if false` so the dead-but-callable code
    // path is removed from the compile surface。 The Rust
    // function + XCFramework symbol + Rust unit tests stay
    // warm (low-cost) so a future arc can 1-line re-enable
    // by flipping `#if false` → `#if true`。

#if false  // chapter 七百五十七 第一刀 deactivated — 0.82× LOSS
    /// Compute the admission-tiebreak decision for N
    /// (existing,new) confidence pairs in a single FFI call。
    /// All N pairs share the same `tiebreakKeepsExisting`
    /// flag (the substrate-wide chapter 一百八十五 invariant)。
    ///
    /// Returns `[Bool]` of length N where `true` means the
    /// fresh event should REPLACE the existing atom。
    /// Returns `nil` on FFI fault (null pointer / shape mismatch)
    /// or array-length mismatch between existing and new。
    public static func atomReducerBatchedShouldReplaceAdmitted(
        existing: [Double],
        new: [Double],
        tiebreakKeepsExisting: Bool
    ) -> [Bool]? {
        guard existing.count == new.count else { return nil }
        let n = existing.count
        if n == 0 { return [] }
        #if os(iOS) || os(macOS)
        var out = [Int32](repeating: 0, count: n)
        let flag: Int32 = tiebreakKeepsExisting ? 1 : 0
        let rc = existing.withUnsafeBufferPointer {
            eb -> Int32 in
            new.withUnsafeBufferPointer {
                nb -> Int32 in
                out.withUnsafeMutableBufferPointer {
                    ob -> Int32 in
                    bas_atom_reducer_batched_should_replace_admitted(
                        eb.baseAddress,
                        nb.baseAddress,
                        Int32(n),
                        flag,
                        ob.baseAddress)
                }
            }
        }
        if rc != 0 { return nil }
        return out.map { $0 != 0 }
        #else
        // watchOS fallback — loop the Swift logic
        return zip(existing, new).map { (e, nv) in
            if e > nv { return false }
            if e < nv { return true }
            return !tiebreakKeepsExisting
        }
        #endif
    }
#endif  // chapter 七百五十七 第一刀
}
