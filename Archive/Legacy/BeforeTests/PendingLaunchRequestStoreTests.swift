import XCTest
@testable import Before

final class PendingLaunchRequestStoreTests: XCTestCase {
    override func tearDown() {
        PendingLaunchRequestStore.clear()
        SharedProtectedStateStore.clearQuarantine(key: "before.pending.launch.request")
        SharedContainer.defaults.removeObject(forKey: "before.pending.launch.request")
        StateStorageIssueRecorder.clear()
        super.tearDown()
    }

    func testNormalizedQueueDropsExpiredRequests() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let fresh = PendingLaunchRequest.quickCapture(
            entrySource: .app,
            requestedAt: now,
            expiresAt: now.addingTimeInterval(60)
        )
        let expired = PendingLaunchRequest.quickCapture(
            entrySource: .shortcut,
            requestedAt: now.addingTimeInterval(-500),
            expiresAt: now.addingTimeInterval(-1)
        )
        let data = try JSONEncoder().encode([expired, fresh])

        let queue = PendingLaunchRequestStore.normalizedQueue(from: data, now: now)

        XCTAssertEqual(queue, [fresh])
    }

    func testNormalizedQueueDecodesLegacySingleRequestPayload() throws {
        let data = """
        {
          "entrySource": "shortcut",
          "requestedAt": 0
        }
        """.data(using: .utf8)!

        let queue = PendingLaunchRequestStore.normalizedQueue(from: data, now: Date(timeIntervalSince1970: 60))

        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.entrySource, .shortcut)
    }

    func testNormalizedQueueDropsLegacyPromptPayloadFromDefaultsData() throws {
        let now = Date(timeIntervalSince1970: 500)
        let request = PendingLaunchRequest.openMode(
            entrySource: .shortcut,
            mode: .mirror,
            prompt: "Should I leave this relationship?",
            requestedAt: now
        )

        let data = try JSONEncoder().encode([request])
        let queue = PendingLaunchRequestStore.normalizedQueue(from: data, now: now)

        XCTAssertEqual(queue.first?.preferredMode, .mirror)
        XCTAssertNil(queue.first?.prompt)
    }

    func testNormalizedQueueDecodesEnvelopePayloadWithoutPromptInDefaults() throws {
        let now = Date(timeIntervalSince1970: 500)
        let data = """
        [
          {
            "id": "\(UUID().uuidString)",
            "entrySource": "shortcut",
            "preferredModeRaw": "mirror",
            "scenarioRaw": null,
            "requestedAt": \(now.timeIntervalSince1970),
            "expiresAt": \(now.addingTimeInterval(60).timeIntervalSince1970),
            "schemaVersion": 1,
            "hasProtectedPayload": true
          }
        ]
        """.data(using: .utf8)!

        let queue = PendingLaunchRequestStore.normalizedQueue(from: data, now: now)

        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.preferredMode, .mirror)
        XCTAssertNil(queue.first?.prompt)
    }

    func testNormalizedDecisionIntentEnvelopeQueuePreservesLegacyRoutingWithoutRecoveringPrompt() throws {
        let now = Date(timeIntervalSince1970: 500)
        let request = PendingLaunchRequest.routedPrompt(
            entrySource: .shortcut,
            prompt: "  Route the normalized legacy prompt.  ",
            requestedAt: now
        )

        let data = try JSONEncoder().encode([request])
        let queue = PendingLaunchRequestStore.normalizedDecisionIntentEnvelopeQueue(from: data, now: now)

        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.kind, .routedInput)
        XCTAssertEqual(queue.first?.entrySource, .shortcut)
        XCTAssertEqual(queue.first?.sourceSurface, .shortcut)
        XCTAssertNil(queue.first?.promptSeed)
    }

    func testEnqueueAndConsumeRoundTripUsesSharedProtectedQueueInsteadOfDefaults() {
        PendingLaunchRequestStore.clear()

        let now = Date()
        let request = PendingLaunchRequest(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            entrySource: .shortcut,
            preferredMode: .mirror,
            prompt: "Keep this private.",
            requestedAt: now
        )

        PendingLaunchRequestStore.enqueue(request)

        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.pending.launch.request"))
        XCTAssertNotNil(SharedProtectedStateStore.loadData(key: "before.pending.launch.request"))
        XCTAssertNotNil(
            SharedProtectedStateStore.loadData(
                key: "before.pending.launch.request.payload.aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
            )
        )

        let restored = PendingLaunchRequestStore.consume()

        XCTAssertEqual(restored?.preferredMode, .mirror)
        XCTAssertEqual(restored?.prompt, "Keep this private.")
        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.pending.launch.request"))
        XCTAssertNil(SharedProtectedStateStore.loadData(key: "before.pending.launch.request"))
        XCTAssertNil(
            SharedProtectedStateStore.loadData(
                key: "before.pending.launch.request.payload.aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
            )
        )
    }

    func testEnqueueEnvelopeAndConsumeEnvelopeRoundTripUsesSharedProtectedQueue() {
        PendingLaunchRequestStore.clear()

        let envelope = DecisionIntentEnvelope.openMode(
            entrySource: .shortcut,
            mode: .mirror,
            promptSeed: "  Keep the envelope-native prompt private.  ",
            requestedAt: Date()
        )

        PendingLaunchRequestStore.enqueue(envelope)

        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.pending.launch.request"))
        XCTAssertNotNil(SharedProtectedStateStore.loadData(key: "before.pending.launch.request"))

        let restored = PendingLaunchRequestStore.consumeEnvelope()

        XCTAssertEqual(restored?.kind, .openMode)
        XCTAssertEqual(restored?.entrySource, .shortcut)
        XCTAssertEqual(restored?.preferredMode, .mirror)
        XCTAssertEqual(restored?.promptSeed, "Keep the envelope-native prompt private.")
        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.pending.launch.request"))
        XCTAssertNil(SharedProtectedStateStore.loadData(key: "before.pending.launch.request"))
    }

    func testSetEnvelopeKeepsLegacyConsumeAsForwardingAdapter() {
        PendingLaunchRequestStore.clear()

        let envelope = DecisionIntentEnvelope.routedInput(
            entrySource: .shortcut,
            promptSeed: "  Route this through the shared write seam.  "
        )

        PendingLaunchRequestStore.set(envelope)

        let restored = PendingLaunchRequestStore.consume()

        XCTAssertEqual(restored?.entrySource, .shortcut)
        XCTAssertEqual(restored?.prompt, "Route this through the shared write seam.")
        XCTAssertEqual(restored?.decisionIntentEnvelope.kind, .routedInput)
        XCTAssertEqual(
            restored?.decisionIntentEnvelope.promptSeed,
            "Route this through the shared write seam."
        )
    }

    func testEnqueueEvolutionControlEnvelopePreservesAuditControlEntryKindAcrossSharedProtectedQueue() {
        PendingLaunchRequestStore.clear()

        let envelope = DecisionIntentEnvelope.openEvolutionControl(
            entrySource: .homeWidgetMedium,
            promptSeed: "Inspect the audit findings",
            controlEntryKindID: DecisionEvolutionWidgetControlEntryKind.audit.rawValue,
            requestedAt: Date()
        )

        PendingLaunchRequestStore.enqueue(envelope)

        let restored = PendingLaunchRequestStore.consumeEnvelope()

        XCTAssertEqual(restored?.kind, .openEvolutionControl)
        XCTAssertEqual(restored?.entrySource, .homeWidgetMedium)
        XCTAssertEqual(
            restored?.controlEntryKindID,
            DecisionEvolutionWidgetControlEntryKind.audit.rawValue
        )
        XCTAssertEqual(
            restored?.instructionDetail,
            DecisionEvolutionWidgetControlEntryLexiconSupport.auditInstruction
        )
        XCTAssertEqual(
            restored?.triggerReason,
            "Inspect evolution audit findings from Medium Widget."
        )
    }

    func testEnqueueLegacyAuditEnvelopeBackfillsInstructionAndTriggerReasonAcrossSharedProtectedQueue() {
        PendingLaunchRequestStore.clear()

        let now = Date()
        let envelope = DecisionIntentEnvelope(
            id: UUID(uuidString: "22222222-3333-4444-5555-666666666666")!,
            kind: .openEvolutionControl,
            sourceSurface: .widget,
            entrySource: .homeWidgetMedium,
            preferredMode: .mirror,
            promptSeed: "Inspect the legacy audit findings",
            instructionDetail: nil,
            triggerReason: nil,
            controlEntryKindID: DecisionEvolutionWidgetControlEntryKind.audit.rawValue,
            requestedAt: now,
            expiresAt: now.addingTimeInterval(BeforePolicy.LaunchRequests.expirationInterval)
        )

        PendingLaunchRequestStore.enqueue(envelope)

        let restored = PendingLaunchRequestStore.consumeEnvelope()

        XCTAssertEqual(restored?.kind, .openEvolutionControl)
        XCTAssertEqual(restored?.entrySource, .homeWidgetMedium)
        XCTAssertEqual(restored?.promptSeed, "Inspect the legacy audit findings")
        XCTAssertEqual(
            restored?.controlEntryKindID,
            DecisionEvolutionWidgetControlEntryKind.audit.rawValue
        )
        XCTAssertEqual(
            restored?.instructionDetail,
            DecisionEvolutionWidgetControlEntryLexiconSupport.auditInstruction
        )
        XCTAssertEqual(
            restored?.triggerReason,
            "Inspect evolution audit findings from Medium Widget."
        )
    }

    func testExpiredProtectedPayloadIsPurgedWhenQueueIsLoaded() {
        PendingLaunchRequestStore.clear()

        let now = Date()
        let expiredRequest = PendingLaunchRequest.openMode(
            id: UUID(uuidString: "FFFFFFFF-1111-2222-3333-444444444444")!,
            entrySource: .shortcut,
            mode: .quick,
            prompt: "Expired sensitive prompt",
            requestedAt: now.addingTimeInterval(-BeforePolicy.LaunchRequests.expirationInterval - 30)
        )

        PendingLaunchRequestStore.enqueue(expiredRequest)

        XCTAssertNotNil(
            SharedProtectedStateStore.loadData(
                key: "before.pending.launch.request.payload.ffffffff-1111-2222-3333-444444444444"
            )
        )

        XCTAssertNil(PendingLaunchRequestStore.consume())
        XCTAssertNil(SharedProtectedStateStore.loadData(key: "before.pending.launch.request"))
        XCTAssertNil(
            SharedProtectedStateStore.loadData(
                key: "before.pending.launch.request.payload.ffffffff-1111-2222-3333-444444444444"
            )
        )
    }

    func testConsumePurgesLegacySharedDefaultsQueueWithoutRestoringIt() throws {
        PendingLaunchRequestStore.clear()

        let now = Date(timeIntervalSince1970: 900)
        let request = PendingLaunchRequest.openMode(
            entrySource: .shortcut,
            mode: .balance,
            prompt: "Legacy sensitive launch prompt",
            requestedAt: now
        )

        let data = try JSONEncoder().encode([request])
        SharedContainer.defaults.set(data, forKey: "before.pending.launch.request")

        XCTAssertNil(PendingLaunchRequestStore.consume())
        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.pending.launch.request"))
        XCTAssertNil(SharedProtectedStateStore.loadData(key: "before.pending.launch.request"))
    }

    func testConsumeQuarantinesUnreadableSharedProtectedQueue() {
        PendingLaunchRequestStore.clear()

        let key = "before.pending.launch.request"
        let raw = Data("broken-queue".utf8)
        SharedProtectedStateStore.saveData(raw, key: key)

        XCTAssertNil(PendingLaunchRequestStore.consume())
        XCTAssertNil(SharedProtectedStateStore.loadData(key: key))
        XCTAssertEqual(SharedProtectedStateStore.quarantinedData(key: key), raw)
        XCTAssertNotNil(StateStorageIssueRecorder.latestNotice())
    }

    func testConsumeRemovesOrphanProtectedPayloads() {
        PendingLaunchRequestStore.clear()

        let orphanKey = "before.pending.launch.request.payload.12345678-1234-1234-1234-1234567890ab"
        XCTAssertTrue(SharedProtectedStateStore.saveData(Data("orphan".utf8), key: orphanKey))

        XCTAssertNil(PendingLaunchRequestStore.consume())
        XCTAssertNil(SharedProtectedStateStore.loadData(key: orphanKey))
    }

    func testUnreadableQueueCleanupRemovesOrphanPayloads() {
        PendingLaunchRequestStore.clear()

        let queueKey = "before.pending.launch.request"
        let orphanKey = "before.pending.launch.request.payload.aaaaaaaa-1234-5678-90ab-aaaaaaaaaaaa"
        XCTAssertTrue(SharedProtectedStateStore.saveData(Data("broken-queue".utf8), key: queueKey))
        XCTAssertTrue(SharedProtectedStateStore.saveData(Data("orphan".utf8), key: orphanKey))

        XCTAssertNil(PendingLaunchRequestStore.consume())
        XCTAssertNil(SharedProtectedStateStore.loadData(key: orphanKey))
    }

    func testOpenModeFactoryTrimsProtectedPromptBeforeRoundTrip() {
        PendingLaunchRequestStore.clear()

        let request = PendingLaunchRequest.openMode(
            entrySource: .shortcut,
            mode: .mirror,
            prompt: "  Keep only the trimmed prompt.  "
        )

        PendingLaunchRequestStore.enqueue(request)

        let restored = PendingLaunchRequestStore.consume()

        XCTAssertEqual(restored?.prompt, "Keep only the trimmed prompt.")
        XCTAssertEqual(restored?.sanitizedPrompt, "Keep only the trimmed prompt.")
    }

    func testPendingLaunchRequestBridgesToSharedRoutedIntentEnvelope() {
        let request = PendingLaunchRequest.routedPrompt(
            entrySource: .shortcut,
            prompt: "  Route the legacy prompt.  "
        )

        let envelope = request.decisionIntentEnvelope

        XCTAssertEqual(envelope.kind, .routedInput)
        XCTAssertEqual(envelope.entrySource, .shortcut)
        XCTAssertEqual(envelope.sourceSurface, .shortcut)
        XCTAssertEqual(envelope.promptSeed, "Route the legacy prompt.")
    }

    func testConsumeDecisionIntentEnvelopeBridgesLegacyQueueToSharedIntentPath() {
        PendingLaunchRequestStore.clear()

        let request = PendingLaunchRequest.routedPrompt(
            entrySource: .shortcut,
            prompt: "  Route the queued prompt.  "
        )
        PendingLaunchRequestStore.enqueue(request)

        let envelope = PendingLaunchRequestStore.consume()?.decisionIntentEnvelope

        XCTAssertEqual(envelope?.kind, .routedInput)
        XCTAssertEqual(envelope?.entrySource, .shortcut)
        XCTAssertEqual(envelope?.sourceSurface, .shortcut)
        XCTAssertEqual(envelope?.promptSeed, "Route the queued prompt.")
        XCTAssertNil(PendingLaunchRequestStore.consume()?.decisionIntentEnvelope)
    }

    func testConsumeEnvelopeBridgesLegacyQueueToSharedIntentPath() {
        PendingLaunchRequestStore.clear()

        let request = PendingLaunchRequest.openMode(
            entrySource: .shortcut,
            mode: .mirror,
            prompt: "  Review this through the new envelope seam.  "
        )
        PendingLaunchRequestStore.enqueue(request)

        let envelope = PendingLaunchRequestStore.consumeEnvelope()

        XCTAssertEqual(envelope?.kind, .openMode)
        XCTAssertEqual(envelope?.entrySource, .shortcut)
        XCTAssertEqual(envelope?.sourceSurface, .shortcut)
        XCTAssertEqual(envelope?.preferredMode, .mirror)
        XCTAssertEqual(envelope?.promptSeed, "Review this through the new envelope seam.")
        XCTAssertNil(PendingLaunchRequestStore.consumeEnvelope())
    }
}
