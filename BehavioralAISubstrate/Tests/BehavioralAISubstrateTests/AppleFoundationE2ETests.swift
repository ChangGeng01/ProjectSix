import XCTest
@testable import BASRuntimeCore
@testable import BASOrgan
@testable import BASAppleAdapters

/// M177 — real-path E2E coverage for `AppleFoundationOrganAdapter`.
///
/// ## Why this is a separate suite
///
/// `AppleFoundationOrganAdapterTests` covers descriptor + role + the
/// stub-fallthrough path that runs even when `FoundationModels` is
/// not importable / OS guard fails. It pins the contract.
///
/// THIS suite proves the adapter can actually drive a real on-device
/// `LanguageModelSession` end-to-end through the `BASOrganAdapter`
/// contract — body comes back non-empty, provider ID matches, the
/// `BASOrganDraft` shape is populated correctly. Without this suite
/// the substrate's "default neural provider = Apple FoundationModels"
/// (plan §9.6 / §9.10 Q1) would be a wiring claim with no executed
/// proof.
///
/// ## Why it's env-gated
///
/// 1. Real `LanguageModelSession.respond(to:)` adds 0.5–3s per call;
///    `swift test` should stay fast by default.
/// 2. Apple Intelligence may be disabled in System Settings on the
///    box running tests — the assertion would flake.
/// 3. `FoundationModels` is only available on iOS 26+ / macOS 26+;
///    older OS test boxes never enter the real path.
///
/// To run on a macOS 26+ dev box with Apple Intelligence enabled:
/// ```
/// BAS_FM_E2E=1 swift test --filter AppleFoundationE2ETests
/// ```
final class AppleFoundationE2ETests: XCTestCase {

    private static let envFlag = "BAS_FM_E2E"

    /// Skip unless we're on a `FoundationModels`-capable OS AND the
    /// human running the suite has opted in via `BAS_FM_E2E=1`. Both
    /// conditions are required.
    private func skipUnlessReady() throws {
        guard ProcessInfo.processInfo.environment[Self.envFlag] == "1" else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise real Apple " +
                "FoundationModels invocation")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+; current OS does not satisfy the guard")
    }

    // MARK: - Real LanguageModelSession invocation

    func testRealScoutDraftReturnsNonEmptyBody() async throws {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()
        let request = BASOrganRequest(
            requestID: "e2e-scout-1",
            role: .scout,
            preset: .scout,
            instruction: "Reply with a single short sentence.")

        let draft = try await adapter.draft(request)

        XCTAssertEqual(
            draft.providerID,
            "apple.foundation-models.v1")
        XCTAssertEqual(draft.role, .scout)
        XCTAssertEqual(draft.requestID, "e2e-scout-1")
        XCTAssertFalse(
            draft.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            "scout draft body must be non-empty real LLM output")
        XCTAssertGreaterThan(
            draft.outputTokensEstimated, 0,
            "estimated output tokens must reflect non-empty body")
        XCTAssertFalse(
            draft.traceID.isEmpty,
            "trace ID must be populated so audit can correlate")
    }

    func testRealCoreDraftReturnsNonEmptyBody() async throws {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()
        let request = BASOrganRequest(
            requestID: "e2e-core-1",
            role: .core,
            preset: .core,
            instruction:
                "In one or two sentences, name a benefit of running an " +
                "LLM on-device versus calling a remote API.")

        let draft = try await adapter.draft(request)

        XCTAssertEqual(
            draft.providerID,
            "apple.foundation-models.v1")
        XCTAssertEqual(draft.role, .core)
        XCTAssertFalse(
            draft.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            "core draft body must be non-empty real LLM output")
        XCTAssertGreaterThan(draft.outputTokensEstimated, 0)
    }

    // MARK: - Capacity reflects real availability

    func testRealCapacityIsUnlimitedWhenAvailable() async throws {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()
        let cap = await adapter.currentCapacity()

        XCTAssertFalse(
            cap.underPressure,
            "capacity must NOT report underPressure when " +
            "FoundationModels is available")
        XCTAssertEqual(
            cap.availableInputTokens, .max,
            ".unlimited capacity reports Int.max input tokens")
        XCTAssertEqual(
            cap.availableOutputTokens, .max,
            ".unlimited capacity reports Int.max output tokens")
    }

    // MARK: - End-to-end through BASOrganRegistry

    /// Proves the full lookup chain — `BASOrganRegistry` resolves to
    /// `AppleFoundationOrganAdapter` (the only registered on-device
    /// adapter) and the resolved adapter produces a real LLM draft.
    /// This is the path `QinaoLoop`'s built-in
    /// `BASOrganRegistryEndpoint` walks per-turn.
    func testRealDraftThroughRegistry() async throws {
        try skipUnlessReady()

        let registry = BASOrganRegistry()
        await registry.register(AppleFoundationOrganAdapter())

        let adapter = try await registry.adapter(for: .scout)
        XCTAssertEqual(
            adapter.descriptor.providerID,
            "apple.foundation-models.v1",
            "registry must resolve to Apple FM (the registered " +
            "on-device adapter)")

        let draft = try await adapter.draft(BASOrganRequest(
            requestID: "e2e-registry-1",
            role: .scout,
            preset: .scout,
            instruction: "Reply with one short word."))

        XCTAssertEqual(draft.providerID, "apple.foundation-models.v1")
        XCTAssertFalse(
            draft.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty)
    }

    /// Proves the registry's "prefer most-recent on-device" rule
    /// keeps Apple FM selected even when a deterministic adapter is
    /// also present (deterministic registers first → Apple FM second
    /// → Apple FM wins). If a future change breaks this preference,
    /// hosts that have both adapters wired would silently route
    /// every turn through the deterministic stub instead of the real
    /// model.
    func testRegistryPrefersAppleFMOverDeterministicWhenBothPresent()
        async throws
    {
        try skipUnlessReady()

        let registry = BASOrganRegistry()
        // Register deterministic FIRST.
        await registry.register(BASOrganDeterministicAdapter())
        // Apple FM SECOND — should win on most-recent ordering.
        await registry.register(AppleFoundationOrganAdapter())

        let adapter = try await registry.adapter(for: .scout)
        XCTAssertEqual(
            adapter.descriptor.providerID,
            "apple.foundation-models.v1",
            "Apple FM (registered last) must be preferred over " +
            "deterministic (registered first) per registry's " +
            "most-recent-on-device rule")
    }
}
