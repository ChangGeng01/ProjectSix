// MARK: - BASStressSweepReportTests — chapter 四百十三 / M1024

import XCTest
@testable import BASHostKit
@testable import BASPolicy

final class BASStressSweepReportTests: XCTestCase {

    private func makeKey(
        risk: BASTurnRuntimeStressRiskBucket = .high
    ) -> BASTurnRuntimeStressFixtureKey {
        BASTurnRuntimeStressFixtureKey(
            risk: risk,
            permitMode: .answer,
            quarantines: false,
            anchorTone: false,
            neuralCoreWired: true,
            evolutionFeedbackPresent: false)
    }

    private func makeReport(
        verdicts: [BASStressSweepVerdict]
    ) -> BASStressSweepReport {
        let keys = verdicts.indices.map { _ in makeKey() }
        let set = BASTurnRuntimeStressFixtureSet(
            name: "test", keys: keys)
        let results = zip(keys, verdicts).map {
            (k, v) -> BASStressSweepFixtureResult in
            BASStressSweepFixtureResult(
                key: k, verdict: v)
        }
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 1002)
        return BASStressSweepReport(
            fixtureSet: set,
            results: results,
            sweepStartedAt: start,
            sweepCompletedAt: end)
    }

    // MARK: - Aggregate metrics

    func testTotalFixturesEqualsResultsCount() {
        let r = makeReport(
            verdicts: [.byteEqual, .byteEqual,
                       .divergent])
        XCTAssertEqual(r.totalFixtures, 3)
    }

    func testPassingAndFailingPartitionTotal() {
        let r = makeReport(
            verdicts: [.byteEqual, .byteEqual,
                       .divergent, .v1Failed])
        XCTAssertEqual(r.passingFixtureCount, 2)
        XCTAssertEqual(r.failingFixtureCount, 2)
        XCTAssertEqual(
            r.passingFixtureCount
                + r.failingFixtureCount,
            r.totalFixtures)
    }

    func testPerVerdictCounts() {
        let r = makeReport(
            verdicts: [.byteEqual, .divergent,
                       .v1Failed, .v2Failed])
        XCTAssertEqual(r.passingFixtureCount, 1)
        XCTAssertEqual(r.divergentFixtureCount, 1)
        XCTAssertEqual(r.v1FailedFixtureCount, 1)
        XCTAssertEqual(r.v2FailedFixtureCount, 1)
    }

    func testSweepDurationMs() {
        let r = makeReport(verdicts: [.byteEqual])
        XCTAssertEqual(r.sweepDurationMs, 2000)
    }

    func testPassRatioWhenEmpty() {
        let r = makeReport(verdicts: [])
        XCTAssertEqual(r.passRatio, 0)
    }

    func testPassRatioComputesCorrectly() {
        let r = makeReport(
            verdicts: [.byteEqual, .byteEqual,
                       .divergent, .divergent])
        XCTAssertEqual(r.passRatio, 0.5, accuracy: 0.0001)
    }

    func testIsFullyPassingTrueWhenAllByteEqual() {
        let r = makeReport(
            verdicts: [.byteEqual, .byteEqual])
        XCTAssertTrue(r.isFullyPassing)
    }

    func testIsFullyPassingFalseWhenAnyFails() {
        let r = makeReport(
            verdicts: [.byteEqual, .divergent])
        XCTAssertFalse(r.isFullyPassing)
    }

    func testIsFullyPassingFalseWhenEmpty() {
        let r = makeReport(verdicts: [])
        XCTAssertFalse(r.isFullyPassing)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesReport() throws {
        let original = makeReport(
            verdicts: [.byteEqual, .divergent])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASStressSweepReport.self, from: data)
        XCTAssertEqual(
            decoded.totalFixtures, original.totalFixtures)
        XCTAssertEqual(
            decoded.passRatio,
            original.passRatio,
            accuracy: 0.0001)
    }
}
