import XCTest
@testable import BASMLXAdapter

/// 结构大重构 — Phase C: pure (framework-free) coverage for `BASMLXMemoryBudget`, the load-time memory budget
/// that resolves to today's single-model values (byte-identical) OR the dual-residency UNION when a speculative
/// draft is co-resident.
final class BASMLXMemoryBudgetTests: XCTestCase {

    private let single512 = 512 * 1024 * 1024

    // MARK: - 1. Single-model resolve = byte-identical to today

    func testSingleModelResolvePassesValuesThroughUnchanged() {
        let b = BASMLXMemoryBudget.resolve(
            targetProviderID: "mlx.gemma4.e4b.it.4bit",
            draftProviderID: nil,
            singleCacheLimitBytes: single512,
            singleMemoryLimitBytes: nil)
        XCTAssertFalse(b.isSpeculativeUnion,
            "no draft ⇒ single-model ⇒ caller applies with .adapterDefault (today's path)")
        XCTAssertEqual(b.cacheLimitBytes, single512, "single-model cache limit must pass through verbatim")
        XCTAssertNil(b.memoryLimitBytes, "single-model memory limit (nil here) must pass through verbatim")
    }

    func testSingleModelResolveHonorsNilCacheLimit() {
        let b = BASMLXMemoryBudget.resolve(
            targetProviderID: "mlx.gemma4.e4b.it.4bit",
            draftProviderID: nil,
            singleCacheLimitBytes: nil,
            singleMemoryLimitBytes: nil)
        XCTAssertNil(b.cacheLimitBytes, "nil single cache limit (unbounded) must stay nil — byte-equal")
        XCTAssertFalse(b.isSpeculativeUnion)
    }

    // MARK: - 2. Union resolve when a draft is configured

    func testUnionLiftsCacheToDualResidencyFloorAndFlagsOverride() {
        let b = BASMLXMemoryBudget.resolve(
            targetProviderID: "mlx.gemma4.e4b.it.4bit",
            draftProviderID: "mlx.gemma4.e2b.it.4bit",
            singleCacheLimitBytes: single512,        // 512 MB < 768 MB floor
            singleMemoryLimitBytes: nil)
        XCTAssertTrue(b.isSpeculativeUnion,
            "a configured draft ⇒ union ⇒ caller applies with .explicitOverride")
        XCTAssertEqual(b.cacheLimitBytes, BASMLXMemoryBudget.dualResidencyCacheFloorBytes,
            "union cache pool is lifted to the dual-residency floor (768 MB) over the single 512 MB")
    }

    func testUnionKeepsSingleCacheWhenItExceedsFloor() {
        let big = 1024 * 1024 * 1024   // 1 GB > 768 MB floor
        let b = BASMLXMemoryBudget.resolve(
            targetProviderID: "mlx.llama3_2.3b.it.4bit",
            draftProviderID: "mlx.llama3_2.1b.it.4bit",
            singleCacheLimitBytes: big,
            singleMemoryLimitBytes: nil)
        XCTAssertEqual(b.cacheLimitBytes, big,
            "when the host's single cache cap already exceeds the floor, keep it (max of the two)")
    }

    func testUnionLeavesMemoryLimitOptIn() {
        let b = BASMLXMemoryBudget.resolve(
            targetProviderID: "mlx.gemma4.e4b.it.4bit",
            draftProviderID: "mlx.gemma4.e2b.it.4bit",
            singleCacheLimitBytes: single512,
            singleMemoryLimitBytes: nil)
        XCTAssertNil(b.memoryLimitBytes,
            "memoryLimit stays opt-in (nil) for the union too — a too-low load cap throttles the load (R1)")
    }

    // MARK: - 3. Resident-byte estimates (diagnostic only)

    func testUnionEstimateSumsBothModels() {
        let b = BASMLXMemoryBudget.resolve(
            targetProviderID: "mlx.gemma4.e4b.it.4bit",
            draftProviderID: "mlx.gemma4.e2b.it.4bit",
            singleCacheLimitBytes: single512,
            singleMemoryLimitBytes: nil)
        let e4b = BASMLXMemoryBudget.approxResidentBytes(forProviderID: "mlx.gemma4.e4b.it.4bit")
        let e2b = BASMLXMemoryBudget.approxResidentBytes(forProviderID: "mlx.gemma4.e2b.it.4bit")
        XCTAssertEqual(b.estimatedResidentBytes, e4b + e2b,
            "the union estimate is the sum of both co-resident models' planning estimates")
        XCTAssertGreaterThan(e4b, e2b, "E4B is the larger target; E2B the smaller draft")
    }

    func testUnknownProviderGetsConservativeEstimate() {
        let unknown = BASMLXMemoryBudget.approxResidentBytes(forProviderID: "mlx.unknown.future.model")
        XCTAssertEqual(unknown, 2 * 1024 * 1024 * 1024,
            "an unmapped entry falls back to a conservative 2 GB so the union never under-counts")
    }

    // MARK: - Pre-load admission (jetsam-cap guard, 2026-06-12 dual-device data)

    private var mib: Int { 1024 * 1024 }

    func testEstimatedPeakFootprintMeasuredAndDerived() {
        // The MEASURED survivors + the DERIVED E4B estimate from the 10h run.
        XCTAssertEqual(
            BASMLXMemoryBudget.estimatedPeakFootprintBytes(forProviderID: "mlx.gemma4.e2b.it.4bit"),
            3_114 * mib, "E2B measured deviceB peak (survived)")
        XCTAssertEqual(
            BASMLXMemoryBudget.estimatedPeakFootprintBytes(forProviderID: "mlx.llama3_2.3b.it.4bit"),
            2_969 * mib, "Llama-3B measured deviceA peak (survived)")
        XCTAssertEqual(
            BASMLXMemoryBudget.estimatedPeakFootprintBytes(forProviderID: "mlx.gemma4.e4b.it.4bit"),
            4_314 * mib, "E4B derived peak (weights + measured Gemma-3n overhead)")
        XCTAssertNil(
            BASMLXMemoryBudget.estimatedPeakFootprintBytes(forProviderID: "mlx.unknown.model"),
            "no basis => nil => admission ADMITS (never refuse what the data can't justify)")
    }

    func testWouldExceedActiveHardCapRefusesE4BAdmitsSurvivors() {
        // Under the measured iPhone Air cap (~3376 MB): E4B refused, the measured survivors admitted.
        XCTAssertTrue(
            BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: "mlx.gemma4.e4b.it.4bit"),
            "E4B (4314+128 MB) crosses the ~3376 MB cap -> refuse (it jetsam'd twice at load)")
        XCTAssertFalse(
            BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: "mlx.gemma4.e2b.it.4bit"),
            "E2B (3114+128 MB) fits under the cap -> admit (survived with 261 MB headroom)")
        XCTAssertFalse(
            BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: "mlx.llama3_2.3b.it.4bit"),
            "Llama-3B (2969+128 MB) fits -> admit (sustained 38.3 tok/s over 10h)")
        XCTAssertFalse(
            BASMLXMemoryBudget.wouldExceedActiveHardCap(targetProviderID: "mlx.unknown.model"),
            "unmeasured => admit (byte-equal-off)")
    }

    func testWouldExceedActiveHardCapAdmitsE4BUnderLargeCap() {
        XCTAssertFalse(
            BASMLXMemoryBudget.wouldExceedActiveHardCap(
                targetProviderID: "mlx.gemma4.e4b.it.4bit", capBytes: 8_000 * mib),
            "under an 8 GB cap E4B (4314 MB) admits")
    }

    func testRecommendedDefaultIsE2BOnConstrainedIPhoneAirElseE4B() {
        XCTAssertEqual(
            MLXModelCatalog.recommendedDefault(),
            MLXModelCatalog.gemma4_E2B_4bit,
            "at the measured iPhone Air cap, the recommended default is E2B (E4B jetsams)")
        XCTAssertEqual(
            MLXModelCatalog.recommendedDefault(forActiveHardCapBytes: 8_000 * mib),
            MLXModelCatalog.gemma4_E4B_4bit,
            "under an 8 GB cap the richer E4B is recommended")
        // Additive only: the hardcoded default catalog entry is unchanged (byte-equal-off).
        XCTAssertEqual(
            MLXModelCatalog.defaultEntries.first,
            MLXModelCatalog.gemma4_E4B_4bit,
            "recommendedDefault() must NOT mutate the pinned defaultEntries ordering")
    }
}
