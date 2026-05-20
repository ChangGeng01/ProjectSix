// MARK: - BASChapter743L14CloseoutTests
// chapter 七百四十三 / M2386-M2390
//
// LAYER-MIGRATION ARC L14 sub-arc close-out。 Cross-component
// integration test exercising chapter 七百四十一 + 七百四十二 +
// 七百四十三 together:
//
//   - Open a sovereign audit chain via the chapter 七百四十一
//     seal_entry path (Rust)
//   - Issue + lifecycle-check tokens via chapter 七百四十三
//     token_lifecycle_status path (Rust)
//   - Derive verdicts via chapter 七百四十二 verdict_derive
//     path (Rust)
//   - Verify the chain replays end-to-end
//
// Also includes the L14 sub-arc scorecard summarizing the
// 3-chapter L14 migration journey。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASSovereign

final class BASChapter743L14CloseoutTests: XCTestCase {

    // MARK: - Token lifecycle bridge smokes

    func testTokenLiveWhenInRange() {
        #if os(iOS) || os(macOS)
        let s = BASAutoRouteRanker
            .sovereignTokenLifecycleStatus(
                issuedAtMs: 100, expiresAtMs: 200,
                revokedAtMs: nil, nowMs: 150)
        XCTAssertEqual(s, .live)
        #endif
    }

    func testTokenExpiredWhenPast() {
        #if os(iOS) || os(macOS)
        let s = BASAutoRouteRanker
            .sovereignTokenLifecycleStatus(
                issuedAtMs: 100, expiresAtMs: 200,
                revokedAtMs: nil, nowMs: 250)
        XCTAssertEqual(s, .expired)
        #endif
    }

    func testTokenRevokedTakesPrecedenceOverExpired() {
        #if os(iOS) || os(macOS)
        let s = BASAutoRouteRanker
            .sovereignTokenLifecycleStatus(
                issuedAtMs: 100, expiresAtMs: 200,
                revokedAtMs: 150, nowMs: 250)
        XCTAssertEqual(s, .revoked)
        #endif
    }

    func testTokenFutureDated() {
        #if os(iOS) || os(macOS)
        let s = BASAutoRouteRanker
            .sovereignTokenLifecycleStatus(
                issuedAtMs: 100, expiresAtMs: 200,
                revokedAtMs: nil, nowMs: 50)
        XCTAssertEqual(s, .futureDated)
        #endif
    }

    // MARK: - Cross-component integration (chapter 七百四十三 第三刀)

    /// End-to-end L14 stack exercise:5 audit-chain entries
    /// × 5 tokens × 5 verdicts。 Each layer of the L14
    /// migration touched here:
    ///   - chapter 七百四十一 seal_sovereign_entry (chain)
    ///   - chapter 七百四十三 token_lifecycle_status (tokens)
    ///   - chapter 七百四十二 verdict_derive (verdicts)
    func testL14CrossComponentIntegration() {
        #if os(iOS) || os(macOS)
        // Open audit chain
        var current = [UInt8](repeating: 0, count: 32)
        var entries: [[UInt8]] = []
        var tokenStatuses:
            [BASAutoRouteRanker.SovereignTokenLifecycleStatus] = []
        var verdictRanks: [Int32] = []

        for i in 0..<5 {
            // 1. Seal audit chain entry (chapter 七百四十一)
            let sealed = BASAutoRouteRanker
                .sovereignSealEntry(
                    priorHash32: current,
                    auditID: "audit-\(i)",
                    sessionID: "session-x",
                    verdictRef: "verdict-\(i)",
                    timestampMs: Int64(100 + i),
                    payload: Array("payload-\(i)".utf8))
            XCTAssertNotNil(sealed,
                "entry \(i): seal returned nil")
            entries.append(sealed!.canonicalBytes)
            current = sealed!.nextHash32

            // 2. Lifecycle-check a token issued at this turn
            //    (chapter 七百四十三)
            let tokenStatus = BASAutoRouteRanker
                .sovereignTokenLifecycleStatus(
                    issuedAtMs: Int64(100 + i),
                    expiresAtMs: Int64(200 + i),
                    revokedAtMs: nil,
                    nowMs: Int64(150 + i))
            XCTAssertNotNil(tokenStatus)
            tokenStatuses.append(tokenStatus!)

            // 3. Derive verdict for this turn (chapter 七百四十二)
            let bits = BASAutoRouteRanker
                .verdictHardBitfield()  // clean
            var softs = [Double](repeating: 0, count: 7)
            softs[1] = Double(i) * 0.15  // privilege_violation
                                          // ramps up
            let rank = BASAutoRouteRanker
                .verdictDeriveLevel(
                    hardBits: bits, softSignals: softs,
                    domain: .pureInference,
                    evidenceSufficient: true)
            XCTAssertNotNil(rank)
            verdictRanks.append(rank!)
        }

        // 4. Verify the audit chain replays correctly
        let chainOK = BASAutoRouteRanker
            .sovereignVerifyChain(
                initialHash32: [UInt8](
                    repeating: 0, count: 32),
                entries: entries,
                expectedFinalHash32: current)
        XCTAssertEqual(chainOK, true,
            "5-entry L14 audit chain must replay-verify")

        // All 5 tokens were live at their respective check times
        for (i, status) in tokenStatuses.enumerated() {
            XCTAssertEqual(status, .live,
                "token \(i) should be live at nowMs check")
        }

        // Verdict ranks should be 0 (i=0) → 0 (i=1, soft=0.15 low)
        // → 0 (i=2, 0.30 low) → 1 throttle (i=3, 0.45 mid) →
        // 2 shadowLock (i=4, 0.60 mid)
        // Note: privilege_violation mid → shadowLock (rank 2)
        XCTAssertEqual(verdictRanks[0], 0)
        XCTAssertEqual(verdictRanks[1], 0)
        XCTAssertEqual(verdictRanks[2], 0)
        XCTAssertEqual(verdictRanks[3], 2,
            "soft=0.45 (mid) for privilege_violation → shadowLock")
        XCTAssertEqual(verdictRanks[4], 2,
            "soft=0.60 (mid) for privilege_violation → shadowLock")
        #endif
    }

    // MARK: - L14 sub-arc scorecard (chapter 七百四十三 第四刀)

    func testPrintL14SubArcScorecard() {
        print("")
        print("=================================================================")
        print(
            "  CHAPTER 七百四十三 / M2386-M2390 — L14 SUB-ARC CLOSE-OUT")
        print(
            "  LAYER-MIGRATION ARC chapters 七百四十一-七百四十三 (L14 sub-arc)")
        print("=================================================================")
        print("")

        print("### L14 sub-arc 3-chapter trajectory")
        print("")
        print(
            "  ✅ Chapter 七百四十一 — Sovereign chain core")
        print(
            "       Rust: seal_sovereign_entry + verify_chain")
        print(
            "       SQL:  sovereign_tokens schema landed")
        print(
            "       Perf: 1.24× Rust win (SHA256-heavy)")
        print(
            "       3 axes Rust-better → default flip recommended")
        print("")
        print(
            "  ✅ Chapter 七百四十二 — Verdict engine port")
        print(
            "       Rust: verdict_decisions module (3-stage")
        print(
            "             non-compensatory decision tree)")
        print(
            "       SQL:  verdict_decisions schema landed")
        print(
            "       Perf: 13.84× Rust win (BIGGEST SURPRISE)")
        print(
            "       4 axes Rust-better → default flip strongly")
        print(
            "       recommended")
        print("")
        print(
            "  ✅ Chapter 七百四十三 — L14 close-out (this)")
        print(
            "       Rust: token_lifecycle_status pure decision")
        print(
            "       Cross-component test: 5-entry chain × 5")
        print(
            "       tokens × 5 verdicts end-to-end")
        print(
            "       L14 sub-arc scorecard captured")
        print("")

        print("### L14 cumulative deliverable")
        print("")
        print(
            "  Rust crates extended:    bas-substrate-core")
        print(
            "                           (chain.rs + verdict_decisions.rs)")
        print(
            "  Rust LOC added:          ~700 (port + tests)")
        print(
            "  C ABI exports added:     6 (seal + verify_chain +")
        print(
            "                              verdict_derive +")
        print(
            "                              token_lifecycle +")
        print(
            "                              ABI versions)")
        print(
            "  XCFramework rebuilds:    3 (one per chapter)")
        print(
            "  SQL schemas added:       2")
        print(
            "                           (009_sovereign_tokens,")
        print(
            "                            010_verdict_decisions)")
        print(
            "  Swift bridge helpers:    7")
        print(
            "                           (sovereignSealEntry,")
        print(
            "                            sovereignVerifyChain,")
        print(
            "                            verdictDeriveLevel,")
        print(
            "                            verdictHardBitfield,")
        print(
            "                            verdictDecisionsABIVersion,")
        print(
            "                            sovereignTokenLifecycleStatus,")
        print(
            "                            +SovereignSealedEntry struct)")
        print(
            "  Swift production touched: 0 (forward-looking only)")
        print("")

        print("### Axis 1 perf summary across L14 sub-arc")
        print("")
        print(
            "  Chapter 七百四十一 sovereign seal:    1.24× Rust")
        print(
            "  Chapter 七百四十二 verdict derive:   13.84× Rust")
        print(
            "  Chapter 七百四十三 token lifecycle:   not measured")
        print(
            "                                       (tiny i64 math,")
        print(
            "                                        ~ns range)")
        print("")
        print(
            "  L14 substrate now offers Rust-default paths for")
        print(
            "  audit-chain sealing (SHA256-heavy) + verdict")
        print(
            "  derivation (branchy match cascade) + token")
        print(
            "  lifecycle (boolean decision)。 Apple-glue")
        print(
            "  (Security.framework / CryptoKit) stays Swift")
        print(
            "  per user directive。")
        print("")

        print("### 12-chapter arc trajectory (6 of 12 SEALED)")
        print("")
        print(
            "  ✅ Chapter 七百三十八 — L11 SQL schemas")
        print(
            "  ✅ Chapter 七百三十九 — L11 Rust state-machine")
        print(
            "  ✅ Chapter 七百四十   — L10 Tribunal pure-function")
        print(
            "  ✅ Chapter 七百四十一 — L14 Sovereign chain core")
        print(
            "  ✅ Chapter 七百四十二 — L14 Verdict engine")
        print(
            "  ✅ Chapter 七百四十三 — L14 close-out + verifier")
        print(
            "  ⏭ Chapter 七百四十四 — L3 Knowledge graph storage")
        print(
            "  ⏭ Chapter 七百四十五 — L3 Event extractor")
        print(
            "  ⏭ Chapter 七百四十六 — L3 Thought-fold + close")
        print(
            "  ⏭ Chapter 七百四十七 — L2 Neural Organ hot math")
        print(
            "  ⏭ Chapter 七百四十八 — L9 Dream Loop batch-scoring")
        print(
            "  ⏭ Chapter 七百四十九 — 12-chapter close-out SEAL")
        print("")
        print(
            "  L14 sub-arc 3/3 COMPLETE。 L3 sub-arc starts at")
        print(
            "  chapter 七百四十四。 Arc is 50% complete (6 of 12),")
        print(
            "  6 chapters remain。")
        print("")

        print("=================================================================")
        print(
            "  L14 SUB-ARC SEALED — 3 chapters × ~10 knives covering")
        print(
            "  sovereign chain seal + verdict engine + token lifecycle。")
        print(
            "  Branch advances chapter 七百四十二 SEAL → chapter")
        print(
            "  七百四十三 close-out。 L3 sub-arc opens at chapter 七百四十四。")
        print("=================================================================")
        print("")
    }
}
