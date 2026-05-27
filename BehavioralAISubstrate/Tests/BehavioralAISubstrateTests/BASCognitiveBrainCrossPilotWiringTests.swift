// MARK: - BASCognitiveBrainCrossPilotWiringTests
// 持续性 发展: cross-language wired 最严苛 test suite。
// Covers:
//   - C CPU-time probe in cascade health snapshot
//   - Rust top-K atoms native FFI
//   - Brain.verifyPilotInvariants() cross-pilot
//     consistency check
//   - Brain.markSummaryHelped() exercising SQL markHelped
//     path that was previously surface-only

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore
@testable import BASCSystemBridge
@testable import BASRustCoreBridge

#if !os(iOS)  // ch 1022 source-gate
final class BASCognitiveBrainCrossPilotWiringTests:
    XCTestCase
{
    // MARK: - C CPU-time probe

    func testCPUTimeProbeABIVersionPin() {
        XCTAssertEqual(
            BASProcessCPUTimeProbe.cBridgeABIVersion, 1)
        XCTAssertEqual(
            BASProcessCPUTimeProbe.liveCBridgeABIVersion(),
            1)
    }

    func testCPUTimeV1ReturnsZeroSample() async throws {
        let probe = BASProcessCPUTimeProbe(
            useCBridge: false)
        let sample = try await probe.current()
        XCTAssertEqual(sample.userMicros, 0)
        XCTAssertEqual(sample.systemMicros, 0)
        XCTAssertEqual(sample.totalMicros, 0)
    }

    func testCPUTimeV2ReturnsPositiveSample() async throws {
        let probe = BASProcessCPUTimeProbe(useCBridge: true)
        let sample = try await probe.current()
        // Process must have done SOMETHING by now → user
        // CPU time > 0
        XCTAssertGreaterThan(sample.userMicros, 0)
        // System CPU could legitimately be 0 if process
        // has done no syscalls (unlikely but possible)
        XCTAssertGreaterThanOrEqual(sample.systemMicros, 0)
        XCTAssertEqual(sample.totalMicros,
            sample.userMicros + sample.systemMicros)
    }

    func testCPUTimeMonotonicAcrossCalls() async throws {
        let probe = BASProcessCPUTimeProbe(useCBridge: true)
        let s1 = try await probe.current()
        // Burn some CPU
        var sum: Double = 0
        for i in 0..<1_000_000 {
            sum += Double(i).squareRoot()
        }
        _ = sum  // suppress unused warning
        let s2 = try await probe.current()
        XCTAssertGreaterThanOrEqual(s2.userMicros,
            s1.userMicros,
            "CPU time monotonic non-decreasing")
        XCTAssertGreaterThanOrEqual(
            s2.totalMicros - s1.totalMicros, 1,
            "1M sqrt iterations → ≥ 1μs CPU delta")
    }

    func testCPUTimeSampleCodableRoundTrip() throws {
        let sample = BASProcessCPUTimeSample(
            userMicros: 12345, systemMicros: 6789)
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(
            BASProcessCPUTimeSample.self, from: data)
        XCTAssertEqual(decoded, sample)
        XCTAssertEqual(decoded.totalMicros, 19134)
    }

    func testHealthSnapshotIncludesCPUTime() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let snap = await brain.healthSnapshot()
        XCTAssertNotNil(snap.cSystemProbes?.cpuTime,
            "C CPU-time sample must surface in" +
            " healthSnapshot")
        let cpu = snap.cSystemProbes!.cpuTime!
        XCTAssertGreaterThan(cpu.userMicros, 0)
    }

    func testRawCPUTimeFunctionVersionPin() {
        XCTAssertEqual(
            bas_process_cpu_time_micros_version(), 1)
    }

    // MARK: - Rust top-K atoms

    func testTopKAtomsReturnsHighestCountsFirst()
        async throws
    {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        // 5 records for "A", 3 for "B", 1 for "C"
        for i in 0..<5 {
            _ = try await tracker.record(
                atomID: "A", sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
        }
        for i in 0..<3 {
            _ = try await tracker.record(
                atomID: "B", sessionRef: "S",
                turnRef: String(i + 5), permitMode: "safe")
        }
        _ = try await tracker.record(
            atomID: "C", sessionRef: "S",
            turnRef: "9", permitMode: "safe")
        let topAll = try await tracker.topKAtoms(limit: 10)
        XCTAssertEqual(topAll.count, 3)
        XCTAssertEqual(topAll[0].atomID, "A")
        XCTAssertEqual(topAll[0].count, 5)
        XCTAssertEqual(topAll[1].atomID, "B")
        XCTAssertEqual(topAll[1].count, 3)
        XCTAssertEqual(topAll[2].atomID, "C")
        XCTAssertEqual(topAll[2].count, 1)
    }

    func testTopKAtomsHonorsLimit() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        for i in 0..<10 {
            _ = try await tracker.record(
                atomID: "atom\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
        }
        let top3 = try await tracker.topKAtoms(limit: 3)
        XCTAssertEqual(top3.count, 3)
    }

    func testTopKAtomsLimitZeroReturnsEmpty() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        _ = try await tracker.record(
            atomID: "anyAtom", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        let zero = try await tracker.topKAtoms(limit: 0)
        XCTAssertEqual(zero.count, 0)
    }

    func testTopKAtomsAlphabeticalTieBreak() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        // Equal counts: "zebra" + "alpha" + "middle"
        // Should sort: alpha < middle < zebra (asc alpha)
        for atom in ["zebra", "alpha", "middle"] {
            _ = try await tracker.record(
                atomID: atom, sessionRef: "S",
                turnRef: "0", permitMode: "safe")
        }
        let result = try await tracker.topKAtoms(limit: 3)
        XCTAssertEqual(result[0].atomID, "alpha",
            "Alphabetical tie-break sorts ascending")
        XCTAssertEqual(result[1].atomID, "middle")
        XCTAssertEqual(result[2].atomID, "zebra")
    }

    func testTopKAtomsCodableEntry() throws {
        let entry = BASTopAtomEntry(
            atomID: "abc123", count: 42)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(
            BASTopAtomEntry.self, from: data)
        XCTAssertEqual(decoded, entry)
    }

    // (Direct C symbol version pin checked implicitly
    // via the Swift wrapper above — BASRustMemoryTracker
    // Binary module isn't importable from this test
    // target,unlike BASCSystemBridge which has a Swift-
    // visible module map。)

    func testStoreTopKAtomsViaBrainHistory() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(rustHistoryStore: store)
        _ = await brain.summary("popular")
        _ = await brain.summary("popular")
        _ = await brain.summary("popular")
        _ = await brain.summary("rare")
        let top = try await store.topKAtoms(limit: 5)
        XCTAssertEqual(top.count, 2)
        XCTAssertEqual(top[0].count, 3,
            "'popular' has 3 occurrences")
        XCTAssertEqual(top[1].count, 1,
            "'rare' has 1")
    }

    // MARK: - verifyPilotInvariants

    func testInvariantCheckPassesOnFreshBrain() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let report = await brain.verifyPilotInvariants()
        XCTAssertTrue(report.allInvariantsHeld,
            "Fresh brain → no violations")
        XCTAssertFalse(report.checksRun.isEmpty,
            "Some checks must have applied")
    }

    func testInvariantCheckPassesAfterParallelSummaries()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // Generate brain activity
        _ = await brain.summary("alpha")
        _ = await brain.summary("beta")
        _ = await brain.summary("gamma")
        _ = await brain.summary("alpha")  // dup
        let report = await brain.verifyPilotInvariants()
        XCTAssertTrue(report.allInvariantsHeld,
            "After 4 summaries SQL + Rust must agree" +
            " (mirror writes)。 Violations: " +
            "\(report.violations)")
        // Both pilots saw 4 records
        XCTAssertEqual(report.sqlTotalRecords, 4)
        XCTAssertEqual(report.rustTotalRecords, 4)
    }

    func testInvariantCheckSurfacesCxxCacheSize()
        async throws
    {
        // 持续性 发展 / 严查 — C++ cache is process-global
        // so we DON'T assert cache size ≤ SQL history。
        // The brain check surfaces cxxCacheSize for host
        // inspection without enforcing equality (would
        // be false in multi-instance scenarios)。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        _ = await brain.summary("a")
        _ = await brain.summary("b")
        let report = await brain.verifyPilotInvariants()
        XCTAssertTrue(report.allInvariantsHeld,
            "Only SQL/Rust mirror invariants checked —" +
            " C++ cache size NOT enforced。 Violations: " +
            "\(report.violations)")
        XCTAssertEqual(report.sqlTotalRecords, 2)
        XCTAssertEqual(report.rustTotalRecords, 2)
        XCTAssertNotNil(report.cxxCacheSize,
            "cxxCacheSize surfaced for host inspection")
    }

    func testInvariantCheckBareBrainNoChecks() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let report = await brain.verifyPilotInvariants()
        XCTAssertTrue(report.checksRun.isEmpty,
            "Bare brain has no other pilots to compare" +
            " against → no checks run")
        XCTAssertTrue(report.allInvariantsHeld,
            "Vacuously held when no checks ran")
    }

    func testInvariantReportCodableRoundTrip() throws {
        let report =
            BASCognitiveBrainPilotInvariantReport(
                checksRun: ["check.one", "check.two"],
                violations: ["violation message"],
                sqlTotalRecords: 5,
                rustTotalRecords: 4,
                cxxCacheSize: 3,
                collectedAt: Date(
                    timeIntervalSince1970:
                        1_700_000_000))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy =
            .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy =
            .millisecondsSince1970
        let data = try encoder.encode(report)
        let decoded = try decoder.decode(
            BASCognitiveBrainPilotInvariantReport.self,
            from: data)
        XCTAssertEqual(decoded, report)
        XCTAssertFalse(decoded.allInvariantsHeld,
            "violations not empty → false")
    }

    // MARK: - markSummaryHelped

    func testMarkSummaryHelpedExercisesSQLPath()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(
            tracker: tracker)
        // Pre-seed a known record via store.recordSummary
        // to capture the recordID
        let s = BASCognitiveBrainSummary(
            input: "x", taskType: .chat,
            confidence: 0.9, ambiguityScore: 0.1,
            safetyVerdict: .safe,
            manipulationHints: [], latencyNanos: 1)
        let recordID = try await store.recordSummary(s)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        let accepted = await brain.markSummaryHelped(
            recordID: recordID, helped: true)
        XCTAssertTrue(accepted,
            "SQL store accepted the markHelped update")
        // Verify the record's helped state actually
        // changed in the tracker。
        let record = await tracker.record(forID: recordID)
        XCTAssertEqual(record?.helpedFlag, .helped,
            "helped_state column updated via SQL path")
    }

    func testMarkSummaryHelpedBareBrainReturnsFalse()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let accepted = await brain.markSummaryHelped(
            recordID: "no-such-id", helped: true)
        XCTAssertFalse(accepted,
            "Bare brain has no store → no acceptor → false")
    }

    func testMarkSummaryHelpedUnknownRecordReturnsFalse()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        let accepted = await brain.markSummaryHelped(
            recordID: "unknown-record-id",
            helped: false)
        XCTAssertFalse(accepted,
            "Store throws on unknown recordID → try?" +
            " nil-coalesces → false")
    }
}
#endif
