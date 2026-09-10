import Foundation

/// M184 — streaming refinement of `BASOrganAdapter`.
///
/// ## Why a separate protocol
///
/// The base `BASOrganAdapter.draft(_:)` returns a complete
/// `BASOrganDraft` after the model has finished. Some providers
/// (Apple FoundationModels, remote LLMs) can yield incremental
/// chunks as the response generates. Streaming changes the contract
/// (caller iterates an async sequence instead of awaiting once), so
/// it lives in a refinement protocol that adapters opt into.
///
/// Adapters that don't conform to this protocol simply don't show up
/// when the loop probes `as? BASStreamingOrganAdapter`. Hosts that
/// want streaming and only have a non-streaming provider have to
/// fall back to `draft(_:)`.
///
/// ## Cumulative vs. delta semantics
///
/// `BASOrganDraftChunk` carries BOTH the cumulative body produced so
/// far AND the delta since the last chunk. Cumulative is what most
/// hosts render directly (just overwrite the rendered text). Delta
/// is what hosts that want token-stream semantics (TTY-style) use.
/// The adapter is responsible for computing the delta — providers
/// that natively yield deltas (rare) just thread them through;
/// providers that natively yield cumulative text (Apple
/// FoundationModels) compute the delta as the diff.
///
/// ## Stream termination
///
/// `AsyncThrowingStream` termination is the end-of-response signal.
/// No `isFinal` marker is needed — the consumer loops with
/// `for try await chunk in stream { ... }` and exits when the
/// generator finishes. Errors propagate via `throws` from the loop.
public protocol BASStreamingOrganAdapter: BASOrganAdapter {
    /// Produce an incremental draft for the given request. Each
    /// element of the returned stream is a `BASOrganDraftChunk` that
    /// carries the cumulative body so far + the delta since the
    /// previous chunk. Stream completion (no more elements) signals
    /// end-of-response.
    ///
    /// Errors are surfaced as the stream's terminal failure — same
    /// taxonomy as `BASOrganError` from the non-streaming path.
    func streamDraft(
        _ request: BASOrganRequest
    ) -> AsyncThrowingStream<BASOrganDraftChunk, Error>
}

/// One incremental piece of a streamed draft.
///
/// `cumulativeBody` is the full text generated up to this chunk
/// (inclusive). `bodyDelta` is `cumulativeBody` minus the previous
/// chunk's `cumulativeBody` — i.e. just the text added in this step.
/// On the first chunk, `bodyDelta == cumulativeBody`.
///
/// `producedAt` is the wall-clock time at which the chunk was
/// emitted, useful for measuring time-to-first-token and inter-chunk
/// gap statistics.
public struct BASOrganDraftChunk: Sendable, Equatable, Codable {
    public let requestID: String
    public let providerID: String
    public let role: BASOrganRole
    public let bodyDelta: String
    public let cumulativeBody: String
    public let producedAt: Date

    public init(
        requestID: String,
        providerID: String,
        role: BASOrganRole,
        bodyDelta: String,
        cumulativeBody: String,
        producedAt: Date
    ) {
        self.requestID = requestID
        self.providerID = providerID
        self.role = role
        self.bodyDelta = bodyDelta
        self.cumulativeBody = cumulativeBody
        self.producedAt = producedAt
    }
}
