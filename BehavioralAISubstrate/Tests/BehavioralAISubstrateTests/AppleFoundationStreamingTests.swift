import XCTest
@testable import BASOrgan
@testable import BASAppleAdapters

/// M184 — env-gated streaming proof for `AppleFoundationOrganAdapter`.
///
/// Pre-M184 the adapter exposed only the synchronous `draft(_:)`
/// path. M184 adds `BASStreamingOrganAdapter` conformance via
/// `streamDraft(_:)`. This suite proves the streaming code path
/// actually drives `LanguageModelSession.streamResponse(to:options:)`
/// and produces a sequence of `BASOrganDraftChunk` values whose
/// `cumulativeBody` grows monotonically and whose `bodyDelta`s
/// concatenate to equal the final cumulative body.
///
/// Gated behind `QINAO_FM_E2E=1` + macOS 26+ same as M177.
final class AppleFoundationStreamingTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise real Apple " +
                "FoundationModels streaming")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels streaming requires iOS 26+ / " +
            "macOS 26+ / visionOS 26+")
    }

    private func collectChunks(
        from stream: AsyncThrowingStream<
            BASOrganDraftChunk, Error>
    ) async throws -> [BASOrganDraftChunk] {
        var chunks: [BASOrganDraftChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        return chunks
    }

    // MARK: - 1. Real streaming yields multiple chunks

    func testRealStreamYieldsMultipleChunks() async throws {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()
        let request = BASOrganRequest(
            requestID: "stream-1",
            role: .scout,
            preset: .scout,
            instruction:
                "List five short single-word colors, one per line.")

        let chunks = try await collectChunks(
            from: adapter.streamDraft(request))

        XCTAssertGreaterThan(
            chunks.count, 1,
            "real Apple FM streaming must yield more than one " +
            "chunk for a multi-token reply; got \(chunks.count)")
        for chunk in chunks {
            XCTAssertEqual(
                chunk.providerID, "apple.foundation-models.v1")
            XCTAssertEqual(chunk.requestID, "stream-1")
            XCTAssertEqual(chunk.role, .scout)
        }
    }

    // MARK: - 2. cumulativeBody is monotonically non-decreasing

    func testCumulativeBodyIsMonotonicallyNonDecreasing()
        async throws
    {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()
        let request = BASOrganRequest(
            requestID: "stream-2",
            role: .scout,
            preset: .scout,
            instruction: "Reply with exactly five short words.")

        let chunks = try await collectChunks(
            from: adapter.streamDraft(request))
        XCTAssertGreaterThan(chunks.count, 0)

        for i in 1..<chunks.count {
            XCTAssertGreaterThanOrEqual(
                chunks[i].cumulativeBody.count,
                chunks[i - 1].cumulativeBody.count,
                "cumulativeBody must never shrink between " +
                "consecutive chunks (chunk \(i) is shorter than " +
                "chunk \(i - 1))")
        }
    }

    // MARK: - 3. delta concatenation equals final cumulative

    func testConcatenatedDeltasEqualFinalCumulativeBody()
        async throws
    {
        try skipUnlessReady()

        let adapter = AppleFoundationOrganAdapter()
        let request = BASOrganRequest(
            requestID: "stream-3",
            role: .scout,
            preset: .scout,
            instruction: "Reply with three short adjectives.")

        let chunks = try await collectChunks(
            from: adapter.streamDraft(request))
        XCTAssertGreaterThan(chunks.count, 0)

        let concatenated = chunks
            .map(\.bodyDelta)
            .reduce("", +)
        let finalCumulative = chunks.last!.cumulativeBody
        XCTAssertEqual(
            concatenated, finalCumulative,
            "concatenating every chunk's bodyDelta must equal " +
            "the final cumulativeBody — the delta-vs-cumulative " +
            "invariant the chunk struct documents")
        XCTAssertFalse(
            finalCumulative
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            "final cumulative body must be non-empty real LLM " +
            "output")
    }

    // MARK: - 4. Adapter advertises supportsStreaming = true

    func testAdapterAdvertisesStreaming() async {
        // Not env-gated — descriptor is local metadata.
        let adapter = AppleFoundationOrganAdapter()
        XCTAssertTrue(
            adapter.descriptor.supportsStreaming,
            "AppleFoundationOrganAdapter descriptor MUST advertise " +
            "supportsStreaming = true post-M184; hosts probe this " +
            "to decide whether to call streamDraft(_:) or fall " +
            "back to draft(_:)")
    }

    // MARK: - 5. Streaming is reachable via BASStreamingOrganAdapter
    //         protocol cast

    func testAdapterConformsToStreamingProtocol() async {
        // Not env-gated — protocol conformance is a compile-time fact.
        let adapter: any BASOrganAdapter =
            AppleFoundationOrganAdapter()
        let streaming = adapter as? BASStreamingOrganAdapter
        XCTAssertNotNil(
            streaming,
            "AppleFoundationOrganAdapter must conform to " +
            "BASStreamingOrganAdapter — host's `as?` probe is the " +
            "production way to choose stream vs non-stream path")
    }
}
