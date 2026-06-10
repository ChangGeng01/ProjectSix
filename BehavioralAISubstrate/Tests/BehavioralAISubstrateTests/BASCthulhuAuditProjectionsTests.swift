// MARK: - BASCthulhuAuditProjectionsTests — chapter 四百四 v2 / M973

import Foundation
import XCTest
@testable import BASOrchestration
@testable import BASWorldPrior

final class BASCthulhuAuditProjectionsTests: XCTestCase {

    func testInitDefaultsAllSlotsNil() {
        let p = BASCthulhuAuditProjections()
        XCTAssertNil(p.permitEscalation)
        XCTAssertNil(p.assertionDecision)
        XCTAssertNil(p.cosmicColdCounterweight)
        XCTAssertNil(p.unknownReserve)
    }

    func testNoneFactory() {
        let p = BASCthulhuAuditProjections.none()
        XCTAssertFalse(p.hasAnyProjection)
        XCTAssertEqual(p.populatedSlotCount, 0)
    }

    func testEqualityShape() {
        // BASCthulhuPermitEscalationDecision +
        // BASCthulhuAssertionCeilingDecision are Sendable +
        // Equatable but not Codable, so the bundle is
        // Equatable + Sendable only。Pin via runtime check。
        let p1 = BASCthulhuAuditProjections()
        let p2 = BASCthulhuAuditProjections()
        XCTAssertEqual(p1, p2)
    }

    func testEqualForSameInputs() {
        let a = BASCthulhuAuditProjections()
        let b = BASCthulhuAuditProjections()
        XCTAssertEqual(a, b,
            "M973:M892 byte-stable equality")
    }

    func testFourSlotShape() {
        // Compile-time check: 4 typed slots
        let p = BASCthulhuAuditProjections()
        let _: BASCthulhuPermitEscalationDecision? =
            p.permitEscalation
        let _: BASCthulhuAssertionCeilingDecision? =
            p.assertionDecision
        let _: BASCosmicColdCounterweight? =
            p.cosmicColdCounterweight
        let _: BASUnknownReserve? = p.unknownReserve
        // Compile-time proof only — the typed binding above IS the contract (a conformance/type change fails compilation, not a runtime assertion). M824 doctrine: no XCTAssertTrue(true) tautology.
    }
}
