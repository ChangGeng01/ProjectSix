// MARK: - BASAutoRouteRanker+Mamba
// God-object extraction (audit ch1040): the Mamba SSM-scan routing (sequential +
// parallel), split out of the BASAutoRouteRanker junk-drawer. Pure relocation,
// same namespace + symbols, call sites unchanged, byte-equal.

import Foundation
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif

extension BASAutoRouteRanker {

    // MARK: - Mamba SSM scan (chapter 八百五十二 第三刀 / M2913)
    //
    // CPU-side selective scan routed through the new
    // `bas-mamba-scan` Rust crate。 Mirrors the Swift
    // `BASSSMScanCPUReference` math + the chapter 六百七十七
    // Metal kernel exactly (bit-equal across all 3
    // implementations within FMA-reorder tolerance)。
    //
    // Two variants:
    //   - `mambaScanSequential`:single-threaded Rust path
    //   - `mambaScanParallel`:rayon parallel over (b, d)
    //
    // Hosts choose based on workload shape:Metal GPU when
    // available is fastest;rayon parallel CPU is the
    // best-on-CPU path;sequential is the byte-equality
    // oracle for testing。
    //
    // Empty / invalid input returns nil — callers route to
    // their Swift fallback (BASSSMScanCPUReference) which
    // produces identical output。

    /// Sequential Mamba SSM scan via Rust。 Returns the
    /// (B, L, D) output `y` as a flat row-major [Float],
    /// or nil on input mismatch / non-Apple platforms。
    public static func mambaScanSequential(
        x: [Float],
        delta: [Float],
        a: [Float],
        bProj: [Float],
        cProj: [Float],
        b: Int32, l: Int32, d: Int32
    ) -> [Float]? {
        #if os(iOS) || os(macOS)
        // chapter 八百六十四 / M2976 — guard against multiplication
        // overflow on signed Int (traps in debug,wraps in release)。
        // Asymmetric with Rust-side checked_mul guard prior to this
        // fix。
        let (lProduct, ovfL) = Int(b).multipliedReportingOverflow(by: Int(l))
        guard !ovfL else { return nil }
        let (bld, ovfD) = lProduct.multipliedReportingOverflow(by: Int(d))
        guard !ovfD else { return nil }
        guard bld > 0,
              x.count == bld, delta.count == bld,
              a.count == Int(d),
              bProj.count == bld, cProj.count == bld
        else { return nil }
        var out = [Float](repeating: 0, count: bld)
        let rc = x.withUnsafeBufferPointer { xp -> Int32 in
            delta.withUnsafeBufferPointer { dp in
                a.withUnsafeBufferPointer { ap in
                    bProj.withUnsafeBufferPointer { bp in
                        cProj.withUnsafeBufferPointer { cp in
                            out.withUnsafeMutableBufferPointer { op in
                                bas_mamba_scan_sequential(
                                    xp.baseAddress,
                                    dp.baseAddress,
                                    ap.baseAddress,
                                    bp.baseAddress,
                                    cp.baseAddress,
                                    b, l, d,
                                    op.baseAddress,
                                    Int32(bld))
                            }
                        }
                    }
                }
            }
        }
        if rc != 0 { return nil }
        return out
        #else
        return nil
        #endif
    }

    /// Parallel Mamba SSM scan via Rust + rayon。 Same
    /// shape + same byte-equal output as sequential —
    /// parallelism is across (b, d) only。
    public static func mambaScanParallel(
        x: [Float],
        delta: [Float],
        a: [Float],
        bProj: [Float],
        cProj: [Float],
        b: Int32, l: Int32, d: Int32
    ) -> [Float]? {
        #if os(iOS) || os(macOS)
        // chapter 八百六十四 / M2976 — guard against multiplication
        // overflow on signed Int (traps in debug,wraps in release)。
        // Asymmetric with Rust-side checked_mul guard prior to this
        // fix。
        let (lProduct, ovfL) = Int(b).multipliedReportingOverflow(by: Int(l))
        guard !ovfL else { return nil }
        let (bld, ovfD) = lProduct.multipliedReportingOverflow(by: Int(d))
        guard !ovfD else { return nil }
        guard bld > 0,
              x.count == bld, delta.count == bld,
              a.count == Int(d),
              bProj.count == bld, cProj.count == bld
        else { return nil }
        var out = [Float](repeating: 0, count: bld)
        let rc = x.withUnsafeBufferPointer { xp -> Int32 in
            delta.withUnsafeBufferPointer { dp in
                a.withUnsafeBufferPointer { ap in
                    bProj.withUnsafeBufferPointer { bp in
                        cProj.withUnsafeBufferPointer { cp in
                            out.withUnsafeMutableBufferPointer { op in
                                bas_mamba_scan_parallel(
                                    xp.baseAddress,
                                    dp.baseAddress,
                                    ap.baseAddress,
                                    bp.baseAddress,
                                    cp.baseAddress,
                                    b, l, d,
                                    op.baseAddress,
                                    Int32(bld))
                            }
                        }
                    }
                }
            }
        }
        if rc != 0 { return nil }
        return out
        #else
        return nil
        #endif
    }
}
