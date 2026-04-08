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
        let prompt = trimmed(note)
        let title = prompt.isEmpty ? "\(scenario.title) later" : prompt
        return TomorrowBoxItem(
            dueAt: NotificationService.nextTomorrowReminderDate(after: .now),
            mode: .quick,
            title: title,
            detail: afterPerspective,
            prompt: prompt,
            entrySource: entrySource,
            linkedCheckEventID: id,
            draft: .quick(from: self)
        )
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
        TomorrowBoxItem(
            dueAt: NotificationService.nextTomorrowReminderDate(after: .now),
            mode: .balance,
            title: trimmed(prompt),
            detail: focusSummary,
            prompt: trimmed(prompt),
            entrySource: entrySource,
            draft: .balance(from: self)
        )
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
        TomorrowBoxItem(
            dueAt: NotificationService.nextTomorrowReminderDate(after: .now),
            mode: .mirror,
            title: trimmed(prompt),
            detail: coreTension,
            prompt: trimmed(prompt),
            entrySource: entrySource,
            draft: .mirror(from: self)
        )
    }
}

private func trimmed(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
}
