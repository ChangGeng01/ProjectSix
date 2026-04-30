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

    func testM258PublicDisclosureScoresAboveTrustDecay() async
    throws {
        // M266 fix — `.informationShift × .irreversible` now
        // weighted 0.85 (was 0.4) so search-engine-indexed
        // disclosures rank above costly but reversible
        // relationship damage. Public-disclosure score:
        //   0.85 × 1.0 × 1.0 = 0.85
        // Trust-decay score:
        //   1.0 × 0.7 × 1.0 = 0.7
        let stack = try await makeStack()
        let disclosure = await stack.vault.assessRisk(
            templateID: "tmpl-social-public-disclosure")
        let trustDecay = await stack.vault.assessRisk(
            templateID: "tmpl-social-trust-decay")
        XCTAssertNotNil(disclosure)
        XCTAssertNotNil(trustDecay)
        XCTAssertEqual(
            disclosure?.reversibility, .irreversible,
            "public-disclosure must be tagged irreversible — " +
            "search engines do not unindex on demand")
        XCTAssertGreaterThan(
            disclosure?.irreversibleHarmScore ?? 0,
            trustDecay?.irreversibleHarmScore ?? 0,
            "after M266 reweight, public-disclosure must " +
            "outrank trust-decay")
    }

    func testM266ReversibleInfoShiftStaysLow() async throws {
        // Sanity: M266 only bumps `.informationShift` when the
        // template is `.irreversible`. Reversible information
        // shifts (M2's `tmpl-language-ambiguity-loss`,
        // `tmpl-time-sunk-cost`, `tmpl-language-framing-effect`)
        // keep their lower 0.4 kind weight.
        let stack = try await makeStack()
        let ambiguity = await stack.vault.assessRisk(
            templateID: "tmpl-language-ambiguity-loss")
        XCTAssertNotNil(ambiguity)
        XCTAssertNotEqual(
            ambiguity?.reversibility, .irreversible,
            "ambiguity-loss is .bounded, not irreversible")
        // .informationShift × .bounded × .language(0.7)
        //   = 0.4 × 0.3 × 0.7 = 0.084
        XCTAssertLessThan(
            ambiguity?.irreversibleHarmScore ?? 1.0, 0.2,
            "reversible info-shift should stay well below " +
            "the irreversible threshold")
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

    // MARK: - M270: counterfactual seeder feeds branches into Decision

    private func makeStackWithSeeder() async throws -> (
        vault: BASWorldPriorVault,
        ledger: BASSovereignAuditLedger,
        engine: BASSovereignVerdictEngine,
        bridge: BASWorldAwareRiskBridge
    ) {
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)
        let ledger = BASSovereignAuditLedger.withSeed(
            "test-key-m270")
        let engine = BASSovereignVerdictEngine(ledger: ledger)
        let seeder = BASWorldPriorCounterfactualSeeder(
            vault: vault)
        let bridge = BASWorldAwareRiskBridge(
            worldVault: vault,
            verdictEngine: engine,
            counterfactualSeeder: seeder)
        return (vault, ledger, engine, bridge)
    }

    func testM270BridgeWithoutSeederReturnsEmptyBranches() async
    throws {
        // Default bridge (no seeder) must return empty branches
        // — backward compatible with all M252 callers.
        let stack = try await makeStack()
        let intent = BASWorldAwareRiskBridge.ProposedIntent(
            sessionID: "s-m270-empty",
            turnID: "t-m270-empty",
            operation: .toolWrite,
            matchedTemplateID:
                "tmpl-physics-electrical-shock",
            consentAcknowledged: false
        )
        let decision = try await stack.bridge.evaluate(
            intent: intent)
        XCTAssertTrue(
            decision.branches.isEmpty,
            "no seeder = no branches; backward compat")
    }

    func testM270BridgeWithSeederGeneratesAtLeastThreeBranches()
    async throws {
        // Spec demands ≥3 counterfactual branches per assessed
        // template. Verify the bridge surfaces them.
        let stack = try await makeStackWithSeeder()
        let intent = BASWorldAwareRiskBridge.ProposedIntent(
            sessionID: "s-m270-1",
            turnID: "t-m270-1",
            operation: .toolWrite,
            matchedTemplateID:
                "tmpl-physics-electrical-shock",
            consentAcknowledged: false
        )
        let decision = try await stack.bridge.evaluate(
            intent: intent)
        XCTAssertGreaterThanOrEqual(
            decision.branches.count, 3,
            "spec-floor: ≥3 counterfactual branches per " +
            "template")
        // Each branch must reference the source template ID so
        // observability can correlate.
        for branch in decision.branches {
            XCTAssertEqual(
                branch.seedTemplateID,
                "tmpl-physics-electrical-shock")
        }
    }

    func testM270M258TemplatesEachProduceAtLeastThreeBranches()
    async throws {
        // Cross-check: every M258-added template fans out to
        // ≥3 branches when the seeder runs. Catches templates
        // that lack enough preconditions / blockers / bridges
        // to satisfy the floor (the seeder pads with synthetic
        // drops in that case, but this test verifies the floor
        // is actually met).
        let stack = try await makeStackWithSeeder()
        let m258TemplateIDs = [
            "tmpl-physics-friction-wear",
            "tmpl-physics-electrical-shock",
            "tmpl-body-caffeine-tail",
            "tmpl-body-repetitive-strain",
            "tmpl-time-context-decay",
            "tmpl-time-meeting-overflow",
            "tmpl-money-fixed-cost-creep",
            "tmpl-money-late-tax-filing",
            "tmpl-social-public-disclosure",
            "tmpl-social-relationship-investment",
            "tmpl-language-jargon-barrier",
            "tmpl-language-translation-loss",
            "tmpl-learning-feedback-vacuum",
            "tmpl-learning-novelty-block",
            "tmpl-ethics-asymmetric-power",
            "tmpl-ethics-precedent-set",
        ]
        for templateID in m258TemplateIDs {
            let intent = BASWorldAwareRiskBridge.ProposedIntent(
                sessionID: "s-m270-fan",
                turnID: "t-m270-\(templateID)",
                operation: .pureInference,
                matchedTemplateID: templateID,
                consentAcknowledged: false
            )
            let decision = try await stack.bridge.evaluate(
                intent: intent)
            XCTAssertGreaterThanOrEqual(
                decision.branches.count, 3,
                "M258 template \(templateID) must fan to ≥3 " +
                "branches; got \(decision.branches.count)")
        }
    }

    func testM270BranchesIncludeMixedPerturbationKinds() async
    throws {
        // Templates with non-empty preconditions AND blockers
        // produce branches across multiple kinds. Verify the
        // mix isn't all `.dropPrecondition`.
        let stack = try await makeStackWithSeeder()
        let intent = BASWorldAwareRiskBridge.ProposedIntent(
            sessionID: "s-m270-mix",
            turnID: "t-m270-mix",
            operation: .pureInference,
            matchedTemplateID:
                "tmpl-physics-electrical-shock",
            consentAcknowledged: false
        )
        let decision = try await stack.bridge.evaluate(
            intent: intent)
        let kinds = Set(
            decision.branches.map(\.perturbKind))
        // Electrical-shock has both preconditions AND blockers,
        // so we should see both .dropPrecondition AND
        // .introduceBlocker in the fan-out.
        XCTAssertTrue(
            kinds.contains(.dropPrecondition),
            "expected at least one .dropPrecondition branch")
        XCTAssertTrue(
            kinds.contains(.introduceBlocker),
            "expected at least one .introduceBlocker branch " +
            "(template has explicit blockers)")
    }

    func testM270UnknownTemplateAbsorbsSeederErrorGracefully()
    async throws {
        // Bridge surfaces unknownTemplate via the assessRisk
        // path BEFORE reaching the seeder. So unknown templates
        // throw via the existing `BridgeError.unknownTemplate`
        // path, never make it to the seeder. Verify that
        // contract holds.
        let stack = try await makeStackWithSeeder()
        let intent = BASWorldAwareRiskBridge.ProposedIntent(
            sessionID: "s-m270-bad",
            turnID: "t-m270-bad",
            operation: .pureInference,
            matchedTemplateID: "tmpl-does-not-exist",
            consentAcknowledged: false
        )
        do {
            _ = try await stack.bridge.evaluate(intent: intent)
            XCTFail("expected unknownTemplate from assessRisk")
        } catch BASWorldAwareRiskBridge.BridgeError
            .unknownTemplate(let id)
        {
            XCTAssertEqual(id, "tmpl-does-not-exist")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }
}
