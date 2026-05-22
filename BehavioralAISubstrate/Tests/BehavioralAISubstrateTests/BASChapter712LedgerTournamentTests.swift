// MARK: - BASChapter712LedgerTournamentTests
// chapter 七百十二 第三刀 / M2233
//
// Tournament across (Swift CryptoKit per-entry SHA256,Rust
// per-entry FFI,Rust batch FFI) at chain depths 1/16/256/4096。
//
// Hypothesis:
//   - At depth 1 the FFI overhead dominates → CryptoKit wins。
//   - At depth ≥ 16 the batched Rust call amortizes FFI →
//     batched Rust wins。
//   - Per-entry Rust FFI stays slower than CryptoKit at all
//     depths because each call pays the unsafe-pointer dance。
//
// Use this output to pick the .ledgerBatchMinEntries threshold
// in chapter 七百十二 第四刀 BASAutoRouteThresholds。

import XCTest
import Foundation
import CryptoKit
@testable import BASRuntimeCore
@testable import BASHostKit

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter712LedgerTournamentTests: XCTestCase {

    /// Chapter 八百七十九 / M3080 — print-only archive skip per
    /// chapter 709/711 pattern。 Ledger tournament doesn't have
    /// asserted-bench replacement yet。
    override func setUp() async throws {
        try await super.setUp()
        throw XCTSkip(
            "Chapter 八百七十九 archive skip — print-only" +
            " ledger tournament without asserted-bench" +
            " replacement yet。")
    }

    /// Encode N payloads as length-prefixed flat buffer。
    private func encodeLengthPrefixed(
        _ payloads: [Data]
    ) -> Data {
        var buf = Data()
        for p in payloads {
            var lenBE = UInt32(p.count).bigEndian
            withUnsafeBytes(of: &lenBE) {
                buf.append(contentsOf: $0)
            }
            buf.append(p)
        }
        return buf
    }

    private func makePayloads(
        count: Int, sizeBytes: Int = 128
    ) -> [Data] {
        return (0..<count).map { i in
            var d = Data(count: sizeBytes)
            d[0] = UInt8(i & 0xFF)
            d[1] = UInt8((i >> 8) & 0xFF)
            return d
        }
    }

    private func ledgerTournament(depth: Int) {
        let payloads = makePayloads(count: depth)
        let buf = encodeLengthPrefixed(payloads)
        let initial = [UInt8](repeating: 0, count: 32)

        // Pre-warm allocations
        var swiftSink: UInt8 = 0
        var rustPerSink: UInt8 = 0
        var rustBatchSink: UInt8 = 0

        let res = BASBenchmarkHarness.tournament(
            warmup: 50,
            rounds: 3,
            iterations: depth >= 256 ? 50 : 200,
            contestants: [
                ("Swift CryptoKit chain", {
                    // N individual SHA256 calls
                    var lastByte: UInt8 = 0
                    for p in payloads {
                        let d = SHA256.hash(data: p)
                        lastByte = lastByte &+ d.compactMap
                            { $0 }.first!
                    }
                    swiftSink = swiftSink &+ lastByte
                }),
                ("Rust per-entry FFI", {
                    var lastByte: UInt8 = 0
                    var out = [UInt8](
                        repeating: 0, count: 32)
                    for p in payloads {
                        _ = p.withUnsafeBytes { pp in
                            out
                                .withUnsafeMutableBufferPointer
                                    { op in
                                bas_ranker_ledger_seal(
                                    pp.bindMemory(
                                        to: UInt8.self)
                                        .baseAddress,
                                    p.count,
                                    op.baseAddress)
                            }
                        }
                        lastByte = lastByte &+ out[0]
                    }
                    rustPerSink = rustPerSink &+ lastByte
                }),
                ("Rust batch FFI", {
                    var out = [UInt8](
                        repeating: 0,
                        count: payloads.count * 32)
                    _ = initial.withUnsafeBufferPointer { ip in
                        buf.withUnsafeBytes { bp in
                            out
                                .withUnsafeMutableBufferPointer
                                    { op in
                                bas_ranker_ledger_seal_batch(
                                    ip.baseAddress,
                                    bp.bindMemory(
                                        to: UInt8.self)
                                        .baseAddress,
                                    buf.count,
                                    payloads.count,
                                    op.baseAddress)
                            }
                        }
                    }
                    rustBatchSink = rustBatchSink &+ out[0]
                }),
            ])
        let winner = res.summaries[res.winnerIndex]
        print("BENCH ledger_seal(depth=\(depth)) — winner: "
            + winner.label)
        for s in res.summaries { print("  " + s.formatted) }
        _ = (swiftSink, rustPerSink, rustBatchSink)
    }

    func testLedgerDepth1()    { ledgerTournament(depth: 1) }
    func testLedgerDepth16()   { ledgerTournament(depth: 16) }
    func testLedgerDepth256()  { ledgerTournament(depth: 256) }
    func testLedgerDepth4096() { ledgerTournament(depth: 4096) }

    // MARK: - Verify-chain tournament

    private func verifyChainTournament(depth: Int) {
        let payloads = makePayloads(count: depth)
        let buf = encodeLengthPrefixed(payloads)
        let initial = [UInt8](repeating: 0, count: 32)
        // Pre-compute expected hashes
        let expected: [UInt8] = payloads.flatMap {
            [UInt8](SHA256.hash(data: $0))
        }

        var swiftSink: UInt8 = 0
        var rustSink: UInt8 = 0

        let res = BASBenchmarkHarness.tournament(
            warmup: 50,
            rounds: 3,
            iterations: depth >= 256 ? 50 : 200,
            contestants: [
                ("Swift CryptoKit verify", {
                    // N individual SHA256 + compare
                    var allOk = true
                    for (i, p) in payloads.enumerated() {
                        let d = [UInt8](
                            SHA256.hash(data: p))
                        let expectedSlice = Array(
                            expected[i * 32..<(i + 1) * 32])
                        if d != expectedSlice {
                            allOk = false
                            break
                        }
                    }
                    swiftSink = swiftSink &+
                        (allOk ? 1 : 0)
                }),
                ("Rust batch verify", {
                    var outTip = [UInt8](
                        repeating: 0, count: 32)
                    let rc = initial.withUnsafeBufferPointer
                        { ip in
                        buf.withUnsafeBytes { bp in
                            expected
                                .withUnsafeBufferPointer { ep in
                                outTip
                                    .withUnsafeMutableBufferPointer
                                        { op in
                                    bas_ranker_ledger_verify_chain(
                                        ip.baseAddress,
                                        bp.bindMemory(
                                            to: UInt8.self)
                                            .baseAddress,
                                        buf.count,
                                        ep.baseAddress,
                                        payloads.count,
                                        op.baseAddress)
                                }
                            }
                        }
                    }
                    rustSink = rustSink &+
                        (rc == 0 ? 1 : 0)
                }),
            ])
        let winner = res.summaries[res.winnerIndex]
        print(
            "BENCH ledger_verify(depth=\(depth)) — winner: "
            + winner.label)
        for s in res.summaries { print("  " + s.formatted) }
        _ = (swiftSink, rustSink)
    }

    func testVerifyChainDepth16()
        { verifyChainTournament(depth: 16) }
    func testVerifyChainDepth256()
        { verifyChainTournament(depth: 256) }
    func testVerifyChainDepth4096()
        { verifyChainTournament(depth: 4096) }
}
