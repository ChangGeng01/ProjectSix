import XCTest
@testable import BASMLXAdapter

/// Pins that `MLXMemoryPolicy` defaults == today's exact adapter defaults, and that the `memoryPolicy:`
/// convenience init matches the flat init for the same explicit model — the byte-equality proof for the knob grouping.
final class MLXMemoryPolicyTests: XCTestCase {

    func testDefaultPolicyReproducesTodaysExactAdapterDefaults() {
        let p = MLXMemoryPolicy()
        XCTAssertEqual(p.cacheLimitBytes, MLXOrganAdapter.defaultCacheLimitBytes) // 512 MB
        XCTAssertEqual(p.cacheLimitBytes, 512 * 1024 * 1024)
        XCTAssertNil(p.memoryLimitBytes)
        XCTAssertNil(p.kvCacheBits)
        XCTAssertNil(p.maxKVSize)
        XCTAssertFalse(p.enforceMemoryAdmission)
        XCTAssertNil(p.activeHardCapBytes)
    }

    func testDefaultPolicyInitEqualsFlatAdapterForSameExplicitModel() {
        let entry = MLXModelCatalog.gemma4_E4B_4bit
        let flat = MLXOrganAdapter(model: entry)
        let grouped = MLXOrganAdapter(
            model: entry,
            memoryPolicy: MLXMemoryPolicy())
        XCTAssertEqual(flat.model, grouped.model)
        XCTAssertEqual(flat.memoryPolicy, grouped.memoryPolicy)
    }

    func testPolicyInitMatchesFlatInitFieldByField() {
        let flat = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E4B_4bit,
            cacheLimitBytes: 256 * 1024 * 1024, memoryLimitBytes: 1024,
            kvCacheBits: 4, maxKVSize: 2048,
            enforceMemoryAdmission: true, activeHardCapBytes: 9_000)
        let viaPolicy = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E4B_4bit,
            memoryPolicy: MLXMemoryPolicy(
                cacheLimitBytes: 256 * 1024 * 1024, memoryLimitBytes: 1024,
                kvCacheBits: 4, maxKVSize: 2048,
                enforceMemoryAdmission: true, activeHardCapBytes: 9_000))
        XCTAssertEqual(flat.cacheLimitBytes, viaPolicy.cacheLimitBytes)
        XCTAssertEqual(flat.memoryLimitBytes, viaPolicy.memoryLimitBytes)
        XCTAssertEqual(flat.kvCacheBits, viaPolicy.kvCacheBits)
        XCTAssertEqual(flat.maxKVSize, viaPolicy.maxKVSize)
        XCTAssertEqual(flat.enforceMemoryAdmission, viaPolicy.enforceMemoryAdmission)
        XCTAssertEqual(flat.activeHardCapBytes, viaPolicy.activeHardCapBytes)
    }

    func testMemoryPolicyAccessorRoundTrips() {
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E4B_4bit,
            cacheLimitBytes: 384 * 1024 * 1024, kvCacheBits: 8, enforceMemoryAdmission: true)
        let p = adapter.memoryPolicy
        XCTAssertEqual(p.cacheLimitBytes, 384 * 1024 * 1024)
        XCTAssertEqual(p.kvCacheBits, 8)
        XCTAssertTrue(p.enforceMemoryAdmission)
        XCTAssertNil(p.maxKVSize)
    }
}
