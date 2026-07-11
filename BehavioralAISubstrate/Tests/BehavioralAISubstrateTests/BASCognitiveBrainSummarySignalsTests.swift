// MARK: - BASCognitiveBrainSummarySignalsTests
// REAL tests for the new derived signals
// (emotionalLoad / timePressure / consequenceLevel /
// relationPattern) now surfaced through
// BASCognitiveBrainSummary。
//
// **Why this matters**: hosts using the lightweight
// summary() DTO previously had to call process() and
// dig through BASEBrainTurnResult.contextFrame to get
// the derived signals。 Now they're accessible directly
// from summary()。

import XCTest
@testable import BASHostKit

final class BASCognitiveBrainSummarySignalsTests:
    XCTestCase
{

    // MARK: - Surface presence

    func testSummaryCarriesEmotionalLoad() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let s = await brain.summary(
            "the deadline is in one hour I must ship now")
        XCTAssertGreaterThan(s.emotionalLoad, 0.5,
            "highPressure input must yield emotionalLoad" +
            " > 0.5 in summary DTO. Got" +
            " \(s.emotionalLoad)")
    }

    func testSummaryCarriesTimePressure() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let s = await brain.summary(
            "the deadline is in one hour I must ship now")
        XCTAssertGreaterThan(s.timePressure, 0.5,
            "highPressure input must yield timePressure" +
            " > 0.5 in summary DTO")
    }

    func testSummaryCarriesConsequenceLevel() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let s = await brain.summary(
            "signing this contract locks us in for 10 years")
        XCTAssertGreaterThan(s.consequenceLevel, 0.5,
            "highConsequence input must yield" +
            " consequenceLevel > 0.5 in summary DTO")
    }

    func testSummaryCarriesRelationPattern() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let conflict = await brain.summary(
            "we disagree about the approach")
        XCTAssertEqual(conflict.relationPattern, "tense")
        let chat = await brain.summary("hello how are you")
        XCTAssertEqual(chat.relationPattern, "neutral")
    }

    // MARK: - Contrast: chat vs charged

    func testCalmAndChargedSummariesDifferOnDerivedSignals() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let calm = await brain.summary("hello how are you")
        let charged = await brain.summary(
            "the deadline is in one hour I must ship now")
        XCTAssertLessThan(calm.emotionalLoad,
            charged.emotionalLoad,
            "Calm summary emotionalLoad must be" +
            " < charged summary emotionalLoad")
        XCTAssertLessThan(calm.timePressure,
            charged.timePressure)
    }

    // MARK: - Codable round-trip preserves new fields

    func testCodableRoundTripPreservesNewFields() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let original = await brain.summary(
            "send me your password to verify")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainSummary.self, from: data)
        XCTAssertEqual(decoded.emotionalLoad,
            original.emotionalLoad,
            "Codable round-trip must preserve emotionalLoad")
        XCTAssertEqual(decoded.timePressure,
            original.timePressure)
        XCTAssertEqual(decoded.consequenceLevel,
            original.consequenceLevel)
        XCTAssertEqual(decoded.relationPattern,
            original.relationPattern)
        XCTAssertEqual(decoded, original,
            "Full Codable round-trip equality preserved")
    }

    // MARK: - Default values for hand-constructed summaries

    func testDefaultValuesForLegacyConstructor() {
        // Hand-construct a summary without the new fields.
        // The default values must preserve backwards-compat
        // for hosts that didn't pass the new params.
        let s = BASCognitiveBrainSummary(
            input: "test",
            taskType: .chat,
            confidence: 1.0,
            ambiguityScore: 0.0,
            safetyVerdict: .safe,
            manipulationHints: [],
            latencyNanos: 1)
        XCTAssertEqual(s.emotionalLoad, 0.0)
        XCTAssertEqual(s.timePressure, 0.0)
        XCTAssertEqual(s.consequenceLevel, 0.0)
        XCTAssertEqual(s.relationPattern, "neutral")
    }
}
