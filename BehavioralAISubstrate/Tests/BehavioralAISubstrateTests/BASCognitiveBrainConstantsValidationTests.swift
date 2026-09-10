// MARK: - BASCognitiveBrainConstantsValidationTests
// SEMANTIC constraints on the named constants — not
// value-pinning。 If a future commit sets latencyBudgetMs
// to -1 or safetyConfidenceThreshold to 5.0, these
// catch the regression。
//
// Why not just pin the literal value? Because value-pinning
// tests are tautological (\"the constant is 0.6\" just
// restates the constant). Constraint tests verify
// REAL invariants the constant must satisfy.

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASCognitiveBrainConstantsValidationTests: XCTestCase {

    // MARK: - safetyConfidenceThreshold

    func testSafetyThresholdMustBeatRandomBaseline() {
        // Random 7-class guess has confidence ≈ 1/7。
        // Threshold must be strictly above so we don't
        // .block on uniform-distribution outputs。
        let randomBaseline = 1.0 / 7.0
        XCTAssertGreaterThan(
            BASCognitiveBrain.safetyConfidenceThreshold,
            randomBaseline,
            "safetyConfidenceThreshold must exceed random" +
            " baseline (1/7) to avoid blocking on uniform" +
            " softmax outputs")
    }

    func testSafetyThresholdMustBeLessThanOne() {
        // Threshold of 1.0 means \"only block if model is
        // 100% sure\" — too strict given softmax never
        // hits exactly 1.0。
        XCTAssertLessThan(
            BASCognitiveBrain.safetyConfidenceThreshold,
            1.0,
            "safetyConfidenceThreshold must be < 1.0 so" +
            " softmax outputs can actually trigger blocks")
    }

    // MARK: - ambiguityComplement

    func testAmbiguityComplementIsOne() {
        // confidence + ambiguityScore = 1 (mathematical
        // invariant)。 If complement is anything else the
        // ambiguity-confidence inversion breaks。
        XCTAssertEqual(
            BASCognitiveBrain.ambiguityComplement, 1.0,
            "ambiguityComplement is the '1' in" +
            " 'confidence = 1 - ambiguity'。 Any other" +
            " value breaks the inversion semantics。")
    }

    // MARK: - DefaultDeviceStateValues

    func testDefaultBatteryLevelInValidRange() {
        let v = BASCognitiveBrain.DefaultDeviceStateValues
            .batteryLevel
        XCTAssertGreaterThanOrEqual(v, 0.0)
        XCTAssertLessThanOrEqual(v, 1.0)
    }

    func testDefaultMemoryFreeMBIsPositive() {
        XCTAssertGreaterThan(
            BASCognitiveBrain.DefaultDeviceStateValues
                .memoryFreeMB, 0,
            "Default memoryFreeMB must be > 0 — zero" +
            " means a contended device which is not a" +
            " sensible default")
    }

    func testDefaultCPUGPULoadInValidRange() {
        let cpu = BASCognitiveBrain
            .DefaultDeviceStateValues.cpuLoad
        let gpu = BASCognitiveBrain
            .DefaultDeviceStateValues.gpuLoad
        XCTAssertGreaterThanOrEqual(cpu, 0.0)
        XCTAssertLessThanOrEqual(cpu, 1.0)
        XCTAssertGreaterThanOrEqual(gpu, 0.0)
        XCTAssertLessThanOrEqual(gpu, 1.0)
    }

    func testDefaultLatencyBudgetIsPositive() {
        XCTAssertGreaterThan(
            BASCognitiveBrain.DefaultDeviceStateValues
                .latencyBudgetMs, 0,
            "Default latencyBudgetMs must be > 0 —" +
            " zero or negative budget would cause the" +
            " cascade to refuse to run")
    }

    func testDefaultLatencyBudgetIsReasonable() {
        // Real measured per-call latency is ~1-10ms。
        // Default budget should give comfortable headroom
        // but not be infinity。 100ms minimum,10s maximum。
        let v = BASCognitiveBrain
            .DefaultDeviceStateValues.latencyBudgetMs
        XCTAssertGreaterThanOrEqual(v, 100,
            "latencyBudgetMs < 100ms is too tight given" +
            " measured ~1-10ms baseline")
        XCTAssertLessThanOrEqual(v, 10000,
            "latencyBudgetMs > 10s is suspicious — host" +
            " may have left a debug value in")
    }

    // MARK: - BASCognitiveBrainPlaceholderConstants

    func testNeutralProbabilitiesInValidRange() {
        let K = BASCognitiveBrainPlaceholderConstants.self
        let probabilities: [Double] = [
            K.neutralEmotionalLoad,
            K.neutralTimePressure,
            K.neutralAmbiguityScore,
            K.neutralConsequenceLevel,
            K.neutralHostRelevance,
            K.neutralCandidateScore,
            K.neutralForecastUncertainty,
            K.neutralCritiqueSeverity,
            K.neutralStabilityScore,
            K.neutralTriSelfScore,
            K.neutralTotalRisk,
            K.neutralRiskUncertainty,
            K.neutralRiskIrreversibility,
            K.neutralRiskManipulationStrength,
            K.neutralGSIScore,
        ]
        for p in probabilities {
            XCTAssertGreaterThanOrEqual(p, 0.0,
                "Probability \(p) must be ≥ 0")
            XCTAssertLessThanOrEqual(p, 1.0,
                "Probability \(p) must be ≤ 1")
        }
    }

    func testPositiveIntegerConstants() {
        let K = BASCognitiveBrainPlaceholderConstants.self
        XCTAssertGreaterThan(K.defaultMaxLoops, 0)
        XCTAssertGreaterThan(K.defaultMaxCandidates, 0)
        XCTAssertGreaterThan(K.defaultMaxDecodeTokens, 0)
        XCTAssertGreaterThan(K.defaultRetrievalDepth, 0)
        XCTAssertGreaterThan(K.defaultOutputLengthCap, 0)
    }

    func testNonEmptyStringConstants() {
        let K = BASCognitiveBrainPlaceholderConstants.self
        let strings: [String] = [
            K.neutralRelationPattern,
            K.placeholderTag,
            K.placeholderCandidateID,
            K.placeholderDecomposeRef,
            K.placeholderTonePolicy,
            K.placeholderTemplatePolicy,
            K.placeholderHostLongTermGoal,
        ]
        for s in strings {
            XCTAssertFalse(s.isEmpty,
                "String constant must be non-empty")
        }
    }
}
