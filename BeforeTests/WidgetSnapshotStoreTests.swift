import XCTest
@testable import Before

final class WidgetSnapshotStoreTests: XCTestCase {
    override func tearDown() {
        WidgetSnapshotStore.clear()
        SharedPublicStateStore.clearQuarantine(key: "before.widget.snapshot")
        SharedContainer.defaults.removeObject(forKey: "before.widget.snapshot")
        StateStorageIssueRecorder.clear()
        super.tearDown()
    }

    func testSaveAndLoadRoundTripUsesSharedPublicStorage() {
        WidgetSnapshotStore.clear()

        let snapshot = WidgetSnapshot(
            safeMessage: WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Give it room",
                body: "A little distance can change a buying answer."
            ),
            latestVerdict: .pause,
            latestScenario: .buy,
            evolution: WidgetEvolutionSnapshot(
                releaseStateID: "watch",
                activeCheckpointSourceID: "automaticFallback",
                headline: "Watching the pending review queue",
                primaryReason: "1 checkpoint still requires review.",
                attentionSeverityID: "review",
                attentionBadgeValue: "1",
                attentionHeadline: "Evolution review is waiting",
                attentionDetail: "1 checkpoint still needs review before the queue is clear.",
                hasActiveCheckpoint: false,
                hasReviewCheckpoint: true,
                pendingReviewCount: 1,
                rollbackReadyCount: 0,
                activeKillSwitchCount: 0,
                recommendedKillSwitchCount: 1
            ),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        WidgetSnapshotStore.save(snapshot)

        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.widget.snapshot"))
        XCTAssertNotNil(SharedPublicStateStore.loadData(key: "before.widget.snapshot"))

        let loaded = WidgetSnapshotStore.load()

        XCTAssertEqual(loaded.messageHeadline, "Give it room")
        XCTAssertEqual(loaded.messageBody, "A little distance can change a buying answer.")
        XCTAssertEqual(loaded.evolution?.releaseStateID, "watch")
        XCTAssertEqual(loaded.evolution?.activeCheckpointSourceID, "automaticFallback")
        XCTAssertEqual(loaded.evolution?.controlEntryKindID, nil)
        XCTAssertEqual(loaded.evolution?.headline, "Watching the pending review queue")
        XCTAssertEqual(loaded.evolution?.primaryReason, "1 checkpoint still requires review.")
        XCTAssertEqual(loaded.evolution?.attentionSeverityID, "review")
        XCTAssertEqual(loaded.evolution?.attentionBadgeValue, "1")
        XCTAssertEqual(loaded.evolution?.attentionHeadline, "Evolution review is waiting")
        XCTAssertEqual(loaded.evolution?.attentionDetail, "1 checkpoint still needs review before the queue is clear.")
        XCTAssertEqual(loaded.evolution?.pendingReviewCount, 1)
        XCTAssertEqual(loaded.evolution?.recommendedKillSwitchCount, 1)
    }

    func testLoadMigratesLegacyDefaultsSnapshotIntoSharedPublicStorage() throws {
        WidgetSnapshotStore.clear()

        let legacySnapshot = WidgetSnapshot(
            safeMessage: WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Unsafe override",
                body: "My private reminder should never appear here."
            ),
            latestVerdict: .pause,
            latestScenario: .buy,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let data = try JSONEncoder().encode(legacySnapshot)
        SharedContainer.defaults.set(data, forKey: "before.widget.snapshot")

        let loaded = WidgetSnapshotStore.load()

        XCTAssertEqual(loaded.messageHeadline, "Give it room")
        XCTAssertEqual(loaded.messageBody, "A little distance can change a buying answer.")
        XCTAssertNil(loaded.evolution)
        XCTAssertNil(SharedContainer.defaults.data(forKey: "before.widget.snapshot"))
        XCTAssertNotNil(SharedPublicStateStore.loadData(key: "before.widget.snapshot"))
    }

    func testLoadDecodesLegacyEvolutionSnapshotWithoutControlEntryFields() throws {
        WidgetSnapshotStore.clear()

        let legacyPayload = """
        {
          "safeMessage": {
            "surfaceRaw": "publicSafe",
            "headline": "Steady",
            "body": "Keep the widget path visible."
          },
          "latestVerdict": "pause",
          "latestScenario": "buy",
          "evolution": {
            "releaseStateID": "watch",
            "activeCheckpointSourceID": "automaticFallback",
            "headline": "Watching the pending review queue",
            "primaryReason": "1 checkpoint still requires review.",
            "attentionSeverityID": "review",
            "attentionBadgeValue": "1",
            "attentionHeadline": "Evolution review is waiting",
            "attentionDetail": "1 checkpoint still needs review before the queue is clear.",
            "hasActiveCheckpoint": false,
            "hasReviewCheckpoint": true,
            "pendingReviewCount": 1,
            "rollbackReadyCount": 0,
            "activeKillSwitchCount": 0,
            "recommendedKillSwitchCount": 1
          },
          "updatedAt": 1000
        }
        """.data(using: .utf8)!

        SharedPublicStateStore.saveData(legacyPayload, key: "before.widget.snapshot")

        let loaded = WidgetSnapshotStore.load()
        let evolution = try XCTUnwrap(loaded.evolution)

        XCTAssertEqual(evolution.controlEntryKindID, nil)
        XCTAssertNil(evolution.storedControlEntry)
        XCTAssertEqual(evolution.releaseStateID, "watch")
        XCTAssertEqual(evolution.activeCheckpointSourceID, "automaticFallback")
        XCTAssertEqual(evolution.displayHeadline, "Evolution review is waiting")
        XCTAssertEqual(
            evolution.displayDetail,
            "1 checkpoint still needs review before the queue is clear."
        )
        XCTAssertEqual(evolution.controlEntryTitle, "Review on iPhone")
        XCTAssertEqual(evolution.controlEntrySystemImage, "checklist")
        XCTAssertEqual(
            evolution.attentionInstruction,
            "Continue on iPhone to review pending checkpoints and clear the queue."
        )
    }

    func testWidgetSnapshotPrimaryActionFallsBackToQuickOpenWhenEvolutionIsAbsent() {
        let snapshot = WidgetSnapshot(
            safeMessage: WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Give it room",
                body: "A little distance can change a buying answer."
            ),
            latestVerdict: .pause,
            latestScenario: .buy,
            evolution: nil,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(snapshot.primaryActionPresentation.kind, .quick)
        XCTAssertEqual(snapshot.primaryActionPresentation.title, "Open Before")
        XCTAssertEqual(snapshot.primaryActionPresentation.systemImage, "pause.circle.fill")
        XCTAssertNil(snapshot.primaryActionPresentation.prompt)
    }

    func testLoadQuarantinesCorruptedSharedPublicSnapshot() {
        WidgetSnapshotStore.clear()

        let key = "before.widget.snapshot"
        let raw = Data("broken-snapshot".utf8)
        SharedPublicStateStore.saveData(raw, key: key)

        let loaded = WidgetSnapshotStore.load()

        XCTAssertEqual(loaded.messageHeadline, WidgetSnapshot.empty.messageHeadline)
        XCTAssertEqual(loaded.messageBody, WidgetSnapshot.empty.messageBody)
        XCTAssertNil(SharedPublicStateStore.loadData(key: key))
        XCTAssertEqual(SharedPublicStateStore.quarantinedData(key: key), raw)
        XCTAssertNotNil(StateStorageIssueRecorder.latestNotice())
    }

    func testWidgetEvolutionSnapshotSurfacesAttentionAndActiveCheckpointSource() {
        let evolution = WidgetEvolutionSnapshot(
            releaseStateID: "watch",
            activeCheckpointSourceID: "automaticFallback",
            headline: "Watching the pending review queue",
            primaryReason: "1 checkpoint still requires review.",
            attentionSeverityID: "review",
            attentionBadgeValue: "2",
            attentionHeadline: "Evolution review is waiting",
            attentionDetail: "2 checkpoint(s) still need review before the queue is clear.",
            hasActiveCheckpoint: true,
            hasReviewCheckpoint: true,
            pendingReviewCount: 2,
            rollbackReadyCount: 1,
            activeKillSwitchCount: 1,
            recommendedKillSwitchCount: 2
        )

        XCTAssertEqual(evolution.releaseStateTitle, "WATCH")
        XCTAssertEqual(evolution.displayHeadline, "Evolution review is waiting")
        XCTAssertEqual(evolution.displayDetail, "2 checkpoint(s) still need review before the queue is clear.")
        XCTAssertEqual(evolution.activeCheckpointSourceTitle, "Recovered active")
        XCTAssertEqual(evolution.attentionSeverity, .review)
        XCTAssertEqual(
            evolution.compactStatusLine,
            "Recovered active • Pending 2 • Rollback 1 • Active switches 1 • Recommended 2"
        )
        XCTAssertTrue(evolution.surfacesAttention)
        XCTAssertEqual(evolution.controlEntryTitle, "Review on iPhone")
        XCTAssertEqual(evolution.controlEntrySystemImage, "checklist")
        XCTAssertEqual(
            evolution.attentionInstruction,
            "Continue on iPhone to review pending checkpoints and clear the queue."
        )
    }

    func testWidgetEvolutionSurfacePresentationBuildsSharedBadgesAndControlEntry() {
        let evolution = WidgetEvolutionSnapshot(
            releaseStateID: "blocked",
            activeCheckpointSourceID: "automaticFallback",
            headline: "Watching the pending review queue",
            primaryReason: "1 checkpoint still requires review.",
            attentionSeverityID: "review",
            attentionBadgeValue: "1",
            attentionHeadline: "Evolution review is waiting",
            attentionDetail: "1 checkpoint still needs review before the queue is clear.",
            hasActiveCheckpoint: true,
            hasReviewCheckpoint: true,
            pendingReviewCount: 1,
            rollbackReadyCount: 1,
            activeKillSwitchCount: 1,
            recommendedKillSwitchCount: 0
        )

        let presentation = evolution.surfacePresentation

        XCTAssertEqual(
            presentation.statusBadges,
            [
                DecisionEvolutionWidgetStatusBadgePresentation(title: "BLOCKED", tone: .red),
                DecisionEvolutionWidgetStatusBadgePresentation(title: "P1", tone: .orange),
                DecisionEvolutionWidgetStatusBadgePresentation(title: "R1", tone: .green),
                DecisionEvolutionWidgetStatusBadgePresentation(title: "K1", tone: .red)
            ]
        )
        XCTAssertEqual(presentation.headline, "Evolution review is waiting")
        XCTAssertEqual(
            presentation.detail,
            "1 checkpoint still needs review before the queue is clear."
        )
        XCTAssertEqual(presentation.activeSourceTitle, "Recovered active")
        XCTAssertEqual(presentation.controlEntry?.title, "Review on iPhone")
        XCTAssertEqual(presentation.controlEntry?.systemImage, "checklist")
    }

    func testWidgetSnapshotPrimaryActionUsesEvolutionControlEntryWhenAttentionIsPresent() {
        let snapshot = WidgetSnapshot(
            safeMessage: WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Hold",
                body: "The queue needs a closer look."
            ),
            latestVerdict: .pause,
            latestScenario: .buy,
            evolution: WidgetEvolutionSnapshot(
                releaseStateID: "blocked",
                activeCheckpointSourceID: "recoveredActive",
                headline: "Evolution review is waiting",
                primaryReason: "1 checkpoint still needs review before the queue is clear.",
                attentionSeverityID: "review",
                attentionBadgeValue: "1",
                attentionHeadline: "Evolution review is waiting",
                attentionDetail: "1 checkpoint still needs review before the queue is clear.",
                hasActiveCheckpoint: true,
                hasReviewCheckpoint: true,
                pendingReviewCount: 1,
                rollbackReadyCount: 0,
                activeKillSwitchCount: 0,
                recommendedKillSwitchCount: 0
            ),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(snapshot.primaryActionPresentation.kind, .evolutionControl)
        XCTAssertEqual(snapshot.primaryActionPresentation.title, "Review on iPhone")
        XCTAssertEqual(snapshot.primaryActionPresentation.systemImage, "checklist")
        XCTAssertEqual(snapshot.primaryActionPresentation.prompt, "Evolution review is waiting")
        XCTAssertEqual(
            snapshot.primaryActionPresentation.triggerReason,
            "1 checkpoint still needs review before the queue is clear."
        )
    }

    func testWidgetEvolutionSnapshotPrefersStoredControlEntryPresentation() {
        let storedControlEntry = DecisionEvolutionWidgetControlEntryPresentation(
            title: "Inspect on iPhone",
            systemImage: "scope",
            prompt: "Stored prompt",
            instruction: "Stored instruction",
            triggerReason: "Stored reason"
        )
        let evolution = WidgetEvolutionSnapshot(
            releaseStateID: "blocked",
            activeCheckpointSourceID: nil,
            controlEntryKindID: DecisionEvolutionWidgetControlEntryKind.review.rawValue,
            storedControlEntry: storedControlEntry,
            headline: "Fallback headline",
            primaryReason: "Fallback reason",
            attentionSeverityID: "review",
            attentionBadgeValue: "1",
            attentionHeadline: "Fallback attention",
            attentionDetail: "Fallback detail",
            hasActiveCheckpoint: true,
            hasReviewCheckpoint: true,
            pendingReviewCount: 1,
            rollbackReadyCount: 0,
            activeKillSwitchCount: 0,
            recommendedKillSwitchCount: 0
        )

        XCTAssertTrue(evolution.surfacesAttention)
        XCTAssertEqual(evolution.controlEntryTitle, "Inspect on iPhone")
        XCTAssertEqual(evolution.controlEntrySystemImage, "scope")
        XCTAssertEqual(evolution.controlEntryPrompt, "Stored prompt")
        XCTAssertEqual(evolution.controlEntryTriggerReason, "Stored reason")
        XCTAssertEqual(evolution.attentionInstruction, "Stored instruction")
        XCTAssertEqual(evolution.surfacePresentation.controlEntry, storedControlEntry)
    }

    func testSaveRoundTripsStoredControlEntryFieldsThroughSharedPublicStorage() throws {
        WidgetSnapshotStore.clear()

        let storedControlEntry = DecisionEvolutionWidgetControlEntryPresentation(
            title: "Inspect on iPhone",
            systemImage: "scope",
            prompt: "Stored prompt",
            instruction: "Stored instruction",
            triggerReason: "Stored reason"
        )
        let snapshot = WidgetSnapshot(
            safeMessage: WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Steady",
                body: "Keep the shared state compact."
            ),
            latestVerdict: .pause,
            latestScenario: .buy,
            evolution: WidgetEvolutionSnapshot(
                releaseStateID: "blocked",
                activeCheckpointSourceID: nil,
                controlEntryKindID: DecisionEvolutionWidgetControlEntryKind.control.rawValue,
                storedControlEntry: storedControlEntry,
                headline: "Fallback headline",
                primaryReason: "Fallback reason",
                attentionSeverityID: "blocked",
                attentionBadgeValue: "!",
                attentionHeadline: "Fallback attention",
                attentionDetail: "Fallback detail",
                hasActiveCheckpoint: true,
                hasReviewCheckpoint: false,
                pendingReviewCount: 0,
                rollbackReadyCount: 0,
                activeKillSwitchCount: 1,
                recommendedKillSwitchCount: 0
            ),
            updatedAt: Date(timeIntervalSince1970: 4_000)
        )

        WidgetSnapshotStore.save(snapshot)
        let evolution = try XCTUnwrap(WidgetSnapshotStore.load().evolution)

        XCTAssertEqual(
            evolution.controlEntryKindID,
            DecisionEvolutionWidgetControlEntryKind.control.rawValue
        )
        XCTAssertEqual(evolution.storedControlEntry, storedControlEntry)
        XCTAssertEqual(evolution.controlEntryTitle, "Inspect on iPhone")
        XCTAssertEqual(evolution.surfacePresentation.controlEntry, storedControlEntry)
    }

    func testWidgetEvolutionSnapshotControlEntryPrefersControlWhenOnlyKillSwitchesRemain() {
        let evolution = WidgetEvolutionSnapshot(
            releaseStateID: "blocked",
            activeCheckpointSourceID: nil,
            headline: "Kill switches are holding the release path",
            primaryReason: "Active host guardrails are enabled.",
            attentionSeverityID: "blocked",
            attentionBadgeValue: "!",
            attentionHeadline: "Evolution is blocked by active kill switches",
            attentionDetail: "Open Evolution Control to clear the blocked review path before release work continues.",
            hasActiveCheckpoint: true,
            hasReviewCheckpoint: false,
            pendingReviewCount: 0,
            rollbackReadyCount: 1,
            activeKillSwitchCount: 1,
            recommendedKillSwitchCount: 0
        )

        XCTAssertTrue(evolution.surfacesAttention)
        XCTAssertEqual(evolution.controlEntryTitle, "Control on iPhone")
        XCTAssertEqual(evolution.controlEntrySystemImage, "shield.lefthalf.filled")
        XCTAssertEqual(evolution.displayHeadline, "Evolution is blocked by active kill switches")
        XCTAssertEqual(
            evolution.attentionInstruction,
            "Continue on iPhone to inspect kill switches and unblock the release path."
        )
    }

    func testWidgetEvolutionSnapshotUsesExplicitControlEntryKindWhenStored() {
        let evolution = WidgetEvolutionSnapshot(
            releaseStateID: "watch",
            activeCheckpointSourceID: nil,
            controlEntryKindID: DecisionEvolutionWidgetControlEntryKind.rollback.rawValue,
            headline: "Policy routed widget action",
            primaryReason: "Rollback is the only remaining safe move.",
            attentionSeverityID: "none",
            attentionBadgeValue: nil,
            attentionHeadline: nil,
            attentionDetail: nil,
            hasActiveCheckpoint: true,
            hasReviewCheckpoint: false,
            pendingReviewCount: 0,
            rollbackReadyCount: 0,
            activeKillSwitchCount: 0,
            recommendedKillSwitchCount: 0
        )

        XCTAssertTrue(evolution.surfacesAttention)
        XCTAssertEqual(evolution.controlEntryTitle, "Rollback on iPhone")
        XCTAssertEqual(evolution.controlEntrySystemImage, "arrow.uturn.backward.circle")
        XCTAssertEqual(
            evolution.surfacePresentation.controlEntry?.title,
            "Rollback on iPhone"
        )
    }

    func testSaveSanitizesEvolutionSnapshotForSharedPublicStorage() throws {
        WidgetSnapshotStore.clear()

        let snapshot = WidgetSnapshot(
            safeMessage: WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Steady",
                body: "Keep the shared state compact."
            ),
            latestVerdict: .pause,
            latestScenario: .buy,
            evolution: WidgetEvolutionSnapshot(
                releaseStateID: "blocked",
                activeCheckpointSourceID: "pinnedHint",
                storedControlEntry: DecisionEvolutionWidgetControlEntryPresentation(
                    title: String(repeating: "T", count: 80),
                    systemImage: String(repeating: "S", count: 90),
                    prompt: String(repeating: "P", count: 220),
                    instruction: String(repeating: "I", count: 260),
                    triggerReason: String(repeating: "G", count: 260)
                ),
                headline: String(repeating: "H", count: 120),
                primaryReason: String(repeating: "R", count: 220),
                attentionSeverityID: "blocked",
                attentionBadgeValue: "!!!!!!!!!!!",
                attentionHeadline: String(repeating: "A", count: 220),
                attentionDetail: String(repeating: "D", count: 220),
                hasActiveCheckpoint: true,
                hasReviewCheckpoint: true,
                pendingReviewCount: -4,
                rollbackReadyCount: -2,
                activeKillSwitchCount: -1,
                recommendedKillSwitchCount: -3
            ),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        WidgetSnapshotStore.save(snapshot)
        let loaded = WidgetSnapshotStore.load()
        let evolution = try XCTUnwrap(loaded.evolution)

        XCTAssertEqual(evolution.releaseStateID, "blocked")
        XCTAssertEqual(evolution.activeCheckpointSourceID, "pinnedHint")
        XCTAssertEqual(evolution.headline.count, 120)
        XCTAssertEqual(evolution.primaryReason?.count, 160)
        XCTAssertEqual(evolution.attentionSeverityID, "blocked")
        XCTAssertEqual(evolution.attentionBadgeValue?.count, 8)
        XCTAssertEqual(evolution.attentionHeadline?.count, 120)
        XCTAssertEqual(evolution.attentionDetail?.count, 160)
        XCTAssertEqual(evolution.storedControlEntry?.title.count, 40)
        XCTAssertEqual(evolution.storedControlEntry?.systemImage.count, 60)
        XCTAssertEqual(evolution.storedControlEntry?.prompt.count, 120)
        XCTAssertEqual(evolution.storedControlEntry?.instruction.count, 160)
        XCTAssertEqual(evolution.storedControlEntry?.triggerReason?.count, 160)
        XCTAssertEqual(evolution.pendingReviewCount, 0)
        XCTAssertEqual(evolution.rollbackReadyCount, 0)
        XCTAssertEqual(evolution.activeKillSwitchCount, 0)
        XCTAssertEqual(evolution.recommendedKillSwitchCount, 0)
    }

    func testWidgetEvolutionSnapshotNormalizesAttentionSeverityContracts() {
        let absent = WidgetEvolutionSnapshot(
            releaseStateID: "watch",
            activeCheckpointSourceID: nil,
            headline: "Evolution is quiet",
            primaryReason: nil,
            attentionSeverityID: nil,
            attentionBadgeValue: nil,
            attentionHeadline: nil,
            attentionDetail: nil,
            hasActiveCheckpoint: false,
            hasReviewCheckpoint: false,
            pendingReviewCount: 0,
            rollbackReadyCount: 0,
            activeKillSwitchCount: 0,
            recommendedKillSwitchCount: 0
        )
        let explicitNone = WidgetEvolutionSnapshot(
            releaseStateID: "watch",
            activeCheckpointSourceID: nil,
            headline: "Evolution is quiet",
            primaryReason: nil,
            attentionSeverityID: "none",
            attentionBadgeValue: nil,
            attentionHeadline: "Evolution is quiet",
            attentionDetail: nil,
            hasActiveCheckpoint: false,
            hasReviewCheckpoint: false,
            pendingReviewCount: 0,
            rollbackReadyCount: 0,
            activeKillSwitchCount: 0,
            recommendedKillSwitchCount: 0
        )
        let invalid = WidgetEvolutionSnapshot(
            releaseStateID: "watch",
            activeCheckpointSourceID: nil,
            headline: "Evolution is quiet",
            primaryReason: nil,
            attentionSeverityID: "unexpected",
            attentionBadgeValue: nil,
            attentionHeadline: "Evolution is quiet",
            attentionDetail: nil,
            hasActiveCheckpoint: false,
            hasReviewCheckpoint: false,
            pendingReviewCount: 0,
            rollbackReadyCount: 0,
            activeKillSwitchCount: 0,
            recommendedKillSwitchCount: 0
        )

        XCTAssertNil(absent.attentionSeverity)
        XCTAssertFalse(absent.surfacesAttention)
        XCTAssertEqual(
            explicitNone.attentionSeverity,
            DecisionEvolutionWidgetAttentionSeverity.none
        )
        XCTAssertFalse(explicitNone.surfacesAttention)
        XCTAssertEqual(explicitNone.controlEntryTitle, "Open on iPhone")
        XCTAssertEqual(
            invalid.attentionSeverity,
            DecisionEvolutionWidgetAttentionSeverity.none
        )
        XCTAssertFalse(invalid.surfacesAttention)
        XCTAssertEqual(invalid.controlEntryTitle, "Open on iPhone")
    }

    func testSaveNormalizesInvalidWidgetAttentionSeverityIDsToNone() throws {
        WidgetSnapshotStore.clear()

        let snapshot = WidgetSnapshot(
            safeMessage: WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Steady",
                body: "Normalize widget evolution state."
            ),
            latestVerdict: .pause,
            latestScenario: .buy,
            evolution: WidgetEvolutionSnapshot(
                releaseStateID: "watch",
                activeCheckpointSourceID: nil,
                headline: "Evolution is quiet",
                primaryReason: nil,
                attentionSeverityID: "unexpected",
                attentionBadgeValue: "!",
                attentionHeadline: "Evolution is quiet",
                attentionDetail: nil,
                hasActiveCheckpoint: false,
                hasReviewCheckpoint: false,
                pendingReviewCount: 0,
                rollbackReadyCount: 0,
                activeKillSwitchCount: 0,
                recommendedKillSwitchCount: 0
            ),
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )

        WidgetSnapshotStore.save(snapshot)
        let loaded = try XCTUnwrap(WidgetSnapshotStore.load().evolution)

        XCTAssertEqual(loaded.attentionSeverityID, DecisionEvolutionWidgetAttentionSeverity.none.rawValue)
        XCTAssertEqual(
            loaded.attentionSeverity,
            DecisionEvolutionWidgetAttentionSeverity.none
        )
        XCTAssertFalse(loaded.surfacesAttention)
    }

    func testWidgetEvolutionSnapshotQuietStateFallsBackToOpenEntry() {
        let evolution = WidgetEvolutionSnapshot(
            releaseStateID: "watch",
            activeCheckpointSourceID: nil,
            headline: "Evolution is quiet",
            primaryReason: nil,
            attentionSeverityID: "none",
            attentionBadgeValue: nil,
            attentionHeadline: "Evolution is quiet",
            attentionDetail: nil,
            hasActiveCheckpoint: false,
            hasReviewCheckpoint: false,
            pendingReviewCount: 0,
            rollbackReadyCount: 0,
            activeKillSwitchCount: 0,
            recommendedKillSwitchCount: 0
        )

        XCTAssertFalse(evolution.surfacesAttention)
        XCTAssertEqual(evolution.compactStatusLine, "No checkpoint attached")
        XCTAssertEqual(evolution.controlEntryTitle, "Open on iPhone")
        XCTAssertEqual(evolution.controlEntrySystemImage, "arrow.up.right.circle")
        XCTAssertEqual(evolution.controlEntryPrompt, "Evolution is quiet")
        XCTAssertEqual(
            evolution.attentionInstruction,
            "Continue on iPhone to open Evolution Control."
        )
        XCTAssertEqual(evolution.watchControlEntryTitle, "Open on iPhone")
    }

    func testWidgetEvolutionSnapshotRollbackAttentionUsesRollbackEntry() {
        let evolution = WidgetEvolutionSnapshot(
            releaseStateID: "ready",
            activeCheckpointSourceID: "pinnedHint",
            headline: "Recovered active checkpoint",
            primaryReason: nil,
            attentionSeverityID: "rollbackWatch",
            attentionBadgeValue: "↺",
            attentionHeadline: "Rollback-ready active checkpoint is available",
            attentionDetail: "Evolution Control can restore the previous checkpoint without rebuilding the full lineage path.",
            hasActiveCheckpoint: true,
            hasReviewCheckpoint: false,
            pendingReviewCount: 0,
            rollbackReadyCount: 1,
            activeKillSwitchCount: 0,
            recommendedKillSwitchCount: 0
        )

        XCTAssertTrue(evolution.surfacesAttention)
        XCTAssertEqual(evolution.controlEntryTitle, "Rollback on iPhone")
        XCTAssertEqual(evolution.controlEntrySystemImage, "arrow.uturn.backward.circle")
        XCTAssertEqual(evolution.displayHeadline, "Rollback-ready active checkpoint is available")
        XCTAssertEqual(
            evolution.attentionInstruction,
            "Continue on iPhone to restore the rollback-ready checkpoint."
        )
        XCTAssertEqual(evolution.watchControlEntryTitle, "Rollback on iPhone")
    }

    func testWidgetEvolutionSnapshotWatchControlEntryTitlesTrackAttentionMode() {
        let review = WidgetEvolutionSnapshot(
            releaseStateID: "watch",
            activeCheckpointSourceID: "automaticFallback",
            headline: "Watching the pending queue",
            primaryReason: nil,
            attentionSeverityID: "review",
            attentionBadgeValue: "2",
            attentionHeadline: "Evolution review is waiting",
            attentionDetail: nil,
            hasActiveCheckpoint: false,
            hasReviewCheckpoint: true,
            pendingReviewCount: 2,
            rollbackReadyCount: 0,
            activeKillSwitchCount: 0,
            recommendedKillSwitchCount: 0
        )
        let blocked = WidgetEvolutionSnapshot(
            releaseStateID: "blocked",
            activeCheckpointSourceID: nil,
            headline: "Kill switches are holding the release path",
            primaryReason: nil,
            attentionSeverityID: "blocked",
            attentionBadgeValue: "!",
            attentionHeadline: "Evolution is blocked by active kill switches",
            attentionDetail: nil,
            hasActiveCheckpoint: true,
            hasReviewCheckpoint: false,
            pendingReviewCount: 0,
            rollbackReadyCount: 1,
            activeKillSwitchCount: 1,
            recommendedKillSwitchCount: 0
        )
        let audit = WidgetEvolutionSnapshot(
            releaseStateID: "watch",
            activeCheckpointSourceID: "automaticFallback",
            controlEntryKindID: DecisionEvolutionWidgetControlEntryKind.audit.rawValue,
            headline: "Watching audit findings before wider rollout",
            primaryReason: "Factors: evidence_caveat_load",
            attentionSeverityID: "review",
            attentionBadgeValue: "!",
            attentionHeadline: "Watching audit findings before wider rollout",
            attentionDetail: "Factors: evidence_caveat_load",
            hasActiveCheckpoint: true,
            hasReviewCheckpoint: false,
            pendingReviewCount: 0,
            rollbackReadyCount: 0,
            activeKillSwitchCount: 0,
            recommendedKillSwitchCount: 0
        )

        XCTAssertEqual(review.watchControlEntryTitle, "Review on iPhone")
        XCTAssertEqual(blocked.watchControlEntryTitle, "Control on iPhone")
        XCTAssertEqual(audit.watchControlEntryTitle, "Audit on iPhone")
        XCTAssertEqual(audit.controlEntrySystemImage, "exclamationmark.circle")
        XCTAssertEqual(
            audit.attentionInstruction,
            "Continue on iPhone to inspect audit findings before widening rollout."
        )
    }

    func testWidgetPresentationSupportBuildsSharedCompactStatusAndControlEntryCopy() {
        XCTAssertEqual(
            DecisionEvolutionWidgetCompactStatusLexiconSupport.pendingTitle(2),
            "Pending 2"
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetCompactStatusLexiconSupport.rollbackTitle(1),
            "Rollback 1"
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetCompactStatusLexiconSupport.activeSwitchesTitle(1),
            "Active switches 1"
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetCompactStatusLexiconSupport.recommendedTitle(2),
            "Recommended 2"
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetCompactStatusLexiconSupport.fallbackTitle(
                usesAttentionContract: true,
                attentionSeverity: .rollbackWatch,
                hasReviewCheckpoint: false,
                hasActiveCheckpoint: true
            ),
            "Rollback watch"
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetCompactStatusLexiconSupport.fallbackTitle(
                usesAttentionContract: false,
                attentionSeverity: nil,
                hasReviewCheckpoint: false,
                hasActiveCheckpoint: false
            ),
            "No checkpoint attached"
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetStatusBadgeLexiconSupport.releaseStateTitle(
                releaseStateID: nil
            ),
            DecisionEvolutionWidgetStatusBadgeLexiconSupport.watchTitle
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetStatusBadgeLexiconSupport.pendingTitle(1),
            "P1"
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetStatusBadgeLexiconSupport.rollbackTitle(1),
            "R1"
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetStatusBadgeLexiconSupport.killSwitchTitle(1),
            "K1"
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetPresentationSupport.compactStatusLine(
                activeCheckpointSourceTitle: "Recovered active",
                hasActiveCheckpoint: true,
                pendingReviewCount: 2,
                rollbackReadyCount: 1,
                activeKillSwitchCount: 1,
                recommendedKillSwitchCount: 2,
                usesAttentionContract: true,
                attentionSeverity: .review,
                hasReviewCheckpoint: true
            ),
            "Recovered active • Pending 2 • Rollback 1 • Active switches 1 • Recommended 2"
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetControlEntryLexiconSupport.title(for: .control),
            "Control on iPhone"
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetControlEntryLexiconSupport.instruction(for: .rollback),
            "Continue on iPhone to restore the rollback-ready checkpoint."
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetPresentationSupport.controlEntryTitle(kind: .control),
            DecisionEvolutionWidgetControlEntryLexiconSupport.title(for: .control)
        )
        XCTAssertEqual(
            DecisionEvolutionWidgetPresentationSupport.attentionInstruction(kind: .rollback),
            DecisionEvolutionWidgetControlEntryLexiconSupport.instruction(for: .rollback)
        )
    }
}
