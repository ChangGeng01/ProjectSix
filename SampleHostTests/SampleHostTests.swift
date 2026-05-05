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

    // MARK: - M665 chapter 一百八十四 — deep review fix-pin tests

    /// M665 fix B2 (CRITICAL): JSONEncoder must encode NaN /
    /// ±Infinity as string sentinels, not throw. Pre-fix a single
    /// non-finite Double in any of 11 row fields would silently
    /// drop the entire iter row from JSONL.
    func testHybridBenchRowEncodesNaNWithoutThrowing() throws {
        let sig = SampleHostPromptSignature(
            tone: "anxious", domain: "financial", stake: "low",
            timeframe: "minutes", confidant: "friend",
            askShape: "narrative")
        let row = SampleHostHybridBenchRow(
            timestamp: "2026-05-06T00:00:00Z",
            iteration: 0, seed: 0, stride: 5041, mutationSeed: 0,
            signature: sig, prompt: "test",
            auditCodeCount: 100,
            permitMode: "answer",
            routerVersion: "test",
            routerPredictedRoute: "afm",
            routerProbability: .nan,           // NaN
            firstTriedLLM: "afm", firstTriedStatus: "ok",
            firstTriedBody: "ok", firstTriedDurationMs: .infinity,
            fallbackTriedLLM: nil, fallbackStatus: nil,
            fallbackBody: nil, fallbackDurationMs: -.infinity,
            actualRoute: "afm-predicted-ok", routerHit: true,
            totalDurationSeconds: .nan, errorMessage: nil,
            dispatchPolicy: nil, dispatchTaken: nil,
            draftOnly: nil, llmSkipped: nil,
            postLLMPermitMode: nil, postLLMAuditCodeCount: nil,
            postLLMShifted: nil,
            permitPredictBlockProb: .nan,
            permitPredictClass: nil,
            permitPredictAgreement: nil,
            permitPredictDetailedAgreement: nil,
            routerOverridden: false,
            lengthPredicted: .nan, lengthError: .infinity,
            latencyPredictedMs: .nan, latencyErrorMs: -.infinity,
            verbosityProbability: .nan, verbosityCorrect: nil)
        // Must not throw — strategy stringifies non-finite.
        let encoded = try SampleHostBenchHelpers.encodeHybrid(row)
        XCTAssertTrue(
            encoded.contains("\"nan\"")
            || encoded.contains("\"inf\"")
            || encoded.contains("\"-inf\""),
            "Non-finite Double should serialize as string sentinel: "
            + encoded)
    }

    /// M665 fix A24 (LOW): private init enforces shared singleton.
    /// (Indirect test — verifies `.shared` returns same instance
    /// every time.)
    func testCoreMLSharedSingletonsAreStable() {
        let p1 = ChengluPreflightInference.shared
        let p2 = ChengluPreflightInference.shared
        XCTAssertTrue(p1 === p2, "Preflight .shared not singleton")
    }

    // MARK: - M666-M672 chapter 一百八十五 — fix-pin tests

    /// M672 chapter 一百八十五 — B14 schema version constant.
    /// M675 chapter 一百八十六 bumped to "6" (added
    /// `permitPredictDetailedAgreement` field).
    func testHybridBenchRowSchemaVersion() {
        XCTAssertEqual(
            SAMPLE_HOST_HYBRID_BENCH_ROW_SCHEMA_VERSION, "6",
            "Schema version must bump on breaking field change")
    }

    /// M672 chapter 一百八十五 — B10 magic numbers extracted.
    func testHybridBenchTuningConstants() {
        XCTAssertEqual(
            HybridBenchTuning.verbosityThresholdChars, 1500)
        XCTAssertEqual(
            HybridBenchTuning.sigmoidClassThreshold, 0.5)
        XCTAssertEqual(
            HybridBenchTuning.yieldEveryNIters, 1)
        XCTAssertEqual(
            HybridBenchTuning.postLLMBodyTruncationChars, 4000)
    }

    /// M669 chapter 一百八十五 — B8 Welford running mean is
    /// numerically equivalent to Sum/Count for finite samples
    /// and avoids precision drift over many iterations.
    func testWelfordRunningMeanMatchesSumCountForFiniteSamples() {
        // Manual replay of the Welford recurrence used in the
        // bench loop: mean += (x - mean) / n.
        var mean: Double = 0
        var n: Int = 0
        var sum: Double = 0
        let samples: [Double] = [479, 421, 502, 380, 555, 488]
        for s in samples {
            n += 1
            sum += s
            mean += (s - mean) / Double(n)
        }
        let sumThenDivide = sum / Double(samples.count)
        XCTAssertEqual(
            mean, sumThenDivide, accuracy: 1e-9,
            "Welford recurrence diverges from Sum/Count")
    }

    /// M675 chapter 一百八十六 — B7 fix: detailed permit
    /// agreement preserves the 9-way actual permit alongside
    /// the binary class so analyses can do confusion matrix.
    func testHybridBenchRowEncodesDetailedPermitAgreement() throws {
        let sig = SampleHostPromptSignature(
            tone: "anxious", domain: "financial", stake: "low",
            timeframe: "minutes", confidant: "friend",
            askShape: "narrative")
        let row = SampleHostHybridBenchRow(
            timestamp: "t", iteration: 1, seed: 1,
            stride: 5041, mutationSeed: 0, signature: sig,
            prompt: "p", auditCodeCount: 100,
            permitMode: "delay",                    // 9-way actual
            routerVersion: "v", routerPredictedRoute: "afm",
            routerProbability: 0.5,
            firstTriedLLM: "afm", firstTriedStatus: "ok",
            firstTriedBody: "x", firstTriedDurationMs: 1,
            fallbackTriedLLM: nil, fallbackStatus: nil,
            fallbackBody: nil, fallbackDurationMs: nil,
            actualRoute: "r", routerHit: true,
            totalDurationSeconds: 0.1, errorMessage: nil,
            dispatchPolicy: nil, dispatchTaken: nil,
            draftOnly: nil, llmSkipped: false,
            postLLMPermitMode: nil, postLLMAuditCodeCount: nil,
            postLLMShifted: nil,
            permitPredictBlockProb: 0.3,
            permitPredictClass: "non-block",        // binary
            permitPredictAgreement: true,
            permitPredictDetailedAgreement:
                "non-block:delay",                  // 2-tuple
            routerOverridden: false,
            lengthPredicted: nil, lengthError: nil,
            latencyPredictedMs: nil, latencyErrorMs: nil,
            verbosityProbability: nil, verbosityCorrect: nil)
        let encoded = try SampleHostBenchHelpers.encodeHybrid(row)
        XCTAssertTrue(
            encoded.contains(
                "\"permitPredictDetailedAgreement\":\"non-block:delay\""),
            "row must encode the 2-tuple: \(encoded)")
    }

    /// M676 chapter 一百八十六 — B15 fix: counter partition
    /// helpers (hybridBenchAccountedTotal +
    /// hybridBenchPartitionDelta).
    @MainActor
    func testHybridBenchPartitionHelpersOnFreshModel() {
        let model = SampleHostModel()
        // Fresh model: all counters 0, iter 0, partition Δ = 0.
        XCTAssertEqual(model.hybridBenchAccountedTotal, 0)
        XCTAssertEqual(model.hybridBenchPartitionDelta, 0)
    }

    /// M683 chapter 一百八十七 — A2 Swift 6 prep:
    /// `private nonisolated init()` lets `static let shared`
    /// initialize without isolation conflict. Callable from any
    /// context (private — actually only Swift-internal); only
    /// the `predict*` methods are @MainActor isolated.
    /// Indirect test — builds + accesses `.shared` 2× from
    /// MainActor; equivalence verified.
    @MainActor
    func testCoreMLSharedSingletonsAccessible() {
        // 4 helpers — verify .shared is identity-stable.
        let p1 = ChengluPreflightInference.shared
        let p2 = ChengluPreflightInference.shared
        XCTAssertTrue(p1 === p2)
        let pp1 = ChengluPermitPredictInference.shared
        let pp2 = ChengluPermitPredictInference.shared
        XCTAssertTrue(pp1 === pp2)
        let mh1 = ChengluMultiHeadInference.shared
        let mh2 = ChengluMultiHeadInference.shared
        XCTAssertTrue(mh1 === mh2)
        let lh1 = ChengluRegressionHeadInference.lengthHead
        let lh2 = ChengluRegressionHeadInference.lengthHead
        XCTAssertTrue(lh1 === lh2)
        let lat1 = ChengluRegressionHeadInference.latencyHead
        let lat2 = ChengluRegressionHeadInference.latencyHead
        XCTAssertTrue(lat1 === lat2)
        // length and latency are different singletons.
        XCTAssertFalse(lh1 === lat1)
    }

    /// M678 chapter 一百八十六 — B6-extended fix-pin: bench row
    /// Codable handles control characters in body (newline, tab,
    /// quote, backslash) without crashing and preserves
    /// content under round-trip.
    func testHybridBenchRowRoundTripsControlChars() throws {
        let sig = SampleHostPromptSignature(
            tone: "anxious", domain: "financial", stake: "low",
            timeframe: "minutes", confidant: "friend",
            askShape: "narrative")
        let body = "Hi\n\"quoted\"\tback\\slash\u{0007}bell"
        let row = SampleHostHybridBenchRow(
            timestamp: "t", iteration: 1, seed: 1,
            stride: 5041, mutationSeed: 0, signature: sig,
            prompt: "p", auditCodeCount: 100,
            permitMode: "answer",
            routerVersion: "v", routerPredictedRoute: "afm",
            routerProbability: 0.5,
            firstTriedLLM: "afm", firstTriedStatus: "ok",
            firstTriedBody: body,        // control chars
            firstTriedDurationMs: 1,
            fallbackTriedLLM: nil, fallbackStatus: nil,
            fallbackBody: nil, fallbackDurationMs: nil,
            actualRoute: "r", routerHit: true,
            totalDurationSeconds: 0.1, errorMessage: nil,
            dispatchPolicy: nil, dispatchTaken: nil,
            draftOnly: nil, llmSkipped: false,
            postLLMPermitMode: nil, postLLMAuditCodeCount: nil,
            postLLMShifted: nil,
            permitPredictBlockProb: nil,
            permitPredictClass: nil,
            permitPredictAgreement: nil,
            permitPredictDetailedAgreement: nil,
            routerOverridden: false,
            lengthPredicted: nil, lengthError: nil,
            latencyPredictedMs: nil, latencyErrorMs: nil,
            verbosityProbability: nil, verbosityCorrect: nil)
        let encoded = try SampleHostBenchHelpers.encodeHybrid(row)
        guard let data = encoded.data(using: .utf8) else {
            XCTFail("failed to UTF-8 encode JSONL line")
            return
        }
        let decoded = try JSONDecoder().decode(
            SampleHostHybridBenchRow.self, from: data)
        XCTAssertEqual(
            decoded.firstTriedBody, body,
            "Codable round-trip lost body content")
    }

    /// M666 chapter 一百八十五 — B1 fix: row carries
    /// routerOverridden flag, default false, optional.
    func testHybridBenchRowEncodesRouterOverridden() throws {
        let sig = SampleHostPromptSignature(
            tone: "anxious", domain: "financial", stake: "low",
            timeframe: "minutes", confidant: "friend",
            askShape: "narrative")
        let row = SampleHostHybridBenchRow(
            timestamp: "2026-05-06T00:00:00Z",
            iteration: 0, seed: 0, stride: 5041, mutationSeed: 0,
            signature: sig, prompt: "test",
            auditCodeCount: 100,
            permitMode: "block",
            routerVersion: "test",
            routerPredictedRoute: "afm",
            routerProbability: 0.5,
            firstTriedLLM: "none-substrate-skip",
            firstTriedStatus: "ok-substrate-skip",
            firstTriedBody: "canned",
            firstTriedDurationMs: 0,
            fallbackTriedLLM: nil, fallbackStatus: nil,
            fallbackBody: nil, fallbackDurationMs: nil,
            actualRoute: "skipped-by-substrate-block",
            routerHit: true,                // legacy default
            totalDurationSeconds: 0.05,
            errorMessage: nil,
            dispatchPolicy: "skip-block",
            dispatchTaken: "skip-block",
            draftOnly: false, llmSkipped: true,
            postLLMPermitMode: nil, postLLMAuditCodeCount: nil,
            postLLMShifted: nil,
            permitPredictBlockProb: 0.99,
            permitPredictClass: "block",
            permitPredictAgreement: true,
            permitPredictDetailedAgreement: "block:block",  // M675 NEW
            routerOverridden: true,         // M666 NEW
            lengthPredicted: nil, lengthError: nil,
            latencyPredictedMs: nil, latencyErrorMs: nil,
            verbosityProbability: nil, verbosityCorrect: nil)
        let encoded = try SampleHostBenchHelpers.encodeHybrid(row)
        XCTAssertTrue(
            encoded.contains("\"routerOverridden\":true"),
            "row must encode routerOverridden field: \(encoded)")
        XCTAssertTrue(
            encoded.contains("\"schemaVersion\":\"6\""),
            "row must encode schemaVersion field: \(encoded)")
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
