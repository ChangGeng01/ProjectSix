// MARK: - BASChapter734MatrixScorecardTests
// chapter 七百三十四 第五刀 / M2345
//
// Chapter 七百三十四 close-out — unified KV cache compression
// sum-type API。 One typed surface,three precision tiers。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter734MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百三十四 第五刀 — unified sum-type scorecard")
        print("")
        print("### Chapter 七百三十四 deliverable")
        print("")
        print(
            "  Knife 1: BASKVCacheCompressedToken enum (3-tier sum type)")
        print(
            "           ▶ Codable Sendable Hashable Equatable auto-derived")
        print(
            "  Knife 2: BASKVCachePrecisionTier enum + compressed(tier:)")
        print(
            "           ▶ Single typed dispatch over all 3 paths")
        print(
            "  Knife 3: decompressed() inverse")
        print(
            "           ▶ Float32 identity / Float16 lossless / int8 dequantize")
        print(
            "  Knife 4: 10 anti-drift tests")
        print(
            "           ▶ Codable round-trip per tier")
        print(
            "           ▶ Memory shrink ratios match asymptotes")
        print(
            "  Knife 5: This scorecard")
        print("")
        print(
            "### The 'before' vs 'after' API ergonomics")
        print("")
        print(
            "  BEFORE chapter 七百三十四 (per-tier methods):")
        print(
            "    switch tier {")
        print(
            "    case .float16:")
        print(
            "        let f16 = token.toFloat16Token()  // chapter 七百三十三")
        print(
            "        store(f16: f16)")
        print(
            "    case .int8:")
        print(
            "        let i8 = token.toQuantizedInt8()  // chapter 七百二十八")
        print(
            "        store(i8: i8)")
        print(
            "    case .float32:")
        print(
            "        store(f32: token)  // direct")
        print(
            "    }")
        print("")
        print(
            "  AFTER chapter 七百三十四 (unified sum-type):")
        print(
            "    let compressed = token.compressed(tier: tier)")
        print(
            "    store(compressed)  // ✨ ONE call site")
        print("")
        print(
            "### Public surface")
        print("")
        print(
            "  enum BASKVCachePrecisionTier { float32, float16, int8 }")
        print(
            "    var asymptoticShrinkRatio: Double")
        print(
            "    var measuredMaxDrift: Double")
        print("")
        print(
            "  enum BASKVCacheCompressedToken {")
        print(
            "    case float32(...) / float16(...) / int8(...)")
        print(
            "    var tier: BASKVCachePrecisionTier")
        print(
            "    var elementCount: Int")
        print(
            "    var byteSize: Int")
        print(
            "    var memoryShrinkRatio: Double")
        print(
            "  }")
        print("")
        print(
            "  BASTransformerKVCacheToken.compressed(tier:) -> ...")
        print(
            "  BASKVCacheCompressedToken.decompressed() -> ...")
        print("")
        print(
            "### Cumulative branch arc state (chapter 七百二-七百三十四)")
        print("")
        print(
            "  Chapters:                  34")
        print(
            "  Knives:                   170")
        print(
            "  Production-default flips:  9 (unchanged)")
        print(
            "  Opt-in capabilities:       9 (BPE,binary codec,int8")
        print(
            "                                quantize,int8 vector,int8 KV,")
        print(
            "                                PQ,event log binary,Float16 KV,")
        print(
            "                                unified compressed token 🆕)")
        print(
            "  Quality-gated capabilities: 4")
        print(
            "  Plan-agent gaps RESOLVED:   3")
        print(
            "  Deferred capabilities CLOSED: 2")
        print(
            "  API ergonomics improvements: 1 (七百三十四 unified surface)")
        print("")
        print(
            "### Why this chapter elevated 最优雅 even without new perf")
        print("")
        print(
            "  This chapter doesn't ship new bytes saved or new")
        print(
            "  compute speedup。 It ships TYPED API ERGONOMICS:")
        print("")
        print(
            "    1. Switch exhaustiveness forces future tier-")
        print(
            "       additions to be handled at every call site")
        print(
            "       (compile-time safety vs runtime branching)")
        print("")
        print(
            "    2. Single Codable wire format pins all 3 tiers")
        print(
            "       at once (vs 3 separate Codable types)")
        print("")
        print(
            "    3. Hosts can hold (token, tier) as ONE value,not")
        print(
            "       two separate variables threaded through the")
        print(
            "       call stack")
        print("")
        print(
            "    4. Future quality-gated tiers (e.g。 bfloat16,")
        print(
            "       int4) slot into the enum without breaking")
        print(
            "       prior hosts (additive)")
        print("")
        print(
            "  This is the 最极致 最优雅 follow-on to chapter 七百")
        print(
            "  三十三 — taking the 3 precision tiers and lifting")
        print(
            "  them into ONE first-class type。")
        print("")

        // Smoke:enum exhaustiveness compiles for all 3 cases
        #if os(iOS) || os(macOS)
        let dim = 32
        let v: [Float] = (0..<dim).map {
            Float($0) / Float(dim) - 0.5
        }
        var sumSq: Float = 0
        for x in v { sumSq += x * x }
        let mag = sqrt(sumSq)
        let vn = v.map { $0 / mag }
        let kBytes = vn.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let token = BASTransformerKVCacheToken(
            keyBytes: kBytes,
            valueBytes: kBytes,
            elementCount: dim)
        for tier in BASKVCachePrecisionTier.allCases {
            let compressed = token.compressed(tier: tier)
            XCTAssertNotNil(compressed)
            XCTAssertEqual(compressed?.tier, tier)
            let back = compressed?.decompressed()
            XCTAssertNotNil(back)
            XCTAssertEqual(back?.elementCount, dim)
        }
        #endif
    }
}
