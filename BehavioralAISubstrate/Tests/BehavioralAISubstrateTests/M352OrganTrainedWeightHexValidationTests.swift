import XCTest
@testable import BASOrgan

/// M352 (chapter 八十一 deep-review fix) — pin that
/// `BASOrganTrainedWeightFilter.rejectionReason` validates hex
/// CONTENT, not just length, on `trainingCorpusHashHex` and
/// `trainedWeightsHashHex`.
///
/// ## Why this exists
///
/// Pre-M352 the filter only checked the length of the hash fields
/// (must be exactly 64 chars). This allowed any 64-character string
/// to pass — for example `"zzzz...zzzz"` (64 z's) — even though
/// SHA-256 hex output is exactly `[0-9a-fA-F]{64}`. A malformed
/// envelope with non-hex content would slip past the gate.
///
/// M352 adds a content check: any non-hex character in either
/// hash field returns the new `.malformedHashContent(field:firstInvalidChar:)`
/// rejection. The check runs after length validation so length-zero
/// inputs (very common malformation) are still reported with the
/// length error.
///
/// What this file pins:
///
///   1. 64 z's pass length but fail content check.
///   2. Mixed-case hex passes (SHA-256 hex commonly uppercase).
///   3. The new `.malformedHashContent` case carries field name
///      + first offending character.
///   4. Length error still fires for wrong-length inputs.
///   5. Backward-compat: valid envelopes (lowercase hex, 64 chars)
///      still pass.
final class M352OrganTrainedWeightHexValidationTests: XCTestCase {

    private let validHash =
        "9e15d296c25c5b28da42eb5d5ca7d89bf768f407a49cbad21ed0b735eec114f5"

    private func envelope(
        corpusHash: String,
        weightsHash: String,
        tier: BASOrganTrainedWeightProvenance.Tier
            = .domainExpertReviewed,
        attestationRef: String? =
            "audit.attestation.test.v1",
        attestationIssuedAt: Date? = Date(
            timeIntervalSince1970: 1_700_000_000)
    ) -> BASOrganTrainedWeightProvenance {
        BASOrganTrainedWeightProvenance(
            adapterID: "adapter.test.v1",
            baseModelID: "apple.foundation-models.v1",
            tier: tier,
            trainingCurriculumRef:
                "audit.curriculum.test.v1",
            trainingCorpusHashHex: corpusHash,
            trainedWeightsHashHex: weightsHash,
            expertAttestationSignatureRef: attestationRef,
            attestationIssuedAt: attestationIssuedAt)
    }

    // MARK: - Tests

    func testSixtyFourZsFailsContentCheck() {
        let nonHex = String(repeating: "z", count: 64)
        let env = envelope(
            corpusHash: nonHex,
            weightsHash: validHash)
        let reason = BASOrganTrainedWeightFilter
            .rejectionReason(for: env)
        XCTAssertEqual(
            reason,
            .malformedHashContent(
                field: "trainingCorpusHashHex",
                firstInvalidChar: "z"))
    }

    func testSixtyFourZsInWeightsHashFailsContentCheck() {
        let nonHex = String(repeating: "z", count: 64)
        let env = envelope(
            corpusHash: validHash,
            weightsHash: nonHex)
        let reason = BASOrganTrainedWeightFilter
            .rejectionReason(for: env)
        XCTAssertEqual(
            reason,
            .malformedHashContent(
                field: "trainedWeightsHashHex",
                firstInvalidChar: "z"))
    }

    func testNonHexCharsInTheMiddleAreDetected() {
        // Length 64, but a 'g' in position 32.
        let prefix = String(repeating: "a", count: 32)
        let suffix = String(repeating: "b", count: 31)
        let bad = prefix + "g" + suffix
        XCTAssertEqual(bad.count, 64)
        let env = envelope(
            corpusHash: bad, weightsHash: validHash)
        XCTAssertEqual(
            BASOrganTrainedWeightFilter.rejectionReason(
                for: env),
            .malformedHashContent(
                field: "trainingCorpusHashHex",
                firstInvalidChar: "g"))
    }

    func testCodableRoundTripForNewRejectionCase() throws {
        // Pin that the new case round-trips through Codable —
        // important because `firstInvalidChar` is `String` not
        // `Character` specifically so synthesized Codable works.
        let rejection: BASOrganTrainedWeightFilter.Rejection =
            .malformedHashContent(
                field: "trainingCorpusHashHex",
                firstInvalidChar: "z")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(rejection)
        let decoded = try JSONDecoder().decode(
            BASOrganTrainedWeightFilter.Rejection.self,
            from: data)
        XCTAssertEqual(rejection, decoded)
    }

    func testUppercaseHexIsValid() {
        let upper =
            "9E15D296C25C5B28DA42EB5D5CA7D89BF768F407A49CBAD21ED0B735EEC114F5"
        XCTAssertEqual(upper.count, 64)
        let env = envelope(
            corpusHash: upper, weightsHash: upper)
        XCTAssertNil(
            BASOrganTrainedWeightFilter.rejectionReason(
                for: env))
    }

    func testMixedCaseHexIsValid() {
        let mixed =
            "9E15d296C25c5B28da42EB5D5ca7D89BF768F407a49CBAD21ED0b735EEC114F5"
        XCTAssertEqual(mixed.count, 64)
        let env = envelope(
            corpusHash: mixed, weightsHash: mixed)
        XCTAssertNil(
            BASOrganTrainedWeightFilter.rejectionReason(
                for: env))
    }

    func testLengthErrorTakesPrecedenceOverContentError() {
        // 8-char string is wrong length AND non-hex (z's).
        // Length error fires first.
        let short = "zzzzzzzz"
        let env = envelope(
            corpusHash: short, weightsHash: validHash)
        XCTAssertEqual(
            BASOrganTrainedWeightFilter.rejectionReason(
                for: env),
            .malformedHash(
                field: "trainingCorpusHashHex",
                length: 8))
    }

    func testValidLowercaseHexStillPasses() {
        let env = envelope(
            corpusHash: validHash, weightsHash: validHash)
        XCTAssertNil(
            BASOrganTrainedWeightFilter.rejectionReason(
                for: env))
    }

    func testFirstNonHexCharacterHelperOnAllHexReturnsNil() {
        XCTAssertNil(
            BASOrganTrainedWeightFilter
                .firstNonHexCharacter(validHash))
    }

    func testFirstNonHexCharacterHelperOnNonHexReturnsFirst() {
        XCTAssertEqual(
            BASOrganTrainedWeightFilter
                .firstNonHexCharacter("abc!def"),
            "!")
    }

    func testEmptyStringHasNoNonHexCharacters() {
        // Empty string has no non-hex characters, so helper
        // returns nil (vacuous truth). Length check would still
        // fire upstream.
        XCTAssertNil(
            BASOrganTrainedWeightFilter
                .firstNonHexCharacter(""))
    }
}
