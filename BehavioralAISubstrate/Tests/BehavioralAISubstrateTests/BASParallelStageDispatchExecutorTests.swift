// MARK: - BASParallelStageDispatchExecutorTests — chapter 四百二十五 / M1072

import XCTest
@testable import BASHostKit

final class BASParallelStageDispatchExecutorTests: XCTestCase {

    // MARK: - 2-way fan-out canonical assembly

    func testTwoWayFanOutAssemblesCanonically() async {
        let executor = BASParallelStageDispatchExecutor()
        // stage A2 step "wins" (returns first conceptually
        // but canonical order pins it second)
        let assembled = await executor
            .dispatchTwoWayFanOut(
                group: .entryAA2,
                first: .stageA,
                second: .stageA2,
                firstStep: { "a-output" },
                secondStep: { "a2-output" })
        XCTAssertEqual(
            assembled.canonicalOutputs,
            ["a-output", "a2-output"],
            "canonical order must pin [A, A2] regardless" +
            " of completion order")
        XCTAssertTrue(assembled.isComplete)
    }

    // MARK: - 2-way fan-out really runs in parallel

    func testTwoWayFanOutRunsInParallel() async {
        let executor = BASParallelStageDispatchExecutor()
        let start = Date()
        let assembled = await executor
            .dispatchTwoWayFanOut(
                group: .dD2,
                first: .stageD,
                second: .stageD2,
                firstStep: {
                    try? await Task.sleep(
                        nanoseconds: 100_000_000) // 100ms
                    return 1
                },
                secondStep: {
                    try? await Task.sleep(
                        nanoseconds: 100_000_000)
                    return 2
                })
        let elapsed = Date()
            .timeIntervalSince(start)
        // Both 100ms tasks ran in parallel → wall-clock ~100ms
        // (allow 200ms upper bound for CI noise)。
        // Sequential would be 200ms+;reject that range。
        XCTAssertLessThan(elapsed, 0.18,
            "parallel fan-out should complete in ~100ms," +
            " not 200ms (got \(elapsed)s)")
        XCTAssertEqual(assembled.canonicalOutputs, [1, 2])
    }

    // MARK: - 4-way fan-out canonical assembly (M1)

    func testFourWayFanOutPopulatesAllFourStageOutputs() async {
        let executor = BASParallelStageDispatchExecutor()
        // For 4-way fan-out the caller provides 4 distinct
        // stages they want parallel-executed。 The
        // returned assembly's outputsByStage holds all 4。
        // canonicalOutputs filters to the group's M1000
        // member-stage list which for .m1FourWay is just
        // [.stageM1] (internal fan-out semantics)。
        let stages: [BASTurnRuntimeStage] =
            [.stageA, .stageB, .stageC, .stageD]
        let s1: BASParallelStageDispatchExecutor
            .StageStep<Int> = { 100 }
        let s2: BASParallelStageDispatchExecutor
            .StageStep<Int> = { 200 }
        let s3: BASParallelStageDispatchExecutor
            .StageStep<Int> = { 300 }
        let s4: BASParallelStageDispatchExecutor
            .StageStep<Int> = { 400 }
        let assembled = await executor
            .dispatchFourWayFanOut(
                group: .m1FourWay,
                stages: stages,
                steps: [s1, s2, s3, s4])
        // outputsByStage contains all 4 entries
        XCTAssertEqual(assembled.outputsByStage.count, 4)
        XCTAssertEqual(
            assembled.outputsByStage[.stageA], 100)
        XCTAssertEqual(
            assembled.outputsByStage[.stageB], 200)
        XCTAssertEqual(
            assembled.outputsByStage[.stageC], 300)
        XCTAssertEqual(
            assembled.outputsByStage[.stageD], 400)
    }

    // MARK: - 4-way fan-out runs in parallel

    func testFourWayFanOutRunsInParallel() async {
        let executor = BASParallelStageDispatchExecutor()
        let stages: [BASTurnRuntimeStage] =
            [.stageA, .stageB, .stageC, .stageD]
        let s1: BASParallelStageDispatchExecutor
            .StageStep<Int> = {
            try? await Task.sleep(
                nanoseconds: 100_000_000)
            return 1
        }
        let s2: BASParallelStageDispatchExecutor
            .StageStep<Int> = {
            try? await Task.sleep(
                nanoseconds: 100_000_000)
            return 2
        }
        let s3: BASParallelStageDispatchExecutor
            .StageStep<Int> = {
            try? await Task.sleep(
                nanoseconds: 100_000_000)
            return 3
        }
        let s4: BASParallelStageDispatchExecutor
            .StageStep<Int> = {
            try? await Task.sleep(
                nanoseconds: 100_000_000)
            return 4
        }
        let start = Date()
        let _ = await executor
            .dispatchFourWayFanOut(
                group: .m1FourWay,
                stages: stages,
                steps: [s1, s2, s3, s4])
        let elapsed = Date().timeIntervalSince(start)
        // 4 × 100ms tasks in parallel → ~100ms wall-clock,
        // not 400ms。
        XCTAssertLessThan(elapsed, 0.18,
            "4-way parallel should be ~100ms,not 400ms" +
            " (got \(elapsed)s)")
    }

    // MARK: - Determinism: same inputs → same canonical output

    func testTwoWayFanOutIsDeterministic() async {
        let executor = BASParallelStageDispatchExecutor()
        let r1 = await executor.dispatchTwoWayFanOut(
            group: .entryAA2,
            first: .stageA, second: .stageA2,
            firstStep: { "a" }, secondStep: { "a2" })
        let r2 = await executor.dispatchTwoWayFanOut(
            group: .entryAA2,
            first: .stageA, second: .stageA2,
            firstStep: { "a" }, secondStep: { "a2" })
        XCTAssertEqual(
            r1.canonicalOutputs, r2.canonicalOutputs,
            "deterministic fan-out per chapter 三百九二")
    }
}
