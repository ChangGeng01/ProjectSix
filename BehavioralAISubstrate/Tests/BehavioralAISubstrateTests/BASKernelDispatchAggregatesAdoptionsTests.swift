// MARK: - BASKernelDispatchAggregatesAdoptionsTests
// chapter 四百九十九 / M1373-M1375 — dispatch aggregates adoption tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASKernelDispatchAggregatesAdoptionsTests:
    XCTestCase
{

    // MARK: - M1373: BASKernelDispatchStatisticsBundle

    func testStatisticsBundleAggregatesTotals() {
        let bundle = BASKernelDispatchStatisticsBundle(
            bundleID: "stats-1",
            schemaVersion: "1.0.0",
            items: [
                BASKernelDispatchStatisticsBundleItem(
                    operation: .matMul,
                    succeeded: true,
                    count: 10),
                BASKernelDispatchStatisticsBundleItem(
                    operation: .matMul,
                    succeeded: false,
                    count: 2),
                BASKernelDispatchStatisticsBundleItem(
                    operation: .rmsNorm,
                    succeeded: true,
                    count: 5),
            ],
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
        XCTAssertEqual(bundle.totalDispatches, 17)
        XCTAssertEqual(bundle.totalSuccessfulDispatches,
                       15)
        XCTAssertEqual(bundle.successRate,
                       15.0 / 17.0, accuracy: 0.0001)
    }

    func testStatisticsBundleEmptyHasZeroSuccessRate() {
        let bundle = BASKernelDispatchStatisticsBundle(
            bundleID: "empty",
            schemaVersion: "1.0.0",
            items: [],
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
        XCTAssertEqual(bundle.successRate, 0.0)
        XCTAssertEqual(bundle.totalDispatches, 0)
    }

    func testStatisticsBundleCodableRoundTrip() throws {
        let original = BASKernelDispatchStatisticsBundle(
            bundleID: "codable",
            schemaVersion: "1.0.0",
            items: [
                BASKernelDispatchStatisticsBundleItem(
                    operation: .softmax,
                    succeeded: true,
                    count: 3)
            ],
            metadata: ["k": "v"],
            recordedAt: Date(
                timeIntervalSince1970: 1_000_000_000))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASKernelDispatchStatisticsBundle.self,
            from: data)
        XCTAssertEqual(decoded.bundleID, original.bundleID)
        XCTAssertEqual(decoded.items.count,
                       original.items.count)
    }

    // MARK: - M1374: BASMPSGraphCacheReportResult

    func testCacheReportBodyHitRatio() {
        let body = BASMPSGraphCacheReportResultBody(
            hitCount: 80,
            missCount: 20,
            totalBuildNanos: 200_000_000,
            totalDispatchNanos: 50_000_000,
            totalCacheHitSavedNanos: 800_000_000)
        XCTAssertEqual(body.totalLookups, 100)
        XCTAssertEqual(body.hitRatio, 0.8)
    }

    func testCacheReportBodyZeroLookupsHasZeroHitRatio() {
        let body = BASMPSGraphCacheReportResultBody(
            hitCount: 0,
            missCount: 0,
            totalBuildNanos: 0,
            totalDispatchNanos: 0,
            totalCacheHitSavedNanos: 0)
        XCTAssertEqual(body.totalLookups, 0)
        XCTAssertEqual(body.hitRatio, 0.0)
    }

    func testCacheReportResultWrapsBody() {
        let body = BASMPSGraphCacheReportResultBody(
            hitCount: 5,
            missCount: 5,
            totalBuildNanos: 100,
            totalDispatchNanos: 50,
            totalCacheHitSavedNanos: 500)
        let result = BASMPSGraphCacheReportResult(
            success: true,
            body: body,
            diagnostics: [])
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.body.hitRatio, 0.5)
    }

    // MARK: - M1375: BASKernelDispatchAttemptCard

    func testAttemptCardAllKindsExist() {
        let cases = BASKernelDispatchAttemptKind.allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.success))
        XCTAssertTrue(cases.contains(.dataTypeMismatch))
        XCTAssertTrue(cases.contains(.shapeMismatch))
        XCTAssertTrue(cases
            .contains(.frameworkUnavailable))
        XCTAssertTrue(cases
            .contains(.deviceDispatchFailure))
    }

    func testAttemptCardConstruction() {
        let body = BASKernelDispatchAttemptCardBody(
            operation: .matMul,
            attemptedAtMs: 1_700_000_000_000,
            reasonCode: "ok")
        let card = BASKernelDispatchAttemptCard(
            kind: .success,
            body: body,
            headline: "matMul ok",
            presentation: "compact")
        XCTAssertEqual(card.kind, .success)
        XCTAssertEqual(card.body.operation, .matMul)
        XCTAssertEqual(card.body.reasonCode, "ok")
    }

    func testAttemptCardCodableRoundTrip() throws {
        let body = BASKernelDispatchAttemptCardBody(
            operation: .conv2D,
            attemptedAtMs: 1_700_000_000_000,
            reasonCode:
                "device-dispatch-buffer-allocation-failed")
        let original = BASKernelDispatchAttemptCard(
            kind: .deviceDispatchFailure,
            body: body,
            headline: "conv2D failed",
            presentation: "rich-text")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASKernelDispatchAttemptCard.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAttemptCardKindCodable() throws {
        let kind: BASKernelDispatchAttemptKind =
            .frameworkUnavailable
        let data = try JSONEncoder().encode(kind)
        let decoded = try JSONDecoder().decode(
            BASKernelDispatchAttemptKind.self,
            from: data)
        XCTAssertEqual(decoded, kind)
    }
}
