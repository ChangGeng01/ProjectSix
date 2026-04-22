import XCTest
@testable import BASOrchestration
@testable import BASPolicy

/// M57 — L12 soft-hand main-chain wiring.
///
/// The M27 per-mode soft-hand observation primitives were originally
/// emitted only by hand-crafted test helpers; the coordinator never
/// produced a bundle on the main-chain thought frame. These tests
/// pin the main-chain behavior:
///
///   1. `BASSoftHandObservationBundle.derive(from:renderedOutput:
///      turnID:sessionID:emittedAt:)` emits a bundle whose contents
///      deterministically mirror the thought frame's risk records
///      and the sealed rendered output (same inputs → same bundle
///      byte-for-byte).
///   2. Three disjoint paths route the derivation —
///        primary (bindings non-empty),
///        fallback (package-only),
///        empty-empty (neither) — each carrying a guaranteed minimum
///      signal set (at least `.selection`) so the bundle always has
///      provenance.
///   3. Each of the six signal kinds (.suggestion / .selection /
///      .render / .deferral / .downgrade / .escalation) is emitted
///      iff the structural precondition holds; no ghost signals.
///   4. Permit → soft-hand mapping is a 9-to-5 condensation with
///      no data loss on the two protective axes (is this a
///      boundary? is this a deferred surface?).
///   5. The escalation / downgrade direction matches M56's rank
///      table — the same semantic ladder across L11 and L12.
///   6. `BASThoughtFrame.withDerivedSoftHandObservationBundle(...)`
///      returns a copy with the bundle attached and leaves every
///      other field untouched.
///   7. The bundle feeds the M32 `.soft` coverage projection
///      (`hasCoreSignalCoverage` == has `.selection` AND `.render`;
///      `subjectIDs` == distinct subjects first-seen).
///   8. Budget stays clamped in [0, 1] even when many signals are
///      emitted simultaneously.
///   9. Legacy pre-M57 frames (persisted without the new key)
///      decode with `softHandObservationBundle == nil`.
final class BASSoftHandObservationDerivationTests: XCTestCase {

    // MARK: - Fixtures

    private let fixedDate = Date(timeIntervalSince1970: 1_000_000)

    /// Builds a thought frame with only the L12-relevant records
    /// populated. Non-relevant fields stay at their defaults — tests
    /// only need to control `riskBindings` and `riskDecisionPackage`
    /// for derive behavior to be testable.
    private func frame(
        stepIndex: Int = 0,
        riskBindings: [BASRiskPermitBinding]? = nil,
        riskDecisionPackage: BASRiskDecisionPackage? = nil
    ) -> BASThoughtFrame {
        BASThoughtFrame(
            stepIndex: stepIndex,
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
            requireSecondCheck: false,
            outputLengthCap: 200,
            tonePolicy: "grounded",
            templatePolicy: "default",
            sovereignHintLevel: sovereignHintLevel
        )
    }

    private func package(
        candidateRef: String = "cand-1",
        primaryMode: BASActionPermitMode = .answer,
        stackedModes: [BASActionPermitMode] = [],
        sovereignEscalationHint: BASSovereignEscalationHint? = nil
    ) -> BASRiskDecisionPackage {
        BASRiskDecisionPackage(
            packageID: "pkg-1",
            riskCard: BASRiskCard(
                totalRisk: 0.5,
                riskLevel: .medium,
                uncertainty: 0.2,
                irreversibility: 0.4,
                manipulationStrength: 0.0,
                gsiScore: 0.3,
                recommendedMode: primaryMode),
            riskField: BASRiskField(
                fieldID: "field-1",
                candidateRef: candidateRef,
                hazardVector: BASHazardVector(
                    harmSeverity: 0.5,
                    harmScope: 0.5,
                    irreversibility: 0.4,
                    uncertainty: 0.2,
                    evidenceDebt: 0.2,
                    manipulationIntensity: 0.0,
                    pressureAuthenticity: 0.5,
                    vulnerabilityCoupling: 0.3,
                    sideEffectScope: 0.3),
                harmRadius: BASHarmRadiusMap(
                    radiusID: "r-1",
                    privateImpact: 0.2,
                    relationImpact: 0.2,
                    workflowImpact: 0.2,
                    publicImpact: 0.2,
                    longTermTrace: 0.3),
                reversibilityProfile: BASReversibilityProfile(
                    profileID: "rv-1",
                    reversible: true,
                    rollbackCost: 0.4,
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
                primaryMode: primaryMode,
                stackedModes: stackedModes,
                confidence: 0.8),
            actionPermit: BASActionPermit(mode: primaryMode),
            sovereignEscalationHint: sovereignEscalationHint
        )
    }

    private func rendered(
        mode: BASActionPermitMode = .answer,
        headline: String = "Headline",
        body: String = "Body text",
        alternatives: [String] = [],
        surfaceGuide: BASRenderedSurfaceGuide? = nil
    ) -> BASRenderedOutput {
        BASRenderedOutput(
            mode: mode,
            headline: headline,
            body: body,
            alternativeActions: alternatives,
            surfaceGuide: surfaceGuide
        )
    }

    private func guide(
        delayWindow: String? = nil,
        delayReservation: BASDelayReservation? = nil,
        sovereignEscalationHint: BASSovereignEscalationHint? = nil
    ) -> BASRenderedSurfaceGuide {
        BASRenderedSurfaceGuide(
            tonePolicy: "grounded",
            templatePolicy: "default",
            outputLengthCap: 200,
            boundary: BASRenderedBoundaryGuide(
                toolScope: "none",
                memoryScope: "none"),
            agency: BASRenderedAgencyGuide(
                requiresCompare: false,
                requiresSecondCheck: false,
                delayAvailable: false,
                chooseLaterAllowed: false,
                prefersDraftOnly: false,
                localOnlyPreferred: false),
            disclosure: BASRenderedDisclosureGuide(
                assertionCeiling: "standard",
                uncertaintyVisible: false),
            delayWindow: delayWindow,
            delayReservation: delayReservation,
            sovereignEscalationHint: sovereignEscalationHint)
    }

    private func hint(id: String = "h-1") -> BASSovereignEscalationHint {
        BASSovereignEscalationHint(
            hintID: id,
            sourceRefs: ["src-1"],
            reasonCodes: ["boundary"],
            urgency: "standard",
            suggestedScope: "session")
    }

    private func reservation(
        id: String = "res-1"
    ) -> BASDelayReservation {
        BASDelayReservation(
            reservationID: id,
            delayType: "cooldown",
            minDelay: 60,
            maxDelay: 3_600)
    }

    // MARK: - 1. Primary path (riskBindings drives)

    func testPrimaryEmitsSuggestionAndSelectionPerBinding() {
        let f = frame(riskBindings: [
            binding(candidateID: "a"),
            binding(candidateID: "b")
        ])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        // Each binding emits suggestion + selection.
        XCTAssertEqual(
            bundle.observations(of: .suggestion).count, 2)
        XCTAssertEqual(
            bundle.observations(of: .selection).count, 2)
        // Active subject ("a" — first binding since no package ref)
        // additionally picks up the render signal since the
        // rendered output carries non-empty headline/body.
        XCTAssertEqual(
            bundle.observations(forSubject: "a").count, 3)
        // The non-active subject ("b") only has its suggestion +
        // selection pair; render/deferral never bind to it.
        XCTAssertEqual(
            bundle.observations(forSubject: "b").count, 2)
    }

    func testPrimaryEmitsEscalationWhenPermitTighterThanRecommended() throws {
        let f = frame(riskBindings: [
            binding(
                candidateID: "c",
                recommendedMode: .answer,      // rank 0
                permitMode: .block)            // rank 7
        ])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let escalations = bundle.observations(of: .escalation)
        XCTAssertEqual(escalations.count, 1)
        let esc = try XCTUnwrap(escalations.first)
        XCTAssertEqual(esc.subjectID, "c")
        XCTAssertEqual(esc.mode, .boundary)   // block → boundary
        // delta = 7, salience = min(1, 7 * 0.20) = 1.0
        XCTAssertEqual(esc.salience, 1.0, accuracy: 1e-9)
        XCTAssertTrue(esc.content.contains("escalation.from:answer"))
        XCTAssertTrue(esc.content.contains("to:block"))
        XCTAssertTrue(esc.content.contains("delta:7"))
    }

    func testPrimaryEmitsDowngradeWhenPermitLooserThanRecommended() throws {
        let f = frame(riskBindings: [
            binding(
                candidateID: "d",
                recommendedMode: .delay,       // rank 5
                permitMode: .answer)           // rank 0
        ])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let downgrades = bundle.observations(of: .downgrade)
        XCTAssertEqual(downgrades.count, 1)
        let down = try XCTUnwrap(downgrades.first)
        XCTAssertEqual(down.subjectID, "d")
        XCTAssertEqual(down.mode, .silentStub)  // answer → silentStub
        // delta = 5, salience = min(1, 5 * 0.20) = 1.0
        XCTAssertEqual(down.salience, 1.0, accuracy: 1e-9)
        XCTAssertTrue(down.content.contains("downgrade.from:delay"))
        XCTAssertTrue(down.content.contains("to:answer"))
    }

    func testPrimaryNoDirectionWhenRecommendedEqualsPermit() {
        let f = frame(riskBindings: [
            binding(
                candidateID: "same",
                recommendedMode: .compare,
                permitMode: .compare)
        ])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(mode: .compare),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        // No escalation / downgrade — the binding is already in its
        // recommended mode.
        XCTAssertTrue(
            bundle.observations(of: .escalation).isEmpty)
        XCTAssertTrue(
            bundle.observations(of: .downgrade).isEmpty)
    }

    func testPrimaryActiveSubjectResolvesFromPackageCandidateRef() {
        // When bindings and package are both present, and the
        // package points at the SECOND binding's candidateID via
        // candidateRef, render/deferral should bind to that subject.
        let f = frame(
            riskBindings: [
                binding(candidateID: "a"),
                binding(candidateID: "b")
            ],
            riskDecisionPackage: package(candidateRef: "b"))
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(mode: .delay),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let renderObs = bundle.observations(of: .render)
        XCTAssertEqual(renderObs.count, 1)
        XCTAssertEqual(renderObs.first?.subjectID, "b")

        let deferrals = bundle.observations(of: .deferral)
        XCTAssertEqual(deferrals.count, 1)
        XCTAssertEqual(deferrals.first?.subjectID, "b")
    }

    func testPrimaryActiveSubjectFallsBackToFirstBindingWhenNoRef() {
        // No package candidateRef → active subject = first binding.
        let f = frame(riskBindings: [
            binding(candidateID: "first"),
            binding(candidateID: "second")
        ])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let renderObs = bundle.observations(of: .render)
        XCTAssertEqual(renderObs.count, 1)
        XCTAssertEqual(renderObs.first?.subjectID, "first")
    }

    // MARK: - 2. Fallback path (package-only)

    func testFallbackEmitsPackageLevelSignalsWhenBindingsEmpty() {
        let f = frame(
            riskDecisionPackage: package(
                candidateRef: "pkg-ref",
                primaryMode: .draftOnly))
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(mode: .draftOnly),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertFalse(bundle.observations.isEmpty)
        XCTAssertEqual(bundle.subjectIDs, ["pkg-ref"])
        XCTAssertEqual(
            bundle.observations(of: .suggestion).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .selection).count, 1)
        XCTAssertEqual(bundle.selectedMode, .draft)
    }

    func testFallbackStackedModesEmitDecayingSuggestions() throws {
        // Primary .answer + three stacked alternatives → 1 primary
        // suggestion + 3 stacked suggestions with decreasing
        // salience (0.60, 0.50, 0.40).
        let f = frame(
            riskDecisionPackage: package(
                primaryMode: .answer,
                stackedModes: [.compare, .delay, .block]))
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let suggestions = bundle.observations(of: .suggestion)
        XCTAssertEqual(suggestions.count, 4)
        // The stacked suggestions appear in the order they were
        // enumerated, after the primary suggestion.
        XCTAssertEqual(
            suggestions[0].salience, 0.70, accuracy: 1e-9) // primary
        XCTAssertEqual(
            suggestions[1].salience, 0.60, accuracy: 1e-9) // idx 0
        XCTAssertEqual(
            suggestions[2].salience, 0.50, accuracy: 1e-9) // idx 1
        XCTAssertEqual(
            suggestions[3].salience, 0.40, accuracy: 1e-9) // idx 2
    }

    func testFallbackSubjectFallsBackToPackageIDWhenCandidateRefEmpty() {
        // candidateRef is empty string → subjectID = packageID.
        let f = frame(
            riskDecisionPackage: package(candidateRef: ""))
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(bundle.subjectIDs, ["pkg-1"])
    }

    // MARK: - 3. Empty-empty path

    func testEmptyEmptyEmitsSelectionWithStepIndexSubject() {
        let f = frame(stepIndex: 7)
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(
            bundle.observations(of: .selection).count, 1)
        XCTAssertEqual(bundle.subjectIDs, ["l12.subject.step-7"])
    }

    func testEmptyEmptyNoSuggestionOrDirection() {
        // No bindings and no package → no suggestion / direction
        // evidence exists in the frame.
        let f = frame()
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertTrue(
            bundle.observations(of: .suggestion).isEmpty)
        XCTAssertTrue(
            bundle.observations(of: .downgrade).isEmpty)
        // An .escalation signal is only allowed if a sovereign hint
        // is present — not the case in this empty-empty frame.
        XCTAssertTrue(
            bundle.observations(of: .escalation).isEmpty)
    }

    // MARK: - 4. Render evidence

    func testRenderEmittedWhenHeadlineNonEmpty() {
        let f = frame(riskBindings: [binding()])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(
                headline: "Hello",
                body: ""),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(
            bundle.observations(of: .render).count, 1)
    }

    func testRenderEmittedWhenBodyNonEmpty() {
        let f = frame(riskBindings: [binding()])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(headline: "", body: "Hi"),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(
            bundle.observations(of: .render).count, 1)
    }

    func testRenderSuppressedWhenBothHeadlineAndBodyBlank() {
        // Trim whitespace before checking — an all-whitespace
        // body still counts as empty.
        let f = frame(riskBindings: [binding()])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(
                headline: "   ",
                body: "\n\t"),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertTrue(
            bundle.observations(of: .render).isEmpty)
    }

    func testRenderContentCarriesHeadlineAndBodyLengths() throws {
        let f = frame(riskBindings: [binding()])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(
                headline: "abc",
                body: "1234",
                alternatives: ["alt-a", "alt-b"]),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let render = try XCTUnwrap(
            bundle.observations(of: .render).first)
        XCTAssertTrue(render.content.contains("headline-len:3"))
        XCTAssertTrue(render.content.contains("body-len:4"))
        XCTAssertTrue(render.content.contains("alt-count:2"))
    }

    // MARK: - 5. Deferral gating

    func testDeferralEmittedWhenRenderedModeIsDelay() {
        let f = frame(riskBindings: [binding()])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(mode: .delay),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(
            bundle.observations(of: .deferral).count, 1)
        // Deferral mode is always .delay regardless of the selected
        // soft-hand mode (a deferral IS a delay signal).
        XCTAssertEqual(
            bundle.observations(of: .deferral).first?.mode, .delay)
    }

    func testDeferralEmittedWhenGuideCarriesDelayReservation() {
        let f = frame(riskBindings: [binding()])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(
                mode: .answer,
                surfaceGuide: guide(
                    delayReservation: reservation())),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(
            bundle.observations(of: .deferral).count, 1)
    }

    func testDeferralEmittedWhenGuideCarriesDelayWindow() {
        let f = frame(riskBindings: [binding()])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(
                mode: .answer,
                surfaceGuide: guide(delayWindow: "PT1H")),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(
            bundle.observations(of: .deferral).count, 1)
    }

    func testDeferralSuppressedWhenNoDelayEvidence() {
        let f = frame(riskBindings: [binding()])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(
                mode: .answer,
                surfaceGuide: guide()),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertTrue(
            bundle.observations(of: .deferral).isEmpty)
    }

    // MARK: - 6. Sovereign escalation

    func testSovereignEscalationFromSurfaceGuide() throws {
        // Even on a binding whose recommended == permit (no
        // rank-based escalation), a sovereign hint on the guide
        // forces an unconditional .escalation signal.
        let f = frame(riskBindings: [
            binding(
                recommendedMode: .answer,
                permitMode: .answer)
        ])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(
                surfaceGuide: guide(sovereignEscalationHint: hint())),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let escalations = bundle.observations(of: .escalation)
        XCTAssertEqual(escalations.count, 1)
        let esc = try XCTUnwrap(escalations.first)
        XCTAssertEqual(esc.mode, .boundary)
        XCTAssertTrue(
            esc.content.contains("escalation.sovereign-hint"))
    }

    func testSovereignEscalationFromPackage() {
        // Hint lives on the package, not the guide — still emits.
        let f = frame(
            riskDecisionPackage: package(
                sovereignEscalationHint: hint()))
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let escalations = bundle.observations(of: .escalation)
        XCTAssertEqual(escalations.count, 1)
    }

    func testSovereignEscalationStacksWithRankEscalation() {
        // Binding has both rank-based escalation AND sovereign
        // hint on the guide → two .escalation signals.
        let f = frame(riskBindings: [
            binding(
                recommendedMode: .answer,
                permitMode: .block)
        ])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(
                surfaceGuide: guide(sovereignEscalationHint: hint())),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        XCTAssertEqual(
            bundle.observations(of: .escalation).count, 2)
    }

    // MARK: - 7. Permit → soft-hand mapping (9 to 5)

    func testMapPermitToSoftHandCoversAllNineCases() {
        // Pin the semantic condensation contract. Each input mode
        // maps to exactly one output mode — no surprise rerouting.
        let cases:
            [(BASActionPermitMode, BASSoftHandMode)] = [
                (.answer,    .silentStub),
                (.mirror,    .compare),
                (.compare,   .compare),
                (.draftOnly, .draft),
                (.delay,     .delay),
                (.localOnly, .silentStub),
                (.block,     .boundary),
                (.replace,   .boundary),
                (.escalate,  .boundary)
            ]
        for (input, expected) in cases {
            let f = frame(riskBindings: [
                binding(
                    candidateID: "map-\(input.rawValue)",
                    recommendedMode: input,
                    permitMode: input)
            ])
            let bundle = BASSoftHandObservationBundle.derive(
                from: f,
                renderedOutput: rendered(mode: input),
                turnID: "t",
                sessionID: "s",
                emittedAt: fixedDate)

            let selections = bundle.observations(of: .selection)
            XCTAssertEqual(selections.count, 1)
            XCTAssertEqual(
                selections.first?.mode, expected,
                "permit \(input) must map to soft-hand \(expected)")
        }
    }

    // MARK: - 8. Rank matrix (9 × 9 — escalation / downgrade)

    /// M57 shares its 9-case rank ladder with M56's gatePressure.
    /// This test pins that the direction label (escalation /
    /// downgrade) flips exactly at the rank diagonal, for all
    /// 9 × 9 − 9 = 72 off-diagonal pairs.
    func testEscalationDowngradeMatrixAcrossAllNineModes() {
        let ladder: [BASActionPermitMode] = [
            .answer, .mirror, .compare, .draftOnly,
            .localOnly, .delay, .replace, .block, .escalate
        ]
        for (i, recommended) in ladder.enumerated() {
            for (j, permit) in ladder.enumerated() {
                guard i != j else { continue }
                let f = frame(riskBindings: [
                    binding(
                        candidateID: "m-\(i)-\(j)",
                        recommendedMode: recommended,
                        permitMode: permit)
                ])
                let bundle = BASSoftHandObservationBundle.derive(
                    from: f,
                    renderedOutput: rendered(mode: permit),
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: fixedDate)

                if j > i {
                    // Tighter permit → escalation.
                    XCTAssertEqual(
                        bundle.observations(of: .escalation)
                            .count,
                        1,
                        "pair (rec=\(recommended), permit=\(permit))"
                            + " must emit escalation")
                    XCTAssertTrue(
                        bundle.observations(of: .downgrade)
                            .isEmpty,
                        "pair (rec=\(recommended), permit=\(permit))"
                            + " must NOT emit downgrade")
                } else {
                    // Looser permit → downgrade.
                    XCTAssertEqual(
                        bundle.observations(of: .downgrade)
                            .count,
                        1,
                        "pair (rec=\(recommended), permit=\(permit))"
                            + " must emit downgrade")
                    XCTAssertTrue(
                        bundle.observations(of: .escalation)
                            .isEmpty,
                        "pair (rec=\(recommended), permit=\(permit))"
                            + " must NOT emit escalation")
                }
            }
        }
    }

    // MARK: - 9. Determinism

    func testDeriveIsDeterministicForSameInputs() {
        let f = frame(
            riskBindings: [
                binding(
                    candidateID: "a",
                    recommendedMode: .answer,
                    permitMode: .compare),
                binding(
                    candidateID: "b",
                    recommendedMode: .delay,
                    permitMode: .delay)
            ],
            riskDecisionPackage: package(
                sovereignEscalationHint: hint()))
        let r = rendered(
            mode: .delay,
            surfaceGuide: guide(
                delayReservation: reservation()))

        let first = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: r,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let second = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: r,
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertEqual(first, second)
    }

    // MARK: - 10. Coherent-by-construction

    func testBundleHonorsCallerTurnAndSessionIDs() {
        let matrix: [(turn: String, session: String)] = [
            ("t-1", "s-A"),
            ("t-1", "s-B"),
            ("t-2", "s-A"),
            ("t-2", "s-B")
        ]
        let f = frame(riskBindings: [binding()])
        for cell in matrix {
            let bundle = BASSoftHandObservationBundle.derive(
                from: f,
                renderedOutput: rendered(),
                turnID: cell.turn,
                sessionID: cell.session,
                emittedAt: fixedDate)
            XCTAssertEqual(bundle.turnID, cell.turn)
            XCTAssertEqual(bundle.sessionID, cell.session)
        }
    }

    func testBundleEmittedAtMatchesParam() {
        let customDate = Date(timeIntervalSince1970: 2_500_000)
        let bundle = BASSoftHandObservationBundle.derive(
            from: frame(riskBindings: [binding()]),
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: customDate)
        XCTAssertEqual(bundle.emittedAt, customDate)
        // All observations also pin the emittedAt stamp.
        for obs in bundle.observations {
            XCTAssertEqual(obs.observedAt, customDate)
        }
    }

    // MARK: - 11. withDerived extension contract

    func testWithDerivedBundleAttachesOnCopy() {
        let f = frame(riskBindings: [binding()])
        let enriched = f
            .withDerivedSoftHandObservationBundle(
                renderedOutput: rendered(),
                turnID: "t-2",
                sessionID: "s-2",
                emittedAt: fixedDate)

        XCTAssertNil(f.softHandObservationBundle)
        XCTAssertNotNil(enriched.softHandObservationBundle)
        XCTAssertEqual(
            enriched.softHandObservationBundle?.turnID, "t-2")
        XCTAssertEqual(
            enriched.softHandObservationBundle?.sessionID, "s-2")
    }

    func testWithDerivedBundlePreservesEveryOtherField() {
        let f = frame(
            riskBindings: [binding(candidateID: "cand-1")],
            riskDecisionPackage: package())

        let enriched = f
            .withDerivedSoftHandObservationBundle(
                renderedOutput: rendered(),
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

    // MARK: - 12. M32 coverage projection

    func testBundleHasCoreSignalCoverageWithSelectionAndRender() {
        let bundle = BASSoftHandObservationBundle.derive(
            from: frame(riskBindings: [binding()]),
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertTrue(bundle.hasCoreSignalCoverage)
    }

    func testBundleLacksCoreCoverageWhenRenderSuppressed() {
        let bundle = BASSoftHandObservationBundle.derive(
            from: frame(riskBindings: [binding()]),
            renderedOutput: rendered(headline: "", body: ""),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertFalse(bundle.hasCoreSignalCoverage)
    }

    func testSubjectIDsDedupPerBinding() {
        // Two bindings with the same candidateID — subjectIDs must
        // contain a single entry per the first-seen dedup contract.
        let f = frame(riskBindings: [
            binding(candidateID: "dup"),
            binding(candidateID: "dup")
        ])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        XCTAssertEqual(bundle.subjectIDs.count, 1)
        XCTAssertEqual(bundle.subjectIDs, ["dup"])
        // But raw selection count = 2 — upstream binding
        // duplication is preserved without implicit dedup.
        XCTAssertEqual(
            bundle.observations(of: .selection).count, 2)
    }

    // MARK: - 13. Budget clamping

    func testBundleBudgetStaysClampedOnDenseEmission() {
        // A dense turn: 5 bindings each with escalation + suggestion
        // + selection (0.25 + 0.10 + 0.10 = 0.45) plus 1 render and
        // 1 deferral on the active subject (0.15 + 0.10 = 0.25) plus
        // 1 sovereign escalation (0.25) → 5 × 0.45 + 0.50 = 2.75
        // pre-clamp. Must clamp to 1.0.
        let bindings = (0..<5).map { i in
            binding(
                candidateID: "b-\(i)",
                recommendedMode: .answer,
                permitMode: .block)
        }
        let f = frame(
            riskBindings: bindings,
            riskDecisionPackage: package(
                candidateRef: "b-0",
                sovereignEscalationHint: hint()))
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(
                mode: .delay,
                surfaceGuide: guide(
                    delayReservation: reservation())),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let cost = BASSoftHandObservationBudget.totalCost(for: bundle)
        XCTAssertEqual(cost, 1.0, accuracy: 1e-9)
    }

    // MARK: - 14. Backwards compatibility (Codable)

    func testThoughtFrameNilBundleRoundTripsThroughCodable() throws {
        let f = frame()
        let data = try JSONEncoder().encode(f)
        let decoded = try JSONDecoder().decode(
            BASThoughtFrame.self, from: data)
        XCTAssertNil(decoded.softHandObservationBundle)
    }

    func testThoughtFrameWithBundleRoundTripsThroughCodable() throws {
        let enriched = frame(
            riskBindings: [binding(candidateID: "cand-1")])
            .withDerivedSoftHandObservationBundle(
                renderedOutput: rendered(),
                turnID: "rt",
                sessionID: "rt-s",
                emittedAt: fixedDate)

        let data = try JSONEncoder().encode(enriched)
        let decoded = try JSONDecoder().decode(
            BASThoughtFrame.self, from: data)

        XCTAssertNotNil(decoded.softHandObservationBundle)
        XCTAssertEqual(
            decoded.softHandObservationBundle?.turnID, "rt")
        XCTAssertEqual(
            decoded.softHandObservationBundle,
            enriched.softHandObservationBundle)
    }

    func testLegacyJSONWithoutBundleFieldDecodesWithNilBundle() throws
    {
        // Simulates a persisted pre-M57 frame that lacks the new
        // key. Swift's synthesized Codable tolerates missing keys
        // for optional fields — decoding must succeed and leave
        // `softHandObservationBundle` as nil.
        let legacy = """
        {
          "schemaVersion": "1.6.0",
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
        XCTAssertNil(decoded.softHandObservationBundle)
        XCTAssertEqual(decoded.schemaVersion, "1.6.0")
    }

    // MARK: - 15. Dense round-trip preserves all six kinds

    /// Exercises all 6 signal kinds in one turn (suggestion /
    /// selection / render / deferral / downgrade / escalation)
    /// and asserts byte-equal round-trip through Codable.
    func testDenseBundleCodableRoundTripPreservesAllSixKinds()
        throws
    {
        let f = frame(
            riskBindings: [
                binding(
                    candidateID: "up",
                    recommendedMode: .answer,
                    permitMode: .block),
                binding(
                    candidateID: "down",
                    recommendedMode: .delay,
                    permitMode: .answer)
            ],
            riskDecisionPackage: package(
                candidateRef: "up",
                sovereignEscalationHint: hint()))
        let enriched = f
            .withDerivedSoftHandObservationBundle(
                renderedOutput: rendered(
                    mode: .delay,
                    surfaceGuide: guide(
                        delayReservation: reservation())),
                turnID: "dense-t",
                sessionID: "dense-s",
                emittedAt: fixedDate)

        // Pre-condition: all 6 kinds present.
        let observed =
            enriched.softHandObservationBundle?.observations ?? []
        let kinds = Set(observed.map(\.kind))
        XCTAssertEqual(kinds.count, 6)
        XCTAssertTrue(kinds.contains(.suggestion))
        XCTAssertTrue(kinds.contains(.selection))
        XCTAssertTrue(kinds.contains(.render))
        XCTAssertTrue(kinds.contains(.deferral))
        XCTAssertTrue(kinds.contains(.downgrade))
        XCTAssertTrue(kinds.contains(.escalation))

        let data = try JSONEncoder().encode(enriched)
        let decoded = try JSONDecoder().decode(
            BASThoughtFrame.self, from: data)

        XCTAssertEqual(
            decoded.softHandObservationBundle,
            enriched.softHandObservationBundle)
    }

    // MARK: - 16. Clamp endpoints

    func testSalienceClampsToOneOnLargeDelta() throws {
        // answer → escalate is an 8-step delta → salience pre-clamp
        // = 8 * 0.20 = 1.60 → must clamp to 1.0.
        let f = frame(riskBindings: [
            binding(
                recommendedMode: .answer,     // rank 0
                permitMode: .escalate)        // rank 8
        ])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let esc = try XCTUnwrap(
            bundle.observations(of: .escalation).first)
        XCTAssertEqual(esc.salience, 1.0, accuracy: 1e-9)
    }

    func testSelectionMirrorsRenderedOutputModeNotBindingPermit() throws {
        // When the binding's permitMode (.block) disagrees with the
        // final rendered mode (.delay), the ACTIVE subject's
        // selection signal follows the BINDING (per-binding selection
        // records the binding's own decision), but the render signal
        // follows the RENDERED output. This pin protects the
        // "binding records binding, render records render" contract.
        let f = frame(riskBindings: [
            binding(
                candidateID: "split",
                recommendedMode: .answer,
                permitMode: .block)
        ])
        let bundle = BASSoftHandObservationBundle.derive(
            from: f,
            renderedOutput: rendered(mode: .delay),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)

        let selection = try XCTUnwrap(
            bundle.observations(of: .selection).first)
        XCTAssertEqual(selection.mode, .boundary) // block → boundary
        let render = try XCTUnwrap(
            bundle.observations(of: .render).first)
        XCTAssertEqual(render.mode, .delay)       // delay → delay
    }
}
