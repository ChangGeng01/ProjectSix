// MARK: - BASChapter716AuditLedgerByteEqualityTests
// chapter 七百十六 第一刀 / M2251
//
// SAFETY-CRITICAL test:proves that the Rust-routed ledger
// seal produces byte-IDENTICAL output to the existing Swift
// CryptoKit `hash(_:)` path for a wide variety of
// `BASSovereignAuditEntry` payloads。
//
// This is the prerequisite for the production swap in Knife
// 2/3:before flipping any production call site,we MUST
// demonstrate that the new path emits the same base64-encoded
// SHA256 string for every possible canonical-bytes input。
//
// SHA256 is fully specified by NIST FIPS 180-4 so byte-equality
// is mathematically guaranteed — this test pins it empirically
// across diverse audit-entry shapes (small/large,with/without
// ruleIDs/signalRefs/actionRefs,ASCII/Unicode,with/without
// signature)。

import XCTest
import Foundation
import CryptoKit
@testable import BASRuntimeCore
@testable import BASSovereign

final class BASChapter716AuditLedgerByteEqualityTests:
    XCTestCase
{
    private let signingNamespace =
        BASSovereignTrustConstants.signingNamespace

    /// Existing Swift production path (verbatim from
    /// BASSovereignAuditLedger.hash(_:))。
    private func swiftCryptoKitHash(_ data: Data) -> String {
        return Data(SHA256.hash(data: data))
            .base64EncodedString()
    }

    /// New routed path:Rust SHA256 → base64。 Bytes
    /// produced by both paths MUST be identical。
    private func rustRoutedHash(_ data: Data) -> String {
        let bytes = Array(data)
        let r = BASAutoRouteRanker.ledgerSeal(bytes)
        return Data(r.value).base64EncodedString()
    }

    private func makeEntry(
        id: String,
        ruleCount: Int = 0,
        signalCount: Int = 0,
        actionCount: Int = 0,
        sessionID: String = "session-canonical",
        signature: String = "",
        unicode: Bool = false
    ) -> BASSovereignAuditEntry {
        let suffix = unicode ? "中文-payload" : "ascii"
        return BASSovereignAuditEntry(
            auditID: id,
            sessionID: sessionID,
            turnID: "turn-\(id)",
            verdictRef: "verdict-\(id)-\(suffix)",
            ruleIDs: (0..<ruleCount).map {
                "rule-\($0)" },
            signalRefs: (0..<signalCount).map {
                "signal-\($0)" },
            actionRefs: (0..<actionCount).map {
                "action-\($0)" },
            snapshotRef: "snap-\(id)",
            actor: .system,
            signature: signature,
            appendedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
    }

    // MARK: - Per-payload byte equality

    func testEmptyCanonicalBytesByteEqual() {
        let data = Data()
        XCTAssertEqual(
            swiftCryptoKitHash(data),
            rustRoutedHash(data),
            "empty payload must hash identically")
    }

    func testGenesisHashByteEqual() {
        // Genesis canonical bytes — derived from a minimal
        // entry with empty ruleIDs/signalRefs/actionRefs。
        let entry = makeEntry(id: "genesis")
        let canonical = basSovereignAuditCanonicalBytes(
            for: entry,
            priorHash: "GENESIS",
            signingNamespace: signingNamespace)
        XCTAssertEqual(
            swiftCryptoKitHash(canonical),
            rustRoutedHash(canonical))
    }

    func testEntryWithRuleIDsByteEqual() {
        let entry = makeEntry(
            id: "with-rules", ruleCount: 5)
        let canonical = basSovereignAuditCanonicalBytes(
            for: entry,
            priorHash: "abc123",
            signingNamespace: signingNamespace)
        XCTAssertEqual(
            swiftCryptoKitHash(canonical),
            rustRoutedHash(canonical))
    }

    func testEntryWithAllRefArraysByteEqual() {
        let entry = makeEntry(
            id: "all-refs",
            ruleCount: 3, signalCount: 4, actionCount: 2)
        let canonical = basSovereignAuditCanonicalBytes(
            for: entry,
            priorHash: "0123abcd",
            signingNamespace: signingNamespace)
        XCTAssertEqual(
            swiftCryptoKitHash(canonical),
            rustRoutedHash(canonical))
    }

    func testEntryWithUnicodeFieldsByteEqual() {
        let entry = makeEntry(
            id: "unicode-id", unicode: true)
        let canonical = basSovereignAuditCanonicalBytes(
            for: entry,
            priorHash: "中文-prior-hash-base64",
            signingNamespace: signingNamespace)
        XCTAssertEqual(
            swiftCryptoKitHash(canonical),
            rustRoutedHash(canonical))
    }

    func testEntryWithSignatureByteEqual() {
        let entry = makeEntry(
            id: "signed",
            signature: "base64-signature-bytes")
        let canonical = basSovereignAuditCanonicalBytes(
            for: entry,
            priorHash: "prev",
            signingNamespace: signingNamespace)
        XCTAssertEqual(
            swiftCryptoKitHash(canonical),
            rustRoutedHash(canonical))
    }

    // MARK: - 50-entry sweep

    func testFiftyVariedEntriesAllByteEqual() {
        // Sweep 50 entries with varied ruleIDs/signalRefs/
        // actionRefs counts (so each canonical-bytes blob has
        // a different length + structure)。 Every single one
        // must hash byte-identically across both paths。
        for i in 0..<50 {
            let entry = makeEntry(
                id: "id-\(i)",
                ruleCount: i % 7,
                signalCount: (i * 3) % 5,
                actionCount: i % 4,
                sessionID: "session-\(i / 10)",
                signature: i % 2 == 0
                    ? "sig-\(i)" : "",
                unicode: i % 3 == 0)
            let priorHash = i == 0
                ? "GENESIS" : "h-\(i - 1)"
            let canonical =
                basSovereignAuditCanonicalBytes(
                    for: entry,
                    priorHash: priorHash,
                    signingNamespace: signingNamespace)
            let cryptoKitOut =
                swiftCryptoKitHash(canonical)
            let rustOut = rustRoutedHash(canonical)
            XCTAssertEqual(cryptoKitOut, rustOut,
                "entry \(i):\n" +
                "  CryptoKit: \(cryptoKitOut)\n" +
                "  Rust:      \(rustOut)")
        }
    }

    // MARK: - Hash-chain linkage byte equality

    func testTenStepChainByteEqualAtEveryStep() {
        // Build a 10-step chain。 At every step,both paths
        // must produce the same selfHash given the same
        // canonical bytes。 priorHash flows from step to step
        // (so any divergence between paths cascades into
        // distinct chains — the test catches that immediately)。
        var cryptoKitPrior = "GENESIS"
        var rustPrior = "GENESIS"
        for i in 0..<10 {
            let entry = makeEntry(
                id: "chain-\(i)",
                ruleCount: i,
                actionCount: i % 3)
            let cryptoKitCanonical =
                basSovereignAuditCanonicalBytes(
                    for: entry,
                    priorHash: cryptoKitPrior,
                    signingNamespace: signingNamespace)
            let rustCanonical =
                basSovereignAuditCanonicalBytes(
                    for: entry,
                    priorHash: rustPrior,
                    signingNamespace: signingNamespace)
            let cryptoKitSelf =
                swiftCryptoKitHash(cryptoKitCanonical)
            let rustSelf =
                rustRoutedHash(rustCanonical)
            XCTAssertEqual(cryptoKitSelf, rustSelf,
                "chain step \(i) must hash equal")
            cryptoKitPrior = cryptoKitSelf
            rustPrior = rustSelf
        }
        XCTAssertEqual(cryptoKitPrior, rustPrior,
            "final chain tips must match after 10 steps")
    }

    // MARK: - Sentinel: NIST anchor

    func testNistSha256AnchorByteEqual() {
        // SHA256("abc") = ba7816bf...015ad
        let data = "abc".data(using: .utf8)!
        let cryptoKit = swiftCryptoKitHash(data)
        let rust = rustRoutedHash(data)
        XCTAssertEqual(cryptoKit, rust)
        // SHA256("abc") raw =
        //   ba7816bf8f01cfea414140de5dae2223
        //   b00361a396177a9cb410ff61f20015ad
        // base64(those 32 bytes) =
        //   ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=
        XCTAssertEqual(cryptoKit,
            "ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=",
            "NIST anchor: base64(SHA256('abc'))" +
            " must match published digest")
    }
}
