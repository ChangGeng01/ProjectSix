import XCTest
@testable import QinaoLoop
import QinaoWorldPrior

/// M288 — wire `expandWithCounterfactual` into the production
/// generation path via `generateCandidatesWithCounterfactualBranches`.
///
/// Doctrine pinned by these tests:
/// - Loop without a vault → `worldPriorUnavailable("no-world-prior-vault")`
/// - Unknown template ID → `worldPriorUnavailable("unknown-template:<id>")`
/// - `tmpl-body-hydration` (3 branches in the seeded built-in vault)
///   → endpoint receives 4 calls, 4 GeneratedCandidate returned,
///     parent first, variants in branch order
/// - Variant prompts contain the perturbation directive (matches
///   M287 prompt grammar)
/// - Parent's candidateID survives as the first GeneratedCandidate
final class QinaoLoopCounterfactualGenerationTests: XCTestCase {

    // MARK: - Spy endpoint (mirrors QinaoLoopGenerationTests pattern)

    actor SpyEndpoint: QinaoOrganEndpoint {
        struct Call: Sendable, Equatable {
            let prompt: String
            let role: QinaoLoop.OrganRole
            let sessionID: String
        }
        private(set) var calls: [Call] = []
        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            let call = Call(
                prompt: prompt,
                role: role,
                sessionID: sessionID)
            calls.append(call)
            return QinaoLoop.OrganResponse(
                body: "body-\(calls.count)",
                providerID: "spy.cf",
                traceID: "trace-\(calls.count)")
        }
        func observedCalls() -> [Call] { calls }
    }

    // MARK: - Fixtures

    private func makeSeededVault()
        async throws -> QinaoWorldPriorVault {
        try await QinaoWorldPriorVault(seedingBuiltIns: true)
    }

    private func makeParentSeed() -> QinaoLoop.CandidateSeed {
        QinaoLoop.CandidateSeed(
            candidateID: "plan-A",
            title: "Original plan",
            prompt: "Decide whether to act now.",
            context: ["recent state is tense"],
            role: .core,
            expectedBenefit: 0.6,
            expectedCost: 0.4,
            reversibility: 0.7,
            confidence: 0.8,
            evidenceGap: 0.2,
            manipulationRisk: 0.1,
            emotionalBias: 0.5,
            boundaryConflict: 0.2,
            worldPriorClaim: nil)
    }

    // MARK: - Error path: no vault wired

    func test_loopWithoutVault_throwsNoWorldPriorVault() async throws {
        let spy = SpyEndpoint()
        let loop = QinaoLoop(organEndpoint: spy)
        do {
            _ = try await loop
                .generateCandidatesWithCounterfactualBranches(
                    sessionID: "s1",
                    seed: makeParentSeed(),
                    templateID: "tmpl-body-hydration")
            XCTFail("expected .worldPriorUnavailable")
        } catch QinaoLoop.LoopError
            .worldPriorUnavailable(let reason) {
            XCTAssertEqual(reason, "no-world-prior-vault")
        }
    }

    // MARK: - Error path: unknown template

    func test_unknownTemplate_throwsUnknownTemplate() async throws {
        let vault = try await makeSeededVault()
        let spy = SpyEndpoint()
        let loop = QinaoLoop(
            organEndpoint: spy, worldPrior: vault)
        do {
            _ = try await loop
                .generateCandidatesWithCounterfactualBranches(
                    sessionID: "s1",
                    seed: makeParentSeed(),
                    templateID: "tmpl-does-not-exist")
            XCTFail("expected .worldPriorUnavailable")
        } catch QinaoLoop.LoopError
            .worldPriorUnavailable(let reason) {
            XCTAssertEqual(
                reason, "unknown-template:tmpl-does-not-exist")
        }
    }

    // MARK: - Happy path: tmpl-body-hydration (3 branches)

    func test_seededTemplate_returnsParentPlusVariants() async throws
    {
        let vault = try await makeSeededVault()
        let spy = SpyEndpoint()
        let loop = QinaoLoop(
            organEndpoint: spy, worldPrior: vault)

        let generated = try await loop
            .generateCandidatesWithCounterfactualBranches(
                sessionID: "sess-cf",
                seed: makeParentSeed(),
                templateID: "tmpl-body-hydration")

        // tmpl-body-hydration ships 3 branches per M84 fixture doc.
        // Expansion adds 1 parent → 4 total.
        XCTAssertEqual(generated.count, 4)

        // Parent's candidateID is first.
        XCTAssertEqual(generated[0].candidateID, "plan-A")

        // Variants carry the #cf-<kind> suffix grammar.
        for variant in generated.dropFirst() {
            XCTAssertTrue(
                variant.candidateID.hasPrefix("plan-A#cf-"),
                "variant \(variant.candidateID) must carry #cf- prefix")
        }
    }

    func test_endpointReceivesOneCallPerExpansionInOrder()
        async throws
    {
        let vault = try await makeSeededVault()
        let spy = SpyEndpoint()
        let loop = QinaoLoop(
            organEndpoint: spy, worldPrior: vault)
        _ = try await loop
            .generateCandidatesWithCounterfactualBranches(
                sessionID: "sess-cf",
                seed: makeParentSeed(),
                templateID: "tmpl-body-hydration")
        let calls = await spy.observedCalls()

        // 1 parent + 3 branches = 4 endpoint calls.
        XCTAssertEqual(calls.count, 4)

        // First call is the parent prompt verbatim.
        XCTAssertEqual(
            calls[0].prompt, "Decide whether to act now.")

        // Variant calls 1..3 must each contain the perturbation
        // directive prefix per M287 prompt grammar.
        for i in 1..<calls.count {
            XCTAssertTrue(
                calls[i].prompt.contains(
                    "Counterfactual perspective ("),
                "call \(i) prompt missing perturbation prefix: \(calls[i].prompt)")
            // Parent prompt suffix preserved.
            XCTAssertTrue(
                calls[i].prompt.hasSuffix(
                    "Decide whether to act now."))
        }
    }

    func test_sessionIDForwardedToEveryCall() async throws {
        let vault = try await makeSeededVault()
        let spy = SpyEndpoint()
        let loop = QinaoLoop(
            organEndpoint: spy, worldPrior: vault)
        _ = try await loop
            .generateCandidatesWithCounterfactualBranches(
                sessionID: "sess-id-pin",
                seed: makeParentSeed(),
                templateID: "tmpl-body-hydration")
        let calls = await spy.observedCalls()
        for call in calls {
            XCTAssertEqual(call.sessionID, "sess-id-pin")
        }
    }
}
