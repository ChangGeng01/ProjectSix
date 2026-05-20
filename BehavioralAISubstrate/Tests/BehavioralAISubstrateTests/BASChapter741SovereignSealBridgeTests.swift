// MARK: - BASChapter741SovereignSealBridgeTests
// chapter 七百四十一 第二刀 / M2377
//
// LAYER-MIGRATION ARC Swift bridge smoke tests for the L14
// Sovereign audit-ledger seal/verify port。
//
// Smoke gates:
//   - sovereignSealEntry encapsulates canonical-bytes + hash
//     in ONE Rust call → returns 32-byte next hash + non-
//     empty canonical buffer
//   - sovereignVerifyChain replays a 5-entry chain + returns
//     true
//   - sovereignVerifyChain returns false on tampered chain
//   - Determinism:same inputs yield same output across calls

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter741SovereignSealBridgeTests: XCTestCase {

    func testSovereignSealEntryReturnsHashAndCanonical() {
        #if os(iOS) || os(macOS)
        let prior = [UInt8](repeating: 0, count: 32)
        let result = BASAutoRouteRanker.sovereignSealEntry(
            priorHash32: prior,
            auditID: "audit-1",
            sessionID: "session-x",
            verdictRef: "verdict-y",
            timestampMs: 1_700_000_000_000,
            payload: Array("body".utf8))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.nextHash32.count, 32)
        // Canonical: 32 prior + (4 + 7) + (4 + 9) + (4 + 9)
        //   + 8 + (4 + 4) = 32 + 11 + 13 + 13 + 8 + 8 = 85
        XCTAssertEqual(result?.canonicalBytes.count, 85)
        // First 32 bytes must equal prior hash
        XCTAssertEqual(
            Array(result!.canonicalBytes.prefix(32)),
            prior)
        // Next-hash must NOT equal prior (sealing changed it)
        XCTAssertNotEqual(result?.nextHash32, prior)
        #endif
    }

    func testSovereignSealEntryIsDeterministic() {
        #if os(iOS) || os(macOS)
        let prior = [UInt8](repeating: 0x42, count: 32)
        let r1 = BASAutoRouteRanker.sovereignSealEntry(
            priorHash32: prior, auditID: "a",
            sessionID: "s", verdictRef: "v",
            timestampMs: 100, payload: [0xde, 0xad])
        let r2 = BASAutoRouteRanker.sovereignSealEntry(
            priorHash32: prior, auditID: "a",
            sessionID: "s", verdictRef: "v",
            timestampMs: 100, payload: [0xde, 0xad])
        XCTAssertNotNil(r1)
        XCTAssertNotNil(r2)
        XCTAssertEqual(r1?.nextHash32, r2?.nextHash32)
        XCTAssertEqual(
            r1?.canonicalBytes, r2?.canonicalBytes)
        #endif
    }

    func testSovereignSealEntryDistinctPayloadsDistinctHashes() {
        #if os(iOS) || os(macOS)
        let prior = [UInt8](repeating: 0, count: 32)
        let r1 = BASAutoRouteRanker.sovereignSealEntry(
            priorHash32: prior, auditID: "a",
            sessionID: "s", verdictRef: "v",
            timestampMs: 100, payload: Array("p1".utf8))
        let r2 = BASAutoRouteRanker.sovereignSealEntry(
            priorHash32: prior, auditID: "a",
            sessionID: "s", verdictRef: "v",
            timestampMs: 100, payload: Array("p2".utf8))
        XCTAssertNotNil(r1)
        XCTAssertNotNil(r2)
        XCTAssertNotEqual(r1?.nextHash32, r2?.nextHash32)
        #endif
    }

    func testSovereignSealEntryRejectsBadPriorHashLength() {
        #if os(iOS) || os(macOS)
        let bad = [UInt8](repeating: 0, count: 16)
        let r = BASAutoRouteRanker.sovereignSealEntry(
            priorHash32: bad, auditID: "a",
            sessionID: "s", verdictRef: "v",
            timestampMs: 0, payload: [])
        XCTAssertNil(r,
            "prior_hash32 must be exactly 32 bytes")
        #endif
    }

    func testSovereignVerifyChainGood() {
        #if os(iOS) || os(macOS)
        let initial = [UInt8](repeating: 0, count: 32)
        var current = initial
        var entries: [[UInt8]] = []
        for i in 0..<5 {
            let r = BASAutoRouteRanker.sovereignSealEntry(
                priorHash32: current,
                auditID: "audit-\(i)",
                sessionID: "session",
                verdictRef: "verdict",
                timestampMs: Int64(1_700_000_000_000 + i),
                payload: Array("body-\(i)".utf8))
            XCTAssertNotNil(r)
            entries.append(r!.canonicalBytes)
            current = r!.nextHash32
        }
        // Verify the chain reconstructs to the same final hash
        let ok = BASAutoRouteRanker.sovereignVerifyChain(
            initialHash32: initial,
            entries: entries,
            expectedFinalHash32: current)
        XCTAssertEqual(ok, true)
        #endif
    }

    func testSovereignVerifyChainBrokenLink() {
        #if os(iOS) || os(macOS)
        let initial = [UInt8](repeating: 0, count: 32)
        var current = initial
        var entries: [[UInt8]] = []
        for i in 0..<3 {
            let r = BASAutoRouteRanker.sovereignSealEntry(
                priorHash32: current,
                auditID: "audit-\(i)",
                sessionID: "session",
                verdictRef: "verdict",
                timestampMs: Int64(100 + i),
                payload: Array("body-\(i)".utf8))!
            entries.append(r.canonicalBytes)
            current = r.nextHash32
        }
        // Tamper with one entry's first byte → breaks link
        if entries[1].count > 0 {
            entries[1][0] ^= 0xff
        }
        let ok = BASAutoRouteRanker.sovereignVerifyChain(
            initialHash32: initial,
            entries: entries,
            expectedFinalHash32: current)
        XCTAssertEqual(ok, false,
            "Tampered chain link must verify as false")
        #endif
    }

    func testSovereignVerifyChainBadHashLengthReturnsNil() {
        #if os(iOS) || os(macOS)
        let badInit = [UInt8](repeating: 0, count: 16)
        let goodFinal = [UInt8](repeating: 0, count: 32)
        XCTAssertNil(
            BASAutoRouteRanker.sovereignVerifyChain(
                initialHash32: badInit,
                entries: [],
                expectedFinalHash32: goodFinal))
        #endif
    }
}
