import XCTest
@testable import QinaoRisk

/// M75 — L12 柔手 surface matrix projection tests.
///
/// The risk gate's four-mode verdict (`.allow / .delay / .replace /
/// .block`) projects onto a four-axis surface matrix (surface /
/// agency / disclosure / substitute). These tests pin the projection
/// rules so the gate→UI hand-off stays stable across refactors:
///
/// 1. **Mapping exhaustiveness** — every `RiskAssessment.mode`
///    projects onto exactly one of the 5 QinaoUI surfaces.
/// 2. **Agency adapts to host input** — replace with ≥2 candidates
///    is `userChoose`; with <2 it degrades to `userAffirm`. Allow
///    with candidates is `userAffirm`; without any is `autoComply`.
/// 3. **Consent routing** — a replace assessment carrying the stable
///    reason `consent-required` routes to `boundaryScript` /
///    `.requestConsent`, not to `comparePanel`.
/// 4. **Defaults are stable** — missing audit ref → `"unspecified"`;
///    missing candidate ID → `"primary-candidate"`; missing delay
///    recommendation → 60 seconds; missing consent prompt key →
///    `"default-consent-prompt"`.
/// 5. **Codable round-trip** — `SurfaceAction` and every
///    `SubstitutePayload` case survive JSON encode/decode.
/// 6. **Raw-value contract** — `SurfaceMode` raw values match
///    `QinaoUI.ComponentID` so a host can log a single string
///    across risk and UI layers.
/// 7. **Actor convenience** — `requestSurfaceAction(for:signals:)`
///    composes `assess` + `surfaceAction` without binding to a
///    specific intent digest.
/// 8. **World-aware path** — the world-aware variant surfaces the
///    world-prior template's consent / evidence / irreversibility
///    decisions to the correct surface, and throws
///    `.unknownWorldTemplate` when the vault doesn't recognise the
///    requested template ID (same contract as the permit path).
final class QinaoRiskSurfaceMatrixTests: XCTestCase {

    // MARK: - Helpers

    private struct StubWorldEndpoint: QinaoWorldPriorEndpoint {
        let assessment: QinaoRiskGate.WorldRiskAssessment?

        func assessRisk(
            templateID: String
        ) async throws -> QinaoRiskGate.WorldRiskAssessment? {
            guard let a = assessment else { return nil }
            guard a.matchedTemplateID == templateID else { return nil }
            return a
        }
    }

    // MARK: - Block projection

    func testSurfaceActionBlockProjectsToSilentStub() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .block,
            reasonCodes: ["harm-severity-ceiling"])
        let action = QinaoRiskGate.surfaceAction(
            for: assessment,
            auditReference: "audit.123")
        XCTAssertEqual(action.surface, .silentStub)
        XCTAssertEqual(action.agency, .hostOverride)
        XCTAssertEqual(action.disclosure, .silent)
        XCTAssertEqual(
            action.substitute,
            .refuse(auditReference: "audit.123"))
        XCTAssertEqual(
            action.reasonCodes,
            ["harm-severity-ceiling"])
        XCTAssertEqual(action.auditReference, "audit.123")
    }

    func testSurfaceActionBlockFallsBackToUnspecifiedAuditRef() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .block,
            reasonCodes: ["irreversibility-ceiling"])
        let action = QinaoRiskGate.surfaceAction(for: assessment)
        XCTAssertEqual(
            action.substitute,
            .refuse(auditReference: "unspecified"))
        XCTAssertNil(action.auditReference)
    }

    // MARK: - Delay projection

    func testSurfaceActionDelayProjectsToDelayPacket() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .delay,
            reasonCodes: ["uncertainty-high", "evidence-debt-high"],
            recommendedDelaySeconds: 120)
        let action = QinaoRiskGate.surfaceAction(for: assessment)
        XCTAssertEqual(action.surface, .delayPacket)
        XCTAssertEqual(action.agency, .hostOverride)
        XCTAssertEqual(action.disclosure, .reasoned)
        XCTAssertEqual(
            action.substitute,
            .deferToLater(retryAfterSeconds: 120))
    }

    func testSurfaceActionDelayDefaultsTo60WhenNoRecommendation() {
        // Synthetic assessment without a recommendedDelaySeconds —
        // the projection must default to 60 so the UI layer has
        // something to render.
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .delay,
            reasonCodes: ["uncertainty-high"])
        let action = QinaoRiskGate.surfaceAction(for: assessment)
        XCTAssertEqual(
            action.substitute,
            .deferToLater(retryAfterSeconds: 60))
    }

    // MARK: - Replace · consent routing

    func testSurfaceActionReplaceWithConsentProjectsToBoundaryScript() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .replace,
            reasonCodes: [
                "consent-required",
                "world-template:tpl.surgery"
            ],
            substituteHint: "request-informed-consent")
        let action = QinaoRiskGate.surfaceAction(
            for: assessment,
            consentPromptKey: "consent.medical.irreversible")
        XCTAssertEqual(action.surface, .boundaryScript)
        XCTAssertEqual(action.agency, .userAffirm)
        XCTAssertEqual(action.disclosure, .explicit)
        XCTAssertEqual(
            action.substitute,
            .requestConsent(
                promptKey: "consent.medical.irreversible"))
    }

    func testSurfaceActionReplaceConsentUsesDefaultPromptKey() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .replace,
            reasonCodes: ["consent-required"],
            substituteHint: "request-informed-consent")
        let action = QinaoRiskGate.surfaceAction(for: assessment)
        XCTAssertEqual(
            action.substitute,
            .requestConsent(promptKey: "default-consent-prompt"))
    }

    // MARK: - Replace · compare routing

    func testSurfaceActionReplaceWithTwoCandidatesChooses() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .replace,
            reasonCodes: ["manipulation-intensity-high"],
            substituteHint: "mirror-and-compare-instead")
        let action = QinaoRiskGate.surfaceAction(
            for: assessment,
            candidateIDs: ["cand.A", "cand.B"])
        XCTAssertEqual(action.surface, .comparePanel)
        XCTAssertEqual(action.agency, .userChoose)
        XCTAssertEqual(action.disclosure, .reasoned)
        XCTAssertEqual(
            action.substitute,
            .mirrorAndCompare(candidateIDs: ["cand.A", "cand.B"]))
    }

    func testSurfaceActionReplaceWithOneCandidateDegradesToAffirm() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .replace,
            reasonCodes: ["gsi-pressure-high"],
            substituteHint: "mirror-and-compare-instead")
        let action = QinaoRiskGate.surfaceAction(
            for: assessment,
            candidateIDs: ["only.one"])
        XCTAssertEqual(action.agency, .userAffirm)
        XCTAssertEqual(
            action.substitute,
            .mirrorAndCompare(candidateIDs: ["only.one"]))
    }

    func testSurfaceActionReplaceWithZeroCandidatesDegradesToAffirm() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .replace,
            reasonCodes: ["pressure-inauthentic"])
        let action = QinaoRiskGate.surfaceAction(for: assessment)
        XCTAssertEqual(action.surface, .comparePanel)
        XCTAssertEqual(action.agency, .userAffirm)
        XCTAssertEqual(
            action.substitute,
            .mirrorAndCompare(candidateIDs: []))
    }

    // MARK: - Allow projection

    func testSurfaceActionAllowWithCandidatesAffirms() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .allow,
            reasonCodes: ["baseline-clear"])
        let action = QinaoRiskGate.surfaceAction(
            for: assessment,
            candidateIDs: ["cand.A", "cand.B", "cand.C"])
        XCTAssertEqual(action.surface, .draftShell)
        XCTAssertEqual(action.agency, .userAffirm)
        XCTAssertEqual(action.disclosure, .minimal)
        // Allow surfaces the FIRST candidate as the primary draft.
        XCTAssertEqual(
            action.substitute,
            .render(candidateID: "cand.A"))
    }

    func testSurfaceActionAllowWithoutCandidatesAutoComplies() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .allow,
            reasonCodes: ["baseline-clear"])
        let action = QinaoRiskGate.surfaceAction(for: assessment)
        XCTAssertEqual(action.surface, .draftShell)
        XCTAssertEqual(action.agency, .autoComply)
        XCTAssertEqual(
            action.substitute,
            .render(candidateID: "primary-candidate"))
    }

    // MARK: - Determinism

    func testSurfaceActionIsDeterministic() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .replace,
            reasonCodes: ["manipulation-intensity-high"],
            substituteHint: "mirror-and-compare-instead")
        let a = QinaoRiskGate.surfaceAction(
            for: assessment,
            auditReference: "audit.A",
            candidateIDs: ["cand.A", "cand.B"])
        let b = QinaoRiskGate.surfaceAction(
            for: assessment,
            auditReference: "audit.A",
            candidateIDs: ["cand.A", "cand.B"])
        XCTAssertEqual(a, b)
    }

    func testSurfaceActionReasonCodesPassThroughVerbatim() {
        let assessment = QinaoRiskGate.RiskAssessment(
            mode: .delay,
            reasonCodes: [
                "uncertainty-high",
                "evidence-debt-high",
                "world-template:tpl.X"
            ],
            recommendedDelaySeconds: 90)
        let action = QinaoRiskGate.surfaceAction(for: assessment)
        XCTAssertEqual(
            action.reasonCodes,
            [
                "uncertainty-high",
                "evidence-debt-high",
                "world-template:tpl.X"
            ])
    }

    // MARK: - Raw-value contract vs QinaoUI.ComponentID

    func testSurfaceModeRawValuesMatchQinaoUIComponentIDs() {
        // QinaoRisk does not depend on QinaoUI (keeps QinaoRisk a
        // leaf target). So we pin the shared string contract here:
        // these raw values MUST equal QinaoUI.ComponentID.rawValue
        // strings. If a refactor breaks the contract, both this
        // test and the UI-side component registry tests will fail.
        XCTAssertEqual(
            QinaoRiskGate.SurfaceMode.comparePanel.rawValue,
            "compare-panel")
        XCTAssertEqual(
            QinaoRiskGate.SurfaceMode.draftShell.rawValue,
            "draft-shell")
        XCTAssertEqual(
            QinaoRiskGate.SurfaceMode.delayPacket.rawValue,
            "delay-packet")
        XCTAssertEqual(
            QinaoRiskGate.SurfaceMode.boundaryScript.rawValue,
            "boundary-script")
        XCTAssertEqual(
            QinaoRiskGate.SurfaceMode.silentStub.rawValue,
            "silent-stub")
    }

    // MARK: - Codable round-trip

    func testSubstitutePayloadCodableRoundTripCoversAllCases() throws {
        let cases: [QinaoRiskGate.SubstitutePayload] = [
            .mirrorAndCompare(candidateIDs: ["cand.A", "cand.B"]),
            .deferToLater(retryAfterSeconds: 300),
            .requestConsent(promptKey: "consent.K"),
            .render(candidateID: "cand.primary"),
            .refuse(auditReference: "audit.999")
        ]
        let enc = JSONEncoder()
        let dec = JSONDecoder()
        for p in cases {
            let data = try enc.encode(p)
            let back = try dec.decode(
                QinaoRiskGate.SubstitutePayload.self, from: data)
            XCTAssertEqual(p, back)
        }
    }

    func testSurfaceActionCodableRoundTrip() throws {
        let action = QinaoRiskGate.SurfaceAction(
            surface: .comparePanel,
            agency: .userChoose,
            disclosure: .reasoned,
            substitute: .mirrorAndCompare(
                candidateIDs: ["cand.A", "cand.B"]),
            reasonCodes: ["manipulation-intensity-high"],
            auditReference: "audit.7")
        let data = try JSONEncoder().encode(action)
        let back = try JSONDecoder().decode(
            QinaoRiskGate.SurfaceAction.self, from: data)
        XCTAssertEqual(action, back)
    }

    // MARK: - Actor convenience

    func testRequestSurfaceActionFromSafeSignalsAllows() async {
        let gate = QinaoRiskGate()
        let action = await gate.requestSurfaceAction(for: .safe)
        XCTAssertEqual(action.surface, .draftShell)
        XCTAssertEqual(action.agency, .autoComply)
        XCTAssertEqual(action.reasonCodes, ["baseline-clear"])
    }

    func testRequestSurfaceActionFromHighGSIReplaces() async {
        let gate = QinaoRiskGate()
        let signals = QinaoRiskGate.RiskSignals(gsiScore: 0.95)
        let action = await gate.requestSurfaceAction(
            for: signals,
            candidateIDs: ["alt.1", "alt.2"])
        XCTAssertEqual(action.surface, .comparePanel)
        XCTAssertEqual(action.agency, .userChoose)
        XCTAssertTrue(
            action.reasonCodes.contains("gsi-pressure-high"))
    }

    // MARK: - World-aware path

    func testRequestSurfaceActionWorldAwareConsentRoutesToBoundaryScript()
        async throws
    {
        let gate = QinaoRiskGate()
        let assessment = QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: 0.8,
            requiresConsent: true,
            evidenceSufficient: true,
            matchedTemplateID: "tpl.surgery.schedule")
        let endpoint = StubWorldEndpoint(assessment: assessment)
        let ctx = QinaoRiskGate.WorldRiskContext(
            templateID: "tpl.surgery.schedule",
            consentAcknowledged: false)
        let action = try await gate.requestSurfaceAction(
            for: .safe,
            worldContext: ctx,
            worldEndpoint: endpoint,
            consentPromptKey: "consent.surgery")
        XCTAssertEqual(action.surface, .boundaryScript)
        XCTAssertEqual(action.agency, .userAffirm)
        XCTAssertEqual(action.disclosure, .explicit)
        XCTAssertEqual(
            action.substitute,
            .requestConsent(promptKey: "consent.surgery"))
        XCTAssertTrue(
            action.reasonCodes.contains("consent-required"))
    }

    func testRequestSurfaceActionWorldAwareUnknownTemplateThrows()
        async
    {
        let gate = QinaoRiskGate()
        let endpoint = StubWorldEndpoint(assessment: nil)
        let ctx = QinaoRiskGate.WorldRiskContext(
            templateID: "tpl.does.not.exist")
        do {
            _ = try await gate.requestSurfaceAction(
                for: .safe,
                worldContext: ctx,
                worldEndpoint: endpoint)
            XCTFail("unknown template must throw")
        } catch QinaoRiskGate.RiskError.unknownWorldTemplate(let id) {
            XCTAssertEqual(id, "tpl.does.not.exist")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
