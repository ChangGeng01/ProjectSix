// MARK: - BASChapter741SovereignSealByteEqualityTests
// chapter 七百四十一 第四刀 / M2379
//
// LAYER-MIGRATION ARC byte-equality gate for the L14
// Sovereign seal port。 50-entry chain test extends chapter
// 七百十六 ergonomics:
//
//   - Chapter 七百十六 proved SHA256(Swift) ≡ SHA256(Rust)
//     for the LOW-LEVEL primitive
//   - Chapter 七百四十一 proves the HIGHER-LEVEL
//     seal_entry path (canonical-bytes assembly + SHA256
//     in ONE Rust call) is byte-equal to a parallel Swift
//     mirror of the same chapter-七百四十一 wire format
//
// ## Wire format pinned (chapter 七百四十一)
//
//   prior_hash(32 bytes) ||
//   u32_be(audit_id_len) || audit_id ||
//   u32_be(session_id_len) || session_id ||
//   u32_be(verdict_ref_len) || verdict_ref ||
//   i64_be(timestamp_ms) ||
//   u32_be(payload_len) || payload
//
// Both the Rust path and the Swift parallel impl must
// produce byte-identical canonical-bytes + SHA256 output
// across 50 random entry shapes (seeded for chapter 392
// replay-determinism)。
//
// ## Honest scope acknowledgment
//
// This test does NOT prove byte-equality with the EXISTING
// L14 Swift wire format
// (basSovereignAuditCanonicalBytes)。 The chapter 七百四十一
// wire is a NEW SHAPE optimized for FFI bulk-transit;the
// existing L14 wire stays untouched on the V1 path。 Hosts
// migrating to the routed seal would adopt the new wire
// format atomically + verify chain integrity via the new
// verify_chain primitive。

import XCTest
import Foundation
import CryptoKit
@testable import BASRuntimeCore

final class BASChapter741SovereignSealByteEqualityTests:
    XCTestCase
{

    // MARK: - SplitMix64 PRNG

    private struct SplitMix64 {
        var state: UInt64
        init(seed: UInt64) { self.state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func nextInt(in range: ClosedRange<Int>)
            -> Int
        {
            let span = UInt64(range.upperBound
                - range.lowerBound + 1)
            return range.lowerBound + Int(next() % span)
        }
        mutating func nextBytes(count: Int) -> [UInt8] {
            var out: [UInt8] = []
            out.reserveCapacity(count)
            for _ in 0..<count {
                out.append(UInt8(next() & 0xFF))
            }
            return out
        }
    }

    // MARK: - Parallel Swift canonical bytes (mirror of Rust)

    /// Build chapter-七百四十一 canonical bytes in Swift。
    /// Verbatim mirror of the Rust function
    /// sovereign_canonical_bytes in chain.rs。 Used as the
    /// byte-equality baseline。
    private func swiftCanonicalBytes(
        priorHash32: [UInt8],
        auditID: String,
        sessionID: String,
        verdictRef: String,
        timestampMs: Int64,
        payload: [UInt8]
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(
            32 + 4 + auditID.utf8.count
            + 4 + sessionID.utf8.count
            + 4 + verdictRef.utf8.count
            + 8 + 4 + payload.count)
        buf.append(contentsOf: priorHash32)
        let auditBytes = Array(auditID.utf8)
        let auditLen = UInt32(auditBytes.count).bigEndian
        withUnsafeBytes(of: auditLen) {
            buf.append(contentsOf: $0)
        }
        buf.append(contentsOf: auditBytes)
        let sessionBytes = Array(sessionID.utf8)
        let sessionLen = UInt32(sessionBytes.count).bigEndian
        withUnsafeBytes(of: sessionLen) {
            buf.append(contentsOf: $0)
        }
        buf.append(contentsOf: sessionBytes)
        let verdictBytes = Array(verdictRef.utf8)
        let verdictLen = UInt32(verdictBytes.count).bigEndian
        withUnsafeBytes(of: verdictLen) {
            buf.append(contentsOf: $0)
        }
        buf.append(contentsOf: verdictBytes)
        let tsBE = timestampMs.bigEndian
        withUnsafeBytes(of: tsBE) {
            buf.append(contentsOf: $0)
        }
        let payloadLen = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: payloadLen) {
            buf.append(contentsOf: $0)
        }
        buf.append(contentsOf: payload)
        return buf
    }

    private func swiftSeal(
        priorHash32: [UInt8],
        auditID: String,
        sessionID: String,
        verdictRef: String,
        timestampMs: Int64,
        payload: [UInt8]
    ) -> (hash: [UInt8], canonical: [UInt8]) {
        let canonical = swiftCanonicalBytes(
            priorHash32: priorHash32,
            auditID: auditID,
            sessionID: sessionID,
            verdictRef: verdictRef,
            timestampMs: timestampMs,
            payload: payload)
        let hash = SHA256.hash(data: Data(canonical))
        return (Array(hash), canonical)
    }

    // MARK: - 50-entry byte-equality

    func testFiftyEntryChainRustEqualsSwift() {
        #if os(iOS) || os(macOS)
        var prng = SplitMix64(seed: 0xCAB_DECAF_C0DE_BAD)
        var current = [UInt8](repeating: 0, count: 32)
        for i in 0..<50 {
            let aid = "audit-\(i)-\(prng.nextInt(in: 0...9999))"
            let sid = "session-\(i)"
            let vr  = "verdict-\(i)"
            let ts  = Int64(1_700_000_000_000 + i)
            let payloadLen = prng.nextInt(in: 0...64)
            let payload = prng.nextBytes(count: payloadLen)

            // Rust path
            let rust = BASAutoRouteRanker.sovereignSealEntry(
                priorHash32: current,
                auditID: aid,
                sessionID: sid,
                verdictRef: vr,
                timestampMs: ts,
                payload: payload)
            XCTAssertNotNil(rust,
                "entry \(i): Rust seal returned nil")

            // Swift mirror
            let swift = swiftSeal(
                priorHash32: current,
                auditID: aid,
                sessionID: sid,
                verdictRef: vr,
                timestampMs: ts,
                payload: payload)

            // Canonical bytes must match exactly
            XCTAssertEqual(
                rust!.canonicalBytes, swift.canonical,
                "entry \(i): canonical bytes mismatch")
            // SHA256 hash must match exactly
            XCTAssertEqual(
                rust!.nextHash32, swift.hash,
                "entry \(i): hash mismatch")

            // Advance chain
            current = rust!.nextHash32
        }
        #endif
    }

    // MARK: - Empty-fields edge cases

    func testEmptyAuditIDByteEquality() {
        #if os(iOS) || os(macOS)
        let prior = [UInt8](repeating: 0, count: 32)
        let rust = BASAutoRouteRanker.sovereignSealEntry(
            priorHash32: prior,
            auditID: "",
            sessionID: "S",
            verdictRef: "V",
            timestampMs: 0,
            payload: [])
        let swift = swiftSeal(
            priorHash32: prior,
            auditID: "", sessionID: "S", verdictRef: "V",
            timestampMs: 0, payload: [])
        XCTAssertNotNil(rust)
        XCTAssertEqual(
            rust!.canonicalBytes, swift.canonical)
        XCTAssertEqual(rust!.nextHash32, swift.hash)
        #endif
    }

    func testEmptyPayloadByteEquality() {
        #if os(iOS) || os(macOS)
        let prior = [UInt8](repeating: 0xCC, count: 32)
        let rust = BASAutoRouteRanker.sovereignSealEntry(
            priorHash32: prior,
            auditID: "A", sessionID: "S",
            verdictRef: "V", timestampMs: 999,
            payload: [])
        let swift = swiftSeal(
            priorHash32: prior,
            auditID: "A", sessionID: "S",
            verdictRef: "V", timestampMs: 999,
            payload: [])
        XCTAssertNotNil(rust)
        XCTAssertEqual(
            rust!.canonicalBytes, swift.canonical)
        XCTAssertEqual(rust!.nextHash32, swift.hash)
        #endif
    }

    // MARK: - Chain replay verification round-trip

    func testFiftyEntryChainReplayRoundTrip() {
        #if os(iOS) || os(macOS)
        var prng = SplitMix64(seed: 0xBABE_FEED_BEEF_BAD)
        let initial = [UInt8](repeating: 0, count: 32)
        var current = initial
        var entries: [[UInt8]] = []
        for i in 0..<50 {
            let r = BASAutoRouteRanker.sovereignSealEntry(
                priorHash32: current,
                auditID: "a-\(i)",
                sessionID: "s",
                verdictRef: "v",
                timestampMs: Int64(i),
                payload: prng.nextBytes(
                    count: prng.nextInt(in: 0...32)))!
            entries.append(r.canonicalBytes)
            current = r.nextHash32
        }
        // Chain verifies with correct final
        XCTAssertEqual(
            BASAutoRouteRanker.sovereignVerifyChain(
                initialHash32: initial,
                entries: entries,
                expectedFinalHash32: current),
            true,
            "50-entry chain must replay-verify")
        // Tamper with last entry → verification fails
        var tampered = entries
        if tampered.count > 0 {
            tampered[tampered.count - 1][32] ^= 0xff
        }
        XCTAssertEqual(
            BASAutoRouteRanker.sovereignVerifyChain(
                initialHash32: initial,
                entries: tampered,
                expectedFinalHash32: current),
            false,
            "tampered entry must fail verification")
        #endif
    }
}
