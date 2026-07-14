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
///
/// ## Cancellation (M192)
///
/// Apple's `LanguageModelSession.streamResponse(to:)` honors the
/// cooperative task-cancellation protocol. When the iterating Task
/// is cancelled, the underlying stream stops producing chunks and
/// the for-await loop exits cleanly (typically without throwing).
/// Empirically the model bails BEFORE producing the first chunk if
/// cancellation lands quickly enough — total latency from
/// `task.cancel()` to iteration exit is sub-millisecond beyond the
/// scheduling tick.
///
/// Hosts that want to abort a long-running stream just cancel the
/// enclosing task; no manual `break` or special signaling needed.
/// Pinned by `AppleFoundationStreamCancellationTests` —
/// `testCancellingStreamingTaskTerminatesWithinBudget` asserts a
/// 5-second exit budget (real measured: ~150ms after the
/// cancellation signal lands).
extension AppleFoundationOrganAdapter: BASStreamingOrganAdapter {

    public nonisolated func streamDraft(
        _ request: BASOrganRequest
    ) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
        AsyncThrowingStream { continuation in
            // audit H18: cancel the PRODUCER task on stream termination. The docstring above says
            // "just cancel the enclosing task" — but cancelling the CONSUMER task only exits the
            // consumer's for-await; the producer Task here is unstructured, so without
            // onTermination it kept pumping FoundationModels to completion. This makes the
            // documented cancellation actually true on the producer side too.
            let task = Task {
                guard
                    descriptor.supportedRoles.contains(request.role)
                else {
                    continuation.finish(
                        throwing: BASOrganError
                            .unsupportedRole(request.role))
                    return
                }

                #if canImport(FoundationModels)
                if #available(iOS 27, macOS 27, visionOS 27, *) {
                    do {
                        try await self.streamViaFoundation(
                            request: request,
                            continuation: continuation)
                        continuation.finish()
                    } catch is CancellationError {
                        // Never mapped: the endpoint cancels this pump when the consumer
                        // breaks. Mapping it would let a router re-run the whole
                        // generation after the caller already walked away.
                        continuation.finish(throwing: CancellationError())
                    } catch let afm as LanguageModelError {
                        // Same contract as draft(): `session.streamResponse` throws the
                        // identical raw set, so leaving this arm untranslated would make
                        // the draft-path mapping a half-truth. organError(for:) returns nil
                        // for the SAFETY-REFUSAL class, which is finished RAW so no router
                        // can launder it onto a second model.
                        continuation.finish(
                            throwing: AppleFoundationOrganAdapter.organError(for: afm) ?? afm)
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
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 27, macOS 27, visionOS 27, *)
    private nonisolated func streamViaFoundation(
        request: BASOrganRequest,
        continuation: AsyncThrowingStream<
            BASOrganDraftChunk, Error>.Continuation
    ) async throws {
        let session = LanguageModelSession(
            instructions: instructions(for: request))
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
