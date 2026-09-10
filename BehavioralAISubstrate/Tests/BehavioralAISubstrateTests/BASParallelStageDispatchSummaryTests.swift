// MARK: - BASParallelStageDispatchSummaryTests — chapter 四百十五 / M1030

import XCTest
@testable import BASHostKit

final class BASParallelStageDispatchSummaryTests:
    XCTestCase
{

    // MARK: - Init wires fields

    func testInitWiresFields() {
        let s = BASParallelStageDispatchSummary(
            group: .entryAA2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        XCTAssertEqual(s.group, .entryAA2)
        XCTAssertEqual(s.cardinalityActual, 2)
        XCTAssertEqual(s.maxStageDurationMs, 50)
        XCTAssertEqual(s.sumStageDurationMs, 80)
    }

    // MARK: - Negative inputs clamp to zero

    func testNegativeInputsClampToZero() {
        let s = BASParallelStageDispatchSummary(
            group: .dD2,
            cardinalityActual: -3,
            maxStageDurationMs: -10,
            sumStageDurationMs: -7)
        XCTAssertEqual(s.cardinalityActual, 0)
        XCTAssertEqual(s.maxStageDurationMs, 0)
        XCTAssertEqual(s.sumStageDurationMs, 0)
    }

    // MARK: - Empty factory

    func testEmptyFactoryHasZeroFields() {
        let s = BASParallelStageDispatchSummary
            .empty(group: .m1FourWay)
        XCTAssertEqual(s.group, .m1FourWay)
        XCTAssertEqual(s.cardinalityActual, 0)
        XCTAssertEqual(s.maxStageDurationMs, 0)
        XCTAssertEqual(s.sumStageDurationMs, 0)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesFields() throws {
        let original = BASParallelStageDispatchSummary(
            group: .o12Way,
            cardinalityActual: 12,
            maxStageDurationMs: 100,
            sumStageDurationMs: 600)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASParallelStageDispatchSummary.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Determinism

    func testInitIsDeterministic() {
        let a = BASParallelStageDispatchSummary(
            group: .entryAA2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        let b = BASParallelStageDispatchSummary(
            group: .entryAA2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        XCTAssertEqual(a, b)
    }

    // MARK: - Equality differentiates groups

    func testDifferentGroupsAreNotEqual() {
        let a = BASParallelStageDispatchSummary(
            group: .entryAA2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        let b = BASParallelStageDispatchSummary(
            group: .dD2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        XCTAssertNotEqual(a, b)
    }
}
