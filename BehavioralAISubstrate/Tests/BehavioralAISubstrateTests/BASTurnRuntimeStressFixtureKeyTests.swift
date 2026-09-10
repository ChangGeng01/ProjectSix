// MARK: - BASTurnRuntimeStressFixtureKeyTests — chapter 四百十一 / M1016

import XCTest
@testable import BASHostKit
@testable import BASPolicy

final class BASTurnRuntimeStressFixtureKeyTests:
    XCTestCase
{

    // MARK: - Init wires fields

    func testInitWiresAllFields() {
        let k = BASTurnRuntimeStressFixtureKey(
            risk: .high,
            permitMode: .answer,
            quarantines: true,
            anchorTone: false,
            neuralCoreWired: true,
            evolutionFeedbackPresent: false)
        XCTAssertEqual(k.risk, .high)
        XCTAssertEqual(k.permitMode, .answer)
        XCTAssertTrue(k.quarantines)
        XCTAssertFalse(k.anchorTone)
        XCTAssertTrue(k.neuralCoreWired)
        XCTAssertFalse(k.evolutionFeedbackPresent)
    }

    // MARK: - Label encoding

    func testLabelEncodesAllSixSlots() {
        let k = BASTurnRuntimeStressFixtureKey(
            risk: .low,
            permitMode: .answer,
            quarantines: false,
            anchorTone: true,
            neuralCoreWired: true,
            evolutionFeedbackPresent: false)
        XCTAssertEqual(
            k.label,
            "low|answer|q:false|t:true|nc:true|ev:false")
    }

    // MARK: - Different keys produce different labels

    func testDifferentRiskProducesDifferentLabel() {
        let low = BASTurnRuntimeStressFixtureKey(
            risk: .low, permitMode: .answer,
            quarantines: false, anchorTone: false,
            neuralCoreWired: false,
            evolutionFeedbackPresent: false)
        let high = BASTurnRuntimeStressFixtureKey(
            risk: .high, permitMode: .answer,
            quarantines: false, anchorTone: false,
            neuralCoreWired: false,
            evolutionFeedbackPresent: false)
        XCTAssertNotEqual(low.label, high.label)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesFields() throws {
        let original = BASTurnRuntimeStressFixtureKey(
            risk: .extreme,
            permitMode: .delay,
            quarantines: true,
            anchorTone: true,
            neuralCoreWired: false,
            evolutionFeedbackPresent: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnRuntimeStressFixtureKey.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Hashable + Equatable contract

    func testEqualKeysHaveEqualHash() {
        let k1 = BASTurnRuntimeStressFixtureKey(
            risk: .low, permitMode: .answer,
            quarantines: false, anchorTone: false,
            neuralCoreWired: false,
            evolutionFeedbackPresent: false)
        let k2 = BASTurnRuntimeStressFixtureKey(
            risk: .low, permitMode: .answer,
            quarantines: false, anchorTone: false,
            neuralCoreWired: false,
            evolutionFeedbackPresent: false)
        XCTAssertEqual(k1, k2)
        XCTAssertEqual(k1.hashValue, k2.hashValue)
    }

    // MARK: - Determinism

    func testLabelIsDeterministic() {
        let k = BASTurnRuntimeStressFixtureKey(
            risk: .medium, permitMode: .mirror,
            quarantines: true, anchorTone: false,
            neuralCoreWired: true,
            evolutionFeedbackPresent: false)
        XCTAssertEqual(k.label, k.label)
    }
}
