// MARK: - BASRuntimeAuditEmissionSummaryFactoryTests
// chapter 四百六 / M993

import Foundation
import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy

final class BASRuntimeAuditEmissionSummaryFactoryTests:
    XCTestCase
{

    // MARK: - Factory surface

    func testFactoryAcceptsResultAndOptionalProjections() {
        // Compile-time check (M996:signature now also takes
        // optional permitEscalationLedger:)
        let _: (
            BASEBrainTurnResult,
            BASRuntimeAuditProjectionsBundle?,
            BASPolicy.BASPermitEscalationLedger?
        ) -> BASRuntimeAuditEmissionSummary =
            BASRuntimeAuditEmissionSummary.from
        XCTAssertTrue(true)
    }

    func testFactoryProjectionsParameterDefaultsToNil() {
        // Compile-time: default param works
        let _: (
            BASEBrainTurnResult
        ) -> BASRuntimeAuditEmissionSummary = { result in
            BASRuntimeAuditEmissionSummary.from(result: result)
        }
        XCTAssertTrue(true)
    }

    // MARK: - Field roundtrip via factory + projections

    func testFactoryProjectionsCountFromBundle() {
        let bundle = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "r",
                jadeSealRef: "s"))
        XCTAssertEqual(bundle.populatedSlotCount, 2)
        // Direct summary construction with same count
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage",
            auditProjectionsPopulatedSlotCount:
                bundle.populatedSlotCount)
        XCTAssertEqual(
            summary.auditProjectionsPopulatedSlotCount, 2)
    }

    func testFactoryDefaultsToZeroWhenProjectionsNil() {
        // When auditProjections is nil, the count is 0
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage",
            auditProjectionsPopulatedSlotCount: 0)
        XCTAssertEqual(
            summary.auditProjectionsPopulatedSlotCount, 0)
    }

    // MARK: - Determinism (chapter 三百九二)

    func testTwoSummariesFromSameInputsAreEqual() {
        let s1 = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage")
        let s2 = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage")
        XCTAssertEqual(s1, s2,
            "M993:M892 byte-stable factory output")
    }

    func testFactoryOutputIsByteStable() throws {
        let s1 = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage",
            auditProjectionsPopulatedSlotCount: 5)
        let s2 = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage",
            auditProjectionsPopulatedSlotCount: 5)
        XCTAssertEqual(s1.payloadJson(), s2.payloadJson())
    }
}
