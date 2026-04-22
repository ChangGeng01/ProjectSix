import XCTest
@testable import QinaoRisk
@testable import QinaoRuntime
@testable import QinaoWorldPrior

/// M79 — Shared-vault bundle tests.
///
/// Before M79, the L9 dream loop and the L11 risk gate each consumed
/// L4 world-prior knowledge from a different source: `QinaoLoop` took
/// a `QinaoWorldPriorVault` (Qinao-public actor), while `QinaoRiskGate`
/// went through a substrate-backed endpoint. A host that registered a
/// custom causal template on the Qinao-public vault would see the new
/// template show up in loop-side claim evaluation — but NOT in the
/// risk gate, because the gate was looking at a different vault.
///
/// M79 unifies the two sides: the new `QinaoWorldPriorVaultAdapter`
/// bridges a Qinao-public vault into the `QinaoWorldPriorEndpoint`
/// protocol, so a single authoritative vault can drive both L9 and
/// L11. `QinaoRuntime.sharedWorldPriorBundle()` is the one-call
/// bootstrap that returns `(vault, endpoint)` pre-wired together.
///
/// These tests prove the seam end-to-end:
///
/// 1. Unknown template → endpoint returns nil (absence signal), no
///    throw — matches `QinaoWorldPriorEndpoint` contract.
/// 2. Seeded ethics-irreversible template surfaces an assessment with
///    the documented score (1.0, clamped) + `requiresConsent = true`
///    + `evidenceSufficient = true` (axiomatic ≥ wellSupported).
/// 3. Bridge projection collapses the 7-field Qinao assessment to the
///    4 fields the gate consumes, byte-equal to the vault's own
///    `assessRisk(templateID:)` output on those 4 fields.
/// 4. `QinaoWorldPriorRiskAssessment` JSON round-trip is byte-equal —
///    schema is stable and projection-safe.
/// 5. A host-registered custom template on the Qinao-public vault is
///    IMMEDIATELY visible through the endpoint — proves one vault
///    instance, not two out-of-sync copies.
/// 6. Score clamping: init with `-0.5` → 0; init with `1.5` → 1 (edge
///    invariant carries through the bridge identically).
/// 7. `sharedWorldPriorBundle()` returns a seeded vault + working
///    endpoint without leaking substrate types on the API.
/// 8. End-to-end shared vault: the same instance feeds loop-side
///    `evaluateHostOverride` AND gate-side `endpoint.assessRisk` for
///    the same template ID.
final class QinaoWorldPriorSharedBundleTests: XCTestCase {

    // MARK: - 1. Unknown template → nil

    func testEndpointReturnsNilForUnknownTemplate() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let endpoint = QinaoRuntime.worldPriorEndpoint(for: vault)
        let result = try await endpoint.assessRisk(
            templateID: "tmpl-definitely-not-registered-\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    // MARK: - 2. Seeded ethics-irreversible produces canonical score

    func testSeededEthicsConsentViolationHasCanonicalAssessment() async throws {
        let (vault, endpoint) = try await QinaoRuntime
            .sharedWorldPriorBundle()

        // Direct Qinao vault read.
        let qinao = await vault.assessRisk(
            templateID: "tmpl-ethics-consent-violation")
        guard let qinao = qinao else {
            XCTFail("seeded vault missing tmpl-ethics-consent-violation")
            return
        }
        XCTAssertEqual(qinao.domain, .ethics)
        XCTAssertEqual(qinao.reversibility, .irreversible)
        XCTAssertEqual(qinao.evidenceLevel, .axiomatic)
        XCTAssertTrue(qinao.requiresConsent)
        XCTAssertTrue(qinao.evidenceSufficient)
        // Score = 1.0 (irreversible) × 1.0 (relationshipChange) × 1.1
        // (ethics upgrade) = 1.1 → clamped to 1.0.
        XCTAssertEqual(qinao.irreversibleHarmScore, 1.0, accuracy: 1e-9)

        // Bridge endpoint read — same template, same fields.
        let gate = try await endpoint.assessRisk(
            templateID: "tmpl-ethics-consent-violation")
        XCTAssertNotNil(gate)
        XCTAssertEqual(
            gate?.irreversibleHarmScore, qinao.irreversibleHarmScore)
        XCTAssertEqual(gate?.requiresConsent, qinao.requiresConsent)
        XCTAssertEqual(
            gate?.evidenceSufficient, qinao.evidenceSufficient)
        XCTAssertEqual(
            gate?.matchedTemplateID, qinao.matchedTemplateID)
    }

    // MARK: - 3. Bridge projection = 4-field subset

    func testBridgeProjectionIsFourFieldSubset() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: true)
        let endpoint = QinaoRuntime.worldPriorEndpoint(for: vault)

        let templateID = "tmpl-money-irreversible-transfer"
        let qinao = await vault.assessRisk(templateID: templateID)
        let gate = try await endpoint.assessRisk(templateID: templateID)

        guard let qinao = qinao, let gate = gate else {
            XCTFail("seeded vault missing \(templateID)")
            return
        }

        // Construct the expected 4-field projection manually.
        let expected = QinaoRiskGate.WorldRiskAssessment(
            irreversibleHarmScore: qinao.irreversibleHarmScore,
            requiresConsent: qinao.requiresConsent,
            evidenceSufficient: qinao.evidenceSufficient,
            matchedTemplateID: qinao.matchedTemplateID)
        XCTAssertEqual(gate, expected)
    }

    // MARK: - 4. Codable round-trip byte-equality

    func testQinaoWorldPriorRiskAssessmentCodableRoundTrip() throws {
        let original = QinaoWorldPriorRiskAssessment(
            matchedTemplateID: "tmpl-example",
            domain: .ethics,
            reversibility: .irreversible,
            evidenceLevel: .axiomatic,
            requiresConsent: true,
            irreversibleHarmScore: 0.85,
            evidenceSufficient: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let first = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            QinaoWorldPriorRiskAssessment.self, from: first)
        XCTAssertEqual(decoded, original)
        let second = try encoder.encode(decoded)
        XCTAssertEqual(first, second)
    }

    // MARK: - 5. Shared state — host-registered template is immediately
    //           visible through the endpoint

    func testHostRegisteredTemplateAppearsOnBridgeEndpoint() async throws {
        let vault = try await QinaoWorldPriorVault(
            seedingBuiltIns: false)
        let endpoint = QinaoRuntime.worldPriorEndpoint(for: vault)

        let customID = "tmpl-host-custom-bridge-\(UUID().uuidString)"
        // Before registration, the endpoint reports absence.
        let beforeRegistration = try await endpoint.assessRisk(
            templateID: customID)
        XCTAssertNil(beforeRegistration)

        let custom = QinaoWorldPriorCausalTemplate(
            id: customID,
            domain: .body,
            preconditions: ["sustained overexertion without recovery"],
            effect: "body accumulates strain debt",
            effectKind: .stateTransition,
            reversibility: .costly,
            latency: .gradual,
            evidence: .wellSupported)
        try await vault.registerTemplate(custom)

        // Immediately after registration — no separate sync, no second
        // vault — the endpoint reflects the new template.
        let afterRegistration = try await endpoint.assessRisk(
            templateID: customID)
        guard let afterRegistration = afterRegistration else {
            XCTFail("endpoint did not see host-registered template")
            return
        }
        XCTAssertEqual(afterRegistration.matchedTemplateID, customID)
        // Cross-check against the vault's own projection for the same ID.
        let direct = await vault.assessRisk(templateID: customID)
        XCTAssertEqual(
            direct?.irreversibleHarmScore,
            afterRegistration.irreversibleHarmScore)
    }

    // MARK: - 6. Clamping invariant on edge values

    func testQinaoWorldPriorRiskAssessmentScoreClampingLowBound() {
        let below = QinaoWorldPriorRiskAssessment(
            matchedTemplateID: "tmpl-low",
            domain: .time,
            reversibility: .trivial,
            evidenceLevel: .plausible,
            requiresConsent: false,
            irreversibleHarmScore: -0.5,
            evidenceSufficient: true)
        XCTAssertEqual(below.irreversibleHarmScore, 0.0)
    }

    func testQinaoWorldPriorRiskAssessmentScoreClampingHighBound() {
        let above = QinaoWorldPriorRiskAssessment(
            matchedTemplateID: "tmpl-high",
            domain: .ethics,
            reversibility: .irreversible,
            evidenceLevel: .axiomatic,
            requiresConsent: true,
            irreversibleHarmScore: 1.5,
            evidenceSufficient: true)
        XCTAssertEqual(above.irreversibleHarmScore, 1.0)
    }

    // MARK: - 7. sharedWorldPriorBundle smoke

    func testSharedBundleProducesSeededVaultAndWorkingEndpoint() async throws {
        let (vault, endpoint) = try await QinaoRuntime
            .sharedWorldPriorBundle()

        let templateCount = await vault.templateCount()
        let domainCount = await vault.domains().count
        XCTAssertGreaterThanOrEqual(templateCount, 20)
        XCTAssertEqual(domainCount, 8)

        // Endpoint answers a known built-in template without BAS leakage.
        let assessment = try await endpoint.assessRisk(
            templateID: "tmpl-ethics-consent-violation")
        XCTAssertNotNil(assessment)
        XCTAssertEqual(
            assessment?.matchedTemplateID,
            "tmpl-ethics-consent-violation")
    }

    // MARK: - 8. End-to-end shared vault feeds both L9 and L11

    func testSharedVaultFeedsBothL9OverrideAndL11RiskAssessment() async throws {
        let (vault, endpoint) = try await QinaoRuntime
            .sharedWorldPriorBundle()

        // L9 path: evaluateHostOverride reads axioms off the same vault
        // the host hands to QinaoLoop(worldPrior:). Target the seeded
        // `axiom-physics-gravity` (default evidence = .axiomatic) with
        // a conflicting statement declared at .speculative — axiomatic
        // strictly beats speculative, so the vault must surface the
        // override as `.reject(axiomID:)`. That proves the axiom path
        // is live off THIS vault instance (not some hidden second one).
        let outcome = await vault.evaluateHostOverride(
            claimID: "axiom-physics-gravity",
            declaredEvidence: .speculative,
            statement: "objects fall upward in this vault")

        switch outcome {
        case .reject(let axiom):
            XCTAssertEqual(axiom.id, "axiom-physics-gravity")
        case .clean, .demote:
            XCTFail(
                "expected .reject on axiomatic vs speculative override, "
                + "got \(outcome)")
        }

        // L11 path: the endpoint bridged off the SAME vault responds to
        // a template from the SAME library. No separate seed needed.
        guard
            let gate = try await endpoint.assessRisk(
                templateID: "tmpl-ethics-consent-violation")
        else {
            XCTFail("bridge endpoint could not see seeded template")
            return
        }
        XCTAssertTrue(gate.requiresConsent)
        XCTAssertEqual(gate.irreversibleHarmScore, 1.0, accuracy: 1e-9)
    }
}
