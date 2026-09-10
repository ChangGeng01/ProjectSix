// MARK: - BASParallelStageAssembleOrderFromCanonicalTests
// chapter 四百十四 / M1028

import XCTest
@testable import BASHostKit

final class BASParallelStageAssembleOrderFromCanonicalTests:
    XCTestCase
{

    // MARK: - Round-trip property holds

    func testRoundTripEntryAA2() {
        let original =
            BASParallelStageAssembleOrder<String>(
                group: .entryAA2,
                outputsByStage: [
                    .stageA: "x", .stageA2: "y"])
        let canonical = original.canonicalOutputs
        let rebuilt =
            BASParallelStageAssembleOrder<String>
                .fromCanonicalOrder(
                    canonical, group: .entryAA2)
        XCTAssertEqual(
            rebuilt.canonicalOutputs,
            original.canonicalOutputs)
    }

    func testRoundTripDD2() {
        let canonical = [101, 202]
        let assembled =
            BASParallelStageAssembleOrder<Int>
                .fromCanonicalOrder(
                    canonical, group: .dD2)
        XCTAssertEqual(
            assembled.canonicalOutputs, canonical)
        XCTAssertTrue(assembled.isComplete)
    }

    // MARK: - Single-cell groups

    func testFromCanonicalForM1HasSingleEntry() {
        let assembled =
            BASParallelStageAssembleOrder<String>
                .fromCanonicalOrder(
                    ["m1-out"], group: .m1FourWay)
        XCTAssertEqual(
            assembled.canonicalOutputs, ["m1-out"])
        XCTAssertTrue(assembled.isComplete)
    }

    func testFromCanonicalForOHasSingleEntry() {
        let assembled =
            BASParallelStageAssembleOrder<Int>
                .fromCanonicalOrder(
                    [42], group: .o12Way)
        XCTAssertEqual(
            assembled.canonicalOutputs, [42])
    }

    // MARK: - Length mismatch handling

    func testFromCanonicalWithFewerOutputsIsIncomplete() {
        let assembled =
            BASParallelStageAssembleOrder<String>
                .fromCanonicalOrder(
                    ["only-a"], group: .entryAA2)
        XCTAssertFalse(assembled.isComplete)
        XCTAssertEqual(
            assembled.canonicalOutputs, ["only-a"])
    }

    func testFromCanonicalWithExtraOutputsIgnoresExtras() {
        let assembled =
            BASParallelStageAssembleOrder<String>
                .fromCanonicalOrder(
                    ["a", "a2", "extra1", "extra2"],
                    group: .entryAA2)
        // Only 2 member stages → only first 2 outputs
        // populate
        XCTAssertTrue(assembled.isComplete)
        XCTAssertEqual(
            assembled.canonicalOutputs, ["a", "a2"])
    }

    // MARK: - Determinism

    func testFromCanonicalIsDeterministic() {
        let outputs = ["a", "a2"]
        let a =
            BASParallelStageAssembleOrder<String>
                .fromCanonicalOrder(
                    outputs, group: .entryAA2)
        let b =
            BASParallelStageAssembleOrder<String>
                .fromCanonicalOrder(
                    outputs, group: .entryAA2)
        XCTAssertEqual(
            a.canonicalOutputs, b.canonicalOutputs)
        XCTAssertEqual(
            a.outputsByStage, b.outputsByStage)
    }
}
