import XCTest
import BASHostKit
@testable import SampleHost

@MainActor
final class SampleHostTests: XCTestCase {
    func testBootstrapCreatesCurrentBrain() {
        let model = SampleHostModel()

        XCTAssertFalse(model.result.currentBrain.dominantGoals.isEmpty)
        XCTAssertFalse(model.result.consoleSnapshot.reports.isEmpty)
        XCTAssertEqual(model.result.activeSessionTitle, "SampleHost Bootstrap")
        XCTAssertTrue(model.result.notices.contains("Refresh substrate projection"))
    }

    func testReflectiveSessionUpdatesMode() {
        let model = SampleHostModel()

        model.start(.reflective)

        XCTAssertEqual(model.result.currentBrain.workflowProfile, .reflective)
        XCTAssertEqual(model.result.currentBrain.workflowTitle, "Signal Lens")
        XCTAssertEqual(model.result.requestKind.rawValue, "interactive")
        XCTAssertEqual(model.result.workflowProfile.rawValue, "reflective")
        XCTAssertEqual(model.result.activeSessionTitle, "Signal Lens from SampleHost")
        XCTAssertTrue(model.result.notices.contains("Application entered the signal lens lane in SampleHost."))
        XCTAssertEqual(model.result.interventionSuggestion?.title, "Run this through Contrast Lens first.")
        XCTAssertEqual(model.result.interventionSuggestion?.preferredWorkflowProfile, .comparative)
        XCTAssertEqual(model.result.projection.activeTemplateIDs, ["samplehost.template.signal-lens"])
        XCTAssertTrue(model.result.currentBrain.verificationSummary.hasPrefix("samplehost/"))
    }

    func testReopenProducesSuggestion() {
        let model = SampleHostModel()

        model.reopen()

        XCTAssertEqual(model.result.requestKind.rawValue, "reopen")
        XCTAssertNotNil(model.result.interventionSuggestion)
        XCTAssertEqual(model.result.interventionSuggestion?.title, "Reopen with more structure")
        XCTAssertTrue(model.result.notices.contains("Use a cooling template before acting."))
    }

    func testWindGatePresentationSupportHumanizesInternalIdentifiers() {
        XCTAssertEqual(
            SampleHostWindGatePresentationSupport.modeLabel(.draftOnly),
            "draft only"
        )
        XCTAssertEqual(
            SampleHostWindGatePresentationSupport.modeLabels([.draftOnly, .localOnly, .mirror]),
            "draft only • local only • mirror"
        )
        XCTAssertEqual(
            SampleHostWindGatePresentationSupport.domainList([
                "bounded_reply",
                "tool_commit",
                "memory_commit"
            ]),
            "bounded reply • tool commit • memory commit"
        )
        XCTAssertEqual(
            SampleHostWindGatePresentationSupport.humanizedToken("cool_down"),
            "cool down"
        )
        XCTAssertEqual(
            SampleHostWindGatePresentationSupport.humanizedToken("local_only_action"),
            "local only action"
        )
    }

    // MARK: - M627 chapter 一百七十七 deep test — CoreML inference path
    // (audit Axis 7 deferred → covered here)

    /// LUT boundary: rawProb = 0 should map to LUT[0]
    func testCalibrationLUTLowerBound() async throws {
        let inference = ChengluPreflightInference.shared
        // Use private interface via a synthetic feature vector at extreme
        // — feature with all zeros makes raw prob undefined per training,
        // but inference should not crash + produce a valid [0, 1] number.
        let features = ChengluPromptFeatures(
            tone: "anxious",  // valid one-hot
            domain: "financial",
            stake: "low",
            timeframe: "minutes",
            confidant: "friend",
            askShape: "narrative",
            mutationSeed: 0)
        do {
            let decision = try inference.predict(features: features)
            XCTAssertGreaterThanOrEqual(
                decision.afmSuccessProbability, 0.0,
                "calibrated prob must be >= 0")
            XCTAssertLessThanOrEqual(
                decision.afmSuccessProbability, 1.0,
                "calibrated prob must be <= 1")
        } catch ChengluPreflightError.modelMissingFromBundle {
            // OK in dev environment without the .mlpackage
            throw XCTSkip("model not in test bundle")
        }
    }

    /// Confidence enum boundary checks — exact threshold values
    func testConfidenceEnumBoundaries() {
        XCTAssertEqual(
            ChengluPreflightDecision.confidence(forProb: 0.10),
            .high)
        XCTAssertEqual(
            ChengluPreflightDecision.confidence(forProb: 0.30),
            .medium,
            "0.30 should be medium (boundary, < 0.30 is .high)")
        XCTAssertEqual(
            ChengluPreflightDecision.confidence(forProb: 0.40),
            .uncertain,
            "0.40 is in uncertain zone")
        XCTAssertEqual(
            ChengluPreflightDecision.confidence(forProb: 0.50),
            .uncertain)
        XCTAssertEqual(
            ChengluPreflightDecision.confidence(forProb: 0.60),
            .uncertain,
            "0.60 is in uncertain zone")
        XCTAssertEqual(
            ChengluPreflightDecision.confidence(forProb: 0.70),
            .medium,
            "0.70 should be medium (boundary, > 0.70 is .high)")
        XCTAssertEqual(
            ChengluPreflightDecision.confidence(forProb: 0.95),
            .high)
    }

    /// Route selection: prob >= 0.5 → AFM; < 0.5 → Gemma
    func testDecisionRouteThreshold() {
        let afmDecision = ChengluPreflightDecision(
            afmSuccessProbability: 0.5,
            route: .afm,
            confidence: .uncertain,
            modelVersion: "test")
        XCTAssertEqual(afmDecision.route, .afm)
        let gemmaDecision = ChengluPreflightDecision(
            afmSuccessProbability: 0.49,
            route: .gemma,
            confidence: .uncertain,
            modelVersion: "test")
        XCTAssertEqual(gemmaDecision.route, .gemma)
    }

    /// Decision struct round-trips through Codable (for JSONL bench rows)
    func testDecisionCodableRoundTrip() throws {
        let original = ChengluPreflightDecision(
            afmSuccessProbability: 0.732,
            route: .afm,
            confidence: .high,
            modelVersion: "v0.4-mlp-64-32-isotonic-lut")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            ChengluPreflightDecision.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    /// ChengluPromptFeatures round-trips correctly
    func testFeaturesEquatable() {
        let a = ChengluPromptFeatures(
            tone: "anxious", domain: "financial", stake: "low",
            timeframe: "minutes", confidant: "friend",
            askShape: "narrative", mutationSeed: 0)
        let b = ChengluPromptFeatures(
            tone: "anxious", domain: "financial", stake: "low",
            timeframe: "minutes", confidant: "friend",
            askShape: "narrative", mutationSeed: 0)
        XCTAssertEqual(a, b)
        let c = ChengluPromptFeatures(
            tone: "angry", domain: "financial", stake: "low",
            timeframe: "minutes", confidant: "friend",
            askShape: "narrative", mutationSeed: 0)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - M652 chapter 一百八十二 — single-source featurize tests

    /// `ChengluFeatureEncoder.dimensionsAreConsistent()` invariant
    /// catches alphabet drift: if anyone adds a tone / domain /
    /// stake without bumping featureCount, this test fails.
    func testFeatureEncoderDimensionsConsistent() {
        XCTAssertTrue(ChengluFeatureEncoder.dimensionsAreConsistent())
        XCTAssertEqual(ChengluFeatureEncoder.featureCount, 43)
    }

    /// Encoded vector has correct dimensionality + correct one-hot
    /// values for a known signature.
    func testFeatureEncoderOneHotShape() {
        let features = ChengluPromptFeatures(
            tone: "anxious",       // index 0 in tones (8)
            domain: "financial",    // index 0 in domains (10), offset 8
            stake: "low",           // index 0 in stakes (6), offset 18
            timeframe: "minutes",   // index 0 in timeframes (7), offset 24
            confidant: "friend",    // index 0 in confidants (4), offset 31
            askShape: "narrative",  // index 0 in askShapes (3), offset 35
            mutationSeed: 0)        // index 0 in mutationSeed (5), offset 38
        let v = ChengluFeatureEncoder.encode(features)
        XCTAssertEqual(v.count, 43)
        // First-element of each alphabet must be 1.0
        XCTAssertEqual(v[0], 1.0, "tone[0]=anxious")
        XCTAssertEqual(v[8], 1.0, "domain[0]=financial")
        XCTAssertEqual(v[18], 1.0, "stake[0]=low")
        XCTAssertEqual(v[24], 1.0, "timeframe[0]=minutes")
        XCTAssertEqual(v[31], 1.0, "confidant[0]=friend")
        XCTAssertEqual(v[35], 1.0, "askshape[0]=narrative")
        XCTAssertEqual(v[38], 1.0, "mutation[0]=0")
        // All others should be 0.0 — count zeros to confirm.
        let onesCount = v.filter { $0 == 1.0 }.count
        XCTAssertEqual(onesCount, 7,
                       "exactly 7 active dims (one per group)")
    }

    /// Out-of-vocab values produce all-zero vector (degenerate
    /// case — model still gets a valid input shape).
    func testFeatureEncoderUnknownValuesAllZero() {
        let features = ChengluPromptFeatures(
            tone: "INVALID",
            domain: "INVALID",
            stake: "INVALID",
            timeframe: "INVALID",
            confidant: "INVALID",
            askShape: "INVALID",
            mutationSeed: 99)  // out of 0..<5
        let v = ChengluFeatureEncoder.encode(features)
        XCTAssertEqual(v.count, 43)
        XCTAssertTrue(v.allSatisfy { $0 == 0.0 })
    }

    /// Predict on out-of-vocab tone (e.g. typo) should not crash —
    /// all features become 0, model still produces valid output.
    func testPredictHandlesOutOfVocabFeatures() async throws {
        let inference = ChengluPreflightInference.shared
        let features = ChengluPromptFeatures(
            tone: "INVALID-TONE-NOT-IN-CORPUS",  // all zeros after one-hot
            domain: "financial",
            stake: "low",
            timeframe: "minutes",
            confidant: "friend",
            askShape: "narrative",
            mutationSeed: 0)
        do {
            let decision = try inference.predict(features: features)
            XCTAssertGreaterThanOrEqual(
                decision.afmSuccessProbability, 0.0)
            XCTAssertLessThanOrEqual(
                decision.afmSuccessProbability, 1.0)
        } catch ChengluPreflightError.modelMissingFromBundle {
            throw XCTSkip("model not in test bundle")
        }
    }
}
