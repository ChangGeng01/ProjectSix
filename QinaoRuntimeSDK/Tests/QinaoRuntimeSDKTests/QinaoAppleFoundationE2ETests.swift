import XCTest
import BASRuntimeCore
import BASOrgan
import BASAppleAdapters
import QinaoLoop

/// M178 — real-path E2E proof at the Qinao SDK boundary.
///
/// ## Why this exists
///
/// M177 proved Apple FoundationModels runs through the substrate's
/// `BASOrganAdapter` contract. This suite proves the same model is
/// actually reachable from the *Qinao public surface* a host writes
/// against — `QinaoLoop.generateCandidates(sessionID:seeds:)` driving
/// real on-device inference and folding the resulting drafts into
/// the deterministic scoring + frontier pipeline.
///
/// ## Pattern this test demonstrates for hosts
///
/// `BASOrganRegistryEndpoint` (inside QinaoLoop) is `internal` so
/// substrate names don't leak via the public API. Hosts that want to
/// drive `QinaoLoop` with a substrate adapter today copy
/// `AppleFoundationTestEndpoint` below — a ~25-line `QinaoOrganEndpoint`
/// conformance that wraps a `BASOrganRegistry`. Once a public
/// `QinaoLoop.makeAppleFoundationEndpoint()` factory ships (future
/// milestone), hosts can drop the wrapper.
///
/// ## Gating
///
/// Same gates as `AppleFoundationE2ETests` in BAS:
/// - `BAS_FM_E2E=1` env var (opt-in)
/// - macOS 26+ / iOS 26+ / visionOS 26+ availability
///
/// ```
/// BAS_FM_E2E=1 swift test --filter QinaoAppleFoundationE2ETests
/// ```

/// Test-fixture endpoint. Wraps a `BASOrganRegistry` and translates
/// the `QinaoLoop.OrganRole` ↔ `BASOrganRole` enum so the public
/// loop API can drive substrate adapters end-to-end.
private struct AppleFoundationTestEndpoint: QinaoOrganEndpoint {
    let registry: BASOrganRegistry

    func produceBody(
        prompt: String,
        context: [String],
        role: QinaoLoop.OrganRole,
        sessionID: String
    ) async throws -> QinaoLoop.OrganResponse {
        let internalRole: BASOrganRole =
            role == .scout ? .scout : .core
        let preset: BASOrganPreset =
            internalRole == .scout ? .scout : .core

        let adapter = try await registry.adapter(for: internalRole)
        let request = BASOrganRequest(
            requestID: UUID().uuidString,
            role: internalRole,
            preset: preset,
            instruction: prompt,
            context: context)
        let draft = try await adapter.draft(request)

        return QinaoLoop.OrganResponse(
            body: draft.body,
            providerID: draft.providerID,
            traceID: draft.traceID)
    }
}

final class QinaoAppleFoundationE2ETests: XCTestCase {

    private static let envFlag = "BAS_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise QinaoLoop driving " +
                "real Apple FoundationModels")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+; current OS does not satisfy the guard")
    }

    private func makeEndpoint() async -> AppleFoundationTestEndpoint {
        let registry = BASOrganRegistry()
        await registry.register(AppleFoundationOrganAdapter())
        return AppleFoundationTestEndpoint(registry: registry)
    }

    // MARK: - Single-seed E2E

    func testGenerateSingleCandidateRoutesToAppleFoundationModels()
        async throws
    {
        try skipUnlessReady()

        let endpoint = await makeEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)

        let seed = QinaoLoop.CandidateSeed(
            candidateID: "c1",
            title: "Mindful break",
            prompt:
                "Suggest one short mindful break activity in " +
                "under 12 words.",
            role: .core,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.8)

        let result = try await loop.generateCandidates(
            sessionID: "qinao-e2e-single",
            seeds: [seed])

        XCTAssertEqual(result.count, 1)
        let candidate = result[0]
        XCTAssertEqual(candidate.candidateID, "c1")
        XCTAssertEqual(
            candidate.providerID,
            "apple.foundation-models.v1",
            "QinaoLoop must surface Apple FM's providerID through " +
            "the GeneratedCandidate so hosts can audit which model " +
            "produced which body")
        XCTAssertFalse(
            candidate.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            "real Apple LLM body must be non-empty")
        XCTAssertFalse(
            candidate.traceID.isEmpty,
            "trace ID must be threaded through for provenance")
    }

    // MARK: - Multiple-seed E2E

    /// Two seeds in one batch, each routed to the same registry. All
    /// generated candidates must report Apple FM's providerID — proves
    /// the per-seed loop in `generateCandidates` walks the registry
    /// every iteration (no caching that could pin to a stale adapter
    /// resolved once).
    func testGenerateMultipleSeedsAllRouteToAppleFoundationModels()
        async throws
    {
        try skipUnlessReady()

        let endpoint = await makeEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)

        let seeds = [
            QinaoLoop.CandidateSeed(
                candidateID: "c-scout",
                title: "Quick reply",
                prompt: "Reply with one short word.",
                role: .scout,
                expectedBenefit: 0.6,
                expectedCost: 0.1,
                reversibility: 0.95,
                confidence: 0.9),
            QinaoLoop.CandidateSeed(
                candidateID: "c-core",
                title: "Stretch suggestion",
                prompt:
                    "Name one beneficial stretch in under 8 words.",
                role: .core,
                expectedBenefit: 0.7,
                expectedCost: 0.2,
                reversibility: 0.95,
                confidence: 0.85),
        ]

        let result = try await loop.generateCandidates(
            sessionID: "qinao-e2e-multi",
            seeds: seeds)

        XCTAssertEqual(result.count, 2)
        let providerIDs = Set(result.map(\.providerID))
        XCTAssertEqual(
            providerIDs,
            ["apple.foundation-models.v1"],
            "every generated candidate must come from Apple FM")
        for candidate in result {
            XCTAssertFalse(
                candidate.body
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty,
                "each real Apple LLM body must be non-empty " +
                "(candidate \(candidate.candidateID))")
        }
    }

    // MARK: - Frontier scoring still deterministic on real bodies

    /// Even with a real LLM producing variable bodies, the
    /// deterministic scoring formula still ranks candidates from
    /// host-supplied numerics. Two seeds with different
    /// `expectedBenefit / expectedCost` numerics must produce a
    /// stable frontier order regardless of what Apple FM said.
    func testFrontierOrderingIsDeterministicAcrossRealLLMBodies()
        async throws
    {
        try skipUnlessReady()

        let endpoint = await makeEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)

        let strong = QinaoLoop.CandidateSeed(
            candidateID: "strong",
            title: "Strong candidate",
            prompt: "Reply with one word.",
            role: .scout,
            expectedBenefit: 0.9,
            expectedCost: 0.1,
            reversibility: 0.95,
            confidence: 0.95)
        let weak = QinaoLoop.CandidateSeed(
            candidateID: "weak",
            title: "Weak candidate",
            prompt: "Reply with one word.",
            role: .scout,
            expectedBenefit: 0.2,
            expectedCost: 0.7,
            reversibility: 0.3,
            confidence: 0.3)

        let result = try await loop.generateCandidates(
            sessionID: "qinao-e2e-frontier",
            seeds: [strong, weak])

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(
            result[0].candidateID, "strong",
            "scoring formula 0.40·B − 0.30·C + 0.15·R + 0.15·Conf " +
            "must rank `strong` over `weak` regardless of Apple " +
            "FM body content")
        XCTAssertGreaterThan(
            result[0].score, result[1].score,
            "frontier score must reflect numeric superiority")
    }
}
