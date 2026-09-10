// MARK: - BASCProbesExtendedTests
// 主线 解构 重构: C pilot now exposes four real native
// functions:
//   - bas_monotonic_nanos          (M2175 chapter 703)
//   - bas_process_resident_memory  (主线 提升)
//   - bas_thread_count             (主线 解构 — this commit)
//   - bas_cpu_count_logical        (主线 解构 — this commit)

import XCTest
@testable import BASRuntimeCore
@testable import BASCSystemBridge

final class BASCProbesExtendedTests: XCTestCase {

    // MARK: - BASThreadCountProbe

    func testThreadCountABIVersionPin() {
        XCTAssertEqual(
            BASThreadCountProbe.cBridgeABIVersion, 1)
        XCTAssertEqual(
            BASThreadCountProbe.liveCBridgeABIVersion(), 1,
            "C-side bas_thread_count_version must equal" +
            " Swift-side pin")
    }

    func testThreadCountV1ReturnsZero() async throws {
        let probe = BASThreadCountProbe(useCBridge: false)
        let count = try await probe.current()
        XCTAssertEqual(count, 0,
            "V1 path returns 0 without calling the C bridge")
    }

    func testThreadCountV2ReturnsPositive() async throws {
        let probe = BASThreadCountProbe(useCBridge: true)
        let count = try await probe.current()
        XCTAssertGreaterThan(count, 0,
            "Apple platforms must have at least 1 thread")
        XCTAssertLessThan(count, 10_000,
            "Sanity bound — thread count never reaches" +
            " 10k in normal substrate operation")
    }

    func testThreadCountIsUsingCBridge() async throws {
        let v1 = BASThreadCountProbe(useCBridge: false)
        let v2 = BASThreadCountProbe(useCBridge: true)
        let v1Mode = await v1.isUsingCBridge
        let v2Mode = await v2.isUsingCBridge
        XCTAssertFalse(v1Mode)
        XCTAssertTrue(v2Mode)
    }

    func testThreadCountErrorCaseIdentifiers() {
        // Pin the discriminator strings — cross-pilot
        // caseIdentifier contract from chapter 七百二十。
        XCTAssertEqual(
            BASThreadCountProbeError.nullOutPointer
                .caseIdentifier, "nullOutPointer")
        XCTAssertEqual(
            BASThreadCountProbeError.machTaskThreadsFailed
                .caseIdentifier, "machTaskThreadsFailed")
        XCTAssertEqual(
            BASThreadCountProbeError.unsupportedPlatform
                .caseIdentifier, "unsupportedPlatform")
        XCTAssertEqual(
            BASThreadCountProbeError.unknownReturnCode(-99)
                .caseIdentifier, "unknownReturnCode")
    }

    func testThreadCountErrorCodableRoundTrip() throws {
        let cases: [BASThreadCountProbeError] = [
            .nullOutPointer,
            .machTaskThreadsFailed,
            .unsupportedPlatform,
            .unknownReturnCode(-42),
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(
                BASThreadCountProbeError.self,
                from: data)
            XCTAssertEqual(decoded, original)
        }
    }

    // MARK: - BASCPUCountProbe

    func testCPUCountABIVersionPin() {
        XCTAssertEqual(
            BASCPUCountProbe.cBridgeABIVersion, 1)
        XCTAssertEqual(
            BASCPUCountProbe.liveCBridgeABIVersion(), 1)
    }

    func testCPUCountV1ReturnsZero() async throws {
        let probe = BASCPUCountProbe(useCBridge: false)
        let count = try await probe.current()
        XCTAssertEqual(count, 0)
    }

    func testCPUCountV2ReturnsHostCPUs() async throws {
        let probe = BASCPUCountProbe(useCBridge: true)
        let count = try await probe.current()
        // Apple silicon always has at least 4 cores
        // (efficiency + perf)。 Use 1 as a defensive
        // lower bound for x86 / future hardware。
        XCTAssertGreaterThanOrEqual(count, 1)
        XCTAssertLessThan(count, 1024,
            "Sanity bound — no Apple machine has 1024+" +
            " logical CPUs as of 2026")
    }

    func testCPUCountMatchesProcessInfo() async throws {
        let probe = BASCPUCountProbe(useCBridge: true)
        let cFromBridge = try await probe.current()
        let swiftSide = ProcessInfo.processInfo
            .processorCount
        XCTAssertEqual(Int(cFromBridge), swiftSide,
            "C-side sysctl(HW_NCPU) must match Swift" +
            " ProcessInfo.processorCount — same kernel" +
            " query underneath")
    }

    func testCPUCountErrorCaseIdentifiers() {
        XCTAssertEqual(
            BASCPUCountProbeError.nullOutPointer
                .caseIdentifier, "nullOutPointer")
        XCTAssertEqual(
            BASCPUCountProbeError.sysctlFailed
                .caseIdentifier, "sysctlFailed")
        XCTAssertEqual(
            BASCPUCountProbeError.unsupportedPlatform
                .caseIdentifier, "unsupportedPlatform")
        XCTAssertEqual(
            BASCPUCountProbeError.unknownReturnCode(-99)
                .caseIdentifier, "unknownReturnCode")
    }

    // MARK: - C-side raw functions directly

    func testRawCFunctionsExist() {
        XCTAssertEqual(bas_thread_count_version(), 1)
        XCTAssertEqual(bas_cpu_count_logical_version(), 1)
    }

    func testRawThreadCountWritesPositive() {
        var out: Int32 = -999
        let rc = bas_thread_count(&out)
        XCTAssertEqual(rc, 0)
        XCTAssertGreaterThan(out, 0)
    }

    func testRawCPUCountWritesPositive() {
        var out: Int32 = -999
        let rc = bas_cpu_count_logical(&out)
        XCTAssertEqual(rc, 0)
        XCTAssertGreaterThan(out, 0)
    }
}
