// MARK: - BASChapter716MatrixScorecardTests
// chapter 七百十六 第五刀 / M2255 — chapter close-out scorecard
//
// Documents the honest finding from chapter 七百十六:the
// Rust-routed ledger seal CAPABILITY ships,but production
// measurement showed the per-append path is NOT a win on
// Apple Silicon。 The chapter 七百十二 deferred-flip from
// flag OFF → flag ON is therefore NOT happening。
//
// This is exactly the「多次 对比 ... 用 winner」discipline:
// when measurement contradicts prediction,routing follows
// measurement,not the original hypothesis。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASSovereign

final class BASChapter716MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百十六 第五刀 — audit ledger swap scorecard")
        print("")
        print("### What this chapter shipped")
        print("")
        print(
            "  Knife 1: 9-test byte-equality sweep                ✅")
        print(
            "    (50-entry sweep + 10-step chain + NIST anchor)")
        print(
            "  Knife 2: hashViaAutoRouter helper + feature flag   ✅")
        print(
            "    (BASSovereignAuditLedger.useRoutedSeal = false)")
        print(
            "  Knife 3: append() branches on feature flag         ✅")
        print(
            "    (4 chain-parity tests pass)")
        print(
            "  Knife 4: production perf measurement               ✅")
        print(
            "    (HONEST FINDING: routed is 0.90x — slower!)")
        print(
            "  Knife 5: this — close-out + scorecard              ✅")
        print("")
        print("### Honest finding (chapter 七百十六 第四刀)")
        print("")
        print(
            "  Per-append production speedup measurement:")
        print(
            "    CryptoKit:  ~5300 ns/append (depth=100)")
        print(
            "    Routed:     ~5800 ns/append (depth=100)")
        print(
            "    speedup:    0.90× — routed is SLOWER")
        print("")
        print(
            "  Why prediction (chapter 七百十二 第三刀: 5-8×)")
        print(
            "  didn't hold:per-append seal is one cost among")
        print(
            "  several (Codable encode 30% + HMAC sign 25% +")
        print(
            "  SHA256 15% + entries.append 15% + segment ensure")
        print(
            "  15%)。 Saving 80% of 15% = 12% total — but FFI")
        print(
            "  overhead per call adds back ~14%。 Net: slightly")
        print(
            "  slower。")
        print("")
        print("### Decision per measurement")
        print("")
        print(
            "  useRoutedSeal stays default `false`")
        print(
            "  per-append path keeps using Swift CryptoKit")
        print(
            "  routed capability stays available for opt-in")
        print("")
        print(
            "  Where Rust DOES still win (chapter 七百十二):")
        print(
            "    - ledgerSealBatch for N records in 1 FFI call:")
        print(
            "      8.1× over per-record CryptoKit")
        print(
            "    - ledgerVerifyChain for chain replay verify:")
        print(
            "      2.85-3.06× over per-record CryptoKit verify")
        print("")
        print(
            "  These batched paths amortize FFI overhead across")
        print(
            "  many records — appropriate for cold-start chain")
        print(
            "  verify or background integrity sweep workloads,")
        print(
            "  NOT the hot-path per-append.")
        print("")
        print("### Architectural principle vindicated")
        print("")
        print(
            "  「多次 对比 如果 swift 更好 就用 swift,")
        print(
            "    rust 更好 就用 rust,Metal 更好 就用 Metal」")
        print("")
        print(
            "  Prediction said Rust。 Measurement said Swift.")
        print(
            "  Routing follows measurement — chapter 七百十六")
        print(
            "  keeps Swift CryptoKit on the per-append hot path.")
        print(
            "  The capability ships;the flip does not。")
        print("")
        print(
            "### Test totals across 15-chapter branch arc")
        print("")
        print(
            "  - 15 chapters · 75 knives · 770+ commits")
        print(
            "  - Empirical measurement at every decision point")
        print(
            "  - Default behavior unchanged for byte-pinned chain")

        // Sanity check — default flag is OFF
        XCTAssertFalse(
            BASSovereignAuditLedger.useRoutedSeal,
            "Default useRoutedSeal must be false per honest" +
            " perf finding")

        // Sanity check — auto-router family count is stable
        let count = BASAutoRouteChoice.allCases.count
        XCTAssertGreaterThanOrEqual(count, 30)
    }
}
