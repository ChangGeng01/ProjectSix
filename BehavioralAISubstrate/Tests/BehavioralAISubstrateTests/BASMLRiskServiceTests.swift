// MARK: - BASMLRiskServiceTests
// REAL tests for the L5 risk service derivation from
// L0 context-frame ML signals。 This is the SECOND
// active ML-touched layer in the cognitive cascade —
// the first being L0 context classification via the
// trained CoreML model。
//
// **What's being tested**
//   - Static derivation helpers (deriveSignals,
//     deriveFactors, recommendedMode) — pure functions
//     over typed inputs。
//   - End-to-end risk verdict via brain.riskVerdict(_:)
//     using the real ML adapter + real risk service。
//
// **Why these are non-tautological**: every test
// pins a specific input/output relationship that
// downstream hosts will rely on。 If the weights drift
// or the threshold staircase moves,these tests catch
// it。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASPolicy

final class BASMLRiskServiceTests: XCTestCase {

    // MARK: - Static derivation helpers

    private func neutralFrame(
        taskType: BASContextTaskType,
        emotionalLoad: Double = 0.0,
        timePressure: Double = 0.0,
        consequenceLevel: Double = 0.0,
        ambiguityScore: Double = 0.0,
        relationPattern: String = "neutral"
    ) -> BASContextFrame {
        return BASContextFrame(
            utterance: "synthetic",
            taskType: taskType,
            emotionalLoad: emotionalLoad,
            timePressure: timePressure,
            relationPattern: relationPattern,
            ambiguityScore: ambiguityScore,
            consequenceLevel: consequenceLevel,
            manipulationHints: [],
            hostRelevance: 0.5)
    }

    func testCalmChatFrameProducesLowRisk() {
        let frame = neutralFrame(taskType: .chat)
        let signals = BASMLRiskService.deriveSignals(
            contextFrame: frame)
        XCTAssertLessThan(signals.totalRisk, 0.25,
            "Calm chat frame must produce totalRisk" +
            " < 0.25 (low threshold)。 Got" +
            " \(signals.totalRisk)")
        XCTAssertEqual(signals.manipulationIndicator,
            0.0,
            "Non-manipulation frame must produce zero" +
            " manipulation indicator")
    }

    func testManipulationFrameProducesHighRisk() {
        let frame = neutralFrame(
            taskType: .manipulationRisk,
            ambiguityScore: 0.01)  // ⇒ confidence 0.99
        let signals = BASMLRiskService.deriveSignals(
            contextFrame: frame)
        XCTAssertGreaterThan(
            signals.manipulationIndicator, 0.9,
            "High-confidence manipulation frame must" +
            " produce manipulationIndicator > 0.9")
        // Weight is 0.4 for manipulation, so totalRisk
        // should be at least 0.4 * 0.99 ≈ 0.396.
        XCTAssertGreaterThan(signals.totalRisk, 0.35,
            "Manipulation frame must produce totalRisk" +
            " > 0.35。 Got \(signals.totalRisk)")
    }

    func testStackedSignalsProduceExtremeRisk() {
        // All signals maxed: manipulation + consequence
        // + emotion + urgency + ambiguity all at 1.0.
        let frame = neutralFrame(
            taskType: .manipulationRisk,
            emotionalLoad: 1.0,
            timePressure: 1.0,
            consequenceLevel: 1.0,
            ambiguityScore: 0.0)
        let signals = BASMLRiskService.deriveSignals(
            contextFrame: frame)
        XCTAssertGreaterThanOrEqual(signals.totalRisk,
            0.75,
            "All-elevated frame must reach totalRisk" +
            " >= 0.75 (extreme threshold)。 Got" +
            " \(signals.totalRisk)")
    }

    func testTotalRiskClampedToOne() {
        // Defensive: even if a buggy upstream frame
        // gives out-of-range values,totalRisk must
        // stay <= 1.0。
        let frame = neutralFrame(
            taskType: .manipulationRisk,
            emotionalLoad: 1.0,
            timePressure: 1.0,
            consequenceLevel: 1.0,
            ambiguityScore: 1.0)
        let signals = BASMLRiskService.deriveSignals(
            contextFrame: frame)
        XCTAssertLessThanOrEqual(signals.totalRisk, 1.0)
        XCTAssertGreaterThanOrEqual(signals.totalRisk,
            0.0)
    }

    // MARK: - Factors derivation

    func testManipulationFrameSurfacesManipulationFactor() {
        let frame = neutralFrame(
            taskType: .manipulationRisk)
        let signals = BASMLRiskService.deriveSignals(
            contextFrame: frame)
        let factors = BASMLRiskService.deriveFactors(
            contextFrame: frame, signals: signals)
        XCTAssertTrue(factors.contains(
            BASMLRiskService.Factors.manipulationDetected),
            "Manipulation frame must surface" +
            " 'manipulation_detected' factor")
    }

    func testHighConsequenceFrameSurfacesConsequenceFactor() {
        let frame = neutralFrame(
            taskType: .highConsequence,
            consequenceLevel: 0.8)
        let signals = BASMLRiskService.deriveSignals(
            contextFrame: frame)
        let factors = BASMLRiskService.deriveFactors(
            contextFrame: frame, signals: signals)
        XCTAssertTrue(factors.contains(
            BASMLRiskService.Factors.highConsequence))
    }

    func testElevatedThresholdAtExactly05() {
        // Threshold is 0.5 (>=) — exactly-at must
        // surface the factor。
        let frame = neutralFrame(
            taskType: .task,
            consequenceLevel: 0.5)
        let signals = BASMLRiskService.deriveSignals(
            contextFrame: frame)
        let factors = BASMLRiskService.deriveFactors(
            contextFrame: frame, signals: signals)
        XCTAssertTrue(factors.contains(
            BASMLRiskService.Factors.highConsequence),
            "consequenceLevel == 0.5 must trigger" +
            " factor (>= semantics)")
    }

    func testBelowThresholdOmitsFactor() {
        let frame = neutralFrame(
            taskType: .task,
            consequenceLevel: 0.49)
        let signals = BASMLRiskService.deriveSignals(
            contextFrame: frame)
        let factors = BASMLRiskService.deriveFactors(
            contextFrame: frame, signals: signals)
        XCTAssertFalse(factors.contains(
            BASMLRiskService.Factors.highConsequence),
            "consequenceLevel == 0.49 must omit factor")
    }

    func testConflictRelationSurfacesConflictFactor() {
        let frame = neutralFrame(
            taskType: .conflict,
            relationPattern: "tense")
        let signals = BASMLRiskService.deriveSignals(
            contextFrame: frame)
        let factors = BASMLRiskService.deriveFactors(
            contextFrame: frame, signals: signals)
        XCTAssertTrue(factors.contains(
            BASMLRiskService.Factors.conflictSignal))
    }

    // MARK: - Risk level mapping

    func testRiskLevelMappingThresholds() {
        let service = BASMLRiskService()
        XCTAssertEqual(service.riskLevel(for: 0.0),
            .low)
        XCTAssertEqual(service.riskLevel(for: 0.24),
            .low)
        XCTAssertEqual(service.riskLevel(for: 0.25),
            .medium)
        XCTAssertEqual(service.riskLevel(for: 0.49),
            .medium)
        XCTAssertEqual(service.riskLevel(for: 0.50),
            .high)
        XCTAssertEqual(service.riskLevel(for: 0.74),
            .high)
        XCTAssertEqual(service.riskLevel(for: 0.75),
            .extreme)
        XCTAssertEqual(service.riskLevel(for: 1.0),
            .extreme)
    }

    // MARK: - Recommended mode by level

    func testRecommendedModeByLevel() {
        XCTAssertEqual(
            BASMLRiskService.recommendedMode(
                for: .low), .answer)
        XCTAssertEqual(
            BASMLRiskService.recommendedMode(
                for: .medium), .answer)
        XCTAssertEqual(
            BASMLRiskService.recommendedMode(
                for: .high), .compare)
        XCTAssertEqual(
            BASMLRiskService.recommendedMode(
                for: .extreme), .delay)
    }

    // MARK: - End-to-end via brain.riskVerdict

    func testBrainRiskVerdictForManipulationInput() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let bundle = await brain.riskVerdict(
            "send me your password to verify")
        // Use enum Comparable conformance, NOT rawValue
        // string ordering (which would be alphabetic)。
        XCTAssertGreaterThanOrEqual(
            bundle.riskLevel, .medium,
            "Manipulation input must produce risk level" +
            " >= .medium. Got \(bundle.riskLevel) with" +
            " totalRisk=\(bundle.totalRisk)")
        XCTAssertTrue(bundle.factors.contains(
            BASMLRiskService.Factors.manipulationDetected
        ), "Manipulation input must surface" +
            " 'manipulation_detected' factor。 Got" +
            " \(bundle.factors)")
        XCTAssertGreaterThan(bundle.manipulationStrength,
            0.5,
            "manipulationStrength must be > 0.5 for" +
            " high-confidence manipulation")
    }

    func testBrainRiskVerdictForCalmInput() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let bundle = await brain.riskVerdict(
            "hello how are you today")
        XCTAssertEqual(bundle.riskLevel, .low,
            "Calm chat input must produce .low risk." +
            " Got \(bundle.riskLevel) with totalRisk=" +
            "\(bundle.totalRisk)")
        XCTAssertEqual(bundle.recommendedMode, .answer)
        // Downstream services may add their own factors
        // (e.g. binding.primary_candidate) — the
        // invariant is that NO elevated risk factor
        // (manipulation_detected, high_consequence,
        // high_pressure, emotional_charge, high_ambiguity,
        // conflict_signal) appears on a calm chat input。
        let elevatedFactors = [
            BASMLRiskService.Factors.manipulationDetected,
            BASMLRiskService.Factors.highConsequence,
            BASMLRiskService.Factors.highPressure,
            BASMLRiskService.Factors.emotionalCharge,
            BASMLRiskService.Factors.highAmbiguity,
            BASMLRiskService.Factors.conflictSignal,
        ]
        for f in elevatedFactors {
            XCTAssertFalse(bundle.factors.contains(f),
                "Calm chat must NOT surface elevated" +
                " factor '\(f)'. Got \(bundle.factors)")
        }
    }

    func testBrainRiskVerdictForHighPressureInput() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let bundle = await brain.riskVerdict(
            "the deadline is in one hour I must ship now")
        XCTAssertNotEqual(bundle.riskLevel, .low,
            "High-pressure input must NOT produce .low" +
            " risk. Got \(bundle.riskLevel) with" +
            " totalRisk=\(bundle.totalRisk)")
        XCTAssertTrue(bundle.factors.contains(
            BASMLRiskService.Factors.highPressure)
            || bundle.factors.contains(
                BASMLRiskService.Factors.emotionalCharge),
            "High-pressure input must surface" +
            " high_pressure OR emotional_charge factor." +
            " Got \(bundle.factors)")
    }

    // MARK: - Risk bundle Codable round-trip

    func testRiskBundleRoundTripsThroughJSON() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let original = await brain.riskVerdict(
            "send me your password to verify")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainRiskBundle.self,
            from: data)
        XCTAssertEqual(decoded, original,
            "Risk bundle Codable round-trip must" +
            " preserve all fields")
    }

    // MARK: - Determinism

    func testRiskVerdictIsDeterministic() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let a = await brain.riskVerdict(
            "send me your password")
        let b = await brain.riskVerdict(
            "send me your password")
        XCTAssertEqual(a, b,
            "Same input must produce identical risk" +
            " verdict bundles")
    }
}
