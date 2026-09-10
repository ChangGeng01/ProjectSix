import Foundation

struct TomorrowBoxDraft: Codable, Equatable, Sendable {
    var prompt: String
    var scenarioRaw: String?
    var motivationRaw: String?
    var expectedOutcomeRaw: String?
    var controlLevelRaw: String?
    var note: String?
    var desire: String?
    var concern: String?
    var constraint: String?
    var longTerm: String?
    var emotion: String?
    var relationship: String?
    var reality: String?
    var selfLens: String?

    @MainActor
    static func quick(from session: QuickCheckSession) -> TomorrowBoxDraft {
        TomorrowBoxDraft(
            prompt: trimmed(session.note),
            scenarioRaw: session.scenario.rawValue,
            motivationRaw: session.motivation?.rawValue,
            expectedOutcomeRaw: session.expectedOutcome?.rawValue,
            controlLevelRaw: session.controlLevel?.rawValue,
            note: trimmed(session.note)
        )
    }

    static func quick(from event: CheckEvent) -> TomorrowBoxDraft {
        TomorrowBoxDraft(
            prompt: trimmed(event.note),
            scenarioRaw: event.scenario.rawValue,
            motivationRaw: event.motivation.rawValue,
            expectedOutcomeRaw: event.expectedOutcome.rawValue,
            controlLevelRaw: event.controlLevel.rawValue,
            note: trimmed(event.note)
        )
    }

    @MainActor
    static func balance(from session: BalanceBoardSession) -> TomorrowBoxDraft {
        TomorrowBoxDraft(
            prompt: trimmed(session.prompt),
            desire: trimmed(session.desire),
            concern: trimmed(session.concern),
            constraint: trimmed(session.constraint),
            longTerm: trimmed(session.longTerm)
        )
    }

    static func balance(from record: BalanceDecisionRecord) -> TomorrowBoxDraft {
        TomorrowBoxDraft(
            prompt: trimmed(record.prompt),
            desire: trimmed(record.desire),
            concern: trimmed(record.concern),
            constraint: trimmed(record.constraint),
            longTerm: trimmed(record.longTerm)
        )
    }

    @MainActor
    static func mirror(from session: MirrorWorkspaceSession) -> TomorrowBoxDraft {
        TomorrowBoxDraft(
            prompt: trimmed(session.prompt),
            longTerm: trimmed(session.longTerm),
            emotion: trimmed(session.emotion),
            relationship: trimmed(session.relationship),
            reality: trimmed(session.reality),
            selfLens: trimmed(session.selfLens)
        )
    }

    static func mirror(from record: MirrorDecisionRecord) -> TomorrowBoxDraft {
        TomorrowBoxDraft(
            prompt: trimmed(record.prompt),
            longTerm: trimmed(record.longTerm),
            emotion: trimmed(record.emotion),
            relationship: trimmed(record.relationship),
            reality: trimmed(record.reality),
            selfLens: trimmed(record.selfLens)
        )
    }

    @MainActor
    func restoreQuickSession(entrySource: EntrySource) -> QuickCheckSession {
        let session = QuickCheckSession(entrySource: entrySource, initialNote: note ?? prompt)
        session.scenario = scenarioRaw.flatMap(ScenarioType.init(rawValue:)) ?? .other
        session.motivation = motivationRaw.flatMap(MotivationChoice.init(rawValue:))
        session.expectedOutcome = expectedOutcomeRaw.flatMap(OutcomeChoice.init(rawValue:))
        session.controlLevel = controlLevelRaw.flatMap(ControlChoice.init(rawValue:))
        return session
    }

    @MainActor
    func restoreBalanceSession(entrySource: EntrySource) -> BalanceBoardSession {
        let session = BalanceBoardSession(entrySource: entrySource, prompt: prompt)
        session.desire = desire ?? ""
        session.concern = concern ?? ""
        session.constraint = constraint ?? ""
        session.longTerm = longTerm ?? ""
        return session
    }

    @MainActor
    func restoreMirrorSession(entrySource: EntrySource) -> MirrorWorkspaceSession {
        let session = MirrorWorkspaceSession(entrySource: entrySource, prompt: prompt)
        session.emotion = emotion ?? ""
        session.relationship = relationship ?? ""
        session.reality = reality ?? ""
        session.longTerm = longTerm ?? ""
        session.selfLens = selfLens ?? ""
        return session
    }

    func hasMeaningfulContent(for mode: DecisionMode) -> Bool {
        switch mode {
        case .quick:
            let hasNonDefaultScenario = scenarioRaw != nil && scenarioRaw != ScenarioType.buy.rawValue
            return hasNonDefaultScenario
                || motivationRaw != nil
                || expectedOutcomeRaw != nil
                || controlLevelRaw != nil
                || !Self.trimmed(prompt).isEmpty
                || !Self.trimmed(note ?? "").isEmpty
        case .balance:
            return [
                prompt,
                desire ?? "",
                concern ?? "",
                constraint ?? "",
                longTerm ?? ""
            ]
            .map(Self.trimmed)
            .contains { !$0.isEmpty }
        case .mirror:
            return [
                prompt,
                emotion ?? "",
                relationship ?? "",
                reality ?? "",
                longTerm ?? "",
                selfLens ?? ""
            ]
            .map(Self.trimmed)
            .contains { !$0.isEmpty }
        }
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
