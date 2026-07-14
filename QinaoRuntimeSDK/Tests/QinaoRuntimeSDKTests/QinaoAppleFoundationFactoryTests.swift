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
    ///
    /// Chapter 九十一.5 honesty correction: the test previously
    /// failed when Apple Intelligence was in a degraded state
    /// (`ModelManagerError Code=1026` — system reports AFM as
    /// available but use-time fails). Pre-correction the test
    /// blamed the substrate; the actual failure mode is "AFM
    /// partially-available" which the factory can't detect at
    /// registration time. The test now catches AFM execution
    /// errors specifically (substring match on `ModelManagerError
    /// Code=1026` / `GenerationError`) and treats them as a skip
    /// with a clear reason. Real substrate breakage (deterministic
    /// adapter throws / no candidate produced / wrong providerID)
    /// still fails the test.
    /// `includeDeterministicFallback: true` is a NO-OP — pinned from whichever
    /// side this host can observe. Runs on EVERY pass; never skips.
    ///
    /// Rewritten 2026-07-14 (skip triage). The previous test
    /// (`testFactoryWithFallbackProducesUsableEndpointOffline`) asserted the
    /// factory "produces a usable endpoint on ANY OS" and then SKIPPED when it
    /// didn't — firing on exactly the condition it existed to disprove, with
    /// skip text ("The factory + registry are correct; only the platform AFM
    /// daemon is unreachable") that is false. It also carried an inline
    /// hand-copy of AFMTestSupport's two-arm matcher, invisible to a
    /// `grep skipIfAFMDegraded` sweep, and weakened its own assertion with
    /// `providerID == apple || providerID == deterministic` — which passes
    /// whatever happens. It was green only because Apple Intelligence is healthy
    /// here.
    ///
    /// Verified 2026-07-14, the deterministic adapter is UNREACHABLE:
    ///   - BASOrganRegistry.adapter(for:) (BASOrganRegistry.swift:67-87) is
    ///     selection-only — most-recently-registered on-device adapter wins, no
    ///     retry, `currentCapacity()` never called;
    ///   - the factory registers deterministic FIRST, Apple LAST;
    ///   - Apple's descriptor hardcodes runsOnDevice:true unconditionally.
    /// So Apple always wins selection, and an unreachable Apple FM THROWS rather
    /// than degrading.
    ///
    /// Both outcomes prove the same fact, so this asserts it without gating:
    ///   - AFM reachable  -> providerID is Apple's (deterministic lost despite
    ///     being registered);
    ///   - AFM unreachable -> the call THROWS (no deterministic body appears).
    /// If a real router ever lands, this REDs — forcing the file-level doc on
    /// QinaoAppleFoundationEndpoint.swift to be corrected at the same time.
    func testDeterministicFallbackIsNeverSelected() async throws {
        let endpoint = await QinaoLoop.makeAppleFoundationEndpoint(
            includeDeterministicFallback: true)
        let loop = QinaoLoop(organEndpoint: endpoint)
        let seed = QinaoLoop.CandidateSeed(
            candidateID: "factory-fallback-c1",
            title: "Fallback probe",
            prompt: "ping",
            role: .scout,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.8)

        var producedProviderID: String?
        do {
            let result = try await loop.generateCandidates(
                sessionID: "factory-fallback-1", seeds: [seed])
            producedProviderID = result.first?.providerID
            XCTAssertEqual(result.count, 1)
        } catch {
            // Threw instead of degrading — the deterministic stub did not run.
            // The error TYPE is deliberately not pinned here: a raw
            // FoundationModels error can still escape the BASOrganAdapter
            // contract (AppleFoundationOrganAdapter.draftViaFoundation wraps
            // neither `session.respond` call), so pinning a typed error would
            // encode that separate defect as if it were the contract.
            producedProviderID = nil
        }

        XCTAssertNotEqual(
            producedProviderID, "bas.deterministic.v1",
            "includeDeterministicFallback:true must remain a NO-OP: the registry "
            + "is selection-only and always resolves to the Apple organ. A "
            + "deterministic providerID here means a REAL fallback now exists — "
            + "which is good, but the file-level doc on "
            + "QinaoAppleFoundationEndpoint.swift documents it as a no-op and "
            + "must be corrected in the same change.")
        if let id = producedProviderID {
            XCTAssertEqual(
                id, "apple.foundation-models.v1",
                "when generation succeeds, the Apple organ must be what ran — it "
                + "is registered last and the registry prefers most-recent "
                + "on-device")
        }
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

        // M400.3 — Code 1026 → XCTSkip
        let result: [QinaoLoop.GeneratedCandidate]
        do {
            result = try await loop.generateCandidates(
                sessionID: "factory-real-1",
                seeds: [seed])
        } catch {
            try skipIfAFMDegraded(error)
            throw error
        }

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

        // M400.3 — Code 1026 → XCTSkip
        let result: [QinaoLoop.GeneratedCandidate]
        do {
            result = try await loop.generateCandidates(
                sessionID: "factory-both-real-1",
                seeds: [seed])
        } catch {
            try skipIfAFMDegraded(error)
            throw error
        }

        XCTAssertEqual(
            result.first?.providerID,
            "apple.foundation-models.v1",
            "with both adapters registered AND Apple FM reachable, " +
            "registry must prefer Apple FM (registered later, " +
            "wins by most-recent on-device rule)")
    }
}
