// MARK: - BASEndOfTurnAuditEmissionRecordTests
// chapter 五百五 / M1397 — end-of-turn audit emission tests

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASEndOfTurnAuditEmissionRecordTests:
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
            totalBuildNanos: 1000,
            totalDispatchNanos: 500,
            totalCacheHitSavedNanos: 800)
        return BASMPSGraphCacheReportResult(
            success: true,
            body: body,
            diagnostics: [])
    }

    private func sampleRoutingBundle(
        items: Int = 3,
        bestCases: Int = 2
    ) -> BASKernelRoutingDecisionBundle {
        let records: [BASKernelRoutingDecisionRecord] =
            (0..<items).map { i in
                BASKernelRoutingDecisionRecord(
                    operation: .matMul,
                    thermalState: .nominal,
                    anePriority: .aneFirst,
                    eligibilityTier: .aneNative,
                    chosenRouting: .aneNative,
                    matchedBestCase: i < bestCases,
                    recordedAtMs: 0)
            }
        return BASKernelRoutingDecisionBundle(
            bundleID: "routing",
            schemaVersion: "1.0.0",
            items: records,
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
    }

    private func sampleDispatchStatistics(
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
            bundleID: "dispatch",
            schemaVersion: "1.0.0",
            items: items,
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
    }

    private func sampleAdvisoryBundle(
        honored: Int = 1,
        unhonored: Int = 2
    ) -> BASEBrainHostRuntimeModeAdvisoryBundle {
        var items:
            [BASEBrainHostRuntimeModeAdvisory] = []
        for _ in 0..<honored {
            items.append(
                BASEBrainHostRuntimeModeAdvisory(
                    preferredMode: .v1ByteEqual,
                    hostID: "H",
                    recordedAtMs: 0,
                    wasHonored: true,
                    reasonCodes: []))
        }
        for _ in 0..<unhonored {
            items.append(
                BASEBrainHostRuntimeModeAdvisory(
                    preferredMode: .nativeV2,
                    hostID: "H",
                    recordedAtMs: 0,
                    wasHonored: false,
                    reasonCodes: ["test-reason"]))
        }
        return BASEBrainHostRuntimeModeAdvisoryBundle(
            bundleID: "advisory",
            schemaVersion: "1.0.0",
            items: items,
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
    }

    // MARK: - 1) Empty record has zero pipelines

    func testEmptyRecordHasZeroPipelines() {
        let record = BASEndOfTurnAuditEmissionRecord(
            turnID: "empty",
            recordedAtMs: 0)
        XCTAssertEqual(
            record.populatedPipelineCount, 0)
        XCTAssertFalse(record.hasAllFourPipelines)
        XCTAssertEqual(
            record.totalLookupsAcrossPipelines, 0)
        XCTAssertEqual(record.cacheHitRatio, 0.0)
        XCTAssertEqual(record.routingBestCaseRatio,
                       0.0)
        XCTAssertEqual(record.dispatchSuccessRate, 0.0)
        XCTAssertEqual(record.advisoryHonoredRatio,
                       0.0)
    }

    // MARK: - 2) Single pipeline populated count

    func testSinglePipelinePopulatedCount() {
        let record = BASEndOfTurnAuditEmissionRecord(
            turnID: "single",
            cacheReport: sampleCacheReport(),
            recordedAtMs: 0)
        XCTAssertEqual(
            record.populatedPipelineCount, 1)
        XCTAssertFalse(record.hasAllFourPipelines)
        XCTAssertEqual(record.cacheHitRatio, 0.5)
    }

    // MARK: - 3) All 4 pipelines populated

    func testAllFourPipelinesPopulated() {
        let record = BASEndOfTurnAuditEmissionRecord(
            turnID: "full",
            cacheReport: sampleCacheReport(),
            routingDecisions: sampleRoutingBundle(),
            dispatchStatistics:
                sampleDispatchStatistics(),
            runtimeModeAdvisories:
                sampleAdvisoryBundle(),
            recordedAtMs: 0)
        XCTAssertEqual(
            record.populatedPipelineCount, 4)
        XCTAssertTrue(record.hasAllFourPipelines)
    }

    // MARK: - 4) Lookups aggregate across pipelines

    func testLookupsAggregateAcrossPipelines() {
        let record = BASEndOfTurnAuditEmissionRecord(
            turnID: "lookups",
            cacheReport: sampleCacheReport(
                hits: 8, misses: 2),
            dispatchStatistics:
                sampleDispatchStatistics(
                    successes: 5, failures: 3),
            recordedAtMs: 0)
        XCTAssertEqual(
            record.totalLookupsAcrossPipelines,
            10 + 8,
            "cache 10 lookups + dispatch 8 attempts" +
            " = 18 total lookups across pipelines")
    }

    // MARK: - 5) Ratios surface per-pipeline values

    func testRatiosSurfacePerPipelineValues() {
        let record = BASEndOfTurnAuditEmissionRecord(
            turnID: "ratios",
            cacheReport: sampleCacheReport(
                hits: 7, misses: 3),
            routingDecisions: sampleRoutingBundle(
                items: 5, bestCases: 4),
            dispatchStatistics:
                sampleDispatchStatistics(
                    successes: 9, failures: 1),
            runtimeModeAdvisories:
                sampleAdvisoryBundle(
                    honored: 3, unhonored: 1),
            recordedAtMs: 0)
        XCTAssertEqual(record.cacheHitRatio, 0.7)
        XCTAssertEqual(
            record.routingBestCaseRatio, 0.8)
        XCTAssertEqual(
            record.dispatchSuccessRate, 0.9)
        XCTAssertEqual(
            record.advisoryHonoredRatio, 0.75)
    }

    // MARK: - 6) Codable round-trip preserves all
    //             pipelines

    func testCodableRoundTripPreservesAllPipelines()
        throws
    {
        let original = BASEndOfTurnAuditEmissionRecord(
            turnID: "codable-full",
            cacheReport: sampleCacheReport(),
            routingDecisions: sampleRoutingBundle(),
            dispatchStatistics:
                sampleDispatchStatistics(),
            runtimeModeAdvisories:
                sampleAdvisoryBundle(),
            recordedAtMs: 1_700_000_000_000)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASEndOfTurnAuditEmissionRecord.self,
            from: data)
        XCTAssertEqual(decoded.turnID, original.turnID)
        XCTAssertEqual(
            decoded.populatedPipelineCount, 4)
        XCTAssertEqual(decoded.recordedAtMs,
                       original.recordedAtMs)
    }

    // MARK: - 7) Codable round-trip with partial
    //             pipelines (nil fields preserved)

    func testCodableRoundTripWithPartialPipelines()
        throws
    {
        let original = BASEndOfTurnAuditEmissionRecord(
            turnID: "partial",
            cacheReport: sampleCacheReport(),
            // routingDecisions intentionally nil
            dispatchStatistics:
                sampleDispatchStatistics(),
            // runtimeModeAdvisories intentionally nil
            recordedAtMs: 0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASEndOfTurnAuditEmissionRecord.self,
            from: data)
        XCTAssertEqual(
            decoded.populatedPipelineCount, 2)
        XCTAssertNil(decoded.routingDecisions)
        XCTAssertNil(decoded.runtimeModeAdvisories)
    }

    // MARK: - 8) Equatable identity

    func testEquatableIdentity() {
        let r1 = BASEndOfTurnAuditEmissionRecord(
            turnID: "T",
            cacheReport: sampleCacheReport(),
            recordedAtMs: 0)
        let r2 = BASEndOfTurnAuditEmissionRecord(
            turnID: "T",
            cacheReport: sampleCacheReport(),
            recordedAtMs: 0)
        XCTAssertEqual(r1, r2)
    }
}
