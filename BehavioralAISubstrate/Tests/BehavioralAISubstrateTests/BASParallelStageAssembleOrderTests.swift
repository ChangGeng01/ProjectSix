// MARK: - BASParallelStageAssembleOrderTests — chapter 四百十四 / M1027

import XCTest
@testable import BASHostKit

final class BASParallelStageAssembleOrderTests:
    XCTestCase
{

    // MARK: - Canonical order regardless of insertion

    func testEntryAA2CanonicalOrderIsAThenA2() {
        // Insert A2 first (simulating non-deterministic
        // async-let completion order)
        let assembled =
            BASParallelStageAssembleOrder<String>(
                group: .entryAA2,
                outputsByStage: [
                    .stageA2: "a2-output",
                    .stageA: "a-output"
                ])
        XCTAssertEqual(
            assembled.canonicalOutputs,
            ["a-output", "a2-output"],
            "canonical order pinned to [A, A2] regardless" +
            " of insertion order")
    }

    func testDD2CanonicalOrderIsDThenD2() {
        let assembled =
            BASParallelStageAssembleOrder<Int>(
                group: .dD2,
                outputsByStage: [
                    .stageD2: 22,
                    .stageD: 11
                ])
        XCTAssertEqual(
            assembled.canonicalOutputs, [11, 22])
    }

    // MARK: - Internal-fan-out groups have single output

    func testM1HasSingleOutputCell() {
        let assembled =
            BASParallelStageAssembleOrder<String>(
                group: .m1FourWay,
                outputsByStage: [.stageM1: "m1-out"])
        XCTAssertEqual(
            assembled.canonicalOutputs, ["m1-out"])
    }

    func testOHasSingleOutputCell() {
        let assembled =
            BASParallelStageAssembleOrder<String>(
                group: .o12Way,
                outputsByStage: [.stageO: "o-out"])
        XCTAssertEqual(
            assembled.canonicalOutputs, ["o-out"])
    }

    // MARK: - isComplete

    func testIsCompleteWhenAllMembersPresent() {
        let assembled =
            BASParallelStageAssembleOrder<String>(
                group: .entryAA2,
                outputsByStage: [
                    .stageA: "a", .stageA2: "a2"])
        XCTAssertTrue(assembled.isComplete)
    }

    func testIsCompleteFalseWhenMissing() {
        let assembled =
            BASParallelStageAssembleOrder<String>(
                group: .entryAA2,
                outputsByStage: [.stageA: "a"])
        XCTAssertFalse(assembled.isComplete)
        // canonicalOutputs returns only present entries
        XCTAssertEqual(
            assembled.canonicalOutputs, ["a"])
    }

    // MARK: - Determinism (chapter 三百九二)

    func testCanonicalOutputIsDeterministic() {
        // Insert keys in opposite orders;canonical output
        // must still match。
        let a = BASParallelStageAssembleOrder<String>(
            group: .entryAA2,
            outputsByStage: [
                .stageA2: "a2", .stageA: "a"])
        let b = BASParallelStageAssembleOrder<String>(
            group: .entryAA2,
            outputsByStage: [
                .stageA: "a", .stageA2: "a2"])
        XCTAssertEqual(
            a.canonicalOutputs, b.canonicalOutputs)
    }

    // MARK: - Empty assembly

    func testEmptyAssemblyReturnsEmptyArray() {
        let assembled =
            BASParallelStageAssembleOrder<String>(
                group: .entryAA2,
                outputsByStage: [:])
        XCTAssertEqual(assembled.canonicalOutputs, [])
        XCTAssertFalse(assembled.isComplete)
    }
}
