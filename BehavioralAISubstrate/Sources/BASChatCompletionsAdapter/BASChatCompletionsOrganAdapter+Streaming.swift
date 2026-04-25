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
/// 2. Reads `URLSession.AsyncBytes` line-by-line.
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
/// ## Error mapping (same as non-streaming)
///
/// HTTP non-2xx, malformed JSON, transport throws — all surfaced
/// via the stream's terminal failure with the same stable
/// reason-code grammar (`http-NNN`, `malformed-json`,
/// `transport:<msg>`).
extension BASChatCompletionsOrganAdapter: BASStreamingOrganAdapter {

    public nonisolated func streamDraft(
        _ request: BASOrganRequest
    ) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard
                    descriptor.supportedRoles.contains(request.role)
                else {
                    continuation.finish(
                        throwing: BASOrganError
                            .unsupportedRole(request.role))
                    return
                }
                if let deadline = request.deadline,
                   deadline < Date()
                {
                    continuation.finish(
                        throwing: BASOrganError.deadlineExpired)
                    return
                }
                do {
                    try await self.streamViaSSE(
                        request: request,
                        continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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

    // MARK: - Private SSE pump

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    private nonisolated func streamViaSSE(
        request: BASOrganRequest,
        continuation: AsyncThrowingStream<
            BASOrganDraftChunk, Error>.Continuation
    ) async throws {
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

        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await streamingURLSession
                .bytes(for: urlRequest)
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

        var cumulative = ""
        for try await line in bytes.lines {
            if Self.isSSEDoneLine(line) { return }
            guard let delta = Self.parseSSEDataLine(line) else {
                continue
            }
            if delta.isEmpty { continue }
            cumulative += delta
            continuation.yield(
                BASOrganDraftChunk(
                    requestID: request.requestID,
                    providerID: descriptor.providerID,
                    role: request.role,
                    bodyDelta: delta,
                    cumulativeBody: cumulative,
                    producedAt: Date()))
        }
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
}
