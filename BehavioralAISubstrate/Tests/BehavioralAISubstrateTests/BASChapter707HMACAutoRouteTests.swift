// MARK: - BASChapter707HMACAutoRouteTests
// chapter 七百七 第四刀 / M2209
//
// Validates the auto-routed HMAC-SHA256 path:
//   - small payload → Rust pure-HMAC
//   - large payload → CryptoKit HW-accel
//   - byte-equivalent output across both paths (RFC 4231 etc.)

import XCTest
import CryptoKit
@testable import BASRuntimeCore

final class BASChapter707HMACAutoRouteTests: XCTestCase {

    func testSmallPayloadPicksRustHMAC() {
        let key = Array("secret-key".utf8)
        let payload = Array("hi there".utf8)
        let r = BASAutoRouteRanker.hmacSHA256(
            key: key, payload: payload)
        XCTAssertEqual(r.choice, .rustHMAC)
        XCTAssertEqual(r.value.count, 32)
    }

    func testLargePayloadPicksCryptoKit() {
        let key = Array("secret-key".utf8)
        let payload = [UInt8](
            repeating: 0xAB, count: 4096)
        let r = BASAutoRouteRanker.hmacSHA256(
            key: key, payload: payload)
        XCTAssertEqual(r.choice, .swiftCryptoKitHMAC)
        XCTAssertEqual(r.value.count, 32)
    }

    /// Cross-impl agreement: Rust + CryptoKit produce byte-
    /// identical output。 Verified by forcing both paths via
    /// threshold overrides。
    func testRustHMACMatchesCryptoKit() {
        let key = Array("secret-key".utf8)
        let payload = Array(
            "the quick brown fox".utf8)
        // Force Rust (default — small payload picks Rust)
        let rust = BASAutoRouteRanker.hmacSHA256(
            key: key, payload: payload)
        XCTAssertEqual(rust.choice, .rustHMAC)
        // Force CryptoKit via tiny crossover threshold
        let t = BASAutoRouteThresholds(
            cosineSIMDMinDim: 64,
            sha256CryptoKitMinBytes: 1,
            attentionMetalMinProduct: 64)
        let ck = BASAutoRouteRanker.hmacSHA256(
            key: key, payload: payload, thresholds: t)
        XCTAssertEqual(ck.choice, .swiftCryptoKitHMAC)
        XCTAssertEqual(
            rust.value, ck.value,
            "Rust HMAC + CryptoKit HMAC must produce" +
            " byte-identical output")
    }

    /// RFC 4231 test case 1 — well-known reference vector。
    func testRFC4231TestCase1() {
        let key = [UInt8](repeating: 0x0b, count: 20)
        let payload = Array("Hi There".utf8)
        let r = BASAutoRouteRanker.hmacSHA256(
            key: key, payload: payload)
        let expected: [UInt8] = [
            0xb0, 0x34, 0x4c, 0x61, 0xd8, 0xdb, 0x38, 0x53,
            0x5c, 0xa8, 0xaf, 0xce, 0xaf, 0x0b, 0xf1, 0x2b,
            0x88, 0x1d, 0xc2, 0x00, 0xc9, 0x83, 0x3d, 0xa7,
            0x26, 0xe9, 0x37, 0x6c, 0x2e, 0x32, 0xcf, 0xf7,
        ]
        XCTAssertEqual(r.value, expected)
    }

    /// Empty key + empty payload — corner case。
    func testEmptyInputsProduceValidMAC() {
        let r = BASAutoRouteRanker.hmacSHA256(
            key: [], payload: [])
        // Output is 32 bytes regardless of input size
        XCTAssertEqual(r.value.count, 32)
    }
}
