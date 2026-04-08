import Foundation

enum TomorrowBoxItemFactory {
    @MainActor
    static func makeQuickItem(
        from session: QuickCheckSession,
        result: QuickCheckResult,
        eventID: UUID? = nil,
        referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TomorrowBoxItem {
        let prompt = trimmed(session.note)
        let title = prompt.isEmpty ? "\(session.scenario.title) later" : prompt
        return TomorrowBoxItem(
            dueAt: dueDate(after: referenceDate, calendar: calendar),
            mode: .quick,
            title: title,
            detail: result.afterPerspective,
            prompt: prompt,
            entrySource: session.entrySource,
            linkedCheckEventID: eventID,
            draft: .quick(from: session)
        )
    }

    static func makeQuickItem(
        from event: CheckEvent,
        entrySource: EntrySource = .app,
        referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TomorrowBoxItem {
        let prompt = trimmed(event.note)
        let title = prompt.isEmpty ? "\(event.scenario.title) later" : prompt
        return TomorrowBoxItem(
            dueAt: dueDate(after: referenceDate, calendar: calendar),
            mode: .quick,
            title: title,
            detail: event.afterPerspective,
            prompt: prompt,
            entrySource: entrySource,
            linkedCheckEventID: event.id,
            draft: .quick(from: event)
        )
    }

    @MainActor
    static func makeBalanceItem(
        from session: BalanceBoardSession,
        result: BalanceBoardResult,
        referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TomorrowBoxItem {
        let prompt = trimmed(session.prompt)
        return TomorrowBoxItem(
            dueAt: dueDate(after: referenceDate, calendar: calendar),
            mode: .balance,
            title: prompt,
            detail: result.summary,
            prompt: prompt,
            entrySource: session.entrySource,
            draft: .balance(from: session)
        )
    }

    static func makeBalanceItem(
        from record: BalanceDecisionRecord,
        entrySource: EntrySource = .app,
        referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TomorrowBoxItem {
        let prompt = trimmed(record.prompt)
        return TomorrowBoxItem(
            dueAt: dueDate(after: referenceDate, calendar: calendar),
            mode: .balance,
            title: prompt,
            detail: record.focusSummary,
            prompt: prompt,
            entrySource: entrySource,
            draft: .balance(from: record)
        )
    }

    @MainActor
    static func makeMirrorItem(
        from session: MirrorWorkspaceSession,
        result: MirrorResult,
        referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TomorrowBoxItem {
        let prompt = trimmed(session.prompt)
        return TomorrowBoxItem(
            dueAt: dueDate(after: referenceDate, calendar: calendar),
            mode: .mirror,
            title: prompt,
            detail: result.coreTension,
            prompt: prompt,
            entrySource: session.entrySource,
            draft: .mirror(from: session)
        )
    }

    static func makeMirrorItem(
        from record: MirrorDecisionRecord,
        entrySource: EntrySource = .app,
        referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TomorrowBoxItem {
        let prompt = trimmed(record.prompt)
        return TomorrowBoxItem(
            dueAt: dueDate(after: referenceDate, calendar: calendar),
            mode: .mirror,
            title: prompt,
            detail: record.coreTension,
            prompt: prompt,
            entrySource: entrySource,
            draft: .mirror(from: record)
        )
    }

    private static func dueDate(
        after referenceDate: Date,
        calendar: Calendar
    ) -> Date {
        BeforePolicy.Notifications.normalizedReminderDate(after: referenceDate, calendar: calendar)
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
