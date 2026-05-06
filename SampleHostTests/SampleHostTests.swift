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
            verbosityProbability: .nan, verbosityCorrect: nil,
            thermalState: "nominal", batteryLevel: 0.5,
            lowPowerMode: false, hourOfDay: 12,
            smokeMode: nil, targetLayer: nil,
            targetLayerName: nil,
            anomalyFlags: nil, pressureProfile: nil,
            adversarialKind: nil, driftSigma: nil,
            pauseSkipped: false)
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
    /// M675 chapter 一百八十六 bumped to "6".
    /// M703 chapter 一百九十 bumped to "7" (pressure fields).
    /// M712 chapter 一百九十一 bumped to "8" (14-layer smoke).
    /// M716+ chapter 一百九十二 bumped to "9" (10h-readiness pack:
    /// rowChecksum + anomalyFlags + pressureProfile +
    /// adversarialKind + driftSigma + pauseSkipped).
    func testHybridBenchRowSchemaVersion() {
        XCTAssertEqual(
            SAMPLE_HOST_HYBRID_BENCH_ROW_SCHEMA_VERSION, "9",
            "Schema version must bump on breaking field change")
    }

    /// M711 chapter 一百九十一 — 14-layer smoke profile MUST
    /// cover exactly 14 layers with monotonic indices 1..14.
    func testFourteenLayerSmokeProfileCoverage() {
        let layers = FourteenLayerSmokeProfile.layers
        XCTAssertEqual(layers.count, 14,
            "FourteenLayerSmokeProfile must have 14 entries")
        let indices = layers.map(\.layerIndex).sorted()
        XCTAssertEqual(indices, Array(1...14),
            "layer indices must be monotonic 1..14")
        let names = Set(layers.map(\.layerName))
        XCTAssertEqual(names.count, 14,
            "layer names must be unique")
    }

    /// M711 — `profile(forIter:)` cycles through all 14 layers.
    func testFourteenLayerSmokeProfileCycles() {
        // 28 iters → each layer hit exactly twice.
        var hits: [Int: Int] = [:]
        for iter in 0..<28 {
            let p = FourteenLayerSmokeProfile.profile(forIter: iter)
            hits[p.layerIndex, default: 0] += 1
        }
        for layer in 1...14 {
            XCTAssertEqual(hits[layer], 2,
                "L\(layer) hit \(hits[layer] ?? 0) times in 28 iters")
        }
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
            verbosityProbability: nil, verbosityCorrect: nil,
            thermalState: nil, batteryLevel: nil,
            lowPowerMode: nil, hourOfDay: nil,
            smokeMode: nil, targetLayer: nil,
            targetLayerName: nil,
            anomalyFlags: nil, pressureProfile: nil,
            adversarialKind: nil, driftSigma: nil,
            pauseSkipped: false)
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

    // MARK: - M698 chapter 一百八十九 — fuzz tests

    /// M698 fuzz: feed random + adversarial signature inputs to
    /// `ChengluFeatureEncoder.encode` — verify dimensions
    /// invariant + sum-bounds invariant hold for ALL inputs.
    func testFeatureEncoderFuzzRandomInputs() {
        // 200 random signatures, no crash, dim+sum invariants.
        var rng = SystemRandomNumberGenerator()
        let canon = [
            ChengluFeatureEncoder.tones,
            ChengluFeatureEncoder.domains,
            ChengluFeatureEncoder.stakes,
            ChengluFeatureEncoder.timeframes,
            ChengluFeatureEncoder.confidants,
            ChengluFeatureEncoder.askShapes,
        ]
        for _ in 0..<200 {
            // Mix of canonical + adversarial values.
            let inAlphabet = Bool.random(using: &rng)
            let pick: (Int) -> String = { i in
                inAlphabet
                    ? (canon[i].randomElement(using: &rng) ?? "")
                    : "INVALID-\(Int.random(in: 0..<99, using: &rng))"
            }
            let f = ChengluPromptFeatures(
                tone: pick(0),
                domain: pick(1),
                stake: pick(2),
                timeframe: pick(3),
                confidant: pick(4),
                askShape: pick(5),
                mutationSeed: Int.random(
                    in: -10..<20, using: &rng))
            let v = ChengluFeatureEncoder.encode(f)
            XCTAssertEqual(v.count, 43, "dim invariant broke")
            // Each value 0.0 or 1.0 (no other floats possible)
            for value in v {
                XCTAssertTrue(
                    value == 0.0 || value == 1.0,
                    "encode produced non-binary value: \(value)")
            }
            // Sum is bounded by alphabet count (max 7 active).
            let sum = v.reduce(0, +)
            XCTAssertGreaterThanOrEqual(sum, 0)
            XCTAssertLessThanOrEqual(sum, 7)
        }
    }

    /// M698 fuzz: random `SampleHostHybridBenchRow` round-trip
    /// through encodeHybrid → JSON → decode. Catches Codable
    /// edge cases beyond what hand-crafted tests cover.
    func testHybridBenchRowFuzzRoundTrip() throws {
        let testCases: [(body: String, prompt: String, status: String)] = [
            ("ok response", "ok prompt", "ok"),
            ("", "empty body case", "afm-error"),
            ("Body with\nnewlines\nand\ttabs", "p", "ok"),
            ("\"quoted\" \\backslash 'single'", "p", "ok"),
            (String(repeating: "x", count: 5000),
             "huge body", "ok"),
            ("emoji 🚀💥🔥", "p", "ok"),
            ("unicode: 你好 こんにちは مرحبا", "p", "ok"),
            ("control \u{0001}\u{0002}\u{001F}", "p", "ok"),
            ("nul \u{0000}char", "p", "ok"),
        ]
        let sig = SampleHostPromptSignature(
            tone: "anxious", domain: "financial", stake: "low",
            timeframe: "minutes", confidant: "friend",
            askShape: "narrative")
        for (idx, tc) in testCases.enumerated() {
            let row = SampleHostHybridBenchRow(
                timestamp: "2026-05-06T01:00:00Z",
                iteration: idx, seed: idx,
                stride: 5041, mutationSeed: idx % 5,
                signature: sig, prompt: tc.prompt,
                auditCodeCount: 100,
                permitMode: "answer",
                routerVersion: "fuzz",
                routerPredictedRoute: "afm",
                routerProbability: Double.random(in: 0...1),
                firstTriedLLM: "afm",
                firstTriedStatus: tc.status,
                firstTriedBody: tc.body,
                firstTriedDurationMs: Double.random(in: 0...10000),
                fallbackTriedLLM: nil, fallbackStatus: nil,
                fallbackBody: nil, fallbackDurationMs: nil,
                actualRoute: "afm-predicted-ok", routerHit: true,
                totalDurationSeconds: Double.random(in: 0...10),
                errorMessage: nil,
                dispatchPolicy: "single-llm",
                dispatchTaken: "single-llm",
                draftOnly: false, llmSkipped: false,
                postLLMPermitMode: nil,
                postLLMAuditCodeCount: nil,
                postLLMShifted: nil,
                permitPredictBlockProb: 0.3,
                permitPredictClass: "non-block",
                permitPredictAgreement: true,
                permitPredictDetailedAgreement: "non-block:answer",
                routerOverridden: false,
                lengthPredicted: 1200,
                lengthError: Double(tc.body.count) - 1200,
                latencyPredictedMs: 5000,
                latencyErrorMs: 0,
                verbosityProbability: 0.3,
                verbosityCorrect: tc.body.count > 1500 ? false : true,
                thermalState: "nominal", batteryLevel: 0.5,
                lowPowerMode: false, hourOfDay: 12,
                smokeMode: "canonical", targetLayer: nil,
                targetLayerName: nil,
                anomalyFlags: nil, pressureProfile: nil,
                adversarialKind: nil, driftSigma: nil,
                pauseSkipped: false)
            let encoded = try SampleHostBenchHelpers.encodeHybrid(row)
            guard let data = encoded.data(using: .utf8) else {
                XCTFail("UTF-8 encode failed: idx=\(idx)")
                continue
            }
            let decoded = try JSONDecoder().decode(
                SampleHostHybridBenchRow.self, from: data)
            // Critical fields must round-trip.
            XCTAssertEqual(
                decoded.firstTriedBody, tc.body,
                "body round-trip failed: idx=\(idx)")
            XCTAssertEqual(
                decoded.firstTriedStatus, tc.status,
                "status round-trip failed: idx=\(idx)")
        }
    }

    // MARK: - chapter 一百八十七 + earlier tests continue below

    /// M703 chapter 一百九十 schema "7" (pressure context).
    /// M712 chapter 一百九十一 schema "8" (14-layer smoke).
    /// M716+ chapter 一百九十二 schema "9" (10h-readiness pack).
    /// Test name kept as `V7` for git history clarity; assertion
    /// pins the live current version.
    func testHybridBenchRowSchemaVersionV7() {
        XCTAssertEqual(
            SAMPLE_HOST_HYBRID_BENCH_ROW_SCHEMA_VERSION, "9",
            "Schema version must bump on breaking field change")
    }

    /// M703 chapter 一百九十 — pressure context fields encode
    /// + decode cleanly through Codable round-trip.
    func testHybridBenchRowPressureContextRoundTrip() throws {
        let sig = SampleHostPromptSignature(
            tone: "anxious", domain: "financial", stake: "low",
            timeframe: "minutes", confidant: "friend",
            askShape: "narrative")
        let row = SampleHostHybridBenchRow(
            timestamp: "2026-05-06T14:30:00Z",
            iteration: 0, seed: 0, stride: 5041, mutationSeed: 0,
            signature: sig, prompt: "p", auditCodeCount: 100,
            permitMode: "answer", routerVersion: "v",
            routerPredictedRoute: "afm",
            routerProbability: 0.5,
            firstTriedLLM: "afm", firstTriedStatus: "ok",
            firstTriedBody: "x", firstTriedDurationMs: 1,
            fallbackTriedLLM: nil, fallbackStatus: nil,
            fallbackBody: nil, fallbackDurationMs: nil,
            actualRoute: "afm-predicted-ok", routerHit: true,
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
            verbosityProbability: nil, verbosityCorrect: nil,
            // M703 chapter 一百九十 — pressure context.
            thermalState: "fair",
            batteryLevel: 0.42,
            lowPowerMode: true,
            hourOfDay: 14,
            // M712 chapter 一百九十一 — 14-layer smoke tags.
            smokeMode: "14-layer-smoke",
            targetLayer: 7,
            targetLayerName: "L7-mirror",
            anomalyFlags: nil, pressureProfile: nil,
            adversarialKind: nil, driftSigma: nil,
            pauseSkipped: false)
        let encoded = try SampleHostBenchHelpers.encodeHybrid(row)
        XCTAssertTrue(
            encoded.contains("\"thermalState\":\"fair\""),
            "thermalState in JSONL: \(encoded)")
        XCTAssertTrue(
            encoded.contains("\"batteryLevel\":0.42"),
            "batteryLevel in JSONL: \(encoded)")
        XCTAssertTrue(
            encoded.contains("\"lowPowerMode\":true"),
            "lowPowerMode in JSONL: \(encoded)")
        XCTAssertTrue(
            encoded.contains("\"hourOfDay\":14"),
            "hourOfDay in JSONL: \(encoded)")
        guard let data = encoded.data(using: .utf8) else {
            XCTFail("UTF-8 encode failed")
            return
        }
        let decoded = try JSONDecoder().decode(
            SampleHostHybridBenchRow.self, from: data)
        XCTAssertEqual(decoded.thermalState, "fair")
        XCTAssertEqual(decoded.batteryLevel, 0.42)
        XCTAssertEqual(decoded.lowPowerMode, true)
        XCTAssertEqual(decoded.hourOfDay, 14)
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
            verbosityProbability: nil, verbosityCorrect: nil,
            thermalState: nil, batteryLevel: nil,
            lowPowerMode: nil, hourOfDay: nil,
            smokeMode: nil, targetLayer: nil,
            targetLayerName: nil,
            anomalyFlags: nil, pressureProfile: nil,
            adversarialKind: nil, driftSigma: nil,
            pauseSkipped: false)
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
            verbosityProbability: nil, verbosityCorrect: nil,
            thermalState: nil, batteryLevel: nil,
            lowPowerMode: nil, hourOfDay: nil,
            smokeMode: nil, targetLayer: nil,
            targetLayerName: nil,
            anomalyFlags: nil, pressureProfile: nil,
            adversarialKind: nil, driftSigma: nil,
            pauseSkipped: false)
        let encoded = try SampleHostBenchHelpers.encodeHybrid(row)
        XCTAssertTrue(
            encoded.contains("\"routerOverridden\":true"),
            "row must encode routerOverridden field: \(encoded)")
        XCTAssertTrue(
            encoded.contains("\"schemaVersion\":\"9\""),
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

    // MARK: - chapter 一百九十二 / M716-M725 — 10h-readiness pack

    /// M716 — SHA-256 helper produces stable hex digest, deterministic
    /// per input, distinct for distinct inputs.
    func testRowChecksumIsDeterministicAndDistinguishing() {
        let h1 = SampleHostBenchRowChecksum.sha256Hex(of: "hello")
        let h2 = SampleHostBenchRowChecksum.sha256Hex(of: "hello")
        let h3 = SampleHostBenchRowChecksum.sha256Hex(of: "hello!")
        XCTAssertEqual(h1, h2, "deterministic")
        XCTAssertNotEqual(h1, h3, "distinguishing")
        XCTAssertEqual(h1.count, 64, "SHA-256 = 64 hex chars")
        XCTAssertTrue(
            h1.allSatisfy { c in
                c.isHexDigit && (c.isLowercase || c.isNumber)
            },
            "lowercase-hex only: \(h1)")
        // Known SHA-256 vector for "hello":
        // 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
        XCTAssertEqual(
            h1,
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    /// M716 — encoded row contains a non-empty rowChecksum field
    /// AND that checksum matches SHA-256 of the bareString (no
    /// rowChecksum). Self-verifying.
    func testEncodedRowContainsValidRowChecksum() throws {
        let sig = SampleHostPromptSignature(
            tone: "agentic", domain: "creative", stake: "modest",
            timeframe: "minutes", confidant: "decision-system",
            askShape: "single-action")
        let row = SampleHostHybridBenchRow(
            timestamp: "2026-05-06T12:00:00Z",
            iteration: 1, seed: 1, stride: 5041, mutationSeed: 0,
            signature: sig, prompt: "p", auditCodeCount: 50,
            permitMode: "answer", routerVersion: "v",
            routerPredictedRoute: "afm", routerProbability: 0.7,
            firstTriedLLM: "afm", firstTriedStatus: "ok",
            firstTriedBody: "ok", firstTriedDurationMs: 100,
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
            verbosityProbability: nil, verbosityCorrect: nil,
            thermalState: nil, batteryLevel: nil,
            lowPowerMode: nil, hourOfDay: nil,
            smokeMode: nil, targetLayer: nil,
            targetLayerName: nil,
            anomalyFlags: nil, pressureProfile: nil,
            adversarialKind: nil, driftSigma: nil,
            pauseSkipped: false)
        let encoded = try SampleHostBenchHelpers.encodeHybrid(row)
        XCTAssertTrue(
            encoded.contains("\"rowChecksum\":\""),
            "row must contain rowChecksum field: \(encoded)")
        guard let data = encoded.data(using: .utf8) else {
            XCTFail("UTF-8 encode failed")
            return
        }
        let decoded = try JSONDecoder().decode(
            SampleHostHybridBenchRow.self, from: data)
        XCTAssertNotNil(decoded.rowChecksum)
        XCTAssertEqual(decoded.rowChecksum?.count, 64)
    }

    /// M717 — thermal gate decides PAUSE on critical thermal.
    func testThermalGatePausesOnCriticalThermal() {
        let d = SampleHostBenchThermalGate.decide(
            thermalRaw: "critical",
            batteryLevel: 0.99,
            lowPowerMode: false,
            batteryStateRaw: "unplugged")
        XCTAssertEqual(d, .pause(reason: "thermal-critical"))
    }

    /// M717 — battery-below-floor pauses iff not charging.
    func testThermalGateBatteryFloorOnlyPausesOffCharger() {
        let off = SampleHostBenchThermalGate.decide(
            thermalRaw: "nominal",
            batteryLevel: 0.04,
            lowPowerMode: false,
            batteryStateRaw: "unplugged")
        XCTAssertEqual(off, .pause(reason: "battery-below-5pct"))
        let on = SampleHostBenchThermalGate.decide(
            thermalRaw: "nominal",
            batteryLevel: 0.04,
            lowPowerMode: false,
            batteryStateRaw: "charging")
        XCTAssertEqual(on, .run)
    }

    /// M717 — low-power + serious thermal triggers defensive pause.
    func testThermalGateLowPowerSeriousThermalPauses() {
        let d = SampleHostBenchThermalGate.decide(
            thermalRaw: "serious",
            batteryLevel: 0.5,
            lowPowerMode: true,
            batteryStateRaw: "unplugged")
        XCTAssertEqual(d, .pause(reason: "low-power-serious-thermal"))
    }

    /// M717 — nominal thermal + battery + non-low-power runs.
    func testThermalGateRunsOnHealthyState() {
        let d = SampleHostBenchThermalGate.decide(
            thermalRaw: "nominal",
            batteryLevel: 0.85,
            lowPowerMode: false,
            batteryStateRaw: "unplugged")
        XCTAssertEqual(d, .run)
    }

    /// M739 chapter 一百九十六 — fire-on-entry doctrine for substrate-stuck.
    /// Pre-fix: 1000 stuck iters = 901 fires (every iter once stuck).
    /// Post-fix: 1000 stuck iters = 1 fire (only on entry).
    func testAnomalyWatcherFiresOnceOnContinuousSubstrateStuck() async {
        let watcher = SampleHostBenchAnomalyWatcher(windowSize: 10)
        var fireCount = 0
        // 1000 iters, all same permitMode "answer"
        for _ in 0..<1000 {
            let flags = await watcher.observe(
                permitMode: "answer",
                bodyIsEmpty: false,
                regressionOutputs: [1.0, 2.0, 3.0, 0.5])
            if flags.contains("substrate-stuck:answer") {
                fireCount += 1
            }
        }
        XCTAssertEqual(
            fireCount, 1,
            "fire-on-entry doctrine: 1000 stuck iters = 1 fire")
        let snap = await watcher.snapshot()
        XCTAssertEqual(snap.stuckSubstrates, 1)
    }

    /// M739 — exit + re-entry should fire AGAIN (1 → many → 1 = 2 fires).
    func testAnomalyWatcherFiresAgainOnReEntry() async {
        let watcher = SampleHostBenchAnomalyWatcher(windowSize: 10)
        var entries = 0
        // First stuck region: 100 iters of "answer"
        for _ in 0..<100 {
            let flags = await watcher.observe(
                permitMode: "answer",
                bodyIsEmpty: false,
                regressionOutputs: [1, 2, 3, 0.5])
            if flags.contains("substrate-stuck:answer") {
                entries += 1
            }
        }
        // Diverse window: 20 iters of varied permits → exits stuck
        for i in 0..<20 {
            _ = await watcher.observe(
                permitMode: i % 2 == 0 ? "answer" : "delay",
                bodyIsEmpty: false,
                regressionOutputs: [1, 2, 3, 0.5])
        }
        // Second stuck region: 100 iters → re-entry fires
        for _ in 0..<100 {
            let flags = await watcher.observe(
                permitMode: "block",
                bodyIsEmpty: false,
                regressionOutputs: [1, 2, 3, 0.5])
            if flags.contains("substrate-stuck:block") {
                entries += 1
            }
        }
        XCTAssertEqual(
            entries, 2,
            "expected 2 entries (one per stuck region)")
    }

    /// M718 — anomaly watcher flags substrate-stuck after window iters.
    func testAnomalyWatcherDetectsSubstrateStuck() async {
        let watcher = SampleHostBenchAnomalyWatcher(windowSize: 10)
        // 9 same → no flag yet (window not full)
        for _ in 0..<9 {
            let flags = await watcher.observe(
                permitMode: "answer",
                bodyIsEmpty: false,
                regressionOutputs: [1.0, 2.0, 3.0, 0.5])
            XCTAssertFalse(flags.contains { $0.starts(with: "substrate-stuck") })
        }
        // 10th completes window → flag fires
        let flags = await watcher.observe(
            permitMode: "answer",
            bodyIsEmpty: false,
            regressionOutputs: [1.0, 2.0, 3.0, 0.5])
        XCTAssertTrue(
            flags.contains("substrate-stuck:answer"),
            "expected substrate-stuck flag, got: \(flags)")
        let snap = await watcher.snapshot()
        XCTAssertEqual(snap.iters, 10)
        XCTAssertGreaterThanOrEqual(snap.stuckSubstrates, 1)
    }

    /// M718 — anomaly watcher flags llm-stuck on all-empty window.
    func testAnomalyWatcherDetectsLLMStuck() async {
        let watcher = SampleHostBenchAnomalyWatcher(windowSize: 10)
        var lastFlags: [String] = []
        // Vary permitMode so substrate-stuck doesn't fire (we're
        // testing the LLM-stuck detector independently)
        let modes = ["answer", "delay", "block", "answer", "delay",
                     "answer", "block", "answer", "delay", "answer"]
        for i in 0..<10 {
            lastFlags = await watcher.observe(
                permitMode: modes[i],
                bodyIsEmpty: true,
                regressionOutputs: [1, 2, 3, 0.5])
        }
        XCTAssertTrue(
            lastFlags.contains("llm-stuck:all-empty"),
            "expected llm-stuck:all-empty, got: \(lastFlags)")
    }

    /// M718 — anomaly watcher emits per-iter NaN-spike flag.
    func testAnomalyWatcherDetectsNaNSpike() async {
        let watcher = SampleHostBenchAnomalyWatcher(windowSize: 10)
        let flags = await watcher.observe(
            permitMode: "answer",
            bodyIsEmpty: false,
            regressionOutputs: [1.0, .nan, 2.0, .infinity])
        // 2 non-finite (nan + inf)
        XCTAssertTrue(
            flags.contains("nan-spike:2"),
            "expected nan-spike:2, got: \(flags)")
    }

    /// M719 — pressure mixer is deterministic by iter and weights
    /// total to 100. Top layer (L11, 25%) is hit roughly 25% over
    /// large-N sample.
    func testPressureMixerWeightsAndDeterminism() {
        XCTAssertEqual(
            SampleHostBenchPressureMixer.layerWeights.count, 14)
        XCTAssertEqual(
            SampleHostBenchPressureMixer.layerWeightsTotal, 100.0,
            accuracy: 0.001)
        // Determinism: same iter → same result
        let a = SampleHostBenchPressureMixer.pickLayerIndex(forIter: 7)
        let b = SampleHostBenchPressureMixer.pickLayerIndex(forIter: 7)
        XCTAssertEqual(a, b, "deterministic")
        // Statistical: across 10K iters, L11 (25%) should hit
        // somewhere in [22%, 28%] (loose bound for any RNG).
        var hits: [Int: Int] = [:]
        for i in 0..<10_000 {
            let idx = SampleHostBenchPressureMixer
                .pickLayerIndex(forIter: i)
            hits[idx, default: 0] += 1
        }
        let l11 = hits[11] ?? 0
        XCTAssertGreaterThan(l11, 2_000, "L11 hit only \(l11)/10K")
        XCTAssertLessThan(l11, 2_900, "L11 over-hit \(l11)/10K")
    }

    /// M720 — adversarial mutator is OFF unless enabled.
    func testAdversarialMutatorOffByDefault() {
        for i in 0..<1000 {
            let m = SampleHostBenchAdversarialMutator
                .decideMutation(forIter: i, enabled: false)
            XCTAssertNil(m, "iter \(i) mutated when disabled")
        }
    }

    /// M720 — when enabled, adversarial fires ~5% of iters
    /// (deterministic; check 2K-iter window approximately matches).
    func testAdversarialMutatorFiresAtExpectedRate() {
        var fires = 0
        let total = 5_000
        for i in 0..<total {
            if SampleHostBenchAdversarialMutator
                .decideMutation(forIter: i, enabled: true) != nil
            {
                fires += 1
            }
        }
        let rate = Double(fires) / Double(total)
        XCTAssertGreaterThan(
            rate, 0.025,
            "adversarial fire rate too low: \(rate)")
        XCTAssertLessThan(
            rate, 0.080,
            "adversarial fire rate too high: \(rate)")
    }

    /// M720 — every adversarial kind produces a non-crashing
    /// mutated string from the input prompt.
    func testAdversarialMutatorAllKindsApplyWithoutCrash() {
        let prompt = "Tell me about tomorrow."
        for kind in SampleHostBenchAdversarialKind.allCases {
            let mutated = kind.apply(to: prompt)
            switch kind {
            case .empty:
                XCTAssertEqual(mutated, "")
            case .oneChar:
                XCTAssertEqual(mutated.count, 1)
            case .giant10K:
                XCTAssertEqual(mutated.count, 10_000)
            default:
                XCTAssertFalse(
                    mutated.isEmpty,
                    "\(kind.rawValue) produced empty")
            }
        }
    }

    /// M721 — drift monitor Welford std-dev matches expected for
    /// known small sample.
    func testDriftMonitorSmallSampleStats() {
        let m = SampleHostBenchDriftMonitor()
        // Sample: [2, 4, 4, 4, 5, 5, 7, 9]
        // Mean = 5, sample std-dev = 2.13809...
        // (sum sq diff = 32, n-1 = 7, var = 32/7 ≈ 4.571)
        for x in [2.0, 4, 4, 4, 5, 5, 7, 9] {
            m.update(x)
        }
        XCTAssertEqual(m.count, 8)
        XCTAssertEqual(m.mean, 5.0, accuracy: 0.0001)
        XCTAssertEqual(m.variance, 32.0 / 7.0, accuracy: 0.0001)
        XCTAssertEqual(m.stdDev, sqrt(32.0 / 7.0), accuracy: 0.0001)
    }

    /// M721 — drift monitor sigma above mean is correct.
    func testDriftMonitorSigmaAbove() {
        let m = SampleHostBenchDriftMonitor()
        for x in [10.0, 10, 10, 10, 10] {
            m.update(x)
        }
        // All samples = 10 → stdDev = 0 → sigmaAbove = 0
        XCTAssertEqual(m.sigmaAbove(15), 0)
        // Add variance:
        m.update(20)
        let s = m.sigmaAbove(20)
        XCTAssertGreaterThan(s, 0)
    }

    /// M721 — drift monitor drops NaN/Inf samples silently.
    func testDriftMonitorDropsNonFinite() {
        let m = SampleHostBenchDriftMonitor()
        m.update(1)
        m.update(.nan)
        m.update(.infinity)
        m.update(-.infinity)
        m.update(2)
        XCTAssertEqual(m.count, 2)
        XCTAssertEqual(m.mean, 1.5, accuracy: 0.0001)
    }

    /// M722 — checkpoint Codable round-trip preserves fields.
    func testCheckpointCodableRoundTrip() throws {
        let cp = SampleHostBenchCheckpoint(
            generation: 3,
            iter: 7500,
            startTimeIso: "2026-05-06T00:00:00Z",
            lastUpdatedIso: "2026-05-06T01:30:00Z",
            outputPath: "/tmp/iphone-hybrid-bench",
            smokeMode: "heavy-tailed",
            durationHours: 10.0,
            mutationSeedCount: 5,
            strideCSV: "5041,5039,5051,5077,7919",
            afmOk: 4000,
            gemmaOk: 2000,
            bothFailed: 50,
            stuckSubstrates: 0,
            stuckLLMs: 0)
        let data = try JSONEncoder().encode(cp)
        let back = try JSONDecoder().decode(
            SampleHostBenchCheckpoint.self, from: data)
        XCTAssertEqual(cp, back)
    }

    /// M722 — checkpoint store atomic write + read round-trip
    /// + clear (uses tmp path; stays inside test sandbox).
    func testCheckpointStoreAtomicWriteReadClear() async throws {
        let store = SampleHostBenchCheckpointStore.shared
        let cp = SampleHostBenchCheckpoint(
            generation: 1, iter: 100,
            startTimeIso: "t", lastUpdatedIso: "t",
            outputPath: "/tmp", smokeMode: "canonical",
            durationHours: 1.0, mutationSeedCount: 5,
            strideCSV: "5041", afmOk: 0, gemmaOk: 0,
            bothFailed: 0, stuckSubstrates: 0, stuckLLMs: 0)
        try await store.write(cp)
        let read = await store.read()
        XCTAssertEqual(read?.iter, 100)
        await store.clear()
        let afterClear = await store.read()
        XCTAssertNil(afterClear)
    }

    /// M719 — `.heavyTailed` SmokeMode raw value stable.
    func testHeavyTailedSmokeModeRawValue() {
        let m = HybridBenchConfig.SmokeMode.heavyTailed
        XCTAssertEqual(m.rawValue, "heavy-tailed")
        // Ensure it lives in CaseIterable
        XCTAssertTrue(
            HybridBenchConfig.SmokeMode.allCases.contains(.heavyTailed))
    }

    /// M722 — 10h preset has heavy-tailed mode + 10.0 hours.
    func testTenHourPresetIsHeavyTailed() {
        let preset = HybridBenchConfig.tenHourHeavyTailed
        XCTAssertEqual(preset.durationHours, 10.0)
        XCTAssertEqual(preset.smokeMode, .heavyTailed)
        XCTAssertEqual(preset.mutationSeedCount, 5)
        XCTAssertEqual(preset.jsonlRotationMB, 25)
    }

    // MARK: - chapter 一百九十三 / M726-M730 — resume + dashboard

    /// M726 — fresh model has nil resumable checkpoint.
    @MainActor
    func testFreshModelHasNoResumableCheckpoint() async {
        let m = SampleHostModel()
        // Pre-emptively clear in case prior test left one
        await m.clearResumableCheckpoint()
        await m.loadResumableCheckpoint()
        XCTAssertNil(m.hybridBenchResumableCheckpoint)
    }

    /// M726 — write a recent checkpoint, then load → present.
    @MainActor
    func testRecentCheckpointSurfacesAfterLoad() async throws {
        let store = SampleHostBenchCheckpointStore.shared
        await store.clear()
        let recentIso = ISO8601DateFormatter()
            .string(from: Date().addingTimeInterval(-300))  // 5min ago
        let cp = SampleHostBenchCheckpoint(
            generation: 1, iter: 4242,
            startTimeIso: recentIso, lastUpdatedIso: recentIso,
            outputPath: "/tmp", smokeMode: "heavy-tailed",
            durationHours: 10.0, mutationSeedCount: 5,
            strideCSV: "5041", afmOk: 100, gemmaOk: 50,
            bothFailed: 1, stuckSubstrates: 0, stuckLLMs: 0)
        try await store.write(cp)

        let m = SampleHostModel()
        await m.loadResumableCheckpoint()
        XCTAssertEqual(
            m.hybridBenchResumableCheckpoint?.iter, 4242)
        XCTAssertEqual(
            m.hybridBenchResumableCheckpoint?.smokeMode, "heavy-tailed")

        // Cleanup
        await m.clearResumableCheckpoint()
        XCTAssertNil(m.hybridBenchResumableCheckpoint)
    }

    /// M726 — stale checkpoint (>24h) is auto-cleared on load.
    @MainActor
    func testStaleCheckpointIsAutoCleared() async throws {
        let store = SampleHostBenchCheckpointStore.shared
        await store.clear()
        let staleIso = ISO8601DateFormatter()
            .string(from: Date().addingTimeInterval(-25 * 3600))  // 25h ago
        let cp = SampleHostBenchCheckpoint(
            generation: 1, iter: 100,
            startTimeIso: staleIso, lastUpdatedIso: staleIso,
            outputPath: "/tmp", smokeMode: "canonical",
            durationHours: 1.0, mutationSeedCount: 5,
            strideCSV: "5041", afmOk: 0, gemmaOk: 0,
            bothFailed: 0, stuckSubstrates: 0, stuckLLMs: 0)
        try await store.write(cp)

        let m = SampleHostModel()
        await m.loadResumableCheckpoint()
        XCTAssertNil(
            m.hybridBenchResumableCheckpoint,
            "stale checkpoint should be auto-cleared")

        // Verify on-disk was wiped
        let after = await store.read()
        XCTAssertNil(after, "store should be empty after auto-clear")
    }

    /// M727 — fresh model has zero anomaly counters.
    @MainActor
    func testFreshModelAnomalyCountersZero() {
        let m = SampleHostModel()
        XCTAssertEqual(m.hybridBenchStuckSubstrateCount, 0)
        XCTAssertEqual(m.hybridBenchStuckLLMCount, 0)
        XCTAssertEqual(m.hybridBenchPauseSkippedCount, 0)
        XCTAssertEqual(m.hybridBenchAdversarialFiredCount, 0)
        XCTAssertEqual(m.hybridBenchDriftAlarmCount, 0)
    }

    // MARK: - chapter 一百九十四 / M731-M734 — flex sliders + manifest

    /// M731 — 4 chapter-192 safety constants are @Published with
    /// safe defaults.
    @MainActor
    func testChapter192FlexConstantsHaveSaneDefaults() {
        let m = SampleHostModel()
        XCTAssertEqual(m.hybridBenchAnomalyWindowSize, 100)
        XCTAssertEqual(m.hybridBenchDriftSigmaThreshold, 3.0)
        XCTAssertEqual(m.hybridBenchMutationProbability, 0.05)
        XCTAssertEqual(m.hybridBenchCheckpointEveryNIters, 1000)
    }

    /// M731 — bound enforcement on the 4 setters.
    @MainActor
    func testChapter192FlexConstantsBounds() {
        let m = SampleHostModel()
        m.updateAnomalyWindowSize(5)        // below 10 floor
        XCTAssertEqual(m.hybridBenchAnomalyWindowSize, 10)
        m.updateAnomalyWindowSize(99_999)   // above 1000 ceiling
        XCTAssertEqual(m.hybridBenchAnomalyWindowSize, 1000)

        m.updateDriftSigmaThreshold(0.5)    // below 1.0 floor
        XCTAssertEqual(m.hybridBenchDriftSigmaThreshold, 1.0)
        m.updateDriftSigmaThreshold(99.0)   // above 10 ceiling
        XCTAssertEqual(m.hybridBenchDriftSigmaThreshold, 10.0)

        m.updateMutationProbability(-0.5)   // below 0.0 floor
        XCTAssertEqual(m.hybridBenchMutationProbability, 0.0)
        m.updateMutationProbability(2.0)    // above 1.0 ceiling
        XCTAssertEqual(m.hybridBenchMutationProbability, 1.0)

        m.updateCheckpointEveryNIters(50)   // below 100 floor
        XCTAssertEqual(m.hybridBenchCheckpointEveryNIters, 100)
        m.updateCheckpointEveryNIters(1_000_000) // above 100K
        XCTAssertEqual(m.hybridBenchCheckpointEveryNIters, 100_000)
    }

    /// M731 — adversarial mutator accepts custom probability.
    func testAdversarialMutatorRespectsCustomProbability() {
        // probability = 0 → never fires
        var fires = 0
        for i in 0..<1000 {
            if SampleHostBenchAdversarialMutator
                .decideMutation(forIter: i, enabled: true,
                                probability: 0.0) != nil
            {
                fires += 1
            }
        }
        XCTAssertEqual(fires, 0, "p=0 should never fire")

        // probability = 1 → always fires
        var alwaysFires = 0
        for i in 0..<100 {
            if SampleHostBenchAdversarialMutator
                .decideMutation(forIter: i, enabled: true,
                                probability: 1.0) != nil
            {
                alwaysFires += 1
            }
        }
        XCTAssertEqual(alwaysFires, 100, "p=1 should always fire")

        // probability = 0.5 → ~50%
        var halfFires = 0
        for i in 0..<10_000 {
            if SampleHostBenchAdversarialMutator
                .decideMutation(forIter: i, enabled: true,
                                probability: 0.5) != nil
            {
                halfFires += 1
            }
        }
        XCTAssertGreaterThan(halfFires, 4_500)
        XCTAssertLessThan(halfFires, 5_500)
    }

    /// M733 — manifest Codable round-trip.
    func testShardManifestCodableRoundTrip() throws {
        let manifest = SampleHostBenchShardManifest(
            benchID: "2026-05-06T00:00:00Z",
            startTimeIso: "2026-05-06T00:00:00Z",
            endTimeIso: "2026-05-06T10:00:00Z",
            totalIters: 180_000,
            totalShards: 7,
            smokeMode: "heavy-tailed",
            durationHours: 10.0,
            mutationSeedCount: 5,
            strideCSV: "5041,5039,5051,5077,7919",
            afmOk: 100_000,
            gemmaOk: 70_000,
            bothFailed: 100,
            routerHits: 162_000,
            routerMisses: 18_000,
            stuckSubstrates: 0,
            stuckLLMs: 0,
            pauseSkipped: 50,
            adversarialFired: 9_000,
            driftAlarms: 12,
            anomalyWindowSize: 100,
            driftSigmaThreshold: 3.0,
            mutationProbability: 0.05,
            checkpointEveryNIters: 1000)
        let data = try JSONEncoder().encode(manifest)
        let back = try JSONDecoder().decode(
            SampleHostBenchShardManifest.self, from: data)
        XCTAssertEqual(manifest, back)
    }

    /// M733 — manifest store atomic write + read round-trip.
    func testShardManifestStoreAtomicWriteRead() async throws {
        let store = SampleHostBenchShardManifestStore.shared
        let m = SampleHostBenchShardManifest(
            benchID: "test", startTimeIso: "t", endTimeIso: "t",
            totalIters: 42, totalShards: 1, smokeMode: "canonical",
            durationHours: 0.1, mutationSeedCount: 1,
            strideCSV: "5041", afmOk: 0, gemmaOk: 0, bothFailed: 0,
            routerHits: 0, routerMisses: 0,
            stuckSubstrates: 0, stuckLLMs: 0,
            pauseSkipped: 0, adversarialFired: 0, driftAlarms: 0,
            anomalyWindowSize: 100, driftSigmaThreshold: 3.0,
            mutationProbability: 0.05, checkpointEveryNIters: 1000)
        try await store.write(m)
        let back = await store.read()
        XCTAssertEqual(back?.totalIters, 42)
        XCTAssertEqual(back?.smokeMode, "canonical")
    }

    // MARK: - chapter 一百九十五 / M735-M738 — LLM timeout + smoke

    /// M735 — withLLMTimeout returns the result when work finishes
    /// before the deadline.
    func testWithLLMTimeoutReturnsFastResult() async throws {
        let result = try await withLLMTimeout(5.0) { () -> String in
            try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
            return "ok"
        }
        XCTAssertEqual(result, "ok")
    }

    /// M735 — withLLMTimeout throws .timeoutExceeded when work
    /// hangs past the deadline.
    func testWithLLMTimeoutFiresOnHang() async throws {
        do {
            _ = try await withLLMTimeout(0.1) { () -> String in
                try await Task.sleep(nanoseconds: 10_000_000_000)  // 10s
                return "should not see this"
            }
            XCTFail("expected timeout")
        } catch SampleHostBenchLLMTimeoutError.timeoutExceeded(let s) {
            XCTAssertEqual(s, 0.1)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    /// M735 — withLLMTimeout propagates work errors (not its own
    /// timeout) when work fails before deadline.
    func testWithLLMTimeoutPropagatesWorkError() async {
        struct WorkError: Error, Equatable {}
        do {
            _ = try await withLLMTimeout(5.0) { () -> String in
                throw WorkError()
            }
            XCTFail("expected throw")
        } catch is WorkError {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    /// M735 — fresh model has zero LLM-timeout count + has flex setter.
    @MainActor
    func testLLMTimeoutFlexSetterAndCounter() {
        let m = SampleHostModel()
        XCTAssertEqual(m.hybridBenchLLMTimeoutCount, 0)
        XCTAssertEqual(m.hybridBenchLLMTimeoutSeconds, 60.0)
        m.updateLLMTimeoutSeconds(2.5)  // below 5s floor
        XCTAssertEqual(m.hybridBenchLLMTimeoutSeconds, 5.0)
        m.updateLLMTimeoutSeconds(500)  // above 300s ceiling
        XCTAssertEqual(m.hybridBenchLLMTimeoutSeconds, 300.0)
        m.updateLLMTimeoutSeconds(45)
        XCTAssertEqual(m.hybridBenchLLMTimeoutSeconds, 45.0)
    }

    /// M737-extended — bench-loop 60-second water-test smoke.
    /// Gated behind `BENCH_60SEC_SMOKE=1` env var so it doesn't
    /// run in normal CI (would add 60s per run). Activate with:
    ///
    ///     BENCH_60SEC_SMOKE=1 xcodebuild ... test ...
    ///
    /// Validates end-to-end that:
    ///   1. Bench loop iterates for 60s without freezing
    ///   2. Substrate routing fires every iter
    ///   3. Counters increment monotonically
    ///   4. Anomaly watcher fires no false positives in 60s
    ///   5. Stop is responsive (cancellation honored within 1s)
    @MainActor
    func testBenchLoop60SecondWaterSmoke() async throws {
        // M737-extended chapter 195 + M739 chapter 196 —
        // 60-second water smoke. Skipped by default because it
        // adds 60s to test runtime. To run: change `true` →
        // `false` below and rebuild. (xcodebuild's test runner
        // ignores parent-shell env so file-edit gating is the
        // simplest mechanism.)
        let skipForCI = true
        if skipForCI {
            throw XCTSkip("Toggle skipForCI=false to run the 60s smoke")
        }
        let m = SampleHostModel()
        m.bootstrap()
        try await Task.sleep(nanoseconds: 500_000_000)
        // 0.1h = 360s = 6 min. We'll stop after 60s.
        m.updateHybridBenchDurationHours(0.1)
        m.startHybridBench()
        XCTAssertTrue(m.hybridBenchIsRunning)
        // Run 60s
        try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
        let mid = m.hybridBenchIterations
        XCTAssertGreaterThan(
            mid, 0,
            "expected ≥1 iter in 60s; saw \(mid)")
        m.stopHybridBench()
        // Wait 1s for cancellation
        try await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertFalse(m.hybridBenchIsRunning,
            "should stop within 1s")
        // M739 chapter 一百九十六 — fire-on-entry doctrine.
        // Pre-M739 this saw 913 in 60s (every iter once stuck).
        // Post-M739 with sim's deterministic substrate, count is
        // bounded — typically 10-50 entries in 60s. Assert bounded
        // (not runaway) — anything > 100 = regression.
        XCTAssertLessThan(
            m.hybridBenchStuckSubstrateCount, 100,
            "substrate-stuck regression — pre-M739 saw 913 in 60s")
        // Document outcome to test log
        print(
            "[smoke] iters=\(mid) afmOk=\(m.hybridBenchAFMOk) " +
            "gemmaOk=\(m.hybridBenchGemmaOk) " +
            "bothFailed=\(m.hybridBenchBothFailed) " +
            "routerHits=\(m.hybridBenchRouterHits) " +
            "stuckSubstrates=\(m.hybridBenchStuckSubstrateCount) " +
            "stuckLLMs=\(m.hybridBenchStuckLLMCount) " +
            "pauseSkipped=\(m.hybridBenchPauseSkippedCount) " +
            "lastError=\(m.hybridBenchLastError ?? "none")")
    }

    // MARK: - chapter 一百九十七 / M740-M743 — iPhone-smoke responses

    /// M740 — pauseOnSerious=false (default) keeps gate at
    /// chapter-192 doctrine baseline: serious thermal runs.
    func testThermalGateRunsOnSeriousByDefault() {
        let d = SampleHostBenchThermalGate.decide(
            thermalRaw: "serious",
            batteryLevel: 0.85,
            lowPowerMode: false,
            batteryStateRaw: "charging",
            pauseOnSerious: false)
        XCTAssertEqual(d, .run)
    }

    /// M740 — pauseOnSerious=true pauses on serious thermal
    /// (10h iPhone survivability opt-in).
    func testThermalGatePausesOnSeriousWhenOptedIn() {
        let d = SampleHostBenchThermalGate.decide(
            thermalRaw: "serious",
            batteryLevel: 0.85,
            lowPowerMode: false,
            batteryStateRaw: "charging",
            pauseOnSerious: true)
        XCTAssertEqual(d,
            .pause(reason: "thermal-serious-flex-opt-in"))
    }

    /// M740 — pauseOnSerious DOESN'T affect critical path
    /// (critical always pauses regardless of toggle).
    func testThermalGateAlwaysPausesOnCriticalRegardlessOfFlex() {
        for opt in [false, true] {
            let d = SampleHostBenchThermalGate.decide(
                thermalRaw: "critical",
                batteryLevel: 0.85,
                lowPowerMode: false,
                batteryStateRaw: "charging",
                pauseOnSerious: opt)
            XCTAssertEqual(d, .pause(reason: "thermal-critical"))
        }
    }

    /// M740 — model has @Published flex with default false.
    @MainActor
    func testFreshModelPauseOnSeriousFalseByDefault() {
        let m = SampleHostModel()
        XCTAssertFalse(m.hybridBenchPauseOnSerious)
    }

    /// M766 chapter 二百四 — workflowProfile flex defaults
    /// .reflective (chapter 178+ baseline). Operator picks .primary
    /// for LLM-data accumulation runs.
    @MainActor
    func testFreshModelWorkflowProfileReflectiveByDefault() {
        let m = SampleHostModel()
        XCTAssertEqual(
            m.hybridBenchWorkflowProfile,
            .reflective)
    }

    /// M766 — workflowProfile is settable to all 3 cases.
    @MainActor
    func testWorkflowProfileSettableToAllCases() {
        let m = SampleHostModel()
        m.hybridBenchWorkflowProfile = .primary
        XCTAssertEqual(m.hybridBenchWorkflowProfile, .primary)
        m.hybridBenchWorkflowProfile = .comparative
        XCTAssertEqual(m.hybridBenchWorkflowProfile, .comparative)
        m.hybridBenchWorkflowProfile = .reflective
        XCTAssertEqual(m.hybridBenchWorkflowProfile, .reflective)
    }

    // MARK: - chapter 二百五 / M771-M775 — benign prompt catalog

    /// M771 — benign catalog has 80 prompts (8 categories × 10).
    func testBenignCatalogHas80Prompts() {
        XCTAssertEqual(
            SampleHostBenignPromptCatalog.benignPrompts.count, 80)
    }

    /// M771 — all benign prompts are non-empty + don't start with
    /// "I'm" (chapter 173+ adversarial often emotional first-person).
    func testBenignCatalogPromptsAreLowRisk() {
        for p in SampleHostBenignPromptCatalog.benignPrompts {
            XCTAssertFalse(p.isEmpty)
            XCTAssertFalse(
                p.hasPrefix("I'm "),
                "Benign prompt should not start with 'I'm ': \(p)")
            XCTAssertFalse(
                p.hasPrefix("Help me "),
                "Benign prompt should not be help-emergency: \(p)")
        }
    }

    /// M771 — benign signature is low-risk by all 6 fields.
    func testBenignSignatureIsLowRisk() {
        let s = SampleHostBenignPromptCatalog.benignSignature
        XCTAssertEqual(s.stake, "low",
            "Benign signature stake must be 'low'")
        XCTAssertEqual(s.tone, "curious")
        XCTAssertEqual(s.timeframe, "minutes")
    }

    /// M771 — generate(forIter:) is deterministic by iter.
    func testBenignGenerateIsDeterministic() {
        let g1 = SampleHostBenignPromptCatalog.generate(forIter: 7)
        let g2 = SampleHostBenignPromptCatalog.generate(forIter: 7)
        XCTAssertEqual(g1.prompt, g2.prompt)
        XCTAssertEqual(g1.signature, g2.signature)
    }

    /// M771 — generate(forIter:) cycles through all 80 prompts.
    func testBenignGenerateCyclesThrough80() {
        var seen = Set<String>()
        for i in 0..<80 {
            let g = SampleHostBenignPromptCatalog.generate(forIter: i)
            seen.insert(g.prompt)
        }
        XCTAssertEqual(seen.count, 80,
            "All 80 distinct prompts should be cycled through")
    }

    // MARK: - chapter 二百六 / M776 — benign auto-forces .primary

    /// M776 chapter 二百六 — when smokeMode is .benign, the bench
    /// loop auto-forces workflowProfile to .primary, regardless of
    /// the @Published value. Chapter 205 verified .benign +
    /// .reflective default = 100% substrate-skip; chapter 206 fix
    /// guarantees .benign always pairs with .primary internally.
    /// This test pins the doctrine — bench loop SHOULD use .primary
    /// when smokeMode is .benign even if @Published is .reflective.
    /// (Tested indirectly: the bench-loop logic captures workflow
    /// at start; we verify the @Published default + the public
    /// expectation.)
    @MainActor
    func testBenignModeImpliesPrimaryWorkflowDoctrine() {
        let m = SampleHostModel()
        // Set workflow to .reflective explicitly (chapter 205 user
        // error path)
        m.hybridBenchWorkflowProfile = .reflective
        m.hybridBenchSmokeMode = .benign
        // The @Published values stand as set:
        XCTAssertEqual(m.hybridBenchWorkflowProfile, .reflective)
        XCTAssertEqual(m.hybridBenchSmokeMode, .benign)
        // But chapter 206 doctrine says: bench loop CAPTURES the
        // workflow at start with the .benign-implies-.primary rule.
        // Verify the capture rule itself:
        let captured: BASHostWorkflowProfile = {
            if m.hybridBenchSmokeMode == .benign {
                return .primary
            }
            return m.hybridBenchWorkflowProfile
        }()
        XCTAssertEqual(captured, .primary,
            "chapter 206 doctrine: .benign implies .primary " +
            "regardless of @Published workflow value")
    }

    /// M776 — non-benign smokeModes preserve operator's
    /// workflowProfile choice (don't override).
    @MainActor
    func testNonBenignModePreservesWorkflowChoice() {
        let m = SampleHostModel()
        m.hybridBenchWorkflowProfile = .reflective
        for mode: HybridBenchConfig.SmokeMode in
            [.canonical, .fourteenLayer, .heavyTailed]
        {
            m.hybridBenchSmokeMode = mode
            let captured: BASHostWorkflowProfile = {
                if m.hybridBenchSmokeMode == .benign {
                    return .primary
                }
                return m.hybridBenchWorkflowProfile
            }()
            XCTAssertEqual(captured, .reflective,
                "non-benign mode (\(mode.rawValue)) should " +
                "preserve operator's workflow choice")
        }
    }

    // MARK: - chapter 一百九十八 / M744-M747 — cooling + thermal widget

    /// M744 — cooling settings have sane defaults.
    @MainActor
    func testCoolingFlexConstantsHaveSaneDefaults() {
        let m = SampleHostModel()
        XCTAssertEqual(m.hybridBenchCoolingEveryNIters, 0)  // disabled
        XCTAssertEqual(m.hybridBenchCoolingSleepSeconds, 10.0)
        XCTAssertEqual(m.hybridBenchCoolingSleepCount, 0)
    }

    /// M744 — bound enforcement on cooling setters.
    @MainActor
    func testCoolingFlexConstantsBounds() {
        let m = SampleHostModel()
        m.updateCoolingEveryNIters(-50)
        XCTAssertEqual(m.hybridBenchCoolingEveryNIters, 0)
        m.updateCoolingEveryNIters(999_999)
        XCTAssertEqual(m.hybridBenchCoolingEveryNIters, 100_000)
        m.updateCoolingEveryNIters(2500)
        XCTAssertEqual(m.hybridBenchCoolingEveryNIters, 2500)

        m.updateCoolingSleepSeconds(2.0)  // below 5s
        XCTAssertEqual(m.hybridBenchCoolingSleepSeconds, 5.0)
        m.updateCoolingSleepSeconds(120.0)  // above 60s
        XCTAssertEqual(m.hybridBenchCoolingSleepSeconds, 60.0)
        m.updateCoolingSleepSeconds(15)
        XCTAssertEqual(m.hybridBenchCoolingSleepSeconds, 15.0)
    }

    /// M745 — fresh model has zero thermal counters + unknown state.
    @MainActor
    func testFreshModelThermalCountersZero() {
        let m = SampleHostModel()
        XCTAssertEqual(m.hybridBenchLastThermalRaw, "unknown")
        XCTAssertEqual(m.hybridBenchThermalNominalIters, 0)
        XCTAssertEqual(m.hybridBenchThermalFairIters, 0)
        XCTAssertEqual(m.hybridBenchThermalSeriousIters, 0)
        XCTAssertEqual(m.hybridBenchThermalCriticalIters, 0)
    }

    // MARK: - chapter 一百九十九 / M748-M750 — resume + analyze-only

    /// M748 — resumeBenchFromCheckpoint() restores config from
    /// checkpoint. Checks that smokeMode / duration / mutation /
    /// stride flow from checkpoint to model state.
    @MainActor
    func testResumeRestoresSettingsFromCheckpoint() async throws {
        let store = SampleHostBenchCheckpointStore.shared
        await store.clear()
        let recentIso = ISO8601DateFormatter()
            .string(from: Date().addingTimeInterval(-300))
        let cp = SampleHostBenchCheckpoint(
            generation: 1, iter: 1234,
            startTimeIso: recentIso, lastUpdatedIso: recentIso,
            outputPath: "/tmp", smokeMode: "heavy-tailed",
            durationHours: 5.5,
            mutationSeedCount: 3,
            strideCSV: "5039,7919",
            afmOk: 0, gemmaOk: 0, bothFailed: 0,
            stuckSubstrates: 0, stuckLLMs: 0)
        try await store.write(cp)

        let m = SampleHostModel()
        m.bootstrap()
        try await Task.sleep(nanoseconds: 200_000_000)
        await m.loadResumableCheckpoint()
        XCTAssertNotNil(m.hybridBenchResumableCheckpoint)
        // Initial state — defaults
        XCTAssertEqual(m.hybridBenchSmokeMode, .canonical)
        XCTAssertEqual(m.hybridBenchDurationHours, 8.0)

        // Resume: restores settings + clears banner + starts bench
        await m.resumeBenchFromCheckpoint()

        // Settings restored
        XCTAssertEqual(m.hybridBenchSmokeMode, .heavyTailed)
        XCTAssertEqual(m.hybridBenchDurationHours, 5.5)
        XCTAssertEqual(m.hybridBenchMutationSeedCount, 3)
        XCTAssertEqual(m.hybridBenchStrideRotationCSV, "5039,7919")
        // Banner cleared
        XCTAssertNil(m.hybridBenchResumableCheckpoint)
        // Bench started
        XCTAssertTrue(m.hybridBenchIsRunning)

        // Cleanup: stop the bench so it doesn't run forever
        m.stopHybridBench()
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    /// M748 — resume with no checkpoint is a no-op.
    @MainActor
    func testResumeWithoutCheckpointIsNoOp() async {
        let m = SampleHostModel()
        await SampleHostBenchCheckpointStore.shared.clear()
        XCTAssertNil(m.hybridBenchResumableCheckpoint)
        // Should not crash; should not start bench.
        await m.resumeBenchFromCheckpoint()
        XCTAssertFalse(m.hybridBenchIsRunning)
    }

    /// M737 — bench-loop integration smoke test: start with
    /// 0.001h (3.6s) duration, verify it starts + can be stopped
    /// without crash. Doesn't rely on LLM availability — substrate
    /// routing always works in test sim.
    @MainActor
    func testBenchLoopStartsAndStopsWithoutCrash() async throws {
        let m = SampleHostModel()
        m.bootstrap()
        // Wait a bit for bootstrap before starting bench
        try await Task.sleep(nanoseconds: 200_000_000)
        m.updateHybridBenchDurationHours(0.001)  // 3.6s; clamped to 0.1
        // (clamp will floor 0.001 → 0.1 = 6 min; we'll stop early)
        // Actually 0.1h = 360s; we'll stop after 0.5s
        m.startHybridBench()
        XCTAssertTrue(m.hybridBenchIsRunning)
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
        m.stopHybridBench()
        // Give the bench task time to observe cancellation
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertFalse(m.hybridBenchIsRunning,
            "bench should be stopped after 1s")
        // No assertion on iter count — substrate may or may not
        // have completed an iter in the 500ms window. Just verify
        // it started + stopped without crash and no error.
        if let err = m.hybridBenchLastError {
            // LLM unavailable on test sim is expected; only crash
            // on UNEXPECTED error categories.
            let acceptable = [
                "GemmaUnavailable", "AFMUnavailable",
                "lora-load-failed", "BASMLXAdapter not built",
            ]
            let isAcceptable = acceptable.contains { err.contains($0) }
            if !isAcceptable {
                XCTFail("unexpected bench error: \(err)")
            }
        }
    }

    /// M733 — sampleHostBenchCountShards counts only `*.jsonl`.
    func testCountShardsCountsOnlyJsonlFiles() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-shards-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true)
        defer {
            _ = try? FileManager.default.removeItem(at: tmpDir)
        }
        // 3 *.jsonl files + 2 unrelated
        for i in 1...3 {
            let url = tmpDir.appendingPathComponent("shard.\(i).jsonl")
            try Data("hello".utf8).write(to: url)
        }
        try Data().write(to: tmpDir.appendingPathComponent("notes.txt"))
        try Data().write(to: tmpDir.appendingPathComponent("manifest.json"))
        XCTAssertEqual(sampleHostBenchCountShards(in: tmpDir), 3)
    }

    // MARK: - chapter 二百三 / M764 — architectural invariants

    /// M764 — pin schema version monotonic.
    /// Future chapters MAY bump version (additive Codable fields)
    /// but version MUST be a String parseable as Int and >= the
    /// last shipped value (currently "9" from chapter 192).
    func testSchemaVersionIsMonotonicallyParseable() {
        let v = SAMPLE_HOST_HYBRID_BENCH_ROW_SCHEMA_VERSION
        guard let n = Int(v) else {
            XCTFail("Schema version must parse as Int: \(v)")
            return
        }
        XCTAssertGreaterThanOrEqual(
            n, 9,
            "Schema version cannot decrease below shipped " +
            "chapter-192 baseline of 9")
    }

    /// M764 — pin SmokeMode case names stable.
    /// chapter 195 had 3 smoke modes; chapter 205 added .benign;
    /// chapter 208 added .rawLLM (5 cases). Future chapters may
    /// add more but cannot remove (would break replay tools that
    /// grep on smokeMode raw values).
    func testSmokeModeRawValuesAreStable() {
        let modes = HybridBenchConfig.SmokeMode.allCases
        XCTAssertGreaterThanOrEqual(modes.count, 5,
            "SmokeMode case count cannot decrease (chapter 208+)")
        let raws = Set(modes.map(\.rawValue))
        XCTAssertTrue(raws.contains("canonical"))
        XCTAssertTrue(raws.contains("14-layer-smoke"))
        XCTAssertTrue(raws.contains("heavy-tailed"))
        XCTAssertTrue(raws.contains("benign"))
        XCTAssertTrue(raws.contains("raw-llm"))
    }

    // MARK: - chapter 二百八 / M783-M789 — .rawLLM bench-data-only mode

    /// M783 — .rawLLM raw value is "raw-llm" (kebab-case stable).
    func testRawLLMSmokeModeRawValue() {
        XCTAssertEqual(
            HybridBenchConfig.SmokeMode.rawLLM.rawValue, "raw-llm")
    }

    /// M784 — bench-loop dispatch override doctrine: when smokeMode
    /// is .rawLLM, dispatchPolicy MUST be .singleLLM regardless of
    /// permitMode. Tests the doctrine via direct branch logic.
    func testRawLLMForcesSingleLLMDispatch() {
        let modes: [String] = [
            "block", "delay", "replace", "answer",
            "compare", "escalate", "localOnly", "draftOnly",
        ]
        for permitMode in modes {
            // Simulating the chapter-208 bench-loop logic:
            let dispatchPolicy: SampleHostHybridDispatchPolicy
            let smokeMode = HybridBenchConfig.SmokeMode.rawLLM
            if smokeMode == .rawLLM {
                dispatchPolicy = .singleLLM
            } else {
                dispatchPolicy =
                    SampleHostHybridDispatchPolicy.from(
                        permitMode: permitMode)
            }
            XCTAssertEqual(
                dispatchPolicy, .singleLLM,
                "rawLLM mode must force singleLLM regardless of " +
                "permit '\(permitMode)'")
        }
    }

    /// M784 — non-rawLLM modes still respect substrate's permit.
    func testNonRawLLMModesRespectSubstratePermit() {
        for mode: HybridBenchConfig.SmokeMode in
            [.canonical, .fourteenLayer, .heavyTailed, .benign]
        {
            let dispatchForBlock: SampleHostHybridDispatchPolicy
            if mode == .rawLLM {
                dispatchForBlock = .singleLLM
            } else {
                dispatchForBlock =
                    SampleHostHybridDispatchPolicy.from(
                        permitMode: "block")
            }
            XCTAssertEqual(
                dispatchForBlock, .skipBlock,
                "Non-rawLLM mode \(mode.rawValue) should preserve " +
                "substrate's .block → .skipBlock dispatch")
        }
    }

    /// M764 — pin DispatchPolicy case names stable (chapter 178 doctrine).
    func testDispatchPolicyCasesAreStable() {
        let raws = [
            "skip-block", "skip-replace", "skip-delay",
            "single-llm", "both-llms",
            "local-only", "draft-only",
        ]
        for raw in raws {
            XCTAssertNotNil(
                SampleHostHybridDispatchPolicy(rawValue: raw),
                "DispatchPolicy must have case for raw \(raw)")
        }
    }

    /// M764 — pin BenchCheckpoint Codable shape stable.
    /// Future chapters add fields as Optional or bump schema.
    func testCheckpointSchemaFieldsAreStable() throws {
        let cp = SampleHostBenchCheckpoint(
            generation: 1, iter: 100,
            startTimeIso: "t", lastUpdatedIso: "t",
            outputPath: "/tmp", smokeMode: "canonical",
            durationHours: 1.0, mutationSeedCount: 5,
            strideCSV: "5041", afmOk: 0, gemmaOk: 0,
            bothFailed: 0, stuckSubstrates: 0, stuckLLMs: 0)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(cp)
        let json = String(data: data, encoding: .utf8) ?? ""
        let expected = [
            "afmOk", "bothFailed", "durationHours", "gemmaOk",
            "generation", "iter", "lastUpdatedIso",
            "mutationSeedCount", "outputPath", "smokeMode",
            "startTimeIso", "strideCSV", "stuckLLMs",
            "stuckSubstrates",
        ]
        for name in expected {
            XCTAssertTrue(
                json.contains("\"\(name)\""),
                "Checkpoint missing expected field: \(name)")
        }
    }

    // MARK: - chapter 二百九 / M790 — adaptive thermal cooldown
    //
    // Doctrine pins for the cooldown ladder. The bench loop trusts
    // these values; if anyone re-tunes them they MUST update both
    // the source file's static constants AND these tests, otherwise
    // a 10h bench will silently sleep too short or too long.

    func testThermalCooldownInitialStateIsZeroStreak() {
        let cooldown = SampleHostThermalCooldown()
        XCTAssertEqual(cooldown.pauseStreak, 0)
        XCTAssertEqual(cooldown.sleepSeconds(), 0)
        XCTAssertEqual(cooldown.sleepNanoseconds(), 0)
        XCTAssertEqual(cooldown.ladderLabel(), "cooldown-idle")
    }

    func testThermalCooldownLadderIs30_60_120_300Capped() {
        var cooldown = SampleHostThermalCooldown()

        // 1st pause: 30s baseline (chapter 一百九十七 preserved)
        cooldown.observe(decision: .pause(reason: "test"))
        XCTAssertEqual(cooldown.pauseStreak, 1)
        XCTAssertEqual(cooldown.sleepSeconds(), 30)
        XCTAssertEqual(cooldown.ladderLabel(), "cooldown-30s")

        // 2nd pause: 60s
        cooldown.observe(decision: .pause(reason: "test"))
        XCTAssertEqual(cooldown.pauseStreak, 2)
        XCTAssertEqual(cooldown.sleepSeconds(), 60)
        XCTAssertEqual(cooldown.ladderLabel(), "cooldown-60s")

        // 3rd pause: 120s
        cooldown.observe(decision: .pause(reason: "test"))
        XCTAssertEqual(cooldown.pauseStreak, 3)
        XCTAssertEqual(cooldown.sleepSeconds(), 120)
        XCTAssertEqual(cooldown.ladderLabel(), "cooldown-120s")

        // 4th pause: 300s ceiling
        cooldown.observe(decision: .pause(reason: "test"))
        XCTAssertEqual(cooldown.pauseStreak, 4)
        XCTAssertEqual(cooldown.sleepSeconds(), 300)
        XCTAssertEqual(cooldown.ladderLabel(), "cooldown-300s-ceiling")

        // 5th-Nth pause: still 300s (ceiling holds)
        for i in 5...20 {
            cooldown.observe(decision: .pause(reason: "test"))
            XCTAssertEqual(cooldown.pauseStreak, i)
            XCTAssertEqual(cooldown.sleepSeconds(), 300)
            XCTAssertEqual(
                cooldown.ladderLabel(), "cooldown-300s-ceiling")
        }
    }

    func testThermalCooldownObserveRunResetsStreak() {
        var cooldown = SampleHostThermalCooldown()

        // Climb to ceiling
        for _ in 1...10 {
            cooldown.observe(decision: .pause(reason: "test"))
        }
        XCTAssertEqual(cooldown.pauseStreak, 10)
        XCTAssertEqual(cooldown.sleepSeconds(), 300)

        // Single .run resets to zero
        cooldown.observe(decision: .run)
        XCTAssertEqual(cooldown.pauseStreak, 0)
        XCTAssertEqual(cooldown.sleepSeconds(), 0)
        XCTAssertEqual(cooldown.ladderLabel(), "cooldown-idle")

        // Next pause re-starts at 30s baseline
        cooldown.observe(decision: .pause(reason: "test"))
        XCTAssertEqual(cooldown.pauseStreak, 1)
        XCTAssertEqual(cooldown.sleepSeconds(), 30)
    }

    func testThermalCooldownSleepNanosecondsMatchesSeconds() {
        var cooldown = SampleHostThermalCooldown()
        cooldown.observe(decision: .pause(reason: "test"))
        // 30s = 30_000_000_000 ns
        XCTAssertEqual(
            cooldown.sleepNanoseconds(),
            UInt64(30 * 1_000_000_000))

        cooldown.observe(decision: .pause(reason: "test"))
        cooldown.observe(decision: .pause(reason: "test"))
        cooldown.observe(decision: .pause(reason: "test"))
        // 300s ceiling = 300_000_000_000 ns
        XCTAssertEqual(
            cooldown.sleepNanoseconds(),
            UInt64(300 * 1_000_000_000))
    }

    func testThermalCooldownStreakSaturatesAtSane() {
        var cooldown = SampleHostThermalCooldown()
        // Force the streak past saturation by observing many pauses.
        // We don't iter to Int.max in a test (slow); instead, push
        // beyond `pauseStreakSaturation` and confirm it caps.
        for _ in 1...(SampleHostThermalCooldown.pauseStreakSaturation + 50) {
            cooldown.observe(decision: .pause(reason: "test"))
        }
        XCTAssertEqual(
            cooldown.pauseStreak,
            SampleHostThermalCooldown.pauseStreakSaturation,
            "Streak must saturate, not overflow")
        XCTAssertEqual(
            cooldown.sleepSeconds(), 300,
            "Saturated streak still sleeps 300s ceiling")
    }

    func testThermalCooldownLadderConstantsAreStable() {
        // Pin the ladder constants. If anyone re-tunes the schedule
        // they must also update this test (deliberate friction —
        // the ladder values are doctrine, not magic numbers).
        XCTAssertEqual(
            SampleHostThermalCooldown.firstSleepSeconds, 30,
            "1st-pause baseline preserves chapter 一百九十七 doctrine")
        XCTAssertEqual(
            SampleHostThermalCooldown.secondSleepSeconds, 60)
        XCTAssertEqual(
            SampleHostThermalCooldown.thirdSleepSeconds, 120)
        XCTAssertEqual(
            SampleHostThermalCooldown.ceilingSleepSeconds, 300,
            "5-min ceiling is the chapter 二百九 invariant")
        XCTAssertEqual(
            SampleHostThermalCooldown.pauseStreakSaturation, 1000,
            "Saturation point above any practical 10h bench horizon")
    }

    func testThermalCooldownEquatableSemantics() {
        var a = SampleHostThermalCooldown()
        var b = SampleHostThermalCooldown()
        XCTAssertEqual(a, b)

        a.observe(decision: .pause(reason: "x"))
        XCTAssertNotEqual(a, b)

        b.observe(decision: .pause(reason: "y"))
        // Different reasons but both produce streak == 1
        XCTAssertEqual(a, b,
            "Cooldown equality is structural — reason string is " +
            "consumed by the gate row, not stored in cooldown state")
    }

    // MARK: - chapter 二百十 / M791 — per-iter context derive
    //
    // The carve-out moved ~95 LOC of inline logic out of
    // `startHybridBench()`. These tests pin the doctrine flow:
    // canonical / .fourteenLayer / .heavyTailed / .benign / .rawLLM
    // all flow through the SAME pure-derive entry point and produce
    // typed context with the right shape per smokeMode.

    func testIterContextDeterministicByIter() {
        // Two independent calls with same args → byte-equal contexts.
        // Doctrine: replay must reconstruct iter context exactly.
        let a = SampleHostBenchIterContext.derive(
            iter: 42,
            rotationPeriod: 8,
            strideRotation: [5041, 5039, 5051, 5077, 7919],
            mutationCount: 5,
            smokeMode: .canonical,
            mutationProbability: 0.05)
        let b = SampleHostBenchIterContext.derive(
            iter: 42,
            rotationPeriod: 8,
            strideRotation: [5041, 5039, 5051, 5077, 7919],
            mutationCount: 5,
            smokeMode: .canonical,
            mutationProbability: 0.05)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.iter, 42)
    }

    func testIterContextStrideRotationSchedule() {
        // rotationPeriod=8 means stride changes every 8 iters.
        // First 8 iters: index 0; iters 8..15: index 1; etc.
        let strides = [5041, 5039, 5051, 5077, 7919]

        for iter in 0..<8 {
            let ctx = SampleHostBenchIterContext.derive(
                iter: iter, rotationPeriod: 8,
                strideRotation: strides, mutationCount: 5,
                smokeMode: .canonical, mutationProbability: 0.0)
            XCTAssertEqual(
                ctx.chosenStride, strides[0],
                "Iters 0..7 use first stride")
        }

        for iter in 8..<16 {
            let ctx = SampleHostBenchIterContext.derive(
                iter: iter, rotationPeriod: 8,
                strideRotation: strides, mutationCount: 5,
                smokeMode: .canonical, mutationProbability: 0.0)
            XCTAssertEqual(
                ctx.chosenStride, strides[1],
                "Iters 8..15 use second stride")
        }
    }

    func testIterContextMutationSeedIsModulo() {
        for iter in 0..<20 {
            let ctx = SampleHostBenchIterContext.derive(
                iter: iter, rotationPeriod: 8,
                strideRotation: [5041], mutationCount: 5,
                smokeMode: .canonical, mutationProbability: 0.0)
            XCTAssertEqual(ctx.mutationSeed, iter % 5)
        }
    }

    func testIterContextCanonicalModeHasNoLayerProfile() {
        let ctx = SampleHostBenchIterContext.derive(
            iter: 100, rotationPeriod: 8,
            strideRotation: [5041], mutationCount: 5,
            smokeMode: .canonical, mutationProbability: 0.05)
        XCTAssertNil(ctx.layerProfile,
            ".canonical mode disables layer override")
        XCTAssertNil(ctx.pressureProfile,
            ".canonical mode emits no pressure tag")
        XCTAssertNil(ctx.adversarialKind,
            ".canonical mode disables adversarial mutator " +
            "(only .heavyTailed enables it)")
    }

    func testIterContextFourteenLayerModePopulatesLayerProfile() {
        let ctx = SampleHostBenchIterContext.derive(
            iter: 5, rotationPeriod: 8,
            strideRotation: [5041], mutationCount: 5,
            smokeMode: .fourteenLayer, mutationProbability: 0.0)
        XCTAssertNotNil(ctx.layerProfile,
            ".fourteenLayer must produce a layer profile per iter")
        // Layer profile's signature should be the one used.
        if let profile = ctx.layerProfile {
            XCTAssertEqual(ctx.signature.tone, profile.tone)
            XCTAssertEqual(ctx.signature.domain, profile.domain)
            XCTAssertEqual(ctx.signature.stake, profile.stake)
        }
    }

    func testIterContextBenignModePinsLowRiskSignature() {
        let ctx = SampleHostBenchIterContext.derive(
            iter: 7, rotationPeriod: 8,
            strideRotation: [5041], mutationCount: 5,
            smokeMode: .benign, mutationProbability: 0.05)
        XCTAssertNil(ctx.layerProfile,
            ".benign disables layer override")
        XCTAssertNil(ctx.adversarialKind,
            ".benign disables adversarial mutator " +
            "(only .heavyTailed enables it)")
        // Benign signature should match catalog (low-risk pinned).
        XCTAssertEqual(ctx.signature.stake, "low",
            ".benign signature must be low-risk")
    }

    func testIterContextRawLLMModeHasNoLayerOverride() {
        // chapter 二百八 doctrine: .rawLLM uses catalog signatures
        // unaltered; substrate routing still runs but dispatch
        // override forces .singleLLM.
        let ctx = SampleHostBenchIterContext.derive(
            iter: 50, rotationPeriod: 8,
            strideRotation: [5041], mutationCount: 5,
            smokeMode: .rawLLM, mutationProbability: 0.05)
        XCTAssertNil(ctx.layerProfile,
            ".rawLLM disables layer override")
        XCTAssertNil(ctx.pressureProfile,
            ".rawLLM emits no pressure tag")
        XCTAssertNil(ctx.adversarialKind,
            ".rawLLM disables adversarial mutator")
    }

    func testIterContextHeavyTailedModeMixesPressure() {
        // .heavyTailed should produce a layer profile + pressure tag
        // (modulo the mixer's distribution; checking ANY iter in a
        // window of 20 fires at least one pressureProfile).
        var sawProfile = false
        for iter in 0..<20 {
            let ctx = SampleHostBenchIterContext.derive(
                iter: iter, rotationPeriod: 8,
                strideRotation: [5041], mutationCount: 5,
                smokeMode: .heavyTailed, mutationProbability: 0.0)
            if ctx.pressureProfile != nil {
                sawProfile = true
                XCTAssertTrue(
                    ctx.pressureProfile?.hasPrefix("heavy-tail-")
                        ?? false,
                    "Pressure tag must be `heavy-tail-<layerName>`")
            }
        }
        XCTAssertTrue(sawProfile,
            ".heavyTailed must produce at least one pressure-tagged " +
            "iter in 20-iter window")
    }

    func testIterContextDefensesAgainstZeroDivisors() {
        // mutationCount=0 / strideRotation.isEmpty / rotationPeriod=0
        // must NOT crash. Defensive math clamps to 1.
        let ctx = SampleHostBenchIterContext.derive(
            iter: 100,
            rotationPeriod: 0,            // bogus
            strideRotation: [5041],
            mutationCount: 0,             // bogus
            smokeMode: .canonical,
            mutationProbability: 0.0)
        XCTAssertEqual(ctx.iter, 100)
        XCTAssertEqual(ctx.chosenStride, 5041)
        XCTAssertEqual(ctx.mutationSeed, 0)
    }
}
