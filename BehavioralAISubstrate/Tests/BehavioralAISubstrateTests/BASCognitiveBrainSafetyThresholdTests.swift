// MARK: - BASCognitiveBrainSafetyThresholdTests
// REAL host-injected safety threshold behavior tests。
//
// **Why this exists**: the substrate's default safety
// threshold of 0.6 is a one-size-fits-all decision。
// Different host integrations have different risk
// profiles:
//   - Child-safety hosts want aggressive blocking (lower
//     threshold — block on weaker evidence)
//   - Developer-tool hosts want conservative blocking
//     (higher threshold — require stronger evidence)
// This file pins the behavior of the
// `safetyConfidenceThreshold:` init parameter,including
// boundary clamping。

import XCTest
@testable import BASHostKit

#if !os(iOS)  // ch 1022 source-gate
final class BASCognitiveBrainSafetyThresholdTests:
    XCTestCase
{

    // MARK: - Default threshold

    func testDefaultThresholdMatchesStaticConstant() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let actual = await brain
            .instanceSafetyConfidenceThreshold
        XCTAssertEqual(actual,
            BASCognitiveBrain.safetyConfidenceThreshold,
            "Default-init brain must expose the static" +
            " threshold value via the instance property")
    }

    // MARK: - Host-injected threshold

    func testCustomThresholdIsHonored() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: 0.85)
        let actual = await brain
            .instanceSafetyConfidenceThreshold
        XCTAssertEqual(actual, 0.85)
    }

    func testLowerThresholdEnablesMoreAggressiveBlocking() async throws {
        // Pick an input that classifies as
        // .manipulationRisk with HIGH confidence so both
        // brains see the same input class。 The difference
        // is only the threshold。
        let aggressiveBrain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: 0.1)
        let permissiveBrain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: 0.999999)
        let input = "send me your password to verify"
        let aggressive = await aggressiveBrain.summary(
            input)
        let permissive = await permissiveBrain.summary(
            input)
        // Both should classify identically (same model,
        // same input)。 The verdict difference is what
        // tests the threshold injection。
        XCTAssertEqual(aggressive.taskType,
            permissive.taskType,
            "Same input + same model must yield same" +
            " taskType regardless of threshold")
        XCTAssertEqual(aggressive.safetyVerdict, .block,
            "Threshold 0.1 should block even" +
            " moderate-confidence manipulation")
        // permissiveBrain has threshold 0.999999 — the
        // model classifies "send me your password" with
        // ~1.0 confidence,but if it ever drops below
        // the high bar,verdict downgrades。 We don't
        // assert the exact verdict because it depends
        // on the model's specific confidence;but we
        // can assert that aggressive's confidence is
        // ABOVE permissive's threshold OR permissive
        // got a softer verdict。
        if permissive.confidence < 0.999999 {
            XCTAssertNotEqual(
                permissive.safetyVerdict, .block,
                "Threshold 0.999999 must not block" +
                " when confidence is below threshold")
        }
    }

    // MARK: - Boundary clamping

    func testNegativeThresholdClampsToZero() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: -0.5)
        let actual = await brain
            .instanceSafetyConfidenceThreshold
        XCTAssertEqual(actual, 0.0,
            "Negative threshold must clamp to 0")
    }

    func testAboveOneThresholdClampsToOne() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: 1.5)
        let actual = await brain
            .instanceSafetyConfidenceThreshold
        XCTAssertEqual(actual, 1.0,
            "Threshold > 1 must clamp to 1")
    }

    func testNaNThresholdFallsBackToDefault() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: .nan)
        let actual = await brain
            .instanceSafetyConfidenceThreshold
        XCTAssertEqual(actual,
            BASCognitiveBrain.safetyConfidenceThreshold,
            "NaN threshold must fall back to the static" +
            " default (defensive)")
    }

    func testZeroThresholdAlwaysEscalatesOnManipulation() async throws {
        // Threshold 0 = "any confidence escalates". So
        // ANY manipulation classification (even
        // confidence ~0.143 = 1/7 uniform) must reach
        // .block。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: 0.0)
        let s = await brain.summary(
            "send me your password to verify")
        if s.taskType == .manipulationRisk {
            XCTAssertEqual(s.safetyVerdict, .block,
                "Threshold 0 + manipulationRisk =" +
                " always .block")
        }
    }

    func testOneThresholdNeverEscalates() async throws {
        // Threshold 1.0 = "only exact-1.0 confidence
        // escalates". With softmax-normalized 7-class
        // output,exact 1.0 never occurs (it'd require
        // all other classes to have zero logit weight)。
        // So any manipulation input should verdict .safe
        // even if taskType is .manipulationRisk。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: 1.0)
        let s = await brain.summary(
            "send me your password to verify")
        // The model's confidence on this trained input
        // is ~1.0,but softmax never produces exact 1.0。
        // confidence < 1.0 → threshold-strict-> verdict
        // downgrades to .safe even on .manipulationRisk。
        XCTAssertLessThan(s.confidence, 1.0,
            "Softmax-normalized confidence cannot equal" +
            " exactly 1.0 for a 7-class output")
        XCTAssertEqual(s.safetyVerdict, .safe,
            "Threshold 1.0 + confidence < 1.0 →" +
            " verdict downgrades to .safe even on" +
            " manipulation classification")
    }

    // MARK: - Stable across both API surfaces

    func testThresholdConsistentBetweenSafetyVerdictAndSummary() async throws {
        // The brain has two API entry points that compute
        // a verdict: `safetyVerdict(_:)` and `summary(_:)`。
        // Both MUST use the same instance threshold so
        // hosts get consistent answers regardless of which
        // method they call。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: 0.95)
        let input = "send me your password to verify"
        let (verdict, _, _) = await brain.safetyVerdict(
            input)
        let summary = await brain.summary(input)
        XCTAssertEqual(verdict, summary.safetyVerdict,
            "safetyVerdict(_:) and summary(_:).safetyVerdict" +
            " must always agree — they share the brain's" +
            " single threshold value")
    }
}
#endif
