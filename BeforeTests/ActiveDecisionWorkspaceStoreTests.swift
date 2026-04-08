import XCTest
@testable import Before

@MainActor
final class ActiveDecisionWorkspaceStoreTests: XCTestCase {
    override func tearDown() {
        ActiveDecisionWorkspaceStore.clear()
        super.tearDown()
    }

    func testQuickWorkspaceRestoresEvaluatedResult() {
        let session = QuickCheckSession(entrySource: .app, initialNote: "Do I buy this now?")
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe
        session.evaluate()

        let state = ActiveDecisionWorkspaceState.capture(from: session)
        let restored = state?.restoreQuickSession()

        XCTAssertEqual(restored?.note, "Do I buy this now?")
        XCTAssertEqual(restored?.motivation, .reward)
        XCTAssertEqual(restored?.expectedOutcome, .temporaryRelief)
        XCTAssertEqual(restored?.controlLevel, .maybe)
        XCTAssertEqual(restored?.result?.verdict, .pause)
    }

    func testQuickWorkspaceRestoresWaitStateWithoutResult() {
        let session = QuickCheckSession(entrySource: .app, initialNote: "Do not answer yet")
        session.scenario = .other
        session.motivation = .avoiding
        session.expectedOutcome = .regret
        session.controlLevel = .no
        session.selectedAction = .wait90s
        session.isShowingWaitSheet = true

        let state = ActiveDecisionWorkspaceState.capture(from: session)
        let restored = state?.restoreQuickSession()

        XCTAssertEqual(restored?.selectedAction, .wait90s)
        XCTAssertEqual(restored?.isShowingWaitSheet, true)
        XCTAssertNil(restored?.result)
    }

    func testStoreRoundTripPreservesMirrorWorkspace() {
        let session = MirrorWorkspaceSession(entrySource: .app, prompt: "Should I leave?")
        session.emotion = "Exhausted"
        session.relationship = "The same boundary keeps getting crossed"
        session.reality = "We still share a lease"
        session.longTerm = "I keep shrinking"
        session.selfLens = "I trust myself less"
        session.evaluate()

        let state = ActiveDecisionWorkspaceState.capture(from: session)
        XCTAssertNotNil(state)

        if let state {
            ActiveDecisionWorkspaceStore.save(state)
        }

        let loaded = ActiveDecisionWorkspaceStore.load()
        let restored = loaded?.restoreMirrorSession()

        XCTAssertEqual(loaded?.mode, .mirror)
        XCTAssertEqual(restored?.prompt, "Should I leave?")
        XCTAssertEqual(restored?.selfLens, "I trust myself less")
        XCTAssertEqual(restored?.result?.nextActionTitle, "Write the boundary")
        XCTAssertNotNil(loaded?.intelligenceLifecycle?.fieldRecords[DecisionContextFieldKey.mirrorEmotion.rawValue])
        XCTAssertNotNil(restored?.intelligenceLifecycleSnapshot.fieldRecords[DecisionContextFieldKey.mirrorEmotion.rawValue])
    }
}
