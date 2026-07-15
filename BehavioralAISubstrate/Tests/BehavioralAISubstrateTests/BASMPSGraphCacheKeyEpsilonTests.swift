import XCTest
@testable import BASMetalSubstrate

/// audit M-l / metal #4 — RMSNorm / LayerNorm bake `epsilon` into the compiled MPSGraph executable,
/// but the cache key was (operation, dataType, inputShapes) only. Two instances differing ONLY in
/// epsilon collided on one key, so the second reused the first's baked epsilon → wrong numerics.
/// The key now carries `epsilonBits`. Pure-Swift (no GPU): the fix is entirely in the key's
/// identity; GPU is needed only to confirm the resulting numerics, not to prove the partitioning.
final class BASMPSGraphCacheKeyEpsilonTests: XCTestCase {

    private let shapes = [[4, 8], [8]]

    func testDifferentEpsilonYieldsDifferentKey() {
        let k1 = BASMPSGraphCacheKey(operation: .rmsNorm, dataType: .float32,
                                     inputShapes: shapes, epsilonBits: Float(1e-6).bitPattern)
        let k2 = BASMPSGraphCacheKey(operation: .rmsNorm, dataType: .float32,
                                     inputShapes: shapes, epsilonBits: Float(1e-5).bitPattern)
        XCTAssertNotEqual(k1, k2,
            "same op/dtype/shapes but different baked epsilon MUST be different cache entries (metal#4)")
        XCTAssertNotEqual(k1.hashValue, k2.hashValue)
    }

    func testSameEpsilonYieldsSameKey() {
        let k1 = BASMPSGraphCacheKey(operation: .rmsNorm, dataType: .float32,
                                     inputShapes: shapes, epsilonBits: Float(1e-6).bitPattern)
        let k3 = BASMPSGraphCacheKey(operation: .rmsNorm, dataType: .float32,
                                     inputShapes: shapes, epsilonBits: Float(1e-6).bitPattern)
        XCTAssertEqual(k1, k3, "same epsilon → same key (a correct cache hit)")
    }

    func testNonEpsilonOpsPartitionUnchanged() {
        // Ops that bake no such constant leave epsilonBits nil → key partitions exactly as before.
        let a1 = BASMPSGraphCacheKey(operation: .attention, dataType: .float32, inputShapes: shapes)
        let a2 = BASMPSGraphCacheKey(operation: .attention, dataType: .float32, inputShapes: shapes)
        XCTAssertEqual(a1, a2, "non-epsilon ops unchanged (byte-equal partitioning)")
        XCTAssertNil(a1.epsilonBits)
    }
}
