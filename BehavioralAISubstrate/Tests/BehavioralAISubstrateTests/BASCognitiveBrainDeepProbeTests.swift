// MARK: - BASCognitiveBrainDeepProbeTests
// 持续性 发展: tests for the 2 deeper probes:
//   1. C: bas_process_disk_io_blocks (ru_inblock /
//      ru_oublock via getrusage)
//   2. Rust: atom_count_percentiles (Rust-native sort
//      + nearest-rank percentile FFI)
// Plus their wire-in to brain.healthSnapshot。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore
@testable import BASCSystemBridge
@testable import BASRustCoreBridge

final class BASCognitiveBrainDeepProbeTests: XCTestCase {

    // MARK: - 1. C disk I/O probe

    func testDiskIOProbeABIVersionPin() {
        XCTAssertEqual(
            BASProcessDiskIOProbe.cBridgeABIVersion, 1)
        XCTAssertEqual(
            BASProcessDiskIOProbe.liveCBridgeABIVersion(),
            1)
    }

    func testDiskIOV1ReturnsZeroSample() async throws {
        let probe = BASProcessDiskIOProbe(useCBridge: false)
        let sample = try await probe.current()
        XCTAssertEqual(sample.inputBlocks, 0)
        XCTAssertEqual(sample.outputBlocks, 0)
        XCTAssertEqual(sample.totalBlocks, 0)
    }

    func testDiskIOV2ReturnsNonNegativeSample()
        async throws
    {
        let probe = BASProcessDiskIOProbe(useCBridge: true)
        let sample = try await probe.current()
        // ru_inblock / ru_oublock are cumulative counters
        // that monotonically increase。 0 is a valid value
        // for a fresh process that hasn't done block I/O。
        XCTAssertGreaterThanOrEqual(sample.inputBlocks, 0)
        XCTAssertGreaterThanOrEqual(sample.outputBlocks, 0)
        XCTAssertEqual(sample.totalBlocks,
            sample.inputBlocks + sample.outputBlocks)
    }

    func testDiskIOMonotonicAcrossCalls() async throws {
        let probe = BASProcessDiskIOProbe(useCBridge: true)
        let s1 = try await probe.current()
        // Force some disk-touching work — write a temp
        // file with sync。 No guarantee getrusage will
        // count it (cache may absorb writes),so we just
        // assert monotonic non-decreasing。
        let url = URL(
            fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "diskio-probe-\(UUID().uuidString)")
        try? Data(repeating: 0xAB, count: 4096)
            .write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }
        let s2 = try await probe.current()
        XCTAssertGreaterThanOrEqual(s2.inputBlocks,
            s1.inputBlocks,
            "ru_inblock is cumulative,non-decreasing")
        XCTAssertGreaterThanOrEqual(s2.outputBlocks,
            s1.outputBlocks)
    }

    func testDiskIOSampleCodableRoundTrip() throws {
        let sample = BASProcessDiskIOSample(
            inputBlocks: 100, outputBlocks: 50)
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(
            BASProcessDiskIOSample.self, from: data)
        XCTAssertEqual(decoded, sample)
        XCTAssertEqual(decoded.totalBlocks, 150)
    }

    func testHealthSnapshotIncludesDiskIO() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let snap = await brain.healthSnapshot()
        XCTAssertNotNil(snap.cSystemProbes?.diskIO,
            "Disk I/O sample must surface in" +
            " healthSnapshot")
    }

    func testRawDiskIOFunctionVersionPin() {
        XCTAssertEqual(
            bas_process_disk_io_blocks_version(), 1)
    }

    func testRawDiskIOErrorCaseIdentifiers() {
        XCTAssertEqual(
            BASProcessDiskIOProbeError.nullOutPointer
                .caseIdentifier, "nullOutPointer")
        XCTAssertEqual(
            BASProcessDiskIOProbeError.getrusageFailed
                .caseIdentifier, "getrusageFailed")
        XCTAssertEqual(
            BASProcessDiskIOProbeError.unsupportedPlatform
                .caseIdentifier, "unsupportedPlatform")
        XCTAssertEqual(
            BASProcessDiskIOProbeError
                .unknownReturnCode(-99)
                .caseIdentifier, "unknownReturnCode")
    }

    // MARK: - 2. Rust atom-count percentiles

    func testPercentilesEmptyTrackerSentinel() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let p = try await tracker.atomCountPercentiles()
        XCTAssertEqual(p.p50, -1)
        XCTAssertEqual(p.p95, -1)
        XCTAssertEqual(p.p99, -1)
        XCTAssertTrue(p.isEmpty)
    }

    func testPercentilesSingleAtom() async throws {
        // Single atom seen 7 times: every percentile = 7
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        for i in 0..<7 {
            _ = try await tracker.record(
                atomID: "only", sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
        }
        let p = try await tracker.atomCountPercentiles()
        XCTAssertEqual(p.p50, 7)
        XCTAssertEqual(p.p95, 7)
        XCTAssertEqual(p.p99, 7)
        XCTAssertFalse(p.isEmpty)
    }

    func testPercentilesUniformDistribution() async throws {
        // 10 distinct atoms each seen 3 times → all
        // percentiles = 3
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        for atomN in 0..<10 {
            for turn in 0..<3 {
                _ = try await tracker.record(
                    atomID: "atom-\(atomN)",
                    sessionRef: "S",
                    turnRef: String(
                        atomN * 10 + turn),
                    permitMode: "safe")
            }
        }
        let p = try await tracker.atomCountPercentiles()
        XCTAssertEqual(p.p50, 3)
        XCTAssertEqual(p.p95, 3)
        XCTAssertEqual(p.p99, 3)
    }

    func testPercentilesSkewedDistribution() async throws {
        // 9 atoms each seen once + 1 atom seen 100 times
        // → p50 = 1, p99 = 100 (nearest-rank picks the
        // top of the sorted distribution)
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        for atomN in 0..<9 {
            _ = try await tracker.record(
                atomID: "rare-\(atomN)",
                sessionRef: "S",
                turnRef: String(atomN),
                permitMode: "safe")
        }
        for turn in 0..<100 {
            _ = try await tracker.record(
                atomID: "popular",
                sessionRef: "S",
                turnRef: String(turn + 100),
                permitMode: "safe")
        }
        let p = try await tracker.atomCountPercentiles()
        XCTAssertEqual(p.p50, 1,
            "median of [1,1,1,1,1,1,1,1,1,100] = 1")
        XCTAssertEqual(p.p99, 100,
            "p99 picks the top of the sorted dist")
    }

    func testPercentilesCodableRoundTrip() throws {
        let p = BASAtomCountPercentiles(
            p50: 5, p95: 17, p99: 42)
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(
            BASAtomCountPercentiles.self, from: data)
        XCTAssertEqual(decoded, p)
        XCTAssertFalse(decoded.isEmpty)
    }

    func testHealthSnapshotIncludesAtomCountPercentiles()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // Some traffic to populate the distribution
        _ = await brain.summary("a")
        _ = await brain.summary("a")
        _ = await brain.summary("b")
        let snap = await brain.healthSnapshot()
        XCTAssertNotNil(snap.atomCountPercentiles,
            "Rust pilot wired → percentiles populate")
        let p = snap.atomCountPercentiles!
        XCTAssertFalse(p.isEmpty)
        // 2 distinct atoms with counts [2, 1]
        // sorted: [1, 2] — nearest rank:
        //   p50 idx = ceil(2 * 0.5) - 1 = 0 → sorted[0]=1
        //   p99 idx = ceil(2 * 0.99) - 1 = 1 → sorted[1]=2
        XCTAssertEqual(p.p50, 1)
        XCTAssertEqual(p.p99, 2)
    }

    func testHealthSnapshotPercentilesNilWithoutRust()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()  // no Rust
        let snap = await brain.healthSnapshot()
        XCTAssertNil(snap.atomCountPercentiles)
    }

    func testStorePercentilesDelegate() async throws {
        // Brain-store wrapper delegates correctly
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        _ = try await store.recordSummary(
            BASCognitiveBrainSummary(
                input: "x", taskType: .chat,
                confidence: 0.9, ambiguityScore: 0.1,
                safetyVerdict: .safe,
                manipulationHints: [], latencyNanos: 1))
        let p = try await store.atomCountPercentiles()
        XCTAssertEqual(p.p50, 1)
        XCTAssertEqual(p.p95, 1)
        XCTAssertEqual(p.p99, 1)
    }

    func testPercentilesV1PathThrows() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: false)
        do {
            _ = try await tracker.atomCountPercentiles()
            XCTFail("V1 must throw")
        } catch {
            XCTAssertTrue(error is
                BASRustMemoryUsageTrackerActorError)
        }
    }
}
