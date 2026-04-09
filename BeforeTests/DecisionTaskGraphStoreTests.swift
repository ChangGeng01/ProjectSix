import XCTest
@testable import Before

@MainActor
final class DecisionTaskGraphStoreTests: XCTestCase {
    override func tearDown() {
        DecisionTaskGraphStore.clear()
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
}
