import Foundation
import BASOrgan
#if canImport(FoundationModels)
import FoundationModels
#endif

/// M184 — Apple FoundationModels streaming conformance for
/// `AppleFoundationOrganAdapter`.
///
/// Apple's `LanguageModelSession.streamResponse(to:options:)` yields
/// `Snapshot` values whose `.content` is the *cumulative* text
/// generated so far (NOT a token-level delta). This extension wraps
/// that stream in our `BASOrganDraftChunk` shape, computing the
/// delta as the suffix added since the previous chunk.
///
/// ## Behavior on unsupported OS / unavailable framework
///
/// Same as the non-streaming path: stream terminates with
/// `BASOrganError.providerUnavailable(reason:)`. Hosts that need
/// to gracefully degrade should `as? BASStreamingOrganAdapter`
/// first; if absent, fall back to `draft(_:)`.
extension AppleFoundationOrganAdapter: BASStreamingOrganAdapter {

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

                #if canImport(FoundationModels)
                if #available(iOS 26, macOS 26, visionOS 26, *) {
                    do {
                        try await self.streamViaFoundation(
                            request: request,
                            continuation: continuation)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                    return
                }
                continuation.finish(
                    throwing: BASOrganError.providerUnavailable(
                        reason:
                            "FoundationModels streaming requires " +
                            "iOS 26+ / macOS 26+ / visionOS 26+"))
                #else
                continuation.finish(
                    throwing: BASOrganError.providerUnavailable(
                        reason:
                            "FoundationModels framework " +
                            "unavailable in this build"))
                #endif
            }
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26, macOS 26, visionOS 26, *)
    private nonisolated func streamViaFoundation(
        request: BASOrganRequest,
        continuation: AsyncThrowingStream<
            BASOrganDraftChunk, Error>.Continuation
    ) async throws {
        let session = LanguageModelSession(
            instructions: Self.systemInstructions(for: request))
        let options = GenerationOptions(
            temperature: request.preset.temperature)
        let promptText = Self.prompt(for: request)
        let prompt = Prompt(promptText)
        let stream = session.streamResponse(
            to: prompt, options: options)

        var lastCumulative = ""
        for try await snapshot in stream {
            let cumulative = snapshot.content
            // Apple FM yields cumulative text. Compute delta as the
            // suffix added since the last snapshot. If a future
            // version of FoundationModels switches to delta-only
            // semantics, this code keeps producing valid (delta,
            // cumulative) pairs as long as cumulative ≥ lastCumulative
            // by character count; otherwise we'd need a code path
            // change.
            let delta: String
            if cumulative.hasPrefix(lastCumulative) {
                delta = String(
                    cumulative.dropFirst(lastCumulative.count))
            } else {
                // Defensive: cumulative is unexpectedly NOT a strict
                // extension of lastCumulative. Yield the whole thing
                // as the delta (rare; would mean FM rewrote part of
                // the prefix between snapshots).
                delta = cumulative
            }
            continuation.yield(
                BASOrganDraftChunk(
                    requestID: request.requestID,
                    providerID: descriptor.providerID,
                    role: request.role,
                    bodyDelta: delta,
                    cumulativeBody: cumulative,
                    producedAt: Date()))
            lastCumulative = cumulative
        }
    }
    #endif
}
