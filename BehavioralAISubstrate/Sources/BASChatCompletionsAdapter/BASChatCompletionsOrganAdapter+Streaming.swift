import Foundation
import BASOrgan

/// M210 — Server-Sent Events (SSE) streaming for the generic
/// OpenAI-compatible Chat Completions adapter.
///
/// ## What this adds
///
/// `BASChatCompletionsOrganAdapter` already supports
/// non-streaming `draft(_:)`. M210 adds `BASStreamingOrganAdapter`
/// conformance via `streamDraft(_:)`, which:
///
/// 1. Sends the same Chat Completions request body with
///    `"stream": true` added.
/// 2. Receives raw bytes into a request-local bounded buffer.
/// 3. Parses SSE format (each event is `data: {json}\n\n`).
/// 4. Extracts `choices[0].delta.content` from each event.
/// 5. Accumulates the cumulative body and yields one
///    `BASOrganDraftChunk` per non-empty delta.
/// 6. Terminates cleanly on the `[DONE]` sentinel.
///
/// ## Compatible providers
///
/// SSE / `[DONE]` semantics are the OpenAI Chat Completions
/// reference shape, supported by every provider listed for the
/// non-streaming path: OpenAI, Anthropic-compatible proxies,
/// Mistral, Together AI, Groq, Fireworks, llama.cpp, vLLM,
/// LM Studio, Ollama.
///
/// Startup transport errors use `transport:<msg>`; body-read transport
/// errors remain the original errors. Malformed SSE frames are ignored.
extension BASChatCompletionsOrganAdapter: BASStreamingOrganAdapter {

    public nonisolated func streamDraft(
        _ request: BASOrganRequest
    ) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
        let state = Result { () throws -> ChatSSEPull in
            guard descriptor.supportedRoles.contains(request.role) else {
                throw BASOrganError.unsupportedRole(request.role)
            }
            if let deadline = request.deadline, deadline <= Date() {
                throw BASOrganError.deadlineExpired
            }
            return try makeSSEPull(request: request)
        }
        // One consumer request produces one delta. No queued cumulative snapshots.
        return AsyncThrowingStream(unfolding: { try await state.get().next() })
    }

    /// Build the same JSON body as `buildRequestBody(for:model:)`
    /// but with `"stream": true` added. Pure function.
    public static func buildStreamingRequestBody(
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
                    ?? request.preset.maxOutputTokens,
            "stream": true
        ]
        if !request.stopSequences.isEmpty {
            payload["stop"] = request.stopSequences
        }
        return try JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys])
    }

    /// Parse one SSE `data:` line's JSON payload and extract the
    /// delta string. Returns nil when:
    ///   - line is not a `data:` line (comment / empty)
    ///   - payload is the `[DONE]` sentinel
    ///   - JSON has no `choices[0].delta.content`
    public static func parseSSEDataLine(
        _ line: String
    ) -> String? {
        let trimmed = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed
            .dropFirst("data:".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization
                  .jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String
        else {
            return nil
        }
        return content
    }

    /// Returns true iff the SSE line is the OpenAI terminator.
    public static func isSSEDoneLine(_ line: String) -> Bool {
        let trimmed = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "data: [DONE]"
            || trimmed == "data:[DONE]"
    }

    // MARK: - Request-local lossless SSE pull

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    private nonisolated func makeSSEPull(request: BASOrganRequest) throws -> ChatSSEPull {
        let body = try Self.buildStreamingRequestBody(
            for: request, model: streamingEndpoint.model)

        var urlRequest = URLRequest(url: streamingEndpoint.url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(
            "text/event-stream",
            forHTTPHeaderField: "Accept")
        for (k, v) in streamingEndpoint.headers {
            urlRequest.setValue(v, forHTTPHeaderField: k)
        }
        urlRequest.httpBody = body

        let response = try BoundedChatResponse(session: streamingURLSession, request: urlRequest,
            cap: streamingMaxResponseBytes, deadline: request.deadline, streaming: true)
        return ChatSSEPull(response: response, request: request, providerID: descriptor.providerID,
                           cap: streamingMaxResponseBytes)
    }
}

/// AsyncIteratorProtocol requires serial next() calls. The unfolding stream owns
/// this state; its last release drops the independent response owner and cancels
/// unfinished receipt, even when no next() call is pending.
private final class ChatSSEPull: @unchecked Sendable {
    private let response: BoundedChatResponse
    private var lines: AsyncLineSequence<BoundedChatResponse.Bytes>.AsyncIterator
    private let request: BASOrganRequest
    private let providerID: String
    private let cap: Int
    private var cumulative = ""
    private var cumulativeBytes = 0
    private var ended = false

    init(response: BoundedChatResponse, request: BASOrganRequest, providerID: String, cap: Int) {
        self.response = response; self.request = request; self.providerID = providerID; self.cap = cap
        lines = response.bytes.lines.makeAsyncIterator()
    }

    func next() async throws -> BASOrganDraftChunk? {
        if ended { return nil }
        return try await withTaskCancellationHandler {
            do {
                try Task.checkCancellation()
                try response.check()
                while let line = try await lines.next() {
                    try response.check()
                    if BASChatCompletionsOrganAdapter.isSSEDoneLine(line) {
                        try response.finish(); ended = true; return nil
                    }
                    guard let delta = BASChatCompletionsOrganAdapter.parseSSEDataLine(line), !delta.isEmpty else { continue }
                    let deltaBytes = delta.utf8.count
                    guard deltaBytes <= cap - cumulativeBytes else {
                        throw BASOrganError.providerUnavailable(reason: "response-too-large:stream>\(cap)")
                    }
                    cumulative += delta; cumulativeBytes += deltaBytes
                    try Task.checkCancellation()
                    try response.check()
                    return BASOrganDraftChunk(requestID: request.requestID, providerID: providerID,
                        role: request.role, bodyDelta: delta, cumulativeBody: cumulative, producedAt: Date())
                }
                try response.finish(); ended = true; return nil
            } catch {
                ended = true; response.cancel(); throw error
            }
        } onCancel: { self.response.cancel() }
    }
}

/// M210 — package-internal accessors so the streaming extension
/// (a nonisolated extension that can't read actor-isolated
/// state) can reach the adapter's endpoint + url session.
extension BASChatCompletionsOrganAdapter {
    /// Endpoint copy reachable from nonisolated context — safe
    /// because `Endpoint` is a Sendable value type.
    package nonisolated var streamingEndpoint: Endpoint {
        nonisolatedEndpoint
    }

    /// URLSession reachable from nonisolated context — URLSession
    /// is Sendable in modern toolchains.
    package nonisolated var streamingURLSession: URLSession {
        nonisolatedURLSession
    }

    /// Response-body ceiling reachable from the nonisolated SSE pump.
    package nonisolated var streamingMaxResponseBytes: Int {
        nonisolatedMaxResponseBytes
    }
}
