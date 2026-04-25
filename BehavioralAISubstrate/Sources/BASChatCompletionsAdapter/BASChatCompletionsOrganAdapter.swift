import Foundation
import BASRuntimeCore
import BASOrgan

/// M208 — generic remote-LLM organ provider that conforms to
/// `BASOrganAdapter` against any **OpenAI Chat Completions**–shape
/// HTTP endpoint.
///
/// ## What this adapter is for
///
/// The substrate has been single-provider since shipping (Apple
/// FoundationModels via `AppleFoundationOrganAdapter` + a
/// deterministic in-memory stub). This adapter proves the
/// `BASOrganAdapter` protocol is genuinely **provider-agnostic**:
/// any HTTP endpoint that speaks the OpenAI Chat Completions JSON
/// shape can drop into the same registry/loop machinery the
/// on-device adapter uses.
///
/// Compatible providers (verified by JSON shape, not vendor
/// affiliation):
///   - OpenAI (`api.openai.com/v1/chat/completions`)
///   - Anthropic via OpenAI-compatible proxy
///   - Mistral, Together AI, Groq, Fireworks, etc.
///   - Local servers: llama.cpp, vLLM, LM Studio, Ollama
///
/// ## Architecture
///
/// `Endpoint` carries the URL + auth headers + model ID. The
/// adapter's `draft(_:)` builds a Chat Completions request body,
/// POSTs via injected `URLSession`, parses the response, and
/// returns a standard `BASOrganDraft`. No streaming yet (would
/// add `BASStreamingOrganAdapter` conformance via SSE in a future
/// milestone).
///
/// `URLSession` is injected for testability — `URLProtocol`-stub
/// tests exercise the full adapter path without network I/O.
///
/// ## Error mapping
///
/// HTTP non-2xx → `BASOrganError.providerUnavailable("http-NNN")`
/// Malformed response → `.providerUnavailable("malformed-...")`
/// Unsupported role → `.unsupportedRole(role)`
/// Network throw → `.providerUnavailable("transport:<msg>")`
public actor BASChatCompletionsOrganAdapter: BASOrganAdapter {

    /// Endpoint config — URL + auth headers + model ID. All three
    /// fields are required because remote providers vary per axis.
    public struct Endpoint: Sendable, Equatable {
        public let url: URL
        public let headers: [String: String]
        public let model: String

        public init(
            url: URL,
            headers: [String: String] = [:],
            model: String
        ) {
            self.url = url
            self.headers = headers
            self.model = model
        }
    }

    public nonisolated let descriptor: BASOrganDescriptor
    private let endpoint: Endpoint
    private let urlSession: URLSession

    /// M210 — nonisolated mirrors of `endpoint` and `urlSession`
    /// so the streaming extension (which builds an
    /// `AsyncThrowingStream` from outside the actor) can read
    /// them without an `await` hop. Both fields are immutable
    /// `let`s; the actor's state machine never mutates them so
    /// reading them off-actor is data-race-free.
    nonisolated let nonisolatedEndpoint: Endpoint
    nonisolated let nonisolatedURLSession: URLSession

    public init(
        endpoint: Endpoint,
        providerID: String,
        providerName: String,
        urlSession: URLSession = URLSession.shared,
        maxInputTokens: Int = 8_192,
        maxOutputTokens: Int = 4_096,
        supportedRoles: Set<BASOrganRole> = [.scout, .core]
    ) {
        self.endpoint = endpoint
        self.urlSession = urlSession
        self.nonisolatedEndpoint = endpoint
        self.nonisolatedURLSession = urlSession
        self.descriptor = BASOrganDescriptor(
            providerID: providerID,
            providerName: providerName,
            supportsStreaming: false,
            maxInputTokens: maxInputTokens,
            maxOutputTokens: maxOutputTokens,
            // Remote provider — registry's "prefer most-recent
            // on-device" rule won't pick this over an on-device
            // adapter. Hosts can still register multiple remotes
            // and pick by descriptor.
            runsOnDevice: false,
            supportedRoles: supportedRoles)
    }

    public func draft(
        _ request: BASOrganRequest
    ) async throws -> BASOrganDraft {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }
        if let deadline = request.deadline,
           deadline < Date()
        {
            throw BASOrganError.deadlineExpired
        }

        let body = try Self.buildRequestBody(
            for: request, model: endpoint.model)

        var urlRequest = URLRequest(url: endpoint.url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type")
        for (k, v) in endpoint.headers {
            urlRequest.setValue(v, forHTTPHeaderField: k)
        }
        urlRequest.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession
                .data(for: urlRequest)
        } catch {
            throw BASOrganError.providerUnavailable(
                reason: "transport:\(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw BASOrganError.providerUnavailable(
                reason: "non-http-response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BASOrganError.providerUnavailable(
                reason: "http-\(http.statusCode)")
        }

        let bodyText = try Self.parseResponseBody(data)

        return BASOrganDraft(
            requestID: request.requestID,
            providerID: descriptor.providerID,
            role: request.role,
            body: bodyText,
            inputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(
                    from: [request.instruction] + request.context),
            outputTokensEstimated: BASOrganDeterministicAdapter
                .estimateTokens(from: [bodyText]),
            producedAt: Date(),
            traceID: BASOrganDeterministicAdapter
                .digest(for: request, providerID: descriptor.providerID))
    }

    public func currentCapacity() async -> BASOrganCapacity {
        // Remote providers self-throttle; we don't have a local
        // pressure signal to surface. Hosts that want budget
        // limits should layer them on top.
        .unlimited
    }

    // MARK: - Pure helpers (testable without URLSession)

    /// Build an OpenAI-style Chat Completions request body from a
    /// `BASOrganRequest`. Pure function — no network, no Date.
    public static func buildRequestBody(
        for request: BASOrganRequest,
        model: String
    ) throws -> Data {
        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": Self.systemInstructions(for: request)
            ],
            [
                "role": "user",
                "content": Self.userMessage(for: request)
            ]
        ]
        var payload: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": request.preset.temperature,
            "max_tokens":
                request.maxOutputTokens
                    ?? request.preset.maxOutputTokens
        ]
        if !request.stopSequences.isEmpty {
            payload["stop"] = request.stopSequences
        }
        return try JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys])
    }

    /// Parse an OpenAI-style Chat Completions response body. Pure
    /// function. Throws `BASOrganError.providerUnavailable` with a
    /// stable reason on shape mismatch.
    public static func parseResponseBody(
        _ data: Data
    ) throws -> String {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw BASOrganError.providerUnavailable(
                reason: "malformed-json")
        }
        guard
            let dict = json as? [String: Any],
            let choices = dict["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw BASOrganError.providerUnavailable(
                reason: "malformed-chat-completions-response")
        }
        return content
    }

    /// Role-to-system-instructions mirror of the Apple FM adapter
    /// — same scout/core split so audit trails stay comparable
    /// across providers.
    public static func systemInstructions(
        for request: BASOrganRequest
    ) -> String {
        switch request.role {
        case .scout:
            return """
            You are the Scout tier of a behavioural AI substrate.
            Keep answers short, structured, and low-commitment.
            Prefer identifying risks and candidate angles over
            producing final prose.
            """
        case .core:
            return """
            You are the Core tier of a behavioural AI substrate.
            Produce a considered response; you are being called
            because a draft has been admitted for full consideration.
            """
        }
    }

    /// Build the user-message content from a request's instruction
    /// + context. Same shape the Apple FM adapter uses.
    public static func userMessage(
        for request: BASOrganRequest
    ) -> String {
        var parts = ["Instruction:", request.instruction]
        if !request.context.isEmpty {
            parts.append("")
            parts.append("Context:")
            for (i, ctx) in request.context.enumerated() {
                parts.append("[\(i + 1)] \(ctx)")
            }
        }
        return parts.joined(separator: "\n")
    }
}
