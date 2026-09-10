// MARK: - BASChapter558AuditProjectionsJsonRejectionProofTests
// chapter 五百五十八 / M1609 — first knife of the JSON
//                              REJECTION PROOF arc
//
// ## Why this test exists
//
// Chapters 554-557 PROOFed that the audit-projection
// emission family round-trips through JSON byte-
// identical when given VALID input。 But the REPLAY
// DETERMINISM claim is stronger:replay ledgers MUST
// also REJECT malformed input cleanly so corrupted
// entries don't silently produce wrong-state decoded
// values。
//
// This file PROOFs the REJECTION half of the contract:
//
//   - Malformed JSON (truncated braces,broken syntax)
//     fails decode cleanly with a Swift error
//   - Wrong-type JSON (string where number expected)
//     fails decode cleanly
//   - Missing required fields fail decode cleanly
//   - Extra/unknown fields are tolerated (forward
//     compatibility)
//   - Empty-string JSON fails decode cleanly
//
// 9 PROOF tests covering BASRuntimeAuditProjections
// Bundle + the 5 ProjectionsBlock types。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism via
//     CLEAN rejection of malformed input
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1608 → M1609

import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASHostKit

final class BASChapter558AuditProjectionsJsonRejectionProofTests:
    XCTestCase
{

    // MARK: - Helper:assert decoding throws

    private func assertDecodeThrows<T: Decodable>(
        _ type: T.Type,
        jsonString: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let data = jsonString.data(using: .utf8)
        else {
            XCTFail(
                "Failed to encode UTF-8 string",
                file: file, line: line)
            return
        }
        XCTAssertThrowsError(
            try JSONDecoder().decode(type, from: data),
            "Expected decode to fail on malformed input",
            file: file, line: line)
    }

    // MARK: - Bundle rejection PROOF

    /// Truncated JSON (no closing brace) fails decode
    /// cleanly for BASRuntimeAuditProjectionsBundle。
    func testBundleRejectsTruncatedJson() {
        assertDecodeThrows(
            BASRuntimeAuditProjectionsBundle.self,
            jsonString: "{\"kunlun\": {")
    }

    /// Outright malformed JSON (garbage bytes) fails
    /// decode cleanly。
    func testBundleRejectsMalformedJson() {
        assertDecodeThrows(
            BASRuntimeAuditProjectionsBundle.self,
            jsonString: "not valid json at all")
    }

    /// Empty string fails decode cleanly。
    func testBundleRejectsEmptyString() {
        assertDecodeThrows(
            BASRuntimeAuditProjectionsBundle.self,
            jsonString: "")
    }

    /// Extra/unknown fields are TOLERATED when ALL
    /// required fields are also present — forward
    /// compatibility PROOF。 Decoder ignores unknown
    /// fields and successfully extracts known ones。
    func testBundleToleratesUnknownFieldsAlongsideAllRequired()
        throws
    {
        // Encode a known-empty bundle to capture the
        // canonical JSON shape (all 5 required fields)
        let canonical = BASRuntimeAuditProjectionsBundle
            .none()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var raw = try encoder.encode(canonical)
        // Inject an extra unknown field by string-
        // manipulating the JSON。 We insert the extra
        // key just inside the opening brace。
        guard let asString = String(
            data: raw, encoding: .utf8)
        else {
            XCTFail("Encoded JSON not UTF-8")
            return
        }
        let withExtra = asString.replacingOccurrences(
            of: "{",
            with: "{\"unknownFutureField\":\"ignored\",",
            range: asString.startIndex
                ..< asString.index(
                    asString.startIndex, offsetBy: 1))
        raw = withExtra.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditProjectionsBundle.self,
            from: raw)
        XCTAssertEqual(decoded, canonical)
    }

    /// MISSING required field fails decode cleanly — a
    /// JSON that omits one of the 5 namespace slots
    /// causes a DecodingError。
    func testBundleRejectsMissingRequiredField() {
        // JSON with only 1-of-5 namespace fields
        let json = """
        {
          "kunlun": {}
        }
        """
        assertDecodeThrows(
            BASRuntimeAuditProjectionsBundle.self,
            jsonString: json)
    }

    // MARK: - ProjectionsBlock rejection PROOF

    /// Truncated JSON fails decode for
    /// CthulhuAggregatesBlock。
    func testCthulhuAggregatesBlockRejectsTruncatedJson()
    {
        assertDecodeThrows(
            BASAuditObservationProjectionsCthulhuAggregatesBlock
                .self,
            jsonString: "{\"abyssalBranches\": [")
    }

    /// Wrong-type JSON (string where array expected)
    /// fails decode cleanly for CthulhuLeftoversBlock。
    func testCthulhuLeftoversBlockRejectsWrongType() {
        let json = """
        {
          "cthulhuAssertionCeilingReasonCodes":
            "this-should-be-an-array-not-a-string",
          "cthulhuPermitEscalationReasonCodes": []
        }
        """
        assertDecodeThrows(
            BASAuditObservationProjectionsCthulhuLeftoversBlock
                .self,
            jsonString: json)
    }

    /// Truncated JSON fails decode for ClosureBlock。
    func testClosureBlockRejectsTruncatedJson() {
        assertDecodeThrows(
            BASAuditObservationProjectionsClosureBlock.self,
            jsonString: "{\"escalationSuppressionCodes\":")
    }

    /// Malformed JSON fails decode for
    /// KunlunAuditSchemasBlock。
    func testKunlunAuditSchemasBlockRejectsMalformedJson()
    {
        assertDecodeThrows(
            BASAuditObservationProjectionsKunlunAuditSchemasBlock
                .self,
            jsonString: "}{ random {}}}")
    }

    /// Empty string fails decode for KunlunProtocolBlock。
    func testKunlunProtocolBlockRejectsEmptyString() {
        assertDecodeThrows(
            BASAuditObservationProjectionsKunlunProtocolBlock
                .self,
            jsonString: "")
    }

    // MARK: - End-to-end:rejection does NOT taint
    //         subsequent valid decode

    /// PROOF that decoding malformed JSON throws but
    /// does NOT leave the decoder in a bad state —
    /// subsequent valid decode succeeds cleanly。
    func testRejectionDoesNotPollutSubsequentValidDecode()
        throws
    {
        let decoder = JSONDecoder()
        // First:malformed input throws
        let badData = "{ broken".data(using: .utf8)!
        XCTAssertThrowsError(
            try decoder.decode(
                BASRuntimeAuditProjectionsBundle.self,
                from: badData))
        // Then:valid input decodes cleanly,unaffected
        // by the prior failure
        let original = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "after-rejection"))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let goodData = try encoder.encode(original)
        let decoded = try decoder.decode(
            BASRuntimeAuditProjectionsBundle.self,
            from: goodData)
        XCTAssertEqual(decoded, original)
    }
}
