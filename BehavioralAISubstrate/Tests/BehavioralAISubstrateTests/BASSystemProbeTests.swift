// MARK: - BASSystemProbeTests
// chapter 七百四 第四刀 / M2194
//
// Validates the Swift wrapper around the chapter-七百三-第五刀
// C system probes ships sensible values + the actor's
// `isUnderPressure()` predicate behaves correctly。

import XCTest
@testable import BASRuntimeCore

final class BASSystemProbeTests: XCTestCase {

    func testProbeProducesSnapshot() async throws {
        let probe = BASSystemProbe()
        let snap = await probe.probe()
        XCTAssertGreaterThan(snap.cpuLogicalCount, 0,
            "Apple platforms always report >= 1 logical CPU")
        XCTAssertGreaterThan(snap.memoryTotalBytes, 0,
            "Apple platforms always report total memory")
    }

    func testThermalBucketIsValid() async throws {
        let probe = BASSystemProbe()
        let snap = await probe.probe()
        // On macOS the thermal sysctl may or may not be
        // exposed depending on hardware。 nil is acceptable;
        // a value must be in [0,3]。
        if let t = snap.thermalBucket {
            XCTAssertTrue(
                [.nominal, .fair, .serious, .critical]
                    .contains(t))
        }
    }

    func testCPUTopologyConsistency() async throws {
        let probe = BASSystemProbe()
        let snap = await probe.probe()
        // Logical >= physical
        XCTAssertGreaterThanOrEqual(
            snap.cpuLogicalCount, snap.cpuPhysicalCount)
        // On Apple Silicon: physical == perf + efficiency
        // (Intel returns -1 for perf/efficiency → 0 in
        // Swift)。 We don't pin the exact split because
        // both Intel + Apple Silicon hosts run tests。
        XCTAssertGreaterThanOrEqual(snap.cpuPhysicalCount, 0)
    }

    func testMemoryPressureInRange() async throws {
        let probe = BASSystemProbe()
        let snap = await probe.probe()
        XCTAssertGreaterThanOrEqual(
            snap.memoryPressurePercent, 0)
        XCTAssertLessThanOrEqual(
            snap.memoryPressurePercent, 100)
    }

    func testVMPageSizeIsPowerOfTwo() async throws {
        let probe = BASSystemProbe()
        let snap = await probe.probe()
        let p = snap.vmPageSize
        XCTAssertGreaterThan(p, 0)
        // Apple platforms use 4 KiB (Intel) or 16 KiB (Apple
        // Silicon)。 Check power-of-two without pinning the
        // exact value。
        XCTAssertEqual(p & (p - 1), 0,
            "VM page size must be a power of two")
    }

    func testSnapshotIsCodable() async throws {
        let probe = BASSystemProbe()
        let snap = await probe.probe()
        let json = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(
            BASSystemSnapshot.self, from: json)
        XCTAssertEqual(snap, decoded)
    }

    func testProbeDeterministicWithinOneCall() async throws {
        // Two consecutive probes may differ slightly (memory
        // pressure can shift) but the cpu topology fields
        // should be stable。
        let probe = BASSystemProbe()
        let s1 = await probe.probe()
        let s2 = await probe.probe()
        XCTAssertEqual(
            s1.cpuLogicalCount, s2.cpuLogicalCount)
        XCTAssertEqual(
            s1.cpuPhysicalCount, s2.cpuPhysicalCount)
        XCTAssertEqual(s1.cpuBrand, s2.cpuBrand)
        XCTAssertEqual(s1.vmPageSize, s2.vmPageSize)
    }

    func testIsUnderPressureRunsOnTestHost() async throws {
        let probe = BASSystemProbe()
        // The test host is unlikely to be under thermal /
        // memory pressure during a normal test run。 We just
        // verify the predicate returns + doesn't crash。
        _ = await probe.isUnderPressure()
    }
}
