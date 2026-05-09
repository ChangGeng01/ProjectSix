// MARK: - BASPermitEscalationStepResultTests — chapter 四百十 / M1010

import XCTest
@testable import BASPolicy

final class BASPermitEscalationStepResultTests: XCTestCase {

    // MARK: - Step result init

    func testStepResultStoresOutputAndCodes() {
        let permit = BASActionPermit(
            mode: .answer, reasonCodes: ["x"])
        let r = BASPermitEscalationStepResult(
            outputPermit: permit,
            reasonCodes: ["y"])
        XCTAssertEqual(r.outputPermit, permit)
        XCTAssertEqual(r.reasonCodes, ["y"])
    }

    // MARK: - Identity factory

    func testIdentityFactoryProducesPassThrough() {
        let permit = BASActionPermit(
            mode: .answer, reasonCodes: ["x"])
        let r = BASPermitEscalationStepResult.identity(
            of: permit)
        XCTAssertEqual(r.outputPermit, permit)
        XCTAssertTrue(r.reasonCodes.isEmpty)
    }

    // MARK: - Codable round-trip

    func testStepResultCodableRoundTrip() throws {
        let permit = BASActionPermit(
            mode: .answer, reasonCodes: ["x"])
        let original = BASPermitEscalationStepResult(
            outputPermit: permit,
            reasonCodes: ["a", "b"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASPermitEscalationStepResult.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Tuple builder produces same ledger as positional

    func testTupleBuilderMatchesPositionalBuild() {
        let initial = BASActionPermit(
            mode: .answer, reasonCodes: ["init"])
        let p1 = BASActionPermit(
            mode: .answer, reasonCodes: ["a"])
        let p2 = BASActionPermit(
            mode: .answer, reasonCodes: ["b"])
        let p3 = BASActionPermit(
            mode: .answer, reasonCodes: ["c"])
        let p4 = BASActionPermit(
            mode: .answer, reasonCodes: ["d"])
        let p5 = BASActionPermit(
            mode: .answer, reasonCodes: ["e"])
        let positional = BASPermitEscalationLedger.build(
            initialPermit: initial,
            afterAbyssal: p1,
            afterAbyssalReasonCodes: ["r1"],
            afterAssertionCeiling: p2,
            afterAssertionCeilingReasonCodes: ["r2"],
            afterKunlun: p3,
            afterKunlunReasonCodes: ["r3"],
            afterCthulhuAssertionCeiling: p4,
            afterCthulhuAssertionCeilingReasonCodes:
                ["r4"],
            afterCthulhuEscalation: p5,
            afterCthulhuEscalationReasonCodes: ["r5"])
        let tuple =
            BASPermitEscalationLedger.buildFromResults(
                initialPermit: initial,
                abyssal: BASPermitEscalationStepResult(
                    outputPermit: p1,
                    reasonCodes: ["r1"]),
                assertionCeiling:
                    BASPermitEscalationStepResult(
                        outputPermit: p2,
                        reasonCodes: ["r2"]),
                kunlun: BASPermitEscalationStepResult(
                    outputPermit: p3,
                    reasonCodes: ["r3"]),
                cthulhuAssertionCeiling:
                    BASPermitEscalationStepResult(
                        outputPermit: p4,
                        reasonCodes: ["r4"]),
                cthulhuEscalation:
                    BASPermitEscalationStepResult(
                        outputPermit: p5,
                        reasonCodes: ["r5"]))
        XCTAssertEqual(positional, tuple,
            "tuple builder must produce byte-equal ledger" +
            " to the M970 positional build")
    }

    // MARK: - Identity-only chain produces no fired stages

    func testAllIdentityResultsProducesZeroFired() {
        let initial = BASActionPermit(
            mode: .answer, reasonCodes: [])
        let identity = BASPermitEscalationStepResult
            .identity(of: initial)
        let ledger =
            BASPermitEscalationLedger.buildFromResults(
                initialPermit: initial,
                abyssal: identity,
                assertionCeiling: identity,
                kunlun: identity,
                cthulhuAssertionCeiling: identity,
                cthulhuEscalation: identity)
        XCTAssertEqual(ledger.firedStageCount, 0,
            "identity chain must not fire any stage")
        XCTAssertEqual(ledger.finalPermit, initial)
    }

    // MARK: - Tuple builder is deterministic

    func testTupleBuilderIsDeterministic() {
        let initial = BASActionPermit(
            mode: .answer, reasonCodes: [])
        let identity = BASPermitEscalationStepResult
            .identity(of: initial)
        let l1 =
            BASPermitEscalationLedger.buildFromResults(
                initialPermit: initial,
                abyssal: identity,
                assertionCeiling: identity,
                kunlun: identity,
                cthulhuAssertionCeiling: identity,
                cthulhuEscalation: identity)
        let l2 =
            BASPermitEscalationLedger.buildFromResults(
                initialPermit: initial,
                abyssal: identity,
                assertionCeiling: identity,
                kunlun: identity,
                cthulhuAssertionCeiling: identity,
                cthulhuEscalation: identity)
        XCTAssertEqual(l1, l2)
    }
}
