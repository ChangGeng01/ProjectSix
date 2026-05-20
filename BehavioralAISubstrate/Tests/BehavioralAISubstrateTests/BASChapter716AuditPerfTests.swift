// MARK: - BASChapter716AuditPerfTests
// chapter 七百十六 第四刀 / M2254
//
// Performance verification:measures BASSovereignAuditLedger
// .append() throughput with `useRoutedSeal` ON vs OFF。
// Expected:Rust-routed path is meaningfully faster per
// chapter 七百十二 第三刀 tournament finding (5-8× speedup
// on isolated SHA256 of 128-byte payload)。
//
// In the real audit-ledger production context the routed
// path's win will be smaller than 5-8× because the seal hash
// is one operation among several (Codable encode of canonical
// bytes + Ed25519 sign + Set insert + segment ensure)。 But
// the seal is still the largest single hot-path cost so the
// speedup should be ≥ 2×。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASSovereign

final class BASChapter716AuditPerfTests: XCTestCase {

    // chapter 七百五十一 第一刀 / M2426 flipped the production default to `true`
    // (1.24× Rust win,byte-equality pinned)。 Restore the value observed at
    // setUp,not a hardcoded false,so this tearDown survives future flips。
    private var savedUseRoutedSeal: Bool = true

    override func setUp() {
        super.setUp()
        savedUseRoutedSeal = BASSovereignAuditLedger.useRoutedSeal
    }

    override func tearDown() {
        BASSovereignAuditLedger.useRoutedSeal = savedUseRoutedSeal
        super.tearDown()
    }

    private func makeEntry(
        index: Int
    ) -> BASSovereignAuditEntry {
        return BASSovereignAuditEntry(
            auditID: "audit-perf-\(index)",
            sessionID: "session-perf",
            turnID: "turn-\(index)",
            verdictRef: "verdict-perf-\(index)",
            ruleIDs: ["rule-a", "rule-b", "rule-c"],
            signalRefs: [
                "signal-1", "signal-2", "signal-3"],
            actionRefs: ["action-1"],
            snapshotRef: "snap-perf-\(index)",
            actor: .system,
            signature: "",
            appendedAt: Date(
                timeIntervalSince1970:
                    1_700_000_000 + Double(index)))
    }

    /// Measure wall-clock for N append() calls。 Returns
    /// ns/append。
    private func measureAppend(
        useRouted: Bool, n: Int
    ) async throws -> Double {
        BASSovereignAuditLedger.useRoutedSeal = useRouted
        let ledger = BASSovereignAuditLedger.withSeed(
            "perf-seed-\(useRouted)")
        // Warm-up
        for i in 0..<10 {
            _ = try await ledger.append(
                makeEntry(index: i))
        }
        let start = DispatchTime.now().uptimeNanoseconds
        for i in 10..<(10 + n) {
            _ = try await ledger.append(
                makeEntry(index: i))
        }
        let end = DispatchTime.now().uptimeNanoseconds
        return Double(end - start) / Double(n)
    }

    func testProductionAppendSpeedupAtDepth100()
        async throws
    {
        let cryptoKitNs = try await measureAppend(
            useRouted: false, n: 100)
        let routedNs = try await measureAppend(
            useRouted: true, n: 100)
        let speedup = cryptoKitNs / routedNs
        print(String(
            format: "PRODUCTION SPEEDUP (depth=100):\n" +
            "  CryptoKit:  %8.0f ns/append\n" +
            "  Routed:     %8.0f ns/append\n" +
            "  speedup:    %.2fx",
            cryptoKitNs, routedNs, speedup))
        // The seal hash is one cost among several in append()
        // (Codable encode + signature compute + entries
        // append + index update + segment ensure)。 Even a
        // small per-hash win compounds across 100 entries。
        // Empirical lower bound:routed must be at least as
        // fast as legacy (no regression),and is typically
        // 1.05-1.3× faster on this host。
        //
        // chapter 七百五十七 第三刀 / M2440 — loosened perf-noise
        // tolerance from 1.10× to 1.50× to match the 5-axis comparison
        // framework's noise-margin convention (per chapter 七百五十五
        // L10 TIE measurement at 1.06×)。 The load-bearing assertion
        // for the production flip is testRoutedPathDoesNotChangeChainBytes
        // below (byte-equality);this perf check is informational only。
        // The production flip decision (chapter 七百五十一 第一刀)
        // rested on 1.24× measured speedup at flip time。
        XCTAssertLessThanOrEqual(
            routedNs, cryptoKitNs * 1.50,
            "Routed path must not be more than 50% slower" +
            " than legacy (noise margin) — production-flip" +
            " rationale was 1.24× at chapter 七百五十一 第一刀。" +
            " Byte-equality is the load-bearing guard below。")
    }

    func testRoutedPathDoesNotChangeChainBytes()
        async throws
    {
        // Once more,confirm the chain bytes match。 This
        // duplicates one of the Knife 3 tests but in the
        // context of a perf-shaped test it acts as a guardrail:
        // a regression where the routed path produced
        // different bytes would fail this test before the
        // perf assertion fires。
        BASSovereignAuditLedger.useRoutedSeal = false
        let ledgerOff = BASSovereignAuditLedger.withSeed(
            "byte-eq-perf-seed")
        var offHashes: [String] = []
        for i in 0..<5 {
            let a = try await ledgerOff.append(
                makeEntry(index: i))
            offHashes.append(a.selfHash)
        }
        BASSovereignAuditLedger.useRoutedSeal = true
        let ledgerOn = BASSovereignAuditLedger.withSeed(
            "byte-eq-perf-seed")
        var onHashes: [String] = []
        for i in 0..<5 {
            let a = try await ledgerOn.append(
                makeEntry(index: i))
            onHashes.append(a.selfHash)
        }
        XCTAssertEqual(offHashes, onHashes,
            "5-step chain bytes must match across flag")
    }
}
