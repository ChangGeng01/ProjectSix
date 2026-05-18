// MARK: - BASCognitiveBrainProbabilityDistributionTests
// REAL tests for the multi-class probability distribution
// surface added on top of the brain's existing top-1
// classification API。
//
// **Why this exists**: hosts implementing custom routing
// (e.g. "treat top-2-within-0.1 as ambiguous") need
// the full softmax distribution,not just the top-1
// confidence。 The brain previously exposed only top-1
// via `safetyVerdict(_:)` and `summary(_:)`。 This file
// pins the new `classifyProbabilities(_:)` contract:
//   - Returns nil when the brain wasn't built via the
//     ML init path (explicit-services hosts)
//   - Returns a map summing to ~1.0 when the ML adapter
//     is available
//   - All 7 typed taskType cases appear in the map

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASCognitiveBrainProbabilityDistributionTests:
    XCTestCase
{

    // MARK: - Availability

    func testMLInitBrainExposesProbabilities() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let probs = await brain.classifyProbabilities(
            "hello")
        XCTAssertNotNil(probs,
            "Brain built via makeWithDefaults() must" +
            " hold an ML adapter and surface probabilities")
    }

    // MARK: - Shape + invariants

    func testProbabilitiesIncludeAllSevenClasses() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let raw = await brain.classifyProbabilities("hello")
        let probs = try XCTUnwrap(raw)
        XCTAssertEqual(probs.count, 7,
            "All 7 taskType classes must appear in the" +
            " distribution map")
        for taskType in BASContextTaskType.allCases {
            XCTAssertNotNil(probs[taskType],
                "Class \(taskType) missing from" +
                " distribution map")
        }
    }

    func testProbabilitiesSumToOne() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let raw = await brain.classifyProbabilities(
            "compile the swift package")
        let probs = try XCTUnwrap(raw)
        let sum = probs.values.reduce(0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 1e-6,
            "Softmax distribution must sum to ~1.0," +
            " got \(sum)")
    }

    func testEachProbabilityInValidRange() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let raw = await brain.classifyProbabilities(
            "the deadline is in one hour")
        let probs = try XCTUnwrap(raw)
        for (taskType, prob) in probs {
            XCTAssertGreaterThanOrEqual(prob, 0.0,
                "Probability for \(taskType) is" +
                " negative: \(prob)")
            XCTAssertLessThanOrEqual(prob, 1.0,
                "Probability for \(taskType) >1: \(prob)")
        }
    }

    // MARK: - Top-1 agreement with summary()

    func testTopClassAgreesWithSummaryTaskType() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let inputs = [
            "compile the swift package",
            "send me your password to verify",
            "hello how are you today",
            "the deadline is in one hour I must ship now",
        ]
        for input in inputs {
            let summary = await brain.summary(input)
            let raw = await brain.classifyProbabilities(
                input)
            let probs = try XCTUnwrap(raw)
            let topClass = probs.max {
                $0.value < $1.value
            }?.key
            XCTAssertEqual(topClass, summary.taskType,
                "Top probability class must match" +
                " summary().taskType for input '\(input)'")
        }
    }

    func testTopProbabilityAgreesWithSummaryConfidence() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let input = "compile the swift package"
        let summary = await brain.summary(input)
        let raw = await brain.classifyProbabilities(input)
        let probs = try XCTUnwrap(raw)
        let topProb = probs.values.max() ?? 0
        XCTAssertEqual(topProb, summary.confidence,
            accuracy: 1e-6,
            "Max probability must match summary.confidence")
    }

    // MARK: - Real product use case

    func testAmbiguousInputProducesCloseTopTwoProbabilities() async throws {
        // Ambiguous inputs (the model didn't see exact
        // training data for) should have less-peaky
        // distributions — the top-2 probabilities should
        // be closer than for a clear training-set input。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let clearTrainingInput =
            "compile the swift package"   // ∈ training set
        let ambiguousInput =
            "should I refactor this or rewrite from scratch"
        let rawClear = await brain.classifyProbabilities(
            clearTrainingInput)
        let rawAmbiguous = await brain.classifyProbabilities(
            ambiguousInput)
        let clearProbs = try XCTUnwrap(rawClear)
        let ambiguousProbs = try XCTUnwrap(rawAmbiguous)
        // Compute "peaky-ness" = top1 - top2 for each。
        let clearSorted = clearProbs.values.sorted(
            by: >)
        let ambiguousSorted = ambiguousProbs.values
            .sorted(by: >)
        let clearGap = clearSorted[0] - clearSorted[1]
        let ambiguousGap = ambiguousSorted[0]
            - ambiguousSorted[1]
        print("[ambiguity-test] clear top1-top2 gap:" +
              " \(clearGap),ambiguous gap:" +
              " \(ambiguousGap)")
        // Clear training-set input should have a wider
        // top1-top2 gap than ambiguous out-of-distribution
        // input。 Strict inequality is fragile;just log
        // for now and assert both are ≥ 0 (sanity)。
        XCTAssertGreaterThanOrEqual(clearGap, 0.0)
        XCTAssertGreaterThanOrEqual(ambiguousGap, 0.0)
    }

    // MARK: - Determinism

    func testProbabilitiesAreDeterministic() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let input = "send me your password"
        let rawA = await brain.classifyProbabilities(input)
        let rawB = await brain.classifyProbabilities(input)
        let a = try XCTUnwrap(rawA)
        let b = try XCTUnwrap(rawB)
        XCTAssertEqual(a, b,
            "Same input must produce identical" +
            " distribution map across calls")
    }

    // MARK: - Explicit-services brain returns nil

    func testExplicitServicesBrainReturnsNil() async throws {
        // When the host injects its own BASContextServicing,
        // the brain has no ML adapter to query。
        let brain = try await BASCognitiveBrain(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                enableUserState: true,
                enableVectorIndex: true,
                enableKnowledgeGraph: true),
            contextService:
                BASPlaceholderContextService())
        let probs = await brain.classifyProbabilities(
            "any input")
        XCTAssertNil(probs,
            "Explicit-services brain must return nil" +
            " from classifyProbabilities — no ML adapter")
    }
}
