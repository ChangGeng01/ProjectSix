// MARK: - BASChapter761CSystemProbesTests
// chapter 七百六十一 第三刀 / M2458
//
// Tests for the L1 C system probes Swift wrappers shipped at
// chapter 七百六十一 第一-二刀。 Covers:
//   - BASWallclockNanos:sleep-INCLUSIVE clock
//   - BASTaskVmInfoProbe:richer memory probe via TASK_VM_INFO

import XCTest
@testable import BASRuntimeCore

final class BASChapter761CSystemProbesTests: XCTestCase {

    // MARK: - BASWallclockNanos: ABI version pin

    func testWallclockNanosABIVersionPinned() {
        XCTAssertEqual(
            BASWallclockNanos.cBridgeABIVersion,
            BASWallclockNanos.liveCBridgeABIVersion(),
            "Swift-side ABI pin must match live C function version")
        XCTAssertEqual(
            BASWallclockNanos.cBridgeABIVersion, 1,
            "bas_wallclock_nanos ABI v1 (chapter 七百六十一 第一刀)")
    }

    // MARK: - BASWallclockNanos: V1 path

    func testWallclockNanosV1Path() async throws {
        let actor = BASWallclockNanos(useCBridge: false)
        let isC = await actor.isUsingCBridge
        XCTAssertFalse(isC,
            "V1 path must use Date()-derived nanos")
        let value = try await actor.current()
        XCTAssertGreaterThan(value, 0,
            "V1 wall-clock nanos must be a positive UNIX epoch nanos")
    }

    // MARK: - BASWallclockNanos: V2 C bridge path

    func testWallclockNanosV2CBridgePath() async throws {
        let actor = BASWallclockNanos(useCBridge: true)
        let isC = await actor.isUsingCBridge
        XCTAssertTrue(isC)
        let value = try await actor.current()
        XCTAssertGreaterThan(value, 0,
            "C bridge wallclock nanos must be positive")
    }

    func testWallclockNanosV2MonotonicallyNonDecreasing() async throws {
        // Two consecutive reads via V2 must produce non-decreasing values
        // (monotonic-clock contract,sleep-INCLUDED)。
        let actor = BASWallclockNanos(useCBridge: true)
        let a = try await actor.current()
        let b = try await actor.current()
        XCTAssertGreaterThanOrEqual(b, a,
            "wall-clock nanos must be monotonically non-decreasing")
    }

    func testWallclockNanosRawCNanosWorks() throws {
        let value = try BASWallclockNanos.rawCNanos()
        XCTAssertGreaterThan(value, 0)
    }

    // MARK: - BASTaskVmInfo: ABI version pin

    func testTaskVmInfoABIVersionPinned() {
        XCTAssertEqual(
            BASTaskVmInfoProbe.cBridgeABIVersion,
            BASTaskVmInfoProbe.liveCBridgeABIVersion(),
            "Swift-side ABI pin must match live C version")
        XCTAssertEqual(
            BASTaskVmInfoProbe.cBridgeABIVersion, 1,
            "bas_task_phys_footprint ABI v1 (chapter 七百六十一 第二刀)")
    }

    // MARK: - BASTaskVmInfoProbe: V1 default returns nil

    func testTaskVmInfoV1DefaultReturnsNil() async throws {
        // V1 path:no Swift equivalent for TASK_VM_INFO,so the
        // actor returns nil when the C bridge is disabled。
        let actor = BASTaskVmInfoProbe(useCBridge: false)
        let snap = try await actor.snapshot()
        XCTAssertNil(snap,
            "V1 path has no equivalent → must return nil")
    }

    // MARK: - BASTaskVmInfoProbe: V2 C bridge

    func testTaskVmInfoV2RawSnapshotProducesPositiveValues() throws {
        let snap = try BASTaskVmInfoProbe.rawSnapshot()
        XCTAssertGreaterThan(snap.physFootprintBytes, 0,
            "test process must have non-zero phys_footprint")
        XCTAssertGreaterThan(snap.internalBytes, 0,
            "test process must have non-zero internal (heap+stack)")
        // compressedBytes may legitimately be zero on a freshly-started
        // test process before the VM compressor has touched any pages。
        XCTAssertGreaterThanOrEqual(snap.compressedBytes, 0)
    }

    func testTaskVmInfoV2WrappedReturnsSnapshot() async throws {
        let actor = BASTaskVmInfoProbe(useCBridge: true)
        let snap = try await actor.snapshot()
        XCTAssertNotNil(snap)
        guard let s = snap else { return }
        XCTAssertGreaterThan(s.physFootprintBytes, 0)
    }

    // MARK: - BASTaskVmInfo struct codability + hashability

    func testTaskVmInfoCodable() throws {
        let original = BASTaskVmInfo(
            physFootprintBytes: 1_048_576,
            compressedBytes: 65_536,
            internalBytes: 512_000)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASTaskVmInfo.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testTaskVmInfoHashable() {
        let a = BASTaskVmInfo(
            physFootprintBytes: 100, compressedBytes: 0,
            internalBytes: 50)
        let b = BASTaskVmInfo(
            physFootprintBytes: 100, compressedBytes: 0,
            internalBytes: 50)
        XCTAssertEqual(a.hashValue, b.hashValue)
        XCTAssertEqual(Set([a, b]).count, 1)
    }

    // MARK: - Equivalence:V2 wallclock + V1 date close in time

    func testWallclockNanosV1AndV2BothPositive() async throws {
        // Both paths produce positive values。 They may differ by
        // arbitrary amounts (V1 is UNIX epoch nanos,V2 is
        // since-boot nanos),so we just verify both nonzero。
        let v1 = BASWallclockNanos.defaultV1Nanos()
        let v2 = try BASWallclockNanos.rawCNanos()
        XCTAssertGreaterThan(v1, 0)
        XCTAssertGreaterThan(v2, 0)
    }

    // MARK: - Error case identifiers stable

    func testWallclockNanosErrorCaseIdentifiers() {
        XCTAssertEqual(
            BASWallclockNanosError.nullOutPointer.caseIdentifier,
            "nullOutPointer")
        XCTAssertEqual(
            BASWallclockNanosError.machTimebaseInitFailed.caseIdentifier,
            "machTimebaseInitFailed")
        XCTAssertEqual(
            BASWallclockNanosError.unsupportedPlatform.caseIdentifier,
            "unsupportedPlatform")
        XCTAssertEqual(
            BASWallclockNanosError.unknownReturnCode(-99).caseIdentifier,
            "unknownReturnCode")
    }

    func testTaskVmInfoErrorCaseIdentifiers() {
        XCTAssertEqual(
            BASTaskVmInfoError.nullOutPointer.caseIdentifier,
            "nullOutPointer")
        XCTAssertEqual(
            BASTaskVmInfoError.machCallFailed.caseIdentifier,
            "machCallFailed")
        XCTAssertEqual(
            BASTaskVmInfoError.unsupportedPlatform.caseIdentifier,
            "unsupportedPlatform")
        XCTAssertEqual(
            BASTaskVmInfoError.unknownReturnCode(-99).caseIdentifier,
            "unknownReturnCode")
    }
}
