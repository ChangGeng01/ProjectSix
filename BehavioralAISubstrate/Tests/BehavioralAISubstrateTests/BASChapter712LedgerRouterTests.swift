// MARK: - BASChapter712LedgerRouterTests
// chapter 七百十二 第四刀 / M2234
//
// Verifies BASAutoRouteRanker.ledgerSeal /
// ledgerSealBatch / ledgerVerifyChain + the BASCognitiveBrain
// helpers:
//
//   1. routing decision lands on the Rust path (matrix duty)
//   2. byte-equality with Swift CryptoKit SHA256
//   3. batch result matches per-entry results
//   4. verify-chain detects tamper at the correct index
//   5. brain helper ≡ ranker call (dual-mode parity)

import XCTest
import Foundation
import CryptoKit
@testable import BASRuntimeCore
@testable import BASHostKit

final class BASChapter712LedgerRouterTests: XCTestCase {

    // MARK: - Single seal

    func testLedgerSealRoutesToRust() {
        let canonical: [UInt8] = Array(
            "audit-entry-payload".utf8)
        let r = BASAutoRouteRanker.ledgerSeal(canonical)
        #if os(iOS) || os(macOS)
        XCTAssertEqual(r.choice, .rustLedgerSeal)
        #endif
        XCTAssertEqual(r.value.count, 32)
    }

    func testLedgerSealMatchesCryptoKit() {
        let canonical: [UInt8] = Array(
            "audit-entry-payload".utf8)
        let r = BASAutoRouteRanker.ledgerSeal(canonical)
        let expected = [UInt8](
            SHA256.hash(data: Data(canonical)))
        XCTAssertEqual(r.value, expected,
            "Rust seal must byte-match Swift CryptoKit")
    }

    func testLedgerSealEmptyPayloadMatchesCryptoKit() {
        let r = BASAutoRouteRanker.ledgerSeal([])
        let expected = [UInt8](
            SHA256.hash(data: Data()))
        XCTAssertEqual(r.value, expected)
    }

    func testLedgerSealNistAnchor() {
        // SHA256("abc") =
        //   ba7816bf8f01cfea414140de5dae2223
        //   b00361a396177a9cb410ff61f20015ad
        let r = BASAutoRouteRanker.ledgerSeal(
            Array("abc".utf8))
        let expected: [UInt8] = [
            0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
            0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
            0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
            0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
        ]
        XCTAssertEqual(r.value, expected)
    }

    // MARK: - Batch seal

    func testLedgerSealBatchMatchesPerEntry() {
        let initial = [UInt8](repeating: 0, count: 32)
        let canonicals: [[UInt8]] = [
            Array("first".utf8),
            Array("second".utf8),
            Array("third".utf8),
            Array("fourth-with-different-length".utf8),
        ]
        let batch = BASAutoRouteRanker.ledgerSealBatch(
            initialHash: initial,
            canonicals: canonicals)
        XCTAssertEqual(batch.value.count, canonicals.count)
        #if os(iOS) || os(macOS)
        XCTAssertEqual(batch.choice, .rustLedgerSealBatch)
        #endif
        for (i, c) in canonicals.enumerated() {
            let perEntry = BASAutoRouteRanker.ledgerSeal(c)
            XCTAssertEqual(batch.value[i], perEntry.value,
                "batch entry \(i) must match per-entry seal")
        }
    }

    func testLedgerSealBatchEmptyReturnsEmpty() {
        let initial = [UInt8](repeating: 0, count: 32)
        let batch = BASAutoRouteRanker.ledgerSealBatch(
            initialHash: initial,
            canonicals: [])
        XCTAssertTrue(batch.value.isEmpty)
    }

    // MARK: - Verify chain

    func testLedgerVerifyChainGoodChainReturnsTip() {
        let initial = [UInt8](repeating: 0, count: 32)
        let canonicals: [[UInt8]] = (0..<8).map {
            Array("entry-\($0)".utf8)
        }
        let expected = canonicals.map { c -> [UInt8] in
            [UInt8](SHA256.hash(data: Data(c)))
        }
        let r = BASAutoRouteRanker.ledgerVerifyChain(
            initialHash: initial,
            canonicals: canonicals,
            expectedSelfHashes: expected)
        #if os(iOS) || os(macOS)
        XCTAssertEqual(r.choice, .rustLedgerVerifyChain)
        #endif
        switch r.value {
        case .valid(let tipHash):
            XCTAssertEqual(tipHash, expected.last!)
        case .firstMismatch:
            XCTFail("good chain must validate")
        }
    }

    func testLedgerVerifyChainDetectsTamper() {
        let initial = [UInt8](repeating: 0, count: 32)
        let canonicals: [[UInt8]] = (0..<5).map {
            Array("entry-\($0)".utf8)
        }
        var expected = canonicals.map { c -> [UInt8] in
            [UInt8](SHA256.hash(data: Data(c)))
        }
        // Tamper entry 2's expected hash
        expected[2][0] ^= 0xFF
        let r = BASAutoRouteRanker.ledgerVerifyChain(
            initialHash: initial,
            canonicals: canonicals,
            expectedSelfHashes: expected)
        switch r.value {
        case .valid:
            XCTFail("tamper must be detected")
        case .firstMismatch(let index):
            XCTAssertEqual(index, 2)
        }
    }

    func testLedgerVerifyChainEmptyReturnsInitialTip() {
        let initial: [UInt8] = (0..<32).map { UInt8($0) }
        let r = BASAutoRouteRanker.ledgerVerifyChain(
            initialHash: initial,
            canonicals: [],
            expectedSelfHashes: [])
        switch r.value {
        case .valid(let tip):
            XCTAssertEqual(tip, initial)
        case .firstMismatch:
            XCTFail("empty chain must validate")
        }
    }

    // MARK: - Brain helpers

    func testBrainLedgerSealMatchesRanker() {
        let canonical: [UInt8] = Array(
            "test-canonical-bytes".utf8)
        let viaBrain = BASCognitiveBrain.ledgerSealAuto(
            canonical)
        let viaRanker = BASAutoRouteRanker.ledgerSeal(
            canonical)
        XCTAssertEqual(viaBrain.choice, viaRanker.choice)
        XCTAssertEqual(viaBrain.value, viaRanker.value)
    }

    func testBrainLedgerVerifyMatchesRanker() {
        let initial = [UInt8](repeating: 0, count: 32)
        let canonicals: [[UInt8]] = (0..<4).map {
            Array("e\($0)".utf8)
        }
        let expected = canonicals.map { c -> [UInt8] in
            [UInt8](SHA256.hash(data: Data(c)))
        }
        let viaBrain =
            BASCognitiveBrain.ledgerVerifyChainAuto(
                initialHash: initial,
                canonicals: canonicals,
                expectedSelfHashes: expected)
        let viaRanker = BASAutoRouteRanker
            .ledgerVerifyChain(
                initialHash: initial,
                canonicals: canonicals,
                expectedSelfHashes: expected)
        XCTAssertEqual(viaBrain.choice, viaRanker.choice)
        XCTAssertEqual(viaBrain.value, viaRanker.value)
    }

    // MARK: - End-to-end round-trip

    func testLedgerSealBatchThenVerifyChainRoundTrip() {
        let initial = [UInt8](repeating: 0, count: 32)
        let canonicals: [[UInt8]] = (0..<64).map {
            var v = [UInt8]()
            v.append(contentsOf: Array("entry-".utf8))
            var iBE = UInt32($0).bigEndian
            withUnsafeBytes(of: &iBE) {
                v.append(contentsOf: $0)
            }
            return v
        }
        // Seal all 64 records in one batch
        let sealed = BASAutoRouteRanker.ledgerSealBatch(
            initialHash: initial,
            canonicals: canonicals)
        XCTAssertEqual(sealed.value.count, 64)
        // Verify with the sealed hashes
        let verify = BASAutoRouteRanker.ledgerVerifyChain(
            initialHash: initial,
            canonicals: canonicals,
            expectedSelfHashes: sealed.value)
        switch verify.value {
        case .valid(let tip):
            XCTAssertEqual(tip, sealed.value.last!)
        case .firstMismatch(let idx):
            XCTFail("round-trip must validate; failed at \(idx)")
        }
    }
}
