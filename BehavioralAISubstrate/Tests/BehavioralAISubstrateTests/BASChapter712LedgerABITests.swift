// MARK: - BASChapter712LedgerABITests
// chapter 七百十二 第二刀 / M2232
//
// Smoke-tests for the 3 new ledger C ABI exports:
//   - bas_ranker_ledger_seal
//   - bas_ranker_ledger_seal_batch
//   - bas_ranker_ledger_verify_chain
//
// Confirms the XCFramework rebuild correctly carried the new
// `#[no_mangle]` symbols + the Swift bridge sees them through
// the BASRustMemoryTrackerBinary module map。 Byte-identity with
// Swift CryptoKit SHA256 is the contract — these tests pin it。

import XCTest
import Foundation
import CryptoKit
@testable import BASRuntimeCore

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter712LedgerABITests: XCTestCase {

    #if os(iOS) || os(macOS)

    // MARK: - Single-shot seal

    func testLedgerSealMatchesSwiftCryptoKitSHA256() {
        let canonical = "audit-entry-payload".data(
            using: .utf8)!
        var out = [UInt8](repeating: 0, count: 32)
        let rc = canonical.withUnsafeBytes { cp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_ledger_seal(
                    cp.bindMemory(to: UInt8.self)
                        .baseAddress,
                    canonical.count,
                    op.baseAddress)
            }
        }
        XCTAssertEqual(rc, 0)
        let expected = [UInt8](
            SHA256.hash(data: canonical))
        XCTAssertEqual(out, expected,
            "Rust seal must byte-match CryptoKit SHA256")
    }

    func testLedgerSealEmptyPayload() {
        var out = [UInt8](repeating: 0, count: 32)
        let rc = out.withUnsafeMutableBufferPointer { op in
            bas_ranker_ledger_seal(
                nil, 0, op.baseAddress)
        }
        XCTAssertEqual(rc, 0)
        let expected = [UInt8](
            SHA256.hash(data: Data()))
        XCTAssertEqual(out, expected)
    }

    func testLedgerSealRejectsNullOut() {
        let canonical = "x".data(using: .utf8)!
        let rc = canonical.withUnsafeBytes { cp in
            bas_ranker_ledger_seal(
                cp.bindMemory(to: UInt8.self)
                    .baseAddress,
                canonical.count, nil)
        }
        XCTAssertEqual(rc, -1)
    }

    // MARK: - Batch seal

    /// Encode N payloads as `[u32_be size][payload]` flat buffer.
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

    func testLedgerSealBatchMatchesIndividualSHA256() {
        let payloads: [Data] = [
            "first".data(using: .utf8)!,
            "second".data(using: .utf8)!,
            "third".data(using: .utf8)!,
        ]
        let buf = encodeLengthPrefixed(payloads)
        let initial = [UInt8](repeating: 0, count: 32)
        var out = [UInt8](
            repeating: 0, count: payloads.count * 32)
        let rc = initial.withUnsafeBufferPointer { ip in
            buf.withUnsafeBytes { bp in
                out.withUnsafeMutableBufferPointer { op in
                    bas_ranker_ledger_seal_batch(
                        ip.baseAddress,
                        bp.bindMemory(to: UInt8.self)
                            .baseAddress,
                        buf.count,
                        payloads.count,
                        op.baseAddress)
                }
            }
        }
        XCTAssertEqual(rc, 0)
        for (i, p) in payloads.enumerated() {
            let expected = [UInt8](
                SHA256.hash(data: p))
            let actual = Array(
                out[i * 32..<(i + 1) * 32])
            XCTAssertEqual(actual, expected,
                "record \(i) batch hash must match CryptoKit")
        }
    }

    func testLedgerSealBatchEmptyReturnsSuccess() {
        let initial = [UInt8](repeating: 0, count: 32)
        var out: [UInt8] = []
        let rc = initial.withUnsafeBufferPointer { ip in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_ledger_seal_batch(
                    ip.baseAddress,
                    [UInt8]().withUnsafeBufferPointer
                        { $0.baseAddress },
                    0, 0,
                    op.baseAddress)
            }
        }
        XCTAssertEqual(rc, 0)
    }

    // MARK: - Verify chain

    func testLedgerVerifyChainGoodChainReturnsZero() {
        let payloads: [Data] = (0..<8).map {
            "entry-\($0)".data(using: .utf8)!
        }
        let buf = encodeLengthPrefixed(payloads)
        let initial = [UInt8](repeating: 0, count: 32)
        // Pre-compute the expected hashes using CryptoKit
        let expected: [UInt8] = payloads.flatMap {
            [UInt8](SHA256.hash(data: $0))
        }
        var outTip = [UInt8](repeating: 0, count: 32)
        let rc = initial.withUnsafeBufferPointer { ip in
            buf.withUnsafeBytes { bp in
                expected.withUnsafeBufferPointer { ep in
                    outTip.withUnsafeMutableBufferPointer
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
        XCTAssertEqual(rc, 0, "verify must succeed")
        // tip should equal last entry's SHA256
        let lastExpected = [UInt8](
            SHA256.hash(data: payloads.last!))
        XCTAssertEqual(outTip, lastExpected)
    }

    func testLedgerVerifyChainDetectsTamper() {
        let payloads: [Data] = (0..<5).map {
            "entry-\($0)".data(using: .utf8)!
        }
        let buf = encodeLengthPrefixed(payloads)
        let initial = [UInt8](repeating: 0, count: 32)
        var expected: [UInt8] = payloads.flatMap {
            [UInt8](SHA256.hash(data: $0))
        }
        // Tamper entry 2's expected hash
        expected[2 * 32] ^= 0xFF
        var outTip = [UInt8](repeating: 0, count: 32)
        let rc = initial.withUnsafeBufferPointer { ip in
            buf.withUnsafeBytes { bp in
                expected.withUnsafeBufferPointer { ep in
                    outTip.withUnsafeMutableBufferPointer
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
        // Return code is 1 + failing-index = 1 + 2 = 3
        XCTAssertEqual(rc, 3,
            "tamper at index 2 → return code 3 (= 1 + index)")
    }

    func testLedgerVerifyChainEmptyChainReturnsInitial() {
        let initial = (0..<32).map { UInt8($0) }
        var outTip = [UInt8](repeating: 0, count: 32)
        // Pass a single-byte placeholder for the unused
        // canonicals + expected buffers — they're ignored
        // when n == 0 but Swift's withUnsafeBufferPointer
        // may yield nil for empty arrays in some toolchains。
        let placeholder = [UInt8](repeating: 0, count: 1)
        let rc = initial.withUnsafeBufferPointer { ip in
            placeholder.withUnsafeBufferPointer { ph in
                outTip.withUnsafeMutableBufferPointer { op in
                    bas_ranker_ledger_verify_chain(
                        ip.baseAddress,
                        ph.baseAddress, 0,
                        ph.baseAddress, 0,
                        op.baseAddress)
                }
            }
        }
        XCTAssertEqual(rc, 0)
        XCTAssertEqual(outTip, initial,
            "empty chain → tip = initial")
    }

    func testLedgerVerifyChainRejectsTruncatedBuffer() {
        // 3 records' worth of data,but say n=4
        let payloads: [Data] = [
            "one".data(using: .utf8)!,
            "two".data(using: .utf8)!,
            "three".data(using: .utf8)!,
        ]
        let buf = encodeLengthPrefixed(payloads)
        let initial = [UInt8](repeating: 0, count: 32)
        // Allocate 4*32 expected (4th is junk)
        let expected = [UInt8](
            repeating: 0, count: 4 * 32)
        var outTip = [UInt8](repeating: 0, count: 32)
        let rc = initial.withUnsafeBufferPointer { ip in
            buf.withUnsafeBytes { bp in
                expected.withUnsafeBufferPointer { ep in
                    outTip.withUnsafeMutableBufferPointer
                        { op in
                        bas_ranker_ledger_verify_chain(
                            ip.baseAddress,
                            bp.bindMemory(
                                to: UInt8.self)
                                .baseAddress,
                            buf.count,
                            ep.baseAddress,
                            4, // wrong record count
                            op.baseAddress)
                    }
                }
            }
        }
        XCTAssertEqual(rc, -2,
            "truncated buffer must return -2")
    }
    #endif
}
