// MARK: - BASChapter721HexDecoderTests
// chapter 七百二十一 第二刀 / M2277
//
// Byte-equality verification + perf measurement for the Rust
// hex decoder (chapter 七百二十一 第一刀)。 Counterpart to
// chapter 七百十九 encoder tests。
//
// Swift baseline: the substrate's typical hex-parse idiom is
//   hex.chunks(of: 2).compactMap { UInt8($0, radix: 16) }
// which round-trips every 2-char chunk through Foundation's
// UInt8 parser (locale-aware UTF-8 walk + radix arithmetic)。

import XCTest
import Foundation
import CryptoKit
@testable import BASRuntimeCore

final class BASChapter721HexDecoderTests: XCTestCase {

    /// The legacy Swift idiom verbatim — used at multiple
    /// substrate sites that decode SHA256-hex → bytes。
    private func swiftLegacyHexToBytes(_ hex: String) -> [UInt8]? {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var i = hex.startIndex
        while i < hex.endIndex {
            guard let nextI = hex.index(
                i, offsetBy: 2, limitedBy: hex.endIndex),
                let byte = UInt8(hex[i..<nextI], radix: 16)
            else { return nil }
            bytes.append(byte)
            i = nextI
        }
        return bytes
    }

    // MARK: - Byte-equality cases

    func testEmptyHexDecodesToEmpty() {
        XCTAssertEqual(
            BASAutoRouteRanker.hexToBytes(""), [])
    }

    func testSingleByteDecodes() {
        XCTAssertEqual(
            BASAutoRouteRanker.hexToBytes("00"), [0x00])
        XCTAssertEqual(
            BASAutoRouteRanker.hexToBytes("ff"), [0xFF])
        XCTAssertEqual(
            BASAutoRouteRanker.hexToBytes("a5"), [0xA5])
    }

    func testNibbleBoundariesMatchSwift() {
        let hex = "0f10a00a"
        XCTAssertEqual(
            BASAutoRouteRanker.hexToBytes(hex),
            [0x0F, 0x10, 0xA0, 0x0A])
        XCTAssertEqual(
            BASAutoRouteRanker.hexToBytes(hex),
            swiftLegacyHexToBytes(hex))
    }

    func testSHA256AnchorRoundTrip() {
        // SHA256("abc") = ba7816bf...015ad
        let hex = "ba7816bf8f01cfea414140de5dae2223" +
                  "b00361a396177a9cb410ff61f20015ad"
        let bytes = BASAutoRouteRanker.hexToBytes(hex)
        let expected: [UInt8] = [
            0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
            0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
            0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
            0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
        ]
        XCTAssertEqual(bytes, expected)
        XCTAssertEqual(bytes, swiftLegacyHexToBytes(hex))
    }

    func testUppercaseHexAccepted() {
        XCTAssertEqual(
            BASAutoRouteRanker.hexToBytes("DEADBEEF"),
            [0xDE, 0xAD, 0xBE, 0xEF])
    }

    func testMixedCaseHexAccepted() {
        XCTAssertEqual(
            BASAutoRouteRanker.hexToBytes("DeAdBeEf"),
            [0xDE, 0xAD, 0xBE, 0xEF])
    }

    func testOddLengthReturnsNil() {
        XCTAssertNil(
            BASAutoRouteRanker.hexToBytes("abc"))
        XCTAssertNil(
            BASAutoRouteRanker.hexToBytes("a"))
    }

    func testInvalidHexCharsReturnNil() {
        XCTAssertNil(
            BASAutoRouteRanker.hexToBytes("agcd"))
        XCTAssertNil(
            BASAutoRouteRanker.hexToBytes("ZZ00"))
        XCTAssertNil(
            BASAutoRouteRanker.hexToBytes("ab cd"))
        XCTAssertNil(
            BASAutoRouteRanker.hexToBytes("中文"))
    }

    func testFullByteRangeRoundTripAgainstSwift() {
        // For every byte 0..255: encode it via Swift idiom,
        // then decode via Rust route + Swift legacy idiom,
        // both must produce the original byte。
        for b in 0..<256 {
            let byte = UInt8(b)
            let hex = String(format: "%02x", byte)
            let rust = BASAutoRouteRanker.hexToBytes(hex)
            let swift = swiftLegacyHexToBytes(hex)
            XCTAssertEqual(
                rust, swift,
                "byte \(byte) Rust vs Swift mismatch")
            XCTAssertEqual(rust, [byte])
        }
    }

    func testDataOverloadMatches() {
        let hex = "cafebabe"
        let bytes = BASAutoRouteRanker.hexToBytes(hex)!
        let data = BASAutoRouteRanker.hexToData(hex)!
        XCTAssertEqual(Array(data), bytes)
        XCTAssertEqual(data, Data([0xca, 0xfe, 0xba, 0xbe]))
    }

    func testRandom1024ByteSweepMatchesSwift() {
        // Generate 1024 random bytes, encode + decode via
        // both paths, byte-equal outputs。
        var bytes: [UInt8] = []
        bytes.reserveCapacity(1024)
        var seed: UInt32 = 0xCAFE_F00D
        for _ in 0..<1024 {
            seed = seed &* 1664525 &+ 1013904223
            bytes.append(UInt8(seed & 0xFF))
        }
        let hex = BASAutoRouteRanker.bytesToHexLower(bytes)
        let rustDecoded = BASAutoRouteRanker.hexToBytes(hex)
        let swiftDecoded = swiftLegacyHexToBytes(hex)
        XCTAssertEqual(rustDecoded, swiftDecoded)
        XCTAssertEqual(rustDecoded, bytes)
    }

    // MARK: - Perf measurement (3 sizes)

    private func measureDecode(
        hex: String, useRust: Bool, iters: Int
    ) -> Double {
        for _ in 0..<3 {
            _ = useRust
                ? BASAutoRouteRanker.hexToBytes(hex)
                : swiftLegacyHexToBytes(hex)
        }
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            _ = useRust
                ? BASAutoRouteRanker.hexToBytes(hex)
                : swiftLegacyHexToBytes(hex)
        }
        let end = DispatchTime.now().uptimeNanoseconds
        return Double(end - start) / Double(iters)
    }

    private func tournament(label: String, byteCount: Int) {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(byteCount)
        var seed: UInt32 = 0xDEAD_BEEF
        for _ in 0..<byteCount {
            seed = seed &* 1664525 &+ 1013904223
            bytes.append(UInt8(seed & 0xFF))
        }
        let hex = BASAutoRouteRanker.bytesToHexLower(bytes)
        let iters = byteCount <= 64 ? 20_000
            : (byteCount <= 1024 ? 2000 : 200)
        let swiftNs = measureDecode(
            hex: hex, useRust: false, iters: iters)
        let rustNs = measureDecode(
            hex: hex, useRust: true, iters: iters)
        let speedup = swiftNs / rustNs
        let winner = swiftNs < rustNs ? "Swift" : "Rust"
        print(String(
            format:
                "BENCH hexToBytes(%@) — winner: %@\n" +
                "  Swift idiom:     %8.1f ns/iter\n" +
                "  Rust LUT:        %8.1f ns/iter (%.2fx vs Swift)",
            label, winner, swiftNs, rustNs, speedup))
    }

    func testHex64CharsPerf() {
        tournament(label: "n_hex=64 (SHA256)", byteCount: 32)
    }

    func testHex2048CharsPerf() {
        tournament(label: "n_hex=2048 (1KB)", byteCount: 1024)
    }

    func testHex20480CharsPerf() {
        tournament(label: "n_hex=20480 (10KB)", byteCount: 10240)
    }
}
