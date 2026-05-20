// MARK: - BASChapter716AppendBranchingTests
// chapter 七百十六 第三刀 / M2253
//
// Verifies that BASSovereignAuditLedger.append() produces
// byte-IDENTICAL chains regardless of which seal path is
// selected by the `useRoutedSeal` feature flag。
//
// Test discipline:
//   1. Reset flag to false
//   2. Build chain with N entries on ledger A
//   3. Reset flag to true
//   4. Build chain with SAME N entries on ledger B
//   5. Reset flag back to false (test isolation)
//   6. For every step:assert
//      ledgerA.entries[i].selfHash == ledgerB.entries[i].selfHash
//      AND priorHash linkage matches

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASSovereign

final class BASChapter716AppendBranchingTests: XCTestCase {

    // chapter 七百五十一 第一刀 / M2426 flipped the production default to `true`
    // (1.24× Rust win,byte-equality pinned)。 tearDown must restore the
    // CURRENT production default,not the chapter-七百十六-era false value,
    // or it bleeds into BASChapter756MaturationArcSealTests.testL14ChainSealRoutedDefaultOn
    // and BASChapter751MaturationArcOpenerTests.testL14RoutedSealIsNowDefaultOn。
    private var savedUseRoutedSeal: Bool = true

    override func setUp() {
        super.setUp()
        savedUseRoutedSeal = BASSovereignAuditLedger.useRoutedSeal
    }

    override func tearDown() {
        // Test isolation:restore the value observed at setUp,not a hardcoded
        // constant。 Survives future default flips automatically。
        BASSovereignAuditLedger.useRoutedSeal = savedUseRoutedSeal
        super.tearDown()
    }

    private func makeEntry(
        index: Int
    ) -> BASSovereignAuditEntry {
        return BASSovereignAuditEntry(
            auditID: "audit-\(index)",
            sessionID: "session-\(index / 5)",
            turnID: "turn-\(index)",
            verdictRef: "verdict-\(index)",
            ruleIDs: (0..<(index % 4)).map {
                "rule-\($0)" },
            signalRefs: (0..<(index % 3)).map {
                "signal-\($0)" },
            actionRefs: [],
            snapshotRef: "snap-\(index)",
            actor: .system,
            signature: "",
            appendedAt: Date(
                timeIntervalSince1970:
                    1_700_000_000 + Double(index)))
    }

    // MARK: - Default flag preserves V1 behavior
    //
    // chapter 七百五十一 第一刀 / M2426 flipped useRoutedSeal default-on
    // (1.24× Rust win,byte-equality pinned)。 The chapter 七百十六-era
    // assertion "Default must be OFF" is now contradicted by the production
    // flip。 Test deactivated per 「依旧 不删除 只 comment」 — kept as a
    // historical record of the pre-flip invariant。 The new default-on
    // invariant lives in BASChapter751MaturationArcOpenerTests.testL14RoutedSealIsNowDefaultOn
    // and BASChapter756MaturationArcSealTests.testL14ChainSealRoutedDefaultOn。
#if false  // chapter 七百五十一 第一刀 invalidated this assertion
    func testDefaultFlagIsFalse() {
        BASSovereignAuditLedger.useRoutedSeal = false
        XCTAssertFalse(
            BASSovereignAuditLedger.useRoutedSeal,
            "Default must be OFF per ADR-014 OPT-IN")
    }
#endif

    // MARK: - Single-entry parity

    func testSingleEntryByteEqualAcrossFlag() async throws {
        BASSovereignAuditLedger.useRoutedSeal = false
        let ledgerLegacy =
            BASSovereignAuditLedger.withSeed("seed-1")
        let appendedLegacy = try await ledgerLegacy.append(
            makeEntry(index: 0))

        BASSovereignAuditLedger.useRoutedSeal = true
        let ledgerRouted =
            BASSovereignAuditLedger.withSeed("seed-1")
        let appendedRouted = try await ledgerRouted.append(
            makeEntry(index: 0))

        XCTAssertEqual(
            appendedLegacy.selfHash,
            appendedRouted.selfHash,
            "single-entry selfHash must match")
        XCTAssertEqual(
            appendedLegacy.priorHash,
            appendedRouted.priorHash)
    }

    // MARK: - 20-entry chain parity

    func testTwentyEntryChainByteEqualAcrossFlag() async throws {
        BASSovereignAuditLedger.useRoutedSeal = false
        let ledgerLegacy =
            BASSovereignAuditLedger.withSeed("seed-chain")
        var legacyChain: [(prior: String, selfHash: String)] = []
        for i in 0..<20 {
            let appended = try await ledgerLegacy.append(
                makeEntry(index: i))
            legacyChain.append((
                appended.priorHash, appended.selfHash))
        }

        BASSovereignAuditLedger.useRoutedSeal = true
        let ledgerRouted =
            BASSovereignAuditLedger.withSeed("seed-chain")
        var routedChain: [(prior: String, selfHash: String)] = []
        for i in 0..<20 {
            let appended = try await ledgerRouted.append(
                makeEntry(index: i))
            routedChain.append((
                appended.priorHash, appended.selfHash))
        }

        for i in 0..<20 {
            XCTAssertEqual(
                legacyChain[i].selfHash,
                routedChain[i].selfHash,
                "step \(i): selfHash must match")
            XCTAssertEqual(
                legacyChain[i].prior,
                routedChain[i].prior,
                "step \(i): priorHash linkage must match")
        }
    }

    // MARK: - Flag flip mid-chain still verifies

    func testFlagFlipMidChainProducesContiguousChain()
        async throws
    {
        // Start with flag OFF,append 5 entries,flip flag
        // ON,append 5 more。 The chain linkage MUST stay
        // contiguous (priorHash of entry 5 == selfHash of
        // entry 4)。 This proves the two paths agree at every
        // chain step,not just on isolated computations。
        BASSovereignAuditLedger.useRoutedSeal = false
        let ledger =
            BASSovereignAuditLedger.withSeed("seed-flip")
        var chain: [(prior: String, selfHash: String)] = []
        for i in 0..<5 {
            let a = try await ledger.append(makeEntry(index: i))
            chain.append((a.priorHash, a.selfHash))
        }
        // Flip flag mid-chain
        BASSovereignAuditLedger.useRoutedSeal = true
        for i in 5..<10 {
            let a = try await ledger.append(makeEntry(index: i))
            chain.append((a.priorHash, a.selfHash))
        }
        // Verify chain linkage stays contiguous
        for i in 1..<10 {
            XCTAssertEqual(
                chain[i].prior, chain[i - 1].selfHash,
                "step \(i): priorHash must link to" +
                " step \(i - 1) selfHash")
        }
    }
}
