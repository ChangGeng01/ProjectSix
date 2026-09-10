// MARK: - BASEndOfTurnAuditEmissionBundleTests
// chapter 五百五 / M1399 — 11th BASBundle adoption tests

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASEndOfTurnAuditEmissionBundleTests:
    XCTestCase
{

    // MARK: - Helpers

    private func sampleCacheReport(
        hits: Int = 5,
        misses: Int = 5
    ) -> BASMPSGraphCacheReportResult {
        let body = BASMPSGraphCacheReportResultBody(
            hitCount: hits,
            missCount: misses,
            totalBuildNanos: 100,
            totalDispatchNanos: 50,
            totalCacheHitSavedNanos: 0)
        return BASMPSGraphCacheReportResult(
            success: true,
            body: body,
            diagnostics: [])
    }

    private func sampleDispatchStats(
        successes: Int = 4,
        failures: Int = 1
    ) -> BASKernelDispatchStatisticsBundle {
        var items:
            [BASKernelDispatchStatisticsBundleItem] = []
        if successes > 0 {
            items.append(
                BASKernelDispatchStatisticsBundleItem(
                    operation: .matMul,
                    succeeded: true,
                    count: successes))
        }
        if failures > 0 {
            items.append(
                BASKernelDispatchStatisticsBundleItem(
                    operation: .matMul,
                    succeeded: false,
                    count: failures))
        }
        return BASKernelDispatchStatisticsBundle(
            bundleID: "d",
            schemaVersion: "1.0.0",
            items: items,
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
    }

    private func sampleRecord(
        turnID: String,
        fullyObserved: Bool = false
    ) -> BASEndOfTurnAuditEmissionRecord {
        if fullyObserved {
            return BASEndOfTurnAuditEmissionRecord(
                turnID: turnID,
                cacheReport: sampleCacheReport(
                    hits: 8, misses: 2),
                routingDecisions:
                    BASKernelRoutingDecisionBundle(
                        bundleID: "r",
                        schemaVersion: "1.0.0",
                        items: [
                            BASKernelRoutingDecisionRecord(
                                operation: .matMul,
                                thermalState: .nominal,
                                anePriority: .aneFirst,
                                eligibilityTier: .aneCapable,
                                chosenRouting: .aneCapable,
                                matchedBestCase: true,
                                recordedAtMs: 0)
                        ],
                        metadata: [:],
                        recordedAt: Date(
                            timeIntervalSince1970: 0)),
                dispatchStatistics:
                    sampleDispatchStats(),
                runtimeModeAdvisories:
                    BASEBrainHostRuntimeModeAdvisoryBundle(
                        bundleID: "a",
                        schemaVersion: "1.0.0",
                        items: [
                            BASEBrainHostRuntimeModeAdvisory(
                                preferredMode: .v1ByteEqual,
                                hostID: "H",
                                recordedAtMs: 0,
                                wasHonored: true,
                                reasonCodes: [])
                        ],
                        metadata: [:],
                        recordedAt: Date(
                            timeIntervalSince1970: 0)),
                recordedAtMs: 0)
        } else {
            return BASEndOfTurnAuditEmissionRecord(
                turnID: turnID,
                cacheReport: sampleCacheReport(),
                recordedAtMs: 0)
        }
    }

    private func bundleWith(
        records: [BASEndOfTurnAuditEmissionRecord]
    ) -> BASEndOfTurnAuditEmissionBundle {
        return BASEndOfTurnAuditEmissionBundle(
            bundleID: "emission-bundle",
            schemaVersion: "1.0.0",
            items: records,
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
    }

    // MARK: - 1) Empty bundle has zero aggregates

    func testEmptyBundleHasZeroAggregates() {
        let bundle = bundleWith(records: [])
        XCTAssertEqual(bundle.fullyObservedTurnCount,
                       0)
        XCTAssertEqual(bundle.fullyObservedTurnRatio,
                       0.0)
        XCTAssertEqual(
            bundle.cumulativePopulatedPipelineCount, 0)
        XCTAssertEqual(bundle.distinctTurnCount, 0)
        XCTAssertEqual(bundle.meanCacheHitRatio, 0.0)
        XCTAssertEqual(
            bundle.meanRoutingBestCaseRatio, 0.0)
        XCTAssertEqual(
            bundle.meanDispatchSuccessRate, 0.0)
    }

    // MARK: - 2) Fully-observed turn counting

    func testFullyObservedTurnCounting() {
        let bundle = bundleWith(records: [
            sampleRecord(turnID: "T1",
                         fullyObserved: true),
            sampleRecord(turnID: "T2",
                         fullyObserved: false),
            sampleRecord(turnID: "T3",
                         fullyObserved: true),
            sampleRecord(turnID: "T4",
                         fullyObserved: true),
        ])
        XCTAssertEqual(bundle.fullyObservedTurnCount, 3)
        XCTAssertEqual(bundle.fullyObservedTurnRatio,
                       0.75)
    }

    // MARK: - 3) Cumulative populated pipeline count

    func testCumulativePopulatedPipelineCount() {
        let bundle = bundleWith(records: [
            sampleRecord(turnID: "T1",
                         fullyObserved: true), // 4
            sampleRecord(turnID: "T2",
                         fullyObserved: false), // 1
            sampleRecord(turnID: "T3",
                         fullyObserved: false), // 1
        ])
        XCTAssertEqual(
            bundle.cumulativePopulatedPipelineCount,
            6)
    }

    // MARK: - 4) Distinct turn count tracks unique IDs

    func testDistinctTurnCount() {
        let bundle = bundleWith(records: [
            sampleRecord(turnID: "T1"),
            sampleRecord(turnID: "T2"),
            sampleRecord(turnID: "T1"),
            sampleRecord(turnID: "T3"),
        ])
        XCTAssertEqual(bundle.distinctTurnCount, 3)
    }

    // MARK: - 5) Mean cache hit ratio across records

    func testMeanCacheHitRatio() {
        // 3 records: 0.8, 0.5, 0.3 → mean ~0.5333
        let bundle = bundleWith(records: [
            BASEndOfTurnAuditEmissionRecord(
                turnID: "T1",
                cacheReport: sampleCacheReport(
                    hits: 8, misses: 2),
                recordedAtMs: 0),
            BASEndOfTurnAuditEmissionRecord(
                turnID: "T2",
                cacheReport: sampleCacheReport(
                    hits: 5, misses: 5),
                recordedAtMs: 0),
            BASEndOfTurnAuditEmissionRecord(
                turnID: "T3",
                cacheReport: sampleCacheReport(
                    hits: 3, misses: 7),
                recordedAtMs: 0),
        ])
        let expected = (0.8 + 0.5 + 0.3) / 3.0
        XCTAssertEqual(bundle.meanCacheHitRatio,
                       expected, accuracy: 0.001)
    }

    // MARK: - 6) Mean ignores records without that
    //             pipeline

    func testMeanIgnoresRecordsWithoutThatPipeline() {
        // 2 records with cache report (0.8, 0.4), 1
        // without。 Mean computed across only the 2.
        let bundle = bundleWith(records: [
            BASEndOfTurnAuditEmissionRecord(
                turnID: "T1",
                cacheReport: sampleCacheReport(
                    hits: 8, misses: 2),
                recordedAtMs: 0),
            BASEndOfTurnAuditEmissionRecord(
                turnID: "T2",
                // No cache report
                recordedAtMs: 0),
            BASEndOfTurnAuditEmissionRecord(
                turnID: "T3",
                cacheReport: sampleCacheReport(
                    hits: 4, misses: 6),
                recordedAtMs: 0),
        ])
        let expected = (0.8 + 0.4) / 2.0
        XCTAssertEqual(bundle.meanCacheHitRatio,
                       expected, accuracy: 0.001,
            "mean MUST ignore records without that" +
            " pipeline (divide by populated count)")
    }

    // MARK: - 7) Bundle Codable round-trip

    func testBundleCodableRoundTrip() throws {
        let original = bundleWith(records: [
            sampleRecord(turnID: "T1",
                         fullyObserved: true),
            sampleRecord(turnID: "T2",
                         fullyObserved: false),
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASEndOfTurnAuditEmissionBundle.self,
            from: data)
        XCTAssertEqual(decoded.items.count,
                       original.items.count)
        XCTAssertEqual(decoded.fullyObservedTurnCount,
                       original.fullyObservedTurnCount)
    }

    // MARK: - 8) Mean dispatch success rate computes
    //             correctly

    func testMeanDispatchSuccessRate() {
        let bundle = bundleWith(records: [
            BASEndOfTurnAuditEmissionRecord(
                turnID: "T1",
                dispatchStatistics:
                    sampleDispatchStats(
                        successes: 4, failures: 1),
                recordedAtMs: 0),
            BASEndOfTurnAuditEmissionRecord(
                turnID: "T2",
                dispatchStatistics:
                    sampleDispatchStats(
                        successes: 9, failures: 1),
                recordedAtMs: 0),
        ])
        // Record1 successRate = 4/5 = 0.8
        // Record2 successRate = 9/10 = 0.9
        // Mean = 0.85
        XCTAssertEqual(bundle.meanDispatchSuccessRate,
                       0.85, accuracy: 0.001)
    }
}
