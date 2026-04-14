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
        XCTAssertEqual(evolution.pendingReviewCount, 0)
        XCTAssertEqual(evolution.rollbackReadyCount, 0)
        XCTAssertEqual(evolution.activeKillSwitchCount, 0)
        XCTAssertEqual(evolution.recommendedKillSwitchCount, 0)
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

        XCTAssertEqual(review.watchControlEntryTitle, "Review on iPhone")
        XCTAssertEqual(blocked.watchControlEntryTitle, "Control on iPhone")
    }
}
