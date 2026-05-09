// MARK: - BASV2FoundationCustomStringConvertibleTests
// chapter 四百二十三 / M1063

import XCTest
@testable import BASRuntimeCore

final class BASV2FoundationCustomStringConvertibleTests:
    XCTestCase
{

    // MARK: - Description format pinned

    func testStagePlanDescriptionFormat() {
        XCTAssertEqual(
            BASV2Foundation.stagePlan.description,
            "V2 Stage Plan Foundation (chapter 四百九 / M1009)")
    }

    func testSummaryDigestDescriptionFormat() {
        XCTAssertEqual(
            BASV2Foundation.summaryDigest.description,
            "V2 Summary Digest Foundation " +
            "(chapter 四百二十 / M1053)")
    }

    func testCoherenceEnvelopeDescriptionFormat() {
        XCTAssertEqual(
            BASV2Foundation.coherenceEnvelope.description,
            "V2 Coherence Envelope Foundation " +
            "(chapter 四百十九 / M1049)")
    }

    // MARK: - Human-name accessor pinned per case

    func testHumanNameMapsAllTwelveCases() {
        for f in BASV2Foundation.allCases {
            XCTAssertFalse(f.humanName.isEmpty,
                "humanName for \(f) must be non-empty")
            // humanName must NOT contain the kebab-case
            // raw value (it should be human-formatted)
            XCTAssertFalse(
                f.humanName.contains("-"),
                "humanName for \(f) must not contain " +
                "kebab-case dashes")
        }
    }

    // MARK: - Description includes 3 components

    func testDescriptionIncludesNameTagAndM() {
        for f in BASV2Foundation.allCases {
            XCTAssertTrue(
                f.description.contains(f.humanName),
                "description for \(f) must contain " +
                "humanName")
            XCTAssertTrue(
                f.description.contains(f.chapterTag),
                "description for \(f) must contain " +
                "chapterTag")
            XCTAssertTrue(
                f.description.contains(
                    "M\(f.mNumberClosingCut)"),
                "description for \(f) must contain " +
                "M-number")
        }
    }

    // MARK: - Determinism

    func testDescriptionIsDeterministic() {
        for f in BASV2Foundation.allCases {
            XCTAssertEqual(
                f.description, f.description)
        }
    }

    // MARK: - String interpolation works

    func testStringInterpolationProducesDescription() {
        let f = BASV2Foundation.stagePlan
        let s = "\(f)"
        XCTAssertEqual(s, f.description)
    }
}
