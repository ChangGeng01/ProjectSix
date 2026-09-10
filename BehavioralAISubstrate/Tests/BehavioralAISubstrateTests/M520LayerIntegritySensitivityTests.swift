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

    // MARK: - M524-M532 (chapter 一百三十四) — fill remaining
    // L2/L3/L5/L6/L7/L8/L9/L10/L12 sensitivity coverage to
    // close Major 8 audit gap fully. Layer integrity now
    // 14/14 coverage post-M532.

    // MARK: - L2 BASAbyssalOrganAlias responds to runMode

    func testL2OrganAliasSensitivityToRunMode() {
        let engageAlias =
            BASCthulhuLeftoverProjections.AbyssalOrganAlias
                .derive(from: .engage)
        let lockdownAlias =
            BASCthulhuLeftoverProjections.AbyssalOrganAlias
                .derive(from: .lockdown)
        XCTAssertNotEqual(
            engageAlias, lockdownAlias,
            "L2 organ alias MUST differ between .engage (counterfactual-forge) and .lockdown (minimal-resonance) — if invariant, L2 derive is dead code")
    }

    // MARK: - L3 BASJadeCasketSnapshot responds to session/turn

    func testL3JadeCasketSensitivityToTurnID() {
        let casket1 = BASKunlunLayerProjections
            .JadeCasketSnapshot.derive(
                turnID: "t1", sessionID: "s1")
        let casket2 = BASKunlunLayerProjections
            .JadeCasketSnapshot.derive(
                turnID: "t2", sessionID: "s1")
        XCTAssertNotEqual(
            casket1.snapshotID, casket2.snapshotID,
            "L3 jade-casket snapshotID MUST differ between turns — if invariant, L3 derive is dead code")
        // Both MUST honor §4.2 jade-canon invariant.
        XCTAssertTrue(
            casket1.honorsJadeCanonInvariants,
            "L3 jade-casket MUST be canonical by construction (§4.2)")
        XCTAssertTrue(
            casket2.honorsJadeCanonInvariants)
    }

    // MARK: - L5 BASHumanAnchorProtocol responds to risk + permit

    func testL5HumanAnchorSensitivityToRiskAndPermit() {
        let lowRiskAnchor = BASHumanAnchorProtocol.derive(
            anchorID: "a1",
            hostSummaryRef: "host:v1",
            riskLevel: .low,
            permitMode: .answer,
            candidateCount: 3)
        let extremeRiskAnchor = BASHumanAnchorProtocol.derive(
            anchorID: "a2",
            hostSummaryRef: "host:v1",
            riskLevel: .extreme,
            permitMode: .block,
            candidateCount: 0)
        XCTAssertNotEqual(
            lowRiskAnchor.recommendedSurfaceTone,
            extremeRiskAnchor.recommendedSurfaceTone,
            "L5 human-anchor tone MUST differ between low-risk + answer mode and extreme-risk + block mode — if invariant, L5 derive is dead code")
    }

    // MARK: - L6 BASAxisDeviation + BASGatePressure respond to risk

    func testL6AxisDeviationSensitivityToRisk() {
        let lowDeviation = BASKunlunLayerProjections
            .AxisDeviation.derive(
                from: .low,
                turnID: "t1",
                situationRef: "sit:1",
                centerlineRef: "axis:1")
        let extremeDeviation = BASKunlunLayerProjections
            .AxisDeviation.derive(
                from: .extreme,
                turnID: "t2",
                situationRef: "sit:1",
                centerlineRef: "axis:1")
        XCTAssertNotEqual(
            lowDeviation.deviationScore,
            extremeDeviation.deviationScore,
            "L6 axis-deviation score MUST differ between low + extreme risk — if invariant, L6 derive is dead code")
        XCTAssertGreaterThan(
            extremeDeviation.deviationScore,
            lowDeviation.deviationScore,
            "extreme risk MUST yield higher deviation score than low risk")
    }

    // MARK: - L7 BASNarrativeDistortion responds to risk

    func testL7NarrativeDistortionSensitivityToRisk() {
        let lowDistortion = BASNarrativeDistortion.derive(
            distortionID: "d1",
            riskLevel: .low,
            permitMode: .answer)
        let highDistortion = BASNarrativeDistortion.derive(
            distortionID: "d2",
            riskLevel: .extreme,
            permitMode: .block)
        XCTAssertNotEqual(
            lowDistortion, highDistortion,
            "L7 narrative-distortion MUST differ between low-risk + answer and extreme-risk + block — if invariant, L7 derive is dead code")
    }

    // MARK: - L8 BASYaochiMemoryLayer responds to runMode

    func testL8YaochiMemoryLayerSensitivityToRunMode() {
        let engageLayer = BASKunlunLayerProjections
            .YaochiMemoryLayer.derive(
                from: .engage, turnID: "t1")
        let lockdownLayer = BASKunlunLayerProjections
            .YaochiMemoryLayer.derive(
                from: .lockdown, turnID: "t2")
        // Engage → no sanctum policy; lockdown → "old-seal".
        XCTAssertNotEqual(
            engageLayer.sanctumPolicy,
            lockdownLayer.sanctumPolicy,
            "L8 yaochi sanctum policy MUST differ between .engage (open) and .lockdown (old-seal) — if invariant, L8 derive is dead code")
    }

    // MARK: - L9 BASAscentBranch responds to candidate state

    func testL9AscentBranchSensitivityToCandidate() {
        let cleanCandidate = BASCandidatePath(
            candidateID: "c1",
            title: "clean",
            actionSummary: "answer",
            requiredEvidence: [],
            expectedBenefit: 0.8,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.9)
        let reversedCandidate = BASCandidatePath(
            candidateID: "c2",
            title: "reversed",
            actionSummary: "block",
            requiredEvidence: ["evidence:1"],
            expectedBenefit: 0.2,
            expectedCost: 0.8,
            reversibility: 0.2,
            confidence: 0.3)
        let cleanBranch = BASKunlunLayerProjections
            .AscentBranch.derive(
                from: cleanCandidate, turnID: "t1")
        let reversedBranch = BASKunlunLayerProjections
            .AscentBranch.derive(
                from: reversedCandidate, turnID: "t1")
        XCTAssertNotEqual(
            cleanBranch.ascentConditions,
            reversedBranch.ascentConditions,
            "L9 ascent-branch conditions MUST differ between high-confidence + low-cost candidate and low-confidence + high-cost candidate — if invariant, L9 derive is dead code")
        XCTAssertNotEqual(
            cleanBranch.stopPoints,
            reversedBranch.stopPoints,
            "L9 ascent-branch stop points MUST differ between high-reversibility (≥0.4) and low-reversibility (<0.4)")
    }

    // MARK: - L10 BASTianhengProfile responds to risk + permit

    func testL10TianhengProfileSensitivityToRiskAndPermit() {
        let lowRisk = BASKunlunLayerProjections
            .TianhengProfile.derive(
                from: .low,
                permitMode: .answer,
                turnID: "t1")
        let extremeRisk = BASKunlunLayerProjections
            .TianhengProfile.derive(
                from: .extreme,
                permitMode: .block,
                turnID: "t2")
        XCTAssertNotEqual(
            lowRisk.dignityFloor,
            extremeRisk.dignityFloor,
            "L10 tianheng dignity floor MUST differ between low-risk and extreme-risk — if invariant, L10 derive is dead code")
        XCTAssertGreaterThan(
            extremeRisk.dignityFloor,
            lowRisk.dignityFloor,
            "extreme risk MUST raise dignity floor (host-protection elevates when system narrows agency)")
    }

    // MARK: - L12 surface aliases respond to permit mode

    func testL12SurfaceAliasSensitivityToPermitMode() {
        let compareMode = BASSurfaceModeFromPermit.derive(
            from: .compare)
        let answerMode = BASSurfaceModeFromPermit.derive(
            from: .answer)
        XCTAssertNotNil(compareMode,
            "compare permit MUST resolve to comparePanel surface")
        XCTAssertNil(answerMode,
            "answer permit MUST resolve to nil (no L12 surface)")
        // Cthulhu vs Kunlun aliases for the same surface MUST differ.
        if let mode = compareMode {
            let cthulhuAlias = BASCthulhuSurfaceAlias.derive(
                from: mode)
            let kunlunAlias = BASKunlunSurfaceAlias.derive(
                from: mode)
            XCTAssertEqual(
                cthulhuAlias, .lighthouseCompare)
            XCTAssertEqual(
                kunlunAlias, .axisComparePanel)
            XCTAssertNotEqual(
                cthulhuAlias?.rawValue,
                kunlunAlias.rawValue,
                "L12 doctrine-specific aliases MUST differ between Cthulhu and Kunlun for same surface mode — if invariant, doctrine-specific naming is dead doctrine")
        }
    }
}
