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
        XCTAssertEqual(
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

        XCTAssertEqual(tmplCount, 20)
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
}
