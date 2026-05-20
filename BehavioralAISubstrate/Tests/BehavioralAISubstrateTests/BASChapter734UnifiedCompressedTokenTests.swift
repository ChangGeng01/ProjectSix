// MARK: - BASChapter734UnifiedCompressedTokenTests
// chapter 七百三十四 第四刀 / M2344
//
// Anti-drift suite for the unified BASKVCacheCompressedToken
// sum-type。 Validates:
//
//   1. Each tier compresses + decompresses end-to-end via the
//      unified API
//   2. tier discriminant + memory properties are correctly
//      reported per case
//   3. Codable wire format round-trips for all 3 cases
//   4. Cross-tier comparison shows the expected shrink ratios
//      (Float32 1× / Float16 2× / int8 4×)

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter734UnifiedCompressedTokenTests: XCTestCase {

    private func unitVector(
        seed: UInt64, dim: Int
    ) -> [Float] {
        var s = seed
        var v = [Float](repeating: 0, count: dim)
        for i in 0..<dim {
            s &+= 0x9E37_79B9_7F4A_7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z = z ^ (z >> 31)
            v[i] = (Float(z & 0xFFFF_FFFF)
                / Float(UInt32.max)) * 2 - 1
        }
        var sumSq: Float = 0
        for x in v { sumSq += x * x }
        let mag = sqrt(sumSq)
        if mag > 0 {
            for i in 0..<dim { v[i] /= mag }
        }
        return v
    }

    private func makeToken(
        seed: UInt64, dim: Int
    ) -> BASTransformerKVCacheToken {
        let k = unitVector(seed: seed * 7, dim: dim)
        let v = unitVector(seed: seed * 11 + 3, dim: dim)
        let kBytes = k.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let vBytes = v.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        return BASTransformerKVCacheToken(
            keyBytes: kBytes,
            valueBytes: vBytes,
            elementCount: dim)
    }

    // MARK: - tier discriminant correctness

    func testTierDiscriminantMatchesEnumCase() {
        let token = makeToken(seed: 1, dim: 64)
        let f32 = token.compressed(tier: .float32)!
        let f16 = token.compressed(tier: .float16)!
        let i8  = token.compressed(tier: .int8)!
        XCTAssertEqual(f32.tier, .float32)
        XCTAssertEqual(f16.tier, .float16)
        XCTAssertEqual(i8.tier, .int8)
    }

    // MARK: - All 3 tiers round-trip

    func testAllThreeTiersRoundTripBack() {
        for tier in BASKVCachePrecisionTier.allCases {
            let token = makeToken(seed: 7, dim: 64)
            let compressed = token.compressed(tier: tier)
            XCTAssertNotNil(
                compressed,
                "compress failed for tier \(tier)")
            let back = compressed?.decompressed()
            XCTAssertNotNil(
                back,
                "decompress failed for tier \(tier)")
            XCTAssertEqual(
                back?.elementCount, token.elementCount,
                "elementCount mismatch for tier \(tier)")
        }
    }

    // MARK: - Element count preserved across all 3 tiers

    func testElementCountPreservedAcrossTiers() {
        let dim = 128
        let token = makeToken(seed: 11, dim: dim)
        for tier in BASKVCachePrecisionTier.allCases {
            let c = token.compressed(tier: tier)!
            XCTAssertEqual(c.elementCount, dim)
        }
    }

    // MARK: - Memory shrink ratios match the tier asymptotes

    func testMemoryShrinkRatiosMatchTierExpectations() {
        let dim = 512  // large enough that overhead is small
        let token = makeToken(seed: 13, dim: dim)

        let f32 = token.compressed(tier: .float32)!
        let f16 = token.compressed(tier: .float16)!
        let i8  = token.compressed(tier: .int8)!

        // Float32 is the baseline — ratio ≈ 1 (slightly less
        // than 1 because compressed wraps adds the elementCount
        // Int overhead)
        XCTAssertGreaterThan(
            f32.memoryShrinkRatio, 0.95)
        XCTAssertLessThan(
            f32.memoryShrinkRatio, 1.05)

        // Float16 ≈ 2×
        XCTAssertGreaterThan(
            f16.memoryShrinkRatio, 1.9)
        XCTAssertLessThan(
            f16.memoryShrinkRatio, 2.1)

        // int8 ≈ 4×
        XCTAssertGreaterThan(
            i8.memoryShrinkRatio, 3.8)
        XCTAssertLessThan(
            i8.memoryShrinkRatio, 4.1)

        print("")
        print(String(
            format: "  Float32: %.2f×",
            f32.memoryShrinkRatio))
        print(String(
            format: "  Float16: %.2f×",
            f16.memoryShrinkRatio))
        print(String(
            format: "  int8:    %.2f×",
            i8.memoryShrinkRatio))
        print("")
    }

    // MARK: - Codable wire format round-trip per tier

    func testCodableWireFormatRoundTripFloat32() throws {
        let token = makeToken(seed: 23, dim: 64)
        let original = token.compressed(tier: .float32)!
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(original)
        let back = try JSONDecoder().decode(
            BASKVCacheCompressedToken.self, from: data)
        XCTAssertEqual(original, back)
        XCTAssertEqual(back.tier, .float32)
    }

    func testCodableWireFormatRoundTripFloat16() throws {
        let token = makeToken(seed: 29, dim: 64)
        let original = token.compressed(tier: .float16)!
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(original)
        let back = try JSONDecoder().decode(
            BASKVCacheCompressedToken.self, from: data)
        XCTAssertEqual(original, back)
        XCTAssertEqual(back.tier, .float16)
    }

    func testCodableWireFormatRoundTripInt8() throws {
        let token = makeToken(seed: 31, dim: 64)
        let original = token.compressed(tier: .int8)!
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(original)
        let back = try JSONDecoder().decode(
            BASKVCacheCompressedToken.self, from: data)
        XCTAssertEqual(original, back)
        XCTAssertEqual(back.tier, .int8)
    }

    // MARK: - Tier metadata

    func testTierAsymptoticShrinkRatios() {
        XCTAssertEqual(
            BASKVCachePrecisionTier.float32
                .asymptoticShrinkRatio,
            1.0)
        XCTAssertEqual(
            BASKVCachePrecisionTier.float16
                .asymptoticShrinkRatio,
            2.0)
        XCTAssertEqual(
            BASKVCachePrecisionTier.int8
                .asymptoticShrinkRatio,
            4.0)
    }

    func testTierMeasuredMaxDriftValues() {
        // Pinned values from chapter 七百三十三 第三刀 3-way
        // drift comparison。
        XCTAssertEqual(
            BASKVCachePrecisionTier.float32
                .measuredMaxDrift,
            0.0)
        XCTAssertEqual(
            BASKVCachePrecisionTier.float16
                .measuredMaxDrift,
            0.000051)
        XCTAssertEqual(
            BASKVCachePrecisionTier.int8
                .measuredMaxDrift,
            0.000879)
    }

    // MARK: - All cases enumeration (exhaustiveness)

    func testAllCasesEnumerationIs3() {
        XCTAssertEqual(
            BASKVCachePrecisionTier.allCases.count, 3)
        XCTAssertEqual(
            Set(BASKVCachePrecisionTier.allCases),
            Set([.float32, .float16, .int8]))
    }
}
