// MARK: - BASPermitEscalationStageOrderTests — chapter 四百十 / M1011

import XCTest
@testable import BASPolicy

final class BASPermitEscalationStageOrderTests: XCTestCase {

    // MARK: - Canonical order is the 5-stage chain

    func testCanonicalOrderIsFiveStagesInChainOrder() {
        XCTAssertEqual(
            BASPermitEscalationStage.canonicalOrder,
            [
                .abyssal,
                .assertionCeiling,
                .kunlun,
                .cthulhuAssertionCeiling,
                .cthulhuEscalation
            ])
    }

    // MARK: - Coverage check

    func testCanonicalOrderCoversEveryCase() {
        let ordered = Set(
            BASPermitEscalationStage.canonicalOrder)
        let all = Set(BASPermitEscalationStage.allCases)
        XCTAssertEqual(ordered, all,
            "canonicalOrder must cover every CaseIterable" +
            " case")
        XCTAssertEqual(
            BASPermitEscalationStage.canonicalOrder.count,
            BASPermitEscalationStage.allCases.count,
            "no duplicates allowed")
    }

    // MARK: - Ledger-side forwarder

    func testLedgerForwarderMatchesEnumArray() {
        XCTAssertEqual(
            BASPermitEscalationLedger
                .canonicalStageOrder,
            BASPermitEscalationStage.canonicalOrder)
    }

    // MARK: - Determinism

    func testCanonicalOrderIsDeterministic() {
        let a = BASPermitEscalationStage.canonicalOrder
        let b = BASPermitEscalationStage.canonicalOrder
        XCTAssertEqual(a, b)
    }

    // MARK: - Build builder uses same ordering

    func testM970BuildOrderMatchesCanonicalOrder() {
        let p = BASActionPermit(
            mode: .answer, reasonCodes: [])
        let ledger = BASPermitEscalationLedger.build(
            initialPermit: p,
            afterAbyssal: p,
            afterAssertionCeiling: p,
            afterKunlun: p,
            afterCthulhuAssertionCeiling: p,
            afterCthulhuEscalation: p)
        let recordedStages = ledger.records.map { $0.stage }
        XCTAssertEqual(
            recordedStages,
            BASPermitEscalationStage.canonicalOrder,
            "M970 .build() must record stages in canonical" +
            " order")
    }
}
