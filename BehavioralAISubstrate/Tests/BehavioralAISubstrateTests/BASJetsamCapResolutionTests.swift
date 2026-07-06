import XCTest
@testable import BASMLXAdapter

/// 缝7 gates: the runtime-resolved per-process cap. On macOS the resolver must return nil (no
/// per-process jetsam semantics) so every pure default falls back to the 2026-06-12 conservative
/// constant — Mac tests stay deterministic. On DEVICE (BAS_JETSAM_CAP_PROBE=1) the resolver must
/// return a plausible cap; on an increased-memory-limit host that is ~6.29GB on the 12GB Air
/// (the FRONTIER_2026H2 measured truth the 3376MB constant under-admitted by ~2.9GB).
final class BASJetsamCapResolutionTests: XCTestCase {

    func testMacFallsBackToConservativeConstant() {
        #if os(iOS)
        throw XCTSkip("Mac-only determinism gate")
        #else
        XCTAssertNil(BASMLXMemoryModel.resolvedActiveHardCapBytes(),
                     "macOS must not fabricate a jetsam cap")
        // The pure admission default therefore keeps the calibrated fallback behavior.
        XCTAssertEqual(BASMLXMemoryModel.measuredIPhoneAirActiveHardCapBytes, 3_376 * 1024 * 1024)
        #endif
    }

    func testDeviceResolvesEntitlementAwareCap() throws {
        guard ProcessInfo.processInfo.environment["BAS_JETSAM_CAP_PROBE"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_JETSAM_CAP_PROBE=1 (device)")
        }
        #if os(iOS)
        let cap = try XCTUnwrap(BASMLXMemoryModel.resolvedActiveHardCapBytes(),
                                "device resolver returned nil — probe broke")
        let mb = cap / (1024 * 1024)
        print("[jetsam-cap] resolved per-process cap = \(mb) MB (fallback constant = 3376 MB)")
        XCTAssertGreaterThan(mb, 3_376, "entitled test host must resolve ABOVE the stale constant")
        XCTAssertLessThan(mb, 12_288, "cap cannot exceed physical memory")
        #else
        throw XCTSkip("device-only")
        #endif
    }
}
