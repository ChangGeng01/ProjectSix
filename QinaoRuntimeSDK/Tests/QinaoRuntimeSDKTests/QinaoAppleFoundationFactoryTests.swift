import XCTest
import QinaoLoop
import QinaoAppleFoundation

/// M180 — coverage for the public
/// `QinaoLoop.makeAppleFoundationEndpoint(...)` factory.
///
/// ## What this proves
///
/// Where M178 (`QinaoAppleFoundationE2ETests`) demonstrates the
/// MANUAL host-pattern (writing your own `QinaoOrganEndpoint`
/// conformance), this suite proves the FACTORY path produces an
/// equivalent endpoint a host can adopt with a single call.
///
/// Two variants:
///
/// 1. `includeDeterministicFallback: false` (default) — Apple FM
///    is the only registered adapter. On supported OS, real model
///    invocation. On unsupported OS, the endpoint surfaces
///    `LoopError.organUnavailable`.
/// 2. `includeDeterministicFallback: true` — `BASOrganDeterministicAdapter`
///    is registered first, then Apple FM. Registry's "most-recent
///    on-device wins" rule still picks Apple FM when reachable;
///    when not, falls through to the deterministic stub.
///
/// ## Real-LLM tests are env-gated
///
/// The test that exercises real Apple FM (`testFactoryWithoutFallbackHitsRealAppleFM`)
/// uses the same `QINAO_FM_E2E=1` gate as M177/M178. Default
/// `swift test` runs only the deterministic-fallback path, which
/// is offline + fast.
final class QinaoAppleFoundationFactoryTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessRealLLMReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise real Apple " +
                "FoundationModels via the public factory")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+; current OS does not satisfy the guard")
    }

    // MARK: - Factory wiring (offline, runs every test pass)

    /// The factory constructs an endpoint without throwing on any
    /// supported platform — registry creation + adapter registration
    /// are pure local work, no network or model load.
    func testFactoryConstructsEndpointSynchronously() async {
        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        // Type erased to `any QinaoOrganEndpoint`; no further
        // assertion is meaningful without invoking the model.
        // The fact that the call returns is the assertion.
        _ = endpoint
    }

    /// `includeDeterministicFallback: true` MUST produce an endpoint
    /// that can drive `generateCandidates` end-to-end on ANY OS — the
    /// deterministic adapter is on-device + always available.
    /// Apple FM is also registered (later, so the registry would
    /// pick it when reachable), but on macOS 14 / older OS the
    /// deterministic adapter wins and the test runs offline.
    func testFactoryWithFallbackProducesUsableEndpointOffline()
        async throws
    {
        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint(
                includeDeterministicFallback: true)
        let loop = QinaoLoop(organEndpoint: endpoint)

        let seed = QinaoLoop.CandidateSeed(
            candidateID: "c1",
            title: "Fallback test",
            prompt: "ping",
            role: .scout,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.8)

        let result = try await loop.generateCandidates(
            sessionID: "factory-fallback-1",
            seeds: [seed])

        XCTAssertEqual(result.count, 1)
        let candidate = result[0]
        XCTAssertFalse(
            candidate.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            "fallback endpoint must produce a non-empty body " +
            "from either Apple FM (when reachable) or the " +
            "deterministic stub")
        // ProviderID identifies which adapter actually ran. On
        // macOS 26+ with Apple Intelligence on, Apple FM wins; on
        // macOS 14 or with AI off, deterministic wins. Both are
        // valid factory outcomes — the test asserts ONE of them.
        XCTAssertTrue(
            candidate.providerID == "apple.foundation-models.v1"
                || candidate.providerID == "bas.deterministic.v1",
            "providerID must be a known registered adapter; got " +
            "\(candidate.providerID)")
    }

    // MARK: - Real Apple FM through the factory (env-gated)

    /// `includeDeterministicFallback: false` — Apple FM is the only
    /// registered adapter. On a capable dev box with the env var
    /// set, this MUST hit the real model.
    func testFactoryWithoutFallbackHitsRealAppleFM()
        async throws
    {
        try skipUnlessRealLLMReady()

        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)

        let seed = QinaoLoop.CandidateSeed(
            candidateID: "c1",
            title: "Factory real LLM",
            prompt: "Reply with one short word.",
            role: .scout,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.8)

        let result = try await loop.generateCandidates(
            sessionID: "factory-real-1",
            seeds: [seed])

        XCTAssertEqual(result.count, 1)
        let candidate = result[0]
        XCTAssertEqual(
            candidate.providerID,
            "apple.foundation-models.v1",
            "with no fallback registered, the factory MUST route " +
            "to Apple FM when reachable")
        XCTAssertFalse(
            candidate.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty)
    }

    /// With `includeDeterministicFallback: true` AND a reachable
    /// Apple FM, the registry's "most-recent on-device wins" rule
    /// must still pick Apple FM (it's registered second).
    func testFactoryWithFallbackPrefersRealAppleFM() async throws {
        try skipUnlessRealLLMReady()

        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint(
                includeDeterministicFallback: true)
        let loop = QinaoLoop(organEndpoint: endpoint)

        let seed = QinaoLoop.CandidateSeed(
            candidateID: "c1",
            title: "Factory both",
            prompt: "Reply with one word.",
            role: .scout,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.8)

        let result = try await loop.generateCandidates(
            sessionID: "factory-both-real-1",
            seeds: [seed])

        XCTAssertEqual(
            result.first?.providerID,
            "apple.foundation-models.v1",
            "with both adapters registered AND Apple FM reachable, " +
            "registry must prefer Apple FM (registered later, " +
            "wins by most-recent on-device rule)")
    }
}
