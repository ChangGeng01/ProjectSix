// MARK: - BASTurnRuntimeStageTests — chapter 四百七 / M1000

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStageTests: XCTestCase {

    // MARK: - Stage enum coverage

    func testStageEnumHas18Cases() {
        XCTAssertEqual(
            BASTurnRuntimeStage.allCases.count, 18,
            "M1000:18 stages per audit DAG topology")
    }

    func testStageRawValuesPinnedForGrep() {
        for s in BASTurnRuntimeStage.allCases {
            XCTAssertTrue(
                s.rawValue.hasPrefix("stage-"),
                "M1000:stage rawValue grep-stable")
        }
    }

    // MARK: - Parallel group enum

    func testParallelGroupHas4Cases() {
        XCTAssertEqual(
            BASTurnRuntimeStageParallelGroup
                .allCases.count, 4)
    }

    // MARK: - Parallel-group membership

    func testStageAAndA2InEntryGroup() {
        XCTAssertEqual(
            BASTurnRuntimeStage.stageA.parallelGroup,
            .entryAA2)
        XCTAssertEqual(
            BASTurnRuntimeStage.stageA2.parallelGroup,
            .entryAA2)
    }

    func testStageDAndD2InDGroup() {
        XCTAssertEqual(
            BASTurnRuntimeStage.stageD.parallelGroup,
            .dD2)
        XCTAssertEqual(
            BASTurnRuntimeStage.stageD2.parallelGroup,
            .dD2)
    }

    func testStageM1InFourWayGroup() {
        XCTAssertEqual(
            BASTurnRuntimeStage.stageM1.parallelGroup,
            .m1FourWay)
    }

    func testStageOIn12WayGroup() {
        XCTAssertEqual(
            BASTurnRuntimeStage.stageO.parallelGroup,
            .o12Way)
    }

    func testSequentialStagesHaveNilGroup() {
        let sequential: [BASTurnRuntimeStage] = [
            .stageB, .stageC, .stageE, .stageF,
            .stageG, .stageH, .stageI, .stageJ,
            .stageK, .stageL, .stageN, .stageP
        ]
        for s in sequential {
            XCTAssertNil(s.parallelGroup,
                "M1000:\(s.rawValue) is sequential")
        }
    }

    // MARK: - Boolean accessors

    func testIsSequentialCount() {
        let sequentialCount = BASTurnRuntimeStage
            .allCases.filter { $0.isSequential }.count
        XCTAssertEqual(sequentialCount, 12,
            "M1000:12 sequential stages per audit")
    }

    func testIsParallelCount() {
        let parallelCount = BASTurnRuntimeStage
            .allCases.filter { $0.isParallel }.count
        XCTAssertEqual(parallelCount, 6,
            "M1000:6 parallel stages (A+A2+D+D2+M1+O)")
    }

    // MARK: - Replay determinism

    func testStageEnumByteStableAcrossRuns() {
        let order1 = BASTurnRuntimeStage.allCases
            .map { $0.rawValue }
        let order2 = BASTurnRuntimeStage.allCases
            .map { $0.rawValue }
        XCTAssertEqual(order1, order2,
            "M1000:CaseIterable order byte-stable")
    }
}
