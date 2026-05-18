// MARK: - BASCSystemProbesRound3Tests
// 主线 解构 重构 Round 3: C pilot now has six native
// functions wrapping mach + sysctl APIs。 This file covers
// the two new round-3 probes (system uptime + physical
// memory)。

import XCTest
@testable import BASRuntimeCore
@testable import BASCSystemBridge

final class BASCSystemProbesRound3Tests: XCTestCase {

    // MARK: - BASSystemUptimeProbe

    func testSystemUptimeABIVersionPin() {
        XCTAssertEqual(
            BASSystemUptimeProbe.cBridgeABIVersion, 1)
        XCTAssertEqual(
            BASSystemUptimeProbe.liveCBridgeABIVersion(),
            1)
    }

    func testSystemUptimeV1ReturnsZero() async throws {
        let probe = BASSystemUptimeProbe(useCBridge: false)
        let uptime = try await probe.current()
        XCTAssertEqual(uptime, 0)
    }

    func testSystemUptimeV2ReturnsPositive() async throws {
        let probe = BASSystemUptimeProbe(useCBridge: true)
        let uptime = try await probe.current()
        XCTAssertGreaterThan(uptime, 0,
            "Apple platform must have been booted before" +
            " this test runs")
        // Sanity: not more than 10 years (Apple silicon
        // doesn't have that uptime)。
        XCTAssertLessThan(uptime, 10 * 365 * 24 * 3600,
            "Uptime sanity bound")
    }

    func testSystemUptimeIncreasesMonotonically()
        async throws
    {
        let probe = BASSystemUptimeProbe(useCBridge: true)
        let t1 = try await probe.current()
        // Sleep ~1.1 seconds to guarantee uptime tick。
        try await Task.sleep(nanoseconds: 1_100_000_000)
        let t2 = try await probe.current()
        XCTAssertGreaterThanOrEqual(t2, t1,
            "Uptime must be monotonic non-decreasing")
        XCTAssertGreaterThanOrEqual(t2 - t1, 1,
            "1.1s sleep → uptime moved ≥ 1 second")
    }

    func testSystemUptimeErrorCaseIdentifiers() {
        XCTAssertEqual(
            BASSystemUptimeProbeError.nullOutPointer
                .caseIdentifier, "nullOutPointer")
        XCTAssertEqual(
            BASSystemUptimeProbeError
                .sysctlOrGettimeofdayFailed
                .caseIdentifier,
            "sysctlOrGettimeofdayFailed")
        XCTAssertEqual(
            BASSystemUptimeProbeError.unsupportedPlatform
                .caseIdentifier, "unsupportedPlatform")
        XCTAssertEqual(
            BASSystemUptimeProbeError.unknownReturnCode(-9)
                .caseIdentifier, "unknownReturnCode")
    }

    // MARK: - BASPhysicalMemoryProbe

    func testPhysicalMemoryABIVersionPin() {
        XCTAssertEqual(
            BASPhysicalMemoryProbe.cBridgeABIVersion, 1)
        XCTAssertEqual(
            BASPhysicalMemoryProbe.liveCBridgeABIVersion(),
            1)
    }

    func testPhysicalMemoryV1ReturnsZero() async throws {
        let probe =
            BASPhysicalMemoryProbe(useCBridge: false)
        let bytes = try await probe.current()
        XCTAssertEqual(bytes, 0)
    }

    func testPhysicalMemoryV2ReturnsPositive() async throws {
        let probe =
            BASPhysicalMemoryProbe(useCBridge: true)
        let bytes = try await probe.current()
        // Sanity bounds:any Apple device shipping has
        // at least 1 GB,no Apple device has 100 TB。
        XCTAssertGreaterThan(bytes, 1_000_000_000,
            "Physical memory must exceed 1 GB on any" +
            " modern Apple device")
        XCTAssertLessThan(bytes, 100_000_000_000_000,
            "Physical memory sanity bound — no Apple" +
            " device has 100 TB of RAM")
    }

    func testPhysicalMemoryMatchesProcessInfo() async throws {
        let probe =
            BASPhysicalMemoryProbe(useCBridge: true)
        let cFromBridge = try await probe.current()
        let swiftSide = ProcessInfo.processInfo
            .physicalMemory
        XCTAssertEqual(cFromBridge, swiftSide,
            "C-side sysctl(HW_MEMSIZE) must match Swift" +
            " ProcessInfo.physicalMemory — same kernel" +
            " query underneath")
    }

    func testPhysicalMemoryErrorCaseIdentifiers() {
        XCTAssertEqual(
            BASPhysicalMemoryProbeError.nullOutPointer
                .caseIdentifier, "nullOutPointer")
        XCTAssertEqual(
            BASPhysicalMemoryProbeError.sysctlFailed
                .caseIdentifier, "sysctlFailed")
        XCTAssertEqual(
            BASPhysicalMemoryProbeError.unsupportedPlatform
                .caseIdentifier, "unsupportedPlatform")
        XCTAssertEqual(
            BASPhysicalMemoryProbeError
                .unknownReturnCode(-9)
                .caseIdentifier, "unknownReturnCode")
    }

    // MARK: - Raw C functions

    func testRawCFunctionVersionPins() {
        XCTAssertEqual(
            bas_system_uptime_seconds_version(), 1)
        XCTAssertEqual(
            bas_physical_memory_bytes_version(), 1)
    }

    func testRawSystemUptimeWritesPositive() {
        var out: Int64 = -999
        let rc = bas_system_uptime_seconds(&out)
        XCTAssertEqual(rc, 0)
        XCTAssertGreaterThan(out, 0)
    }

    func testRawPhysicalMemoryWritesPositive() {
        var out: UInt64 = 0
        let rc = bas_physical_memory_bytes(&out)
        XCTAssertEqual(rc, 0)
        XCTAssertGreaterThan(out, 1_000_000_000)
    }

    // MARK: - RSS / physical memory ratio sanity

    func testRSSIsLessThanPhysicalMemory() async throws {
        let rssProbe =
            BASProcessMemoryProbe(useCBridge: true)
        let physProbe =
            BASPhysicalMemoryProbe(useCBridge: true)
        let rss = try await rssProbe.current()
        let phys = try await physProbe.current()
        XCTAssertLessThan(rss, phys,
            "Our process's RSS must be less than total" +
            " physical RAM — sanity check across the" +
            " two probes")
    }
}
