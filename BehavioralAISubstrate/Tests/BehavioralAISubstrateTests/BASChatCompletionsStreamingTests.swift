import XCTest
@testable import BASOrgan
@testable import BASChatCompletionsAdapter

/// M210 — coverage for SSE streaming via the generic
/// Chat Completions adapter.
///
/// Three groups:
///   1. Pure SSE-line parser (no network)
///   2. Streaming request body (must include `"stream": true`)
///   3. Conformance to `BASStreamingOrganAdapter` (cast probe)
///
/// Network-driven streaming end-to-end requires a chunked
/// `URLProtocol` mock that delivers bytes in pieces. That's out
/// of scope for this offline suite; the pure parser + cast probe
/// already pin every code path other than `URLSession.bytes(...)`,
/// which is Apple framework code.
final class BASChatCompletionsStreamingTests: XCTestCase {

    private let endpoint = BASChatCompletionsOrganAdapter.Endpoint(
        url: URL(string: "https://stub.example.com/v1/chat/completions")!,
        headers: ["Authorization": "Bearer test-key"],
        model: "test-model")

    private func makeAdapter() -> BASChatCompletionsOrganAdapter {
        BASChatCompletionsOrganAdapter(
            endpoint: endpoint,
            providerID: "test.openai-stream",
            providerName: "OpenAI-Compatible (stream)")
    }

    // MARK: - 1. SSE line parser

    func testParseSSEDataLineExtractsContent() {
        let line = #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#
        let delta = BASChatCompletionsOrganAdapter
            .parseSSEDataLine(line)
        XCTAssertEqual(delta, "Hello")
    }

    func testParseSSEDataLineHandlesUnicodeContent() {
        let line = #"data: {"choices":[{"delta":{"content":"你好"}}]}"#
        let delta = BASChatCompletionsOrganAdapter
            .parseSSEDataLine(line)
        XCTAssertEqual(delta, "你好")
    }

    func testParseSSEDataLineReturnsNilForDoneSentinel() {
        XCTAssertNil(
            BASChatCompletionsOrganAdapter
                .parseSSEDataLine("data: [DONE]"))
    }

    func testParseSSEDataLineReturnsNilForCommentLine() {
        XCTAssertNil(
            BASChatCompletionsOrganAdapter
                .parseSSEDataLine(": keep-alive"))
    }

    func testParseSSEDataLineReturnsNilForEmptyLine() {
        XCTAssertNil(
            BASChatCompletionsOrganAdapter
                .parseSSEDataLine(""))
    }

    func testParseSSEDataLineReturnsNilWhenDeltaContentMissing() {
        // OpenAI emits a leading event with `delta: {"role": "assistant"}`
        // but no `content` field. Adapter ignores it.
        let line = #"data: {"choices":[{"delta":{"role":"assistant"}}]}"#
        XCTAssertNil(
            BASChatCompletionsOrganAdapter
                .parseSSEDataLine(line))
    }

    func testParseSSEDataLineReturnsNilForMalformedJSON() {
        let line = "data: {not-json"
        XCTAssertNil(
            BASChatCompletionsOrganAdapter
                .parseSSEDataLine(line))
    }

    // MARK: - 2. [DONE] sentinel detection

    func testIsSSEDoneLineRecognizesStandardForm() {
        XCTAssertTrue(
            BASChatCompletionsOrganAdapter
                .isSSEDoneLine("data: [DONE]"))
    }

    func testIsSSEDoneLineRecognizesNoSpaceForm() {
        XCTAssertTrue(
            BASChatCompletionsOrganAdapter
                .isSSEDoneLine("data:[DONE]"))
    }

    func testIsSSEDoneLineRejectsContentLines() {
        XCTAssertFalse(
            BASChatCompletionsOrganAdapter
                .isSSEDoneLine(
                    #"data: {"choices":[{"delta":{"content":"x"}}]}"#))
        XCTAssertFalse(
            BASChatCompletionsOrganAdapter
                .isSSEDoneLine(""))
    }

    // MARK: - 3. Streaming request body

    func testStreamingRequestBodyIncludesStreamTrue() throws {
        let request = BASOrganRequest(
            requestID: "r1",
            role: .scout,
            preset: .scout,
            instruction: "ping")
        let data = try BASChatCompletionsOrganAdapter
            .buildStreamingRequestBody(
                for: request, model: "m1")
        let json = try JSONSerialization.jsonObject(with: data)
            as! [String: Any]
        XCTAssertEqual(json["stream"] as? Bool, true,
            "streaming body MUST include stream:true")
        XCTAssertEqual(json["model"] as? String, "m1")
        let messages = json["messages"] as! [[String: String]]
        XCTAssertEqual(messages.count, 2)
    }

    func testStreamingRequestBodyMatchesNonStreamingExceptForStreamFlag()
        throws
    {
        // Same input, both helpers, JSON should differ ONLY in
        // the `stream` key.
        let request = BASOrganRequest(
            requestID: "r2",
            role: .core,
            preset: .core,
            instruction: "test")
        let nonStream = try BASChatCompletionsOrganAdapter
            .buildRequestBody(for: request, model: "m")
        let stream = try BASChatCompletionsOrganAdapter
            .buildStreamingRequestBody(for: request, model: "m")
        let nonStreamJSON = try JSONSerialization
            .jsonObject(with: nonStream) as! [String: Any]
        let streamJSON = try JSONSerialization
            .jsonObject(with: stream) as! [String: Any]

        var nonStreamWithStream = nonStreamJSON
        nonStreamWithStream["stream"] = true

        // Compare via stable JSON serialization (sortedKeys)
        let a = try JSONSerialization.data(
            withJSONObject: nonStreamWithStream,
            options: [.sortedKeys])
        let b = try JSONSerialization.data(
            withJSONObject: streamJSON, options: [.sortedKeys])
        XCTAssertEqual(a, b,
            "streaming body must equal non-streaming body PLUS " +
            "stream:true")
    }

    // MARK: - 4. Adapter conforms to BASStreamingOrganAdapter

    func testAdapterConformsToBASStreamingOrganAdapter() {
        let adapter: any BASOrganAdapter = makeAdapter()
        let streaming = adapter as? BASStreamingOrganAdapter
        XCTAssertNotNil(
            streaming,
            "BASChatCompletionsOrganAdapter must conform to " +
            "BASStreamingOrganAdapter — hosts probe via `as?` " +
            "to choose stream vs non-stream path")
    }

    func testStreamRejectsUnsupportedRoleBeforeNetwork()
        async throws
    {
        // Adapter that only supports core; ask for scout → stream
        // terminates with .unsupportedRole BEFORE making any HTTP
        // call. (Empty URL would fail at network level if we
        // reached that far.)
        let coreOnly = BASChatCompletionsOrganAdapter(
            endpoint: endpoint,
            providerID: "test.core-only",
            providerName: "Core-only",
            supportedRoles: [.core])
        let request = BASOrganRequest(
            requestID: "r-rej",
            role: .scout,
            preset: .scout,
            instruction: "x")
        let stream = coreOnly.streamDraft(request)
        do {
            for try await _ in stream { /* none */ }
            XCTFail("expected unsupportedRole")
        } catch BASOrganError.unsupportedRole(let r) {
            XCTAssertEqual(r, .scout)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 5. Cumulative-body invariant via simulated SSE lines

    /// Drive `parseSSEDataLine` on a recorded sequence of SSE
    /// events; concatenated deltas == full text. This is the
    /// invariant the network-fed `streamDraft(_:)` would maintain;
    /// we verify the parser piece works correctly without
    /// running URLSession.
    func testConcatenatedDeltasEqualFullExpectedText() {
        let events = [
            #"data: {"choices":[{"delta":{"role":"assistant"}}]}"#,
            #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#,
            #"data: {"choices":[{"delta":{"content":", "}}]}"#,
            #"data: {"choices":[{"delta":{"content":"world"}}]}"#,
            #"data: {"choices":[{"delta":{"content":"!"}}]}"#,
            "data: [DONE]"
        ]
        var collected = ""
        for event in events {
            if BASChatCompletionsOrganAdapter
                .isSSEDoneLine(event) { break }
            if let delta = BASChatCompletionsOrganAdapter
                .parseSSEDataLine(event)
            {
                collected += delta
            }
        }
        XCTAssertEqual(collected, "Hello, world!")
    }
}
