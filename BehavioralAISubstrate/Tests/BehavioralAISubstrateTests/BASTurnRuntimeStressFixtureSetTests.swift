// MARK: - BASTurnRuntimeStressFixtureSetTests — chapter 四百十二 / M1018

import XCTest
@testable import BASHostKit
@testable import BASPolicy

final class BASTurnRuntimeStressFixtureSetTests:
    XCTestCase
{

    private func makeKey(
        risk: BASTurnRuntimeStressRiskBucket = .low,
        mode: BASActionPermitMode = .answer
    ) -> BASTurnRuntimeStressFixtureKey {
        BASTurnRuntimeStressFixtureKey(
            risk: risk,
            permitMode: mode,
            quarantines: false,
            anchorTone: false,
            neuralCoreWired: false,
            evolutionFeedbackPresent: false)
    }

    // MARK: - Empty factory

    func testEmptyFactoryHasZeroFixtures() {
        let s = BASTurnRuntimeStressFixtureSet
            .empty(name: "smoke")
        XCTAssertEqual(s.name, "smoke")
        XCTAssertEqual(s.setVersion, "1.0.0")
        XCTAssertEqual(s.fixtureCount, 0)
        XCTAssertTrue(s.uniqueRiskBuckets.isEmpty)
    }

    // MARK: - Appending

    func testAppendingProducesNewSet() {
        let s0 = BASTurnRuntimeStressFixtureSet
            .empty(name: "smoke")
        let s1 = s0.appending(makeKey())
        XCTAssertEqual(s0.fixtureCount, 0)
        XCTAssertEqual(s1.fixtureCount, 1)
    }

    // MARK: - Aggregate accessors

    func testUniqueRiskBucketsCoversAppendedRisks() {
        let s = BASTurnRuntimeStressFixtureSet
            .empty(name: "smoke")
            .appending(makeKey(risk: .low))
            .appending(makeKey(risk: .medium))
            .appending(makeKey(risk: .low))  // dup
        XCTAssertEqual(
            s.uniqueRiskBuckets,
            Set([.low, .medium]))
    }

    func testCoversAllRiskBucketsTrueWhenAllFourPresent() {
        let s = BASTurnRuntimeStressFixtureSet
            .empty(name: "smoke")
            .appending(makeKey(risk: .low))
            .appending(makeKey(risk: .medium))
            .appending(makeKey(risk: .high))
            .appending(makeKey(risk: .extreme))
        XCTAssertTrue(s.coversAllRiskBuckets)
    }

    func testCoversAllRiskBucketsFalseWhenMissing() {
        let s = BASTurnRuntimeStressFixtureSet
            .empty(name: "smoke")
            .appending(makeKey(risk: .low))
            .appending(makeKey(risk: .high))
        XCTAssertFalse(s.coversAllRiskBuckets)
    }

    func testUniquePermitModesCovers() {
        let s = BASTurnRuntimeStressFixtureSet
            .empty(name: "smoke")
            .appending(makeKey(mode: .answer))
            .appending(makeKey(mode: .delay))
        XCTAssertEqual(
            s.uniquePermitModes, Set([.answer, .delay]))
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesFields() throws {
        let original = BASTurnRuntimeStressFixtureSet
            .empty(name: "smoke", setVersion: "2.5.0")
            .appending(makeKey(risk: .extreme))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnRuntimeStressFixtureSet.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Label digest is deterministic

    func testLabelDigestIsDeterministic() {
        let s = BASTurnRuntimeStressFixtureSet
            .empty(name: "smoke")
            .appending(makeKey(risk: .low))
            .appending(makeKey(risk: .high))
        XCTAssertEqual(s.labelDigest, s.labelDigest)
        // Should encode all fixture labels separated by ";"
        let parts = s.labelDigest.split(separator: ";")
        XCTAssertEqual(parts.count, 2)
    }
}
