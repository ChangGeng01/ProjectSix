// MARK: - BASChapter730AutoRouterDashboardTests
// chapter 七百三十 第一刀 / M2321
//
// Final auto-router primitive-family dashboard。 The chapter
// 七百十五 dashboard recorded 14 families;the chapter 七百
// 二十一-七百二十九 aggressive evolution arc adds 3 new families
// (quantize,BPE,PQ) bringing the total to 17。
//
// This test prints the full dashboard as the close-out
// substrate-shape audit for the 30-chapter branch arc。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter730AutoRouterDashboardTests: XCTestCase {

    func testPrintSeventeenFamilyDashboard() {
        print("")
        print(
            "## chapter 七百三十 第一刀 — 17-family auto-router dashboard")
        print("")
        print(
            "  Family # | Primitive               | Source chapter | Status")
        print(
            "  ---------+-------------------------+----------------+------------------")
        print(
            "   1       | cosine similarity        | 七百四         | default Rust SIMD ≥ dim 64")
        print(
            "   2       | SHA256 + HMAC            | 七百四         | default Rust ≤ 1KB")
        print(
            "   3       | top-K retrieval          | 七百四         | default Rust SIMD")
        print(
            "   4       | Metal FlashAttention     | 七百五         | wired via 七百七 dispatcher")
        print(
            "   5       | Rust SIMD math (L2,vec)  | 七百五         | default Rust ≥ dim 64")
        print(
            "   6       | LSH index                | 七百五         | C++ vendored")
        print(
            "   7       | SPSC ring buffer         | 七百五         | C lock-free")
        print(
            "   8       | Auto-route ranker        | 七百六         | dispatch layer")
        print(
            "   9       | Attention routing        | 七百七         | dispatch family")
        print(
            "  10       | MatMul SIMD blocked      | 七百八         | default Rust")
        print(
            "  11       | Softmax + LayerNorm      | 七百九         | default Rust SIMD")
        print(
            "  12       | Runtime calibrator       | 七百十         | dispatch policy")
        print(
            "  13       | Activations (GELU,SiLU)  | 七百十一       | default Rust SIMD")
        print(
            "  14       | Ledger seal + chain      | 七百十二       | default Rust")
        print(
            "  15       | Forget cascade           | 七百十三       | default Swift (七百十七 measured 2.2× faster)")
        print(
            "  16       | Provenance filter        | 七百十三       | default Rust (4.9×)")
        print(
            "  17       | Batched cosine           | 七百十五       | default Rust SIMD (8.7-43×)")
        print(
            "  -- arc 七百二十一-七百二十九 additions --")
        print(
            "  18       | Hex encode + decode      | 七百十九-七百二十一 | default Rust LUT (41-120×)")
        print(
            "  19       | BPE tokenizer            | 七百二十二     | opt-in (28× pre-tok)")
        print(
            "  20       | Event log binary codec   | 七百二十四     | opt-in primitive (2.3× storage)")
        print(
            "  21       | recordBatch multi-row SQL| 七百二十三     | default ON (1.63×) ✨")
        print(
            "  22       | int8 quantize / matmul   | 七百二十六     | opt-in (1.17× / 4× memory)")
        print(
            "  23       | int8 vector storage      | 七百二十七     | opt-in (3.88× RAM,99% recall)")
        print(
            "  24       | int8 KV cache            | 七百二十八     | opt-in (3.82× RAM,drift 0.0009)")
        print(
            "  25       | PQ index                 | 七百二十九     | opt-in (78× / 53× memory)")
        print("")
        print(
            "  Total auto-router families:  25 (chapter 七百十五 had 14;")
        print(
            "                                   arc 七百二十一-七百二十九 added 11)")
        print(
            "  Production-default flips:    9 (recordBatch multi-row SQL was the chapter")
        print(
            "                                  七百二十一-七百二十九 arc's only flip;")
        print(
            "                                  prior 8 from chapter 七百四-七百二十)")
        print(
            "  Opt-in net-new capabilities: 6 (BPE,binary codec,int8 quantize,int8")
        print(
            "                                  vector,int8 KV,PQ index)")
        print("")

        // Smoke: all chapter 七百二十一-七百二十九 surfaces compile
        #if os(iOS) || os(macOS)
        // Chapter 七百二十一 hex decoder
        let bytes = BASAutoRouteRanker.hexToBytes("ff00aa")
        XCTAssertEqual(bytes, [0xff, 0x00, 0xaa])
        // Chapter 七百二十六 int8 quantize
        let q = BASAutoRouteRanker.quantizeInt8(
            [0.5, -0.3, 0.8])
        XCTAssertNotNil(q)
        // Chapter 七百二十七 int8 cosine
        let cos = BASAutoRouteRanker.cosineInt8(
            a: q!.quantized, scaleA: q!.scale,
            b: q!.quantized, scaleB: q!.scale)
        XCTAssertGreaterThan(cos!, 0.99)
        // Chapter 七百二十九 PQ index
        let pq = BASPQIndex(dim: 16, m: 4, k: 8)
        XCTAssertNotNil(pq)
        #endif
    }
}
