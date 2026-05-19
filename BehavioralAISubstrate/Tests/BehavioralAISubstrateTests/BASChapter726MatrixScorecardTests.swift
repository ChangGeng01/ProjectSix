// MARK: - BASChapter726MatrixScorecardTests
// chapter 七百二十六 第五刀 / M2305
//
// Chapter 七百二十六 close-out scorecard。 Net-new int8
// quantization primitives shipped。 Foundation for chapters
// 七百二十七 + 七百二十八。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter726MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百二十六 第五刀 — int8 quantization scorecard")
        print("")
        print("### Chapter 七百二十六 deliverable")
        print("")
        print(
            "  Knife 1: Rust quantize.rs (~140 LOC + 11 unit tests)")
        print(
            "           ▶ Symmetric int8 quantize/dequantize")
        print(
            "           ▶ int8 × int8 → f32 matmul (i32 accumulation)")
        print(
            "  Knife 2: C ABI + Swift bridge")
        print(
            "           ▶ bas_ranker_quantize_int8 / dequantize / matmul")
        print(
            "           ▶ BASAutoRouteRanker.quantizeInt8 + helpers")
        print(
            "           ▶ 3.98× memory savings (Float32 → int8 + scale)")
        print(
            "  Knife 3: Perf grid — 1.17× vs Rust Float32 SIMD-blocked")
        print(
            "           ▶ HONEST apples-to-apples (not 202× scalar-Swift)")
        print(
            "           ▶ Below 1.5× decision gate → no production swap")
        print(
            "  Knife 4: BASQuantizedTensor Codable Sendable wrapper")
        print(
            "           ▶ Single value for storage / pass / persist")
        print(
            "           ▶ Foundation for chapters 七百二十七 + 七百二十八")
        print(
            "  Knife 5: This scorecard")
        print("")
        print(
            "### Knife 3 perf measurement (64×64 × 64×64 matmul)")
        print("")
        print(
            "  vs scalar Swift Float32:     ~202×   [MISLEADING baseline]")
        print(
            "  vs Rust Float32 SIMD-blocked:  1.17× [HONEST apples-to-apples]")
        print(
            "  Memory:                        3.98× shrink")
        print("")
        print(
            "  Plan-agent honest estimate: 1.5× compute + 4× memory")
        print(
            "  Actual landing: 1.17× compute (below) + 3.98× memory (matches)")
        print("")
        print(
            "### Capability summary")
        print("")
        print(
            "  ✨ quantize_int8(x: [f32]) -> ([i8], scale)")
        print(
            "     Symmetric quantization,amax/127 scale")
        print(
            "  ✨ dequantize_int8(q: [i8], scale: f32) -> [f32]")
        print(
            "     Per-element error ≤ scale/2 ≈ 1/254 for typical values")
        print(
            "  ✨ matmul_int8(A: i8, B: i8, scales, m, k, n) -> [f32]")
        print(
            "     i32 accumulation;avoids overflow for k up to ~2^15")
        print(
            "  ✨ BASQuantizedTensor (Codable Sendable Hashable)")
        print(
            "     Typed wrapper for storage / persistence / actor")
        print(
            "     boundary passing")
        print("")
        print(
            "### Cumulative production paths (chapter 七百四 → 七百二十六)")
        print("")
        print(
            "  ✅ SHA256 / HMAC / cosine / provenance / vector topK")
        print(
            "  ✅ hex encode / decode (Rust LUT)")
        print(
            "  🆕 BPE tokenization (28× pre-tok speedup) — opt-in")
        print(
            "  ✅ recordBatch multi-row SQL (1.63× — default ON)")
        print(
            "  🆕 event log binary codec (2.3× storage shrink) — primitive")
        print(
            "  ⛔ scoreAll Rust / usageCount Rust — Swift wins,opt-in only")
        print(
            "  🆕 int8 quantization (1.17× compute,3.98× memory) — primitive")
        print("")
        print(
            "### 26-chapter branch arc — current state")
        print("")
        print(
            "  - 26 chapters · 130 knives · ~830 commits")
        print(
            "  - 89.5% Swift / ~10.5% native")
        print(
            "  - Production-default flips: 9 (unchanged from chapter 七百二十三)")
        print(
            "  - Net-new opt-in capabilities: 3 (BPE,binary codec,int8)")
        print(
            "  - 9 Rust crates bundled")
        print(
            "  - **6/10 chapters of 七百二十一-七百三十 arc complete**")
        print("")
        print(
            "### Plan-agent realism check ← actual landing")
        print("")
        print(
            "  Plan estimate (chapter 七百二十六):")
        print(
            "    \"~1.5× compute on M1/M2 + 4× memory shrink\"")
        print("")
        print(
            "  Actual landing:")
        print(
            "    ✅ Memory: 3.98× shrink — MATCHES plan")
        print(
            "    ⚠️  Compute: 1.17× (below plan's 1.5×)")
        print(
            "       Rust Float32 SIMD-blocked is already very good,")
        print(
            "       so int8's perf margin is narrow on M1/M2 (no AMX")
        print(
            "       for int8 dot products)。")
        print(
            "    ✅ Capability: shipped as primitive + typed wrapper,")
        print(
            "       ready for chapter 七百二十七 (int8 vector storage)")
        print(
            "       + 七百二十八 (int8 KV cache)。")
        print("")

        // Smoke: end-to-end primitive call
        #if os(iOS) || os(macOS)
        let x: [Float] = [0.5, -0.3, 0.8, -0.1]
        let t = BASQuantizedTensor(
            floatValues: x, shape: [4])
        XCTAssertNotNil(t)
        XCTAssertEqual(t!.count, 4)
        let back = t!.dequantizeToFloat32()
        XCTAssertNotNil(back)
        XCTAssertEqual(back?.count, 4)
        #endif
    }
}
