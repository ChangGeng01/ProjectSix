// MARK: - BASTurnRuntimeStagePlanTests — chapter 四百九 / M1006

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStagePlanTests: XCTestCase {

    // MARK: - BASTurnRuntimeStageStep — sequential factory

    func testSequentialStepHoldsOneStage() {
        let step = BASTurnRuntimeStageStep
            .sequential(.stageB)
        XCTAssertEqual(step.stages, [.stageB])
        XCTAssertNil(step.parallelGroup)
        XCTAssertTrue(step.isSequential)
        XCTAssertFalse(step.isParallel)
        XCTAssertEqual(step.stageCount, 1)
    }

    // MARK: - BASTurnRuntimeStageStep — parallel factory

    func testParallelStepHoldsListedStages() {
        let step = BASTurnRuntimeStageStep.parallel(
            [.stageA, .stageA2],
            group: .entryAA2)
        XCTAssertEqual(step.stages, [.stageA, .stageA2])
        XCTAssertEqual(step.parallelGroup, .entryAA2)
        XCTAssertTrue(step.isParallel)
        XCTAssertFalse(step.isSequential)
        XCTAssertEqual(step.stageCount, 2)
    }

    // MARK: - Codable round-trip

    func testStepCodableRoundTrip() throws {
        let original = BASTurnRuntimeStageStep.parallel(
            [.stageD, .stageD2], group: .dD2)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnRuntimeStageStep.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - BASTurnRuntimeStagePlan — empty default

    func testEmptyPlanHasZeroSteps() {
        let plan = BASTurnRuntimeStagePlan()
        XCTAssertEqual(plan.stepCount, 0)
        XCTAssertEqual(plan.stageCount, 0)
        XCTAssertTrue(plan.orderedStages.isEmpty)
    }

    // MARK: - BASTurnRuntimeStagePlan — canonical plan

    func testCanonicalPlanHasSixteenSteps() {
        let plan = BASTurnRuntimeStagePlan.canonical()
        XCTAssertEqual(plan.stepCount, 16)
    }

    func testCanonicalPlanCoversAllEighteenStages() {
        let plan = BASTurnRuntimeStagePlan.canonical()
        XCTAssertEqual(plan.stageCount, 18)
        XCTAssertEqual(plan.orderedStages.count, 18)
    }

    func testCanonicalPlanOrderMatchesDagTopology() {
        let plan = BASTurnRuntimeStagePlan.canonical()
        XCTAssertEqual(plan.orderedStages, [
            .stageA, .stageA2,
            .stageB, .stageC,
            .stageD, .stageD2,
            .stageE, .stageF, .stageG, .stageH,
            .stageI, .stageJ, .stageK, .stageL,
            .stageM1, .stageN, .stageO, .stageP
        ])
    }

    func testCanonicalPlanHasFourParallelSteps() {
        let plan = BASTurnRuntimeStagePlan.canonical()
        XCTAssertEqual(plan.parallelStepCount, 4)
        XCTAssertEqual(plan.sequentialStepCount, 12)
    }

    func testCanonicalPlanCoversEveryM1000StageOnce() {
        let plan = BASTurnRuntimeStagePlan.canonical()
        let plannedStages = Set(plan.orderedStages)
        let allStages = Set(BASTurnRuntimeStage.allCases)
        XCTAssertEqual(plannedStages, allStages,
            "Canonical plan must cover every M1000 stage")
        // No duplicates
        XCTAssertEqual(
            plan.orderedStages.count,
            plannedStages.count,
            "Each stage must appear exactly once")
    }

    func testCanonicalPlanParallelGroupAssignmentMatchesM1000() {
        let plan = BASTurnRuntimeStagePlan.canonical()
        for step in plan.steps where step.isParallel {
            // Every stage in a parallel step must have a
            // matching M1000 parallelGroup that equals the
            // step's parallelGroup
            for stage in step.stages {
                XCTAssertEqual(
                    stage.parallelGroup,
                    step.parallelGroup,
                    "Stage \(stage.rawValue) parallel-group" +
                    " must match step's parallel-group")
            }
        }
    }

    func testCanonicalPlanSequentialStepsMatchM1000Sequential() {
        let plan = BASTurnRuntimeStagePlan.canonical()
        for step in plan.steps where step.isSequential {
            XCTAssertEqual(step.stageCount, 1,
                "Sequential step must hold exactly one stage")
            for stage in step.stages {
                // Sequential stages may or may not be
                // M1000-sequential — M1 and O are
                // M1000-parallel-internal but plan-sequential
                // single-step steps with parallelGroup nil
                // are M1000 sequential。
                XCTAssertTrue(stage.isSequential,
                    "Sequential plan step at stage " +
                    "\(stage.rawValue) must be M1000-" +
                    "sequential too")
            }
        }
    }

    // MARK: - Determinism (chapter 三百九二)

    func testCanonicalPlanIsDeterministic() {
        let p1 = BASTurnRuntimeStagePlan.canonical()
        let p2 = BASTurnRuntimeStagePlan.canonical()
        XCTAssertEqual(p1, p2)
    }

    // MARK: - Codable round-trip on plan

    func testPlanCodableRoundTrip() throws {
        let original = BASTurnRuntimeStagePlan.canonical()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnRuntimeStagePlan.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
