// MARK: - BASTribunalAuditProjectionsTests — chapter 四百四 v3 / M975

import Foundation
import XCTest
@testable import BASOrchestration

final class BASTribunalAuditProjectionsTests: XCTestCase {

    func testInitDefaultsAllSlotsEmpty() {
        let p = BASTribunalAuditProjections()
        XCTAssertTrue(p.triScores.isEmpty)
        XCTAssertNil(p.mergedChoice)
        XCTAssertNil(p.arbitrationFrame)
    }

    func testNoneFactory() {
        let p = BASTribunalAuditProjections.none()
        XCTAssertFalse(p.hasAnyProjection)
        XCTAssertEqual(p.populatedSlotCount, 0)
        XCTAssertEqual(p.triScoreCount, 0)
    }

    func testCodableRoundTripEmpty() throws {
        let p = BASTribunalAuditProjections()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(p)
        let decoded = try JSONDecoder().decode(
            BASTribunalAuditProjections.self, from: data)
        XCTAssertEqual(decoded, p)
    }

    func testEqualForSameInputs() {
        let a = BASTribunalAuditProjections()
        let b = BASTribunalAuditProjections()
        XCTAssertEqual(a, b,
            "M975:M892 byte-stable equality")
    }

    func testThreeSlotShape() {
        let p = BASTribunalAuditProjections()
        let _: [BASTriSelfScore] = p.triScores
        let _: BASMergedChoice? = p.mergedChoice
        let _: BASArbitrationFrame? = p.arbitrationFrame
        XCTAssertTrue(true)
    }

    func testTriScoreCountReflectsArrayLength() {
        let p = BASTribunalAuditProjections(
            triScores: [])
        XCTAssertEqual(p.triScoreCount, 0)
    }
}
