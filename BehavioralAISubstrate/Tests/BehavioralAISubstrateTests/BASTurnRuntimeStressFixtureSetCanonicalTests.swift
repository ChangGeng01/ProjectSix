// MARK: - BASTurnRuntimeStressFixtureSetCanonicalTests
// chapter 四百十二 / M1019

import XCTest
@testable import BASHostKit
@testable import BASPolicy

final class BASTurnRuntimeStressFixtureSetCanonicalTests:
    XCTestCase
{

    // MARK: - smoke-10 factory

    func testSmoke10HasTenFixtures() {
        let s = BASTurnRuntimeStressFixtureSet.smoke10()
        XCTAssertEqual(s.fixtureCount, 10)
        XCTAssertEqual(s.name, "smoke-10")
    }

    func testSmoke10CoversAllRiskBuckets() {
        let s = BASTurnRuntimeStressFixtureSet.smoke10()
        XCTAssertTrue(s.coversAllRiskBuckets)
    }

    func testSmoke10IsDeterministic() {
        let a = BASTurnRuntimeStressFixtureSet.smoke10()
        let b = BASTurnRuntimeStressFixtureSet.smoke10()
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.labelDigest, b.labelDigest)
    }

    // MARK: - canonical-60 factory

    func testCanonical60HasSixtyFixtures() {
        let s = BASTurnRuntimeStressFixtureSet.canonical60()
        XCTAssertEqual(s.fixtureCount, 60)
        XCTAssertEqual(s.name, "canonical-60")
    }

    func testCanonical60CoversAllRiskBuckets() {
        let s = BASTurnRuntimeStressFixtureSet.canonical60()
        XCTAssertTrue(s.coversAllRiskBuckets)
    }

    func testCanonical60Has5UniquePermitModes() {
        let s = BASTurnRuntimeStressFixtureSet.canonical60()
        XCTAssertEqual(s.uniquePermitModes.count, 5)
        XCTAssertTrue(s.uniquePermitModes.contains(.answer))
        XCTAssertTrue(s.uniquePermitModes.contains(.mirror))
        XCTAssertTrue(s.uniquePermitModes.contains(.delay))
        XCTAssertTrue(
            s.uniquePermitModes.contains(.draftOnly))
        XCTAssertTrue(s.uniquePermitModes.contains(.block))
    }

    func testCanonical60IsDeterministic() {
        let a = BASTurnRuntimeStressFixtureSet.canonical60()
        let b = BASTurnRuntimeStressFixtureSet.canonical60()
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.labelDigest, b.labelDigest)
    }

    // MARK: - Smoke and canonical disagree

    func testSmokeAndCanonicalAreDifferent() {
        let smoke =
            BASTurnRuntimeStressFixtureSet.smoke10()
        let canonical =
            BASTurnRuntimeStressFixtureSet.canonical60()
        XCTAssertNotEqual(smoke, canonical)
        XCTAssertNotEqual(
            smoke.fixtureCount,
            canonical.fixtureCount)
    }

    // MARK: - Pinned name constants

    func testNameConstantsArePinned() {
        XCTAssertEqual(
            BASTurnRuntimeStressFixtureSet.smoke10Name,
            "smoke-10")
        XCTAssertEqual(
            BASTurnRuntimeStressFixtureSet.canonical60Name,
            "canonical-60")
        XCTAssertEqual(
            BASTurnRuntimeStressFixtureSet
                .canonicalSetVersion,
            "1.0.0")
    }

    // MARK: - Codable round-trip preserves canonical

    func testCanonicalCodableRoundTrip() throws {
        let original =
            BASTurnRuntimeStressFixtureSet.canonical60()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnRuntimeStressFixtureSet.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }
}
