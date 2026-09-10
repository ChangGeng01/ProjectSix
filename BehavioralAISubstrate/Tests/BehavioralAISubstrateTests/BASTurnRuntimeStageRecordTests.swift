// MARK: - BASTurnRuntimeStageRecordTests — chapter 四百八 / M1002

import Foundation
import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStageRecordTests: XCTestCase {

    // MARK: - Status enum

    func testStatusEnumHas3Cases() {
        XCTAssertEqual(
            BASTurnRuntimeStageStatus.allCases.count, 3)
    }

    func testStatusRawValuesPinned() {
        XCTAssertEqual(
            BASTurnRuntimeStageStatus.completed.rawValue,
            "completed")
        XCTAssertEqual(
            BASTurnRuntimeStageStatus.skipped.rawValue,
            "skipped")
        XCTAssertEqual(
            BASTurnRuntimeStageStatus.failed.rawValue,
            "failed")
    }

    // MARK: - Init

    func testInitRequiredFields() {
        let r = BASTurnRuntimeStageRecord(
            stage: .stageH,
            status: .completed,
            durationMs: 12,
            reasonCodes: ["risk-low"])
        XCTAssertEqual(r.stage, .stageH)
        XCTAssertEqual(r.status, .completed)
        XCTAssertEqual(r.durationMs, 12)
        XCTAssertEqual(r.reasonCodes, ["risk-low"])
    }

    func testInitClampsNegativeDuration() {
        let r = BASTurnRuntimeStageRecord(
            stage: .stageA,
            status: .completed,
            durationMs: -5)
        XCTAssertEqual(r.durationMs, 0,
            "M1002:negative durationMs clamps to 0")
    }

    // MARK: - Factories

    func testCompletedFactory() {
        let r = BASTurnRuntimeStageRecord.completed(
            .stageF, durationMs: 8)
        XCTAssertEqual(r.status, .completed)
        XCTAssertTrue(r.didComplete)
        XCTAssertFalse(r.didSkip)
        XCTAssertFalse(r.didFail)
    }

    func testSkippedFactory() {
        let r = BASTurnRuntimeStageRecord.skipped(
            .stageD2)
        XCTAssertEqual(r.status, .skipped)
        XCTAssertTrue(r.didSkip)
        XCTAssertEqual(r.durationMs, 0,
            "M1002:skipped factory always 0 duration")
    }

    func testFailedFactory() {
        let r = BASTurnRuntimeStageRecord.failed(
            .stageI, reasonCodes: ["err-x"])
        XCTAssertEqual(r.status, .failed)
        XCTAssertTrue(r.didFail)
        XCTAssertEqual(r.reasonCodes, ["err-x"])
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let r = BASTurnRuntimeStageRecord(
            stage: .stageM1,
            status: .completed,
            durationMs: 5,
            reasonCodes: ["ok"])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(r)
        let decoded = try JSONDecoder().decode(
            BASTurnRuntimeStageRecord.self, from: data)
        XCTAssertEqual(decoded, r)
    }

    // MARK: - Replay determinism

    func testTwoRecordsWithSameInputsAreEqual() {
        let r1 = BASTurnRuntimeStageRecord.completed(
            .stageH, durationMs: 3,
            reasonCodes: ["a", "b"])
        let r2 = BASTurnRuntimeStageRecord.completed(
            .stageH, durationMs: 3,
            reasonCodes: ["a", "b"])
        XCTAssertEqual(r1, r2,
            "M1002:M892 byte-stable equality")
    }
}
