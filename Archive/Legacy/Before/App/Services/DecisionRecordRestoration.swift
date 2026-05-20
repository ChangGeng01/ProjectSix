import Foundation

extension CheckEvent {
    @MainActor
    func restoredSession(entrySource: EntrySource = .app) -> QuickCheckSession {
        let session = QuickCheckSession(entrySource: entrySource, initialNote: note)
        session.scenario = scenario
        session.motivation = motivation
        session.expectedOutcome = expectedOutcome
        session.controlLevel = controlLevel
        session.evaluate()
        session.selectedAction = finalAction
        return session
    }

    func makeTomorrowBoxItem(entrySource: EntrySource = .app) -> TomorrowBoxItem {
        TomorrowBoxItemFactory.makeQuickItem(from: self, entrySource: entrySource)
    }
}

extension BalanceDecisionRecord {
    @MainActor
    func restoredSession(entrySource: EntrySource = .app) -> BalanceBoardSession {
        let session = BalanceBoardSession(entrySource: entrySource, prompt: prompt)
        session.desire = desire
        session.concern = concern
        session.constraint = constraint
        session.longTerm = longTerm
        session.evaluate()
        return session
    }

    func makeTomorrowBoxItem(entrySource: EntrySource = .app) -> TomorrowBoxItem {
        TomorrowBoxItemFactory.makeBalanceItem(from: self, entrySource: entrySource)
    }
}

extension MirrorDecisionRecord {
    @MainActor
    func restoredSession(entrySource: EntrySource = .app) -> MirrorWorkspaceSession {
        let session = MirrorWorkspaceSession(entrySource: entrySource, prompt: prompt)
        session.emotion = emotion
        session.relationship = relationship
        session.reality = reality
        session.longTerm = longTerm
        session.selfLens = selfLens
        session.evaluate()
        return session
    }

    func makeTomorrowBoxItem(entrySource: EntrySource = .app) -> TomorrowBoxItem {
        TomorrowBoxItemFactory.makeMirrorItem(from: self, entrySource: entrySource)
    }
}
