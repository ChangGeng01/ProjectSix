import XCTest
@testable import BASOrgan
@testable import BASMLXAdapter

/// M221 — end-to-end tests against a real Hugging Face model
/// download + MLX inference path. These tests are *not* part of
/// the default `swift test` run because:
///
///   1. First run downloads ~1.4 GB (Gemma 3n E2B 4-bit) of weights
///      from `huggingface.co` — expensive in CI.
///   2. Inference itself takes 1–10 seconds per draft on Apple
///      Silicon, depending on the model and prompt length.
///   3. Network failures and rate-limiting from HF would otherwise
///      flake the offline test suite.
///
/// Gated behind `QINAO_MLX_E2E=1`. Pick the smallest entry
/// (`gemma3n_E2B_4bit`) so re-runs are tolerable; tests that need
/// the larger Gemma 3 4B variants must opt in explicitly via the
/// `QINAO_MLX_E2E_FULL=1` flag.
final class MLXOrganAdapterE2ETests: XCTestCase {

    private static let envFlag = "QINAO_MLX_E2E"
    private static let envFlagFull = "QINAO_MLX_E2E_FULL"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise MLX " +
                "end-to-end (downloads ~1.4 GB + runs inference)")
        }
    }

    // MARK: - 1. Load + draft round-trip

    func testLoadModelAndDraftReturnsRealBody() async throws {
        try skipUnlessReady()

        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma3n_E2B_4bit)

        // First-run download path. Ignore progress in tests; UI
        // hosts wire a non-empty handler in M222.
        try await adapter.loadModel()

        let isLoaded = await adapter.isModelLoaded()
        XCTAssertTrue(
            isLoaded,
            "loadModel() must produce a ModelContainer; without " +
            "one the draft path stays unavailable")

        let request = BASOrganRequest(
            requestID: "e2e-1",
            role: .core,
            preset: .core,
            instruction:
                "Reply with a single short sentence about a " +
                "calming evening habit.",
            context: [])

        let draft = try await adapter.draft(request)
        XCTAssertFalse(
            draft.body.isEmpty,
            "real Gemma inference must produce non-empty body")
        XCTAssertEqual(draft.requestID, "e2e-1")
        XCTAssertEqual(
            draft.providerID,
            MLXModelCatalog.gemma3n_E2B_4bit.providerID)
        XCTAssertGreaterThan(
            draft.outputTokensEstimated, 0,
            "non-empty body should yield a positive output-token " +
            "estimate")
    }

    // MARK: - 2. Streaming round-trip

    func testStreamDraftYieldsAccumulatingChunks() async throws {
        try skipUnlessReady()

        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma3n_E2B_4bit)
        try await adapter.loadModel()

        let request = BASOrganRequest(
            requestID: "e2e-stream-1",
            role: .core,
            preset: .core,
            instruction: "Count from one to three.",
            context: [])

        var chunks: [BASOrganDraftChunk] = []
        for try await chunk in adapter.streamDraft(request) {
            chunks.append(chunk)
        }
        XCTAssertFalse(
            chunks.isEmpty,
            "streaming must produce at least one chunk")

        // Cumulative body must monotonically grow across chunks.
        var lastLength = 0
        for chunk in chunks {
            XCTAssertGreaterThanOrEqual(
                chunk.cumulativeBody.count, lastLength,
                "cumulativeBody must monotonically grow across " +
                "stream chunks; got drop from \(lastLength) → " +
                "\(chunk.cumulativeBody.count)")
            lastLength = chunk.cumulativeBody.count
        }

        // Last cumulativeBody must equal sum of all bodyDeltas.
        let summedDeltas = chunks
            .map(\.bodyDelta)
            .joined()
        XCTAssertEqual(
            chunks.last?.cumulativeBody, summedDeltas,
            "final cumulativeBody must equal concatenation of " +
            "all bodyDeltas — invariant for the +Streaming bridge")
    }

    // MARK: - 3. Capacity flips after load

    func testCapacityReportsLoadedAfterLoadModel() async throws {
        try skipUnlessReady()

        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma3n_E2B_4bit)

        // Pre-load: underPressure with MLX_NOT_LOADED.
        let pre = await adapter.currentCapacity()
        XCTAssertTrue(pre.underPressure)
        XCTAssertEqual(pre.reasonCodes, ["MLX_NOT_LOADED"])

        try await adapter.loadModel()

        let post = await adapter.currentCapacity()
        XCTAssertFalse(
            post.underPressure,
            "loaded model should report not-under-pressure")
        XCTAssertEqual(
            post.reasonCodes, [],
            "loaded model should clear all reason codes")
        XCTAssertGreaterThan(post.availableInputTokens, 0)
        XCTAssertGreaterThan(post.availableOutputTokens, 0)
    }

    // MARK: - 4. Idempotent load

    func testLoadModelIsIdempotentOnSecondCall() async throws {
        try skipUnlessReady()

        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.gemma3n_E2B_4bit)

        try await adapter.loadModel()
        let firstLoaded = await adapter.isModelLoaded()
        XCTAssertTrue(firstLoaded)

        // Second call should return immediately and leave state
        // unchanged.
        try await adapter.loadModel()
        let secondLoaded = await adapter.isModelLoaded()
        XCTAssertTrue(
            secondLoaded,
            "loadModel() must be idempotent — second call should " +
            "not unload")
    }
}
