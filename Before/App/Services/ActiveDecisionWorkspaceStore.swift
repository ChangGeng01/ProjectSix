import Foundation

struct ActiveDecisionWorkspaceState: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var modeRaw: String
    var entrySourceRaw: String
    var draft: TomorrowBoxDraft
    var wasEvaluated: Bool
    var selectedActionRaw: String?
    var isShowingWaitSheet: Bool

    init(
        schemaVersion: Int = 1,
        mode: DecisionMode,
        entrySource: EntrySource,
        draft: TomorrowBoxDraft,
        wasEvaluated: Bool = false,
        selectedAction: CheckAction? = nil,
        isShowingWaitSheet: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.modeRaw = mode.rawValue
        self.entrySourceRaw = entrySource.rawValue
        self.draft = draft
        self.wasEvaluated = wasEvaluated
        self.selectedActionRaw = selectedAction?.rawValue
        self.isShowingWaitSheet = isShowingWaitSheet
    }

    var mode: DecisionMode? {
        DecisionMode(rawValue: modeRaw)
    }

    var entrySource: EntrySource {
        EntrySource(rawValue: entrySourceRaw) ?? .app
    }

    var selectedAction: CheckAction? {
        selectedActionRaw.flatMap(CheckAction.init(rawValue:))
    }

    @MainActor
    static func capture(from session: QuickCheckSession) -> ActiveDecisionWorkspaceState? {
        let draft = TomorrowBoxDraft.quick(from: session)
        guard draft.hasMeaningfulContent(for: .quick) else { return nil }

        return ActiveDecisionWorkspaceState(
            mode: .quick,
            entrySource: session.entrySource,
            draft: draft,
            wasEvaluated: session.result != nil,
            selectedAction: session.selectedAction,
            isShowingWaitSheet: session.isShowingWaitSheet
        )
    }

    @MainActor
    static func capture(from session: BalanceBoardSession) -> ActiveDecisionWorkspaceState? {
        let draft = TomorrowBoxDraft.balance(from: session)
        guard draft.hasMeaningfulContent(for: .balance) else { return nil }

        return ActiveDecisionWorkspaceState(
            mode: .balance,
            entrySource: session.entrySource,
            draft: draft,
            wasEvaluated: session.result != nil
        )
    }

    @MainActor
    static func capture(from session: MirrorWorkspaceSession) -> ActiveDecisionWorkspaceState? {
        let draft = TomorrowBoxDraft.mirror(from: session)
        guard draft.hasMeaningfulContent(for: .mirror) else { return nil }

        return ActiveDecisionWorkspaceState(
            mode: .mirror,
            entrySource: session.entrySource,
            draft: draft,
            wasEvaluated: session.result != nil
        )
    }

    @MainActor
    func restoreQuickSession() -> QuickCheckSession {
        let session = draft.restoreQuickSession(entrySource: entrySource)
        session.selectedAction = selectedAction
        session.isShowingWaitSheet = isShowingWaitSheet

        if wasEvaluated, session.canEvaluate, !isShowingWaitSheet {
            session.evaluate()
        }

        return session
    }

    @MainActor
    func restoreBalanceSession() -> BalanceBoardSession {
        let session = draft.restoreBalanceSession(entrySource: entrySource)

        if wasEvaluated, session.canEvaluate {
            session.evaluate()
        }

        return session
    }

    @MainActor
    func restoreMirrorSession() -> MirrorWorkspaceSession {
        let session = draft.restoreMirrorSession(entrySource: entrySource)

        if wasEvaluated, session.canEvaluate {
            session.evaluate()
        }

        return session
    }
}

enum ActiveDecisionWorkspaceStore {
    private static let key = "before.active.decision.workspace"

    static func load() -> ActiveDecisionWorkspaceState? {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let state = try? JSONDecoder().decode(ActiveDecisionWorkspaceState.self, from: data)
        else {
            return nil
        }

        return state
    }

    static func save(_ state: ActiveDecisionWorkspaceState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
