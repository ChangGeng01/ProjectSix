import XCTest
@testable import Before

@MainActor
final class ActiveDecisionWorkspaceStoreTests: XCTestCase {
    override func tearDown() {
        ActiveDecisionWorkspaceStore.clear()
        ProtectedLocalStateStore.clearQuarantine(key: "before.active.decision.workspace")
        StateStorageIssueRecorder.clear()
        UserDefaults.standard.removeObject(forKey: "before.active.decision.workspace")
        super.tearDown()
    }

    func testQuickWorkspaceRestoresEvaluatedResult() {
        let session = QuickCheckSession(entrySource: .app, initialNote: "Do I buy this now?")
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe
        session.evaluate()

        guard let originalResult = session.result else {
            XCTFail("Expected evaluated quick result")
            return
        }

        guard var state = ActiveDecisionWorkspaceState.capture(from: session) else {
            XCTFail("Expected workspace state")
            return
        }

        state.draft.motivationRaw = MotivationChoice.genuineNeed.rawValue
        state.draft.expectedOutcomeRaw = OutcomeChoice.satisfied.rawValue
        state.draft.controlLevelRaw = ControlChoice.yes.rawValue

        let changedSession = state.draft.restoreQuickSession(entrySource: .app)
        changedSession.evaluate()
        XCTAssertEqual(changedSession.result?.verdict, .goAhead)

        let restored = state.restoreQuickSession()

        XCTAssertEqual(restored.note, "Do I buy this now?")
        XCTAssertEqual(restored.motivation, .genuineNeed)
        XCTAssertEqual(restored.expectedOutcome, .satisfied)
        XCTAssertEqual(restored.controlLevel, .yes)
        XCTAssertEqual(restored.result?.verdict, originalResult.verdict)
        XCTAssertEqual(restored.result?.primaryAction, originalResult.primaryAction)
        XCTAssertEqual(restored.result?.currentPerspective, originalResult.currentPerspective)
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

        guard let originalResult = session.result else {
            XCTFail("Expected mirror result")
            return
        }

        guard var state = ActiveDecisionWorkspaceState.capture(from: session) else {
            XCTFail("Expected workspace state")
            return
        }

        state.draft.relationship = "I might miss them"
        state.draft.reality = ""
        state.draft.selfLens = "I am afraid of being alone"

        let changedSession = state.draft.restoreMirrorSession(entrySource: .app)
        changedSession.evaluate()
        XCTAssertEqual(changedSession.result?.nextActionTitle, "Name the real question")

        ActiveDecisionWorkspaceStore.save(state)

        let loaded = ActiveDecisionWorkspaceStore.load()
        let restored = loaded?.restoreMirrorSession()

        XCTAssertEqual(loaded?.mode, .mirror)
        XCTAssertEqual(restored?.prompt, "Should I leave?")
        XCTAssertEqual(restored?.selfLens, "I am afraid of being alone")
        XCTAssertEqual(restored?.result?.nextActionTitle, originalResult.nextActionTitle)
        XCTAssertEqual(restored?.result?.coreTension, originalResult.coreTension)
        XCTAssertNotNil(loaded?.intelligenceLifecycle?.fieldRecords[DecisionContextFieldKey.mirrorEmotion.rawValue])
        XCTAssertNotNil(restored?.intelligenceLifecycleSnapshot.fieldRecords[DecisionContextFieldKey.mirrorEmotion.rawValue])
    }

    func testSaveStoresWorkspaceOnlyInProtectedLocalState() throws {
        ActiveDecisionWorkspaceStore.clear()

        let session = QuickCheckSession(entrySource: .app, initialNote: "Do I buy this now?")
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        guard let state = ActiveDecisionWorkspaceState.capture(from: session) else {
            XCTFail("Expected workspace state")
            return
        }

        let key = "before.active.decision.workspace"
        ActiveDecisionWorkspaceStore.save(state)

        XCTAssertNil(UserDefaults.standard.data(forKey: key))
        XCTAssertEqual(
            ProtectedLocalStateStore.load(ActiveDecisionWorkspaceState.self, key: key),
            state
        )
    }

    func testLoadPurgesLegacyUserDefaultsWorkspaceWithoutRestoringIt() throws {
        ActiveDecisionWorkspaceStore.clear()

        let session = QuickCheckSession(entrySource: .app, initialNote: "Do I buy this now?")
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        guard let state = ActiveDecisionWorkspaceState.capture(from: session) else {
            XCTFail("Expected workspace state")
            return
        }

        let key = "before.active.decision.workspace"
        let data = try JSONEncoder().encode(state)
        UserDefaults.standard.set(data, forKey: key)

        XCTAssertNil(ActiveDecisionWorkspaceStore.load())
        XCTAssertNil(UserDefaults.standard.data(forKey: key))
    }

    func testClearRemovesProtectedWorkspaceAndLegacyDefaults() throws {
        ActiveDecisionWorkspaceStore.clear()

        let session = QuickCheckSession(entrySource: .app, initialNote: "Do I buy this now?")
        session.scenario = .buy
        session.motivation = .reward
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        guard let state = ActiveDecisionWorkspaceState.capture(from: session) else {
            XCTFail("Expected workspace state")
            return
        }

        let key = "before.active.decision.workspace"
        ActiveDecisionWorkspaceStore.save(state)
        let legacyData = try JSONEncoder().encode(state)
        UserDefaults.standard.set(legacyData, forKey: key)

        ActiveDecisionWorkspaceStore.clear()

        XCTAssertNil(ProtectedLocalStateStore.loadData(key: key))
        XCTAssertNil(UserDefaults.standard.data(forKey: key))
    }

    func testLoadQuarantinesCorruptedProtectedWorkspacePayload() {
        ActiveDecisionWorkspaceStore.clear()

        let key = "before.active.decision.workspace"
        ProtectedLocalStateStore.saveData(Data("not-json".utf8), key: key)

        XCTAssertNil(ActiveDecisionWorkspaceStore.load())
        XCTAssertNil(ProtectedLocalStateStore.loadData(key: key))
        XCTAssertEqual(ProtectedLocalStateStore.quarantinedData(key: key), Data("not-json".utf8))
        XCTAssertNotNil(StateStorageIssueRecorder.latestNotice())
    }

    func testLoadClearsExpiredWorkspaceState() {
        ActiveDecisionWorkspaceStore.clear()

        let state = ActiveDecisionWorkspaceState(
            savedAt: Date(timeIntervalSince1970: 10),
            mode: .quick,
            entrySource: .app,
            draft: TomorrowBoxDraft(prompt: "Old workspace", note: "Old workspace")
        )

        ActiveDecisionWorkspaceStore.save(state)

        let now = Date(timeIntervalSince1970: 10 + BeforePolicy.RuntimeState.workspaceRetentionInterval + 1)
        XCTAssertNil(ActiveDecisionWorkspaceStore.load(now: now))
        XCTAssertNil(ProtectedLocalStateStore.loadData(key: "before.active.decision.workspace"))
    }
}
