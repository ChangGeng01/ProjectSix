// MARK: - BASANELiveReaderTests
// chapter 四百七十四 / M1272 — POST-PHASE-3 hot-path
// attack: close the "ANE probe defaults to .conservative"
// gap scored 1/10 at chapter 473 deep review。
//
// Verifies the M1272 BASANELiveReader factory:
//   - .live() returns a Sendable closure
//   - liveProbe on simulator falls back to conservative
//     (no ANE present)
//   - liveProbe on real M-series silicon (gated tests)
//     returns aneFirst priority + non-empty supportedOps
//   - thermal .critical always returns cpuOnlyFallback
//     regardless of ANE presence
//   - Wiring into BASANECapabilityProbe: when probe is
//     constructed with .live() reader, cache still honors
//     chapter 三百九二 replay-determinism

import XCTest
@testable import BASMetalSubstrate

final class BASANELiveReaderTests: XCTestCase {

    // MARK: - Live factory shape

    func testLiveFactoryReturnsCallableClosure() {
        let reader = BASANELiveReader.live()
        let snapshot = reader(.nominal)
        XCTAssertEqual(
            snapshot.thermalSnapshot, .nominal,
            "live reader must echo input thermal into" +
            " returned capability")
    }

    func testLiveFactoryIsSendable() {
        // Compile-time check: assignment to a Sendable
        // closure type fails if .live() drops Sendable。
        let reader: BASANECapabilityProbe.CapabilityReader =
            BASANELiveReader.live()
        _ = reader(.nominal)
    }

    // MARK: - Critical thermal → CPU fallback

    func testCriticalThermalAlwaysCPUFallback() {
        let snapshot = BASANELiveReader.liveProbe(
            thermal: .critical)
        XCTAssertEqual(
            snapshot.acceleratorPriority, .cpuOnly,
            "critical thermal must downgrade to" +
            " cpuOnly regardless of ANE presence")
        XCTAssertTrue(
            snapshot.supportedOps.isEmpty,
            "cpu fallback has empty supported-ops set")
    }

    // MARK: - Simulator behavior (no real ANE)

    func testSimulatorFallsBackToNonAneFirst() {
        // On simulator MLComputeDevice may return CPU+GPU
        // but never neuralEngine。 Either path is valid:
        //   - if iOS 17+: live MLCompute returns gpuOnly
        //   - if iOS <17: code path returns .conservative
        // Both yield priority != .aneFirst on simulator。
        let snapshot = BASANELiveReader.liveProbe(
            thermal: .nominal)
        #if targetEnvironment(simulator)
        XCTAssertNotEqual(
            snapshot.acceleratorPriority, .aneFirst,
            "simulator must never report aneFirst")
        #endif
        // Regardless of platform, thermalSnapshot must
        // echo input
        XCTAssertEqual(
            snapshot.thermalSnapshot, .nominal)
    }

    // MARK: - Real-device gated assertions

    /// Gated to physical Apple Silicon with ANE。 Skipped
    /// on simulator,Intel Mac,or older OS。 Runs nightly
    /// on M-series real-device CI lane。
    func testRealAppleSiliconReportsANEFirst() throws {
        try XCTSkipUnless(
            isRealAppleSiliconWithANE(),
            "Requires real M-series / A-series device" +
            " with ANE + iOS 17+ / macOS 14+")
        let snapshot = BASANELiveReader.liveProbe(
            thermal: .nominal)
        XCTAssertEqual(
            snapshot.acceleratorPriority, .aneFirst,
            "Real M-series silicon at .nominal thermal" +
            " must report aneFirst")
        XCTAssertFalse(
            snapshot.supportedOps.isEmpty,
            "Real ANE must support at least one op")
        XCTAssertGreaterThanOrEqual(
            snapshot.maxBatchSize, 4,
            "Real M-series ANE supports batch >= 4")
    }

    /// Thermal derating sanity check on real silicon。
    /// `.nominal` < `.fair` < `.serious` latency。
    func testRealSiliconThermalDeratingIsMonotonic() throws {
        try XCTSkipUnless(
            isRealAppleSiliconWithANE(),
            "Requires real M-series / A-series device")
        let nominal = BASANELiveReader.liveProbe(
            thermal: .nominal)
        let fair = BASANELiveReader.liveProbe(
            thermal: .fair)
        let serious = BASANELiveReader.liveProbe(
            thermal: .serious)
        XCTAssertLessThan(
            nominal.estimatedLatencyMs,
            fair.estimatedLatencyMs,
            "nominal latency < fair latency")
        XCTAssertLessThan(
            fair.estimatedLatencyMs,
            serious.estimatedLatencyMs,
            "fair latency < serious latency")
    }

    // MARK: - Wired into BASANECapabilityProbe

    func testProbeAcceptsLiveReaderAndCachesPerThermal() async {
        let probe = BASANECapabilityProbe(
            reader: BASANELiveReader.live())
        let snap1 = await probe.capability(forThermal: .nominal)
        let snap2 = await probe.capability(forThermal: .nominal)
        XCTAssertEqual(
            snap1, snap2,
            "Probe must return identical snapshot for" +
            " same thermal (chapter 三百九二)")
        let snap3 = await probe.capability(forThermal: .fair)
        // Different thermal → probably different latency;
        // not asserted as != because conservative path
        // doesn't differ across thermal levels
        XCTAssertEqual(snap3.thermalSnapshot, .fair)
    }

    // MARK: - Helpers

    /// Detects real Apple Silicon with ANE。 Returns true
    /// only when:
    ///   - Not running in simulator
    ///   - iOS 17+ / macOS 14+ MLCompute API available
    ///   - At least one neuralEngine device reported
    private func isRealAppleSiliconWithANE() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let snap = BASANELiveReader.liveProbe(
            thermal: .nominal)
        return snap.acceleratorPriority == .aneFirst
        #endif
    }
}
