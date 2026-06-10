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
}
