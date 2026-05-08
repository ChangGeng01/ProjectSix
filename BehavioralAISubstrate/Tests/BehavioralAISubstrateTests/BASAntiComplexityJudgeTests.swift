// MARK: - BASAntiComplexityJudgeTests — chapter 四百一 / M938

import XCTest
@testable import BASRuntimeCore

final class BASAntiComplexityJudgeTests: XCTestCase {

    // MARK: - Enum surface

    func testSignalAllCases() {
        XCTAssertEqual(
            BASScopeCreepSignal.allCases.count, 6)
    }

    func testRiskLevelAllCases() {
        XCTAssertEqual(
            BASScopeCreepRiskLevel.allCases.count, 3)
    }

    // MARK: - Clean text

    func testCleanTextIsClean() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "Let's ship the MVP this sprint with " +
                "minimal features.")
        XCTAssertEqual(assessment.riskLevel, .clean)
        XCTAssertEqual(assessment.totalHitCount, 0)
        XCTAssertTrue(assessment.signalHits.isEmpty)
    }

    // MARK: - Chinese signal detection

    func testDetectsChineseBleedingEdge() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "我们要用最先进的架构,前沿技术全部上。")
        XCTAssertNotEqual(assessment.riskLevel, .clean)
        XCTAssertNotNil(
            assessment.signalHits[
                .bleedingEdgeAdmiration])
    }

    func testDetectsChineseFinalForm() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "这是最终局的设计。")
        XCTAssertNotEqual(assessment.riskLevel, .clean)
        XCTAssertNotNil(
            assessment.signalHits[
                .finalFormFantasy])
    }

    func testDetectsChineseFeatureAddictionLoop() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "还可以加什么?还能加什么模型?")
        XCTAssertNotEqual(assessment.riskLevel, .clean)
        XCTAssertNotNil(
            assessment.signalHits[
                .featureAddictionLoop])
    }

    // MARK: - English signal detection

    func testDetectsEnglishStateOfTheArt() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "We need state-of-the-art everything.")
        XCTAssertNotEqual(assessment.riskLevel, .clean)
        XCTAssertNotNil(
            assessment.signalHits[
                .bleedingEdgeAdmiration])
    }

    func testDetectsEnglishUltimate() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "The ultimate solution.")
        XCTAssertNotEqual(assessment.riskLevel, .clean)
        XCTAssertNotNil(
            assessment.signalHits[.ultimateFraming])
    }

    func testCaseInsensitiveEnglish() {
        let assessment1 =
            BASAntiComplexityJudge.assess(
                text: "ULTIMATE")
        let assessment2 =
            BASAntiComplexityJudge.assess(
                text: "ultimate")
        XCTAssertEqual(
            assessment1.totalHitCount,
            assessment2.totalHitCount)
    }

    // MARK: - Risk level escalation

    func testWarningOnSingleSignal() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "use 最先进 architecture")
        XCTAssertEqual(assessment.riskLevel, .warning)
    }

    func testCriticalOnTwoSignalCategories() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "最先进的最强大的架构")
        // Two distinct signal categories
        XCTAssertEqual(assessment.riskLevel, .critical)
        XCTAssertEqual(assessment.signalHits.count, 2)
    }

    func testCriticalOnHighSignalDensity() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "最先进!最先进!最先进!")
        // 3+ hits same category → critical
        XCTAssertEqual(assessment.riskLevel, .critical)
        XCTAssertGreaterThanOrEqual(
            assessment.totalHitCount, 3)
    }

    // MARK: - Risk flags

    func testRiskFlagsForCleanIsEmpty() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "clean MVP")
        let flags = BASAntiComplexityJudge.riskFlags(
            for: assessment)
        XCTAssertEqual(flags, [])
    }

    func testRiskFlagsCarryNamespacedSignals() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "最先进的最终局")
        let flags = BASAntiComplexityJudge.riskFlags(
            for: assessment)
        XCTAssertTrue(flags.allSatisfy {
            $0.hasPrefix("anti-complexity:")
        })
    }

    // MARK: - Mitigation hint pinned

    func testMitigationHintPinned() {
        let assessment = BASAntiComplexityJudge.assess(
            text: "最先进")
        XCTAssertEqual(
            assessment.mitigationHint,
            BASAntiComplexityJudge
                .canonicalMitigationHint)
    }

    // MARK: - Codable round-trip

    func testAssessmentCodable() throws {
        let assessment = BASAntiComplexityJudge.assess(
            text: "最先进的最终局架构")
        let data = try JSONEncoder().encode(assessment)
        let decoded = try JSONDecoder().decode(
            BASScopeCreepAssessment.self, from: data)
        XCTAssertEqual(decoded, assessment)
    }
}
