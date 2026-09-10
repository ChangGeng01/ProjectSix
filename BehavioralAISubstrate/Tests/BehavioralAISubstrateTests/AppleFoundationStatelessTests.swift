import XCTest
@testable import BASOrgan
@testable import BASAppleAdapters

/// M197 — empirical proof that `AppleFoundationOrganAdapter`'s
/// `draft(_:)` path is stateless across calls.
///
/// ## Why this exists
///
/// `AppleFoundationOrganAdapter.draft(_:)` constructs a new
/// `LanguageModelSession` per request, so by inspection the
/// adapter shouldn't leak state across calls. M190 hit one
/// suspicious context-window overflow ("Content contains 4090
/// tokens, which exceeds the maximum allowed context size of
/// 4096") on a test that made two sequential calls — too cheap
/// to dismiss as a flake without investigation.
///
/// M197 pins three properties empirically:
///
/// 1. **No context accumulation across calls on one adapter.**
///    10 sequential short-prompt draft calls on the same
///    `AppleFoundationOrganAdapter` actor instance all succeed
///    without context-window overflow. Token usage doesn't grow
///    monotonically.
/// 2. **No process-wide state leak across fresh adapters.**
///    10 sequential draft calls each on a freshly-constructed
///    adapter all succeed. Confirms that any process-level cache
///    Apple's framework holds doesn't bleed semantic content
///    between callers.
/// 3. **Prompt content from turn N doesn't leak into turn N+1.**
///    A unique marker word in turn 1's prompt does not appear in
///    turn 2's response when turn 2's prompt is unrelated. This
///    is the strong "stateless" property at the response level.
///
/// Gated behind `QINAO_FM_E2E=1` + macOS 26+.
final class AppleFoundationStatelessTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise Apple FM " +
                "stateless invariants")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+")
    }

    // MARK: - 1. Same adapter, 10 sequential calls

    /// 10 sequential `draft(_:)` calls on ONE adapter instance.
    /// Every call must succeed; estimated input-token counts
    /// must not grow monotonically (which would imply prompt
    /// accumulation).
    func testSameAdapterSequentialCallsDoNotAccumulateContext()
        async throws
    {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()
        let count = 10
        var inputTokens: [Int] = []

        for i in 0..<count {
            let request = BASOrganRequest(
                requestID: "stateless-same-\(i)",
                role: .scout,
                preset: .scout,
                instruction: "Reply with one short word.")
            let draft = try await adapter.draft(request)
            inputTokens.append(draft.inputTokensEstimated)
            XCTAssertFalse(
                draft.body.trimmingCharacters(
                    in: .whitespacesAndNewlines).isEmpty,
                "iteration \(i): empty body — adapter went wrong " +
                "mid-stream")
        }

        // Every iteration's input-token estimate should be the
        // same (the prompt is identical). Monotonic growth would
        // mean prompts are concatenating across calls.
        let firstTokens = inputTokens[0]
        for (i, tokens) in inputTokens.enumerated() {
            XCTAssertEqual(
                tokens, firstTokens,
                "iteration \(i): input-token estimate \(tokens) " +
                "differs from iteration 0 (\(firstTokens)). " +
                "Identical prompts must produce identical token " +
                "counts; if they don't, the adapter is " +
                "stateful")
        }
    }

    // MARK: - 2. Fresh adapter per call, 10 sequential calls

    /// Same pattern but with a fresh adapter per call. Confirms
    /// that no process-wide state accumulates between adapter
    /// constructions.
    func testFreshAdapterPerCallAllSucceed() async throws {
        try skipUnlessReady()

        for i in 0..<10 {
            let adapter = AppleFoundationOrganAdapter()
            let request = BASOrganRequest(
                requestID: "stateless-fresh-\(i)",
                role: .scout,
                preset: .scout,
                instruction: "Reply with one word.")
            let draft = try await adapter.draft(request)
            XCTAssertFalse(
                draft.body.trimmingCharacters(
                    in: .whitespacesAndNewlines).isEmpty,
                "iteration \(i) failed on a fresh adapter")
            XCTAssertEqual(
                draft.providerID, "apple.foundation-models.v1")
        }
    }

    // MARK: - 3. Marker word from turn 1 doesn't leak to turn 2

    /// Strong stateless property at the response level: turn 1's
    /// prompt mentions a unique marker word; turn 2's prompt is
    /// unrelated. Turn 2's response MUST NOT contain the marker.
    /// If it did, turn 2 would have seen turn 1's context.
    ///
    /// The marker is chosen to be a low-frequency token Apple's
    /// model is unlikely to spontaneously emit on an unrelated
    /// prompt. This is empirical — a future model update could
    /// flake the assertion if the model becomes verbose enough
    /// to reach the marker by coincidence; in that case the
    /// assertion's flake is itself a positive signal worth
    /// investigating.
    func testTurnTwoResponseDoesNotContainTurnOneMarker()
        async throws
    {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()
        let marker = "ZQXJW-KPLBN"  // unlikely-coincidence token

        let req1 = BASOrganRequest(
            requestID: "marker-1",
            role: .scout,
            preset: .scout,
            instruction:
                "Echo the following marker exactly once and " +
                "nothing else: \(marker)")
        let draft1 = try await adapter.draft(req1)
        XCTAssertFalse(draft1.body.isEmpty)
        // We don't strictly require the model to echo the marker
        // (Apple FM may rephrase). But IF it did, that's the
        // case where a real leak into turn 2 would be visible.

        let req2 = BASOrganRequest(
            requestID: "marker-2",
            role: .scout,
            preset: .scout,
            instruction: "Reply with the word 'orange' only.")
        let draft2 = try await adapter.draft(req2)

        XCTAssertFalse(
            draft2.body.uppercased().contains(marker),
            "turn 2 response must NOT contain turn 1's marker " +
            "'\(marker)'. If it does, the adapter is leaking " +
            "context across calls. Got body: '\(draft2.body)'")
    }
}
