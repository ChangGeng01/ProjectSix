// MARK: - BASCognitiveBrainEdgeCaseTests
// Real edge case integration tests for the full
// brain.process() + safetyVerdict() pipeline. NOT
// tautological — these exercise real input boundaries
// that compiler/type system don't enforce.

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASCognitiveBrainEdgeCaseTests: XCTestCase {

    // MARK: - Empty / whitespace input

    func testEmptyStringInputDoesNotCrash() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process("")
        // No crash, returns a result. Output is whatever
        // the ML model produces for zero-vector input.
        XCTAssertEqual(
            result.contextFrame.utterance, "",
            "Empty input should round-trip as empty" +
            " utterance")
    }

    func testWhitespaceOnlyInputDoesNotCrash() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process("   \t\n  ")
        XCTAssertEqual(
            result.contextFrame.utterance, "   \t\n  ",
            "Whitespace-only input should round-trip")
    }

    func testEmptyInputSafetyVerdictIsSafe() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let (verdict, _, confidence) =
            await brain.safetyVerdict("")
        // Empty input has near-uniform softmax → low
        // confidence → must NOT block (per
        // safetyConfidenceThreshold = 0.6)
        XCTAssertEqual(verdict, .safe,
            "Empty input must not trigger .block or .warn" +
            " — confidence \(confidence) should be below" +
            " threshold")
    }

    // MARK: - Long input (no OOM, no truncation crash)

    func testVeryLongInputDoesNotCrash() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        // 10KB of "word " — 2000 tokens
        let longInput = String(
            repeating: "word ", count: 2000)
        let result = await brain.process(longInput)
        // Should not crash, should not truncate
        // utterance silently
        XCTAssertEqual(
            result.contextFrame.utterance.count,
            longInput.count,
            "Long input should round-trip without" +
            " truncation")
    }

    func testVeryLongInputAdapterAlsoSurvives() throws {
        let adapter = try BASContextClassifierMLAdapter()
        let longInput = String(
            repeating: "alpha beta gamma ", count: 1000)
        let (label, confidence, _) =
            try adapter.classify(text: longInput)
        XCTAssertTrue(
            BASContextClassifierMLAdapter.labels.contains(
                label),
            "Long input must still produce a valid label")
        XCTAssertGreaterThanOrEqual(confidence, 0.0)
        XCTAssertLessThanOrEqual(confidence, 1.0)
    }

    // MARK: - Unicode / non-ASCII input

    func testChineseInputDoesNotCrash() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "你好 请帮我 编译 这个 swift 项目")
        XCTAssertEqual(
            result.contextFrame.utterance,
            "你好 请帮我 编译 这个 swift 项目")
    }

    func testEmojiInputDoesNotCrash() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "hello 🌍 how are you 😊 today")
        XCTAssertEqual(
            result.contextFrame.utterance,
            "hello 🌍 how are you 😊 today")
    }

    func testMixedScriptInputDoesNotCrash() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "compile 编译 the package 包 🎯")
        XCTAssertEqual(
            result.contextFrame.utterance,
            "compile 编译 the package 包 🎯")
    }

    // MARK: - Punctuation / special chars

    func testPureNumericInputDoesNotCrash() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process("12345 67890")
        XCTAssertEqual(
            result.contextFrame.utterance, "12345 67890")
    }

    func testPunctuationOnlyInputDoesNotCrash() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "!@#$%^&*() ,.;:?")
        XCTAssertEqual(
            result.contextFrame.utterance,
            "!@#$%^&*() ,.;:?")
    }

    func testNewlinesInInputDoesNotCrash() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "line 1\nline 2\nline 3")
        XCTAssertEqual(
            result.contextFrame.utterance,
            "line 1\nline 2\nline 3")
    }

    // MARK: - Hash-bucket collision resilience

    /// The 256-bucket hash space has known collisions for
    /// distinct tokens (256 buckets, vocab >256 produces
    /// pigeon-hole). Verify that classification still
    /// works robustly even when input tokens happen to
    /// share buckets。
    func testTwoDifferentInputsCanProduceSamePrediction() throws {
        let adapter = try BASContextClassifierMLAdapter()
        // Both are "task" semantically; should classify
        // similarly even though wording differs
        let (labelA, _, _) = try adapter.classify(
            text: "compile the swift package")
        let (labelB, _, _) = try adapter.classify(
            text: "compile the swift package now")
        // Both should be "task" (semantic class)
        XCTAssertEqual(labelA, "task")
        XCTAssertEqual(labelB, "task")
        // Even though inputs differ → labels can match
        // (this is fine — it's a classifier, not an
        // identity function)
    }
}
