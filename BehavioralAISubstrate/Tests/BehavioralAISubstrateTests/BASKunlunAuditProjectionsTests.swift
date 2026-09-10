// MARK: - BASKunlunAuditProjectionsTests — chapter 四百四 v2 / M971

import Foundation
import XCTest
@testable import BASOrchestration

final class BASKunlunAuditProjectionsTests: XCTestCase {

    // MARK: - Init shape

    func testInitDefaultsAllSlotsNil() {
        let p = BASKunlunAuditProjections()
        XCTAssertNil(p.heavenGate)
        XCTAssertNil(p.axisAlignment)
        XCTAssertNil(p.readinessRef)
        XCTAssertNil(p.jadeSealRef)
        XCTAssertNil(p.riverTraceRef)
    }

    func testInitWithReadinessRef() {
        let p = BASKunlunAuditProjections(
            readinessRef: "ready-1",
            jadeSealRef: "seal-1",
            riverTraceRef: "trace-1")
        XCTAssertEqual(p.readinessRef, "ready-1")
        XCTAssertEqual(p.jadeSealRef, "seal-1")
        XCTAssertEqual(p.riverTraceRef, "trace-1")
    }

    // MARK: - Factory

    func testNoneFactoryReturnsAllNil() {
        let p = BASKunlunAuditProjections.none()
        XCTAssertFalse(p.hasAnyProjection)
        XCTAssertEqual(p.populatedSlotCount, 0)
    }

    // MARK: - Accessors

    func testHasAnyProjectionFalseWhenAllNil() {
        XCTAssertFalse(
            BASKunlunAuditProjections().hasAnyProjection)
    }

    func testHasAnyProjectionTrueWhenOneSlotSet() {
        let p = BASKunlunAuditProjections(
            readinessRef: "x")
        XCTAssertTrue(p.hasAnyProjection)
    }

    func testPopulatedSlotCount() {
        let p0 = BASKunlunAuditProjections()
        let p1 = BASKunlunAuditProjections(
            readinessRef: "x")
        let p2 = BASKunlunAuditProjections(
            readinessRef: "x", jadeSealRef: "y")
        let p3 = BASKunlunAuditProjections(
            readinessRef: "x", jadeSealRef: "y",
            riverTraceRef: "z")
        XCTAssertEqual(p0.populatedSlotCount, 0)
        XCTAssertEqual(p1.populatedSlotCount, 1)
        XCTAssertEqual(p2.populatedSlotCount, 2)
        XCTAssertEqual(p3.populatedSlotCount, 3)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let p = BASKunlunAuditProjections(
            readinessRef: "r",
            jadeSealRef: "s",
            riverTraceRef: "t")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(p)
        let decoded = try JSONDecoder().decode(
            BASKunlunAuditProjections.self, from: data)
        XCTAssertEqual(decoded, p)
    }

    // MARK: - Replay determinism

    func testEqualForSameInputs() {
        let a = BASKunlunAuditProjections(
            readinessRef: "x")
        let b = BASKunlunAuditProjections(
            readinessRef: "x")
        XCTAssertEqual(a, b,
            "M971:M892 byte-stable equality")
    }
}
