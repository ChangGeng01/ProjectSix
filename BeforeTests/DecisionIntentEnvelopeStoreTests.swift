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
