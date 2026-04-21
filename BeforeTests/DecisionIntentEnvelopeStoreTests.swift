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
        let first = DecisionIntentEnvelope
            .quickCapture(
                entrySource: .watch,
                promptSeed: "Pause this purchase",
                requestedAt: now,
                expiresAt: now.addingTimeInterval(600)
            )
            .withID(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!)
        let second = DecisionIntentEnvelope
            .predictiveIntervention(
                preferredMode: .mirror,
                promptSeed: "Do not send this tonight",
                riskLevel: .high,
                requestedAt: now.addingTimeInterval(10),
                expiresAt: now.addingTimeInterval(900)
            )
            .withID(UUID(uuidString: "FFFFFFFF-1111-2222-3333-444444444444")!)

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
        let expired = DecisionIntentEnvelope.quickCapture(
            entrySource: .watch,
            promptSeed: "Expired",
            requestedAt: now.addingTimeInterval(-600),
            expiresAt: now.addingTimeInterval(-10)
        )
        let valid = DecisionIntentEnvelope.openMode(
            entrySource: .shortcut,
            mode: .balance,
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
        let original = DecisionIntentEnvelope
            .quickCapture(entrySource: .app, promptSeed: "old")
            .withID(id)
        let replacement = DecisionIntentEnvelope
            .resumeCurrentDecision(
                sourceSurface: .notification,
                entrySource: .app,
                preferredMode: .mirror,
                promptSeed: "new"
            )
            .withID(id)

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
        let controlEntry = DecisionEvolutionWidgetControlEntryPresentation(
            title: "Review on iPhone",
            systemImage: "checklist",
            prompt: "Review the pending queue",
            instruction: "Continue on iPhone to review pending checkpoints and clear the queue.",
            triggerReason: "Watch glance requested iPhone review."
        )

        WatchHandoffCoordinator.enqueueOpenEvolutionControl(controlEntry)

        let next = DecisionIntentEnvelopeStore.consume(now: now)

        XCTAssertEqual(next?.kind, .openEvolutionControl)
        XCTAssertEqual(next?.sourceSurface, .watch)
        XCTAssertEqual(next?.entrySource, .watch)
        XCTAssertEqual(next?.preferredMode, .mirror)
        XCTAssertEqual(next?.promptSeed, "Review the pending queue")
        XCTAssertEqual(next?.triggerReason, "Watch glance requested iPhone review.")
    }

    func testQuickCheckIntentQueuesShortcutScopedQuickCapture() async throws {
        let intent = OpenQuickCheckIntent(
            entrySource: .shortcut,
            scenario: .other
        )

        _ = try await intent.perform()

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .quickCapture)
        XCTAssertEqual(next?.sourceSurface, .shortcut)
        XCTAssertEqual(next?.entrySource, .shortcut)
        XCTAssertEqual(next?.preferredMode, .quick)
        XCTAssertEqual(next?.scenario, .other)
        XCTAssertEqual(next?.riskLevel, .low)
        XCTAssertNil(next?.promptSeed)
    }

    func testOpenDecisionModeIntentTrimsPromptThroughSharedFactory() async throws {
        let intent = OpenDecisionModeIntent(
            mode: .mirror,
            prompt: "  Bring the real concern into view.  ",
            entrySource: .shortcut
        )

        _ = try await intent.perform()

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .openMode)
        XCTAssertEqual(next?.sourceSurface, .shortcut)
        XCTAssertEqual(next?.entrySource, .shortcut)
        XCTAssertEqual(next?.preferredMode, .mirror)
        XCTAssertEqual(next?.promptSeed, "Bring the real concern into view.")
        XCTAssertNil(next?.riskLevel)
    }

    func testWidgetEvolutionControlIntentQueuesWidgetScopedReviewRequest() async throws {
        let controlEntry = DecisionEvolutionWidgetControlEntryPresentation(
            title: "Review on iPhone",
            systemImage: "checklist",
            prompt: "Review the guarded queue",
            instruction: "Continue on iPhone to review pending checkpoints and clear the queue.",
            triggerReason: "Widget surfaced the guarded queue detail."
        )
        let intent = OpenEvolutionControlIntent(
            entrySource: .homeWidgetMedium,
            controlEntry: controlEntry
        )

        _ = try await intent.perform()

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .openEvolutionControl)
        XCTAssertEqual(next?.sourceSurface, .widget)
        XCTAssertEqual(next?.entrySource, .homeWidgetMedium)
        XCTAssertEqual(next?.preferredMode, .mirror)
        XCTAssertEqual(next?.promptSeed, "Review the guarded queue")
        XCTAssertEqual(next?.triggerReason, "Widget surfaced the guarded queue detail.")
        XCTAssertEqual(next?.riskLevel, .medium)
    }

    func testWidgetEvolutionControlIntentFallsBackToSharedTriggerReason() async throws {
        let intent = OpenEvolutionControlIntent(
            entrySource: .homeWidgetSmall,
            prompt: "Review the compact queue"
        )

        _ = try await intent.perform()

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .openEvolutionControl)
        XCTAssertEqual(next?.sourceSurface, .widget)
        XCTAssertEqual(next?.entrySource, .homeWidgetSmall)
        XCTAssertEqual(next?.promptSeed, "Review the compact queue")
        XCTAssertEqual(
            next?.triggerReason,
            EntrySource.homeWidgetSmall.defaultEvolutionControlTriggerReason
        )
        XCTAssertEqual(next?.riskLevel, .medium)
    }

    func testWidgetEvolutionControlIntentUsesAuditAwareFallbackReason() async throws {
        let controlEntry = DecisionEvolutionWidgetControlEntryPresentation(
            kindID: DecisionEvolutionWidgetControlEntryKind.audit.rawValue,
            title: "Audit on iPhone",
            systemImage: "exclamationmark.circle",
            prompt: "Inspect the audit findings",
            instruction: "Continue on iPhone to inspect audit findings before widening rollout.",
            triggerReason: nil
        )
        let intent = OpenEvolutionControlIntent(
            entrySource: .homeWidgetMedium,
            controlEntry: controlEntry
        )

        _ = try await intent.perform()

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .openEvolutionControl)
        XCTAssertEqual(next?.sourceSurface, .widget)
        XCTAssertEqual(next?.entrySource, .homeWidgetMedium)
        XCTAssertEqual(next?.promptSeed, "Inspect the audit findings")
        XCTAssertEqual(
            next?.controlEntryKindID,
            DecisionEvolutionWidgetControlEntryKind.audit.rawValue
        )
        XCTAssertEqual(
            next?.triggerReason,
            "Inspect evolution audit findings from Medium Widget."
        )
    }

    func testWatchQuickCaptureUsesSharedFactoryAndPreservesScenarioAndRisk() {
        WatchHandoffCoordinator.enqueueQuickCapture(
            promptSeed: "Pause before replying",
            scenario: .scroll,
            riskLevel: .high
        )

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .quickCapture)
        XCTAssertEqual(next?.sourceSurface, .watch)
        XCTAssertEqual(next?.entrySource, .watch)
        XCTAssertEqual(next?.preferredMode, .quick)
        XCTAssertEqual(next?.promptSeed, "Pause before replying")
        XCTAssertEqual(next?.scenario, .scroll)
        XCTAssertEqual(next?.riskLevel, .high)
    }

    func testWatchReopenTomorrowItemUsesSharedFactoryAndTrimsTitle() {
        WatchHandoffCoordinator.enqueueReopenTomorrowItem(
            title: "  Revisit the launch plan  ",
            riskLevel: .medium,
            preferredMode: .balance
        )

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .reopenTomorrowItem)
        XCTAssertEqual(next?.sourceSurface, .watch)
        XCTAssertEqual(next?.entrySource, .watch)
        XCTAssertEqual(next?.preferredMode, .balance)
        XCTAssertEqual(next?.promptSeed, "Revisit the launch plan")
        XCTAssertEqual(next?.riskLevel, .medium)
    }

    func testResumeCurrentDecisionFactoryTrimsPromptAndTriggerReason() {
        let envelope = DecisionIntentEnvelope.resumeCurrentDecision(
            sourceSurface: .notification,
            entrySource: .app,
            preferredMode: .quick,
            promptSeed: "  Resume this carefully.  ",
            riskLevel: .high,
            triggerReason: "  prediction  "
        )

        XCTAssertEqual(envelope.kind, .resumeCurrentDecision)
        XCTAssertEqual(envelope.sourceSurface, .notification)
        XCTAssertEqual(envelope.entrySource, .app)
        XCTAssertEqual(envelope.promptSeed, "Resume this carefully.")
        XCTAssertEqual(envelope.triggerReason, "prediction")
        XCTAssertEqual(envelope.riskLevel, .high)
    }

    func testRoutedInputFactoryTrimsPromptAndUsesEntrySurface() {
        let envelope = DecisionIntentEnvelope.routedInput(
            entrySource: .shortcut,
            promptSeed: "  Route this shared prompt.  "
        )

        XCTAssertEqual(envelope.kind, .routedInput)
        XCTAssertEqual(envelope.entrySource, .shortcut)
        XCTAssertEqual(envelope.sourceSurface, .shortcut)
        XCTAssertEqual(envelope.promptSeed, "Route this shared prompt.")
    }

    func testReopenTomorrowItemFactorySupportsExplicitNotificationSurface() {
        let envelope = DecisionIntentEnvelope.reopenTomorrowItem(
            sourceSurface: .notification,
            entrySource: .app,
            title: "  Resume with more space.  ",
            riskLevel: .medium,
            preferredMode: .balance
        )

        XCTAssertEqual(envelope.kind, .reopenTomorrowItem)
        XCTAssertEqual(envelope.sourceSurface, .notification)
        XCTAssertEqual(envelope.entrySource, .app)
        XCTAssertEqual(envelope.promptSeed, "Resume with more space.")
        XCTAssertEqual(envelope.riskLevel, .medium)
        XCTAssertEqual(envelope.preferredMode, .balance)
    }

    func testLockScreenPrimaryActionIntentQueuesWidgetScopedReviewRequest() async throws {
        let action = DecisionEvolutionWidgetPrimaryActionPresentation(
            kind: .evolutionControl,
            title: "Review on iPhone",
            systemImage: "checklist",
            prompt: "Review the accessory queue",
            triggerReason: "Accessory widget surfaced the guarded queue detail."
        )
        let intent = OpenEvolutionControlIntent(
            entrySource: .lockScreenWidget,
            primaryAction: action
        )

        _ = try await intent.perform()

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .openEvolutionControl)
        XCTAssertEqual(next?.sourceSurface, .widget)
        XCTAssertEqual(next?.entrySource, .lockScreenWidget)
        XCTAssertEqual(next?.preferredMode, .mirror)
        XCTAssertEqual(next?.promptSeed, "Review the accessory queue")
        XCTAssertEqual(
            next?.triggerReason,
            "Accessory widget surfaced the guarded queue detail."
        )
        XCTAssertEqual(next?.riskLevel, .medium)
    }

    func testWatchEvolutionControlHandoffFallsBackToSharedTriggerReason() {
        WatchHandoffCoordinator.enqueueOpenEvolutionControl(headline: "Review the watch queue")

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .openEvolutionControl)
        XCTAssertEqual(next?.sourceSurface, .watch)
        XCTAssertEqual(next?.entrySource, .watch)
        XCTAssertEqual(next?.promptSeed, "Review the watch queue")
        XCTAssertEqual(
            next?.triggerReason,
            EntrySource.watch.defaultEvolutionControlTriggerReason
        )
        XCTAssertEqual(next?.riskLevel, .medium)
    }

    func testWatchEvolutionControlHandoffUsesAuditAwareFallbackReason() {
        let controlEntry = DecisionEvolutionWidgetControlEntryPresentation(
            kindID: DecisionEvolutionWidgetControlEntryKind.audit.rawValue,
            title: "Audit on iPhone",
            systemImage: "exclamationmark.circle",
            prompt: "Inspect the watch audit findings",
            instruction: "Continue on iPhone to inspect audit findings before widening rollout.",
            triggerReason: nil
        )

        WatchHandoffCoordinator.enqueueOpenEvolutionControl(controlEntry)

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .openEvolutionControl)
        XCTAssertEqual(next?.sourceSurface, .watch)
        XCTAssertEqual(next?.entrySource, .watch)
        XCTAssertEqual(next?.promptSeed, "Inspect the watch audit findings")
        XCTAssertEqual(
            next?.controlEntryKindID,
            DecisionEvolutionWidgetControlEntryKind.audit.rawValue
        )
        XCTAssertEqual(
            next?.triggerReason,
            "A watch audit alert asked the iPhone brain to inspect evolution findings."
        )
        XCTAssertEqual(next?.riskLevel, .medium)
    }

    func testLockScreenPrimaryActionIntentUsesAuditAwareFallbackReason() async throws {
        let action = DecisionEvolutionWidgetPrimaryActionPresentation(
            kind: .evolutionControl,
            controlEntryKindID: DecisionEvolutionWidgetControlEntryKind.audit.rawValue,
            title: "Audit on iPhone",
            systemImage: "exclamationmark.circle",
            prompt: "Inspect the accessory audit findings",
            triggerReason: nil
        )
        let intent = OpenEvolutionControlIntent(
            entrySource: .lockScreenWidget,
            primaryAction: action
        )

        _ = try await intent.perform()

        let next = DecisionIntentEnvelopeStore.consume()

        XCTAssertEqual(next?.kind, .openEvolutionControl)
        XCTAssertEqual(next?.sourceSurface, .widget)
        XCTAssertEqual(next?.entrySource, .lockScreenWidget)
        XCTAssertEqual(next?.promptSeed, "Inspect the accessory audit findings")
        XCTAssertEqual(
            next?.controlEntryKindID,
            DecisionEvolutionWidgetControlEntryKind.audit.rawValue
        )
        XCTAssertEqual(
            next?.triggerReason,
            "Inspect evolution audit findings from Lock Screen Widget."
        )
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
        .quickCapture(
            entrySource: .watch,
            promptSeed: promptSeed,
            requestedAt: requestedAt,
            expiresAt: expiresAt ?? requestedAt.addingTimeInterval(600)
        )
        .withID(id)
    }
}

private extension DecisionIntentEnvelope {
    func withID(_ id: UUID) -> DecisionIntentEnvelope {
        DecisionIntentEnvelope(
            id: id,
            kind: kind,
            sourceSurface: sourceSurface,
            entrySource: entrySource,
            preferredMode: preferredMode,
            scenario: scenario,
            promptSeed: promptSeed,
            riskLevel: riskLevel,
            triggerReason: triggerReason,
            controlEntryKindID: controlEntryKindID,
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }
}
