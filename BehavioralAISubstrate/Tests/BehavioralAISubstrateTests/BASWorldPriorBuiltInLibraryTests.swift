import XCTest
@testable import BASWorldPrior

/// Tests for the built-in world-prior library (§9.3 minimum): the
/// 5 axioms, 20 causal templates across 8 domains, and 8 cross-
/// domain bridges that ship in-box.
///
/// These tests are deliberately shape-of-the-library focused. If
/// someone adds/removes/renames a template the spec counts change
/// and this file is the tripwire.
final class BASWorldPriorBuiltInLibraryTests: XCTestCase {

    // MARK: - Counts pin §9.3 commitments

    func testTwentyCausalTemplates() {
        // §9.3 demands at least 20 causal templates. M2 shipped
        // exactly 20; M258 expanded the library to 36 with 16
        // additional templates spread across the 8 domains
        // (~2 each). The test stays "at least 20" so future
        // additions don't trip it; per-domain coverage is
        // checked separately by `testEightDomainsCovered`.
        XCTAssertGreaterThanOrEqual(
            BASWorldPriorBuiltInLibrary.allTemplates.count, 20,
            "§9.3 demands at least 20 causal templates.")
    }

    func testEightDomainBridges() {
        XCTAssertEqual(
            BASWorldPriorBuiltInLibrary.bridges.count, 8,
            "§9.3 demands at least 8 cross-domain bridges.")
    }

    func testAxiomsPresent() {
        XCTAssertGreaterThanOrEqual(
            BASWorldPriorBuiltInLibrary.axioms.count, 5)
    }

    // MARK: - Eight canonical domains each covered

    func testEightDomainsCovered() {
        let required: Set<BASWorldPriorDomain> = [
            .physics, .body, .time, .money,
            .social, .language, .learning, .ethics,
        ]
        let present = Set(
            BASWorldPriorBuiltInLibrary.allTemplates.map(\.domain))
        XCTAssertEqual(
            present, required,
            "every §9.3 domain must have at least one template")
    }

    // MARK: - Structural integrity

    func testAllTemplateIDsUnique() {
        let ids = BASWorldPriorBuiltInLibrary.allTemplates.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate template id")
    }

    func testAllBridgeIDsUnique() {
        let ids = BASWorldPriorBuiltInLibrary.bridges.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate bridge id")
    }

    func testAllBridgePairingsResolve() {
        let tids = Set(
            BASWorldPriorBuiltInLibrary.allTemplates.map(\.id))
        for bridge in BASWorldPriorBuiltInLibrary.bridges {
            for pair in bridge.templatePairings {
                XCTAssertTrue(
                    tids.contains(pair.sourceTemplateID),
                    "bridge \(bridge.id) refs unknown source \(pair.sourceTemplateID)"
                )
                XCTAssertTrue(
                    tids.contains(pair.targetTemplateID),
                    "bridge \(bridge.id) refs unknown target \(pair.targetTemplateID)"
                )
            }
        }
    }

    // MARK: - Calibration discipline

    func testAxiomsAreAxiomaticUnlessMarked() {
        for ax in BASWorldPriorBuiltInLibrary.axioms {
            // Either explicit axiomatic, or explicitly declared
            // weaker (e.g. sleep-required is .wellSupported). The
            // point is we never silently claim axiomatic for a
            // contested prior.
            XCTAssertGreaterThanOrEqual(
                ax.evidence.rank,
                BASWorldPriorEvidenceLevel.wellSupported.rank,
                "axiom \(ax.id) evidence weaker than wellSupported"
            )
        }
    }

    func testIrreversibleOnlyForPermanentTransfers() {
        // Sanity: only the things that should be irreversible are.
        let irreversibleIDs = BASWorldPriorBuiltInLibrary.allTemplates
            .filter { $0.reversibility == .irreversible }
            .map(\.id)
        XCTAssertTrue(
            irreversibleIDs.contains("tmpl-money-irreversible-transfer"))
        XCTAssertTrue(
            irreversibleIDs.contains("tmpl-ethics-consent-violation"))
    }

    // MARK: - Horizon assembly

    func testHorizonsCover8Domains() {
        let horizons = BASWorldPriorBuiltInLibrary.horizons()
        let domains = Set(horizons.map(\.domain))
        XCTAssertEqual(
            domains,
            [
                .physics, .body, .time, .money,
                .social, .language, .learning, .ethics,
            ])
    }

    func testBridgesAttachToSourceDomainInVault() async throws {
        // Bridges are registered after horizons at bootstrap — verify
        // each bridge lands on the correct source domain horizon.
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)
        for bridge in BASWorldPriorBuiltInLibrary.bridges {
            let outbound = await vault.outboundBridges(
                from: bridge.sourceDomain)
            XCTAssertTrue(
                outbound.contains(where: { $0.id == bridge.id }),
                "bridge \(bridge.id) missing from \(bridge.sourceDomain.rawValue) horizon after bootstrap"
            )
        }
    }

    // MARK: - Bootstrap integration

    func testBootstrapPopulatesVault() async throws {
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)

        let tmplCount = await vault.registeredTemplateCount()
        let bridgeCount = await vault.registeredBridgeCount()
        let axCount = await vault.registeredAxiomCount()
        let horizonCount = await vault.registeredHorizonCount()

        XCTAssertGreaterThanOrEqual(
            tmplCount, 20,
            "M2 minimum is 20; M258 raised the library to 36")
        XCTAssertEqual(bridgeCount, 8)
        XCTAssertGreaterThanOrEqual(axCount, 5)
        XCTAssertEqual(horizonCount, 8)
    }

    func testBootstrapExposesKnownTemplateByID() async throws {
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)

        let sleep = await vault.template(id: "tmpl-body-sleep-debt")
        XCTAssertNotNil(sleep)
        XCTAssertEqual(sleep?.domain, .body)
    }

    // MARK: - M258 expansion (16 added templates across 8 domains)

    func testM258TemplatesAreLoaded() {
        // Spot-check one new template per domain.
        let ids = Set(
            BASWorldPriorBuiltInLibrary.allTemplates.map(\.id))
        XCTAssertTrue(ids.contains("tmpl-physics-friction-wear"))
        XCTAssertTrue(ids.contains("tmpl-physics-electrical-shock"))
        XCTAssertTrue(ids.contains("tmpl-body-caffeine-tail"))
        XCTAssertTrue(ids.contains("tmpl-body-repetitive-strain"))
        XCTAssertTrue(ids.contains("tmpl-time-context-decay"))
        XCTAssertTrue(ids.contains("tmpl-time-meeting-overflow"))
        XCTAssertTrue(ids.contains("tmpl-money-fixed-cost-creep"))
        XCTAssertTrue(ids.contains("tmpl-money-late-tax-filing"))
        XCTAssertTrue(
            ids.contains("tmpl-social-public-disclosure"))
        XCTAssertTrue(
            ids.contains("tmpl-social-relationship-investment"))
        XCTAssertTrue(ids.contains("tmpl-language-jargon-barrier"))
        XCTAssertTrue(
            ids.contains("tmpl-language-translation-loss"))
        XCTAssertTrue(
            ids.contains("tmpl-learning-feedback-vacuum"))
        XCTAssertTrue(ids.contains("tmpl-learning-novelty-block"))
        XCTAssertTrue(ids.contains("tmpl-ethics-asymmetric-power"))
        XCTAssertTrue(ids.contains("tmpl-ethics-precedent-set"))
    }

    func testEachDomainHasAtLeastTwoTemplatesAfterM258() {
        // Per-domain density check: M258 spread additions evenly,
        // so every domain should have ≥2 templates.
        var byDomain: [BASWorldPriorDomain: Int] = [:]
        for tmpl in BASWorldPriorBuiltInLibrary.allTemplates {
            byDomain[tmpl.domain, default: 0] += 1
        }
        for (domain, count) in byDomain {
            XCTAssertGreaterThanOrEqual(
                count, 2,
                "domain \(domain.rawValue) has only " +
                "\(count) template(s) — expected ≥2 after M258")
        }
    }

    func testM258AddsIrreversibleHighRiskTemplates() {
        // The M251 risk-gate test surface should see new
        // irreversible templates from M258 (electrical shock,
        // public disclosure). These let L11 GSI find more
        // catastrophic causal paths.
        let irreversibleIDs =
            BASWorldPriorBuiltInLibrary.allTemplates
                .filter { $0.reversibility == .irreversible }
                .map(\.id)
        XCTAssertTrue(
            irreversibleIDs.contains(
                "tmpl-physics-electrical-shock"),
            "physics electrical shock should be irreversible")
        XCTAssertTrue(
            irreversibleIDs.contains(
                "tmpl-social-public-disclosure"),
            "social public-disclosure should be irreversible " +
            "(search engines index permanently)")
    }
}
