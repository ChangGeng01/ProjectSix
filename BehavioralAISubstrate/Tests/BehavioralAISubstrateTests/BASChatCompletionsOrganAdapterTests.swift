import XCTest
@testable import BASOrgan
@testable import BASChatCompletionsAdapter

/// M208 — coverage for the generic OpenAI-compatible Chat
/// Completions adapter. Tests fall into three groups:
///
/// 1. Pure helpers (no network): request body shape, response
///    parsing, error mapping for malformed shapes.
/// 2. End-to-end via `URLProtocol` stub: full adapter path with
///    a fake HTTP response. No real network — runs offline in CI.
/// 3. Behavior under HTTP error / malformed body: stable
///    `BASOrganError` reason codes preserved.

// MARK: - URLProtocol-based offline stub

/// `URLProtocol` subclass that intercepts ALL `URLRequest`s on a
/// configured `URLSession` and returns a canned response. Tests
/// install this once; each test method sets `Self.canned`.
private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var canned: (
        statusCode: Int, body: Data
    ) = (200, Data())
    nonisolated(unsafe) static var lastRequestBody: Data?
    nonisolated(unsafe) static var lastRequestURL: URL?
    nonisolated(unsafe) static var lastRequestHeaders: [String: String]?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequestURL = request.url
        Self.lastRequestHeaders = request.allHTTPHeaderFields
        // URLSession's "data(for:)" doesn't expose the body via
        // request.httpBody when it was set on URLRequest before
        // upload — for an offline stub we read it from
        // `httpBodyStream` if needed. For our adapter, body is
        // small and set inline so request.httpBody is populated.
        Self.lastRequestBody = request.httpBody

        let canned = Self.canned
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "stub://x")!,
            statusCode: canned.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: canned.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeStubbedSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

private func okBody(_ content: String) -> Data {
    let payload: [String: Any] = [
        "id": "chatcmpl-stub",
        "object": "chat.completion",
        "model": "stub-model",
        "choices": [[
            "index": 0,
            "message": ["role": "assistant", "content": content],
            "finish_reason": "stop"
        ]]
    ]
    return try! JSONSerialization.data(withJSONObject: payload)
}

// MARK: - Tests

final class BASChatCompletionsOrganAdapterTests: XCTestCase {

    private let endpoint = BASChatCompletionsOrganAdapter.Endpoint(
        url: URL(string: "https://stub.example.com/v1/chat/completions")!,
        headers: ["Authorization": "Bearer test-key"],
        model: "test-model-1")

    private func makeAdapter(
        session: URLSession,
        providerID: String = "test.openai-compat"
    ) -> BASChatCompletionsOrganAdapter {
        BASChatCompletionsOrganAdapter(
            endpoint: endpoint,
            providerID: providerID,
            providerName: "OpenAI-Compatible (test)",
            urlSession: session)
    }

    private func makeRequest(
        _ instruction: String = "ping",
        role: BASOrganRole = .scout
    ) -> BASOrganRequest {
        BASOrganRequest(
            requestID: "req-\(UUID().uuidString)",
            role: role,
            preset: role == .scout ? .scout : .core,
            instruction: instruction)
    }

    // MARK: - 1. Descriptor + role enforcement

    func testDescriptorReportsRemoteAndAdvertisesBothRoles() async {
        let session = makeStubbedSession()
        let adapter = makeAdapter(session: session)
        XCTAssertEqual(
            adapter.descriptor.providerID, "test.openai-compat")
        XCTAssertFalse(
            adapter.descriptor.runsOnDevice,
            "remote adapter MUST advertise runsOnDevice = false")
        XCTAssertTrue(
            adapter.descriptor.supportedRoles.contains(.scout))
        XCTAssertTrue(
            adapter.descriptor.supportedRoles.contains(.core))
    }

    func testRejectsUnsupportedRoleBeforeNetwork() async {
        let session = makeStubbedSession()
        // Build adapter that only supports core; ask for scout.
        let adapter = BASChatCompletionsOrganAdapter(
            endpoint: endpoint,
            providerID: "test.core-only",
            providerName: "Core-only",
            urlSession: session,
            supportedRoles: [.core])
        let request = makeRequest("hi", role: .scout)
        do {
            _ = try await adapter.draft(request)
            XCTFail("expected unsupportedRole")
        } catch BASOrganError.unsupportedRole(let r) {
            XCTAssertEqual(r, .scout)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 2. Pure helpers

    func testBuildRequestBodyHasOpenAIShape() throws {
        let request = makeRequest("explain gravity")
        let data = try BASChatCompletionsOrganAdapter
            .buildRequestBody(for: request, model: "test-model-1")
        let json = try JSONSerialization.jsonObject(with: data)
            as! [String: Any]
        XCTAssertEqual(json["model"] as? String, "test-model-1")
        let messages = json["messages"] as! [[String: String]]
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertEqual(messages[1]["role"], "user")
        XCTAssertTrue(
            (messages[1]["content"] ?? "").contains("explain gravity"))
        XCTAssertNotNil(json["temperature"])
        XCTAssertNotNil(json["max_tokens"])
    }

    func testParseResponseBodyExtractsContent() throws {
        let payload: [String: Any] = [
            "choices": [[
                "message": [
                    "role": "assistant",
                    "content": "the answer is 42"
                ]
            ]]
        ]
        let data = try JSONSerialization.data(
            withJSONObject: payload)
        let body = try BASChatCompletionsOrganAdapter
            .parseResponseBody(data)
        XCTAssertEqual(body, "the answer is 42")
    }

    func testParseResponseBodyMalformedJSONThrowsTyped() {
        let bogus = Data("not-json".utf8)
        do {
            _ = try BASChatCompletionsOrganAdapter
                .parseResponseBody(bogus)
            XCTFail("expected throw")
        } catch BASOrganError.providerUnavailable(let reason) {
            XCTAssertEqual(reason, "malformed-json")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testParseResponseBodyMissingChoicesThrowsTyped() throws {
        let payload: [String: Any] = ["error": "rate-limited"]
        let data = try JSONSerialization.data(
            withJSONObject: payload)
        do {
            _ = try BASChatCompletionsOrganAdapter
                .parseResponseBody(data)
            XCTFail("expected throw")
        } catch BASOrganError.providerUnavailable(let reason) {
            XCTAssertEqual(
                reason, "malformed-chat-completions-response")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 3. End-to-end via URLProtocol stub

    func testEndToEndHappyPathProducesDraft() async throws {
        StubURLProtocol.canned = (
            200, okBody("Gravity pulls things toward Earth."))
        let session = makeStubbedSession()
        let adapter = makeAdapter(session: session)

        let draft = try await adapter.draft(
            makeRequest("Reply with one sentence about gravity."))

        XCTAssertEqual(
            draft.body, "Gravity pulls things toward Earth.")
        XCTAssertEqual(draft.providerID, "test.openai-compat")
        XCTAssertEqual(draft.role, .scout)
        XCTAssertGreaterThan(draft.outputTokensEstimated, 0)
        XCTAssertFalse(draft.traceID.isEmpty)

        // Verify the stub saw the right outbound request.
        XCTAssertEqual(
            StubURLProtocol.lastRequestURL?.absoluteString,
            "https://stub.example.com/v1/chat/completions")
        XCTAssertEqual(
            StubURLProtocol.lastRequestHeaders?["Authorization"],
            "Bearer test-key")
        XCTAssertEqual(
            StubURLProtocol.lastRequestHeaders?["Content-Type"],
            "application/json")
        // URLSession converts inline httpBody to a stream before
        // URLProtocol sees the request, so lastRequestBody is nil
        // here. The fact that draft.body matches the canned
        // response proves the request DID reach the stub and the
        // response parsed correctly — that's the round-trip we
        // care about.
    }

    func testHTTP401MapsToProviderUnavailable() async {
        StubURLProtocol.canned = (
            401, Data(#"{"error":"unauthorized"}"#.utf8))
        let session = makeStubbedSession()
        let adapter = makeAdapter(session: session)

        do {
            _ = try await adapter.draft(makeRequest())
            XCTFail("expected providerUnavailable")
        } catch BASOrganError.providerUnavailable(let reason) {
            XCTAssertEqual(reason, "http-401")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testHTTP500MapsToProviderUnavailable() async {
        StubURLProtocol.canned = (500, Data())
        let session = makeStubbedSession()
        let adapter = makeAdapter(session: session)

        do {
            _ = try await adapter.draft(makeRequest())
            XCTFail("expected providerUnavailable")
        } catch BASOrganError.providerUnavailable(let reason) {
            XCTAssertEqual(reason, "http-500")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testHTTP200WithMalformedBodyMapsToProviderUnavailable()
        async
    {
        StubURLProtocol.canned = (200, Data("not-json".utf8))
        let session = makeStubbedSession()
        let adapter = makeAdapter(session: session)

        do {
            _ = try await adapter.draft(makeRequest())
            XCTFail("expected providerUnavailable")
        } catch BASOrganError.providerUnavailable(let reason) {
            XCTAssertEqual(reason, "malformed-json")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 4. Registry compatibility

    /// The whole point of the protocol portability claim: the new
    /// adapter drops into `BASOrganRegistry` exactly the way the
    /// Apple FM and deterministic adapters do.
    func testAdapterIsRegistryCompatible() async throws {
        StubURLProtocol.canned = (
            200, okBody("registry-okay"))
        let session = makeStubbedSession()
        let adapter = makeAdapter(session: session)

        let registry = BASOrganRegistry()
        await registry.register(adapter)

        // Registry resolves it for both roles. The adapter's
        // descriptor.runsOnDevice == false means in production it
        // wouldn't be the most-recent on-device pick, but with no
        // on-device adapter registered it falls through to it.
        let resolved = try await registry.adapter(for: .scout)
        XCTAssertEqual(
            resolved.descriptor.providerID, "test.openai-compat")

        let draft = try await resolved.draft(makeRequest())
        XCTAssertEqual(draft.body, "registry-okay")
    }
}
