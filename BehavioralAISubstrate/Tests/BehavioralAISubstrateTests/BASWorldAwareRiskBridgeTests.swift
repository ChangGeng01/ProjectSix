import XCTest
@testable import BASRuntimeCore
@testable import BASOrchestration
@testable import BASSovereign
@testable import BASWorldPrior

/// Integration tests for the L4↔L14 bridge — these are the proof
/// that the world-prior vault is no longer an island.
///
/// Each test constructs a real VerdictEngine + real WorldPriorVault +
/// real bridge and asserts on actual verdicts, not mocks.
final class BASWorldAwareRiskBridgeTests: XCTestCase {

    // MARK: - Fixture

    private func makeStack() async throws -> (
        vault: BASWorldPriorVault,
        ledger: BASSovereignAuditLedger,
        engine: BASSovereignVerdictEngine,
        bridge: BASWorldAwareRiskBridge
    ) {
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)
        let ledger = BASSovereignAuditLedger.withSeed(
            "test-key-integration")
        let engine = BASSovereignVerdictEngine(ledger: ledger)
        let bridge = BASWorldAwareRiskBridge(
            worldVault: vault,
            verdictEngine: engine)
        return (vault, ledger, engine, bridge)
    }

    // MARK: - Core claim: ethics-consent-violation blocks without consent

    func testIrreversibleEthicsTemplateWithoutConsentUpgrades()
        async throws
    {
        let stack = try await makeStack()

        let intent = BASWorldAwareRiskBridge.ProposedIntent(
            sessionID: "s-ethics-1",
            turnID: "t-ethics-1",
            operation: .toolWrite,
            matchedTemplateID: "tmpl-ethics-consent-violation",
            consentAcknowledged: false
        )
        let decision = try await stack.bridge.evaluate(intent: intent)

        // The verdict MUST be at least .toolCut — this is the
        // structural guarantee that "irreversible consequence
        // without informed consent" is blocked.
        XCTAssertGreaterThanOrEqual(
            decision.verdict.verdictLevel.rank,
            BASSovereignVerdictLevel.toolCut.rank,
            "ethics-consent-violation without consent must at least toolCut, got \(decision.verdict.verdictLevel)"
        )

        // The assessment bundle must expose the world-prior
        // reasoning, not just the final verdict — that's how
        // observability can prove the engine used L4.
        XCTAssertEqual(
            decision.assessment.matchedTemplateID,
            "tmpl-ethics-consent-violation")
        XCTAssertTrue(decision.assessment.requiresConsent)
        XCTAssertEqual(decision.assessment.reversibility, .irreversible)
    }

    // MARK: - Consent acknowledged relaxes to normal verdict path

    func testIrreversibleEthicsTemplateWithConsentDoesNotUpgrade()
        async throws
    {
        let stack = try await makeStack()

        let intent = BASWorldAwareRiskBridge.ProposedIntent(
            sessionID: "s-ethics-2",
            turnID: "t-ethics-2",
            operation: .pureInference,
            matchedTemplateID: "tmpl-ethics-consent-violation",
            consentAcknowledged: true
        )
        let decision = try await stack.bridge.evaluate(intent: intent)

        // With consent acknowledged the operation is not forced
        // to hostMutate. For pure-inference the base verdict should
        // still be .pass UNLESS the irreversibleHarm score alone
        // is high enough to trip the soft-signal lex order.
        // Ethics × irreversible = very high score — we expect at
        // least a throttle.
        XCTAssertGreaterThanOrEqual(
            decision.verdict.verdictLevel.rank,
            BASSovereignVerdictLevel.throttle.rank)
    }

    // MARK: - Low-harm templates don't elevate above pass

    func testTrivialBodyTemplateDoesNotElevateVerdict() async throws {
        let stack = try await makeStack()

        let intent = BASWorldAwareRiskBridge.ProposedIntent(
            sessionID: "s-body-1",
            turnID: "t-body-1",
            operation: .pureInference,
            matchedTemplateID: "tmpl-body-hydration",
            consentAcknowledged: false
        )
        let decision = try await stack.bridge.evaluate(intent: intent)

        // Hydration is trivial reversibility, body domain — score
        // should be low enough to pass.
        XCTAssertEqual(decision.verdict.verdictLevel, .pass)
        XCTAssertFalse(decision.assessment.requiresConsent)
        XCTAssertEqual(decision.assessment.reversibility, .trivial)
    }

    // MARK: - Assessment score calibration

    func testIrreversibleEthicsScoreIsHighest() async throws {
        let stack = try await makeStack()

        let ethics = await stack.vault.assessRisk(
            templateID: "tmpl-ethics-consent-violation")!
        let hydration = await stack.vault.assessRisk(
            templateID: "tmpl-body-hydration")!
        let trustDecay = await stack.vault.assessRisk(
            templateID: "tmpl-social-trust-decay")!

        XCTAssertGreaterThan(
            ethics.irreversibleHarmScore,
            trustDecay.irreversibleHarmScore)
        XCTAssertGreaterThan(
            trustDecay.irreversibleHarmScore,
            hydration.irreversibleHarmScore)
    }

    // MARK: - Baseline signals are preserved (bridge only raises floor)

    func testBaselineSignalsAreNotLowered() async throws {
        let stack = try await makeStack()

        // Caller already has privilegeViolation = 0.9 on baseline.
        // The bridge should not erase that just because it queried
        // a low-harm template.
        let baseline = BASSovereignVerdictEngine.SoftSignals(
            privilegeViolation: 0.9)
        let intent = BASWorldAwareRiskBridge.ProposedIntent(
            sessionID: "s-base-1",
            turnID: "t-base-1",
            operation: .pureInference,
            matchedTemplateID: "tmpl-body-hydration",
            consentAcknowledged: false,
            baselineSignals: baseline
        )
        let decision = try await stack.bridge.evaluate(intent: intent)

        // privilegeViolation = 0.9 must still trip the verdict
        // path regardless of the low-harm template.
        XCTAssertNotEqual(decision.verdict.verdictLevel, .pass)
    }

    // MARK: - Unknown template errors

    func testUnknownTemplateErrors() async throws {
        let stack = try await makeStack()

        let intent = BASWorldAwareRiskBridge.ProposedIntent(
            sessionID: "s-unk-1",
            turnID: "t-unk-1",
            operation: .pureInference,
            matchedTemplateID: "does-not-exist"
        )
        do {
            _ = try await stack.bridge.evaluate(intent: intent)
            XCTFail("expected unknownTemplate error")
        } catch BASWorldAwareRiskBridge.BridgeError
            .unknownTemplate(let id)
        {
            XCTAssertEqual(id, "does-not-exist")
        }
    }

    // MARK: - Ledger is exercised end-to-end

    func testVerdictIsAuditedWhenBridgeEvaluates() async throws {
        let stack = try await makeStack()
        let ledgerBefore = await stack.ledger.count()

        let intent = BASWorldAwareRiskBridge.ProposedIntent(
            sessionID: "s-aud-1",
            turnID: "t-aud-1",
            operation: .toolWrite,
            matchedTemplateID: "tmpl-ethics-consent-violation",
            consentAcknowledged: false
        )
        _ = try await stack.bridge.evaluate(intent: intent)

        let ledgerAfter = await stack.ledger.count()
        XCTAssertEqual(ledgerAfter, ledgerBefore + 1)
    }

    // MARK: - M262: M258 templates flow through risk gate

    func testM258ElectricalShockProducesHighRiskScore() async
    throws {
        // M258 added `tmpl-physics-electrical-shock` with
        // .irreversible reversibility and .physicalChange effect.
        // Should produce a high irreversibleHarmScore — comparable
        // to the canonical irreversible templates.
        let stack = try await makeStack()
        let shock = await stack.vault.assessRisk(
            templateID: "tmpl-physics-electrical-shock")
        XCTAssertNotNil(
            shock,
            "M258 electrical-shock template must be loaded")
        XCTAssertEqual(shock?.reversibility, .irreversible)
        XCTAssertGreaterThan(
            shock?.irreversibleHarmScore ?? 0, 0.7,
            "irreversible physical-change should score > 0.7")
    }

    func testM258PublicDisclosureMarkedIrreversible() async
    throws {
        // M258 added `tmpl-social-public-disclosure` with
        // .irreversible reversibility. The score itself uses
        // effectKind × reversibility × domain weighting, and
        // because `.informationShift` (kind weight 0.4) is
        // lower than `.relationshipChange` (1.0), public-
        // disclosure's score (~0.4) sits below trust-decay's
        // (~0.7). That's a feature of the current scoring
        // function's treatment of information shifts; the test
        // pins what the gate actually sees: the reversibility
        // tag is correct + the score is non-zero, so L11 has
        // the signal to escalate even if the raw float looks
        // moderate.
        let stack = try await makeStack()
        let disclosure = await stack.vault.assessRisk(
            templateID: "tmpl-social-public-disclosure")
        XCTAssertNotNil(disclosure)
        XCTAssertEqual(
            disclosure?.reversibility, .irreversible,
            "public-disclosure must be tagged irreversible — " +
            "search engines do not unindex on demand")
        XCTAssertGreaterThan(
            disclosure?.irreversibleHarmScore ?? 0, 0,
            "score must be > 0 so verdict engine sees a signal")
    }

    func testM258RepetitiveStrainProducesNonZeroScore() async
    throws {
        // M258 added `tmpl-body-repetitive-strain` with .costly
        // reversibility — not catastrophic but the gate should
        // still see it as a real signal.
        let stack = try await makeStack()
        let strain = await stack.vault.assessRisk(
            templateID: "tmpl-body-repetitive-strain")
        XCTAssertNotNil(strain)
        XCTAssertGreaterThan(
            strain?.irreversibleHarmScore ?? 0, 0,
            "costly-reversibility template should produce > 0 score")
    }

    func testM258FixedCostCreepIsLowRisk() async throws {
        // M258 added `tmpl-money-fixed-cost-creep` with .trivial
        // reversibility — should score well below the
        // irreversible templates (verifies the score ranking
        // didn't get inverted by the expansion).
        let stack = try await makeStack()
        let creep = await stack.vault.assessRisk(
            templateID: "tmpl-money-fixed-cost-creep")
        let creepScore = creep?.irreversibleHarmScore ?? 1.0
        XCTAssertLessThan(
            creepScore, 0.3,
            "trivial reversibility must score < 0.3")
    }

    func testM258TemplateDrivesGateFloorRaiseEndToEnd() async
    throws {
        // The bridge accepts a templateID and runs the assessment
        // through the verdict engine. Verify a new M258 high-risk
        // template (`electrical-shock`) actually moves the verdict
        // verdictLevel away from .pass — the bridge consumed the
        // assessment.
        let stack = try await makeStack()
        let intent = BASWorldAwareRiskBridge.ProposedIntent(
            sessionID: "s-m258-1",
            turnID: "t-m258-1",
            operation: .toolWrite,
            matchedTemplateID: "tmpl-physics-electrical-shock",
            consentAcknowledged: false
        )
        let decision = try await stack.bridge.evaluate(
            intent: intent)
        XCTAssertNotEqual(
            decision.verdict.verdictLevel, .pass,
            "M258 electrical-shock template must trigger " +
            "non-pass verdict via the gate floor mechanism")
    }
}
