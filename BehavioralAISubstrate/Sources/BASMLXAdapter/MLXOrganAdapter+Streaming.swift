import Foundation
import BASRuntimeCore
import BASOrgan
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// M221 — streaming refinement of `MLXOrganAdapter`.
///
/// Mirrors `AppleFoundationOrganAdapter+Streaming.swift`:
/// `streamDraft(_:)` delegates to `ChatSession.streamResponse(to:)`
/// and translates each delta into a `BASOrganDraftChunk` with both
/// `bodyDelta` (just-emitted) and `cumulativeBody` (full text so
/// far) so UI append-rendering and final-body audits both work off
/// the same stream.
///
/// Errors from the underlying ChatSession (model-not-loaded,
/// unsupported role, OS-version unavailability) are propagated
/// through the stream's terminal failure — callers `for try await`
/// loop sees them as a thrown error, identical taxonomy to the
/// non-streaming `draft(_:)` path.
extension MLXOrganAdapter: BASStreamingOrganAdapter {

    public nonisolated func streamDraft(
        _ request: BASOrganRequest
    ) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }
                do {
                    try await self._streamDraft(
                        request,
                        continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Actor-isolated body of the stream task.
    fileprivate func _streamDraft(
        _ request: BASOrganRequest,
        continuation: AsyncThrowingStream<
            BASOrganDraftChunk, Error>.Continuation
    ) async throws {
        guard descriptor.supportedRoles.contains(request.role) else {
            throw BASOrganError.unsupportedRole(request.role)
        }

        #if canImport(MLXLLM)
        // 结构大重构 — route to the speculative decoder when a draft model is loaded AND the mode is live.
        // Default off (no draft / `.off`) ⇒ this guard is skipped ⇒ the exact pre-speculative single-model path
        // below runs, byte-identical. Deleting these three lines fully reverts the feature.
        if shouldSpeculate(for: request) {
            try await _streamDraftSpeculative(request, continuation: continuation)
            return
        }
        guard let container = self._loadedContainerForStreaming()
        else {
            throw BASOrganError.providerUnavailable(
                reason: MLXOrganAdapter.notLoadedReason(
                    "loadModel(progressHandler:) before streamDraft(_:)"))
        }

        let session = ChatSession(
            container,
            instructions: Self.systemInstructions(for: request),
            generateParameters: self._generateParameters(
                for: request.preset,
                maxOutputTokens: request.maxOutputTokens))

        let prompt = Self.prompt(for: request)
        var cumulative = ""

        for try await delta in session.streamResponse(to: prompt) {
            cumulative += delta
            // M256 — `bodyDelta` stays raw (so concatenation by
            // downstream consumers stays consistent), but
            // `cumulativeBody` is post-processed so any
            // `[NEEDS_VERIFICATION]` substring becomes
            // `[NEEDS_PERMIT]` — same gate-recognition guarantee
            // as non-streaming `draft(_:)`. Consumers that scan
            // `cumulativeBody` for markers (the recommended path,
            // per `BASOrganDraftChunk` docs) see the corrected
            // tokens.
            let chunk = BASOrganDraftChunk(
                requestID: request.requestID,
                providerID: descriptor.providerID,
                role: request.role,
                bodyDelta: delta,
                cumulativeBody:
                    MLXOrganAdapter.applyMarkerPostprocessing(
                        cumulative),
                producedAt: Date())
            continuation.yield(chunk)
        }
        #else
        throw BASOrganError.providerUnavailable(
            reason: MLXOrganAdapter.frameworkUnavailableReason
                + MLXOrganAdapter.frameworkUnavailablePlatformSuffix)
        #endif
    }
}
