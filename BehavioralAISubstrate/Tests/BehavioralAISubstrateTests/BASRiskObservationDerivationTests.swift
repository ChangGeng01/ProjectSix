import XCTest
@testable import BASOrchestration
@testable import BASPolicy

/// M56 — L11 risk climate main-chain wiring.
///
/// The M26 per-dimension risk observation primitives (shape covered
/// by `BASRiskObservationTests`) were originally emitted only by
/// hand-crafted test helpers; the coordinator never produced a
/// bundle on the main-chain thought frame. These tests pin the
/// main-chain behavior:
///
///   1. `BASRiskObservationBundle.derive(from:turnID:sessionID:
///      emittedAt:)` emits a bundle whose contents deterministically
///      mirror the thought frame's risk records (same frame → same
///      bundle byte-for-byte).
///   2. Each of the six risk signal kinds (.hazardReading /
///      .irreversibilityReading / .harmPotentialReading /
///      .consequenceHorizonReading / .noveltyReading / .gatePressure)
///      is emitted iff the frame carries structural evidence for it.
///      A frame with no bindings and no package produces zero
///      observations.
///   3. Per-binding derivation is the primary path; package-level
///      fallback only fires when `riskBindings` is empty and the
///      package is present.
///   4. Signal payloads (salience / confidence / content) are
///      computed from the frame's records — no magic constants
///      smuggled in.
///   5. `BASThoughtFrame.withDerivedRiskObservationBundle(...)`
///      returns a copy with the bundle attached and leaves every
///      other field untouched.
///   6. The bundle feeds the M32 `.riskClimate` coverage projection
///      (`hasCoreSignalCoverage` == all three pillars present,
///      `distinctSubjectCount` == distinct intentIDs).
///   7. Budget stays clamped in [0, 1] even when many signals are
///      emitted simultaneously.
///   8. Legacy pre-M56 frames (persisted without the new key)
///      decode with `riskObservationBundle == nil`.
final class BASRiskObservationDerivationTests: XCTestCase {

    // MARK: - Fixtures

    private let fixedDate = Date(timeIntervalSince1970: 1_000_000)

    /// Builds a thought frame with only the risk-relevant records
    /// populated. Non-risk fields stay at their defaults — tests
    /// only need to control `riskBindings` and `riskDecisionPackage`
    /// for the derive behavior to be testable.
    private func frame(
        riskBindings: [BASRiskPermitBinding]? = nil,
        riskDecisionPackage: BASRiskDecisionPackage? = nil
    ) -> BASThoughtFrame {
        BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "d-1",
            riskBindings: riskBindings,
            riskDecisionPackage: riskDecisionPackage
        )
    }

    private func binding(
        candidateID: String = "cand-1",
        riskLevel: BASBrainRiskLevel = .medium,
        totalRisk: Double = 0.5,
        uncertainty: Double = 0.2,
        irreversibility: Double = 0.4,
        manipulationStrength: Double = 0.0,
        gsiScore: Double = 0.3,
        recommendedMode: BASActionPermitMode = .answer,
        permitMode: BASActionPermitMode = .answer,
        requireSecondCheck: Bool = false,
        assertionCeiling: String? = "standard",
        sovereignHintLevel: String? = "low"
    ) -> BASRiskPermitBinding {
        BASRiskPermitBinding(
            candidateID: candidateID,
            riskLevel: riskLevel,
            totalRisk: totalRisk,
            uncertainty: uncertainty,
            irreversibility: irreversibility,
            manipulationStrength: manipulationStrength,
            gsiScore: gsiScore,
            recommendedMode: recommendedMode,
            permitMode: permitMode,
            assertionCeiling: assertionCeiling,
            requireSecondCheck: requireSecondCheck,
            outputLengthCap: 200,
            tonePolicy: "grounded",
            templatePolicy: "default",
            sovereignHintLevel: sovereignHintLevel
        )
    }

    private func package(
        candidateRef: String = "cand-1",
        totalRisk: Double = 0.5,
        riskLevel: BASBrainRiskLevel = .medium,
        uncertainty: Double = 0.2,
        irreversibility: Double = 0.4,
        manipulationIntensity: Double = 0.0,
        longTermTrace: Double = 0.3,
        publicImpact: Double = 0.2,
        decisionMode: BASActionPermitMode = .answer,
        permitMode: BASActionPermitMode = .answer
    ) -> BASRiskDecisionPackage {
        BASRiskDecisionPackage(
            packageID: "pkg-1",
            riskCard: BASRiskCard(
                totalRisk: totalRisk,
                riskLevel: riskLevel,
                uncertainty: uncertainty,
                irreversibility: irreversibility,
                manipulationStrength: manipulationIntensity,
                gsiScore: 0.3,
                recommendedMode: decisionMode),
            riskField: BASRiskField(
                fieldID: "field-1",
                candidateRef: candidateRef,
                hazardVector: BASHazardVector(
                    harmSeverity: totalRisk,
                    harmScope: totalRisk,
                    irreversibility: irreversibility,
                    uncertainty: uncertainty,
                    evidenceDebt: uncertainty,
                    manipulationIntensity: manipulationIntensity,
                    pressureAuthenticity: 0.5,
                    vulnerabilityCoupling: 0.3,
                    sideEffectScope: 0.3),
                harmRadius: BASHarmRadiusMap(
                    radiusID: "r-1",
                    privateImpact: 0.2,
                    relationImpact: 0.2,
                    workflowImpact: 0.2,
                    publicImpact: publicImpact,
                    longTermTrace: longTermTrace),
                reversibilityProfile: BASReversibilityProfile(
                    profileID: "rv-1",
                    reversible: irreversibility < 0.5,
                    rollbackCost: irreversibility,
                    draftSafe: true,
                    smallStepPossible: true),
                evidenceSufficiency: BASEvidenceSufficiency(
                    sufficiencyID: "ev-1",
                    supportLevel: 0.5,
                    allowedAssertionLevel: "standard",
                    allowedActionLevel: "standard"),
                gsiTrace: BASGSITrace(
                    traceID: "gsi-1",
                    coerciveUrgency: 0.2,
                    shamePressure: 0.2,
                    authorityMask: 0.2,
                    relationLeverage: 0.2,
                    susceptibilityBand: "normal"),
                vulnerabilityCoupling: BASVulnerabilityCoupling(
                    couplingID: "vc-1",
                    lowEnergyResonance: 0.2,
                    sensitivityWindow: 0.2,
                    protectionBias: 0.2),
                confidenceBand: "normal"),
            actionModeDecision: BASActionModeDecision(
                decisionID: "dec-1",
                primaryMode: decisionMode,
                confidence: 0.8),
            actionPermit: BASActionPermit(mode: permitMode))
    }

    // MARK: - 1. Emission

    func testDeriveEmitsZeroObservationsOnEmptyFrame() {
        // A frame with no risk records at all must produce an empty
        // bundle — this is the "light turn" invariant the risk
        // contract shares with L6/L7/L9/L10.
        let f = frame()
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t-1",
            sessionID: "s-1",
            emittedAt: fixedDate)

        XCTAssertTrue(bundle.observations.isEmpty)
        XCTAssertEqual(bundle.turnID, "t-1")
        XCTAssertEqual(bundle.sessionID, "s-1")
        XCTAssertEqual(bundle.emittedAt, fixedDate)
    }

    func testDeriveEmitsThreeCoreSignalsPerBinding() {
        // Even a minimal binding must always emit the three core
        // pillars: hazard, irreversibility, harmPotential.
        let f = frame(riskBindings: [binding()])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(
            bundle.observations(of: .hazardReading).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .irreversibilityReading).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .harmPotentialReading).count, 1)
    }

    func testDeriveEmitsCoreTripleForEachBinding() {
        let f = frame(riskBindings: [
            binding(candidateID: "a"),
            binding(candidateID: "b"),
            binding(candidateID: "c")
        ])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        // 3 bindings × 3 core pillars = 9 core observations.
        XCTAssertEqual(
            bundle.observations(of: .hazardReading).count, 3)
        XCTAssertEqual(
            bundle.observations(of: .irreversibilityReading).count, 3)
        XCTAssertEqual(
            bundle.observations(of: .harmPotentialReading).count, 3)
        XCTAssertEqual(bundle.intentIDs.count, 3)
        XCTAssertEqual(bundle.intentIDs, ["a", "b", "c"])
    }

    func testDeriveFallsBackToPackageWhenBindingsEmpty() {
        // No bindings, but a package exists → package-level
        // observations must be emitted, intentID from candidateRef.
        let f = frame(riskDecisionPackage: package(
            candidateRef: "cand-pkg"))
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertFalse(bundle.observations.isEmpty)
        XCTAssertEqual(bundle.intentIDs, ["cand-pkg"])
        XCTAssertEqual(
            bundle.observations(of: .hazardReading).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .irreversibilityReading).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .harmPotentialReading).count, 1)
        // Package path always emits consequenceHorizon.
        XCTAssertEqual(
            bundle.observations(of: .consequenceHorizonReading).count,
            1)
    }

    func testDerivePrefersBindingsOverPackage() {
        // Both bindings and package populated → bindings drive the
        // per-intent stream; package is only used for the
        // consequenceHorizon enrichment.
        let f = frame(
            riskBindings: [binding(candidateID: "b-1")],
            riskDecisionPackage: package(candidateRef: "pkg-ref"))
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        // Single binding → single intentID, NOT the package's
        // candidateRef.
        XCTAssertEqual(bundle.intentIDs, ["b-1"])
    }

    func testDerivePerBindingConsequenceHorizonRequiresPackage() {
        // Bindings only, no package → no consequenceHorizon signal.
        let f = frame(riskBindings: [binding()])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertTrue(
            bundle.observations(of: .consequenceHorizonReading)
                .isEmpty)
    }

    func testDerivePerBindingConsequenceHorizonEmittedWhenPackagePresent()
    {
        let f = frame(
            riskBindings: [binding(candidateID: "b-1")],
            riskDecisionPackage: package(
                longTermTrace: 0.9,
                publicImpact: 0.4))
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let horizon = bundle
            .observations(of: .consequenceHorizonReading)
        XCTAssertEqual(horizon.count, 1)
        // salience = max(longTermTrace, publicImpact * 0.75)
        //         = max(0.9, 0.3) = 0.9
        XCTAssertEqual(
            horizon.first?.salience ?? 0,
            0.9,
            accuracy: 1e-9)
        XCTAssertEqual(horizon.first?.intentID, "b-1")
    }

    // MARK: - 2. Structural gating

    func testNoveltyReadingGatedOnUncertaintyAboveHalf() {
        // uncertainty ≤ 0.5 → no novelty signal
        let f = frame(riskBindings: [
            binding(candidateID: "low-u", uncertainty: 0.3),
            binding(candidateID: "exactly-half", uncertainty: 0.5)
        ])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertTrue(
            bundle.observations(of: .noveltyReading).isEmpty)
    }

    func testNoveltyReadingEmittedWhenUncertaintyOverHalf() {
        let f = frame(riskBindings: [
            binding(candidateID: "novel", uncertainty: 0.7)
        ])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let novelty = bundle.observations(of: .noveltyReading)
        XCTAssertEqual(novelty.count, 1)
        XCTAssertEqual(
            novelty.first?.salience ?? 0,
            0.7,
            accuracy: 1e-9)
        XCTAssertEqual(
            novelty.first?.confidence ?? 0,
            0.7,
            accuracy: 1e-9)
    }

    func testGatePressureSuppressedWhenStable() {
        // manipulation == 0 AND recommendedMode == permitMode →
        // no gatePressure emission.
        let f = frame(riskBindings: [
            binding(
                manipulationStrength: 0.0,
                recommendedMode: .answer,
                permitMode: .answer)
        ])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertTrue(
            bundle.observations(of: .gatePressure).isEmpty)
    }

    func testGatePressureEmittedOnManipulationOnly() {
        let f = frame(riskBindings: [
            binding(
                manipulationStrength: 0.4,
                recommendedMode: .answer,
                permitMode: .answer)
        ])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let pressure = bundle.observations(of: .gatePressure)
        XCTAssertEqual(pressure.count, 1)
        // No mode shift → salience = manipulation = 0.4
        XCTAssertEqual(
            pressure.first?.salience ?? 0,
            0.4,
            accuracy: 1e-9)
        XCTAssertTrue(
            pressure.first?.content.contains("modeShifted:false")
                ?? false)
    }

    func testGatePressureEmittedOnModeShiftOnly() {
        // manipulation == 0 but recommended ≠ permit → emit
        // pressure with salience ≥ 0.6 from mode-shift floor.
        let f = frame(riskBindings: [
            binding(
                manipulationStrength: 0.0,
                recommendedMode: .answer,
                permitMode: .delay)
        ])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let pressure = bundle.observations(of: .gatePressure)
        XCTAssertEqual(pressure.count, 1)
        XCTAssertEqual(
            pressure.first?.salience ?? 0,
            0.6,
            accuracy: 1e-9)
        XCTAssertTrue(
            pressure.first?.content.contains("modeShifted:true")
                ?? false)
        XCTAssertTrue(
            pressure.first?.content.contains("direction:tighten")
                ?? false)
    }

    // MARK: - 3. Payload fidelity

    func testHazardReadingSalienceTracksTotalRisk() throws {
        let f = frame(riskBindings: [
            binding(totalRisk: 0.73)
        ])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let hazard = try XCTUnwrap(
            bundle.observations(of: .hazardReading).first)
        XCTAssertEqual(hazard.salience, 0.73, accuracy: 1e-9)
    }

    func testIrreversibilityReadingSalienceTracksBinding() throws {
        let f = frame(riskBindings: [
            binding(irreversibility: 0.82)
        ])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let irr = try XCTUnwrap(
            bundle.observations(of: .irreversibilityReading).first)
        XCTAssertEqual(irr.salience, 0.82, accuracy: 1e-9)
    }

    func testHarmPotentialSeverityMapping() throws {
        let cases: [(BASBrainRiskLevel, Double)] = [
            (.low, 0.25),
            (.medium, 0.5),
            (.high, 0.75),
            (.extreme, 1.0)
        ]
        for (level, expected) in cases {
            let f = frame(riskBindings: [
                binding(candidateID: "x", riskLevel: level)
            ])
            let bundle = BASRiskObservationBundle.derive(
                from: f,
                turnID: "t",
                sessionID: "s",
                emittedAt: fixedDate)
            let hp = try XCTUnwrap(
                bundle.observations(of: .harmPotentialReading).first)
            XCTAssertEqual(
                hp.salience,
                expected,
                accuracy: 1e-9,
                "riskLevel \(level) should map to severity \(expected)")
        }
    }

    func testConfidenceIsOneMinusUncertainty() throws {
        // confidence should be 1 - uncertainty on all core
        // observations for a given binding (within a single turn).
        let f = frame(riskBindings: [
            binding(uncertainty: 0.3)
        ])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let expectedConfidence = 0.7
        let hazard = try XCTUnwrap(
            bundle.observations(of: .hazardReading).first)
        let irr = try XCTUnwrap(
            bundle.observations(of: .irreversibilityReading).first)
        let hp = try XCTUnwrap(
            bundle.observations(of: .harmPotentialReading).first)
        XCTAssertEqual(
            hazard.confidence, expectedConfidence, accuracy: 1e-9)
        XCTAssertEqual(
            irr.confidence, expectedConfidence, accuracy: 1e-9)
        XCTAssertEqual(
            hp.confidence, expectedConfidence, accuracy: 1e-9)
    }

    func testGatePressureDirectionReflectsModeShift() throws {
        // Tighten: recommendedMode rank < permitMode rank
        let tightenFrame = frame(riskBindings: [
            binding(
                recommendedMode: .answer,
                permitMode: .block)
        ])
        let tightenBundle = BASRiskObservationBundle.derive(
            from: tightenFrame,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let tighten = try XCTUnwrap(
            tightenBundle.observations(of: .gatePressure).first)
        XCTAssertTrue(
            tighten.content.contains("direction:tighten"))

        // Loosen: recommendedMode rank > permitMode rank
        let loosenFrame = frame(riskBindings: [
            binding(
                recommendedMode: .block,
                permitMode: .answer)
        ])
        let loosenBundle = BASRiskObservationBundle.derive(
            from: loosenFrame,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let loosen = try XCTUnwrap(
            loosenBundle.observations(of: .gatePressure).first)
        XCTAssertTrue(
            loosen.content.contains("direction:loosen"))
    }

    // MARK: - 4. Determinism

    func testDeriveIsDeterministicForSameFrame() {
        let f = frame(
            riskBindings: [
                binding(candidateID: "a", uncertainty: 0.6),
                binding(
                    candidateID: "b",
                    manipulationStrength: 0.3,
                    recommendedMode: .answer,
                    permitMode: .delay)
            ],
            riskDecisionPackage: package(longTermTrace: 0.5))
        let first = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let second = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertEqual(first, second)
    }

    // MARK: - 5. withDerived helper contract

    func testWithDerivedBundleAttachesBundleOnCopy() {
        let f = frame(riskBindings: [binding()])
        let enriched = f.withDerivedRiskObservationBundle(
            turnID: "t-2",
            sessionID: "s-2",
            emittedAt: fixedDate)

        XCTAssertNil(f.riskObservationBundle)
        XCTAssertNotNil(enriched.riskObservationBundle)
        XCTAssertEqual(
            enriched.riskObservationBundle?.turnID, "t-2")
        XCTAssertEqual(
            enriched.riskObservationBundle?.sessionID, "s-2")
    }

    func testWithDerivedBundlePreservesEveryOtherField() {
        let f = frame(
            riskBindings: [binding(candidateID: "cand-1")],
            riskDecisionPackage: package())

        let enriched = f.withDerivedRiskObservationBundle(
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(
            enriched.riskBindings?.count, f.riskBindings?.count)
        XCTAssertEqual(
            enriched.riskBindings?.first?.candidateID,
            f.riskBindings?.first?.candidateID)
        XCTAssertEqual(
            enriched.riskDecisionPackage?.packageID,
            f.riskDecisionPackage?.packageID)
        XCTAssertEqual(enriched.stepIndex, f.stepIndex)
        XCTAssertEqual(enriched.decomposeRef, f.decomposeRef)
        XCTAssertEqual(enriched.schemaVersion, f.schemaVersion)
    }

    // MARK: - 6. M32 coverage projection integration

    func testBundleFeedsM32RiskClimateCoverageProjection() {
        let f = frame(riskBindings: [
            binding(candidateID: "cand-1"),
            binding(candidateID: "cand-2")
        ])
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "turn-xyz",
            sessionID: "session-xyz",
            emittedAt: fixedDate)

        let summary = bundle.coverageSummary
        XCTAssertEqual(summary.layer, .riskClimate)
        XCTAssertEqual(summary.turnID, "turn-xyz")
        XCTAssertEqual(summary.sessionID, "session-xyz")
        // 2 distinct candidate intents.
        XCTAssertEqual(summary.distinctSubjectCount, 2)
        // Three core pillars present on every binding → core
        // coverage trips.
        XCTAssertTrue(summary.hasCoreSignalCoverage)
    }

    func testCoreCoverageRequiresThreePillars() {
        // An empty frame (no bindings, no package) cannot satisfy
        // core coverage — the three pillars are missing.
        let f = frame()
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertFalse(bundle.coverageSummary.hasCoreSignalCoverage)
    }

    // MARK: - 7. Budget clamping

    func testBundleBudgetStaysClampedOnDenseEmission() {
        // A dense L11 round: 6 bindings each emitting all 6 signal
        // kinds → 36 observations. Sum of weights: 6 * (0.15 + 0.20
        // + 0.25 + 0.30 + 0.10 + 0.10) = 6 * 1.10 = 6.60 → must
        // clamp to 1.0.
        let bindings = (0..<6).map { i in
            binding(
                candidateID: "cand-\(i)",
                uncertainty: 0.8,
                manipulationStrength: 0.5,
                recommendedMode: .answer,
                permitMode: .delay)
        }
        let f = frame(
            riskBindings: bindings,
            riskDecisionPackage: package(
                longTermTrace: 0.5,
                publicImpact: 0.5))
        let bundle = BASRiskObservationBundle.derive(
            from: f,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let cost = BASRiskObservationBudget.totalCost(for: bundle)
        XCTAssertEqual(cost, 1.0, accuracy: 1e-9)
    }

    // MARK: - 8. Backwards compatibility

    func testThoughtFrameNilBundleRoundTripsThroughCodable() throws {
        let f = frame()
        let data = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(
            BASThoughtFrame.self, from: data)
        XCTAssertNil(decoded.riskObservationBundle)
    }

    func testThoughtFrameWithBundleRoundTripsThroughCodable() throws
    {
        let enriched = frame(
            riskBindings: [binding(candidateID: "cand-1")])
            .withDerivedRiskObservationBundle(
                turnID: "rt",
                sessionID: "rt-s",
                emittedAt: fixedDate)

        let data = try JSONEncoder().encode(enriched)
        let decoded = try JSONDecoder().decode(
            BASThoughtFrame.self, from: data)

        XCTAssertNotNil(decoded.riskObservationBundle)
        XCTAssertEqual(
            decoded.riskObservationBundle?.turnID, "rt")
        XCTAssertEqual(
            decoded.riskObservationBundle?.observations.count,
            enriched.riskObservationBundle?.observations.count)
    }

    func testLegacyJSONWithoutBundleFieldDecodesWithNilBundle()
        throws
    {
        // Simulates a persisted pre-M56 frame that lacks the new
        // key. Swift's synthesized Codable tolerates missing keys
        // for optional fields — decoding must succeed and leave
        // `riskObservationBundle` as nil.
        let legacy = """
        {
          "schemaVersion": "1.5.0",
          "stepIndex": 0,
          "decomposeRef": "d-1",
          "memoryRefs": [],
          "candidates": [],
          "forecasts": [],
          "critiques": [],
          "triScores": [],
          "stabilityScore": 0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(
            BASThoughtFrame.self, from: legacy)
        XCTAssertNil(decoded.riskObservationBundle)
        XCTAssertEqual(decoded.schemaVersion, "1.5.0")
    }
}
