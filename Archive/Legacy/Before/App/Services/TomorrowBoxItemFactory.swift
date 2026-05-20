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
            draft: .quick(from: session),
            riskLevel: quickRiskLevel(for: result),
            brainSnapshot: session.brainState?.verificationSnapshot,
            taskGraphSummary: "Quick check with \(session.scenario.title.lowercased()) still active.",
            reopenHint: result.primaryAction.title(using: BeforePolicy.QuickCheck.defaultBufferDuration),
            templateHint: session.brainState?.activeInterventionTemplateIDs.first,
            interventionHistorySummary: session.brainState?.sessionBiases.first
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
            draft: .quick(from: event),
            riskLevel: event.reflectionOutcome == .regrettedIt || event.reflectionOutcome == .feltEmptier ? .high : .medium,
            taskGraphSummary: "Quick check history for \(event.scenario.title.lowercased()).",
            reopenHint: "Reopen this with a pause instead of replaying the same urge.",
            interventionHistorySummary: event.reflectionNote
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
            draft: .balance(from: session),
            riskLevel: .medium,
            brainSnapshot: session.brainState?.verificationSnapshot,
            taskGraphSummary: result.focusTitle,
            reopenHint: result.nextAction,
            templateHint: session.brainState?.activeInterventionTemplateIDs.first,
            interventionHistorySummary: session.brainState?.sessionBiases.first
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
            draft: .balance(from: record),
            riskLevel: .medium,
            taskGraphSummary: record.focusTitle,
            reopenHint: record.nextAction
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
            draft: .mirror(from: session),
            riskLevel: .high,
            brainSnapshot: session.brainState?.verificationSnapshot,
            taskGraphSummary: result.nextActionTitle,
            reopenHint: result.nextAction,
            templateHint: session.brainState?.activeInterventionTemplateIDs.first,
            interventionHistorySummary: session.brainState?.sessionBiases.first
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
            draft: .mirror(from: record),
            riskLevel: .high,
            taskGraphSummary: record.nextActionTitle,
            reopenHint: record.nextAction
        )
    }

    static func makeSupportItem(
        from request: SupportRequest,
        entrySource: EntrySource = .app,
        referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TomorrowBoxItem? {
        guard let mode = request.mode, let draft = request.draft else { return nil }

        let prompt = trimmed(draft.prompt)
        let title = trimmed(request.message).isEmpty ? request.kind.title : trimmed(request.message)
        let detail = trimmed(request.reply ?? request.summary)

        return TomorrowBoxItem(
            dueAt: dueDate(after: referenceDate, calendar: calendar),
            mode: mode,
            title: title,
            detail: detail,
            prompt: prompt,
            entrySource: entrySource,
            draft: draft,
            riskLevel: .medium,
            taskGraphSummary: request.summary,
            reopenHint: request.reply ?? request.summary,
            interventionHistorySummary: request.message
        )
    }

    static func makeSharedLifeItem(
        from item: SharedLifeBoxItem,
        entrySource: EntrySource = .app,
        referenceDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TomorrowBoxItem? {
        guard let mode = item.mode, let draft = item.draft else { return nil }

        return TomorrowBoxItem(
            dueAt: dueDate(after: referenceDate, calendar: calendar),
            mode: mode,
            title: trimmed(item.title),
            detail: trimmed(item.detail),
            prompt: trimmed(item.prompt),
            entrySource: entrySource,
            draft: draft,
            riskLevel: .medium,
            taskGraphSummary: trimmed(item.title),
            reopenHint: trimmed(item.detail),
            interventionHistorySummary: trimmed(item.prompt)
        )
    }

    private static func quickRiskLevel(for result: QuickCheckResult) -> InterventionRiskLevel {
        switch result.verdict {
        case .goAhead:
            .low
        case .pause:
            .medium
        case .notRecommended:
            .high
        }
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
