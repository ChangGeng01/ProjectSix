// MARK: - BASPermitEscalationStepResultsTests — chapter 四百十 / M1012

import XCTest
@testable import BASPolicy

final class BASPermitEscalationStepResultsTests:
    XCTestCase
{

    // MARK: - Init wires fields

    func testInitWiresFields() {
        let p = BASActionPermit(
            mode: .answer, reasonCodes: [])
        let r1 = BASPermitEscalationStepResult(
            outputPermit: p, reasonCodes: ["1"])
        let r2 = BASPermitEscalationStepResult(
            outputPermit: p, reasonCodes: ["2"])
        let r3 = BASPermitEscalationStepResult(
            outputPermit: p, reasonCodes: ["3"])
        let r4 = BASPermitEscalationStepResult(
            outputPermit: p, reasonCodes: ["4"])
        let r5 = BASPermitEscalationStepResult(
            outputPermit: p, reasonCodes: ["5"])
        let bundle = BASPermitEscalationStepResults(
            initialPermit: p,
            abyssal: r1,
            assertionCeiling: r2,
            kunlun: r3,
            cthulhuAssertionCeiling: r4,
            cthulhuEscalation: r5)
        XCTAssertEqual(bundle.initialPermit, p)
        XCTAssertEqual(bundle.abyssal.reasonCodes, ["1"])
        XCTAssertEqual(
            bundle.assertionCeiling.reasonCodes, ["2"])
        XCTAssertEqual(bundle.kunlun.reasonCodes, ["3"])
        XCTAssertEqual(
            bundle.cthulhuAssertionCeiling.reasonCodes,
            ["4"])
        XCTAssertEqual(
            bundle.cthulhuEscalation.reasonCodes, ["5"])
    }

    // MARK: - allIdentity factory

    func testAllIdentityFactoryProducesPassThroughBundle() {
        let p = BASActionPermit(
            mode: .answer, reasonCodes: [])
        let bundle = BASPermitEscalationStepResults
            .allIdentity(of: p)
        XCTAssertEqual(bundle.initialPermit, p)
        XCTAssertTrue(bundle.abyssal.reasonCodes.isEmpty)
        XCTAssertTrue(
            bundle.cthulhuEscalation.reasonCodes.isEmpty)
        XCTAssertEqual(bundle.firedStepCount, 0)
        XCTAssertEqual(bundle.finalPermit, p)
    }

    // MARK: - toLedger() matches M1010 tuple builder

    func testToLedgerMatchesTupleBuilder() {
        let initial = BASActionPermit(
            mode: .answer, reasonCodes: [])
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
        let r1 = BASPermitEscalationStepResult(
            outputPermit: p1, reasonCodes: ["r1"])
        let r2 = BASPermitEscalationStepResult(
            outputPermit: p2, reasonCodes: ["r2"])
        let r3 = BASPermitEscalationStepResult(
            outputPermit: p3, reasonCodes: ["r3"])
        let r4 = BASPermitEscalationStepResult(
            outputPermit: p4, reasonCodes: ["r4"])
        let r5 = BASPermitEscalationStepResult(
            outputPermit: p5, reasonCodes: ["r5"])
        let bundle = BASPermitEscalationStepResults(
            initialPermit: initial,
            abyssal: r1,
            assertionCeiling: r2,
            kunlun: r3,
            cthulhuAssertionCeiling: r4,
            cthulhuEscalation: r5)
        let viaBundle = bundle.toLedger()
        let viaTupleBuilder =
            BASPermitEscalationLedger.buildFromResults(
                initialPermit: initial,
                abyssal: r1,
                assertionCeiling: r2,
                kunlun: r3,
                cthulhuAssertionCeiling: r4,
                cthulhuEscalation: r5)
        XCTAssertEqual(viaBundle, viaTupleBuilder,
            "bundle.toLedger() must equal direct tuple" +
            " builder")
    }

    // MARK: - Codable round-trip

    func testStepResultsCodableRoundTrip() throws {
        let p = BASActionPermit(
            mode: .answer, reasonCodes: ["x"])
        let original = BASPermitEscalationStepResults
            .allIdentity(of: p)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASPermitEscalationStepResults.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - finalPermit equals last step output

    func testFinalPermitEqualsCthulhuEscalationOutput() {
        let p1 = BASActionPermit(
            mode: .answer, reasonCodes: [])
        let p2 = BASActionPermit(
            mode: .answer, reasonCodes: ["last"])
        let last = BASPermitEscalationStepResult(
            outputPermit: p2,
            reasonCodes: ["bumped"])
        let identity = BASPermitEscalationStepResult
            .identity(of: p1)
        let bundle = BASPermitEscalationStepResults(
            initialPermit: p1,
            abyssal: identity,
            assertionCeiling: identity,
            kunlun: identity,
            cthulhuAssertionCeiling: identity,
            cthulhuEscalation: last)
        XCTAssertEqual(bundle.finalPermit, p2)
    }

    // MARK: - Determinism

    func testToLedgerIsDeterministic() {
        let p = BASActionPermit(
            mode: .answer, reasonCodes: [])
        let bundle = BASPermitEscalationStepResults
            .allIdentity(of: p)
        XCTAssertEqual(
            bundle.toLedger(), bundle.toLedger())
    }
}
