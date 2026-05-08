// MARK: - BASMambaInferenceLatencyTrackerTests — chapter 四百 / M927

import XCTest
@testable import BASRuntimeCore

final class BASMambaInferenceLatencyTrackerTests:
    XCTestCase
{

    func testEmptyTrackerSnapshotHasZeroSamples() async {
        let tracker = BASMambaInferenceLatencyTracker()
        let snapshot = await tracker.snapshot(
            atTimestampMs: 1_000)
        XCTAssertEqual(snapshot.totalCalls, 0)
        XCTAssertEqual(snapshot.perBand.count, 4,
            "All BASEventLogRiskBand cases included")
        for summary in snapshot.perBand {
            XCTAssertEqual(summary.sampleCount, 0)
            XCTAssertEqual(summary.p50Ms, 0)
            XCTAssertEqual(summary.p99Ms, 0)
        }
    }

    func testRecordIncrementsTotalCalls() async {
        let tracker = BASMambaInferenceLatencyTracker()
        await tracker.record(
            latencyMs: 5.0, thermalBand: .low)
        await tracker.record(
            latencyMs: 10.0, thermalBand: .medium)
        await tracker.record(
            latencyMs: 15.0, thermalBand: .high)
        let count = await tracker.totalCalls
        XCTAssertEqual(count, 3)
    }

    func testPerBandStratification() async {
        let tracker = BASMambaInferenceLatencyTracker()
        // 100 samples in .low at ~5ms,100 in .medium at
        // ~10ms,100 in .high at ~30ms
        for i in 0..<100 {
            await tracker.record(
                latencyMs: 4.0 + Double(i) * 0.02,
                thermalBand: .low)
            await tracker.record(
                latencyMs: 9.0 + Double(i) * 0.02,
                thermalBand: .medium)
            await tracker.record(
                latencyMs: 28.0 + Double(i) * 0.04,
                thermalBand: .high)
        }
        let snapshot = await tracker.snapshot(
            atTimestampMs: 0)
        XCTAssertEqual(snapshot.totalCalls, 300)

        let lowSummary = snapshot.summary(for: .low)!
        XCTAssertEqual(lowSummary.sampleCount, 100)
        XCTAssertGreaterThan(lowSummary.p50Ms, 4.0)
        XCTAssertLessThan(lowSummary.p50Ms, 7.0)

        let mediumSummary = snapshot.summary(for: .medium)!
        XCTAssertEqual(mediumSummary.sampleCount, 100)
        XCTAssertGreaterThan(mediumSummary.p50Ms, 9.0)
        XCTAssertLessThan(mediumSummary.p50Ms, 12.0)

        let highSummary = snapshot.summary(for: .high)!
        XCTAssertEqual(highSummary.sampleCount, 100)
        XCTAssertGreaterThan(highSummary.p50Ms, 28.0)
        XCTAssertLessThan(highSummary.p50Ms, 35.0)

        // Verify stratification:.high p50 > .medium p50 >
        // .low p50 (the whole point of thermal stratification)
        XCTAssertGreaterThan(
            highSummary.p50Ms, mediumSummary.p50Ms)
        XCTAssertGreaterThan(
            mediumSummary.p50Ms, lowSummary.p50Ms)
    }

    func testRecordViaTypedRecord() async {
        let tracker = BASMambaInferenceLatencyTracker()
        let record = BASMambaInferenceLatencyRecord(
            latencyMs: 7.5,
            thermalBand: .medium,
            timestampMs: 1_000)
        await tracker.record(record)
        let snapshot = await tracker.snapshot(
            atTimestampMs: 0)
        XCTAssertEqual(snapshot.totalCalls, 1)
        XCTAssertEqual(
            snapshot.summary(for: .medium)?.sampleCount, 1)
    }

    func testResetClearsAllSamples() async {
        let tracker = BASMambaInferenceLatencyTracker()
        for _ in 0..<10 {
            await tracker.record(
                latencyMs: 5.0, thermalBand: .low)
        }
        let beforeReset = await tracker.totalCalls
        XCTAssertEqual(beforeReset, 10)

        await tracker.reset()
        let afterReset = await tracker.totalCalls
        XCTAssertEqual(afterReset, 0)
        let snapshot = await tracker.snapshot(
            atTimestampMs: 0)
        XCTAssertEqual(snapshot.totalCalls, 0)
        for summary in snapshot.perBand {
            XCTAssertEqual(summary.sampleCount, 0)
        }
    }

    func testMinMaxCorrect() async {
        let tracker = BASMambaInferenceLatencyTracker()
        await tracker.record(
            latencyMs: 1.0, thermalBand: .low)
        await tracker.record(
            latencyMs: 5.0, thermalBand: .low)
        await tracker.record(
            latencyMs: 100.0, thermalBand: .low)
        await tracker.record(
            latencyMs: 50.0, thermalBand: .low)

        let snapshot = await tracker.snapshot(
            atTimestampMs: 0)
        let summary = snapshot.summary(for: .low)!
        XCTAssertEqual(summary.minMs, 1.0)
        XCTAssertEqual(summary.maxMs, 100.0)
        XCTAssertEqual(summary.sampleCount, 4)
        XCTAssertEqual(summary.meanMs, 39.0,
            accuracy: 0.001)
    }

    func testCodableSnapshotRoundTrip() async throws {
        let tracker = BASMambaInferenceLatencyTracker()
        for i in 0..<5 {
            await tracker.record(
                latencyMs: Double(i + 1),
                thermalBand: .medium)
        }
        let snapshot = await tracker.snapshot(
            atTimestampMs: 1_700_000_000_000)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(
            BASMambaInferenceLatencySnapshot.self,
            from: data)
        XCTAssertEqual(decoded, snapshot)
    }
}
