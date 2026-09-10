import XCTest
@testable import QinaoRisk

/// M85 — L12 柔手 × L9 dream-cycle counterfactual evidence tests.
///
/// M75 gave `QinaoRiskGate` a pure surface-matrix projection from
/// a `RiskAssessment`. M85 adds an enriched overload that accepts a
/// `CounterfactualEvidence` value (copied from L9's
/// `QinaoLoop.DreamCycleOutcome.CandidateCounterfactualView`) and
/// optionally rewrites the surface when the dream-cycle evidence
/// alone would trip L9's guardian threshold (aggregated contradiction
/// ≥ 0.7).
///
/// These tests pin:
///
/// 1. **Upgrade fires only on upgradeable surfaces** — `.allow`
///    (draftShell) and non-consent `.replace` (comparePanel) upgrade
///    to boundaryScript + explicit + requestConsent when the
///    threshold is crossed. `.block` / `.delay` / consent-required
///    `.replace` stay stringent regardless (their surfaces already
///    disclose).
///
/// 2. **Threshold boundary** — crossesGuardianThreshold is true at
///    exactly 0.7 and above; false strictly below.
///
/// 3. **Evidence clamping** — aggregatedContradiction clamps to
///    [0, 1]; branch counts clamp to ≥0. `branchesExamined` is the
///    sum invariant.
///
/// 4. **Dominant-signal labelling** — 5 stable strings mapped from
///    the three branch tallies.
///
/// 5. **Reason-code preservation** — an upgrade appends
///    `"world-prior-contradiction-counterfactual"` without losing
///    the assessment's original reason codes; a repeated upgrade
///    doesn't duplicate the marker.
///
/// 6. **Codable round-trip** — CounterfactualEvidence and
///    EnrichedSurfaceAction survive JSON.
///
/// 7. **Actor convenience** — `requestSurfaceAction(for:
///    counterfactualEvidence:)` composes `assess` + the enriched
///    projector.
final class QinaoRiskSurfaceMatrixDreamCycleTests: XCTestCase {

    // MARK: - Fixtures

    private func makeSignals(
        harmSeverity: Double = 0.1,
        irreversibility: Double = 0.1,
        manipulationIntensity: Double = 0.0,
        gsiScore: Double = 0.0,
        uncertainty: Double = 0.1,
        evidenceDebt: Double = 0.1
    ) -> QinaoRiskGate.RiskSignals {
        QinaoRiskGate.RiskSignals(
            harmSeverity: harmSeverity,
            irreversibility: irreversibility,
            uncertainty: uncertainty,
            evidenceDebt: evidenceDebt,
            manipulationIntensity: manipulationIntensity,
            gsiScore: gsiScore)
    }

    // MARK: - CounterfactualEvidence init clamping

    func testEvidenceClampsAggregatedContradictionToUnitInterval() {
        let low = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: -5,
            branchesExposedInsufficient: 0,
            branchesEqualEvidence: 0,
            branchesRobustlySurvived: 0)
        XCTAssertEqual(low.aggregatedContradiction, 0, accuracy: 1e-12)

        let high = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 5,
            branchesExposedInsufficient: 0,
            branchesEqualEvidence: 0,
            branchesRobustlySurvived: 0)
        XCTAssertEqual(high.aggregatedContradiction, 1, accuracy: 1e-12)
    }

    func testEvidenceClampsBranchCountsToNonNegative() {
        let e = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.5,
            branchesExposedInsufficient: -3,
            branchesEqualEvidence: -1,
            branchesRobustlySurvived: -7)
        XCTAssertEqual(e.branchesExposedInsufficient, 0)
        XCTAssertEqual(e.branchesEqualEvidence, 0)
        XCTAssertEqual(e.branchesRobustlySurvived, 0)
    }

    func testEvidenceBranchesExaminedIsSumInvariant() {
        let e = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.4,
            branchesExposedInsufficient: 1,
            branchesEqualEvidence: 2,
            branchesRobustlySurvived: 4)
        XCTAssertEqual(e.branchesExamined, 7)
    }

    // MARK: - Dominant signal × 5

    func testEvidenceDominantSignalNoBranches() {
        let e = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0,
            branchesExposedInsufficient: 0,
            branchesEqualEvidence: 0,
            branchesRobustlySurvived: 0)
        XCTAssertEqual(e.dominantSignal, "no-branches")
    }

    func testEvidenceDominantSignalExposedInsufficient() {
        let e = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 1,
            branchesExposedInsufficient: 4,
            branchesEqualEvidence: 1,
            branchesRobustlySurvived: 0)
        XCTAssertEqual(e.dominantSignal, "exposed-insufficient-dominant")
    }

    func testEvidenceDominantSignalEqualEvidence() {
        let e = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.5,
            branchesExposedInsufficient: 0,
            branchesEqualEvidence: 5,
            branchesRobustlySurvived: 1)
        XCTAssertEqual(e.dominantSignal, "equal-evidence-dominant")
    }

    func testEvidenceDominantSignalRobustSurvival() {
        let e = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0,
            branchesExposedInsufficient: 0,
            branchesEqualEvidence: 1,
            branchesRobustlySurvived: 4)
        XCTAssertEqual(e.dominantSignal, "robust-survival-dominant")
    }

    func testEvidenceDominantSignalBalancedWhenEqualToOthers() {
        let e = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.5,
            branchesExposedInsufficient: 2,
            branchesEqualEvidence: 2,
            branchesRobustlySurvived: 2)
        XCTAssertEqual(e.dominantSignal, "balanced")
    }

    // MARK: - Threshold

    func testCrossesGuardianThresholdAtExactly07() {
        let atThreshold = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.7,
            branchesExposedInsufficient: 0,
            branchesEqualEvidence: 0,
            branchesRobustlySurvived: 0)
        XCTAssertTrue(atThreshold.crossesGuardianThreshold)

        let below = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.699,
            branchesExposedInsufficient: 0,
            branchesEqualEvidence: 0,
            branchesRobustlySurvived: 0)
        XCTAssertFalse(below.crossesGuardianThreshold)
    }

    // MARK: - Upgrade path: allow + threshold crossed

    func testUpgradeFromAllowDraftShellToBoundaryScript() {
        let signals = makeSignals()  // baseline allow
        let evidence = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.8,
            branchesExposedInsufficient: 3,
            branchesEqualEvidence: 0,
            branchesRobustlySurvived: 0)

        let assessment = QinaoRiskGate.assess(signals)
        XCTAssertEqual(assessment.mode, .allow)

        let enriched = QinaoRiskGate.surfaceAction(
            for: assessment,
            counterfactualEvidence: evidence,
            candidateIDs: ["c1"])

        XCTAssertTrue(enriched.upgraded)
        XCTAssertEqual(enriched.base.surface, .boundaryScript)
        XCTAssertEqual(enriched.base.agency, .userAffirm)
        XCTAssertEqual(enriched.base.disclosure, .explicit)
        switch enriched.base.substitute {
        case .requestConsent(let key):
            XCTAssertEqual(key, "dream-cycle-counterfactual-concern")
        default:
            XCTFail("expected .requestConsent")
        }
        XCTAssertTrue(
            enriched.base.reasonCodes.contains(
                "world-prior-contradiction-counterfactual"))
    }

    // MARK: - Upgrade path: replace (non-consent) + threshold crossed

    func testUpgradeFromReplaceComparePanelToBoundaryScript() {
        // Pressure-driven replace: high manipulationIntensity →
        // mirror-and-compare replace, not consent-required.
        let signals = makeSignals(manipulationIntensity: 0.9)
        let evidence = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.85,
            branchesExposedInsufficient: 3,
            branchesEqualEvidence: 1,
            branchesRobustlySurvived: 0)

        let assessment = QinaoRiskGate.assess(signals)
        XCTAssertEqual(assessment.mode, .replace)
        XCTAssertFalse(assessment.reasonCodes.contains("consent-required"))

        let enriched = QinaoRiskGate.surfaceAction(
            for: assessment,
            counterfactualEvidence: evidence,
            candidateIDs: ["c1", "c2"])

        XCTAssertTrue(enriched.upgraded)
        XCTAssertEqual(enriched.base.surface, .boundaryScript)
        XCTAssertEqual(enriched.base.agency, .userAffirm)
        XCTAssertEqual(enriched.base.disclosure, .explicit)
    }

    // MARK: - No upgrade: allow + threshold NOT crossed

    func testNoUpgradeWhenAllowBelowThresholdReturnsDraftShell() {
        let signals = makeSignals()
        let evidence = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.3,
            branchesExposedInsufficient: 1,
            branchesEqualEvidence: 2,
            branchesRobustlySurvived: 0)

        let assessment = QinaoRiskGate.assess(signals)
        let enriched = QinaoRiskGate.surfaceAction(
            for: assessment,
            counterfactualEvidence: evidence,
            candidateIDs: ["c1"])

        XCTAssertFalse(enriched.upgraded)
        XCTAssertEqual(enriched.base.surface, .draftShell)
        XCTAssertFalse(
            enriched.base.reasonCodes.contains(
                "world-prior-contradiction-counterfactual"))
    }

    // MARK: - No upgrade on already-stringent surfaces

    func testNoUpgradeOnBlockAssessmentEvenAtThreshold() {
        // High harmSeverity triggers .block.
        let signals = makeSignals(harmSeverity: 0.95)
        let evidence = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 1.0,
            branchesExposedInsufficient: 5,
            branchesEqualEvidence: 0,
            branchesRobustlySurvived: 0)

        let assessment = QinaoRiskGate.assess(signals)
        XCTAssertEqual(assessment.mode, .block)

        let enriched = QinaoRiskGate.surfaceAction(
            for: assessment,
            counterfactualEvidence: evidence,
            auditReference: "audit-1")

        XCTAssertFalse(
            enriched.upgraded,
            "block already stringent; upgrade would duplicate signals")
        XCTAssertEqual(enriched.base.surface, .silentStub)
        // Evidence is still attached for audit even without upgrade.
        XCTAssertEqual(
            enriched.evidence.aggregatedContradiction,
            1.0,
            accuracy: 1e-12)
    }

    func testNoUpgradeOnDelayAssessmentEvenAtThreshold() {
        // Moderate uncertainty → .delay.
        let signals = makeSignals(uncertainty: 0.75)
        let evidence = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.9,
            branchesExposedInsufficient: 2,
            branchesEqualEvidence: 1,
            branchesRobustlySurvived: 0)

        let assessment = QinaoRiskGate.assess(signals)
        XCTAssertEqual(assessment.mode, .delay)

        let enriched = QinaoRiskGate.surfaceAction(
            for: assessment,
            counterfactualEvidence: evidence)

        XCTAssertFalse(enriched.upgraded)
        XCTAssertEqual(enriched.base.surface, .delayPacket)
    }

    // MARK: - Repeated upgrade does not duplicate marker

    func testRepeatedUpgradeDoesNotDuplicateReasonMarker() {
        // Assessment that will upgrade.
        let signals = makeSignals()
        let evidence = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.85,
            branchesExposedInsufficient: 3,
            branchesEqualEvidence: 0,
            branchesRobustlySurvived: 0)
        let assessment = QinaoRiskGate.assess(signals)
        let first = QinaoRiskGate.surfaceAction(
            for: assessment,
            counterfactualEvidence: evidence,
            candidateIDs: ["c1"])

        // Fabricate a second assessment whose reason codes already
        // include the marker (simulating a second projection
        // downstream of the first).
        let alreadyMarked = QinaoRiskGate.RiskAssessment(
            mode: assessment.mode,
            reasonCodes: first.base.reasonCodes,
            recommendedDelaySeconds: assessment.recommendedDelaySeconds,
            substituteHint: assessment.substituteHint)
        let second = QinaoRiskGate.surfaceAction(
            for: alreadyMarked,
            counterfactualEvidence: evidence,
            candidateIDs: ["c1"])

        let markerCount = second.base.reasonCodes.filter {
            $0 == "world-prior-contradiction-counterfactual"
        }.count
        XCTAssertEqual(markerCount, 1,
            "re-upgrading must not duplicate the marker")
    }

    // MARK: - Preserves pre-existing reason codes

    func testUpgradePreservesOriginalReasonCodes() {
        // Replace with manipulationIntensity emits reasons like
        // "manipulation-intensity-high". Those should survive the
        // upgrade alongside the new marker.
        let signals = makeSignals(manipulationIntensity: 0.9)
        let evidence = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.85,
            branchesExposedInsufficient: 3,
            branchesEqualEvidence: 0,
            branchesRobustlySurvived: 0)
        let assessment = QinaoRiskGate.assess(signals)
        // Snapshot original reasons BEFORE upgrading.
        let originalReasons = assessment.reasonCodes
        XCTAssertFalse(originalReasons.isEmpty)

        let enriched = QinaoRiskGate.surfaceAction(
            for: assessment,
            counterfactualEvidence: evidence,
            candidateIDs: ["c1", "c2"])

        XCTAssertTrue(enriched.upgraded)
        for reason in originalReasons {
            XCTAssertTrue(
                enriched.base.reasonCodes.contains(reason),
                "upgrade must preserve original reason '\(reason)'")
        }
        XCTAssertTrue(
            enriched.base.reasonCodes.contains(
                "world-prior-contradiction-counterfactual"))
    }

    // MARK: - Codable round-trip

    func testCounterfactualEvidenceCodableRoundTrip() throws {
        let original = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.6666,
            branchesExposedInsufficient: 1,
            branchesEqualEvidence: 2,
            branchesRobustlySurvived: 0)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(original)
        let decoded = try JSONDecoder().decode(
            QinaoRiskGate.CounterfactualEvidence.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testEnrichedSurfaceActionCodableRoundTrip() throws {
        let signals = makeSignals()
        let evidence = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.85,
            branchesExposedInsufficient: 3,
            branchesEqualEvidence: 0,
            branchesRobustlySurvived: 0)
        let assessment = QinaoRiskGate.assess(signals)
        let original = QinaoRiskGate.surfaceAction(
            for: assessment,
            counterfactualEvidence: evidence,
            candidateIDs: ["c1"])
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(original)
        let decoded = try JSONDecoder().decode(
            QinaoRiskGate.EnrichedSurfaceAction.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Actor convenience

    func testRequestSurfaceActionWithEvidenceComposesAssessAndProject()
        async {
        let gate = QinaoRiskGate()
        let signals = makeSignals()
        let evidence = QinaoRiskGate.CounterfactualEvidence(
            aggregatedContradiction: 0.85,
            branchesExposedInsufficient: 3,
            branchesEqualEvidence: 0,
            branchesRobustlySurvived: 0)
        let enriched = await gate.requestSurfaceAction(
            for: signals,
            counterfactualEvidence: evidence,
            candidateIDs: ["c1"])
        XCTAssertTrue(enriched.upgraded)
        XCTAssertEqual(enriched.base.surface, .boundaryScript)
    }
}
