// MARK: - BASAbyssalAuditProjectionsTests — chapter 四百四 v2 / M972

import Foundation
import XCTest
@testable import BASOrchestration

final class BASAbyssalAuditProjectionsTests: XCTestCase {

    func testInitDefaultsAllSlotsNil() {
        let p = BASAbyssalAuditProjections()
        XCTAssertNil(p.abyssalPressure)
        XCTAssertNil(p.humanAnchorSignal)
        XCTAssertNil(p.narrativeDistortion)
        XCTAssertNil(p.anomalyTraceRef)
    }

    func testNoneFactory() {
        let p = BASAbyssalAuditProjections.none()
        XCTAssertFalse(p.hasAnyProjection)
        XCTAssertEqual(p.populatedSlotCount, 0)
    }

    func testHasAnyProjectionTrueWhenAnomalyRefSet() {
        let p = BASAbyssalAuditProjections(
            anomalyTraceRef: "anomaly-1")
        XCTAssertTrue(p.hasAnyProjection)
        XCTAssertEqual(p.populatedSlotCount, 1)
    }

    func testCodableRoundTrip() throws {
        let p = BASAbyssalAuditProjections(
            anomalyTraceRef: "anomaly-1")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(p)
        let decoded = try JSONDecoder().decode(
            BASAbyssalAuditProjections.self, from: data)
        XCTAssertEqual(decoded, p)
    }

    func testEqualForSameInputs() {
        let a = BASAbyssalAuditProjections(
            anomalyTraceRef: "x")
        let b = BASAbyssalAuditProjections(
            anomalyTraceRef: "x")
        XCTAssertEqual(a, b,
            "M972:M892 byte-stable equality")
    }
}
