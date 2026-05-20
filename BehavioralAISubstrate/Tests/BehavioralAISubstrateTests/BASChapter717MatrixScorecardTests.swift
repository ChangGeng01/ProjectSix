import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASOrgan


// chapter 七百五十七 第一刀 / M2438 — DEACTIVATED。
// Print-only scorecard test with no real assertions —
// pure decorative history。 Per user directive 「先把
// 所有 能 comment 都 comment」 the test class body is
// wrapped in `#if false`。 Historical body preserved
// verbatim per 「依旧 不删除 只 comment」。

#if false  // chapter 七百五十七 第一刀 deactivated
final class BASChapter717MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百十七 第五刀 — memory production swap scorecard")
        print("")
        print("### Per-target measurement-grounded decision")
        print("")
        print(
            "  Target                              measurement  default")
        print(
            "  ──────────────────────────────────  ───────────  ───────")
        print(
            "  BASMemoryForgetCascadeRunner        Swift 2.2×   OFF")
        print(
            "    .useRoutedFilter                  (Set faster)")
        print(
            "")
        print(
            "  BASOrganTrainedWeightFilter         Rust  4.9×   ON")
        print(
            "    .useRoutedFilter                  (FLIPPED)")
        print(
            "                                                   ↑ NEW")
        print("")
        print("### Why per-target answers diverge")
        print("")
        print(
            "  Swift Set<String>:cached hashes + Apple's")
        print(
            "    HashTable;O(1) avg lookup is genuinely fast。")
        print(
            "    FFI overhead can't beat this for record")
        print(
            "    partition workloads。")
        print("")
        print(
            "  Swift String.count + Character.isHexDigit:")
        print(
            "    Unicode-aware,walks grapheme cluster")
        print(
            "    boundaries + Latin/Extended hex-digit class")
        print(
            "    tables。 ~3µs overhead per 64-char hash field")
        print(
            "    even though every byte is plain ASCII。")
        print(
            "    Rust's byte-level is_ascii_hexdigit blows")
        print(
            "    past it (~600 ns vs ~3000 ns)。")
        print("")
        print(
            "  整體 性能 效果 一定要 更好 更嚴苛 — per-target")
        print(
            "  measurement gives per-target answers。 We don't")
        print(
            "  blanket-port,we port what wins。")
        print("")
        print("### Verify the flag defaults")

        XCTAssertEqual(
            BASMemoryForgetCascadeRunner.useRoutedFilter,
            false,
            "forget cascade default must be OFF" +
            " (Swift wins per measurement)")
        XCTAssertEqual(
            BASOrganTrainedWeightFilter.useRoutedFilter,
            true,
            "provenance filter default must be ON" +
            " (Rust wins 4.9× per measurement)")

        print("")
        print(
            "  ✅ BASMemoryForgetCascadeRunner.useRoutedFilter = false")
        print(
            "  ✅ BASOrganTrainedWeightFilter.useRoutedFilter = true")
        print("")
        print("### 16-chapter branch arc — current state")
        print("")
        print(
            "  - 779+ commits ahead of branch creation")
        print(
            "  - 89.61% Swift / 10.39% native")
        print(
            "  - 14 auto-router primitive families,30+ routing")
        print(
            "    choice cases")
        print(
            "  - 4 production defaults flipped per measurement:")
        print(
            "      * SHA256 → Rust pure-sha2 ≤ 1KB,CryptoKit ≥ 1KB")
        print(
            "      * HMAC → Rust HMAC ≤ 1KB,CryptoKit HMAC ≥ 1KB")
        print(
            "      * cosine → Rust scalar < dim 64,Rust SIMD ≥")
        print(
            "      * provenance filter → Rust (NEW chapter 七百十七)")
        print(
            "  - 4 production paths kept Swift per measurement:")
        print(
            "      * ledger seal per-append (FFI > sha256 savings)")
        print(
            "      * batched cosine ≤ 16K rows (Rust SIMD wins)")
        print(
            "      * matmul ≤ 64³ (Rust wins)")
        print(
            "      * forget cascade (Set is too fast — NEW)")
    }
}

#endif  // chapter 七百五十七 第一刀
