import XCTest
@testable import BASMLXAdapter

/// Pins that `MLXMemoryPolicy` defaults == today's exact adapter defaults, and that the `memoryPolicy:`
/// convenience init is byte-identical to the flat init — the byte-equality proof for the knob grouping.
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

    func testDefaultPolicyInitEqualsDefaultAdapter() {
        let a = MLXOrganAdapter()
        let b = MLXOrganAdapter(memoryPolicy: MLXMemoryPolicy())
        XCTAssertEqual(a.cacheLimitBytes, b.cacheLimitBytes)   // both 512 MB
        XCTAssertEqual(a.memoryLimitBytes, b.memoryLimitBytes) // both nil
        XCTAssertEqual(a.kvCacheBits, b.kvCacheBits)
        XCTAssertEqual(a.maxKVSize, b.maxKVSize)
        XCTAssertEqual(a.enforceMemoryAdmission, b.enforceMemoryAdmission)
        XCTAssertEqual(a.activeHardCapBytes, b.activeHardCapBytes)
        XCTAssertEqual(a.descriptor.providerID, b.descriptor.providerID)
    }

    func testPolicyInitMatchesFlatInitFieldByField() {
        let flat = MLXOrganAdapter(
            cacheLimitBytes: 256 * 1024 * 1024, memoryLimitBytes: 1024,
            kvCacheBits: 4, maxKVSize: 2048,
            enforceMemoryAdmission: true, activeHardCapBytes: 9_000)
        let viaPolicy = MLXOrganAdapter(memoryPolicy: MLXMemoryPolicy(
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
            cacheLimitBytes: 384 * 1024 * 1024, kvCacheBits: 8, enforceMemoryAdmission: true)
        let p = adapter.memoryPolicy
        XCTAssertEqual(p.cacheLimitBytes, 384 * 1024 * 1024)
        XCTAssertEqual(p.kvCacheBits, 8)
        XCTAssertTrue(p.enforceMemoryAdmission)
        XCTAssertNil(p.maxKVSize)
    }
}
