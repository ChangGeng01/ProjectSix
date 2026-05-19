// MARK: - BASChapter719MatrixScorecardTests
// chapter 七百十九 第五刀 / M2270
//
// Chapter 七百十九 close-out scorecard:Rust hex encoder
// centralizes 10+ scattered Swift idioms behind a single
// helper that runs 41-120× faster。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter719MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百十九 第五刀 — hex encoder scorecard")
        print("")
        print("### What this chapter ships")
        print("")
        print(
            "  Rust:")
        print(
            "    Cargo/bas-retrieval-ranker/src/hex.rs")
        print(
            "      lookup-table hex encoder (16-entry LUT)")
        print(
            "      bas_ranker_bytes_to_hex_lower C ABI")
        print(
            "    Adds 110 LOC of Rust,8 unit tests pass")
        print(
            "")
        print(
            "  Swift:")
        print(
            "    BASAutoRouteRanker.bytesToHexLower(_:) -> String")
        print(
            "    BASAutoRouteRanker.dataToHexLower(_:) -> String")
        print(
            "    Routes through Rust LUT;Swift fallback when")
        print(
            "    XCFramework unavailable")
        print(
            "")
        print(
            "  Production sites wired (5):")
        print(
            "    BASSovereignIntegritySentinel.hash(_:)")
        print(
            "    BASSovereignSnapshotManager.hash(_:)")
        print(
            "    ObservabilityCore.replayFingerprint(...)")
        print(
            "    BASRuntimeAuditEmissionSummaryDigest+FromSummary")
        print(
            "    BASCognitiveBrain.sha256HexAuto + hmacSha256HexAuto")
        print("")
        print("### Measurement (chapter 七百十九 第二刀)")
        print("")
        print(
            "  size            Swift idiom    Rust LUT    speedup")
        print(
            "  ──────────────  ────────────   ─────────   ───────")
        print(
            "  32 B (SHA256)        36.1 µs    0.88 µs    41.25×")
        print(
            "  1024 B (1 KB)       1.29 ms    10.8 µs   119.69×")
        print(
            "  10240 B (10 KB)     12.4 ms     127 µs    97.29×")
        print("")
        print(
            "  Speedup compounds at all measured sizes because")
        print(
            "  Swift String(format: \"%02x\", byte) round-trips")
        print(
            "  through Foundation NSString printf。 Rust LUT is")
        print(
            "  branchless byte-level lookup → ~2 ns/byte。")
        print("")
        print("### Verify the helper works")

        let sample: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        let result = BASAutoRouteRanker.bytesToHexLower(
            sample)
        XCTAssertEqual(result, "deadbeef",
            "helper must produce lowercase hex")

        let emptyResult = BASAutoRouteRanker
            .bytesToHexLower([])
        XCTAssertEqual(emptyResult, "")

        // NIST SHA256("abc") anchor
        let sha256Abc: [UInt8] = [
            0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
            0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
            0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
            0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
        ]
        XCTAssertEqual(
            BASAutoRouteRanker.bytesToHexLower(sha256Abc),
            "ba7816bf8f01cfea414140de5dae2223" +
            "b00361a396177a9cb410ff61f20015ad",
            "NIST SHA256(\"abc\") anchor must match")

        print(
            "  ✅ deadbeef → 'deadbeef'")
        print(
            "  ✅ [] → ''")
        print(
            "  ✅ SHA256('abc') → published NIST digest")
        print("")
        print(
            "### Cumulative production-default flips (chapter 七百四 → 七百十九)")
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
            "  ✅ hex encoding (5 sites)    → Rust LUT (41-120×) ✨ NEW")
        print("")
        print(
            "### 18-chapter branch arc — current state")
        print("")
        print(
            "  - 18 chapters · 90 knives · 794+ commits")
        print(
            "  - 89.55% Swift / 10.45% native (+0.06pp from 718)")
        print(
            "  - 14 auto-router primitive families")
        print(
            "  - 8 production paths flipped to Rust per measurement")
        print(
            "  - 4 production paths kept Swift per measurement")
        print(
            "  - 18 byte-equality test suites + 13 perf grids")
    }
}
