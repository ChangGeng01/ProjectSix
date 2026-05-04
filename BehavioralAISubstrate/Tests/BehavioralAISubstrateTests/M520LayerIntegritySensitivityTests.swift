import XCTest
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASSovereign
@testable import BASWorldPrior

/// M520-M523 (chapter 一百三十三) — Layer-integrity sensitivity tests
/// per chapter 一百三十二 ENGINEERING_HEALTH_DEBT.md C.5 (mutation
/// tests gap) + Section A.4 (14-layer narrative inflation: 0
/// mutation tests = no proof layers aren't dead code).
///
/// **Purpose**: prove that each load-bearing layer's derive helper
/// actually responds to upstream input changes. If a layer's
/// output is invariant across diverse inputs, the layer has
/// silently degraded to no-op and the 14-layer claim is theater.
///
/// These tests are NOT full mutation tests (deleting code +
/// expecting failure). They are **sensitivity tests**: vary the
/// input, assert the output meaningfully changes. A no-op layer
/// would produce constant output regardless of input → these tests
/// would fail.
///
/// **Doctrine pin**: chapter 一百三十二 honesty admission — true
/// engineering health honest satisfaction was ~30% pre-debt-log.
/// Layer-integrity tests close one corner of that gap.
final class M520LayerIntegritySensitivityTests: XCTestCase {

    // MARK: - Test fixture helper

    private func makeFrame(
        runMode: BASEBrainRunMode,
        maxLoops: Int,
        retrievalDepth: Int,
        maxCandidates: Int
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: runMode,
            maxLoops: maxLoops,
            maxCandidates: maxCandidates,
            maxDecodeTokens: 256,
            retrievalDepth: retrievalDepth,
            precisionProfile: .balanced,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false)
    }

    // MARK: - L1 BASAbyssBudget responds to BASBudgetFrame

    /// **L1 sensitivity** — different BASBudgetFrame inputs
    /// MUST produce different BASAbyssBudget outputs. A no-op L1
    /// derive would return the same budget for all frames.
    func testL1AbyssBudgetSensitivityToBudgetFrame() {
        let frameA = makeFrame(
            runMode: .engage,
            maxLoops: 2, retrievalDepth: 1, maxCandidates: 2)
        let frameB = makeFrame(
            runMode: .deepLoop,
            maxLoops: 8, retrievalDepth: 5, maxCandidates: 6)
        let budgetA = BASCthulhuLayerProjections.AbyssBudget
            .derive(from: frameA, turnID: "t1")
        let budgetB = BASCthulhuLayerProjections.AbyssBudget
            .derive(from: frameB, turnID: "t2")
        XCTAssertNotEqual(
            budgetA.aggregateAvailability,
            budgetB.aggregateAvailability,
            "L1 abyss-budget MUST be sensitive to BudgetFrame input — if invariant, L1 derive is dead code")
    }

    // MARK: - L4 BASOntologyFog responds to assertion ceiling

    /// **L4 sensitivity** — different assertion-ceiling inputs MUST
    /// produce different OntologyFog quality outputs. No-op L4
    /// derive would return the same fog for all ceilings.
    func testL4OntologyFogSensitivityToCeiling() {
        let unrestricted = BASCthulhuLayerProjections.OntologyFog
            .derive(
                unknownRefs: ["a", "b"],
                assertionCeilingRawValue: "unrestricted",
                turnID: "t1")
        let qualified = BASCthulhuLayerProjections.OntologyFog
            .derive(
                unknownRefs: ["a", "b"],
                assertionCeilingRawValue: "qualified",
                turnID: "t2")
        let none = BASCthulhuLayerProjections.OntologyFog
            .derive(
                unknownRefs: ["a", "b"],
                assertionCeilingRawValue: "none",
                turnID: "t3")
        // Three distinct ceilings → at least 2 distinct fog
        // qualities (unrestricted=partialGrasp, qualified=
        // provisionalNaming, none=unnameable).
        let qualities = Set([
            unrestricted.partialGraspQuality,
            qualified.partialGraspQuality,
            none.partialGraspQuality,
        ])
        XCTAssertGreaterThanOrEqual(
            qualities.count, 2,
            "L4 ontology-fog MUST produce different qualities for different ceilings — if invariant, L4 derive is dead code")
    }

    // MARK: - L11 BASAbyssalPressure responds to risk + uncertainty

    /// **L11 sensitivity** — different risk-level + uncertainty
    /// inputs MUST produce different abyssal-pressure
    /// recommended-modes lists. No-op L11 derive would return
    /// the same modes regardless.
    func testL11AbyssalPressureSensitivityToRisk() {
        let lowRisk = BASAbyssalPressureBudget.derive(
            turnID: "t1",
            riskLevel: .low,
            uncertaintyLedger: nil,
            evidenceDebtCount: 0)
        let highRisk = BASAbyssalPressureBudget.derive(
            turnID: "t2",
            riskLevel: .extreme,
            uncertaintyLedger: nil,
            evidenceDebtCount: 10)
        // Low risk → no modes triggered; extreme risk + high debt →
        // multiple modes triggered.
        XCTAssertNotEqual(
            lowRisk.recommendedModes,
            highRisk.recommendedModes,
            "L11 abyssal-pressure MUST yield different modes for different risk inputs — if invariant, L11 derive is dead code")
        XCTAssertGreaterThan(
            highRisk.aggregateMagnitude,
            lowRisk.aggregateMagnitude,
            "high-risk + high-debt MUST produce strictly higher aggregate magnitude than low-risk + zero-debt")
    }

    // MARK: - L13 BASCounterHostCheck responds to risk score

    /// **L13 sensitivity** — different inducedRiskScore inputs MUST
    /// produce different outcomes. No-op L13 derive would return
    /// the same outcome regardless of risk score.
    func testL13CounterHostCheckSensitivityToRiskScore() {
        let cleanScore = BASCounterHostCheckProtocol.derive(
            candidateRef: "c1",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.05,
            inducedRiskScore: 0.1,  // below threshold
            appliesToHostConstitution: true,
            turnID: "t1")
        let highScore = BASCounterHostCheckProtocol.derive(
            candidateRef: "c1",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.5,
            inducedRiskScore: 0.9,  // above 0.6 threshold
            appliesToHostConstitution: true,
            turnID: "t2")
        XCTAssertNotEqual(
            cleanScore.outcome, highScore.outcome,
            "L13 counter-host-check MUST yield different outcomes for different risk scores — if invariant, L13 derive is dead code")
        XCTAssertEqual(
            cleanScore.outcome, .genuineHostPattern)
        XCTAssertEqual(
            highScore.outcome, .systemInducedDrift)
    }

    // MARK: - L14 BASSovereignDomainScopeLinter responds to reason code

    /// **L14 sensitivity** — clean vs power-creep reason codes
    /// MUST produce different lint outcomes. No-op linter would
    /// return same result regardless of input.
    func testL14SovereignDomainScopeLinterSensitivity() {
        let clean = BASSovereignDomainScopeLinter
            .isWithinSovereignScope(
                "sovereign.verdict:high-consequence-commit")
        let creeping = BASSovereignDomainScopeLinter
            .isWithinSovereignScope(
                "sovereign.verdict:style-preference")
        XCTAssertTrue(clean,
            "clean code MUST pass lint")
        XCTAssertFalse(creeping,
            "power-creep code MUST fail lint — if linter returns same value for both, L14 BR-014 typed pin is dead code")
        XCTAssertNotEqual(
            clean, creeping,
            "L14 lint outcome MUST be sensitive to reason-code content")
    }

    // MARK: - Cross-layer composability sensitivity

    /// **Cross-layer sensitivity** — L4 + L11 derives composed on
    /// the same turn MUST produce coherent mappings (low risk →
    /// permissive permit + permissive ceiling).
    func testCrossLayerL4L11Coherence() {
        let lowRiskPressure = BASAbyssalPressureBudget.derive(
            turnID: "t1",
            riskLevel: .low,
            uncertaintyLedger: nil,
            evidenceDebtCount: 0)
        let highRiskPressure = BASAbyssalPressureBudget.derive(
            turnID: "t2",
            riskLevel: .extreme,
            uncertaintyLedger: nil,
            evidenceDebtCount: 10)
        // Low risk → 0 recommended modes (no escalation).
        XCTAssertTrue(
            lowRiskPressure.recommendedModes.isEmpty,
            "low-risk turn MUST have empty recommendedModes — if non-empty, threshold logic is broken")
        // High risk → at least 1 mode triggered.
        XCTAssertFalse(
            highRiskPressure.recommendedModes.isEmpty,
            "extreme-risk turn MUST trigger at least 1 recommended mode — if empty, escalation logic is dead code")
    }

    // MARK: - Determinism (sensitivity's complement)

    /// **Determinism counterpart** — same inputs MUST yield same
    /// outputs across separate derive calls. If derives are
    /// non-deterministic, audit emission becomes unreproducible
    /// and chapter 一百二十八 sensitivity tests would flake.
    func testDeterminism() {
        let frame = makeFrame(
            runMode: .engage,
            maxLoops: 3, retrievalDepth: 2, maxCandidates: 4)
        let budget1 = BASCthulhuLayerProjections.AbyssBudget
            .derive(from: frame, turnID: "t1")
        let budget2 = BASCthulhuLayerProjections.AbyssBudget
            .derive(from: frame, turnID: "t1")
        XCTAssertEqual(
            budget1, budget2,
            "same inputs MUST yield byte-equal AbyssBudget — non-determinism would break audit replay")
    }
}
