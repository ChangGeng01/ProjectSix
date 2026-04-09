import XCTest
@testable import Before

@MainActor
final class DecisionTaskGraphStoreTests: XCTestCase {
    override func tearDown() {
        DecisionTaskGraphStore.clear()
        UserDefaults.standard.removeObject(forKey: "before.decision.task.graph")
        super.tearDown()
    }

    func testQuickCaptureTracksSignalEvaluationAndCommitStates() {
        let session = QuickCheckSession(entrySource: .app, initialNote: "Do I buy this now?")
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        let beforeEvaluation = DecisionTaskGraphSnapshot.capture(from: session)
        XCTAssertEqual(beforeEvaluation?.mode, .quick)
        XCTAssertEqual(beforeEvaluation?.tasks.first(where: { $0.kind == .collectSignals })?.status, .completed)
        XCTAssertEqual(beforeEvaluation?.tasks.first(where: { $0.kind == .evaluate })?.status, .inProgress)
        XCTAssertEqual(beforeEvaluation?.tasks.first(where: { $0.kind == .commit })?.status, .pending)

        session.evaluate()
        session.selectedAction = .wait90s

        let afterEvaluation = DecisionTaskGraphSnapshot.capture(from: session)
        XCTAssertEqual(afterEvaluation?.tasks.first(where: { $0.kind == .evaluate })?.status, .completed)
        XCTAssertEqual(afterEvaluation?.tasks.first(where: { $0.kind == .commit })?.status, .completed)
        XCTAssertEqual(
            afterEvaluation?.nextActionHint,
            "The quick judgment already has a chosen action; let that path finish before reopening the loop."
        )
    }

    func testStoreRoundTripPreservesMirrorTaskGraph() {
        let session = MirrorWorkspaceSession(entrySource: .app, prompt: "Should I leave?")
        session.emotion = "Exhausted"
        session.relationship = "The same boundary keeps getting crossed"
        session.reality = "We still share a lease"
        session.selfLens = "I trust myself less here"

        let snapshot = DecisionTaskGraphSnapshot.capture(from: session)
        XCTAssertEqual(snapshot?.mode, .mirror)
        XCTAssertEqual(snapshot?.tasks.first(where: { $0.kind == .collectSignals })?.status, .completed)

        if let snapshot {
            DecisionTaskGraphStore.save(snapshot)
        }

        let loaded = DecisionTaskGraphStore.load()
        XCTAssertEqual(loaded, snapshot)
        XCTAssertEqual(loaded?.promptSeed, "Should I leave?")
        XCTAssertFalse(loaded?.continuityFingerprint.isEmpty ?? true)
    }

    func testLoadRejectsTamperedContinuityFingerprint() {
        let session = QuickCheckSession(entrySource: .app, initialNote: "Do I buy this now?")
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        guard let snapshot = DecisionTaskGraphSnapshot.capture(from: session) else {
            XCTFail("Expected task graph snapshot")
            return
        }

        let tampered = DecisionTaskGraphSnapshot(
            schemaVersion: snapshot.schemaVersion,
            mode: snapshot.mode ?? .quick,
            promptSeed: snapshot.promptSeed,
            nextActionHint: snapshot.nextActionHint,
            continuityFingerprint: "tampered",
            tasks: snapshot.tasks,
            updatedAt: snapshot.updatedAt
        )
        DecisionTaskGraphStore.save(tampered)

        XCTAssertNil(DecisionTaskGraphStore.load())
    }

    func testLoadPurgesLegacyUserDefaultsTaskGraphWithoutRestoringIt() throws {
        DecisionTaskGraphStore.clear()

        let session = QuickCheckSession(entrySource: .app, initialNote: "Do I buy this now?")
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        guard let snapshot = DecisionTaskGraphSnapshot.capture(from: session) else {
            XCTFail("Expected task graph snapshot")
            return
        }

        let key = "before.decision.task.graph"
        let data = try JSONEncoder().encode(snapshot)
        UserDefaults.standard.set(data, forKey: key)

        XCTAssertNil(DecisionTaskGraphStore.load())
        XCTAssertNil(UserDefaults.standard.data(forKey: key))
    }
}
