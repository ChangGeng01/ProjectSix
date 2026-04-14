import XCTest
@testable import Before

final class DecisionIntentEnvelopeStoreTests: XCTestCase {
    private let key = "before.intent.envelopes"

    override func tearDown() {
        DecisionIntentEnvelopeStore.clear()
        SharedProtectedStateStore.clearQuarantine(key: key)
        StateStorageIssueRecorder.clear()
        super.tearDown()
    }

    func testEnqueueAndConsumeRoundTripPreservesOrder() {
        let now = Date()
        let first = DecisionIntentEnvelope(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            kind: .quickCapture,
            sourceSurface: .watch,
            entrySource: .watch,
            preferredMode: .quick,
            promptSeed: "Pause this purchase",
            requestedAt: now,
            expiresAt: now.addingTimeInterval(600)
        )
        let second = DecisionIntentEnvelope(
            id: UUID(uuidString: "FFFFFFFF-1111-2222-3333-444444444444")!,
            kind: .predictiveIntervention,
            sourceSurface: .notification,
            entrySource: .app,
            preferredMode: .mirror,
            promptSeed: "Do not send this tonight",
            riskLevel: .high,
            requestedAt: now.addingTimeInterval(10),
            expiresAt: now.addingTimeInterval(900)
        )

        DecisionIntentEnvelopeStore.enqueue(first)
        DecisionIntentEnvelopeStore.enqueue(second)

        XCTAssertNotNil(SharedProtectedStateStore.loadData(key: key))
        XCTAssertEqual(DecisionIntentEnvelopeStore.consume(now: now)?.id, first.id)
        XCTAssertEqual(DecisionIntentEnvelopeStore.consume(now: now)?.id, second.id)
        XCTAssertNil(DecisionIntentEnvelopeStore.consume(now: now))
        XCTAssertNil(SharedProtectedStateStore.loadData(key: key))
    }

    func testLoadQueueDropsExpiredEnvelopesAndRewritesValidState() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let expired = DecisionIntentEnvelope(
            kind: .quickCapture,
            sourceSurface: .watch,
            entrySource: .watch,
            promptSeed: "Expired",
            requestedAt: now.addingTimeInterval(-600),
            expiresAt: now.addingTimeInterval(-10)
        )
        let valid = DecisionIntentEnvelope(
            kind: .openMode,
            sourceSurface: .shortcut,
            entrySource: .shortcut,
            preferredMode: .balance,
            promptSeed: "Still valid",
            requestedAt: now
        )

        XCTAssertTrue(
            SharedProtectedStateStore.saveData(try JSONEncoder().encode([expired, valid]), key: key)
        )

        let queue = DecisionIntentEnvelopeStore.loadQueue(now: now)

        XCTAssertEqual(queue, [valid])
        let persisted = SharedProtectedStateStore.load([DecisionIntentEnvelope].self, key: key)
        XCTAssertEqual(persisted, [valid])
    }

    func testEnqueueReplacesExistingEnvelopeWithSameID() {
        let id = UUID(uuidString: "12345678-1234-1234-1234-1234567890AB")!
        let original = DecisionIntentEnvelope(
            id: id,
            kind: .quickCapture,
            sourceSurface: .app,
            entrySource: .app,
            preferredMode: .quick,
            promptSeed: "old"
        )
        let replacement = DecisionIntentEnvelope(
            id: id,
            kind: .resumeCurrentDecision,
            sourceSurface: .notification,
            entrySource: .app,
            preferredMode: .mirror,
            promptSeed: "new"
        )

        DecisionIntentEnvelopeStore.enqueue(original)
        DecisionIntentEnvelopeStore.enqueue(replacement)

        let queue = DecisionIntentEnvelopeStore.loadQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.kind, .resumeCurrentDecision)
        XCTAssertEqual(queue.first?.preferredMode, .mirror)
        XCTAssertEqual(queue.first?.promptSeed, "new")
    }

    func testWatchEvolutionControlHandoffRoundTripsThroughIntentQueue() {
        let now = Date(timeIntervalSince1970: 4_000)

        WatchHandoffCoordinator.enqueueOpenEvolutionControl(
            headline: "Review the pending queue",
            reason: "Watch glance requested iPhone review."
        )

        let next = DecisionIntentEnvelopeStore.consume(now: now)

        XCTAssertEqual(next?.kind, .openEvolutionControl)
        XCTAssertEqual(next?.sourceSurface, .watch)
        XCTAssertEqual(next?.entrySource, .watch)
        XCTAssertEqual(next?.preferredMode, .mirror)
        XCTAssertEqual(next?.promptSeed, "Review the pending queue")
        XCTAssertEqual(next?.triggerReason, "Watch glance requested iPhone review.")
    }

    func testWidgetEvolutionControlIntentQueuesWidgetScopedReviewRequest() async throws {
        let intent = OpenEvolutionControlIntent(
            entrySource: .homeWidgetMedium,
            prompt: "Review the guarded queue"
        )

        _ = try await intent.perform()

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .openEvolutionControl)
        XCTAssertEqual(next?.sourceSurface, .widget)
        XCTAssertEqual(next?.entrySource, .homeWidgetMedium)
        XCTAssertEqual(next?.preferredMode, .mirror)
        XCTAssertEqual(next?.promptSeed, "Review the guarded queue")
        XCTAssertEqual(next?.riskLevel, .medium)
    }

    func testEnqueueKeepsNewestFiveEnvelopesWhenQueueOverflows() {
        let now = Date()

        for offset in 0..<7 {
            DecisionIntentEnvelopeStore.enqueue(
                makeEnvelope(
                    id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", offset + 1))!,
                    promptSeed: "prompt-\(offset)",
                    requestedAt: now.addingTimeInterval(Double(offset)),
                    expiresAt: now.addingTimeInterval(3_600 + Double(offset))
                )
            )
        }

        let queue = DecisionIntentEnvelopeStore.loadQueue(now: now)

        XCTAssertEqual(queue.count, BeforePolicy.LaunchRequests.maxQueuedRequests)
        XCTAssertEqual(queue.map(\.promptSeed), ["prompt-2", "prompt-3", "prompt-4", "prompt-5", "prompt-6"])
    }

    func testConsumeClearsBackingStoreWhenOnlyExpiredEnvelopesRemain() {
        let now = Date(timeIntervalSince1970: 20_000)
        let expired = makeEnvelope(
            promptSeed: "expired",
            requestedAt: now.addingTimeInterval(-600),
            expiresAt: now.addingTimeInterval(-1)
        )

        DecisionIntentEnvelopeStore.enqueue(expired)

        XCTAssertNil(DecisionIntentEnvelopeStore.consume(now: now))
        XCTAssertNil(SharedProtectedStateStore.loadData(key: key))
    }

    func testRepeatedOverflowAcrossMultipleBatchesKeepsOnlyNewestFreshEnvelopes() {
        let now = Date()

        for offset in 0..<5 {
            DecisionIntentEnvelopeStore.enqueue(
                makeEnvelope(
                    id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", offset + 1))!,
                    promptSeed: "batch-a-\(offset)",
                    requestedAt: now.addingTimeInterval(Double(offset)),
                    expiresAt: now.addingTimeInterval(3_600 + Double(offset))
                )
            )
        }
        for offset in 0..<5 {
            DecisionIntentEnvelopeStore.enqueue(
                makeEnvelope(
                    id: UUID(uuidString: String(format: "20000000-0000-0000-0000-%012d", offset + 1))!,
                    promptSeed: "batch-b-\(offset)",
                    requestedAt: now.addingTimeInterval(100 + Double(offset)),
                    expiresAt: now.addingTimeInterval(7_200 + Double(offset))
                )
            )
        }

        let queue = DecisionIntentEnvelopeStore.loadQueue(now: now)

        XCTAssertEqual(queue.count, BeforePolicy.LaunchRequests.maxQueuedRequests)
        XCTAssertEqual(queue.map(\.promptSeed), [
            "batch-b-0",
            "batch-b-1",
            "batch-b-2",
            "batch-b-3",
            "batch-b-4"
        ])
    }

    func testRepeatedLoadAndConsumeNeverResurrectsExpiredOrConsumedEnvelopes() {
        let now = Date(timeIntervalSince1970: 30_000)
        let expired = makeEnvelope(
            promptSeed: "expired",
            requestedAt: now.addingTimeInterval(-500),
            expiresAt: now.addingTimeInterval(-5)
        )
        let fresh = (0..<3).map { offset in
            makeEnvelope(
                id: UUID(uuidString: String(format: "30000000-0000-0000-0000-%012d", offset + 1))!,
                promptSeed: "fresh-\(offset)",
                requestedAt: now.addingTimeInterval(Double(offset)),
                expiresAt: now.addingTimeInterval(600 + Double(offset))
            )
        }

        XCTAssertTrue(
            SharedProtectedStateStore.saveData(try! JSONEncoder().encode([expired] + fresh), key: key)
        )

        var consumed: [UUID] = []
        for _ in 0..<5 {
            _ = DecisionIntentEnvelopeStore.loadQueue(now: now)
            if let next = DecisionIntentEnvelopeStore.consume(now: now) {
                consumed.append(next.id)
            }
        }

        XCTAssertEqual(consumed, fresh.map(\.id))
        XCTAssertEqual(Set(consumed).count, fresh.count)
        XCTAssertNil(DecisionIntentEnvelopeStore.consume(now: now))
        XCTAssertNil(SharedProtectedStateStore.loadData(key: key))
    }

    private func makeEnvelope(
        id: UUID = UUID(),
        promptSeed: String,
        requestedAt: Date,
        expiresAt: Date? = nil
    ) -> DecisionIntentEnvelope {
        DecisionIntentEnvelope(
            id: id,
            kind: .quickCapture,
            sourceSurface: .watch,
            entrySource: .watch,
            preferredMode: .quick,
            promptSeed: promptSeed,
            requestedAt: requestedAt,
            expiresAt: expiresAt ?? requestedAt.addingTimeInterval(600)
        )
    }
}
