import XCTest
import Foundation
@testable import BASEvaluation

/// audit organ-eval MED-2 — a fidelity anchor of 0 mismatches is ambiguous:
/// "verified clean" vs "nothing to compare". The report now records
/// `fidelityVerifiable`, so the anchor can no longer be SILENTLY bypassed
/// (a consumer sees when 0 meant "no data").
final class BASABFidelityVerifiableTests: XCTestCase {

    private func rows(tokHash: Int?) -> [BASABMeasurementRow] {
        var out: [BASABMeasurementRow] = []
        for arm in ["a", "inc"] {
            for b in 0..<2 {
                for g in 0..<8 {
                    out.append(BASABMeasurementRow(
                        block: b, arm: arm, gen: g + 1, prompt: g % 3,
                        tokens: 192, seconds: 192.0 / 10.0, thermal: 0,
                        measured: true, tokHash: tokHash))
                }
            }
        }
        return out
    }
    private func spec() -> BASABProtocolSpec {  // fidelityAnchorRequired defaults true
        BASABProtocolSpec(arms: ["a", "inc"], incumbentArm: "inc", minMeasuredRowsPerArm: 8)
    }

    func testFidelityVerifiableHelper() {
        XCTAssertFalse(BASABJudge.fidelityVerifiable(rows: rows(tokHash: nil)))
        XCTAssertTrue(BASABJudge.fidelityVerifiable(rows: rows(tokHash: 7)))
    }

    func testRequiredButUnverifiableAnchorFailsClosed() {
        // audit organ-eval MED-2: the anchor is REQUIRED (default) but there is NOTHING to compare
        // (nil tokHash, no external count). 0 mismatches here means "unverified", not "clean" — the
        // verdict must FAIL CLOSED (.instrumentInvalid), not silently pass through to the per-arm logic.
        let report = BASABJudge.judge(spec: spec(), rows: rows(tokHash: nil))
        XCTAssertEqual(report.fidelityMismatches, 0)
        XCTAssertFalse(report.fidelityVerifiable,
            "0 mismatches with NO comparable data is NOT verifiable")
        XCTAssertEqual(report.overall, .instrumentInvalid,
            "a REQUIRED-but-unverifiable fidelity anchor fails closed — no silent bypass")
    }

    func testUnverifiableIsAllowedWhenAnchorNotRequired() {
        // With the anchor NOT required, an unverifiable run is not invalidated on fidelity grounds.
        let s = BASABProtocolSpec(arms: ["a", "inc"], incumbentArm: "inc",
                                  fidelityAnchorRequired: false, minMeasuredRowsPerArm: 8)
        let report = BASABJudge.judge(spec: s, rows: rows(tokHash: nil))
        XCTAssertNotEqual(report.overall, .instrumentInvalid,
            "anchor not required ⇒ an unverifiable run is not fidelity-invalidated")
    }

    func testReportMarksVerifiableWithTokHashes() {
        let report = BASABJudge.judge(spec: spec(), rows: rows(tokHash: 7))
        XCTAssertTrue(report.fidelityVerifiable, "≥1 tokHash ⇒ the anchor had data to compare")
    }

    func testExternalCountCountsAsVerifiable() {
        let report = BASABJudge.judge(
            spec: spec(), rows: rows(tokHash: nil), externalFidelityMismatches: 0)
        XCTAssertTrue(report.fidelityVerifiable, "an external mismatch count means fidelity was checked")
    }

    func testCodableAbsentKeyDecodesAsVerifiable() throws {
        let full = BASABReport(overall: .pass, fidelityMismatches: 0,
                               fidelityVerifiable: false, arms: [])
        var obj = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(full)) as! [String: Any]
        obj.removeValue(forKey: "fidelityVerifiable")   // report logged before the field
        let legacy = try JSONSerialization.data(withJSONObject: obj)
        let decoded = try JSONDecoder().decode(BASABReport.self, from: legacy)
        XCTAssertTrue(decoded.fidelityVerifiable,
            "absent key ⇒ verifiable (byte-stable; pre-field reports came from real runs)")
    }
}
