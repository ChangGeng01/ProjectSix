import XCTest
@testable import BASMemory

final class BASEvolutionCoreTests: XCTestCase {
    func testCheckpointPlannerDeduplicatesEquivalentLatestState() {
        let now = Date(timeIntervalSince1970: 1_715_000_000)
        let input = BASEvolutionCheckpointInput(
            modeName: " quick ",
            sourceID: "launch",
            fingerprint: "fp-1",
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyAdvisory,
            calibrationStatus: .stable
        )
        let latest = BASEvolutionCheckpointStoredFields(
            id: "latest",
            createdAt: now,
            fingerprint: "fp-1",
            previousCheckpointID: nil,
            modeName: "quick",
            sourceID: "launch",
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyAdvisory,
            calibrationStatus: .stable,
            diffSummary: ["noop"],
            approvalState: .automatic,
            rollbackReady: true
        )

        XCTAssertTrue(BASEvolutionCheckpointPlanner.shouldDeduplicate(latest: latest, input: input))
    }

    func testCheckpointPlannerBuildsReviewCheckpointAndRetainsNewestFreshEntries() {
        let now = Date(timeIntervalSince1970: 1_715_000_000)
        let previous = BASEvolutionCheckpointStoredFields(
            id: "older",
            createdAt: now.addingTimeInterval(-60),
            fingerprint: "fp-0",
            previousCheckpointID: nil,
            modeName: "mirror",
            sourceID: "scene_active",
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyAdvisory,
            calibrationStatus: .stable,
            diffSummary: ["older"],
            approvalState: .automatic,
            rollbackReady: true
        )
        let input = BASEvolutionCheckpointInput(
            modeName: "mirror",
            sourceID: "scene_active",
            fingerprint: "fp-1",
            identityRole: .mirrorWitness,
            boundaryMode: .localOnlyProtective,
            calibrationStatus: .drifting
        )

        let planned = BASEvolutionCheckpointPlanner.checkpointFields(
            id: "newer",
            createdAt: now,
            latest: previous,
            input: input
        )

        XCTAssertEqual(planned.previousCheckpointID, "older")
        XCTAssertEqual(planned.approvalState, .reviewSuggested)
        XCTAssertTrue(planned.diffSummary.contains(where: { $0.contains("Role shifted") }))
        XCTAssertTrue(planned.diffSummary.contains(where: { $0.contains("Boundary mode tightened") }))
        XCTAssertTrue(planned.diffSummary.contains(where: { $0.contains("Calibration state moved to drifting") }))

        let stale = BASEvolutionCheckpointStoredFields(
            id: "stale",
            createdAt: now.addingTimeInterval(-(BASEvolutionCheckpointPlanner.defaultRetentionInterval + 1)),
            fingerprint: "stale",
            previousCheckpointID: nil,
            modeName: "quick",
            sourceID: "launch",
            identityRole: .pauseCompanion,
            boundaryMode: .localOnlyAdvisory,
            calibrationStatus: .stable,
            diffSummary: [],
            approvalState: .automatic,
            rollbackReady: true
        )

        let retained = BASEvolutionCheckpointPlanner.retainedCheckpointIDs(
            in: [stale, previous, planned],
            now: now,
            maxEntries: 2
        )

        XCTAssertEqual(retained, Set(["older", "newer"]))

        let state = BASEvolutionCheckpointPlanner.currentState(from: [stale, previous, planned])
        XCTAssertEqual(state.checkpointCount, 3)
        XCTAssertEqual(state.pendingReviewCount, 1)
        XCTAssertEqual(state.latestCheckpoint?.id, "newer")
    }
}
