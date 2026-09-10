import XCTest
@testable import QinaoWorldPrior

/// M50 — L4 world-prior vault façade.
///
/// Before M50, `L4` was only reachable from hosts indirectly through
/// the `QinaoRisk` permit gate (M13 `QinaoRiskWorldPriorTests`).
/// Hosts couldn't inspect what the second brain knew about the
/// world, only accept or reject its downstream risk verdicts. That
/// made "懂世界也懂宿主" half-truthful at the SDK boundary.
///
/// M50 closes the gap by exposing the substrate's
/// `BASWorldPriorVault` as a Qinao-owned actor with Qinao-owned
/// mirror types — hosts never need to import `BASWorldPrior` to
/// query the canonical 20-template × 8-domain × 8-bridge library,
/// register custom templates, or ask the boundary-bedrock guard
/// about a proposed host override.
///
/// Contract covered here:
///
/// 1. Empty bootstrap produces an empty vault.
/// 2. Seeded bootstrap pre-loads 8 domains, ≥20 templates, ≥8
///    bridges, ≥5 axioms from the canonical built-in library.
/// 3. All query paths (`domains`, `templates(in:)`, `template(id:)`,
///    `axioms(in:)`, `bridgesOutbound(from:)`, `bridgesInbound(to:)`)
///    round-trip through `QinaoWorldPriorProjection` without losing
///    field fidelity.
/// 4. `counterfactualBranches(for:)` produces ≥3 branches per the
///    substrate spec; unknown template IDs surface as a typed
///    `.unknownTemplate(id:)` VaultError.
/// 5. `evaluateHostOverride` covers all three BoundaryBedrock
///    outcomes (`.clean` / `.demote` / `.reject`) with the correct
///    axiom referenced and the correct effective evidence emitted.
/// 6. `registerTemplate` + `registerBridge` grow-path honours the
///    substrate's duplicate-ID and unknown-template-ref guards and
///    translates BAS errors into the Qinao-owned `VaultError`
///    surface.
final class QinaoWorldPriorTests: XCTestCase {

    // MARK: - Bootstrap

    /// Empty vault has zero templates, zero bridges, zero axioms,
    /// zero horizons.
    func testEmptyInitProducesEmptyVault() async {
        let vault = QinaoWorldPriorVault()
        let templateCount = await vault.templateCount()
        let bridgeCount = await vault.bridgeCount()
        let axiomCount = await vault.axiomCount()
        let horizonCount = await vault.horizonCount()
        XCTAssertEqual(templateCount, 0)
        XCTAssertEqual(bridgeCount, 0)
        XCTAssertEqual(axiomCount, 0)
        XCTAssertEqual(horizonCount, 0)
    }

    /// Seeded vault pre-loads the canonical library: 8 domains, at
    /// least 20 causal templates (per §9.3 design), at least 8
    /// cross-domain bridges, and at least 5 BoundaryBedrock axioms.
    func testSeededInitLoadsCanonicalLibrary() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)

        let domains = await vault.domains()
        XCTAssertEqual(domains.count, 8)
        XCTAssertTrue(domains.contains(.physics))
        XCTAssertTrue(domains.contains(.body))
        XCTAssertTrue(domains.contains(.time))
        XCTAssertTrue(domains.contains(.money))
        XCTAssertTrue(domains.contains(.social))
        XCTAssertTrue(domains.contains(.language))
        XCTAssertTrue(domains.contains(.learning))
        XCTAssertTrue(domains.contains(.ethics))

        let templateCount = await vault.templateCount()
        let bridgeCount = await vault.bridgeCount()
        let axiomCount = await vault.axiomCount()
        XCTAssertGreaterThanOrEqual(templateCount, 20)
        XCTAssertGreaterThanOrEqual(bridgeCount, 8)
        XCTAssertGreaterThanOrEqual(axiomCount, 5)
    }

    /// `domains()` returns the registered domains sorted on
    /// `rawValue` ascending so any two consumers reading the vault
    /// see the same listing order — reproducibility matters for
    /// snapshots and diffs.
    func testDomainsAreSortedAscending() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let domains = await vault.domains()
        let raw = domains.map(\.rawValue)
        XCTAssertEqual(raw, raw.sorted())
    }

    // MARK: - Template queries

    /// `.body` holds the canonical body templates:
    /// sleep-debt / hydration / exercise-mood (M2 trio) plus the
    /// M258 additions (caffeine-tail, repetitive-strain).
    /// Test pins the canonical IDs and uses `>=` for total
    /// count so future M258-style expansions don't trip it.
    func testBodyDomainHoldsItsThreeBuiltInTemplates() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let body = await vault.templates(in: .body)
        let ids = Set(body.map(\.id))
        XCTAssertGreaterThanOrEqual(
            body.count, 3,
            "body domain must have ≥3 templates (M2 minimum)")
        XCTAssertTrue(ids.contains("tmpl-body-sleep-debt"))
        XCTAssertTrue(ids.contains("tmpl-body-hydration"))
        XCTAssertTrue(ids.contains("tmpl-body-exercise-mood"))
        // M258 expansions — present after the library expansion
        XCTAssertTrue(ids.contains("tmpl-body-caffeine-tail"))
        XCTAssertTrue(ids.contains("tmpl-body-repetitive-strain"))
    }

    /// A known template id round-trips: `template(id:)` returns a
    /// template whose scalar fields match the canonical library.
    /// This is the projection parity proof on the read side.
    func testKnownTemplateRoundTripsWithAllFields() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let tmpl = await vault.template(id: "tmpl-body-sleep-debt")
        XCTAssertNotNil(tmpl)
        XCTAssertEqual(tmpl?.id, "tmpl-body-sleep-debt")
        XCTAssertEqual(tmpl?.domain, .body)
        XCTAssertEqual(tmpl?.effectKind, .stateTransition)
        XCTAssertEqual(tmpl?.reversibility, .bounded)
        XCTAssertEqual(tmpl?.latency, .cumulative)
        XCTAssertEqual(tmpl?.evidence, .wellSupported)
        XCTAssertFalse(tmpl?.preconditions.isEmpty ?? true)
        XCTAssertFalse(tmpl?.effect.isEmpty ?? true)
    }

    /// Unknown template ID returns nil — absence signal, not an
    /// error (consistent with BAS semantics).
    func testUnknownTemplateLookupReturnsNil() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let missing = await vault.template(
            id: "tmpl-does-not-exist")
        XCTAssertNil(missing)
    }

    // MARK: - Axiom queries

    /// `.physics` has at least the gravity + conservation axioms.
    /// Both are `.axiomatic` evidence level — BoundaryBedrock.
    func testPhysicsAxiomsAreAxiomatic() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let axioms = await vault.axioms(in: .physics)
        XCTAssertGreaterThanOrEqual(axioms.count, 2)
        for axiom in axioms {
            XCTAssertEqual(axiom.evidence, .axiomatic)
            XCTAssertEqual(axiom.domain, .physics)
        }
    }

    // MARK: - Bridge queries

    /// The canonical library includes bridges that land in `.money`
    /// (e.g. body↔money, learning↔money, social↔money).
    /// `bridgesInbound(to:)` walks the registry and sorts by id
    /// ascending so the list is reproducible.
    func testBridgesInboundToMoneyIsNonEmptyAndSorted() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let inbound = await vault.bridgesInbound(to: .money)
        XCTAssertFalse(inbound.isEmpty)
        let ids = inbound.map(\.id)
        XCTAssertEqual(ids, ids.sorted())
        for bridge in inbound {
            XCTAssertEqual(bridge.targetDomain, .money)
        }
    }

    /// `bridgesOutbound(from:)` returns only bridges whose source
    /// domain matches the queried domain.
    func testBridgesOutboundFromBodyAllOriginateInBody() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let outbound = await vault.bridgesOutbound(from: .body)
        XCTAssertFalse(outbound.isEmpty)
        for bridge in outbound {
            XCTAssertEqual(bridge.sourceDomain, .body)
        }
    }

    // MARK: - Counterfactual seeder

    /// Every known template produces ≥3 counterfactual branches.
    /// The substrate's `BASWorldPriorCounterfactualSeeder.minBranches`
    /// invariant is the backing contract.
    func testCounterfactualBranchesMeetMinCountInvariant() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let branches = try await vault.counterfactualBranches(
            for: "tmpl-body-sleep-debt")
        XCTAssertGreaterThanOrEqual(branches.count, 3)
        for branch in branches {
            XCTAssertEqual(branch.seedTemplateID, "tmpl-body-sleep-debt")
        }
    }

    /// Unknown template ID surfaces as a typed Qinao `VaultError`
    /// (not a raw `BASWorldPriorCounterfactualSeeder.SeederError`),
    /// so hosts can pattern-match on the Qinao-owned surface.
    func testUnknownTemplateInSeederThrowsTypedError() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        do {
            _ = try await vault.counterfactualBranches(
                for: "tmpl-does-not-exist")
            XCTFail("expected unknownTemplate")
        } catch QinaoWorldPriorVault.VaultError
            .unknownTemplate(let id) {
            XCTAssertEqual(id, "tmpl-does-not-exist")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - BoundaryBedrock override guard

    /// Unknown claim ID → `.clean` (no axiom to collide with).
    func testUnknownClaimOverrideIsClean() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let outcome = await vault.evaluateHostOverride(
            claimID: "claim-does-not-exist",
            declaredEvidence: .wellSupported,
            statement: "whatever")
        XCTAssertEqual(outcome, .clean)
    }

    /// Known axiom with byte-identical statement → `.clean` (no
    /// collision to resolve).
    func testByteIdenticalStatementOverrideIsClean() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let gravity = await vault.axiom(
            id: "axiom-physics-gravity")
        XCTAssertNotNil(gravity)
        let outcome = await vault.evaluateHostOverride(
            claimID: "axiom-physics-gravity",
            declaredEvidence: .axiomatic,
            statement: gravity?.statement ?? "")
        XCTAssertEqual(outcome, .clean)
    }

    /// Host declares `.wellSupported` against an `.axiomatic`
    /// axiom (gravity) with a conflicting statement → `.reject`.
    /// The axiom wins; the override is denied outright.
    func testAxiomaticClaimOutranksWellSupportedOverride()
    async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let outcome = await vault.evaluateHostOverride(
            claimID: "axiom-physics-gravity",
            declaredEvidence: .wellSupported,
            statement: "I personally float.")
        if case .reject(let axiom) = outcome {
            XCTAssertEqual(axiom.id, "axiom-physics-gravity")
            XCTAssertEqual(axiom.evidence, .axiomatic)
        } else {
            XCTFail("expected .reject, got \(outcome)")
        }
    }

    /// Host declares `.wellSupported` against the `.wellSupported`
    /// sleep axiom — equal rank, not strictly greater — so the
    /// override survives demoted to `.plausible` (coexistence path).
    func testEqualEvidenceOverrideDemotesToPlausible() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let outcome = await vault.evaluateHostOverride(
            claimID: "axiom-body-sleep-required",
            declaredEvidence: .wellSupported,
            statement: "I function fine on 4 hours.")
        if case .demote(let axiom, let effective) = outcome {
            XCTAssertEqual(axiom.id, "axiom-body-sleep-required")
            XCTAssertEqual(axiom.evidence, .wellSupported)
            XCTAssertEqual(effective, .plausible)
        } else {
            XCTFail("expected .demote, got \(outcome)")
        }
    }

    // MARK: - Grow-path (register template / bridge)

    /// A host-supplied custom template registers cleanly into an
    /// existing domain and shows up in subsequent queries.
    func testRegisterCustomTemplateAppearsInDomain() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: false)
        let template = QinaoWorldPriorCausalTemplate(
            id: "tmpl-custom-routine",
            domain: .time,
            preconditions: ["daily trigger"],
            effect: "routine fires",
            effectKind: .stateTransition,
            reversibility: .trivial,
            latency: .prompt,
            evidence: .plausible)
        try await vault.registerTemplate(template)
        let fetched = await vault.template(
            id: "tmpl-custom-routine")
        XCTAssertEqual(fetched, template)
        let timeTemplates = await vault.templates(in: .time)
        XCTAssertTrue(timeTemplates.contains(template))
    }

    /// Registering a template with a duplicate ID surfaces as a
    /// typed Qinao `VaultError` (translated from BAS).
    func testDuplicateTemplateIDThrowsTypedError() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let clashing = QinaoWorldPriorCausalTemplate(
            id: "tmpl-body-sleep-debt",  // already in built-ins
            domain: .body,
            preconditions: [],
            effect: "e",
            effectKind: .stateTransition,
            reversibility: .trivial,
            latency: .prompt,
            evidence: .speculative)
        do {
            try await vault.registerTemplate(clashing)
            XCTFail("expected duplicateTemplateID")
        } catch QinaoWorldPriorVault.VaultError
            .duplicateTemplateID(let id) {
            XCTAssertEqual(id, "tmpl-body-sleep-debt")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// Registering a bridge that references a template ID the
    /// vault does not know throws the referential-integrity error.
    func testBridgeReferencingUnknownTemplateFailsRefIntegrity()
    async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let dangling = QinaoWorldPriorDomainBridge(
            id: "br-custom-unknown",
            sourceDomain: .body,
            targetDomain: .time,
            analogy: "arbitrary",
            templatePairings: [
                .init(
                    sourceTemplateID: "tmpl-does-not-exist",
                    targetTemplateID: "tmpl-time-deadline-pressure"
                )
            ],
            evidence: .plausible)
        do {
            try await vault.registerBridge(dangling)
            XCTFail("expected bridgeReferencesUnknownTemplate")
        } catch QinaoWorldPriorVault.VaultError
            .bridgeReferencesUnknownTemplate(
                let bridgeID, let templateID) {
            XCTAssertEqual(bridgeID, "br-custom-unknown")
            XCTAssertEqual(templateID, "tmpl-does-not-exist")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Evidence-level semantics

    /// `QinaoWorldPriorEvidenceLevel` is `Comparable`; the ordering
    /// matches the substrate's ladder. This test pins the full
    /// order so no refactor can quietly flip a rung.
    func testEvidenceLadderOrderingIsStable() {
        XCTAssertGreaterThan(
            QinaoWorldPriorEvidenceLevel.axiomatic,
            QinaoWorldPriorEvidenceLevel.wellSupported)
        XCTAssertGreaterThan(
            QinaoWorldPriorEvidenceLevel.wellSupported,
            QinaoWorldPriorEvidenceLevel.plausible)
        XCTAssertGreaterThan(
            QinaoWorldPriorEvidenceLevel.plausible,
            QinaoWorldPriorEvidenceLevel.speculative)
        XCTAssertGreaterThan(
            QinaoWorldPriorEvidenceLevel.speculative,
            QinaoWorldPriorEvidenceLevel.contested)
    }
}
