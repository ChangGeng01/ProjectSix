// MARK: - BASChapter708ProductionWiringTests
// chapter 七百八 第四刀 / M2214
//
// Validates the brain-level auto-routed SHA256 + HMAC helpers
// + verifies they produce byte-identical output to the legacy
// fixed-impl paths still in use at sovereign + observability +
// host sites。 Demonstrates the OPT-IN production wire pattern。

import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMemory

final class BASChapter708ProductionWiringTests: XCTestCase {

    // MARK: - SHA256 hex helper

    func testSha256HexAutoMatchesCryptoKitOutput() {
        let cases = [
            "",
            "a",
            "the quick brown fox",
            String(repeating: "z", count: 64),
            String(repeating: "0", count: 2048),
        ]
        for s in cases {
            let auto = BASCognitiveBrain.sha256HexAuto(s)
            let cryptoKit = SHA256.hash(
                data: Data(s.utf8))
            let cryptoHex = cryptoKit.map {
                String(format: "%02x", $0)
            }.joined()
            XCTAssertEqual(
                auto.value, cryptoHex,
                "auto-routed output for '\(s.prefix(20))'" +
                " must match CryptoKit")
        }
    }

    func testSha256HexAutoSmallPicksRust() {
        // 16-byte input → Rust path
        let auto = BASCognitiveBrain.sha256HexAuto(
            "0123456789abcdef")
        XCTAssertEqual(auto.choice, .rustPureSHA256)
    }

    func testSha256HexAutoLargePicksCryptoKit() {
        // 2 KB input → CryptoKit
        let big = String(repeating: "x", count: 2048)
        let auto = BASCognitiveBrain.sha256HexAuto(big)
        XCTAssertEqual(auto.choice, .swiftCryptoKit)
    }

    // MARK: - HMAC hex helper

    func testHmacSha256HexAutoSmallPicksRust() {
        let auto = BASCognitiveBrain.hmacSha256HexAuto(
            key: "secret", payload: "short message")
        XCTAssertEqual(auto.choice, .rustHMAC)
        XCTAssertEqual(auto.value.count, 64)
    }

    func testHmacSha256HexAutoLargePicksCryptoKit() {
        let big = String(repeating: "x", count: 2048)
        let auto = BASCognitiveBrain.hmacSha256HexAuto(
            key: "secret", payload: big)
        XCTAssertEqual(
            auto.choice, .swiftCryptoKitHMAC)
        XCTAssertEqual(auto.value.count, 64)
    }

    func testHmacSha256AutoMatchesCryptoKit() {
        // Force both paths and compare
        let payload = "the quick brown fox"
        let keyBytes = Array("secret-key".utf8)

        let rust = BASCognitiveBrain.hmacSha256HexAuto(
            key: "secret-key", payload: payload)
        XCTAssertEqual(rust.choice, .rustHMAC)

        // Direct CryptoKit reference
        let payloadData = Data(payload.utf8)
        let key = SymmetricKey(data: Data(keyBytes))
        let mac = HMAC<SHA256>.authenticationCode(
            for: payloadData, using: key)
        let macHex = mac.map {
            String(format: "%02x", $0)
        }.joined()
        XCTAssertEqual(rust.value, macHex)
    }

    // MARK: - Production-shape end-to-end (audit emission digest)

    /// Verifies the auto-routed SHA256 produces output that
    /// would interop with the substrate's audit-emission digest
    /// shape (chapter 一百八十五 raw-value-stability)。
    func testAuditEmissionDigestShape() {
        let summary =
            "{audit:emission:summary:turn-123:v1}"
        let auto = BASCognitiveBrain.sha256HexAuto(summary)
        XCTAssertEqual(auto.value.count, 64)
        XCTAssertTrue(auto.value.allSatisfy {
            $0.isHexDigit
        })
    }

    /// Determinism — same input → same output across calls。
    func testAutoRouterDeterminism() {
        let payload = "fixed-content"
        let r1 = BASCognitiveBrain.sha256HexAuto(payload)
        let r2 = BASCognitiveBrain.sha256HexAuto(payload)
        let r3 = BASCognitiveBrain.sha256HexAuto(payload)
        XCTAssertEqual(r1.value, r2.value)
        XCTAssertEqual(r2.value, r3.value)
        XCTAssertEqual(r1.choice, r2.choice)
    }
}
