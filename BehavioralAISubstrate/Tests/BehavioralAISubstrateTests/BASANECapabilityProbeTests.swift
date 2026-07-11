// MARK: - BASANECapabilityProbeTests — chapter 四百三十一 / M1097

import XCTest
@testable import BASMetalSubstrate

final class BASANECapabilityProbeTests: XCTestCase {

    // MARK: - Explicit conservative reader returns conservative

    /// chapter 四百八十 / M1296:default flipped to live
    /// binding。 Tests that need explicit conservative
    /// behavior must opt in via the static factory。
    func testExplicitConservativeReaderReturnsGpuOnly()
        async
    {
        let probe = BASANECapabilityProbe(
            reader: BASANECapabilityProbe
                .conservativeReader())
        let cap = await probe.capability(
            forThermal: .nominal)
        XCTAssertEqual(cap.acceleratorPriority, .gpuOnly,
            "explicit conservative reader must return" +
            " gpu-only priority")
        XCTAssertTrue(cap.supportedOps.isEmpty)
        XCTAssertEqual(cap.thermalSnapshot, .nominal)
    }

    /// chapter 四百八十 / M1296:default reader now uses
    /// live binding on iOS 17+ / macOS 14+。 On simulator
    /// without MLComputeDevice support OR on older OS,
    /// falls back to conservative。 Test asserts the
    /// thermal snapshot flows through regardless of
    /// underlying reader。
    func testDefaultReaderProducesCapabilityWithExpectedThermal()
        async
    {
        let probe = BASANECapabilityProbe()
        let cap = await probe.capability(
            forThermal: .nominal)
        XCTAssertEqual(cap.thermalSnapshot, .nominal,
            "default reader (live or conservative) must" +
            " echo input thermal into capability")
    }

    // MARK: - Cache returns same snapshot for same key

    func testCacheReturnsSameSnapshotForSameThermal() async {
        let probe = BASANECapabilityProbe(
            reader: BASANECapabilityProbe
                .conservativeReader())
        let c1 = await probe.capability(
            forThermal: .nominal)
        let c2 = await probe.capability(
            forThermal: .nominal)
        XCTAssertEqual(c1, c2,
            "repeated reads at same thermal must return" +
            " same snapshot (chapter 三百九二)")
    }

    // MARK: - Cache invalidates on thermal change

    func testCacheInvalidatesOnThermalChange() async {
        let probe = BASANECapabilityProbe(reader: { thermal in
            switch thermal {
            case .nominal:
                return BASANECapability(
                    maxBatchSize: 8,
                    supportedOps: [.matMul],
                    estimatedLatencyMs: 0.5,
                    memoryFootprintMB: 2048,
                    acceleratorPriority: .aneFirst,
                    thermalSnapshot: .nominal)
            case .serious:
                return BASANECapability(
                    maxBatchSize: 1,
                    supportedOps: [],
                    estimatedLatencyMs: 5.0,
                    memoryFootprintMB: 256,
                    acceleratorPriority: .gpuOnly,
                    thermalSnapshot: .serious)
            default:
                return BASANECapability.cpuOnlyFallback(
                    thermalSnapshot: thermal)
            }
        })
        let nominal = await probe.capability(
            forThermal: .nominal)
        let serious = await probe.capability(
            forThermal: .serious)
        XCTAssertEqual(nominal.acceleratorPriority, .aneFirst)
        XCTAssertEqual(serious.acceleratorPriority, .gpuOnly,
            "thermal transition must re-probe + return" +
            " degraded capability")
    }

    // MARK: - Invalidate forces re-probe

    func testInvalidateForcesReprobe() async {
        let counter = AsyncProbeCounter()
        let probe = BASANECapabilityProbe(reader: { thermal in
            Task {
                await counter.increment()
            }
            return BASANECapability.conservative(
                thermalSnapshot: thermal)
        })
        _ = await probe.capability(forThermal: .nominal)   // reader runs (increment pending)
        _ = await probe.capability(forThermal: .nominal)   // cached ⇒ no second reader call
        // The reader increments via a DETACHED Task; a single `Task.yield()` is not a reliable barrier for it
        // to land — that made this test flaky ("1 is not greater than 1"). The cache guarantees exactly ONE
        // pre-invalidate increment and ONE post-invalidate increment, so the VALUES are deterministic; only the
        // Task timing isn't. Poll (bounded) until each settles.
        var countBeforeInvalidate = await counter.value
        for _ in 0..<200 where countBeforeInvalidate < 1 {
            try? await Task.sleep(nanoseconds: 1_000_000)   // 1ms
            countBeforeInvalidate = await counter.value
        }
        await probe.invalidate()
        _ = await probe.capability(forThermal: .nominal)   // invalidate ⇒ reader MUST run again
        var countAfterInvalidate = await counter.value
        for _ in 0..<200 where countAfterInvalidate <= countBeforeInvalidate {
            try? await Task.sleep(nanoseconds: 1_000_000)   // 1ms
            countAfterInvalidate = await counter.value
        }
        XCTAssertGreaterThan(
            countAfterInvalidate, countBeforeInvalidate,
            "invalidate must force the next read to re-" +
            "invoke the reader closure")
    }

    // MARK: - Test introspection accessors

    func testThermalKeyForTestsReflectsLastRead() async {
        let probe = BASANECapabilityProbe()
        let beforeKey = await probe.thermalKeyForTests
        XCTAssertNil(beforeKey, "no read yet → no cached key")
        _ = await probe.capability(forThermal: .fair)
        let afterKey = await probe.thermalKeyForTests
        XCTAssertEqual(afterKey, .fair)
    }

    func testSnapshotForTestsReflectsLastRead() async {
        let probe = BASANECapabilityProbe()
        let beforeSnap = await probe.snapshotForTests
        XCTAssertNil(beforeSnap)
        let read = await probe.capability(
            forThermal: .nominal)
        let afterSnap = await probe.snapshotForTests
        XCTAssertEqual(afterSnap, read)
    }

    // MARK: - Custom reader can return aneFirst

    func testCustomReaderCanReturnANEFirst() async {
        let probe = BASANECapabilityProbe(reader: { _ in
            BASANECapability.nominalAppleSilicon()
        })
        let cap = await probe.capability(
            forThermal: .nominal)
        XCTAssertEqual(
            cap.acceleratorPriority, .aneFirst)
        XCTAssertEqual(cap.supportedOps.count, 7)
    }

    // MARK: - currentCapability uses live thermal

    func testCurrentCapabilityReadsLiveThermalState() async {
        let probe = BASANECapabilityProbe()
        let cap = await probe.currentCapability()
        let liveThermal = BASCapabilityThermalSnapshot
            .current()
        XCTAssertEqual(cap.thermalSnapshot, liveThermal)
    }

    // MARK: - Determinism

    func testProbeIsDeterministicForFixedReader() async {
        let p1 = BASANECapabilityProbe(reader: { _ in
            BASANECapability.nominalAppleSilicon()
        })
        let p2 = BASANECapabilityProbe(reader: { _ in
            BASANECapability.nominalAppleSilicon()
        })
        let r1 = await p1.capability(forThermal: .nominal)
        let r2 = await p2.capability(forThermal: .nominal)
        XCTAssertEqual(r1, r2)
    }
}

// MARK: - Test helper

/// Async-safe counter for probe-invocation tests。
private actor AsyncProbeCounter {
    private(set) var value: Int = 0
    func increment() {
        value += 1
    }
}
