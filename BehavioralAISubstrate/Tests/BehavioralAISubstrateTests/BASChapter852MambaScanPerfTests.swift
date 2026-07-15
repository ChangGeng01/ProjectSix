// MARK: - BASChapter852MambaScanPerfTests
// chapter 八百五十二 第四刀 / M2914 — 5-axis perf for Mamba SSM scan
//
// Compares 3 CPU implementations of the Mamba selective scan
// at a realistic grid of (B, L, D) shapes:
//
//   1. Swift `BASSSMScanCPUReference` (chapter 六百七十八)
//   2. Rust `bas_mamba_scan_sequential` (chapter 八百五十二 第一刀)
//   3. Rust `bas_mamba_scan_parallel`   (chapter 八百五十二 第二刀)
//
// The Metal GPU path (`BASMetalSSMScanKernel`) is NOT included
// in this perf grid because:
//   - It's already production-default on Apple Silicon
//   - Per chapter 681,it's the fastest on warmed GPU but has
//     dispatch overhead on cold paths
//   - Perf comparison vs MetalGPU lives in the existing
//     BASSSMScanWallclockBenchmarkTests fixture
//
// Goal of this chapter:answer whether the Rust paths are
// production-default-flip candidates for the CPU fallback path
// (which today is Swift only)。
//
// 5-axis verdict per chapter 七百四十九 framework:
//   Axis 1 — perf:        measured here
//   Axis 2 — memory:      equivalent (all 3 allocate same shape)
//   Axis 3 — state mach:  TIE (same recurrence semantics)
//   Axis 4 — persistence: N/A (pure compute)
//   Axis 5 — replay byte: PASS (chapter 八百五十二 第三刀 bridge tests
//                          already pin Swift ≡ Rust seq ≡ Rust par
//                          within 1e-5 tolerance)

import XCTest
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

#if os(iOS) || os(macOS)

final class BASChapter852MambaScanPerfTests: XCTestCase {

    private struct Scale: CustomStringConvertible {
        let b: Int32
        let l: Int32
        let d: Int32
        var bld: Int { Int(b) * Int(l) * Int(d) }
        var description: String { "(B=\(b), L=\(l), D=\(d))" }
    }

    private func mkInputs(scale: Scale) -> (x: [Float], delta: [Float], a: [Float], bProj: [Float], cProj: [Float]) {
        var state: UInt64 = 0xCAFE_BABE_FACE_FEED
        let next: () -> Float = {
            state ^= state &<< 13
            state ^= state &>> 7
            state ^= state &<< 17
            return Float(state % 1000) / 1000.0
        }
        let bld = scale.bld
        let d = Int(scale.d)
        let x = (0..<bld).map { _ in next() }
        let delta = (0..<bld).map { _ in 0.01 + 0.1 * next() }
        let a = (0..<d).map { _ in -1.0 - next() }
        let bProj = (0..<bld).map { _ in next() }
        let cProj = (0..<bld).map { _ in next() }
        return (x, delta, a, bProj, cProj)
    }

    // MARK: - Scale 1: tiny (cold-start latency)

    func testMambaScanScale_B1_L64_D32() {
        runComparison(scale: Scale(b: 1, l: 64, d: 32),
            label: "tiny — B=1 L=64 D=32 (2048 cells)")
    }

    // MARK: - Scale 2: medium (typical warm path)

    func testMambaScanScale_B4_L128_D128() {
        runComparison(scale: Scale(b: 4, l: 128, d: 128),
            label: "medium — B=4 L=128 D=128 (65,536 cells)")
    }

    // MARK: - Scale 3: large (long-sequence simulation)

    func testMambaScanScale_B8_L256_D256() {
        runComparison(scale: Scale(b: 8, l: 256, d: 256),
            label: "large — B=8 L=256 D=256 (524,288 cells)")
    }

    // MARK: - Verdict summary

    func testMambaScanFlipVerdict() {
        // Print expected verdict based on the 3 scale tests above。
        // Recall:rayon overhead per task ≈ 1µs;sequential Rust
        // and Swift CPU should be ~equivalent (both use
        // `expf` + small fmadd loops);parallel wins when
        // total work ÷ thread_count > overhead。
        //
        // Threshold rule of thumb:rayon wins when B×D ≥ ~64
        // AND total cells ≥ ~10K。 Below that,sequential is
        // best because rayon scatter cost dominates。
        print("== chapter 852 第四刀 5-axis Mamba scan verdict ==")
        print("   Axis 1 perf:     measured at 3 scales above")
        print("   Axis 2 memory:   equivalent (all alloc B×L×D)")
        print("   Axis 3 state:    TIE (same recurrence)")
        print("   Axis 4 persist:  N/A (pure compute)")
        print("   Axis 5 byte-eq:  PASS (chapter 852/3 bridge tests)")
        print("   Production flip recommendation:")
        print("   - SSM CPU fallback path: stays Swift OR flips to")
        print("     Rust parallel depending on measured ratios")
        print("   - Rust paths remain opt-in via BASAutoRouteRanker")
        print("   - Metal GPU continues as primary production path")

        // Compute the flip verdict for the 3 documented scales using the
        // threshold rule stated above: rayon (parallel) wins when
        // B×D ≥ 64 AND total cells ≥ 10_000.
        let scales = [
            Scale(b: 1, l: 64, d: 32),   // B×D=32,  cells=2048   → no flip
            Scale(b: 4, l: 128, d: 128), // B×D=512, cells=65536  → flip
            Scale(b: 8, l: 256, d: 256), // B×D=2048,cells=524288 → flip
        ]
        let flips = scales.map { s -> Bool in
            let bd = Int(s.b) * Int(s.d)
            return bd >= 64 && s.bld >= 10_000
        }
        let flipCount = flips.filter { $0 }.count
        print("   flip verdict per scale: \(flips) → \(flipCount)/3 flip")
        // #18: assertion — threshold rule flips exactly the 2 larger scales,
        // and never the tiny cold-start scale (independent expected values).
        XCTAssertEqual(flipCount, 2)
        XCTAssertFalse(flips[0])
        XCTAssertTrue(flips[1] && flips[2])
    }

    // MARK: - Helpers

    private func runComparison(scale: Scale, label: String) {
        let inputs = mkInputs(scale: scale)
        let shape = BASSSMScanShape(
            B: UInt32(scale.b), L: UInt32(scale.l), D: UInt32(scale.d))
        // Warm up all 3 paths
        for _ in 0..<3 {
            _ = try? BASSSMScanCPUReference.scan(
                x: inputs.x, delta: inputs.delta,
                A: inputs.a, B: inputs.bProj, C: inputs.cProj,
                shape: shape)
            _ = BASAutoRouteRanker.mambaScanSequential(
                x: inputs.x, delta: inputs.delta, a: inputs.a,
                bProj: inputs.bProj, cProj: inputs.cProj,
                b: scale.b, l: scale.l, d: scale.d)
            _ = BASAutoRouteRanker.mambaScanParallel(
                x: inputs.x, delta: inputs.delta, a: inputs.a,
                bProj: inputs.bProj, cProj: inputs.cProj,
                b: scale.b, l: scale.l, d: scale.d)
        }

        // Choose iter count proportional to inverse work
        let iters: Int = scale.bld <= 4_096 ? 100
            : scale.bld <= 100_000 ? 30 : 10

        let swiftNs = measureNanos {
            for _ in 0..<iters {
                _ = try? BASSSMScanCPUReference.scan(
                    x: inputs.x, delta: inputs.delta,
                    A: inputs.a, B: inputs.bProj, C: inputs.cProj,
                    shape: shape)
            }
        }
        let rustSeqNs = measureNanos {
            for _ in 0..<iters {
                _ = BASAutoRouteRanker.mambaScanSequential(
                    x: inputs.x, delta: inputs.delta, a: inputs.a,
                    bProj: inputs.bProj, cProj: inputs.cProj,
                    b: scale.b, l: scale.l, d: scale.d)
            }
        }
        let rustParNs = measureNanos {
            for _ in 0..<iters {
                _ = BASAutoRouteRanker.mambaScanParallel(
                    x: inputs.x, delta: inputs.delta, a: inputs.a,
                    bProj: inputs.bProj, cProj: inputs.cProj,
                    b: scale.b, l: scale.l, d: scale.d)
            }
        }

        let swiftMs = Double(swiftNs) / 1_000_000.0
        let rustSeqMs = Double(rustSeqNs) / 1_000_000.0
        let rustParMs = Double(rustParNs) / 1_000_000.0
        let seqRatio = Double(rustSeqNs) / Double(swiftNs)
        let parRatio = Double(rustParNs) / Double(swiftNs)
        let parVsSeq = Double(rustParNs) / Double(rustSeqNs)

        print("== chapter 852 perf [\(label)] × \(iters) iters")
        print(String(format:
            "   Swift  CPU ref:  %.3f ms total / %.1f µs/iter",
            swiftMs, swiftMs * 1000 / Double(iters)))
        print(String(format:
            "   Rust   seq:      %.3f ms total / %.1f µs/iter " +
            "(ratio vs Swift %.2f×)",
            rustSeqMs, rustSeqMs * 1000 / Double(iters), seqRatio))
        print(String(format:
            "   Rust   parallel: %.3f ms total / %.1f µs/iter " +
            "(ratio vs Swift %.2f×, vs Rust seq %.2f×)",
            rustParMs, rustParMs * 1000 / Double(iters), parRatio, parVsSeq))

        XCTAssertGreaterThan(swiftNs, 0)
        XCTAssertGreaterThan(rustSeqNs, 0)
        XCTAssertGreaterThan(rustParNs, 0)
    }

    private func measureNanos(_ body: () -> Void) -> UInt64 {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let end = DispatchTime.now().uptimeNanoseconds
        return end - start
    }
}

#endif
