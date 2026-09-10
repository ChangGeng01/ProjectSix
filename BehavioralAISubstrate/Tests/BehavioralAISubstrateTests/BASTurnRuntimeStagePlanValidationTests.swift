// MARK: - BASTurnRuntimeStagePlanValidationTests — chapter 四百九 / M1007

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStagePlanValidationTests:
    XCTestCase
{

    // MARK: - Canonical plan is valid + canonical

    func testCanonicalPlanIsWellFormed() {
        let plan = BASTurnRuntimeStagePlan.canonical()
        XCTAssertTrue(plan.validate().isEmpty)
        XCTAssertTrue(plan.isWellFormed)
    }

    func testCanonicalPlanIsCanonical() {
        let plan = BASTurnRuntimeStagePlan.canonical()
        XCTAssertTrue(plan.isCanonical)
    }

    // MARK: - Empty plan flags missing stages

    func testEmptyPlanReportsMissingStages() {
        let plan = BASTurnRuntimeStagePlan()
        let issues = plan.validate()
        XCTAssertFalse(issues.isEmpty)
        // Should report 18 missing stages
        var foundMissing = false
        for issue in issues {
            if case let .missingStages(stages) = issue {
                XCTAssertEqual(
                    stages.count,
                    BASTurnRuntimeStage.allCases.count)
                foundMissing = true
            }
        }
        XCTAssertTrue(foundMissing)
        XCTAssertFalse(plan.isWellFormed)
        XCTAssertFalse(plan.isCanonical)
    }

    // MARK: - Duplicate stages flagged

    func testDuplicateStageFlagged() {
        let plan = BASTurnRuntimeStagePlan(steps: [
            .sequential(.stageB),
            .sequential(.stageB),  // duplicated
            .sequential(.stageC)
        ])
        var foundDuplicate = false
        for issue in plan.validate() {
            if case let .duplicateStages(stages) = issue {
                XCTAssertTrue(stages.contains(.stageB))
                foundDuplicate = true
            }
        }
        XCTAssertTrue(foundDuplicate)
        XCTAssertFalse(plan.isWellFormed)
    }

    // MARK: - Sequential step holding multiple stages
    // flagged

    func testSequentialStepHoldingMultipleStagesFlagged() {
        // Construct invalid step:nil parallelGroup but
        // 2 stages
        let badStep = BASTurnRuntimeStageStep(
            stages: [.stageB, .stageC],
            parallelGroup: nil)
        let plan = BASTurnRuntimeStagePlan(steps: [badStep])
        var found = false
        for issue in plan.validate() {
            if case let .sequentialStepHasMultipleStages(
                stepIndex: idx, stageCount: count) = issue
            {
                XCTAssertEqual(idx, 0)
                XCTAssertEqual(count, 2)
                found = true
            }
        }
        XCTAssertTrue(found)
        XCTAssertFalse(plan.isWellFormed)
    }

    // MARK: - Parallel-group mismatch flagged

    func testParallelGroupMismatchFlagged() {
        // Stage B (sequential per M1000) shoehorned into
        // a parallel group entryAA2 → mismatch
        let badStep = BASTurnRuntimeStageStep(
            stages: [.stageB],
            parallelGroup: .entryAA2)
        let plan = BASTurnRuntimeStagePlan(steps: [badStep])
        var found = false
        for issue in plan.validate() {
            if case let .parallelGroupMismatch(
                stage: s, declaredGroup: g) = issue
            {
                XCTAssertEqual(s, .stageB)
                XCTAssertEqual(g, .entryAA2)
                found = true
            }
        }
        XCTAssertTrue(found)
        XCTAssertFalse(plan.isWellFormed)
    }

    // MARK: - Custom valid plan passes

    func testCustomValidPlanPasses() {
        // Valid 1-step plan covering all 18 stages with
        // appropriate parallel groups
        let plan = BASTurnRuntimeStagePlan.canonical()
        XCTAssertTrue(plan.isWellFormed)
        // But not canonical if rearranged
        let reversed = BASTurnRuntimeStagePlan(
            steps: plan.steps.reversed())
        // Reversed still well-formed (covers all 18,no
        // duplicates,no per-step issues)
        XCTAssertTrue(reversed.isWellFormed)
        // But not canonical
        XCTAssertFalse(reversed.isCanonical)
    }

    // MARK: - Determinism

    func testValidationIsDeterministic() {
        let p = BASTurnRuntimeStagePlan.canonical()
        XCTAssertEqual(p.validate(), p.validate())
    }
}
