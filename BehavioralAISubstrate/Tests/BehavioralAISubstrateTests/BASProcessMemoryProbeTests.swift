// MARK: - BASProcessMemoryProbeTests
// 主线 全面 提升: C pilot second-function tests。
// Pins the bas_process_resident_memory_bytes ABI +
// the Swift wrapper's typed surface。

import XCTest
@testable import BASRuntimeCore

final class BASProcessMemoryProbeTests: XCTestCase {

    // MARK: - C ABI version pin

    func testCBridgeABIVersionMatches() {
        XCTAssertEqual(
            BASProcessMemoryProbe.cBridgeABIVersion,
            BASProcessMemoryProbe
                .liveCBridgeABIVersion(),
            "Swift-side version pin must mirror live" +
            " C-side version (catches ABI drift)")
    }

    func testInitialVersionIsOne() {
        XCTAssertEqual(
            BASProcessMemoryProbe.cBridgeABIVersion, 1)
    }

    // MARK: - V1 path (useCBridge = false)

    func testV1PathReturnsZero() async throws {
        let probe = BASProcessMemoryProbe(
            useCBridge: false)
        let v = try await probe.current()
        XCTAssertEqual(v, 0,
            "V1 path returns 0 (no syscall)")
        let usingBridge = await probe.isUsingCBridge
        XCTAssertFalse(usingBridge)
    }

    // MARK: - V2 path returns realistic RSS

    func testV2PathReturnsRealisticRSS() async throws {
        let probe = BASProcessMemoryProbe(
            useCBridge: true)
        let v = try await probe.current()
        XCTAssertGreaterThan(v, 0,
            "Resident memory must be > 0 for a running" +
            " process。 Got \(v) bytes")
        XCTAssertLessThan(v, 10_000_000_000,
            "Test process resident memory should not" +
            " exceed 10GB。 Got \(v) bytes")
    }

    // MARK: - Repeated calls are stable + cheap

    func testRepeatedCallsAreCheap() async throws {
        let probe = BASProcessMemoryProbe(
            useCBridge: true)
        let start = Date()
        for _ in 0..<1000 {
            _ = try await probe.current()
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 1.0,
            "1000 RSS reads took \(elapsed)s, expected" +
            " < 1s (mach_task_basic_info is a userspace" +
            " fast path)")
    }

    // MARK: - Codable error round-trip

    func testErrorCasesAreCodable() throws {
        let cases: [BASProcessMemoryProbeError] = [
            .nullOutPointer,
            .machTaskInfoFailed,
            .unsupportedPlatform,
            .unknownReturnCode(-99),
        ]
        for c in cases {
            let data = try JSONEncoder().encode(c)
            let decoded = try JSONDecoder().decode(
                BASProcessMemoryProbeError.self,
                from: data)
            XCTAssertEqual(decoded, c)
        }
    }

    func testCaseIdentifiersAreStable() {
        XCTAssertEqual(
            BASProcessMemoryProbeError.nullOutPointer
                .caseIdentifier,
            "nullOutPointer")
        XCTAssertEqual(
            BASProcessMemoryProbeError
                .machTaskInfoFailed.caseIdentifier,
            "machTaskInfoFailed")
        XCTAssertEqual(
            BASProcessMemoryProbeError
                .unsupportedPlatform.caseIdentifier,
            "unsupportedPlatform")
        XCTAssertEqual(
            BASProcessMemoryProbeError
                .unknownReturnCode(-99).caseIdentifier,
            "unknownReturnCode")
    }
}
