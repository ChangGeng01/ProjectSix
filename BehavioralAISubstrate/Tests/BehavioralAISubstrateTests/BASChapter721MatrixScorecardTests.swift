// MARK: - BASChapter721MatrixScorecardTests
// chapter 七百二十一 第五刀 / M2280
//
// Chapter 七百二十一 close-out scorecard。 Opens the chapter
// 七百二十一-七百三十 aggressive evolution arc with a clean
// safe-opener: Rust hex decoder counterpart to chapter 七百十九
// encoder。 91-99× speedup measured + 1 production site wired。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter721MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百二十一 第五刀 — hex decoder scorecard")
        print("")
        print("### Chapter 七百二十一 deliverable")
        print("")
        print(
            "  Knife 1: Rust hex_decode.rs (~145 LOC) + 10 unit tests + C ABI")
        print(
            "  Knife 2: Swift byte-equality + perf grid")
        print(
            "           ▶ 91-99× speedup (exceeds 40-60× plan estimate)")
        print(
            "  Knife 3: Wire BASRustBrainHistoryStore.verifyChainHash")
        print(
            "           ▶ Audit finding: only 1 production hex-decode site")
        print(
            "  Knife 4: Full Swift test sweep (production smoke)")
        print(
            "  Knife 5: This scorecard")
        print("")
        print(
            "### Measurement (chapter 七百二十一 第二刀)")
        print("")
        print(
            "  size                  Swift idiom    Rust LUT   speedup")
        print(
            "  ────────────────────  ───────────    ────────   ───────")
        print(
            "  64-char hex (SHA256)      6.18 µs      ~62 ns     ~99×")
        print(
            "  2048-char hex (1 KB)       192.8 µs    2.12 µs    91.17×")
        print(
            "  20480-char hex (10 KB)      1.86 ms    18.8 µs    98.75×")
        print("")
        print("### Helper verification")

        // NIST SHA256("abc") anchor round-trip
        let hex = "ba7816bf8f01cfea414140de5dae2223" +
                  "b00361a396177a9cb410ff61f20015ad"
        let bytes = BASAutoRouteRanker.hexToBytes(hex)!
        XCTAssertEqual(bytes.count, 32)
        XCTAssertEqual(bytes[0], 0xba)
        XCTAssertEqual(bytes[31], 0xad)

        // Round-trip through encoder
        let encodedAgain = BASAutoRouteRanker
            .bytesToHexLower(bytes)
        XCTAssertEqual(encodedAgain, hex)
        print("  ✅ NIST SHA256('abc') decode produces canonical 32 bytes")
        print("  ✅ Round-trip encode→decode→encode is byte-identical")
        print("")
        print(
            "### Cumulative production Rust paths (chapter 七百四 → 七百二十一)")
        print("")
        print(
            "  ✅ SHA256 ≤ 1KB              → Rust pure-sha2")
        print(
            "  ✅ HMAC ≤ 1KB                → Rust HMAC")
        print(
            "  ✅ cosine primitive ≥ dim 64 → Rust SIMD")
        print(
            "  ✅ provenance filter         → Rust (4.9×)")
        print(
            "  ✅ vector retrieval topK     → Rust SIMD (8.7-43×)")
        print(
            "  ✅ hex encoding (16 sites)   → Rust LUT (41-120×)")
        print(
            "  ✅ hex decoding (1 site)     → Rust LUT (91-99×) ✨ NEW")
        print("")
        print(
            "### 21-chapter branch arc — current state")
        print("")
        print(
            "  - 21 chapters · 100 knives · 803+ commits")
        print(
            "  - 89.48% Swift / 10.52% native (+0.08pp from 720)")
        print(
            "  - 14 auto-router primitive families")
        print(
            "  - 8 production Rust defaults flipped + 8 helpers routed by default")
        print(
            "  - 20 byte-equality test suites + 14 perf grids")
        print(
            "  - 1/10 chapters of 七百二十一-七百三十 arc complete")
    }
}
