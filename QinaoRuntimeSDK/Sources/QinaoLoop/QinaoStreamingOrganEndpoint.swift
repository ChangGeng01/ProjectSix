import Foundation

/// M188 — Qinao-level streaming refinement.
///
/// ## Why this exists
///
/// M184 added `BASStreamingOrganAdapter` at the substrate layer so
/// hosts could drive `LanguageModelSession.streamResponse(to:options:)`
/// directly. That works for hosts that already speak the substrate
/// dialect, but the Qinao public API surface stayed
/// non-streaming — `QinaoLoop.generateCandidates(...)` returns the
/// fully-formed body in one await. Hosts wanting TTY-style append
/// UIs had no public on-ramp.
///
/// `QinaoStreamingOrganEndpoint` is the public refinement of
/// `QinaoOrganEndpoint` that endpoints conform to when they can
/// yield incremental chunks. `QinaoLoop.streamBody(...)` (added
/// alongside) is the host-facing entry point.
///
/// ## Stream-vs-frontier separation
///
/// `QinaoLoop.streamBody(...)` is INTENTIONALLY a separate code path
/// from `generateCandidates(...)`. The frontier scoring formula
/// requires the full body + numeric host-supplied fields, neither
/// of which is available mid-stream. Hosts that want streaming for
/// UI render BUT also want the candidate to land in the frontier
/// can:
///   1. `streamBody(...)` for UI append rendering
///   2. After the stream finishes, call `generateCandidates(...)`
///      with the same prompt to get the frontier-scored, audited
///      version
/// or just call `generateCandidates(...)` if streaming UI isn't
/// needed.
public protocol QinaoStreamingOrganEndpoint: QinaoOrganEndpoint {

    /// Produce an incremental draft body for the given prompt.
    /// Each element is a `QinaoLoop.OrganResponseChunk` carrying
    /// `cumulativeBody` (full text so far) + `bodyDelta` (text
    /// added since previous chunk) + `providerID`.
    ///
    /// Stream completion (no more elements) signals end-of-response.
    /// Errors propagate via the stream's terminal failure with the
    /// same `LoopError.organUnavailable(reason:)` reason-code
    /// grammar as the non-streaming path.
    func streamBody(
        prompt: String,
        context: [String],
        role: QinaoLoop.OrganRole,
        sessionID: String
    ) -> AsyncThrowingStream<
        QinaoLoop.OrganResponseChunk, Error>
}

extension QinaoLoop {

    /// One incremental chunk of a streamed body. Hosts that render
    /// progressive output overwrite the rendered text with each
    /// `cumulativeBody`; hosts that want token-level append iterate
    /// `bodyDelta`s. `providerID` is stable across all chunks of a
    /// single request — same value as the non-streaming
    /// `OrganResponse.providerID`.
    ///
    /// `traceID` is intentionally absent — provenance recovery
    /// requires the final body, which is only known when the
    /// stream completes. Hosts that need a stable trace handle
    /// should call `generateCandidates(...)` for the final/canonical
    /// version after streaming for UI concludes.
    public struct OrganResponseChunk: Sendable, Equatable {
        public let bodyDelta: String
        public let cumulativeBody: String
        public let providerID: String

        public init(
            bodyDelta: String,
            cumulativeBody: String,
            providerID: String
        ) {
            self.bodyDelta = bodyDelta
            self.cumulativeBody = cumulativeBody
            self.providerID = providerID
        }
    }
}
