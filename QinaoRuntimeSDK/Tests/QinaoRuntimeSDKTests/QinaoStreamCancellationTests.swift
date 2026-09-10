import XCTest
@testable import QinaoLoop

/// audit F9 (2026-07-12) — cancelling the outer stream must propagate down to the producer.
///
/// Pre-fix, QinaoLoop.streamBody spawned a handle-less Task with no continuation.onTermination,
/// so a consumer break never cancelled the inner (model) stream — the GPU decode ran to
/// completion unwatched. The fix captures the task and wires onTermination; this proves the
/// inner producer's own termination fires when the outer consumer breaks early.
final class QinaoStreamCancellationTests: XCTestCase {

    /// Records whether the inner (model) stream saw its onTermination fire.
    actor Flag {
        private(set) var innerTerminated = false
        func markTerminated() { innerTerminated = true }
    }

    /// A streaming endpoint whose inner stream yields chunks slowly and, crucially, records
    /// via onTermination whether it was torn down (the signal a real GPU pump would use to
    /// stop decoding).
    struct SlowSpyEndpoint: QinaoStreamingOrganEndpoint {
        let flag: Flag

        func produceBody(prompt: String, context: [String],
                         role: QinaoLoop.OrganRole, sessionID: String)
            async throws -> QinaoLoop.OrganResponse {
            QinaoLoop.OrganResponse(body: "x", providerID: "spy", traceID: "t")
        }

        func streamBody(prompt: String, context: [String],
                        role: QinaoLoop.OrganRole, sessionID: String)
            -> AsyncThrowingStream<QinaoLoop.OrganResponseChunk, Error> {
            let flag = self.flag
            return AsyncThrowingStream { continuation in
                let task = Task {
                    var i = 0
                    while !Task.isCancelled && i < 10_000 {
                        continuation.yield(QinaoLoop.OrganResponseChunk(
                            bodyDelta: "d", cumulativeBody: String(repeating: "d", count: i + 1),
                            providerID: "spy"))
                        i += 1
                        try? await Task.sleep(nanoseconds: 2_000_000)  // 2ms per chunk
                    }
                    continuation.finish()
                }
                continuation.onTermination = { @Sendable _ in
                    task.cancel()
                    Task { await flag.markTerminated() }
                }
            }
        }
    }

    func testConsumerCancelPropagatesToProducer() async throws {
        let flag = Flag()
        let loop = QinaoLoop(organEndpoint: SlowSpyEndpoint(flag: flag))

        // A consumer task that iterates the outer stream. Cancelling it drops the stream's
        // iterator → the outer AsyncThrowingStream deinits → its onTermination fires →
        // (fix) task.cancel() → the inner producer's onTermination fires.
        let firstChunk = XCTestExpectation(description: "got first chunk")
        let consumer = Task {
            let stream = loop.streamBody(sessionID: "cancel-1", prompt: "go")
            var got = 0
            for try await _ in stream {
                got += 1
                if got == 1 { firstChunk.fulfill() }
            }
        }
        await fulfillment(of: [firstChunk], timeout: 5.0)
        consumer.cancel()

        // Give the termination cascade a moment to unwind through both stream layers.
        try await Task.sleep(nanoseconds: 300_000_000)  // 300ms
        let terminated = await flag.innerTerminated
        XCTAssertTrue(terminated,
            "the inner (model) producer must be torn down when the consumer is cancelled — "
            + "without the outer onTermination the producer runs on unwatched (F9)")
    }
}
