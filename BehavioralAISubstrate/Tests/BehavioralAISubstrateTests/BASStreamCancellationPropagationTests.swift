import XCTest
@testable import BASHostKit
import BASOrgan

/// audit H18 — teeth for the streamDraft cancellation-leak fix.
///
/// The bug class: a streaming decorator that wraps its producer in an unstructured
/// `Task { ... }` without `continuation.onTermination = { task.cancel() }` leaks that
/// task when the consumer drops the stream. Cancelling the *consumer* only exits the
/// consumer's `for await`; the producer keeps pumping the inner stream to completion.
///
/// This test drives the fixed `BASCountingOrganAdapter` decorator with an inner that
/// pumps until cancelled. The consumer reads ONE chunk then drops the stream. With the
/// H18 fix the decorator's producer task is cancelled on termination, which propagates
/// down to the inner pump (its own `for try await` throws `CancellationError`). Without
/// the fix the decorator's producer stays alive, keeps pulling the inner stream, and the
/// pump runs to its safety cap — `endedByCancel` never flips and the test fails.
///
/// Fully deterministic + Mac-runnable: no model, no wall-clock timing assertions beyond a
/// generous propagation budget. This is the on-Mac counterpart to
/// `AppleFoundationStreamCancellationTests` (which skips without FoundationModels).
final class BASStreamCancellationPropagationTests: XCTestCase {

    /// Observable shared state for the pump — an actor so the producer task and the test
    /// assertion don't race.
    private actor PumpSignal {
        private(set) var endedByCancel = false
        private(set) var yielded = 0
        func markYield() { yielded += 1 }
        func markCancelled() { endedByCancel = true }
    }

    /// A well-behaved streaming provider that pumps chunks until its task is cancelled
    /// (cooperative cancellation, like the real MLX / Apple FM adapters). The safety cap
    /// bounds a regression so a leaked producer terminates the test instead of hanging.
    private final class ForeverPumpInner: BASOrganAdapter, BASStreamingOrganAdapter, @unchecked Sendable {
        static let safetyCap = 50_000
        let signal: PumpSignal
        init(_ signal: PumpSignal) { self.signal = signal }

        var descriptor: BASOrganDescriptor {
            BASOrganDescriptor(providerID: "pump", providerName: "pump", supportsStreaming: true,
                               maxInputTokens: 4096, maxOutputTokens: 256, runsOnDevice: true,
                               supportedRoles: [.core])
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            BASOrganDraft(requestID: request.requestID, providerID: "pump", role: request.role,
                          body: "", inputTokensEstimated: 0, outputTokensEstimated: 0,
                          producedAt: Date(timeIntervalSince1970: 0), traceID: "t")
        }
        func streamDraft(_ request: BASOrganRequest) -> AsyncThrowingStream<BASOrganDraftChunk, Error> {
            AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        var i = 0
                        while i < Self.safetyCap {
                            try Task.checkCancellation()
                            continuation.yield(BASOrganDraftChunk(
                                requestID: request.requestID, providerID: "pump", role: request.role,
                                bodyDelta: "x", cumulativeBody: "x",
                                producedAt: Date(timeIntervalSince1970: 0)))
                            await self.signal.markYield()
                            await Task.yield()
                            i += 1
                        }
                        continuation.finish()   // reached cap WITHOUT cancel → the leak (regression path)
                    } catch {
                        await self.signal.markCancelled()
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { @Sendable _ in task.cancel() }
            }
        }
    }

    private func req(_ s: String) -> BASOrganRequest {
        BASOrganRequest(requestID: "r", role: .core, preset: .core, instruction: s, context: [])
    }

    /// Consume exactly one chunk then let the stream (and its iterator) go out of scope,
    /// which fires the decorator's `onTermination`.
    private func consumeOne(_ s: AsyncThrowingStream<BASOrganDraftChunk, Error>) async throws {
        for try await _ in s { break }
    }

    func testConsumerCancelPropagatesThroughCountingDecorator() async throws {
        let signal = PumpSignal()
        let counter = BASLLMCallCounter()
        let dec = BASCountingOrganAdapter(wrapping: ForeverPumpInner(signal), counter: counter)

        // Read one chunk, then drop the stream. The whole chain must cancel:
        // decorator producer (H18 fix) → inner pump.
        try await consumeOne(dec.streamDraft(req("hi")))

        // Await the inner pump's cancel-observed flag within a generous 5s propagation budget.
        var ended = false
        for _ in 0..<50 {
            if await signal.endedByCancel { ended = true; break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(ended,
            "consumer cancel must propagate through BASCountingOrganAdapter to the inner pump (H18)")
        let yielded = await signal.yielded
        XCTAssertLessThan(yielded, ForeverPumpInner.safetyCap,
            "pump stopped well before the safety cap — cancellation landed early")
    }
}
