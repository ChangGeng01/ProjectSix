import XCTest
@testable import BASWorldPrior

/// Tests for the L4 World Prior Vault: type contracts, registry
/// invariants, host-override evaluation, and built-in library
/// bootstrap.
///
/// The vault is a registry, so correctness == "every invariant the
/// spec promises (uniqueness, referential integrity, L5-cannot-
/// override-L4, min-3-counterfactual-branches) is enforced before a
/// caller can observe partial state".
final class BASWorldPriorVaultTests: XCTestCase {

    // MARK: - Evidence ladder

    func testEvidenceLadderOrdering() {
        XCTAssertLessThan(
            BASWorldPriorEvidenceLevel.contested,
            .speculative)
        XCTAssertLessThan(
            BASWorldPriorEvidenceLevel.speculative,
            .plausible)
        XCTAssertLessThan(
            BASWorldPriorEvidenceLevel.plausible,
            .wellSupported)
        XCTAssertLessThan(
            BASWorldPriorEvidenceLevel.wellSupported,
            .axiomatic)
    }

    func testEvidenceRankMonotonic() {
        let levels: [BASWorldPriorEvidenceLevel] = [
            .contested, .speculative, .plausible, .wellSupported, .axiomatic,
        ]
        for i in 0..<(levels.count - 1) {
            XCTAssertLessThan(levels[i].rank, levels[i + 1].rank)
        }
    }

    // MARK: - Domain normalization

    func testDomainNormalizesLowercase() {
        let d = BASWorldPriorDomain("Physics")
        XCTAssertEqual(d.rawValue, "physics")
        XCTAssertEqual(d, BASWorldPriorDomain.physics)
    }

    // MARK: - Registration happy-path

    func testRegisterHorizonAddsContent() async throws {
        let vault = BASWorldPriorVault()
        let tmpl = Self.sampleTemplate(id: "tmpl-a", domain: .body)
        let horizon = BASWorldPriorHorizon(
            domain: .body,
            templates: [tmpl])
        try await vault.registerHorizon(horizon)

        let fetched = await vault.template(id: "tmpl-a")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.domain, .body)

        let inDomain = await vault.templates(in: .body)
        XCTAssertEqual(inDomain.count, 1)
    }

    // MARK: - Uniqueness

    func testDuplicateHorizonDomainRejected() async throws {
        let vault = BASWorldPriorVault()
        try await vault.registerHorizon(
            BASWorldPriorHorizon(domain: .time))
        do {
            try await vault.registerHorizon(
                BASWorldPriorHorizon(domain: .time))
            XCTFail("expected duplicate-horizon error")
        } catch BASWorldPriorVault.VaultError.duplicateHorizonDomain(let d) {
            XCTAssertEqual(d, "time")
        }
    }

    func testDuplicateTemplateIDRejected() async throws {
        let vault = BASWorldPriorVault()
        let t = Self.sampleTemplate(id: "dup", domain: .body)
        try await vault.registerHorizon(
            BASWorldPriorHorizon(domain: .body, templates: [t]))
        do {
            try await vault.registerTemplate(
                Self.sampleTemplate(id: "dup", domain: .body))
            XCTFail("expected duplicate-template error")
        } catch BASWorldPriorVault.VaultError.duplicateTemplateID(let id) {
            XCTAssertEqual(id, "dup")
        }
    }

    // MARK: - Referential integrity

    func testBridgeReferencesUnknownTemplateRejected() async throws {
        let vault = BASWorldPriorVault()
        let t = Self.sampleTemplate(id: "t1", domain: .body)
        try await vault.registerHorizon(
            BASWorldPriorHorizon(domain: .body, templates: [t]))

        let brokenBridge = BASWorldPriorDomainBridge(
            id: "b1",
            sourceDomain: .body,
            targetDomain: .money,
            analogy: "missing-target test",
            templatePairings: [
                .init(
                    sourceTemplateID: "t1",
                    targetTemplateID: "does-not-exist")
            ]
        )
        do {
            try await vault.registerBridge(brokenBridge)
            XCTFail("expected bridge-references-unknown-template error")
        } catch BASWorldPriorVault.VaultError
            .bridgeReferencesUnknownTemplate(_, let tid)
        {
            XCTAssertEqual(tid, "does-not-exist")
        }
    }

    // audit policy-obs-misc LOW-8: a bridge whose sourceDomain has no horizon must be rejected,
    // not half-registered (findable by id but absent from any horizon's bridgesOutbound = unroutable).
    func testBridgeWithUnregisteredSourceDomainRejected() async throws {
        let vault = BASWorldPriorVault()
        let t = Self.sampleTemplate(id: "t1", domain: .body)
        try await vault.registerHorizon(
            BASWorldPriorHorizon(domain: .body, templates: [t]))
        // sourceDomain = .money has NO registered horizon, though the template pairings are valid.
        let bridge = BASWorldPriorDomainBridge(
            id: "b-nodomain",
            sourceDomain: .money,
            targetDomain: .body,
            analogy: "no source horizon",
            templatePairings: [.init(sourceTemplateID: "t1", targetTemplateID: "t1")])
        do {
            try await vault.registerBridge(bridge)
            XCTFail("expected bridgeReferencesUnknownDomain")
        } catch BASWorldPriorVault.VaultError
            .bridgeReferencesUnknownDomain(let bid, let dom)
        {
            XCTAssertEqual(bid, "b-nodomain")
            XCTAssertEqual(dom, "money")
        }
        let found = await vault.bridge(id: "b-nodomain")
        XCTAssertNil(found, "a rejected bridge must not land in bridgesByID (no half-registration)")
    }

    func testHorizonBridgeValidationIsAtomic() async throws {
        // If a horizon's bridgesOutbound reference an unknown template,
        // the entire registration must fail — the horizon's templates
        // and axioms must not leak into the vault.
        let vault = BASWorldPriorVault()
        let t = Self.sampleTemplate(id: "local-t", domain: .body)
        let ax = BASWorldPriorAxiom(
            id: "local-ax", domain: .body,
            statement: "local test axiom")
        let brokenBridge = BASWorldPriorDomainBridge(
            id: "local-bridge",
            sourceDomain: .body,
            targetDomain: .money,
            analogy: "atomic-fail test",
            templatePairings: [
                .init(
                    sourceTemplateID: "local-t",
                    targetTemplateID: "unknown-remote")
            ]
        )
        let horizon = BASWorldPriorHorizon(
            domain: .body,
            axioms: [ax],
            templates: [t],
            bridgesOutbound: [brokenBridge])

        do {
            try await vault.registerHorizon(horizon)
            XCTFail("expected atomic failure")
        } catch {
            // expected — now verify no state leaked
            let seenTmpl = await vault.template(id: "local-t")
            let seenAx = await vault.axiom(id: "local-ax")
            let seenHoriz = await vault.horizon(for: .body)
            XCTAssertNil(seenTmpl)
            XCTAssertNil(seenAx)
            XCTAssertNil(seenHoriz)
        }
    }

    // MARK: - Host override (BoundaryBedrock)

    func testHostOverrideCleanWhenNoAxiom() async {
        let vault = BASWorldPriorVault()
        let outcome = await vault.evaluateHostOverride(
            claimID: "no-such-axiom",
            declaredEvidence: .wellSupported,
            statement: "whatever")
        XCTAssertEqual(outcome, .clean)
    }

    func testHostOverrideRejectedByHigherAxiom() async throws {
        let vault = BASWorldPriorVault()
        let ax = BASWorldPriorAxiom(
            id: "ax-gravity",
            domain: .physics,
            statement: "objects fall")
        try await vault.registerHorizon(
            BASWorldPriorHorizon(domain: .physics, axioms: [ax]))

        let outcome = await vault.evaluateHostOverride(
            claimID: "ax-gravity",
            declaredEvidence: .plausible,
            statement: "objects float")
        if case .reject(let residentAx) = outcome {
            XCTAssertEqual(residentAx.id, "ax-gravity")
        } else {
            XCTFail("expected reject, got \(outcome)")
        }
    }

    func testHostOverrideDemotedWhenTie() async throws {
        let vault = BASWorldPriorVault()
        let ax = BASWorldPriorAxiom(
            id: "ax-plausible",
            domain: .social,
            statement: "people reciprocate favours",
            evidence: .plausible)
        try await vault.registerHorizon(
            BASWorldPriorHorizon(domain: .social, axioms: [ax]))

        let outcome = await vault.evaluateHostOverride(
            claimID: "ax-plausible",
            declaredEvidence: .plausible,
            statement: "people do not reciprocate")
        if case .demote(let residentAx, let effective) = outcome {
            XCTAssertEqual(residentAx.id, "ax-plausible")
            XCTAssertEqual(effective, .plausible)
        } else {
            XCTFail("expected demote, got \(outcome)")
        }
    }

    // MARK: - Helpers

    private static func sampleTemplate(
        id: String,
        domain: BASWorldPriorDomain
    ) -> BASWorldPriorCausalTemplate {
        BASWorldPriorCausalTemplate(
            id: id,
            domain: domain,
            preconditions: ["pre-1"],
            effect: "effect",
            effectKind: .stateTransition,
            blockers: ["blk-1"],
            reversibility: .bounded,
            latency: .prompt,
            evidence: .wellSupported)
    }
}
