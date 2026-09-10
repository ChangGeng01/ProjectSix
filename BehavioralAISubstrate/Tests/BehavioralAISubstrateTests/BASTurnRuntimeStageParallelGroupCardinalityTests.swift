// MARK: - BASTurnRuntimeStageParallelGroupCardinalityTests
// chapter 四百十四 / M1026

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStageParallelGroupCardinalityTests:
    XCTestCase
{

    // MARK: - Cardinality matches DAG topology

    func testEntryAA2HasFanOutTwo() {
        XCTAssertEqual(
            BASTurnRuntimeStageParallelGroup
                .entryAA2.canonicalFanOutCount, 2)
    }

    func testDD2HasFanOutTwo() {
        XCTAssertEqual(
            BASTurnRuntimeStageParallelGroup
                .dD2.canonicalFanOutCount, 2)
    }

    func testM1FourWayHasFanOutFour() {
        XCTAssertEqual(
            BASTurnRuntimeStageParallelGroup
                .m1FourWay.canonicalFanOutCount, 4)
    }

    func testO12WayHasFanOutTwelve() {
        XCTAssertEqual(
            BASTurnRuntimeStageParallelGroup
                .o12Way.canonicalFanOutCount, 12)
    }

    // MARK: - Member stages

    func testEntryAA2MembersAreAandA2() {
        XCTAssertEqual(
            BASTurnRuntimeStageParallelGroup
                .entryAA2.canonicalMemberStages,
            [.stageA, .stageA2])
    }

    func testDD2MembersAreDandD2() {
        XCTAssertEqual(
            BASTurnRuntimeStageParallelGroup
                .dD2.canonicalMemberStages,
            [.stageD, .stageD2])
    }

    func testM1FourWayMemberIsM1Only() {
        XCTAssertEqual(
            BASTurnRuntimeStageParallelGroup
                .m1FourWay.canonicalMemberStages,
            [.stageM1])
    }

    func testO12WayMemberIsOOnly() {
        XCTAssertEqual(
            BASTurnRuntimeStageParallelGroup
                .o12Way.canonicalMemberStages,
            [.stageO])
    }

    // MARK: - Cross-check against M1000 stage.parallelGroup

    func testStageLevelFanOutMembersAlignWithM1000() {
        // For stage-level fan-outs (cardinality > 1 members),
        // each member's M1000 .parallelGroup must equal the
        // group。
        for group: BASTurnRuntimeStageParallelGroup
            in [.entryAA2, .dD2]
        {
            for stage in group.canonicalMemberStages {
                XCTAssertEqual(
                    stage.parallelGroup, group,
                    "stage \(stage.rawValue) parallel-group" +
                    " must equal group \(group.rawValue)")
            }
        }
    }

    // MARK: - Determinism

    func testCardinalityIsDeterministic() {
        for group in BASTurnRuntimeStageParallelGroup
            .allCases
        {
            XCTAssertEqual(
                group.canonicalFanOutCount,
                group.canonicalFanOutCount)
            XCTAssertEqual(
                group.canonicalMemberStages,
                group.canonicalMemberStages)
        }
    }
}
