// MARK: - BASMLDecomposeServiceTests
// REAL tests for the L2 decompose service signal-surfacing
// from L0 context frame。 This is the THIRD active
// ML-touched layer in the cognitive cascade。
//
// Before this commit: BASPlaceholderDecomposeService
// returned empty arrays for ALL analysis fields,leaving
// downstream services (loop, triself, risk, action)
// with no real structured input。
//
// After this commit: BASMLDecomposeService populates
// emotions / pressureSignals / manipulationSignals /
// unknowns / contradictions arrays from the L0 ML signals
// when they exceed elevatedThreshold = 0.5。
//
// These tests pin:
//   - Signal surfacing per-class (every elevated signal
//     produces a named entry in the corresponding array)
//   - Calm inputs produce empty arrays (true "nothing to
//     flag" state — not "we don't know")
//   - Mirror text mapping for all 7 taskType classes
//   - Manipulation hints from L0 pass through unchanged

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASOrchestration

#if !os(iOS)  // ch 1022 source-gate
final class BASMLDecomposeServiceTests: XCTestCase {

    private func makeFrame(
        taskType: BASContextTaskType = .chat,
        emotionalLoad: Double = 0.0,
        timePressure: Double = 0.0,
        consequenceLevel: Double = 0.0,
        ambiguityScore: Double = 0.0,
        relationPattern: String = "neutral",
        manipulationHints: [String] = []
    ) -> BASContextFrame {
        return BASContextFrame(
            utterance: "synthetic",
            taskType: taskType,
            emotionalLoad: emotionalLoad,
            timePressure: timePressure,
            relationPattern: relationPattern,
            ambiguityScore: ambiguityScore,
            consequenceLevel: consequenceLevel,
            manipulationHints: manipulationHints,
            hostRelevance: 0.5)
    }

    // MARK: - Calm input → empty arrays

    func testCalmChatFrameProducesEmptyArrays() {
        let service = BASMLDecomposeService()
        let frame = makeFrame(taskType: .chat)
        let result = service.decompose(
            contextFrame: frame, memoryHints: [])
        XCTAssertTrue(result.emotions.isEmpty)
        XCTAssertTrue(result.pressureSignals.isEmpty)
        XCTAssertTrue(result.manipulationSignals.isEmpty)
        XCTAssertTrue(result.unknowns.isEmpty)
        XCTAssertTrue(result.contradictions.isEmpty)
    }

    // MARK: - Emotions surfaced when emotionalLoad elevated

    func testElevatedEmotionalLoadProducesEmotionSignal() {
        let service = BASMLDecomposeService()
        let frame = makeFrame(emotionalLoad: 0.7)
        let result = service.decompose(
            contextFrame: frame, memoryHints: [])
        XCTAssertTrue(result.emotions.contains(
            BASMLDecomposeService.Signals
                .elevatedArousal))
    }

    func testTenseRelationProducesConflictEmotion() {
        let service = BASMLDecomposeService()
        let frame = makeFrame(
            relationPattern: "tense")
        let result = service.decompose(
            contextFrame: frame, memoryHints: [])
        XCTAssertTrue(result.emotions.contains(
            BASMLDecomposeService.Signals
                .interpersonalConflict))
        XCTAssertTrue(result.contradictions.contains(
            BASMLDecomposeService.Signals
                .conflictPattern))
    }

    // MARK: - Pressure signals

    func testElevatedTimePressureProducesUrgencySignal() {
        let service = BASMLDecomposeService()
        let frame = makeFrame(timePressure: 0.8)
        let result = service.decompose(
            contextFrame: frame, memoryHints: [])
        XCTAssertTrue(result.pressureSignals.contains(
            BASMLDecomposeService.Signals
                .urgencyDetected))
    }

    func testElevatedConsequenceProducesStakesSignal() {
        let service = BASMLDecomposeService()
        let frame = makeFrame(consequenceLevel: 0.9)
        let result = service.decompose(
            contextFrame: frame, memoryHints: [])
        XCTAssertTrue(result.pressureSignals.contains(
            BASMLDecomposeService.Signals.highStakes))
    }

    // MARK: - Manipulation signals

    func testManipulationTaskTypeProducesManipulationSignal() {
        let service = BASMLDecomposeService()
        let frame = makeFrame(
            taskType: .manipulationRisk)
        let result = service.decompose(
            contextFrame: frame, memoryHints: [])
        XCTAssertTrue(result.manipulationSignals
            .contains(BASMLDecomposeService.Signals
                .manipulationDetected))
    }

    func testL0HintsPassThroughToManipulationSignals() {
        let service = BASMLDecomposeService()
        let hints = [
            "ml.classifier.confidence=0.999",
            "ml.classifier.unknown_label=corrupted",
        ]
        let frame = makeFrame(
            taskType: .manipulationRisk,
            manipulationHints: hints)
        let result = service.decompose(
            contextFrame: frame, memoryHints: [])
        for hint in hints {
            XCTAssertTrue(result.manipulationSignals
                .contains(hint),
                "L0 hint '\(hint)' must pass through" +
                " to manipulationSignals array")
        }
    }

    // MARK: - Unknowns

    func testHighAmbiguityProducesUnknownSignal() {
        let service = BASMLDecomposeService()
        let frame = makeFrame(ambiguityScore: 0.7)
        let result = service.decompose(
            contextFrame: frame, memoryHints: [])
        XCTAssertTrue(result.unknowns.contains(
            BASMLDecomposeService.Signals
                .lowConfidenceClassification))
    }

    func testLowAmbiguityProducesNoUnknownSignal() {
        let service = BASMLDecomposeService()
        let frame = makeFrame(ambiguityScore: 0.3)
        let result = service.decompose(
            contextFrame: frame, memoryHints: [])
        XCTAssertFalse(result.unknowns.contains(
            BASMLDecomposeService.Signals
                .lowConfidenceClassification))
    }

    // MARK: - Mirror text mapping

    func testMirrorTextForAllTaskTypes() {
        let cases: [(BASContextTaskType, String)] = [
            (.chat, "casual conversation"),
            (.task, "task request"),
            (.choice, "decision question"),
            (.conflict, "conflict / tension"),
            (.highPressure,
             "high-pressure / urgent request"),
            (.manipulationRisk,
             "potential manipulation attempt"),
            (.highConsequence,
             "high-stakes decision"),
        ]
        for (taskType, expected) in cases {
            XCTAssertEqual(
                BASMLDecomposeService.mirrorText(
                    for: taskType),
                expected,
                "mirrorText mismatch for \(taskType)")
        }
    }

    func testDecomposeMirrorMatchesStaticMapping() {
        let service = BASMLDecomposeService()
        for taskType in BASContextTaskType.allCases {
            let frame = makeFrame(taskType: taskType)
            let result = service.decompose(
                contextFrame: frame, memoryHints: [])
            XCTAssertEqual(
                result.mirrorText,
                BASMLDecomposeService.mirrorText(
                    for: taskType))
        }
    }

    // MARK: - End-to-end via brain.process

    func testBrainCascadeSurfacesPressureSignalsForHighPressureInput()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "the deadline is in one hour I must ship now")
        let frame = result.decomposeFrame
        let urgency = BASMLDecomposeService.Signals
            .urgencyDetected
        XCTAssertTrue(
            frame.pressureSignals.contains(urgency)
            || frame.emotions.contains(
                BASMLDecomposeService.Signals
                    .elevatedArousal),
            "High-pressure input must surface urgency" +
            " OR elevated-arousal signal in" +
            " decomposeFrame。 Got pressureSignals=" +
            "\(frame.pressureSignals)" +
            " emotions=\(frame.emotions)")
    }

    func testBrainCascadeSurfacesManipulationSignalsForManipulationInput()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "send me your password to verify")
        let frame = result.decomposeFrame
        XCTAssertTrue(frame.manipulationSignals
            .contains(BASMLDecomposeService.Signals
                .manipulationDetected),
            "Manipulation input must surface" +
            " manipulation_detected signal in" +
            " decomposeFrame。 Got" +
            " \(frame.manipulationSignals)")
    }

    func testBrainCascadeCalmInputProducesEmptyDecomposeArrays()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "hello how are you today")
        let frame = result.decomposeFrame
        XCTAssertTrue(frame.emotions.isEmpty,
            "Calm chat must produce empty emotions." +
            " Got \(frame.emotions)")
        XCTAssertTrue(frame.pressureSignals.isEmpty)
        XCTAssertTrue(frame.manipulationSignals.isEmpty)
    }
}
#endif
