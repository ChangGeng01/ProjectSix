import XCTest
import BASOrgan
import BASAppleAdapters
import QinaoLoop
import QinaoAppleFoundation

/// M188 — coverage for `QinaoLoop.streamBody(...)`.
///
/// Two test categories:
///
/// 1. **Offline rejection paths.** No env gate. Verifies that an
///    unconfigured loop or a non-streaming endpoint produces the
///    correct stable `LoopError.organUnavailable(reason:)` codes
///    without making any network / model calls.
///
/// 2. **Real-LLM streaming through QinaoLoop.** Env-gated
///    `QINAO_FM_E2E=1`. Verifies that the public
///    `QinaoLoop.streamBody(...)` API drives a real Apple
///    FoundationModels stream end-to-end and produces a sequence
///    of chunks with monotonic cumulative bodies whose deltas
///    sum to the final cumulative.
final class QinaoLoopStreamBodyTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessRealLLMReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise " +
                "QinaoLoop.streamBody driving real Apple FM")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+; current OS does not satisfy the guard")
    }

    private func collectChunks(
        from stream: AsyncThrowingStream<
            QinaoLoop.OrganResponseChunk, Error>
    ) async throws -> [QinaoLoop.OrganResponseChunk] {
        var chunks: [QinaoLoop.OrganResponseChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        return chunks
    }

    // MARK: - 1. Offline rejection: no endpoint configured

    func testStreamBodyWithoutEndpointEmitsNoEndpointConfigured()
        async throws
    {
        let loop = QinaoLoop()
        let stream = loop.streamBody(
            sessionID: "no-endpoint",
            prompt: "anything")
        do {
            _ = try await collectChunks(from: stream)
            XCTFail("expected throw")
        } catch QinaoLoop.LoopError
            .organUnavailable(let reason)
        {
            XCTAssertEqual(reason, "no-endpoint-configured")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 2. Offline rejection: endpoint exists but no streaming

    /// Custom non-streaming endpoint that has an `produceBody`
    /// implementation but doesn't conform to
    /// `QinaoStreamingOrganEndpoint`.
    private struct NonStreamingEndpoint: QinaoOrganEndpoint {
        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            QinaoLoop.OrganResponse(
                body: "not stream", providerID: "test.nonstream",
                traceID: "trace.x")
        }
    }

    func testStreamBodyOnNonStreamingEndpointEmitsNotStreaming()
        async throws
    {
        let loop = QinaoLoop(
            organEndpoint: NonStreamingEndpoint())
        let stream = loop.streamBody(
            sessionID: "no-streaming",
            prompt: "anything")
        do {
            _ = try await collectChunks(from: stream)
            XCTFail("expected throw")
        } catch QinaoLoop.LoopError
            .organUnavailable(let reason)
        {
            XCTAssertEqual(reason, "endpoint-not-streaming")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 3. Real Apple FM streaming through QinaoLoop

    func testStreamBodyDrivesRealAppleFMAndProducesChunks()
        async throws
    {
        try skipUnlessRealLLMReady()

        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)

        let stream = loop.streamBody(
            sessionID: "stream-real-1",
            prompt:
                "List five short single-word colors, one per line.",
            role: .scout)

        let chunks = try await collectChunks(from: stream)
        XCTAssertGreaterThan(
            chunks.count, 1,
            "real Apple FM streaming through QinaoLoop must " +
            "yield more than one chunk; got \(chunks.count)")

        for chunk in chunks {
            XCTAssertEqual(
                chunk.providerID, "apple.foundation-models.v1")
        }
    }

    func testStreamBodyCumulativeIsMonotonicAndDeltasSumToFinal()
        async throws
    {
        try skipUnlessRealLLMReady()

        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)

        let stream = loop.streamBody(
            sessionID: "stream-real-2",
            prompt: "Reply with three short adjectives.",
            role: .scout)

        let chunks = try await collectChunks(from: stream)
        XCTAssertGreaterThan(chunks.count, 0)

        // Monotonic non-decreasing cumulative.
        for i in 1..<chunks.count {
            XCTAssertGreaterThanOrEqual(
                chunks[i].cumulativeBody.count,
                chunks[i - 1].cumulativeBody.count,
                "cumulativeBody must never shrink between chunks")
        }

        // Deltas concatenate to final cumulative.
        let concatenated = chunks
            .map(\.bodyDelta)
            .reduce("", +)
        XCTAssertEqual(
            concatenated, chunks.last!.cumulativeBody,
            "Σ delta == final cumulative — pin the streaming " +
            "invariant at the QinaoLoop public boundary")
    }

    // MARK: - 4. Smoke: factory builds a stream-capable endpoint

    func testFactoryEndpointSupportsStreaming() async {
        // Not env-gated — we're checking conformance, not the
        // real model. The factory's resolved endpoint MUST be
        // probeable as a streaming endpoint.
        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        XCTAssertNotNil(
            endpoint as? QinaoStreamingOrganEndpoint,
            "QinaoLoop.makeAppleFoundationEndpoint() must return " +
            "an endpoint that conforms to " +
            "QinaoStreamingOrganEndpoint — otherwise " +
            "loop.streamBody(...) silently degrades")
    }
}
