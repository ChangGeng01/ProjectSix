// MARK: - BASChapter719HexEncoderTests
// chapter 七百十九 第一/二刀 / M2266, M2267
//
// Byte-equality + perf verification for the Rust lookup-table
// hex encoder。 The Swift idiom across 10+ call sites is
// `bytes.map { String(format: "%02x", $0) }.joined()` — slow
// because each byte round-trips through Foundation printf。
// Rust path is ~2 ns/byte via simple 16-entry lookup table。

import XCTest
import Foundation
import CryptoKit
@testable import BASRuntimeCore

final class BASChapter719HexEncoderTests: XCTestCase {

    /// The legacy Swift idiom verbatim — what 10+ production
    /// sites currently use。 Byte-equality test pins that the
    /// Rust path produces IDENTICAL output。
    private func swiftLegacyHexLower(_ bytes: [UInt8]) -> String {
        return bytes.map {
            String(format: "%02x", $0) }.joined()
    }

    // MARK: - Byte-equality (8 cases)

    func testEmptyBytesProducesEmptyString() {
        XCTAssertEqual(
            BASAutoRouteRanker.bytesToHexLower([]),
            "")
    }

    func testSingleZeroByte() {
        XCTAssertEqual(
            BASAutoRouteRanker.bytesToHexLower([0x00]),
            "00")
    }

    func testSingleMaxByte() {
        XCTAssertEqual(
            BASAutoRouteRanker.bytesToHexLower([0xFF]),
            "ff")
    }

    func testNibbleBoundaries() {
        XCTAssertEqual(
            BASAutoRouteRanker.bytesToHexLower(
                [0x0F, 0x10, 0xA0, 0x0A]),
            "0f10a00a")
    }

    func testSHA256AnchorMatchesNIST() {
        // SHA256("abc") = ba7816bf...015ad
        let data = "abc".data(using: .utf8)!
        let digest = [UInt8](SHA256.hash(data: data))
        XCTAssertEqual(
            BASAutoRouteRanker.bytesToHexLower(digest),
            "ba7816bf8f01cfea414140de5dae2223" +
            "b00361a396177a9cb410ff61f20015ad")
    }

    func testFullByteRangeMatchesSwiftIdiom() {
        // Every byte 0..255 in one call。 Output must be
        // byte-identical to the Swift idiom across all 256 inputs。
        let allBytes: [UInt8] = Array(0...255)
        XCTAssertEqual(
            BASAutoRouteRanker.bytesToHexLower(allBytes),
            swiftLegacyHexLower(allBytes))
    }

    func testRandom1024ByteSweep() {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(1024)
        var seed: UInt32 = 0xDEAD_BEEF
        for _ in 0..<1024 {
            seed = seed &* 1664525 &+ 1013904223
            bytes.append(UInt8(seed & 0xFF))
        }
        XCTAssertEqual(
            BASAutoRouteRanker.bytesToHexLower(bytes),
            swiftLegacyHexLower(bytes))
    }

    func testDataOverloadMatches() {
        let data = Data([0xCA, 0xFE, 0xBA, 0xBE])
        XCTAssertEqual(
            BASAutoRouteRanker.dataToHexLower(data),
            "cafebabe")
    }

    // MARK: - Perf measurement (3 sizes)

    private func measureHex(
        bytes: [UInt8],
        useRust: Bool,
        iters: Int
    ) -> Double {
        // Warm
        for _ in 0..<3 {
            _ = useRust
                ? BASAutoRouteRanker
                    .bytesToHexLower(bytes)
                : swiftLegacyHexLower(bytes)
        }
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            _ = useRust
                ? BASAutoRouteRanker
                    .bytesToHexLower(bytes)
                : swiftLegacyHexLower(bytes)
        }
        let end = DispatchTime.now().uptimeNanoseconds
        return Double(end - start) / Double(iters)
    }

    private func tournament(label: String, n: Int) {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(n)
        var seed: UInt32 = 0xCAFE_F00D
        for _ in 0..<n {
            seed = seed &* 1664525 &+ 1013904223
            bytes.append(UInt8(seed & 0xFF))
        }
        let iters = n <= 32 ? 50_000
            : (n <= 1024 ? 5_000 : 500)
        let swiftNs = measureHex(
            bytes: bytes, useRust: false, iters: iters)
        let rustNs = measureHex(
            bytes: bytes, useRust: true, iters: iters)
        let speedup = swiftNs / rustNs
        let winner = swiftNs < rustNs ? "Swift" : "Rust"
        print(String(
            format:
                "BENCH bytesToHexLower(%@) — winner: %@\n" +
                "  Swift idiom:     %8.1f ns/iter\n" +
                "  Rust LUT:        %8.1f ns/iter (%.2fx vs Swift)",
            label, winner, swiftNs, rustNs, speedup))
    }

    func testHex32BytesPerf() {
        tournament(label: "n=32 (SHA256)", n: 32)
    }

    func testHex1024BytesPerf() {
        tournament(label: "n=1024 (1KB blob)", n: 1024)
    }

    func testHex10240BytesPerf() {
        tournament(label: "n=10240 (10KB blob)", n: 10240)
    }
}
