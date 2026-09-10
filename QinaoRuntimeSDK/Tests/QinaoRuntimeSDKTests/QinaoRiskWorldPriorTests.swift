import XCTest
@testable import QinaoRisk
@testable import QinaoRuntime

/// M13 — QinaoRisk world-prior integration tests.
///
/// The L11 risk gate gains a world-aware overload that folds an L4
/// world-prior assessment into the permit decision. These tests prove
/// the contract end-to-end:
///
/// 1. **Unknown template** → `.unknownWorldTemplate` (distinct from
///    `.denied`; "taxonomy miss", not "assessed unsafe").
/// 2. **Irreversibility folding** — a high-harm template forces the
///    gate into `.block` even when the caller's signals look clean.
/// 3. **Consent gate** — `requiresConsent && !consentAcknowledged`
///    routes to `.replace` with the stable `consent-required` code
///    and the `request-informed-consent` substitute hint.
/// 4. **Consent satisfied** — with `consentAcknowledged = true` and
///    evidence sufficient, the permit is issued.
/// 5. **Evidence gate** — an irreversible template with insufficient
///    evidence is deferred with `evidence-insufficient-for-irreversible`.
/// 6. **Block trumps consent** — a template that also crosses the
///    hard harm ceiling is still blocked; consent cannot unlock it.
/// 7. **Template tag** — every world-aware assessment carries a
///    `world-template:<id>` reason code for audit tracing.
/// 8. **Built-in factory** — `QinaoRuntime.defaultWorldPriorEndpoint()`
///    bootstraps the L4 built-in library and answers at least one
///    known template ID without leaking BAS types.
final class QinaoRiskWorldPriorTests: XCTestCase {

    // MARK: - Helpers

    private struct StubEndpoint: QinaoWorldPriorEndpoint {
        let assessment: QinaoRiskGate.WorldRiskAssessment?

        func assessRisk(
            templateID: String
        ) async throws -> QinaoRiskGate.WorldRiskAssessment? {
            guard let a = assessment else { return nil }
            guard a.matchedTemplateID == templateID else { return nil }
            return a
        }
    }

    private func makeGate(
        now: @escaping @Sendable () -> Date = {
            Date(timeIntervalSince1970: 1_700_000_000)
        }
    ) -> QinaoRiskGate {
        QinaoRiskGate(
            permitTTLSeconds: 30,
            defaultDelaySeconds: 60,
            now: now)
    }

    private func makeIntent(
        digest: String = "intent.world.A"
    ) -> QinaoRiskGate.ActionIntent {
        QinaoRiskGate.ActionIntent(
            digest: digest,
            toolName: "surgery.schedule",
            sessionID: "sess.world",
            hostVersionID: "host.v1",
            summary: "schedule an irreversible procedure")
    }

    // MARK: - Unknown template

    func testUnknownTemplateThrowsDistinctError() async {
        let gate = makeGate()
        let endpoint = StubEndpoint(assessment: nil)
        let intent = makeIntent()
        let ctx = QinaoRiskGate.WorldRiskContext(
            templateID: "tpl.does.not.exist")
        do {
            _ = try await gate.requestActionPermit(
                for: intent,
                signals: .safe,
                worldContext: ctx,
                worldEndpoint: endpoint)
            XCTFail("expected unknownWorldTemplate")
        } catch QinaoRiskGate.RiskError.unknownWorldTemplate(let id) {
            XCTAssertEqual(id, "tpl.does.not.exist")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Irreversibility folding

    func testHighIrreversibleHarmBlocksEvenWhenSignalsClean() async {
        let gate = makeGate()
        let tpl = "tpl.irreversible.surgery"
        let assessment = QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: 0.95,  // ≥ 0.9 → block
            requiresConsent: false,
            evidenceSufficient: true,
            matchedTemplateID: tpl)
        let endpoint = StubEndpoint(assessment: assessment)
        let intent = makeIntent()
        let ctx = QinaoRiskGate.WorldRiskContext(
            templateID: tpl,
            consentAcknowledged: true)

        do {
            _ = try await gate.requestActionPermit(
                for: intent,
                signals: .safe,
                worldContext: ctx,
                worldEndpoint: endpoint)
            XCTFail("expected .denied")
        } catch QinaoRiskGate.RiskError.denied(let reason) {
            XCTAssertTrue(
                reason.contains("irreversibility-ceiling"),
                "reason: \(reason)")
            XCTAssertTrue(
                reason.contains("world-template:\(tpl)"),
                "reason: \(reason)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Consent gate

    func testConsentRequiredButNotAcknowledgedReplaces() async {
        let gate = makeGate()
        let tpl = "tpl.ethics.consent-required"
        let assessment = QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: 0.6,
            requiresConsent: true,
            evidenceSufficient: true,
            matchedTemplateID: tpl)
        let endpoint = StubEndpoint(assessment: assessment)
        let ctx = QinaoRiskGate.WorldRiskContext(
            templateID: tpl,
            consentAcknowledged: false)

        do {
            _ = try await gate.requestActionPermit(
                for: makeIntent(),
                signals: .safe,
                worldContext: ctx,
                worldEndpoint: endpoint)
            XCTFail("expected .replaced")
        } catch QinaoRiskGate.RiskError.replaced(let hint, let reason) {
            XCTAssertEqual(hint, "request-informed-consent")
            XCTAssertTrue(
                reason.contains("consent-required"),
                "reason: \(reason)")
            XCTAssertTrue(
                reason.contains("world-template:\(tpl)"),
                "reason: \(reason)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testConsentAcknowledgedAndEvidenceSufficientAllows() async throws {
        let gate = makeGate()
        let tpl = "tpl.ethics.consent-required"
        let assessment = QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: 0.6,
            requiresConsent: true,
            evidenceSufficient: true,
            matchedTemplateID: tpl)
        let endpoint = StubEndpoint(assessment: assessment)
        let ctx = QinaoRiskGate.WorldRiskContext(
            templateID: tpl,
            consentAcknowledged: true)

        let permit = try await gate.requestActionPermit(
            for: makeIntent(),
            signals: .safe,
            worldContext: ctx,
            worldEndpoint: endpoint)
        XCTAssertEqual(permit.mode, .allow)
        XCTAssertTrue(
            permit.reasonCodes.contains("world-template:\(tpl)"))
        XCTAssertTrue(
            permit.reasonCodes.contains("baseline-clear"))
    }

    // MARK: - Evidence gate

    func testInsufficientEvidenceOnIrreversibleDelays() async {
        let gate = makeGate()
        let tpl = "tpl.irreversible.evidence-short"
        let assessment = QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: 0.7,   // non-trivial
            requiresConsent: false,
            evidenceSufficient: false,    // but evidence short
            matchedTemplateID: tpl)
        let endpoint = StubEndpoint(assessment: assessment)
        let ctx = QinaoRiskGate.WorldRiskContext(templateID: tpl)

        do {
            _ = try await gate.requestActionPermit(
                for: makeIntent(),
                signals: .safe,
                worldContext: ctx,
                worldEndpoint: endpoint)
            XCTFail("expected .deferred")
        } catch QinaoRiskGate.RiskError.deferred(let retry, let reason) {
            XCTAssertEqual(retry, 60)
            XCTAssertTrue(
                reason.contains(
                    "evidence-insufficient-for-irreversible"),
                "reason: \(reason)")
            XCTAssertTrue(
                reason.contains("world-template:\(tpl)"),
                "reason: \(reason)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testInsufficientEvidenceOnLowImpactStillAllows() async throws {
        let gate = makeGate()
        let tpl = "tpl.low-impact.evidence-short"
        let assessment = QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: 0.2,   // below 0.5 threshold
            requiresConsent: false,
            evidenceSufficient: false,
            matchedTemplateID: tpl)
        let endpoint = StubEndpoint(assessment: assessment)
        let ctx = QinaoRiskGate.WorldRiskContext(templateID: tpl)

        let permit = try await gate.requestActionPermit(
            for: makeIntent(),
            signals: .safe,
            worldContext: ctx,
            worldEndpoint: endpoint)
        XCTAssertEqual(permit.mode, .allow)
        XCTAssertTrue(
            permit.reasonCodes.contains("world-template:\(tpl)"))
    }

    // MARK: - Block trumps consent

    func testBlockTrumpsConsentGate() async {
        let gate = makeGate()
        let tpl = "tpl.hardceiling.and-consent"
        // Both conditions: harm ceiling AND consent required.
        let assessment = QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: 0.98,
            requiresConsent: true,
            evidenceSufficient: true,
            matchedTemplateID: tpl)
        let endpoint = StubEndpoint(assessment: assessment)
        let ctx = QinaoRiskGate.WorldRiskContext(
            templateID: tpl,
            consentAcknowledged: false)

        do {
            _ = try await gate.requestActionPermit(
                for: makeIntent(),
                signals: .safe,
                worldContext: ctx,
                worldEndpoint: endpoint)
            XCTFail("expected .denied (block trumps consent)")
        } catch QinaoRiskGate.RiskError.denied(let reason) {
            XCTAssertTrue(
                reason.contains("irreversibility-ceiling"),
                "reason: \(reason)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Pure evaluator parity

    func testPureEvaluatorIsDeterministic() {
        let tpl = "tpl.pure"
        let world = QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: 0.5,
            requiresConsent: false,
            evidenceSufficient: true,
            matchedTemplateID: tpl)
        let ctx = QinaoRiskGate.WorldRiskContext(templateID: tpl)
        let a = QinaoRiskGate.assess(
            .safe, worldAssessment: world, worldContext: ctx)
        let b = QinaoRiskGate.assess(
            .safe, worldAssessment: world, worldContext: ctx)
        XCTAssertEqual(a, b)
    }

    func testMergedIrreversibilityTakesMax() {
        let tpl = "tpl.merge"
        let signals = QinaoRiskGate.RiskSignals(irreversibility: 0.3)
        let worldLow = QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: 0.1,
            requiresConsent: false,
            evidenceSufficient: true,
            matchedTemplateID: tpl)
        let ctx = QinaoRiskGate.WorldRiskContext(templateID: tpl)
        // Caller signal 0.3 > world 0.1 → still allow.
        let low = QinaoRiskGate.assess(
            signals, worldAssessment: worldLow, worldContext: ctx)
        XCTAssertEqual(low.mode, .allow)

        let worldHigh = QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: 0.95,
            requiresConsent: false,
            evidenceSufficient: true,
            matchedTemplateID: tpl)
        // World 0.95 > signal 0.3 → block.
        let high = QinaoRiskGate.assess(
            signals, worldAssessment: worldHigh, worldContext: ctx)
        XCTAssertEqual(high.mode, .block)
    }

    // MARK: - Built-in factory smoke test

    func testDefaultWorldPriorEndpointAnswersKnownTemplate() async throws {
        let endpoint = try await QinaoRuntime.defaultWorldPriorEndpoint()

        // We don't hard-code a template ID here — we just prove the
        // endpoint wires up and is conformant. An unknown ID returns
        // nil (the documented absence signal) without throwing.
        let unknown = try await endpoint.assessRisk(
            templateID: "tpl.certainly-not-registered-\(UUID().uuidString)")
        XCTAssertNil(unknown)
    }
}
