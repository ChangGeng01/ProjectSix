import XCTest
@testable import BASWorldPrior

/// Tests for the counterfactual seeder — §9.3's "given a
/// MemoryAtom, produce ≥3 counterfactual branches" invariant.
final class BASWorldPriorCounterfactualSeederTests: XCTestCase {

    // MARK: - ≥3 branch guarantee

    func testAtLeastThreeBranchesForTemplateWithManyPreconditions()
        async throws
    {
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)
        let seeder = BASWorldPriorCounterfactualSeeder(vault: vault)

        let seed = BASWorldPriorCounterfactualSeed(
            templateID: "tmpl-time-deadline-compression",
            seedDescription: "tight deadline on a big project"
        )
        let branches = try await seeder.generate(from: seed)
        XCTAssertGreaterThanOrEqual(branches.count, 3)
    }

    func testAtLeastThreeBranchesForTemplateWithSparseBlockers()
        async throws
    {
        // tmpl-body-hydration has only 1 precondition and 0 blockers —
        // seeder must still pad to 3.
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)
        let seeder = BASWorldPriorCounterfactualSeeder(vault: vault)

        let branches = try await seeder.generate(
            templateID: "tmpl-body-hydration")
        XCTAssertGreaterThanOrEqual(branches.count, 3)
    }

    // MARK: - Perturbation kinds

    func testPerturbationKindsCoverAllThreeKinds() async throws {
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)
        let seeder = BASWorldPriorCounterfactualSeeder(vault: vault)

        // body-sleep-debt is the source of a built-in bridge →
        // exercises all three perturbation kinds.
        let branches = try await seeder.generate(
            templateID: "tmpl-body-sleep-debt")
        let kinds = Set(branches.map(\.perturbKind))
        XCTAssertTrue(kinds.contains(.dropPrecondition))
        XCTAssertTrue(kinds.contains(.crossDomain))
    }

    func testCrossDomainBranchCarriesBridgeID() async throws {
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)
        let seeder = BASWorldPriorCounterfactualSeeder(vault: vault)

        let branches = try await seeder.generate(
            templateID: "tmpl-body-sleep-debt")
        let crossDomain = branches.filter { $0.perturbKind == .crossDomain }
        XCTAssertFalse(crossDomain.isEmpty)
        for b in crossDomain {
            XCTAssertNotNil(b.bridgeID)
        }
    }

    // MARK: - Uncertainty propagation

    func testCrossDomainBranchIsDemotedTwoRungs() async throws {
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)
        let seeder = BASWorldPriorCounterfactualSeeder(vault: vault)

        // tmpl-learning-spacing (wellSupported) bridges to
        // tmpl-money-compounding via bridge-learning-to-money
        // (wellSupported). The cross-domain branch should be
        // demoted by 2 rungs from the min(wellSupported,
        // wellSupported) = wellSupported → speculative.
        let branches = try await seeder.generate(
            templateID: "tmpl-learning-spacing")
        let crossDomain = branches.first {
            $0.perturbKind == .crossDomain
        }
        XCTAssertNotNil(crossDomain)
        XCTAssertEqual(crossDomain?.branchEvidence, .speculative)
    }

    func testDropPreconditionBranchIsDemotedOneRung() async throws {
        let vault = BASWorldPriorVault()
        try await BASWorldPriorBuiltInLibrary.bootstrap(into: vault)
        let seeder = BASWorldPriorCounterfactualSeeder(vault: vault)

        // tmpl-money-budget-deplete is axiomatic; drop-precondition
        // should come back wellSupported (one rung down).
        let branches = try await seeder.generate(
            templateID: "tmpl-money-budget-deplete")
        let dropped = branches.first {
            $0.perturbKind == .dropPrecondition
        }
        XCTAssertNotNil(dropped)
        XCTAssertEqual(dropped?.branchEvidence, .wellSupported)
    }

    func testContestedBranchDoesNotDemoteBelowContested() async throws {
        // Register a contested template and verify we never go
        // below .contested.
        let vault = BASWorldPriorVault()
        let weakTemplate = BASWorldPriorCausalTemplate(
            id: "tmpl-weak",
            domain: .social,
            preconditions: ["some pre"],
            effect: "some effect",
            effectKind: .stateTransition,
            blockers: ["some blocker"],
            reversibility: .bounded,
            latency: .prompt,
            evidence: .contested)
        try await vault.registerHorizon(
            BASWorldPriorHorizon(
                domain: .social,
                templates: [weakTemplate]))

        let seeder = BASWorldPriorCounterfactualSeeder(vault: vault)
        let branches = try await seeder.generate(templateID: "tmpl-weak")
        for b in branches {
            XCTAssertGreaterThanOrEqual(
                b.branchEvidence.rank,
                BASWorldPriorEvidenceLevel.contested.rank)
        }
    }

    // MARK: - Error handling

    func testUnknownTemplateThrows() async throws {
        let vault = BASWorldPriorVault()
        let seeder = BASWorldPriorCounterfactualSeeder(vault: vault)
        do {
            _ = try await seeder.generate(templateID: "nope")
            XCTFail("expected unknownTemplate error")
        } catch BASWorldPriorCounterfactualSeeder.SeederError
            .unknownTemplate(let id)
        {
            XCTAssertEqual(id, "nope")
        }
    }
}
